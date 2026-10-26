import SwiftUI

extension Color {
    static let mileageGreen = Color(red: 0.25, green: 0.91, blue: 0.65)
    static let mileageBackground = Color(red: 0.035, green: 0.065, blue: 0.08)
    static let mileageCard = Color(red: 0.075, green: 0.11, blue: 0.13)
}

struct MileageCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mileageCard, in: RoundedRectangle(cornerRadius: 26))
    }
}

struct IssueBanner: View {
    var text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
