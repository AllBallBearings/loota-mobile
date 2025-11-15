// HuntJoinConfirmationView.swift

import Foundation
import SwiftUI

struct HuntJoinConfirmationView: View {
  let huntData: HuntData
  @Binding var isPresented: Bool

  let onConfirm: (String, String) -> Void
  let onCancel: () -> Void

  // User data from HuntDataManager
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

  // Initialize with existing user data
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
      // Darkened glassy backdrop
      LootaTheme.backgroundGradient
        .ignoresSafeArea()
      Color.black.opacity(0.55)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
          // Dismiss keyboard when tapping backdrop
          focusedField = nil
        }

      ScrollView {
        VStack(spacing: 24) {
        // Hunt Information Header
        VStack(spacing: 16) {
          Text("Join Hunt?")
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundColor(LootaTheme.textPrimary)

          Text(huntData.name ?? "Treasure Hunt")
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(LootaTheme.highlight)
            .multilineTextAlignment(.center)

          if let description = huntData.description {
            Text(description)
              .font(.system(size: 16, weight: .regular, design: .rounded))
              .foregroundColor(LootaTheme.textSecondary)
              .multilineTextAlignment(.center)
              .lineLimit(3)
          }

          HStack {
            StatChip(title: "Type", value: huntData.type.rawValue.capitalized, icon: "map")

            Spacer()

            StatChip(title: "Loot Pins", value: lootPinsDisplayValue, icon: "diamond.fill")
          }

          // Hunt ID as fine print
          Text("Hunt ID: \(String(huntData.id.prefix(8)).uppercased())")
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundColor(LootaTheme.textSecondary.opacity(0.6))
            .padding(.top, 4)
        }
        .lootaGlassBackground(
          cornerRadius: 28,
          padding: EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22)
        )

        // User Information Section
        VStack(spacing: 20) {
          Text("Your Information")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(LootaTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          // Name Section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Name")
                .font(.caption)
                .foregroundColor(LootaTheme.textSecondary)
                .textCase(.uppercase)
              Spacer()
              if !showingNameField {
                Button("Edit") {
                  showingNameField = true
                }
                .font(.caption)
                .foregroundColor(LootaTheme.neonCyan)
              }
            }

            if showingNameField {
              TextField("Enter your name", text: $editingName)
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit {
                  showingNameField = false
                  focusedField = nil
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                      RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                )
                .foregroundColor(LootaTheme.textPrimary)
            } else {
              let displayName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
              Text(displayName.isEmpty ? "Anonymous" : displayName)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                )
                .onTapGesture {
                  showingNameField = true
                  focusedField = .name
                }
            }
          }

          // Phone Number Section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading) {
                Text("Phone Number")
                  .font(.caption)
                  .foregroundColor(LootaTheme.textSecondary)
                  .textCase(.uppercase)
                Text("(Required to claim Loot)")
                  .font(.caption2)
                  .foregroundColor(LootaTheme.highlight.opacity(0.9))
              }
              Spacer()
              if !showingPhoneField {
                Button("Edit") {
                  showingPhoneField = true
                }
                .font(.caption)
                .foregroundColor(LootaTheme.neonCyan)
              }
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
                    .font(.title3)
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(Color.white.opacity(0.08))
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(Color.white.opacity(0.12), lineWidth: 1)
                  )
              )
            } else {
              let displayPhone = editingPhone.trimmingCharacters(in: .whitespacesAndNewlines)
              Text(displayPhone.isEmpty ? "Not provided" : formatPhoneNumber(displayPhone))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(
                  displayPhone.isEmpty
                    ? LootaTheme.textSecondary
                    : LootaTheme.textPrimary
                )
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                )
                .onTapGesture {
                  showingPhoneField = true
                  focusedField = .phone
                }
            }
          }

          if existingUserId != nil {
            Text("✓ Existing user - your data will be updated")
              .font(.caption)
              .foregroundColor(LootaTheme.success)
          } else {
            Text("New user - account will be created")
              .font(.caption)
              .foregroundColor(LootaTheme.neonCyan)
          }
        }
        .lootaGlassBackground(
          cornerRadius: 28,
          padding: EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
        )

        // Prize Disclaimer
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(LootaTheme.warning)
              .font(.caption)
            Text("Prize Disclaimer")
              .font(.caption.bold())
              .foregroundColor(LootaTheme.warning)
          }

          Text(
            "Hunt creators may offer prizes at their discretion. Loota does not guarantee prizes or handle prize fulfillment. By joining, you agree to share your contact information with the hunt creator for communication purposes only."
          )
          .font(.caption2)
          .foregroundColor(LootaTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.orange.opacity(0.18))
            .overlay(
              RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )

        // Action buttons
        VStack(spacing: 12) {
          Button(action: {
            joinHunt()
          }) {
            HStack {
              if isJoining {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "location.fill")
              }
              Text(isJoining ? "Joining Hunt..." : "Join Hunt")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              LinearGradient(
                colors: [LootaTheme.neonCyan, LootaTheme.cosmicPurple],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .cornerRadius(18)
            .shadow(color: LootaTheme.neonCyan.opacity(0.4), radius: 12, x: 0, y: 8)
            .disabled(isJoining || !isFormValid)
            .opacity((isJoining || !isFormValid) ? 0.6 : 1.0)
          }

          Button("Cancel") {
            onCancel()
          }
          .font(.body)
          .foregroundColor(LootaTheme.textSecondary)
          .disabled(isJoining)
        }
        }
        .padding(24)
        .frame(maxWidth: 440)
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          focusedField = nil
        }
        .foregroundColor(LootaTheme.neonCyan)
        .fontWeight(.semibold)
      }
    }
    .onAppear {
      print("DEBUG: HuntJoinConfirmationView - onAppear: Hunt Name: '\(huntData.name ?? "nil")'")
      print(
        "DEBUG: HuntJoinConfirmationView - onAppear: Existing User Name: '\(existingUserName ?? "nil")'"
      )
      print(
        "DEBUG: HuntJoinConfirmationView - onAppear: Existing User Phone: '\(existingUserPhone ?? "nil")'"
      )
      print(
        "DEBUG: HuntJoinConfirmationView - onAppear: Existing User ID: '\(existingUserId ?? "nil")'"
      )

      // Pre-fill with existing data
      editingName = existingUserName ?? ""
      editingPhone = existingUserPhone ?? ""

      // Show fields that need to be filled
      showingNameField =
        (existingUserName == nil || existingUserName?.isEmpty == true
          || existingUserName == "Anonymous")
      showingPhoneField = (existingUserPhone == nil || existingUserPhone?.isEmpty == true)

      print("DEBUG: HuntJoinConfirmationView - onAppear: Will show name field: \(showingNameField)")
      print(
        "DEBUG: HuntJoinConfirmationView - onAppear: Will show phone field: \(showingPhoneField)")
    }
  }

  private var lootPinsDisplayValue: String {
    let totalPins = huntData.pins.count

    // Count pins by loot type
    let lootTypeCounts = Dictionary(grouping: huntData.pins) { pin in
      pin.objectType ?? .coin  // Default to coin if no type specified
    }.mapValues { $0.count }

    // If all pins are the same type, show count + type
    if lootTypeCounts.count == 1, let (lootType, count) = lootTypeCounts.first {
      let pluralName = count == 1 ? lootType.displayName : pluralizeLootType(lootType)
      return "\(count) \(pluralName)"
    }

    // If mixed types, just show total count
    return "\(totalPins)"
  }

  private func pluralizeLootType(_ type: ARObjectType) -> String {
    switch type {
    case .coin:
      return "Coins"
    case .giftCard:
      return "Gift Cards"
    case .dollarSign:
      return "Dollar Signs"
    case .none:
      return "Items"
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
    // Remove all non-digit characters
    let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    // Check if it has exactly 10 digits
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

    // Give immediate feedback and then call the confirmation handler
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      onConfirm(finalNameValue, finalPhoneValue)
    }
  }
}

#Preview {
  HuntJoinConfirmationView(
    huntData: HuntData(
      id: "test123",
      name: "Downtown Adventure Hunt",
      description:
        "Explore the heart of the city and discover hidden treasures around iconic landmarks!",
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

private struct StatChip: View {
  let title: String
  let value: String
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption.weight(.bold))
          .foregroundColor(LootaTheme.neonCyan)
        Text(title.uppercased())
          .font(.caption2)
          .foregroundColor(LootaTheme.textSecondary)
      }
      Text(value)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundColor(LootaTheme.textPrimary)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color.white.opacity(0.08))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    )
  }
}
