import SwiftUI
import MapKit

/// The instrument used by Home, an active drive, and the reports half dial.
struct InstrumentGauge: View {
    var value: Double
    var maximum: Double
    var title: String
    var subtitle: String? = nil
    var weeklyValues: [Double] = []
    var compact = false
    var detail: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var progress: Double { min(max(value / max(maximum, 1), 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let center = CGPoint(x: width / 2, y: compact ? proxy.size.height * 0.82 : width * 0.48)
            let radius = width * 0.445
            let start = compact ? 180.0 : 135.0
            let sweep = compact ? 180.0 : 270.0
            ZStack {
                Canvas { context, size in
                    let tickCount = compact ? 60 : 90
                    let ringRadius = radius * 1.05
                    let outer = arc(center: center, radius: ringRadius, start: start, sweep: sweep)
                    context.stroke(outer, with: .color(Color.mileageSeparator.opacity(0.8)), lineWidth: 0.8)
                    for tick in 0...tickCount {
                        let angle = start + sweep * Double(tick) / Double(tickCount)
                        let major = tick % 15 == 0
                        let length: CGFloat = major ? 12 : (tick % 5 == 0 ? 8 : 5)
                        var path = Path()
                        path.move(to: point(center, ringRadius - 6, angle))
                        path.addLine(to: point(center, ringRadius - 6 - length, angle))
                        context.stroke(path, with: .color(major ? Color.mileagePrimary.opacity(0.85) : Color.mileageSecondary.opacity(0.7)),
                                       style: StrokeStyle(lineWidth: major ? 1.4 : 0.7, lineCap: .round))
                    }
                    let activeRadius = radius * 0.88
                    context.stroke(arc(center: center, radius: activeRadius, start: start, sweep: sweep),
                                   with: .color(Color.mileageSeparator),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    if progress > 0 {
                        context.stroke(arc(center: center, radius: activeRadius, start: start, sweep: sweep * progress),
                                       with: .color(Color.mileageGreen),
                                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    }
                    let endpoint = point(center, activeRadius, start + sweep * progress)
                    context.fill(Path(ellipseIn: CGRect(x: endpoint.x - 4.5, y: endpoint.y - 4.5, width: 9, height: 9)),
                                 with: .color(Color.mileageGreen))
                    if compact {
                        let labels: [(Double, CGPoint)] = [
                            (0, CGPoint(x: center.x - radius * 1.02, y: center.y + 12)),
                            (maximum / 2, CGPoint(x: center.x, y: center.y - radius * 0.74)),
                            (maximum, CGPoint(x: center.x + radius * 1.02, y: center.y + 12))
                        ]
                        for (number, location) in labels {
                            context.draw(Text(number.formatted(.number.precision(.fractionLength(0))))
                                .font(.system(size: 10))
                                .foregroundColor(Color.mileageSecondary), at: location)
                        }
                    } else {
                        for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
                            let location = point(center, radius * 0.69, start + sweep * fraction)
                            context.draw(Text((maximum * fraction).formatted(.number.precision(.fractionLength(0))))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color.mileageSecondary), at: location)
                        }
                    }
                }
                .accessibilityHidden(true)
                VStack(spacing: compact ? 3 : 5) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(Color.mileageSecondary)
                    Text(value, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: width * (compact ? 0.16 : 0.185), weight: .semibold))
                        .tracking(-2)
                        .monospacedDigit()
                        .foregroundStyle(Color.mileagePrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(subtitle ?? "mi")
                        .font(.body)
                        .foregroundStyle(Color.mileagePrimary)
                    if let detail {
                        Text(detail)
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(Color.mileagePrimary)
                            .padding(.top, 6)
                    }
                }
                .frame(width: width * 0.58)
                .position(x: center.x, y: center.y + (compact ? -width * 0.12 : -width * 0.015))
                if !weeklyValues.isEmpty && !compact {
                    weeklyBars
                        .frame(width: width * 0.39, height: width * 0.16)
                        .position(x: center.x, y: center.y + width * 0.26)
                }
            }
        }
        .aspectRatio(compact ? 1.75 : 1.05, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value.formatted(.number.precision(.fractionLength(1)))) \(subtitle ?? "miles")\(detail.map { ", \($0)" } ?? "")")
        .accessibilityValue(weeklyValues.isEmpty ? "" : weeklyValues.enumerated().map { index, miles in
            "\(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][index % 7]): \(miles.formatted(.number.precision(.fractionLength(1)))) miles"
        }.joined(separator: ", "))
    }

