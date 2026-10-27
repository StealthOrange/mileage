import SwiftUI
import Charts
import UIKit

struct ReportsView: View {
    @EnvironmentObject private var store: MileageStore
    @State private var selectedMonth = Date()
    @State private var format = "PDF"
    @State private var sharedFile: MileageSharedFile?
    @State private var exportError: String?

    private var trips: [Trip] {
        store.completedTrips.filter { Calendar.current.isDate($0.startedAt, equalTo: selectedMonth, toGranularity: .month) }
    }
    private var totalMiles: Double { trips.reduce(0) { $0 + $1.miles } }
    private var businessMiles: Double { trips.filter { $0.category == .business }.reduce(0) { $0 + $1.miles } }
    private var personalMiles: Double { trips.filter { $0.category == .personal }.reduce(0) { $0 + $1.miles } }

    private var weeklyTotals: [WeeklyMileage] {
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 31
        return (1...Int(ceil(Double(days) / 7))).flatMap { week in
            TripCategory.allCases.map { category in
                let miles = trips.filter { $0.category == category && (calendar.component(.day, from: $0.startedAt) - 1) / 7 + 1 == week }.reduce(0) { $0 + $1.miles }
                return WeeklyMileage(week: week, category: category.rawValue, miles: miles)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Reports").font(.system(.largeTitle, weight: .bold))
                        Spacer()
                        MileageMonthPicker(selection: $selectedMonth, trips: store.completedTrips, compact: true)
                    }
                    InstrumentGauge(value: totalMiles, maximum: max(600, ceil(totalMiles / 100) * 100), title: "Total mileage", compact: true)
                        .padding(.top, 4)
                    HStack(alignment: .top, spacing: 20) {
                        categoryTotal("Business", value: businessMiles, color: .mileageAccentText)
                        Divider().frame(height: 54).overlay(Color.mileageSeparator)
                        categoryTotal("Personal", value: personalMiles, color: .mileageSecondary)
                    }.padding(.horizontal, 20)
                    weeklyChart
                    VStack(spacing: 0) {
                        countRow("Total trips", count: trips.count, filter: "All", accented: false)
                        countRow("Business trips", count: trips.filter { $0.category == .business }.count, filter: "Business", accented: true)
                        countRow("Personal trips", count: trips.filter { $0.category == .personal }.count, filter: "Personal", accented: false)
                    }
                    if trips.contains(where: \.needsReview) {
                        Label("Includes trips that need review", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(Color.mileageWarning)
                    }
                    if let exportError { IssueBanner(text: exportError) }
                    Button { exportReport() } label: { Label("Export report", systemImage: "doc.richtext") }
                        .buttonStyle(MileagePrimaryButtonStyle()).disabled(trips.isEmpty || store.isReadOnly)
                    HStack {
                        Text("Format").font(.subheadline)
                        Spacer()
                        MileagePillPicker(options: ["PDF", "CSV"], selection: $format).frame(maxWidth: 200)
                    }
                    if trips.isEmpty {
                        Text("Your report will be ready after you save a trip this month.")
                            .font(.caption).foregroundStyle(Color.mileageSecondary)
                    }
                }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 22)
            }
            .background(Color.mileageBackground).foregroundStyle(Color.mileagePrimary)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sharedFile) { MileageShareSheet(url: $0.url) }
        }
    }

    private func categoryTotal(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) { Circle().fill(color).frame(width: 10, height: 10); Text(title).font(.subheadline) }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value, format: .number.precision(.fractionLength(1))).font(.system(size: 27, weight: .semibold)).monospacedDigit()
                Text("mi").font(.body)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private var weeklyChart: some View {
        Chart(weeklyTotals) { item in
            BarMark(x: .value("Week", "Week \(item.week)"), y: .value("Miles", item.miles), width: .ratio(0.7))
                .position(by: .value("Category", item.category))
                .foregroundStyle(by: .value("Category", item.category))
                .cornerRadius(3)
                .accessibilityLabel("Week \(item.week), \(item.category)")
                .accessibilityValue("\(item.miles.formatted(.number.precision(.fractionLength(1)))) miles")
        }
        .chartForegroundStyleScale(["Business": Color.mileageGreen, "Personal": Color.mileageSecondary.opacity(0.65)])
        .chartYScale(domain: 0...max(10, ceil((weeklyTotals.map(\.miles).max() ?? 0) / 10) * 10))
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.mileageSeparator)
                AxisValueLabel().foregroundStyle(Color.mileageSecondary)
            }
        }
        .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.mileageSecondary) } }
        .chartLegend(position: .bottom, alignment: .center, spacing: 12)
        .font(.caption2)
        .frame(height: 160)
        .padding(.top, 4)
        .accessibilityLabel("Weekly mileage for \(selectedMonth.formatted(.dateTime.month(.wide).year()))")
    }

    private func countRow(_ title: String, count: Int, filter: String, accented: Bool) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.mileageSeparator)
            NavigationLink { TripHistoryView(initialFilter: filter, initialMonth: selectedMonth, showsBack: true) } label: {
                HStack(spacing: 17) {
                    MileageRouteSymbol(accent: accented)
                    Text(title).font(.subheadline)
                    Spacer()
                    Text("\(count)").font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.mileageSecondary)
                }.frame(minHeight: 48)
            }.buttonStyle(.plain)
        }
    }

    private func exportReport() {
        do {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM"
            let name = "Mileage-report-\(formatter.string(from: selectedMonth))"
            let url: URL
            if format == "CSV" {
                url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".csv")
                try TripCSV.export(trips).write(to: url, atomically: true, encoding: .utf8)
            } else {
                url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".pdf")
                try MileagePDFReport.write(trips: trips, month: selectedMonth, to: url)
            }
            sharedFile = MileageSharedFile(url: url); exportError = nil
        } catch { exportError = "Could not create your report: \(error.localizedDescription)" }
    }
}

