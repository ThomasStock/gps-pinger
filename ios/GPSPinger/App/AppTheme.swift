import SwiftUI
#if os(iOS)
import UIKit
#endif

enum AppTheme {
    static let primary = Color.dynamic(light: .rgb(0.07, 0.29, 0.54), dark: .rgb(0.40, 0.63, 0.98))
    static let success = Color.dynamic(light: .rgb(0.06, 0.50, 0.38), dark: .rgb(0.20, 0.67, 0.53))
    static let danger = Color.dynamic(light: .rgb(0.74, 0.21, 0.20), dark: .rgb(0.94, 0.43, 0.41))

    static let textPrimary = Color.dynamic(light: .rgb(0.12, 0.16, 0.23), dark: .rgb(0.92, 0.95, 0.99))
    static let textMuted = Color.dynamic(light: .rgb(0.40, 0.45, 0.54), dark: .rgb(0.63, 0.70, 0.80))

    static let pageBackgroundTop = Color.dynamic(light: .rgb(0.95, 0.97, 0.99), dark: .rgb(0.07, 0.10, 0.14))
    static let pageBackgroundBottom = Color.dynamic(light: .rgb(0.89, 0.93, 0.97), dark: .rgb(0.11, 0.15, 0.21))
    static let cardBackground = Color.dynamic(light: .rgba(1.00, 1.00, 1.00, 0.90), dark: .rgba(0.14, 0.18, 0.26, 0.90))
    static let fieldBackground = Color.dynamic(light: .rgba(1.00, 1.00, 1.00, 0.94), dark: .rgba(0.18, 0.22, 0.30, 0.94))
    static let fieldBorder = Color.dynamic(light: .rgba(1.00, 1.00, 1.00, 0.62), dark: .rgba(0.52, 0.60, 0.73, 0.45))
    static let border = fieldBorder

    static let buttonText = Color.white
    static let buttonShadow = Color.dynamic(light: .rgba(0.00, 0.00, 0.00, 0.15), dark: .rgba(0.00, 0.00, 0.00, 0.38))
    static let secondaryButtonText = Color.dynamic(light: .rgb(0.04, 0.37, 0.27), dark: .rgb(0.70, 0.95, 0.86))
    static let secondaryButtonFill = Color.dynamic(light: .rgb(0.84, 0.95, 0.90), dark: .rgb(0.12, 0.34, 0.30))
    static let tabBarBackground = Color.dynamic(light: .rgba(0.97, 0.98, 1.00, 0.95), dark: .rgba(0.10, 0.12, 0.17, 0.95))
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}

#if os(iOS)
private extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private extension UIColor {
    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    static func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif
