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
            // Background
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Celebration header
                VStack(spacing: 12) {
                    Text("🎉")
                        .font(.system(size: 80))
                    
                    Text("Totally Looted!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    if isWinner {
                        Text("Congratulations! You won!")
                            .font(.title2)
                            .foregroundColor(.green)
                    } else {
                        Text("Hunt Complete")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                // Winner information
                if isWinner {
                    WinnerContactCard(creatorContact: huntData.creatorContact)
                } else {
                    VStack(spacing: 12) {
                        Text("Better luck next time!")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if let winnerId = huntData.winnerId {
                            Text("Winner: \(winnerId)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Button("Back to Hunts") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
            }
            .padding()
            .multilineTextAlignment(.center)
        }
    }
}

struct WinnerContactCard: View {
    let creatorContact: CreatorContact?
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Contact Hunt Creator")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Reach out to collect your prize!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let contact = creatorContact {
                VStack(spacing: 12) {
                    if let name = contact.name {
                        Text("Creator: \(name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    // Show contact options based on creator's preference
                    if contact.preferred == "phone", let phone = contact.phone {
                        HStack(spacing: 12) {
                            Button(action: { 
                                UIApplication.makePhoneCall(phone) 
                            }) {
                                Label("Call", systemImage: "phone.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: { 
                                UIApplication.sendText(phone) 
                            }) {
                                Label("Text", systemImage: "message.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Text("Phone: \(phone.formattedPhoneNumber())")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if contact.preferred == "email", let email = contact.email {
                        Button(action: { 
                            UIApplication.sendEmail(email) 
                        }) {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                        
                        Text("Email: \(email)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Show both contact methods if no preference specified
                    if contact.preferred == nil {
                        VStack(spacing: 8) {
                            if let phone = contact.phone {
                                HStack(spacing: 12) {
                                    Button(action: { 
                                        UIApplication.makePhoneCall(phone) 
                                    }) {
                                        Label("Call", systemImage: "phone.fill")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                    
                                    Button(action: { 
                                        UIApplication.sendText(phone) 
                                    }) {
                                        Label("Text", systemImage: "message.fill")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                }
                                
                                Text("Phone: \(phone.formattedPhoneNumber())")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            if let email = contact.email {
                                Button(action: { 
                                    UIApplication.sendEmail(email) 
                                }) {
                                    Label("Email", systemImage: "envelope.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }
                                
                                Text("Email: \(email)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            } else {
                Text("Creator contact information not available")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
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
        VStack(spacing: 20) {
            // Hunt details
            VStack(alignment: .leading, spacing: 8) {
                Text("Hunt ID: \(huntData.id)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(huntData.pins.count) treasures to find")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            
            // Phone number input
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number Required")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Your phone number is needed for Apple Pay prize transfers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("(555) 123-4567", text: $participantPhone)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.phonePad)
                    .onChange(of: participantPhone) { _, newValue in
                        // Auto-format phone number as user types
                        participantPhone = newValue.formattedPhoneNumber()
                    }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Button("Join Hunt") {
                joinHunt()
            }
            .disabled(participantPhone.isEmpty || !participantPhone.isValidPhoneNumber() || isJoining)
            .buttonStyle(.borderedProminent)
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
        
        // Monitor join status
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let error = huntDataManager.errorMessage {
                showError(message: error)
                isJoining = false
            } else if huntDataManager.joinStatusMessage != nil {
                isJoining = false
                // Success - hunt joined
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