    private var weeklyBars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                let dayValue = index < weeklyValues.count ? weeklyValues[index] : 0
                VStack(spacing: 5) {
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(dayValue > 0 ? Color.mileageGreen : Color.mileageSecondary.opacity(0.45))
                        .frame(width: 4, height: max(5, 28 * dayValue / max(weeklyValues.max() ?? 0, 1)))
                    Text(["M", "T", "W", "T", "F", "S", "S"][index])
                        .font(.system(size: 8))
                        .foregroundStyle(Color.mileageSecondary)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    private func arc(center: CGPoint, radius: CGFloat, start: Double, sweep: Double) -> Path {
        Path { path in
            path.move(to: point(center, radius, start))
            let steps = max(1, Int(sweep * 1.5))
            for step in 1...steps {
                path.addLine(to: point(center, radius, start + sweep * Double(step) / Double(steps)))
            }
        }
    }
}

/// A real MapKit map: only recorded samples become route lines.
struct MileageRouteMap: View {
    var trip: Trip?
    var interactive = false
    @State private var position: MapCameraPosition

    init(trip: Trip?, interactive: Bool = false) {
        self.trip = trip
        self.interactive = interactive
        _position = State(initialValue: .region(Self.region(for: trip)))
    }

    var body: some View {
        Map(position: $position, interactionModes: interactive ? .all : []) {
            if let trip {
                ForEach(Array(trip.routeSegments.enumerated()), id: \.offset) { _, segment in
                    if segment.count > 1 {
                        MapPolyline(coordinates: segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                            .stroke(Color.mileageGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                if let first = trip.samples.first {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                        Circle().fill(Color.mileageBackground)
                            .overlay { Circle().strokeBorder(Color.mileagePrimary, lineWidth: 2) }
                            .frame(width: 12, height: 12)
                    }
                    .annotationTitles(.hidden)
                }
                if trip.samples.count > 1, let last = trip.samples.last {
                    Annotation("Latest point", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                        Circle().fill(Color.mileageGreen)
                            .overlay { Circle().strokeBorder(Color.mileageOnAccent.opacity(0.55), lineWidth: 1.5) }
                            .frame(width: 12, height: 12)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .overlay(alignment: .topTrailing) {
            Label(trip?.samples.isEmpty == false ? "Recorded route" : "No recorded route", systemImage: "location")
                .font(.caption2)
                .foregroundStyle(Color.mileagePrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.mileageBackground.opacity(0.88), in: Capsule())
                .overlay { Capsule().strokeBorder(Color.mileageSeparator, lineWidth: 0.7) }
                .padding(.top, 28)
                .padding(.trailing, 24)
        }
        .allowsHitTesting(interactive)
        .onChange(of: trip?.id) { _, _ in position = .region(Self.region(for: trip)) }
        .onChange(of: trip?.samples.count) { _, _ in position = .region(Self.region(for: trip)) }
        .accessibilityLabel(trip?.samples.isEmpty == false ? "Recorded GPS route. Missing sections are not connected." : "No recorded route. Map centered on Houston as a default view.")
    }

    private static func region(for trip: Trip?) -> MKCoordinateRegion {
        guard let samples = trip?.samples, let first = samples.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698),
                                      span: MKCoordinateSpan(latitudeDelta: 0.17, longitudeDelta: 0.2))
        }
        let latitudes = samples.map(\.latitude), longitudes = samples.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude, maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude, maxLon = longitudes.max() ?? first.longitude
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                                  span: MKCoordinateSpan(latitudeDelta: max(0.015, (maxLat - minLat) * 1.4),
                                                         longitudeDelta: max(0.02, (maxLon - minLon) * 1.4)))
    }
}
