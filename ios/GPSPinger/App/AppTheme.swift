import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.07, green: 0.29, blue: 0.54)
    static let success = Color(red: 0.06, green: 0.50, blue: 0.38)
    static let danger = Color(red: 0.74, green: 0.21, blue: 0.20)

    static let textPrimary = Color(red: 0.12, green: 0.16, blue: 0.23)
    static let textMuted = Color(red: 0.40, green: 0.45, blue: 0.54)

    static let pageBackgroundTop = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let pageBackgroundBottom = Color(red: 0.89, green: 0.93, blue: 0.97)
    static let cardBackground = Color.white.opacity(0.90)
    static let fieldBackground = Color.white.opacity(0.94)
    static let border = Color.white.opacity(0.62)

    static let buttonText = Color.white
    static let buttonShadow = Color.black.opacity(0.15)
    static let secondaryButtonText = Color(red: 0.04, green: 0.37, blue: 0.27)
    static let secondaryButtonFill = Color(red: 0.84, green: 0.95, blue: 0.90)
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
