// HuntJoinConfirmationView.swift

import SwiftUI
import Foundation

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
    
    // Initialize with existing user data
    private let existingUserName: String?
    private let existingUserId: String?
    private let existingUserPhone: String?
    
    init(huntData: HuntData, 
         existingUserName: String? = nil, 
         existingUserId: String? = nil,
         existingUserPhone: String? = nil,
         isPresented: Binding<Bool>,
         onConfirm: @escaping (String, String) -> Void,
         onCancel: @escaping () -> Void) {
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
            // Dark background
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Prevent dismissal on background tap
                }
            
            VStack(spacing: 20) {
                // Hunt Information Header
                VStack(spacing: 12) {
                    Text("Join Hunt?")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text(huntData.name ?? "Treasure Hunt")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                    
                    if let description = huntData.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    
                    HStack {
                        VStack {
                            Text("Type")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(huntData.type.rawValue.capitalized)
                                .font(.body.bold())
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Treasure Pins")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(huntData.pins.count)")
                                .font(.body.bold())
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Hunt ID")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(String(huntData.id.prefix(8)))
                                .font(.body.bold())
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                // User Information Section
                VStack(spacing: 16) {
                    Text("Your Information")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Name:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            if !showingNameField {
                                Button("Edit") {
                                    showingNameField = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        if showingNameField {
                            TextField("Enter your name", text: $editingName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .background(Color.white)
                                .cornerRadius(8)
                        } else {
                            Text(existingUserName ?? "Anonymous")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                                .onTapGesture {
                                    showingNameField = true
                                }
                        }
                    }
                    
                    // Phone Number Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Phone Number:")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("(Required for Apple Pay prize transfers)")
                                    .font(.caption2)
                                    .foregroundColor(.yellow.opacity(0.8))
                            }
                            Spacer()
                            if !showingPhoneField {
                                Button("Edit") {
                                    showingPhoneField = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        if showingPhoneField {
                            TextField("(555) 123-4567", text: $editingPhone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                                .background(Color.white)
                                .cornerRadius(8)
                        } else {
                            let displayPhone = existingUserPhone ?? editingPhone
                            Text(displayPhone.isEmpty ? "Not provided" : formatPhoneNumber(displayPhone))
                                .font(.body)
                                .foregroundColor(displayPhone.isEmpty ? .white.opacity(0.5) : .white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                                .onTapGesture {
                                    showingPhoneField = true
                                }
                        }
                    }
                    
                    if existingUserId != nil {
                        Text("✓ Existing user - your data will be updated")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("New user - account will be created")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
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
                                gradient: Gradient(colors: [.green, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .disabled(isJoining || !isFormValid)
                        .opacity((isJoining || !isFormValid) ? 0.6 : 1.0)
                    }
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .disabled(isJoining)
                }
            }
            .padding(24)
            .frame(maxWidth: 400)
        }
        .onAppear {
            print("DEBUG: HuntJoinConfirmationView - onAppear: Hunt Name: '\(huntData.name ?? "nil")'")
            print("DEBUG: HuntJoinConfirmationView - onAppear: Existing User Name: '\(existingUserName ?? "nil")'")
            print("DEBUG: HuntJoinConfirmationView - onAppear: Existing User Phone: '\(existingUserPhone ?? "nil")'")
            print("DEBUG: HuntJoinConfirmationView - onAppear: Existing User ID: '\(existingUserId ?? "nil")'")
            
            // Pre-fill with existing data
            editingName = existingUserName ?? ""
            editingPhone = existingUserPhone ?? ""
            
            // Show fields that need to be filled
            showingNameField = (existingUserName == nil || existingUserName?.isEmpty == true || existingUserName == "Anonymous")
            showingPhoneField = (existingUserPhone == nil || existingUserPhone?.isEmpty == true)
            
            print("DEBUG: HuntJoinConfirmationView - onAppear: Will show name field: \(showingNameField)")
            print("DEBUG: HuntJoinConfirmationView - onAppear: Will show phone field: \(showingPhoneField)")
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