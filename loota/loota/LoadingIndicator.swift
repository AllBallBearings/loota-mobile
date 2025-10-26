import SwiftUI

struct LoadingIndicator: View {
    @State private var isAnimating = false
    @State private var rotationAngle = 0.0

    let message: String
    let showProgress: Bool
    let subtitle: String?

    init(message: String = "Initializing Hunt...", showProgress: Bool = true, subtitle: String? = nil) {
        self.message = message
        self.showProgress = showProgress
        self.subtitle = subtitle
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            LootaTheme.backgroundGradient
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Spinner or progress indicator
                if showProgress {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 3)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .trim(from: 0.08, to: 0.92)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        LootaTheme.neonCyan,
                                        LootaTheme.cosmicPurple,
                                        LootaTheme.highlight,
                                        LootaTheme.neonCyan
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(rotationAngle))
                        
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        LootaTheme.cosmicPurple.opacity(0.5),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 36
                                )
                            )
                            .frame(width: 54, height: 54)
                    }
                    .shadow(color: LootaTheme.accentGlow.opacity(0.4), radius: 16, x: 0, y: 6)
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: rotationAngle)
                }
                
                // Loading message
                Text(message)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                // Optional subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LootaTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .lootaGlassBackground(
                cornerRadius: 32,
                padding: EdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
            )
        }
        .onAppear {
            withAnimation {
                isAnimating = true
                rotationAngle = 360.0
            }
        }
    }
}

#Preview {
    LoadingIndicator()
}
