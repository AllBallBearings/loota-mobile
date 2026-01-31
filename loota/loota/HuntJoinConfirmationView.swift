// HuntJoinConfirmationView.swift

import Foundation
import SwiftUI

struct HuntJoinConfirmationView: View {
    let huntData: HuntData
    @Binding var isPresented: Bool

    let onConfirm: (String, String) -> Void
    let onCancel: () -> Void

    @State private var editingName: String = ""
    @State private var editingPhone: String = ""
    @State private var isJoining: Bool = false
    @State private var showingNameField: Bool = false
    @State private var showingPhoneField: Bool = false
    @FocusState private var focusedField: Field?

    enum Field {
        case name
        case phone
    }

    private let existingUserName: String?
    private let existingUserId: String?
    private let existingUserPhone: String?

    init(
        huntData: HuntData,
        existingUserName: String? = nil,
        existingUserId: String? = nil,
        existingUserPhone: String? = nil,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.huntData = huntData
        self.existingUserName = existingUserName
        self.existingUserId = existingUserId
        self.existingUserPhone = existingUserPhone
        self._isPresented = isPresented
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Background
            LootaTheme.backgroundGradient
                .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

            ScrollView {
                VStack(spacing: 20) {
                    // Header section
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(LootaTheme.accentGlow.opacity(0.15))
                                .frame(width: 72, height: 72)

                            Image(systemName: "map.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(LootaTheme.accentGradient)
                        }

                        Text("Join Hunt")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(LootaTheme.textPrimary)

                        Text(huntData.name ?? "Treasure Hunt")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(LootaTheme.highlight)
                            .multilineTextAlignment(.center)

                        if let description = huntData.description {
                            Text(description)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(LootaTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                    .padding(.top, 8)

                    // Stats row
                    HStack(spacing: 12) {
                        StatChip(
                            title: "Type",
                            value: huntData.type.rawValue.capitalized,
                            icon: "location.fill"
                        )
                        Spacer()
                        StatChip(
                            title: "Loot",
                            value: lootPinsDisplayValue,
                            icon: "diamond.fill"
                        )
                    }
                    .padding(.horizontal, 4)

                    // Divider
                    Rectangle()
                        .fill(LootaTheme.divider)
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // User information section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Details")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(LootaTheme.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(LootaTheme.textMuted)

                            if showingNameField {
                                HStack {
                                    TextField("Enter your name", text: $editingName)
                                        .focused($focusedField, equals: .name)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            showingNameField = false
                                            focusedField = nil
                                        }
                                        .foregroundColor(LootaTheme.textPrimary)

                                    Button(action: {
                                        showingNameField = false
                                        focusedField = nil
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(LootaTheme.success)
                                            .font(.system(size: 20))
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(LootaTheme.inputBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(LootaTheme.accentGlow.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            } else {
                                let displayName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                                HStack {
                                    Text(displayName.isEmpty ? "Anonymous" : displayName)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(LootaTheme.textPrimary)
                                    Spacer()
                                    Button("Edit") {
                                        showingNameField = true
                                        focusedField = .name
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LootaTheme.accentGlow)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(LootaTheme.inputBackground.opacity(0.5))
                                )
                            }
                        }

                        // Phone field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Phone Number")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(LootaTheme.textMuted)
                                Text("Required")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(LootaTheme.warning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(LootaTheme.warning.opacity(0.15))
                                    )
                            }

                            if showingPhoneField {
                                HStack {
                                    TextField("(555) 123-4567", text: $editingPhone)
                                        .focused($focusedField, equals: .phone)
                                        .keyboardType(.phonePad)
                                        .foregroundColor(LootaTheme.textPrimary)

                                    Button(action: {
                                        showingPhoneField = false
                                        focusedField = nil
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(LootaTheme.success)
                                            .font(.system(size: 20))
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(LootaTheme.inputBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(LootaTheme.accentGlow.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            } else {
                                let displayPhone = editingPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                                HStack {
                                    Text(displayPhone.isEmpty ? "Not provided" : formatPhoneNumber(displayPhone))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(displayPhone.isEmpty ? LootaTheme.textMuted : LootaTheme.textPrimary)
                                    Spacer()
                                    Button("Edit") {
                                        showingPhoneField = true
                                        focusedField = .phone
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LootaTheme.accentGlow)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(LootaTheme.inputBackground.opacity(0.5))
                                )
                            }
                        }

                        // User status
                        if existingUserId != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(LootaTheme.success)
                                Text("Returning user")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(LootaTheme.success)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(LootaTheme.textMuted)
                            Text("About Prizes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(LootaTheme.textMuted)
                        }

                        Text("Hunt creators may offer prizes at their discretion. By joining, you agree to share your contact info with the hunt creator.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(LootaTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LootaTheme.inputBackground.opacity(0.4))
                    )

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { joinHunt() }) {
                            HStack(spacing: 10) {
                                if isJoining {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 18))
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
                                    .opacity((isJoining || !isFormValid) ? 0.5 : 1.0)
                            )
                            .shadow(color: LootaTheme.accentGlow.opacity(0.25), radius: 12, x: 0, y: 6)
                        }
                        .disabled(isJoining || !isFormValid)

                        Button("Cancel") {
                            onCancel()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LootaTheme.textSecondary)
                        .padding(.vertical, 8)
                        .disabled(isJoining)
                    }
                    .padding(.top, 8)

                    // Hunt ID
                    Text("ID: \(String(huntData.id.prefix(8)).uppercased())")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(LootaTheme.textMuted.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(24)
                .lootaGlassBackground(cornerRadius: 24, elevated: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .foregroundColor(LootaTheme.accentGlow)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            editingName = existingUserName ?? ""
            editingPhone = existingUserPhone ?? ""
            showingNameField = (existingUserName == nil || existingUserName?.isEmpty == true || existingUserName == "Anonymous")
            showingPhoneField = (existingUserPhone == nil || existingUserPhone?.isEmpty == true)
        }
    }

    private var lootPinsDisplayValue: String {
        let totalPins = huntData.pins.count
        let lootTypeCounts = Dictionary(grouping: huntData.pins) { pin in
            pin.objectType ?? .coin
        }.mapValues { $0.count }

        if lootTypeCounts.count == 1, let (lootType, count) = lootTypeCounts.first {
            let pluralName = count == 1 ? lootType.displayName : pluralizeLootType(lootType)
            return "\(count) \(pluralName)"
        }

        return "\(totalPins)"
    }

    private func pluralizeLootType(_ type: ARObjectType) -> String {
        switch type {
        case .coin: return "Coins"
        case .giftCard: return "Gift Cards"
        case .dollarSign: return "Dollar Signs"
        case .none: return "Items"
        }
    }

    private var isFormValid: Bool {
        let name = finalName
        let phone = finalPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && isValidPhone(phone)
    }

    private var finalName: String {
        if showingNameField {
            let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Anonymous" : trimmed
        } else {
            return existingUserName ?? "Anonymous"
        }
    }

    private var finalPhone: String {
        if showingPhoneField {
            return editingPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return existingUserPhone ?? ""
        }
    }

    private func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return digits.count == 10
    }

    private func formatPhoneNumber(_ phone: String) -> String {
        let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard digits.count == 10 else { return phone }
        let area = String(digits.prefix(3))
        let exchange = String(digits.dropFirst(3).prefix(3))
        let number = String(digits.suffix(4))
        return "(\(area)) \(exchange)-\(number)"
    }

    private func joinHunt() {
        guard isFormValid else { return }
        isJoining = true
        let finalNameValue = finalName
        let finalPhoneValue = finalPhone
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onConfirm(finalNameValue, finalPhoneValue)
        }
    }
}

// MARK: - Supporting Components

private struct StatChip: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(LootaTheme.accentGlow)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(LootaTheme.textMuted)
                    .tracking(0.3)
            }
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LootaTheme.inputBackground.opacity(0.6))
        )
    }
}

#Preview {
    HuntJoinConfirmationView(
        huntData: HuntData(
            id: "test123",
            name: "Downtown Adventure Hunt",
            description: "Explore the heart of the city and discover hidden treasures around iconic landmarks!",
            type: .geolocation,
            winnerId: nil,
            createdAt: nil,
            updatedAt: nil,
            creatorId: nil,
            pins: [PinData](),
            isCompleted: false,
            completedAt: nil,
            participants: [],
            creator: nil,
            winner: nil,
            winnerContact: nil,
            creatorContact: nil
        ),
        existingUserName: "John Doe",
        existingUserId: "user123",
        existingUserPhone: "(555) 123-4567",
        isPresented: .constant(true),
        onConfirm: { name, phone in
            print("Confirmed: \(name), \(phone)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
