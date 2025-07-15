import SwiftUI

struct SplashScreen: View {
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.purple.opacity(0.8),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 20) {
                // Loota text with glow effect
                Text("Loota")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.8), radius: 20, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.6), radius: 10, x: 0, y: 0)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // Subtitle
                Text("AR Treasure Hunt")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(textOpacity)
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
        }
    }
}

#Preview {
    SplashScreen()
}