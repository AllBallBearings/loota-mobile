import SwiftUI

struct HuntCompletionView: View {
    let huntData: HuntData
    let currentUserId: String
    @Binding var isPresented: Bool

    private var isWinner: Bool {
        huntData.winnerId == currentUserId
    }

    private var hasLootedEverything: Bool {
        let userCollectedPins = huntData.pins.filter { $0.collectedByUserId == currentUserId }
        let remainingPins = huntData.pins.filter { $0.collectedByUserId == nil }
        return !userCollectedPins.isEmpty && remainingPins.isEmpty
    }

    var body: some View {
        ZStack {
            // Background
            LootaTheme.backgroundGradient
                .ignoresSafeArea()

            // Subtle ambient glow
            RadialGradient(
                gradient: Gradient(colors: [
                    LootaTheme.accentGlow.opacity(0.1),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()

            if hasLootedEverything && !(huntData.isCompleted ?? false) {
                EverythingsLootedView(huntData: huntData, currentUserId: currentUserId, isPresented: $isPresented)
            } else {
                completionCard
            }
        }
    }

    private var completionCard: some View {
        VStack(spacing: 28) {
            // Header with celebration icon
            VStack(spacing: 20) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(LootaTheme.accentGlow.opacity(0.12))
                        .frame(width: 100, height: 100)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LootaTheme.highlight.opacity(0.5),
                                    LootaTheme.accentGlow.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100, height: 100)

                    Text(isWinner ? "🏆" : "🎉")
                        .font(.system(size: 48))
                }

                VStack(spacing: 8) {
                    Text("Hunt Complete!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(LootaTheme.textPrimary)

                    if isWinner {
                        Text("Congratulations, you won!")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(LootaTheme.success)
                    } else {
                        Text("The hunt has ended")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(LootaTheme.textSecondary)
                    }
                }
            }

            // Contact card or results
            if isWinner {
                WinnerContactCard(creatorContact: huntData.creatorContact)
            } else {
                VStack(spacing: 12) {
                    Text("Better luck next time!")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(LootaTheme.textSecondary)

                    if let winnerName = huntData.winner?.name {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14))
                                .foregroundColor(LootaTheme.highlight)
                            Text("Winner: \(winnerName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(LootaTheme.textMuted)
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LootaTheme.inputBackground.opacity(0.5))
                )
            }

            // Back button
            Button(action: { isPresented = false }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LootaTheme.primaryButtonGradient)
                    )
                    .shadow(color: LootaTheme.accentGlow.opacity(0.25), radius: 10, x: 0, y: 5)
            }
        }
        .padding(28)
        .lootaGlassBackground(cornerRadius: 28, elevated: true)
        .padding(.horizontal, 24)
    }
}

// MARK: - Everything's Looted View

struct EverythingsLootedView: View {
    let huntData: HuntData
    let currentUserId: String
    @Binding var isPresented: Bool

