import SwiftUI
import UIKit

/// Shared native styles. Palette, spacing, and radii come from design/tokens.json.
enum MileageAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    private static func mileageColor(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    static let mileageBackground = mileageColor(light: MileageTokens.Light.background, dark: MileageTokens.Dark.background)
    static let mileageCard = mileageColor(light: MileageTokens.Light.surface, dark: MileageTokens.Dark.surface)
    static let mileageField = mileageColor(light: MileageTokens.Light.surfaceSecondary, dark: MileageTokens.Dark.surfaceSecondary)
    static let mileagePrimary = mileageColor(light: MileageTokens.Light.text, dark: MileageTokens.Dark.text)
    static let mileageSecondary = mileageColor(light: MileageTokens.Light.textSecondary, dark: MileageTokens.Dark.textSecondary)
    static let mileageSeparator = mileageColor(light: MileageTokens.Light.border, dark: MileageTokens.Dark.border)
    static let mileageGreen = mileageColor(light: MileageTokens.Light.accent, dark: MileageTokens.Dark.accent)
    static let mileageOnAccent = mileageColor(light: MileageTokens.Light.onAccent, dark: MileageTokens.Dark.onAccent)
    static let mileageWarning = mileageColor(light: MileageTokens.Light.warning, dark: MileageTokens.Dark.warning)
    static let mileageWarningSurface = mileageColor(light: MileageTokens.Light.warningSurface, dark: MileageTokens.Dark.warningSurface)
    static let mileageDanger = mileageColor(light: MileageTokens.Light.danger, dark: MileageTokens.Dark.danger)
}

struct MileagePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, MileageTokens.Space.lg)
            .padding(.vertical, MileageTokens.Space.md)
            .foregroundStyle(Color.mileageOnAccent)
            .background(Color.mileageGreen, in: RoundedRectangle(cornerRadius: MileageTokens.Radius.control))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct MileageSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, MileageTokens.Space.lg)
            .padding(.vertical, MileageTokens.Space.md)
            .foregroundStyle(Color.mileagePrimary)
            .background(Color.mileageField, in: RoundedRectangle(cornerRadius: MileageTokens.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: MileageTokens.Radius.control)
                    .strokeBorder(Color.mileageSeparator, lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.45)
    }
}

struct MileageCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MileageTokens.Space.lg) { content }
            .padding(MileageTokens.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mileageCard, in: RoundedRectangle(cornerRadius: MileageTokens.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: MileageTokens.Radius.card)
                    .strokeBorder(Color.mileageSeparator, lineWidth: 1)
            }
    }
}

struct IssueBanner: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(Color.mileageWarning)
            .padding(MileageTokens.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mileageWarningSurface, in: RoundedRectangle(cornerRadius: MileageTokens.Radius.control))
            .accessibilityElement(children: .combine)
    }
}
