// ContentView.swift

import SwiftUI
import RealityKit   // <-- Add this import
import ARKit        // <-- Add this import

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
    // Removed map-related state variables
    @State private var arViewRef: ARView? = nil // Reference to ARView for screen projection
    @State private var objectDistances: [UUID: Float] = [:] // Store distances keyed by Anchor ID

    var body: some View {
        ZStack { // Main container ZStack
            // AR View in the background
            ARViewContainer(
                // Removed pinLocations binding
                arViewRef: $arViewRef, // Pass ARView reference binding
                onCoinCollected: { // Keep existing callback
                    coinsCollected += 1
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
                            animate = true
                        }
                        // Reset animation after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            animate = false
                        }
                    },
                onDistanceUpdate: { distances in // Add the new callback
                        // Update the state variable when distances are received
                        self.objectDistances = distances
                    },
                    objectType: selectedObject
                )
                // Use object type for ID
                .id(selectedObject)
                .edgesIgnoringSafeArea(.all)
            // } else { // Keep ARView always visible
            //     // Placeholder when no object is selected (or no pins placed?)
            //      Color.gray.edgesIgnoringSafeArea(.all)
            //      Text("Select an object type and place pins")
            //          .foregroundColor(.white)
            //          .font(.title)
            // } // Let's keep the AR view active and rely on ARViewContainer to handle no pins

            // Show placeholder text if no object is selected
            if selectedObject == .none {
                 Color.gray.opacity(0.7).edgesIgnoringSafeArea(.all) // Semi-transparent overlay
                 Text("Select an object type")
                     .foregroundColor(.white)
                     .font(.title)
                     .padding()
                     .background(Color.black.opacity(0.5))
                     .cornerRadius(10)
            }
            // Removed placeholder text for placing pins


            // --- Distance Overlay ---
            if let arView = arViewRef {
                // Iterate through the anchors currently managed by the Coordinator
                // Use the objectDistances dictionary which is updated by the Coordinator
                ForEach(Array(objectDistances.keys), id: \.self) { anchorID in
                    // Find the anchor in the scene using its ID
                    if let anchor = arView.scene.anchors.first(where: { $0.id == anchorID }),
                       let distance = objectDistances[anchorID] { // Get distance from state
                        
                        let worldPosition = anchor.position(relativeTo: nil)
                        
                        // Project the anchor's position to screen coordinates
                        if let screenPoint = arView.project(worldPosition) {
                            
                            // Format the distance string
                            let distanceInFeet = distance * 3.28084
                            let label = String(format: "%.1f ft / %.1f m", distanceInFeet, distance)
                            
                            // Overlay the label at the projected screen point
                            Text(label)
                                .font(.system(size: 14, weight: .medium, design: .monospaced)) // Adjusted font
                                .foregroundColor(.white)
                                .padding(4) // Add some padding
                                .background(Color.black.opacity(0.5)) // Add background for readability
                                .cornerRadius(5)
                                .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 1)
                                .position(x: screenPoint.x, y: screenPoint.y + 35) // Adjusted offset
                        }
                    }
                }
            }
            // --- End Distance Overlay ---

            // UI Overlay VStack (This is the main UI layer)
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

                Spacer() // Pushes controls to bottom (if any were left)

                // Removed "Place on Map" Button

            } // End UI Overlay VStack
        } // End Main ZStack
        // Removed sheet modifier
        // Removed .onOpenURL and handleIncomingURL function
    }

    // Removed handleIncomingURL function
}

// Removed CLLocationCoordinate2D Hashable extension
