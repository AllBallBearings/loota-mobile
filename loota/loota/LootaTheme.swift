import SwiftUI

enum LootaTheme {
    // MARK: - Core Colors

    // Rich, deep backgrounds with warm undertones
    private static let backgroundDark = Color(red: 18 / 255, green: 20 / 255, blue: 24 / 255)
    private static let backgroundMid = Color(red: 26 / 255, green: 28 / 255, blue: 34 / 255)
    private static let backgroundLight = Color(red: 38 / 255, green: 42 / 255, blue: 50 / 255)

    // Premium amber/gold - refined treasure aesthetic
    private static let amber = Color(red: 232 / 255, green: 170 / 255, blue: 80 / 255)
    private static let amberLight = Color(red: 248 / 255, green: 196 / 255, blue: 120 / 255)
    private static let amberDark = Color(red: 196 / 255, green: 130 / 255, blue: 50 / 255)

    // Warm coral for interactive elements
    private static let coral = Color(red: 232 / 255, green: 120 / 255, blue: 100 / 255)
    private static let coralLight = Color(red: 248 / 255, green: 150 / 255, blue: 130 / 255)

    // Soft teal for secondary accents
    private static let teal = Color(red: 90 / 255, green: 180 / 255, blue: 172 / 255)
    private static let tealLight = Color(red: 120 / 255, green: 200 / 255, blue: 192 / 255)

    // MARK: - Gradients

    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            backgroundDark,
            backgroundMid,
            backgroundDark
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [
            amberLight,
            amber
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        gradient: Gradient(colors: [
            coral,
            coralLight
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        gradient: Gradient(colors: [
            backgroundLight.opacity(0.9),
            backgroundMid.opacity(0.8)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Semantic Colors

    // Accent colors
    static let accentGlow = amber
    static let cosmicPurple = coral  // Remapped for compatibility
    static let neonCyan = teal       // Remapped for compatibility
    static let highlight = amberLight
    static let success = Color(red: 92 / 255, green: 190 / 255, blue: 140 / 255)
    static let warning = Color(red: 240 / 255, green: 160 / 255, blue: 90 / 255)

    // Text colors - warm off-whites for better aesthetics
    static let textPrimary = Color(red: 250 / 255, green: 248 / 255, blue: 244 / 255)
    static let textSecondary = Color(red: 180 / 255, green: 175 / 255, blue: 168 / 255)
    static let textMuted = Color(red: 120 / 255, green: 116 / 255, blue: 110 / 255)

    // Panel colors
    static let panelBackground = Color.white.opacity(0.05)
    static let panelBorder = Color.white.opacity(0.1)
    static let panelShadow = Color.black.opacity(0.4)

    // MARK: - Additional Components

    static let cardBackground = backgroundLight
    static let inputBackground = backgroundMid
    static let divider = Color.white.opacity(0.08)

    static func scoreGlow(for animationState: Bool) -> Color {
        animationState ? amber.opacity(0.7) : amber.opacity(0.4)
    }

    // MARK: - Button Styles

    static let primaryButtonGradient = LinearGradient(
        gradient: Gradient(colors: [amber, amberDark]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let secondaryButtonGradient = LinearGradient(
        gradient: Gradient(colors: [teal, tealLight]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct LootaGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LootaTheme.cardBackground.opacity(elevated ? 0.95 : 0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(elevated ? 0.5 : 0.3), radius: elevated ? 20 : 12, x: 0, y: elevated ? 12 : 6)
            )
    }
}

extension View {
    func lootaGlassBackground(
        cornerRadius: CGFloat = 20,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18),
        elevated: Bool = false
    ) -> some View {
        modifier(LootaGlassBackground(cornerRadius: cornerRadius, padding: padding, elevated: elevated))
    }
}

// MARK: - Reusable Button Styles

struct LootaPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(LootaTheme.textPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LootaTheme.primaryButtonGradient)
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .shadow(color: LootaTheme.accentGlow.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LootaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(LootaTheme.textSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LootaTheme.inputBackground.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
