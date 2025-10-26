import SwiftUI

enum LootaTheme {
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(
            colors: [
                Color(red: 16 / 255, green: 10 / 255, blue: 63 / 255),
                Color(red: 60 / 255, green: 16 / 255, blue: 108 / 255),
                Color(red: 9 / 255, green: 32 / 255, blue: 63 / 255)
            ]
        ),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        gradient: Gradient(
            colors: [
                Color(red: 247 / 255, green: 181 / 255, blue: 0 / 255),
                Color(red: 255 / 255, green: 85 / 255, blue: 0 / 255)
            ]
        ),
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGlow = Color(red: 255 / 255, green: 140 / 255, blue: 0 / 255)
    static let cosmicPurple = Color(red: 148 / 255, green: 73 / 255, blue: 255 / 255)
    static let neonCyan = Color(red: 89 / 255, green: 243 / 255, blue: 255 / 255)
    static let highlight = Color(red: 255 / 255, green: 214 / 255, blue: 10 / 255)
    static let success = Color(red: 86 / 255, green: 255 / 255, blue: 140 / 255)
    static let warning = Color(red: 255 / 255, green: 182 / 255, blue: 89 / 255)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.45)

    static let panelBackground = Color.white.opacity(0.08)
    static let panelBorder = Color.white.opacity(0.2)
    static let panelShadow = Color.black.opacity(0.35)

    static func scoreGlow(for animationState: Bool) -> Color {
        animationState ? highlight.opacity(0.85) : highlight.opacity(0.55)
    }
}

struct LootaGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(LootaTheme.panelBorder, lineWidth: 1)
                    )
                    .shadow(color: LootaTheme.panelShadow, radius: 18, x: 0, y: 10)
            )
    }
}

extension View {
    func lootaGlassBackground(
        cornerRadius: CGFloat = 24,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
    ) -> some View {
        modifier(LootaGlassBackground(cornerRadius: cornerRadius, padding: padding))
    }
}
