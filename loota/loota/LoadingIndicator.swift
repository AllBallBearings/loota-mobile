import SwiftUI

struct LoadingIndicator: View {
    @State private var isAnimating = false
    @State private var rotationAngle = 0.0
    @State private var pulseScale = 1.0

    let message: String
    let showProgress: Bool
    let subtitle: String?

    init(message: String = "Loading...", showProgress: Bool = true, subtitle: String? = nil) {
        self.message = message
        self.showProgress = showProgress
        self.subtitle = subtitle
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 28) {
                // Refined spinner
                if showProgress {
                    ZStack {
                        // Track circle
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 56, height: 56)

                        // Animated arc
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        LootaTheme.accentGlow,
                                        LootaTheme.highlight.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(rotationAngle))

                        // Center pulse
                        Circle()
                            .fill(LootaTheme.accentGlow.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .scaleEffect(pulseScale)
                    }
                }

                // Message text
                VStack(spacing: 8) {
                    Text(message)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(LootaTheme.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(LootaTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .lootaGlassBackground(cornerRadius: 24, elevated: true)
        }
        .onAppear {
            // Rotation animation
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360.0
            }

            // Pulse animation
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }

            isAnimating = true
        }
    }
}

#Preview {
    LoadingIndicator(
        message: "Joining Hunt...",
        subtitle: "Preparing your adventure"
    )
}
