import SwiftUI

struct SplashScreen: View {
    @State private var isAnimating = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.85
    @State private var subtitleOpacity = 0.0
    @State private var ringRotation = 0.0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        ZStack {
            // Rich dark background
            LootaTheme.backgroundGradient
                .ignoresSafeArea()

            // Subtle radial warmth
            RadialGradient(
                gradient: Gradient(colors: [
                    LootaTheme.accentGlow.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 60,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo container
                ZStack {
                    // Outer decorative ring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LootaTheme.accentGlow.opacity(0.4),
                                    LootaTheme.accentGlow.opacity(0.1),
                                    LootaTheme.accentGlow.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(ringRotation))

                    // Inner glow circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LootaTheme.accentGlow.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 70
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.05 : 0.95)

                    // Main logo text
                    Text("Loota")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    LootaTheme.textPrimary,
                                    LootaTheme.highlight
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: LootaTheme.accentGlow.opacity(0.4), radius: 20, x: 0, y: 0)
                        .overlay(
                            // Shimmer effect
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 60)
                                .offset(x: shimmerOffset)
                                .mask(
                                    Text("Loota")
                                        .font(.system(size: 52, weight: .bold, design: .rounded))
                                )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                // Subtitle section
                VStack(spacing: 10) {
                    Text("Treasure Hunt")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(LootaTheme.textSecondary)
                        .tracking(2)

                    Text("Discover  ·  Collect  ·  Win")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LootaTheme.textMuted)
                        .tracking(1)
                }
                .opacity(subtitleOpacity)

                // Loading indicator
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [LootaTheme.accentGlow, LootaTheme.highlight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: isAnimating ? 90 : 40, height: 4)
                        .frame(maxWidth: 120, alignment: .leading)
                }
                .padding(.top, 8)
                .opacity(subtitleOpacity)
            }
        }
        .onAppear {
            // Staggered animations for premium feel
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                subtitleOpacity = 1.0
            }

            // Continuous subtle animations
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }

            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }

            // Shimmer animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.5)) {
                shimmerOffset = 200
            }
        }
    }
}

#Preview {
    SplashScreen()
}
