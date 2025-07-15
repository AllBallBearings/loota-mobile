import SwiftUI

struct LoadingIndicator: View {
    @State private var isAnimating = false
    @State private var rotationAngle = 0.0
    
    let message: String
    let showProgress: Bool
    
    init(message: String = "Initializing Hunt...", showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Spinner or progress indicator
                if showProgress {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        // Animated ring
                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple, .white, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(rotationAngle))
                            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
                    }
                }
                
                // Loading message
                Text(message)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                // Optional subtitle
                Text("Please wait while we prepare your adventure")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
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