private struct WeeklyMileage: Identifiable {
    var week: Int
    var category: String
    var miles: Double
    var id: String { "\(week)-\(category)" }
}

@MainActor
private enum MileagePDFReport {
    static func write(trips: [Trip], month: Date, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let titleFont = UIFont.systemFont(ofSize: 25, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let labelFont = UIFont.systemFont(ofSize: 10)
        let boldFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let muted = UIColor.darkGray
        try renderer.writePDF(to: url) { context in
            var y: CGFloat = 0
            var page = 0
            func text(_ value: String, at rect: CGRect, font: UIFont, color: UIColor = .black) {
                (value as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color])
            }
            func beginPage() {
                context.beginPage(); page += 1; y = 45
                text("Mileage report", at: CGRect(x: 42, y: y, width: 528, height: 34), font: titleFont)
                y += 40
                text(month.formatted(.dateTime.month(.wide).year()), at: CGRect(x: 42, y: y, width: 528, height: 18), font: bodyFont, color: muted)
                y += 30
                text("Page \(page) · Created \(Date().formatted(date: .abbreviated, time: .shortened))", at: CGRect(x: 42, y: 754, width: 528, height: 16), font: labelFont, color: muted)
            }
            beginPage()
            let total = trips.reduce(0) { $0 + $1.miles }
            let business = trips.filter { $0.category == .business }.reduce(0) { $0 + $1.miles }
            let personal = trips.filter { $0.category == .personal }.reduce(0) { $0 + $1.miles }
            text("\(total.formatted(.number.precision(.fractionLength(1)))) total miles · \(trips.count) trips", at: CGRect(x: 42, y: y, width: 528, height: 24), font: boldFont)
            y += 25
            text("Business: \(business.formatted(.number.precision(.fractionLength(1)))) mi     Personal: \(personal.formatted(.number.precision(.fractionLength(1)))) mi", at: CGRect(x: 42, y: y, width: 528, height: 20), font: bodyFont)
            y += 32
            for trip in trips.sorted(by: { $0.startedAt < $1.startedAt }) {
                let heading = trip.purpose.isEmpty ? "\(trip.category.rawValue) trip" : trip.purpose
                let details = "\(trip.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(trip.category.rawValue) · \(trip.miles.formatted(.number.precision(.fractionLength(2)))) mi"
                var audit = "GPS: \(trip.gpsMiles.formatted(.number.precision(.fractionLength(2)))) mi"
                if let corrected = trip.adjustedMiles { audit += " · Verified total: \(corrected.formatted(.number.precision(.fractionLength(2)))) mi" }
                if trip.needsReview { audit += " · Needs review" }
                let headingHeight = max(18, min(80, (heading as NSString).boundingRect(with: CGSize(width: 528, height: 80), options: .usesLineFragmentOrigin, attributes: [.font: boldFont], context: nil).height))
                if y + headingHeight + 56 > 724 { beginPage() }
                text(heading, at: CGRect(x: 42, y: y, width: 528, height: headingHeight + 2), font: boldFont)
                y += headingHeight + 5
                text(details, at: CGRect(x: 42, y: y, width: 528, height: 18), font: bodyFont); y += 18
                text(audit, at: CGRect(x: 42, y: y, width: 528, height: 18), font: labelFont, color: muted); y += 26
                context.cgContext.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
                context.cgContext.move(to: CGPoint(x: 42, y: y)); context.cgContext.addLine(to: CGPoint(x: 570, y: y)); context.cgContext.strokePath(); y += 13
            }
            if y + 35 > 724 { beginPage() }
            text("GPS mileage is approximate. Export CSV for correction reasons, notes, and full trip fields.", at: CGRect(x: 42, y: y, width: 528, height: 35), font: labelFont, color: muted)
        }
    }
}
