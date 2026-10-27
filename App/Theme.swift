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
    static let mileageAccentText = mileageColor(light: MileageTokens.Light.accentText, dark: MileageTokens.Dark.accentText)
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
            .font(.headline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, MileageTokens.Space.lg)
            .padding(.vertical, MileageTokens.Space.lg)
            .foregroundStyle(Color.mileageOnAccent)
            .background(Color.mileageGreen, in: Capsule())
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
            .padding(.vertical, MileageTokens.Space.lg)
            .foregroundStyle(Color.mileagePrimary)
            .background(Color.mileageField, in: Capsule())
            .overlay {
                Capsule()
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


struct MileageCategoryPicker: View {
    @Binding var selection: TripCategory

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TripCategory.allCases) { category in
                Button { selection = category } label: {
                    Text(category.rawValue)
                        .font(.subheadline.weight(selection == category ? .semibold : .regular))
                        .foregroundStyle(selection == category ? Color.mileageAccentText : Color.mileagePrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == category {
                                Capsule().fill(Color.mileageGreen.opacity(0.16))
                                    .overlay { Capsule().strokeBorder(Color.mileageGreen.opacity(0.4), lineWidth: 0.7) }
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == category ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.mileageField, in: Capsule())
        .overlay { Capsule().strokeBorder(Color.mileageSeparator, lineWidth: 0.7) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trip category")
    }
}

struct MileageRouteGlyph: View {
    var highlighted = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.24, y: size.height * 0.15))
                path.addCurve(to: CGPoint(x: size.width * 0.76, y: size.height * 0.85),
                              control1: CGPoint(x: size.width * 0.12, y: size.height * 0.65),
                              control2: CGPoint(x: size.width * 0.28, y: size.height * 0.84))
            }
            .stroke(highlighted ? Color.mileageAccentText : Color.mileageSecondary,
                    style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            Circle().fill(Color.mileageBackground)
                .overlay { Circle().strokeBorder(Color.mileagePrimary, lineWidth: 1.7) }
                .frame(width: 6, height: 6)
                .position(x: size.width * 0.24, y: size.height * 0.15)
            Circle().fill(Color.mileageBackground)
                .overlay { Circle().strokeBorder(Color.mileagePrimary, lineWidth: 1.7) }
                .frame(width: 6, height: 6)
                .position(x: size.width * 0.76, y: size.height * 0.85)
        }
        .frame(width: 21, height: 34)
        .accessibilityHidden(true)
    }
}
