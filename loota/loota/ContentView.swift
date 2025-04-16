// ContentView.swift

import SwiftUI

enum ARObjectType: String, CaseIterable, Identifiable {
    case none = "None"
    case coin = "Coin"
    case dollarSign = "Dollar Sign"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @State private var coinsCollected: Int = 0
    @State private var animate: Bool = false
    @State private var selectedObject: ARObjectType = .none
    @State private var distanceInFeet: Float = 5.0 // Initial distance (matches ARViewContainer)
    @State private var heightInFeet: Float = 1.0   // Initial height (matches ARViewContainer)

    // Helper to format float values
    private func formatFloat(_ value: Float) -> String {
        String(format: "%.1f", value)
    }

    var body: some View {
        ZStack { // Main container ZStack
            // AR View in the background
            if selectedObject != .none {
                ARViewContainer(
                    distanceInFeet: $distanceInFeet, // Pass binding
                    heightInFeet: $heightInFeet,   // Pass binding
                    onCoinCollected: {
                        coinsCollected += 1
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
                            animate = true
                        }
                        // Reset animation after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            animate = false
                        }
                    },
                    objectType: selectedObject
                )
                .id(selectedObject) // Recreate only when object type changes
                .edgesIgnoringSafeArea(.all)
            } else {
                 // Placeholder when no object is selected
                 Color.gray.edgesIgnoringSafeArea(.all)
                 Text("Select an object type")
                     .foregroundColor(.white)
                     .font(.title)
            }

            // UI Overlay VStack
            VStack {
                // Top Row: Counter and Picker
                HStack(alignment: .top) {
                    // Animated counter in top left
                    ZStack {
                Text("\(coinsCollected)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .yellow.opacity(0.7), radius: animate ? 16 : 4)
                    .scaleEffect(animate ? 1.4 : 1.0)
                    .opacity(animate ? 1.0 : 0.85)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animate)
                    }
                    .padding([.top, .leading], 16)

                    Spacer() // Pushes picker to the right

                    // Picker for object type
                    Picker("Object", selection: $selectedObject) {
                        ForEach(ARObjectType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    } // <<< Picker ends here
                    .pickerStyle(SegmentedPickerStyle()) // Apply modifiers to Picker
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .frame(maxWidth: 250) // Limit picker width
                    .padding([.top, .trailing], 16)
                } // <<< HStack ends here (Correct position)
                .padding(.bottom, 20) // Add padding below top controls

                Spacer() // Pushes sliders to bottom/right

                // Bottom/Right Sliders
                HStack {
                    // Bottom Distance Slider
                    VStack {
                        Slider(value: $distanceInFeet, in: 2...30, step: 0.5)
                            .padding(.horizontal)
                        Text("Distance: \(formatFloat(distanceInFeet)) ft")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                    }
                    .padding(.horizontal)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.leading)
                    .padding(.bottom)

                    // Right Height Slider (Rotated)
                    VStack {
                         Slider(value: $heightInFeet, in: 0...10, step: 0.5)
                             .rotationEffect(.degrees(-90))
                             .frame(width: 150) // Adjust width for rotated slider height
                         Text("Height: \(formatFloat(heightInFeet)) ft")
                             .font(.caption)
                             .foregroundColor(.white)
                             .padding(.trailing, 5) // Adjust text position
                     }
                     .frame(width: 60) // Container width for rotated slider + text
                     .padding(.vertical, 20) // Padding inside the Vstack
                     .background(Color.black.opacity(0.6))
                     .cornerRadius(10)
                     .padding(.trailing)
                     .padding(.bottom) // Align bottom with distance slider
                }
            } // End UI Overlay VStack
        } // End Main ZStack
    }
}
