import SwiftUI

enum LootaTheme {
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(
            colors: [
                Color(red: 226 / 255, green: 235 / 255, blue: 246 / 255),
                Color(red: 197 / 255, green: 214 / 255, blue: 233 / 255),
                Color(red: 173 / 255, green: 193 / 255, blue: 215 / 255)
            ]
        ),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        gradient: Gradient(
            colors: [
                Color(red: 51 / 255, green: 153 / 255, blue: 245 / 255),
                Color(red: 66 / 255, green: 205 / 255, blue: 172 / 255)
            ]
        ),
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGlow = Color(red: 54 / 255, green: 136 / 255, blue: 219 / 255)
    static let cosmicPurple = Color(red: 63 / 255, green: 119 / 255, blue: 185 / 255)
    static let neonCyan = Color(red: 68 / 255, green: 181 / 255, blue: 201 / 255)
    static let highlight = Color(red: 250 / 255, green: 208 / 255, blue: 126 / 255)
    static let success = Color(red: 43 / 255, green: 175 / 255, blue: 131 / 255)
    static let warning = Color(red: 226 / 255, green: 150 / 255, blue: 93 / 255)

    static let textPrimary = Color(red: 26 / 255, green: 41 / 255, blue: 61 / 255)
    static let textSecondary = Color(red: 45 / 255, green: 74 / 255, blue: 104 / 255).opacity(0.8)
    static let textMuted = Color(red: 65 / 255, green: 96 / 255, blue: 130 / 255).opacity(0.7)

    static let panelBackground = Color.white.opacity(0.28)
    static let panelBorder = Color.white.opacity(0.55)
    static let panelHighlight = Color.white.opacity(0.8)
    static let panelShadow = Color(red: 117 / 255, green: 140 / 255, blue: 166 / 255).opacity(0.45)
    static let panelDeepShadow = Color(red: 121 / 255, green: 146 / 255, blue: 172 / 255).opacity(0.55)
    static let insetShadow = Color(red: 118 / 255, green: 141 / 255, blue: 168 / 255).opacity(0.36)
    static let insetHighlight = Color.white.opacity(0.72)

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
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LootaTheme.panelHighlight.opacity(0.35),
                                    LootaTheme.panelBackground
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LootaTheme.panelBorder, lineWidth: 1.2)

                    RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                        .stroke(LootaTheme.panelHighlight.opacity(0.4), lineWidth: 0.8)
                        .blur(radius: 0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .compositingGroup()
                .shadow(color: LootaTheme.panelHighlight.opacity(0.55), radius: 10, x: -5, y: -5)
                .shadow(color: LootaTheme.panelShadow, radius: 18, x: 10, y: 12)
            )
    }
}

struct LootaInsetFieldBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.26))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .compositingGroup()
                    .shadow(color: LootaTheme.insetHighlight.opacity(0.9), radius: 4, x: -3, y: -3)
                    .shadow(color: LootaTheme.insetShadow, radius: 7, x: 4, y: 6)
            )
    }
}

struct LootaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [LootaTheme.cosmicPurple, LootaTheme.neonCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .compositingGroup()
                    .shadow(color: Color.white.opacity(0.3), radius: 5, x: -3, y: -3)
                    .shadow(color: LootaTheme.panelDeepShadow.opacity(configuration.isPressed ? 0.4 : 0.75), radius: configuration.isPressed ? 6 : 12, x: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 4 : 8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func lootaGlassBackground(
        cornerRadius: CGFloat = 24,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
    ) -> some View {
        modifier(LootaGlassBackground(cornerRadius: cornerRadius, padding: padding))
    }

    func lootaInsetField(cornerRadius: CGFloat = 16) -> some View {
        modifier(LootaInsetFieldBackground(cornerRadius: cornerRadius))
    }
}
