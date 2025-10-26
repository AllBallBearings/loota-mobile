import SwiftUI

struct SplashScreen: View {
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LootaTheme.backgroundGradient
            .ignoresSafeArea()
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.15), Color.clear]),
                center: .center,
                startRadius: 40,
                endRadius: 320
            )
            .blendMode(.screen)
            
            // Main content
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    LootaTheme.neonCyan.opacity(0.8),
                                    LootaTheme.cosmicPurple.opacity(0.8),
                                    LootaTheme.highlight.opacity(0.8),
                                    LootaTheme.neonCyan.opacity(0.8)
                                ]),
                                center: .center
                            ),
                            lineWidth: 6
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(rotation))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotation)
                        .blur(radius: 0.4)
                        .shadow(color: LootaTheme.accentGlow.opacity(0.4), radius: 16, x: 0, y: 0)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LootaTheme.cosmicPurple.opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 120
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isAnimating)
                    
                    // Loota text with glow effect
                    Text("Loota")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: LootaTheme.cosmicPurple.opacity(0.9), radius: 24, x: 0, y: 0)
                        .shadow(color: .white.opacity(0.35), radius: 16, x: 0, y: 0)
                        .scaleEffect(isAnimating ? 1.06 : 1.0)
                        .opacity(textOpacity)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // Subtitle
                Text("AR Treasure Hunt")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(LootaTheme.textSecondary)
                    .opacity(textOpacity)
                
                Text("Find. Collect. Celebrate.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.neonCyan.opacity(0.9))
                    .opacity(textOpacity)
                
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 140, height: 5)
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [LootaTheme.neonCyan, LootaTheme.cosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: isAnimating ? 110 : 60, height: 5)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isAnimating)
                    )
            }
        }
        .onAppear {
            // Animate text appearance
            withAnimation(.easeIn(duration: 1.0)) {
                textOpacity = 1.0
            }
            
            // Start pulsing animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            
            withAnimation(.easeIn(duration: 0.5)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    SplashScreen()
}