    private var lootBreakdown: [(type: ARObjectType, count: Int)] {
        let userCollectedPins = huntData.pins.filter { $0.collectedByUserId == currentUserId }
        let grouped = Dictionary(grouping: userCollectedPins) { pin in
            pin.objectType ?? .coin
        }
        return grouped.map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.type.displayName < $1.type.displayName }
    }

    private var totalCollected: Int {
        huntData.pins.filter { $0.collectedByUserId == currentUserId }.count
    }

    private var creatorName: String {
        huntData.creator?.name ?? "the Hunt Creator"
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LootaTheme.highlight.opacity(0.12))
                        .frame(width: 88, height: 88)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LootaTheme.highlight.opacity(0.4),
                                    LootaTheme.accentGlow.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 88, height: 88)

                    Text("💰")
                        .font(.system(size: 40))
                }

                VStack(spacing: 6) {
                    Text("All Loot Collected!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(LootaTheme.textPrimary)

                    Text("You got everything!")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(LootaTheme.highlight)
                }
            }

            // Loot breakdown
            VStack(spacing: 14) {
                HStack {
                    Text("Your Loot")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(LootaTheme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(lootBreakdown, id: \.type) { item in
                        HStack {
                            Image(systemName: iconForType(item.type))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(LootaTheme.accentGlow)
                                .frame(width: 28)

                            Text(item.type.displayName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(LootaTheme.textPrimary)

                            Spacer()

                            Text("×\(item.count)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(LootaTheme.highlight)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LootaTheme.inputBackground.opacity(0.4))
                        )
                    }
                }

                // Total
                Rectangle()
                    .fill(LootaTheme.divider)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                HStack {
                    Text("Total")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LootaTheme.textPrimary)
                    Spacer()
                    Text("\(totalCollected)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(LootaTheme.highlight)
                }
                .padding(.horizontal, 4)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LootaTheme.inputBackground.opacity(0.5))
            )

            // Next steps
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(LootaTheme.textMuted)
                    Text("Next Steps")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(LootaTheme.textMuted)
                }

                Text("**\(creatorName)** will contact you to settle your loot.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LootaTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LootaTheme.inputBackground.opacity(0.3))
            )

            // Continue button
            Button(action: { isPresented = false }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LootaTheme.primaryButtonGradient)
                    )
                    .shadow(color: LootaTheme.accentGlow.opacity(0.25), radius: 10, x: 0, y: 5)
            }
        }
        .padding(24)
        .lootaGlassBackground(cornerRadius: 24, elevated: true)
        .padding(.horizontal, 20)
    }

    private func iconForType(_ type: ARObjectType) -> String {
        switch type {
        case .coin: return "bitcoinsign.circle.fill"
        case .dollarSign: return "dollarsign.circle.fill"
        case .giftCard: return "giftcard.fill"
        case .none: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Winner Contact Card

struct WinnerContactCard: View {
    let creatorContact: CreatorContact?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Claim Your Prize")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)

                Text("Contact the hunt creator")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LootaTheme.textSecondary)
            }

            if let contact = creatorContact {
                VStack(spacing: 12) {
                    if let name = contact.name {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 13))
                                .foregroundColor(LootaTheme.textMuted)
                            Text(name)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(LootaTheme.textPrimary)
                        }
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
                Text("Contact info not available")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(LootaTheme.textMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LootaTheme.success.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LootaTheme.success.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func phoneActions(phone: String) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ContactActionButton(
                    title: "Call",
                    systemImage: "phone.fill",
                    color: LootaTheme.success,
                    action: { UIApplication.makePhoneCall(phone) }
                )

                ContactActionButton(
                    title: "Text",
                    systemImage: "message.fill",
                    color: LootaTheme.neonCyan,
                    action: { UIApplication.sendText(phone) }
                )
            }

            Text(phone.formattedPhoneNumber())
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(LootaTheme.textMuted)
        }
    }

    @ViewBuilder
    private func emailAction(email: String) -> some View {
        VStack(spacing: 8) {
            ContactActionButton(
                title: "Email",
                systemImage: "envelope.fill",
                color: LootaTheme.warning,
                action: { UIApplication.sendEmail(email) }
            )

            Text(email)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(LootaTheme.textMuted)
        }
    }
}

// MARK: - Supporting Components

private struct ContactActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
            )
        }
    }
}

// MARK: - Join Hunt View

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
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LootaTheme.inputBackground.opacity(0.5))
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Phone Number")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(LootaTheme.textPrimary)

                Text("Required for prize transfers")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LootaTheme.textMuted)

                TextField("(555) 123-4567", text: $participantPhone)
                    .keyboardType(.phonePad)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LootaTheme.inputBackground)
                    )
                    .foregroundColor(LootaTheme.textPrimary)
                    .onChange(of: participantPhone) { newValue in
                        participantPhone = newValue.formattedPhoneNumber()
                    }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LootaTheme.inputBackground.opacity(0.5))
            )

            Button(action: { joinHunt() }) {
                HStack {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    }
                    Text(isJoining ? "Joining..." : "Join Hunt")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundColor(LootaTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LootaTheme.primaryButtonGradient)
                        .opacity(canJoin ? 1 : 0.5)
                )
            }
            .disabled(!canJoin || isJoining)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var canJoin: Bool {
        !participantPhone.isEmpty && participantPhone.isValidPhoneNumber()
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
