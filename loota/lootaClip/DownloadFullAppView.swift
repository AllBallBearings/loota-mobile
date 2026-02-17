import StoreKit
import SwiftUI

struct DownloadFullAppView: View {
  @State private var showOverlay = false

  var body: some View {
    ZStack {
      LootaTheme.backgroundGradient
        .ignoresSafeArea()

      VStack(spacing: 32) {
        Spacer()

        // Celebration icon
        ZStack {
          Circle()
            .fill(LootaTheme.accentGradient)
            .frame(width: 120, height: 120)
            .shadow(color: LootaTheme.accentGlow.opacity(0.7), radius: 24, x: 0, y: 12)
          Image(systemName: "star.fill")
            .font(.system(size: 52, weight: .bold))
            .foregroundColor(.white)
        }

        VStack(spacing: 12) {
          Text("You're a Natural!")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundColor(LootaTheme.highlight)
            .multilineTextAlignment(.center)

          Text("You've completed your free App Clip hunts. Download the full Loota app for unlimited treasure hunting!")
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(LootaTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }

        // Benefits list
        VStack(alignment: .leading, spacing: 16) {
          benefitRow(icon: "infinity", text: "Unlimited treasure hunts")
          benefitRow(icon: "wand.and.stars", text: "Full spell-casting summoning")
          benefitRow(icon: "trophy.fill", text: "Compete for prizes")
          benefitRow(icon: "person.2.fill", text: "Join hunts with friends")
        }
        .padding(.horizontal, 32)

        Spacer()

        // Download button
        Button(action: {
          showOverlay = true
        }) {
          HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
              .font(.title2)
            Text("Get the Full App")
              .font(.system(size: 18, weight: .bold, design: .rounded))
          }
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [LootaTheme.cosmicPurple, LootaTheme.neonCyan],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
          )
          .shadow(color: LootaTheme.cosmicPurple.opacity(0.5), radius: 16, x: 0, y: 8)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 48)
      }
    }
    .onAppear {
      presentAppStoreOverlay()
    }
    .onChange(of: showOverlay) { newValue in
      if newValue {
        presentAppStoreOverlay()
      }
    }
  }

  private func benefitRow(icon: String, text: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 20, weight: .semibold))
        .foregroundColor(LootaTheme.neonCyan)
        .frame(width: 32)
      Text(text)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundColor(LootaTheme.textPrimary)
    }
  }

  private func presentAppStoreOverlay() {
    guard let windowScene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first
    else { return }

    let config = SKOverlay.AppClipConfiguration(position: .bottom)
    let overlay = SKOverlay(configuration: config)
    overlay.present(in: windowScene)
  }
}
