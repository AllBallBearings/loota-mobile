import SwiftUI

struct HuntCompletionView: View {
    let huntData: HuntData
    let currentUserId: String
    @Binding var isPresented: Bool
    
    private var isWinner: Bool {
        huntData.winnerId == currentUserId
    }
    
    var body: some View {
        ZStack {
            LootaTheme.backgroundGradient
                .ignoresSafeArea()
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]),
                center: .center,
                startRadius: 80,
                endRadius: 480
            )
            .blendMode(.screen)
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        LootaTheme.neonCyan,
                                        LootaTheme.cosmicPurple,
                                        LootaTheme.highlight,
                                        LootaTheme.neonCyan
                                    ]),
                                    center: .center
                                ),
                                lineWidth: 6
                            )
                            .frame(width: 116, height: 116)
                            .shadow(color: LootaTheme.accentGlow.opacity(0.45), radius: 18, x: 0, y: 10)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.18), Color.clear],
                                    center: .center,
                                    startRadius: 6,
                                    endRadius: 84
                                )
                            )
                            .frame(width: 98, height: 98)
                        Text("🎉")
                            .font(.system(size: 64))
                    }
                    
                    Text("Totally Looted!")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(LootaTheme.highlight)
                    
                    if isWinner {
                        Text("Congratulations! You won!")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(LootaTheme.success)
                    } else {
                        Text("Hunt Complete")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(LootaTheme.neonCyan)
                    }
                }
                .multilineTextAlignment(.center)
                
                if isWinner {
                    WinnerContactCard(creatorContact: huntData.creatorContact)
                } else {
                    VStack(spacing: 10) {
                        Text("Better luck next time!")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(LootaTheme.textSecondary)
                        
                        if let winnerId = huntData.winnerId {
                            Text("Winner: \(winnerId)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(LootaTheme.textMuted)
                        }
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Back to Hunts")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 34)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [LootaTheme.cosmicPurple, LootaTheme.neonCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(22)
                        .shadow(color: LootaTheme.cosmicPurple.opacity(0.4), radius: 14, x: 0, y: 10)
                }
                .padding(.top, 8)
            }
            .lootaGlassBackground(
                cornerRadius: 36,
                padding: EdgeInsets(top: 32, leading: 30, bottom: 34, trailing: 30)
            )
            .padding(.horizontal, 24)
        }
    }
}

struct WinnerContactCard: View {
    let creatorContact: CreatorContact?
    
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Contact Hunt Creator")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)
                
                Text("Reach out to collect your prize!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(LootaTheme.textSecondary)
            }
            
            if let contact = creatorContact {
                VStack(spacing: 14) {
                    if let name = contact.name {
                        Text("Creator: \(name)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(LootaTheme.textPrimary)
                    }
                    
                    if contact.preferred == "phone", let phone = contact.phone {
                        phoneActions(phone: phone)
                    }
                    
                    if contact.preferred == "email", let email = contact.email {
                        emailAction(email: email)
                    }
                    
                    if contact.preferred == nil {
                        if let phone = contact.phone {
                            phoneActions(phone: phone)
                        }
                        if let email = contact.email {
                            emailAction(email: email)
                        }
                    }
                }
            } else {
                Text("Creator contact information not available")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func phoneActions(phone: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ContactActionButton(
                    title: "Call",
                    systemImage: "phone.fill",
                    colors: [LootaTheme.success, LootaTheme.neonCyan],
                    action: { UIApplication.makePhoneCall(phone) }
                )
                
                ContactActionButton(
                    title: "Text",
                    systemImage: "message.fill",
                    colors: [LootaTheme.neonCyan, LootaTheme.cosmicPurple],
                    action: { UIApplication.sendText(phone) }
                )
            }
            
            Text("Phone: \(phone.formattedPhoneNumber())")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textMuted)
        }
    }
    
    @ViewBuilder
    private func emailAction(email: String) -> some View {
        VStack(spacing: 6) {
            ContactActionButton(
                title: "Email",
                systemImage: "envelope.fill",
                colors: [LootaTheme.warning, LootaTheme.cosmicPurple],
                action: { UIApplication.sendEmail(email) }
            )
            
            Text("Email: \(email)")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textMuted)
        }
    }
}

struct JoinHuntView: View {
    let huntData: HuntData
    @State private var participantPhone: String = ""
    @State private var isJoining: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @ObservedObject private var huntDataManager = HuntDataManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hunt ID: \(huntData.id)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)
                
                Text("\(huntData.pins.count) treasures to find")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(LootaTheme.textSecondary)
            }
            .lootaGlassBackground(
                cornerRadius: 26,
                padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Phone Number Required")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)
                
                Text("Your phone number is needed for Apple Pay prize transfers")
                    .font(.caption)
                    .foregroundColor(LootaTheme.textSecondary)
                
                TextField("(555) 123-4567", text: $participantPhone)
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .foregroundColor(LootaTheme.textPrimary)
                    .onChange(of: participantPhone) { _, newValue in
                        participantPhone = newValue.formattedPhoneNumber()
                    }
            }
            .lootaGlassBackground(
                cornerRadius: 26,
                padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
            )
            
            Button(action: {
                joinHunt()
            }) {
                Text(isJoining ? "Joining Hunt..." : "Join Hunt")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [LootaTheme.neonCyan, LootaTheme.cosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: LootaTheme.neonCyan.opacity(0.3), radius: 12, x: 0, y: 8)
            }
            .disabled(participantPhone.isEmpty || !participantPhone.isValidPhoneNumber() || isJoining)
            .opacity((participantPhone.isEmpty || !participantPhone.isValidPhoneNumber() || isJoining) ? 0.6 : 1.0)
            
            if isJoining {
                ProgressView("Joining hunt...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func joinHunt() {
        guard participantPhone.isValidPhoneNumber() else {
            showError(message: "Please enter a valid phone number")
            return
        }
        
        isJoining = true
        
        huntDataManager.joinHunt(huntId: huntData.id, phoneNumber: participantPhone)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let error = huntDataManager.errorMessage {
                showError(message: error)
                isJoining = false
            } else if huntDataManager.joinStatusMessage != nil {
                isJoining = false
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

private struct ContactActionButton: View {
    let title: String
    let systemImage: String
    let colors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
    }
}

#Preview {
    let sampleHunt = HuntData(
        id: "sample",
        name: "Sample Hunt",
        description: "A sample treasure hunt for preview",
        type: .geolocation,
        winnerId: "user123",
        createdAt: nil,
        updatedAt: nil,
        creatorId: nil,
        pins: [],
        isCompleted: true,
        completedAt: "2024-01-01",
        participants: [],
        creator: nil,
        winner: nil,
        winnerContact: WinnerContact(name: "John Doe", phone: "5551234567"),
        creatorContact: CreatorContact(name: "Jane Smith", preferred: "phone", phone: "5559876543", email: "jane@example.com")
    )
    
    HuntCompletionView(huntData: sampleHunt, currentUserId: "user123", isPresented: .constant(true))
}
