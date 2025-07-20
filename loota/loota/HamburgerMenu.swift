import SwiftUI

struct HamburgerMenu: View {
    @Binding var isShowingMenu: Bool
    @Binding var isShowingSurveyMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Menu")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowingMenu = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 15)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, 20)
            
            // Menu Items
            VStack(alignment: .leading, spacing: 0) {
                MenuItemView(
                    icon: "map",
                    title: "Survey Quest",
                    subtitle: "Track your route with elevation",
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowingMenu = false
                        }
                        // Small delay to allow menu to close before showing survey
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isShowingSurveyMode = true
                        }
                    }
                )
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                    .padding(.horizontal, 20)
                
                // Future menu items can be added here
                MenuItemView(
                    icon: "gearshape",
                    title: "Settings",
                    subtitle: "Coming soon",
                    action: {
                        // TODO: Implement settings
                    }
                )
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(width: 280)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.yellow)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HamburgerMenuButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "line.horizontal.3")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    HamburgerMenu(isShowingMenu: .constant(true), isShowingSurveyMode: .constant(false))
}