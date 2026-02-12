// ContentView.swift

import CoreLocation
//import DataModels  // Import DataModels to access ARObjectType, HuntType, ProximityMarkerData
import SwiftUI

public struct ContentView: View {
  @State private var coinsCollectedThisSession: Int = 0
  @State private var animate: Bool = false
  @State private var selectedObject: ARObjectType = .none
  @State private var currentLocation: CLLocationCoordinate2D?
  @State private var objectLocations: [CLLocationCoordinate2D] = []
  @State private var proximityMarkers: [ProximityMarkerData] = []
  @State private var pinData: [PinData] = []
  @State private var statusMessage: String = ""
  @State private var currentHuntType: HuntType?
  @State private var isSummoningActive: Bool = false
  @State private var focusedLootId: String? = nil
  @State private var focusedLootDistance: Float? = nil
  @State private var nearestLootDistance: Float? = nil
  @State private var nearestLootDirection: Float = 0 // Angle in radians relative to camera forward
  @State private var smoothedCompassAngle: Float = 0 // Smoothed angle for display
  @State private var isDebugMode: Bool = false
  @State private var showHorizonLine: Bool = false
  @State private var isPerformanceMode: Bool = false
  @State private var showGiftCardTest: Bool = false
  @State private var showARSimulator: Bool = false
  @State private var debugObjectTypeOverride: ARObjectType? = nil

  @StateObject private var locationManager = LocationManager()
  @StateObject private var huntDataManager = HuntDataManager.shared
  @State private var showingNamePrompt = false
  @State private var showingJoinPrompt = false
  @State private var showingHuntConfirmation = false
  @State private var userName = ""
  @State private var phoneNumber = ""
  @State private var isInitializing = true
  @State private var showingSplash = true
  @State private var userConfirmedHunt = false
  @State private var confirmedHuntId: String? = nil
  @State private var isLoadingLoot = false
  @State private var isLoadingModels = false

  public init() {
    print("DEBUG: ContentView - init() called.")
  }

  private var showSimulatorPreview: Bool {
    #if targetEnvironment(simulator)
    return ProcessInfo.processInfo.arguments.contains("SIMULATOR_COIN")
    #else
    return false
    #endif
  }

  private var shouldAutoLaunchARSimulator: Bool {
    #if targetEnvironment(simulator)
    return ProcessInfo.processInfo.arguments.contains("AR_SIMULATOR_TEST")
    #else
    return false
    #endif
  }

  // Computed property to calculate remaining loot count
  private var remainingLootCount: Int {
    guard let huntData = huntDataManager.huntData else { return 0 }
    let totalPins = huntData.pins.count
    let collectedPins = huntData.pins.filter { $0.collectedByUserId != nil }.count
    return totalPins - collectedPins
  }

  // Computed property for total coins collected by current user
  private var totalCoinsCollected: Int {
    guard let huntData = huntDataManager.huntData, let userId = huntDataManager.userId else { return 0 }
    return huntData.pins.filter { $0.collectedByUserId == userId }.count + coinsCollectedThisSession
  }

  // Smooth compass angle changes
  private func updateSmoothedAngle() {
    let targetAngle = nearestLootDirection

    // Calculate shortest rotation path (handle wraparound at +/- pi)
    var delta = targetAngle - smoothedCompassAngle

    // Normalize delta to [-pi, pi] range
    while delta > .pi {
      delta -= 2 * .pi
    }
    while delta < -.pi {
      delta += 2 * .pi
    }

    // Apply exponential smoothing (0.3 = smoother, 0.7 = more responsive)
    let smoothingFactor: Float = 0.4
    smoothedCompassAngle += delta * smoothingFactor

    // Normalize result to [-pi, pi]
    while smoothedCompassAngle > .pi {
      smoothedCompassAngle -= 2 * .pi
    }
    while smoothedCompassAngle < -.pi {
      smoothedCompassAngle += 2 * .pi
    }
  }

  public var body: some View {
    Group {
      if showSimulatorPreview {
        ZStack {
          LootaTheme.backgroundGradient
            .ignoresSafeArea()
          CoinSimulatorView()
        }
      } else {
        ZStack {
          LootaTheme.backgroundGradient
            .ignoresSafeArea()

          // Show splash screen first
          if showingSplash {
            SplashScreen()
              .transition(.opacity)
          }
          // Main app content (always present after splash)
          else {
            mainAppContent
              .disabled(isInitializing || isLoadingLoot || isLoadingModels || huntDataManager.isFetchingHunt) // Disable interaction during loading

            // Loading indicator overlays
            if isInitializing {
              LoadingIndicator(message: "Initializing Hunt...", showProgress: true, subtitle: "Please wait while we prepare your adventure")
                .transition(.opacity)
            } else if huntDataManager.isFetchingHunt {
              LoadingIndicator(message: "Summoning Hunt Map...", showProgress: true, subtitle: "Fetching treasure details from Loota HQ")
                .transition(.opacity)
            } else if isLoadingLoot {
              LoadingIndicator(message: "Loading Loot...", showProgress: true, subtitle: "Joining hunt and preparing AR treasures")
                .transition(.opacity)
            } else if isLoadingModels {
              LoadingIndicator(message: "Preparing AR Models...", showProgress: true, subtitle: "Loading 3D treasures for augmented reality")
                .transition(.opacity)
            }
          }
        }
        .onAppear {
          print("[Auto Claude] Main content view loaded successfully")

          // Auto-launch AR simulator if launched with AR_SIMULATOR_TEST argument
          if shouldAutoLaunchARSimulator {
            showingSplash = false
            showARSimulator = true
            return
          }

          // Show splash for 2 seconds, then start initialization
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
              showingSplash = false
            }

            // Start app initialization after splash
            initializeApp()
          }
        }
      }
    }
  }
  
  private var mainAppContent: some View {
    ZStack {
      // Main container ZStack
      // AR View in the background - only show after user has confirmed hunt participation
      // Condition to show ARViewContainer based on hunt type and user confirmation
      // Keep AR view active even when all loot is collected for better user experience
      if userConfirmedHunt && currentHuntType != nil {
        ARViewContainer(
          objectLocations: $objectLocations,
          referenceLocation: locationManager.currentLocation,
          statusMessage: $statusMessage,
          heading: $locationManager.heading,
          onCoinCollected: { collectedPinId in
            print("🎯 CONTENTVIEW: ===============================================")
            print("🎯 CONTENTVIEW: onCoinCollected called with pinId: \(collectedPinId)")
            print("🎯 CONTENTVIEW: Timestamp: \(Date())")
            coinsCollectedThisSession += 1
            print("🎯 CONTENTVIEW: Counter incremented to: \(coinsCollectedThisSession)")
            print("🎯 CONTENTVIEW: Total collected (including previous): \(totalCoinsCollected)")
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
              animate = true
            }
            // Reset animation after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
              animate = false
            }

            if let huntId = huntDataManager.huntData?.id {
              print("🎯 CONTENTVIEW: Found huntId: \(huntId)")
              print("🎯 CONTENTVIEW: About to call huntDataManager.collectPin")
              print("🎯 CONTENTVIEW: Parameters - huntId: \(huntId), pinId: \(collectedPinId)")
              huntDataManager.collectPin(huntId: huntId, pinId: collectedPinId)
              print("🎯 CONTENTVIEW: huntDataManager.collectPin call completed")
            } else {
              print("🎯 CONTENTVIEW: ❌ NO HUNT ID AVAILABLE")
              print("🎯 CONTENTVIEW: huntDataManager.huntData: \(huntDataManager.huntData?.id ?? "nil")")
            }
            print("🎯 CONTENTVIEW: ===============================================")
          },
          objectType: $selectedObject,
          currentHuntType: $currentHuntType,
          proximityMarkers: $proximityMarkers,
          pinData: $pinData,
          isSummoningActive: $isSummoningActive,
          focusedLootId: $focusedLootId,
          focusedLootDistance: $focusedLootDistance,
          nearestLootDistance: $nearestLootDistance,
          nearestLootDirection: $nearestLootDirection,
          isDebugMode: $isDebugMode,
          showHorizonLine: $showHorizonLine,
          isPerformanceMode: $isPerformanceMode,
          isLoadingModels: $isLoadingModels,
          debugObjectTypeOverride: $debugObjectTypeOverride
        )
        // Use a stable ID that doesn't change during active gameplay
        .id("ar-view-\(currentHuntType?.rawValue ?? "none")")
        .edgesIgnoringSafeArea(.all)
      } else {
        // Placeholder when AR is not ready or hunt not confirmed
        Color.black.opacity(0.65).edgesIgnoringSafeArea(.all)
        VStack(spacing: 20) {
          ZStack {
            Circle()
              .fill(LootaTheme.accentGradient)
              .frame(width: 88, height: 88)
              .shadow(color: LootaTheme.accentGlow.opacity(0.7), radius: 16, x: 0, y: 8)
            Image(systemName: "sparkles")
              .font(.system(size: 36, weight: .semibold))
              .foregroundColor(.white)
          }
          
          VStack(spacing: 8) {
            if showingHuntConfirmation {
              Text("Hunt Found!")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(LootaTheme.highlight)
              Text("Review the details and confirm to begin your adventure.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LootaTheme.textSecondary)
                .multilineTextAlignment(.center)
            } else if currentHuntType != nil && !userConfirmedHunt {
              Text("Hunt Ready")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
              Text("Complete the quick confirmation to start summoning loot.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LootaTheme.textSecondary)
                .multilineTextAlignment(.center)
            } else {
              Text("Loota Treasure Hunt")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
              Text("Scan a QR code or enter a hunt ID to jump into the action.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LootaTheme.textSecondary)
                .multilineTextAlignment(.center)
            }
          }
          .padding(.top, 8)

          // Display current hunt type and data counts for debugging (only in debug mode)
          if isDebugMode {
            VStack(alignment: .leading, spacing: 6) {
              Text("Debug Snapshots")
                .font(.caption2.smallCaps())
                .foregroundStyle(LootaTheme.textSecondary)
              
              Text("Hunt Type: \(currentHuntType.map { $0.rawValue } ?? "None")")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textPrimary)
              Text("Geolocation Objects: \(objectLocations.count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textPrimary)
              Text("Proximity Markers: \(proximityMarkers.count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textPrimary)
              Text("User Confirmed: \(userConfirmedHunt ? "Yes" : "No")")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textPrimary)
            }
            .lootaGlassBackground(
              cornerRadius: 20,
              padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            )
          }
        }
        .lootaGlassBackground()
        .padding(.horizontal, 36)
      }

      // VStack for Heading and Accuracy Display (Top Center) - Debug Mode Only
      if isDebugMode {
        VStack {
          debugChip(locationManager.trueHeadingString)
          debugChip(locationManager.accuracyString)
          Spacer()  // Pushes this VStack to the top
        }
        .padding(.top, 10)  // Add some padding from the top edge
        .frame(maxWidth: .infinity, alignment: .center)  // Center horizontally
      }

      // Distance Display - Center of Screen (only when loot is >20ft and focused)
      if let distance = focusedLootDistance, distance > 6.096 { // 20 feet in meters
        VStack {
          Spacer()

          Text(String(format: "%.2f ft", distance * 3.28084))
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(LootaTheme.highlight)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.6))
                .overlay(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                      LinearGradient(
                        colors: [LootaTheme.neonCyan.opacity(0.6), LootaTheme.cosmicPurple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 2
                    )
                )
            )
            .shadow(color: LootaTheme.accentGlow.opacity(0.4), radius: 12, x: 0, y: 4)

          Spacer()
        }
        .frame(maxWidth: .infinity)
      }

      // Compass Needle and Nearest Loot Label - Bottom Center (hide when summoning)
      if let distance = nearestLootDistance, focusedLootId == nil {
        VStack {
          Spacer()

          VStack(spacing: 12) {
            // Distance label
            VStack(spacing: 4) {
              Text("Nearest Loot")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
              Text(String(format: "%.0f ft", distance * 3.28084))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(LootaTheme.highlight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.6))
                .overlay(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                      LinearGradient(
                        colors: [LootaTheme.neonCyan.opacity(0.6), LootaTheme.cosmicPurple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 2
                    )
                )
            )
            .shadow(color: LootaTheme.accentGlow.opacity(0.4), radius: 12, x: 0, y: 4)

            // Compass needle with a flattened HUD look
            ZStack {
              Ellipse()
                .fill(
                  LinearGradient(
                    colors: [
                      Color.black.opacity(0.85),
                      Color.black.opacity(0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                  )
                )
                .overlay(
                  Ellipse()
                    .stroke(
                      LinearGradient(
                        colors: [LootaTheme.neonCyan.opacity(0.6), LootaTheme.cosmicPurple.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                      ),
                      lineWidth: 3
                    )
                    .blur(radius: 0.5)
                )

              Ellipse()
                .fill(
                  LinearGradient(
                    colors: [
                      LootaTheme.neonCyan.opacity(0.12),
                      Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .padding(8)

              Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 72, height: 6)
                .blur(radius: 2)
                .offset(y: -22)

              Capsule()
                .fill(Color.black.opacity(0.6))
                .frame(width: 85, height: 12)
                .blur(radius: 6)
                .offset(y: 30)

              // Rotating arrow needle with smoothed rotation
              Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(
                  LinearGradient(
                    colors: [LootaTheme.neonCyan, LootaTheme.cosmicPurple],
                    startPoint: .top,
                    endPoint: .bottom
                  )
                )
                .shadow(color: LootaTheme.neonCyan.opacity(0.9), radius: 10)
                .rotationEffect(Angle(radians: Double(smoothedCompassAngle)))
            }
            .frame(width: 130, height: 95)
            .rotation3DEffect(.degrees(55), axis: (x: 1, y: 0, z: 0))
            .shadow(color: LootaTheme.accentGlow.opacity(0.35), radius: 16, x: 0, y: 12)
          }
          .padding(.bottom, 100) // Above bottom edge
        }
        .frame(maxWidth: .infinity)
        .onChange(of: nearestLootDirection) { _ in
          updateSmoothedAngle()
        }
      }

      // Summoning Button - Bottom Center (always visible when loot is focused)
      if let focusedId = focusedLootId {
        let shortId = String(focusedId.suffix(4)).uppercased()
        VStack {
          Spacer()

          VStack(spacing: 8) {
            // Circular Summoning Button
            Button(action: {}) {
              ZStack {
                Circle()
                  .strokeBorder(
                    LinearGradient(
                      colors: [LootaTheme.neonCyan.opacity(0.8), LootaTheme.cosmicPurple.opacity(0.8)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                  )
                  .frame(width: 104, height: 104)
                  .overlay(
                    Circle()
                      .strokeBorder(Color.white.opacity(isSummoningActive ? 0.7 : 0.25), lineWidth: 1)
                      .blur(radius: 2)
                  )

                Circle()
                  .fill(
                    RadialGradient(
                      gradient: Gradient(colors: [
                        isSummoningActive ? LootaTheme.neonCyan.opacity(0.9) : Color.white.opacity(0.15),
                        LootaTheme.cosmicPurple.opacity(0.85)
                      ]),
                      center: .center,
                      startRadius: 2,
                      endRadius: 120
                    )
                  )
                  .frame(width: 96, height: 96)
                  .shadow(color: LootaTheme.accentGlow.opacity(isSummoningActive ? 0.8 : 0.4), radius: isSummoningActive ? 24 : 10, x: 0, y: 8)

                Image(systemName: isSummoningActive ? "waveform.path.ecg" : "wand.and.stars")
                  .font(.system(size: 32, weight: .semibold, design: .rounded))
                  .foregroundColor(.white)
                  .scaleEffect(isSummoningActive ? 1.08 : 1.0)
                  .animation(.easeInOut(duration: 0.3), value: isSummoningActive)
              }
            }
            .scaleEffect(isSummoningActive ? 1.1 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
              isSummoningActive = pressing
            }) {
              // Long press ended
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSummoningActive)

            VStack(spacing: 4) {
              Text("Hold to Summon")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
              Text("Focus ID · \(shortId)")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                  Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                      Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                )
            }
          }
          .padding(.bottom, 100) // Above bottom edge but below debug panel
        }
        .frame(maxWidth: .infinity)
      }
      
      // UI Overlay VStack
      VStack {
        HStack(alignment: .top) {  // Top Row: Counter and Object Type Display
          // Animated counter in top left
          HStack(alignment: .center, spacing: 14) {
            ZStack {
              Circle()
                .fill(LootaTheme.accentGradient)
                .frame(width: 54, height: 54)
                .shadow(color: LootaTheme.scoreGlow(for: animate), radius: animate ? 18 : 8, x: 0, y: 6)
              Image(systemName: "diamond.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white)
                .rotationEffect(.degrees(12))
            }
            .scaleEffect(animate ? 1.15 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.55), value: animate)
            
            VStack(alignment: .leading, spacing: 2) {
              Text("Loot Collected")
                .font(.caption)
                .foregroundColor(LootaTheme.textSecondary)
                .textCase(.uppercase)
              
              Text("\(totalCoinsCollected)")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundColor(LootaTheme.highlight)
                .shadow(color: LootaTheme.scoreGlow(for: animate), radius: animate ? 14 : 4, x: 0, y: 0)
                .scaleEffect(animate ? 1.2 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animate)
            }
          }
          .lootaGlassBackground(
            cornerRadius: 28,
            padding: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 22)
          )
          .padding([.top, .leading], 16)

          Spacer()  // Pushes coin count to the right

          // Remaining loot count display
          VStack(alignment: .trailing, spacing: 4) {
            Text("Remaining Loot")
              .font(.caption2.smallCaps())
              .foregroundColor(LootaTheme.textSecondary)
            HStack(spacing: 8) {
              Text("\(remainingLootCount)")
                .font(.headline.weight(.bold))
                .foregroundColor(LootaTheme.highlight)
              Text("Coins")
                .font(.headline.weight(.bold))
                .foregroundColor(LootaTheme.highlight)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                  Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
          }
          .lootaGlassBackground(
            cornerRadius: 26,
            padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
          )
          .padding([.top, .trailing], 16)
        }

        Spacer()  // Pushes debug button to bottom

        // Debug mode toggle button - Lower Left
        HStack {
          Button(action: {
            isDebugMode.toggle()
          }) {
            HStack(spacing: 8) {
              Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
              Text(isDebugMode ? "Debug Mode" : "Play Mode")
                .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
              Capsule()
                .fill(
                  LinearGradient(
                    colors: isDebugMode
                      ? [LootaTheme.warning, LootaTheme.cosmicPurple]
                      : [LootaTheme.cosmicPurple, LootaTheme.neonCyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 6)
          }
          .padding([.bottom, .leading], 16)

          Spacer()
        }

        // Debug Information Panel - Only show in debug mode
        if isDebugMode {
          let errorMessage = (huntDataManager.errorMessage ?? statusMessage)
            .trimmingCharacters(in: .whitespacesAndNewlines)
          let joinMessage = huntDataManager.joinStatusMessage?
            .trimmingCharacters(in: .whitespacesAndNewlines)

          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Explorer Status")
                .font(.caption.smallCaps())
                .foregroundColor(LootaTheme.textSecondary)
              HStack(spacing: 12) {
                debugChip(String(format: "%.6f", currentLocation?.latitude ?? 0))
                debugChip(String(format: "%.6f", currentLocation?.longitude ?? 0))
              }
              Text("User: \(huntDataManager.userName ?? "N/A")")
                .font(.caption)
                .foregroundColor(LootaTheme.textMuted)
            }

            dividerLine

            if currentHuntType == .geolocation {
              VStack(alignment: .leading, spacing: 6) {
                Text("Geolocation Loot (\(objectLocations.count))")
                  .font(.caption.smallCaps())
                  .foregroundColor(LootaTheme.textSecondary)
                if let firstLocation = objectLocations.first {
                  debugChip(String(format: "%.6f", firstLocation.latitude))
                  debugChip(String(format: "%.6f", firstLocation.longitude))
                } else {
                  debugChip("Awaiting coordinates")
                }
              }
            } else if currentHuntType == .proximity {
              VStack(alignment: .leading, spacing: 6) {
                Text("Proximity Markers (\(proximityMarkers.count))")
                  .font(.caption.smallCaps())
                  .foregroundColor(LootaTheme.textSecondary)
                if let firstMarker = proximityMarkers.first {
                  debugChip("Dist \(String(format: "%.1f", firstMarker.dist)) m")
                  debugChip("Dir \(firstMarker.dir)")
                } else {
                  debugChip("Awaiting marker data")
                }
              }
            } else {
              Text("No hunt data loaded yet.")
                .font(.caption)
                .foregroundColor(LootaTheme.textMuted)
            }

            dividerLine

            Button(action: {
              showHorizonLine.toggle()
            }) {
              HStack(spacing: 12) {
                Image(systemName: showHorizonLine ? "minus.circle.fill" : "plus.circle.fill")
                  .foregroundColor(showHorizonLine ? LootaTheme.warning : LootaTheme.neonCyan)
                  .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                  Text("Horizon Line")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(LootaTheme.textPrimary)
                  Text(showHorizonLine ? "Visible" : "Hidden")
                    .font(.caption)
                    .foregroundColor(showHorizonLine ? LootaTheme.warning : LootaTheme.textSecondary)
                }
                Spacer()
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
              .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .fill(Color.white.opacity(0.08))
                  .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                      .stroke(Color.white.opacity(0.18), lineWidth: 1)
                  )
              )
            }

            Button(action: {
              isPerformanceMode.toggle()
            }) {
              HStack(spacing: 12) {
                Image(systemName: "speedometer")
                  .foregroundColor(isPerformanceMode ? LootaTheme.warning : LootaTheme.neonCyan)
                  .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                  Text("Perf Mode")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(LootaTheme.textPrimary)
                  Text(isPerformanceMode ? "Reduced updates" : "Full updates")
                    .font(.caption)
                    .foregroundColor(isPerformanceMode ? LootaTheme.warning : LootaTheme.textSecondary)
                }
                Spacer()
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
              .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .fill(Color.white.opacity(0.08))
                  .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                      .stroke(Color.white.opacity(0.18), lineWidth: 1)
                  )
              )
            }

            // Object Type Override Picker
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 12) {
                Image(systemName: "cube.fill")
                  .foregroundColor(debugObjectTypeOverride != nil ? LootaTheme.warning : LootaTheme.neonCyan)
                  .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                  Text("Object Type Override")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(LootaTheme.textPrimary)
                  Text(debugObjectTypeOverride?.displayName ?? "Use Default")
                    .font(.caption)
                    .foregroundColor(debugObjectTypeOverride != nil ? LootaTheme.warning : LootaTheme.textSecondary)
                }
                Spacer()
              }

              HStack(spacing: 8) {
                ForEach([nil, ARObjectType.coin, ARObjectType.giftCard], id: \.self) { type in
                  Button(action: {
                    debugObjectTypeOverride = type
                  }) {
                    Text(type?.displayName ?? "Default")
                      .font(.caption.weight(.semibold))
                      .foregroundColor(debugObjectTypeOverride == type ? .white : LootaTheme.textSecondary)
                      .padding(.horizontal, 12)
                      .padding(.vertical, 6)
                      .background(
                        Capsule()
                          .fill(debugObjectTypeOverride == type ? LootaTheme.cosmicPurple : Color.white.opacity(0.08))
                      )
                  }
                }
              }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            )

            Button(action: {
              showGiftCardTest = true
            }) {
              HStack(spacing: 12) {
                Image(systemName: "creditcard.viewfinder")
                  .foregroundColor(LootaTheme.cosmicPurple)
                  .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                  Text("Gift Card Test")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(LootaTheme.textPrimary)
                  Text("Test orientation")
                    .font(.caption)
                    .foregroundColor(LootaTheme.textSecondary)
                }
                Spacer()
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
              .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .fill(Color.white.opacity(0.08))
                  .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                      .stroke(Color.white.opacity(0.18), lineWidth: 1)
                  )
              )
            }

            Button(action: {
              showARSimulator = true
            }) {
              HStack(spacing: 12) {
                Image(systemName: "arkit")
                  .foregroundColor(LootaTheme.cosmicPurple)
                  .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                  Text("AR Simulator")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(LootaTheme.textPrimary)
                  Text("Test AR without hardware")
                    .font(.caption)
                    .foregroundColor(LootaTheme.textSecondary)
                }
                Spacer()
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
              .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .fill(Color.white.opacity(0.08))
                  .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                      .stroke(Color.white.opacity(0.18), lineWidth: 1)
                  )
              )
            }

            if !errorMessage.isEmpty {
              HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.red.opacity(0.8))
                Text(errorMessage)
                  .font(.footnote.weight(.semibold))
                  .foregroundColor(.red.opacity(0.9))
              }
              .padding(.vertical, 8)
            }

            if let joinMessage, !joinMessage.isEmpty {
              HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                  .foregroundColor(LootaTheme.success)
                Text(joinMessage)
                  .font(.footnote.weight(.semibold))
                  .foregroundColor(LootaTheme.success)
              }
              .padding(.vertical, 6)
            }

            HStack(spacing: 12) {
              debugChip("Fetched: \(currentHuntType != nil ? "YES" : "NO")")
              if currentHuntType == .geolocation {
                debugChip("Objects: \(objectLocations.count)")
              } else if currentHuntType == .proximity {
                debugChip("Markers: \(proximityMarkers.count)")
              }
            }
          }
          .lootaGlassBackground(
            cornerRadius: 30,
            padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 24)
        }
      }
      
      // Hunt join confirmation screen overlay
      if showingHuntConfirmation,
         let huntData = huntDataManager.huntData {
        HuntJoinConfirmationView(
          huntData: huntData,
          existingUserName: huntDataManager.userName,
          existingUserId: huntDataManager.userId,
          existingUserPhone: huntDataManager.userPhone,
          isPresented: $showingHuntConfirmation,
          onConfirm: { name, phone in
            confirmHuntParticipation(name: name, phone: phone)
          },
          onCancel: {
            cancelHuntParticipation()
          }
        )
        .transition(.opacity)
        .zIndex(1000) // Ensure it appears on top of everything
      }
      
      // Hunt completion screen overlay
      if huntDataManager.showCompletionScreen,
         let huntData = huntDataManager.huntData,
         let userId = huntDataManager.userId {
        HuntCompletionView(
          huntData: huntData,
          currentUserId: userId,
          isPresented: $huntDataManager.showCompletionScreen
        )
        .transition(.opacity)
        .zIndex(999) // Ensure it appears on top
      }
      
    }
    .onChange(of: selectedObject) { newValue in
      handleSelectedObjectChange(selectedObject, newValue)
    }
    .onChange(of: showingNamePrompt) { newValue in
      print("🔥 DEBUG: showingNamePrompt changed to \(newValue)")
    }
    .onReceive(locationManager.$currentLocation) { location in
      currentLocation = location
      print("ContentView onReceive: Updated currentLocation: \(String(describing: location))")
      
    }
    .onReceive(locationManager.$heading) { newHeading in
      print(
        "ContentView onReceive: Updated heading: \(String(describing: newHeading?.trueHeading))")
    }
    // Note: Old alert-based prompts replaced with HuntJoinConfirmationView modal
    // Keeping alert infrastructure for potential error dialogs or edge cases
    .onReceive(huntDataManager.$huntData) { huntData in
      if let huntData = huntData {
        print("🔥 DEBUG: Hunt data received")
        print("🔥 DEBUG: Hunt ID: \(huntData.id)")
        print("🔥 DEBUG: Hunt Name: '\(huntData.name ?? "nil")'")
        print("🔥 DEBUG: Hunt Description: '\(huntData.description ?? "nil")'")
        print("🔥 DEBUG: userConfirmedHunt: \(userConfirmedHunt)")
        print("🔥 DEBUG: confirmedHuntId: \(confirmedHuntId ?? "nil")")
        print("🔥 DEBUG: showingHuntConfirmation: \(showingHuntConfirmation)")

        // Load the hunt data first (but don't show AR yet - userConfirmedHunt is still false)
        loadHuntData(huntData)

        // Pre-fill user name if available
        if let existingName = huntDataManager.userName {
          userName = existingName
        }

        // Only show hunt confirmation if user hasn't already confirmed this specific hunt
        if confirmedHuntId != huntData.id {
          print("🔥 DEBUG: New hunt or user hasn't confirmed this hunt yet, showing confirmation modal")
          showingHuntConfirmation = true
        } else {
          print("🔥 DEBUG: User already confirmed hunt \(huntData.id), skipping confirmation modal")
        }
      }
    }
    .onReceive(huntDataManager.$joinStatusMessage) { joinMessage in
      // When hunt join is successful, activate AR view
      if joinMessage != nil {
        print("🔥 DEBUG: Hunt join completed, activating AR view")
        withAnimation(.easeInOut(duration: 0.5)) {
          isLoadingLoot = false
          userConfirmedHunt = true
        }
      }
    }
    .onReceive(huntDataManager.$errorMessage) { errorMessage in
      // If there's an error during loading, stop the loading state
      if isLoadingLoot && errorMessage != nil {
        print("🔥 DEBUG: Hunt join failed, stopping loading state")
        withAnimation(.easeInOut(duration: 0.3)) {
          isLoadingLoot = false
        }
      }
    }
    .fullScreenCover(isPresented: $showGiftCardTest) {
      GiftCardTestView()
    }
    .fullScreenCover(isPresented: $showARSimulator) {
      ARSimulatorTestView()
    }
  }

  private func initializeApp() {
    print("ContentView initializeApp: Starting app initialization.")
    locationManager.requestAuthorization()
    locationManager.startUpdating()
    
    print(
      "ContentView initializeApp: objectLocations.count = \(objectLocations.count), proximityMarkers.count = \(proximityMarkers.count), selectedObject = \(selectedObject.rawValue), currentHuntType = \(String(describing: currentHuntType))"
    )
    
    // Don't show name prompt immediately - wait for hunt data and actual join attempt
    // Finish initialization after a short delay to allow location services to start
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      withAnimation(.easeInOut(duration: 0.5)) {
        isInitializing = false
      }
    }
  }
  
  // Note: Old alert-based methods replaced with unified confirmHuntParticipation
  // Keeping for potential fallback scenarios or debug purposes
  
  private func submitName() {
    // Legacy method - now handled by HuntJoinConfirmationView
    print("🔥 DEBUG: submitName() called - should use confirmHuntParticipation instead")
  }
  
  private func cancelNamePrompt() {
    // Legacy method - now handled by HuntJoinConfirmationView
    print("🔥 DEBUG: cancelNamePrompt() called - should use cancelHuntParticipation instead")
  }
  
  private func joinHuntWithPhone() {
    // Legacy method - now handled by HuntJoinConfirmationView
    print("🔥 DEBUG: joinHuntWithPhone() called - should use confirmHuntParticipation instead")
  }
  
  private func confirmHuntParticipation(name: String, phone: String) {
    print("🔥 DEBUG: confirmHuntParticipation called with name: '\(name)', phone: '\(phone)'")

    // Start loading state
    withAnimation(.easeInOut(duration: 0.3)) {
      isLoadingLoot = true
      showingHuntConfirmation = false
    }

    // Update local state
    userName = name
    phoneNumber = phone

    // Update the user name in hunt manager if it changed
    let currentName = huntDataManager.userName
    if currentName != name {
      print("🔥 DEBUG: User name changed from '\(currentName ?? "nil")' to '\(name)' - updating")
      huntDataManager.setUserName(name)
    }

    // Update the user phone in hunt manager if it changed
    let currentPhone = huntDataManager.userPhone
    if currentPhone != phone {
      print("🔥 DEBUG: User phone changed from '\(currentPhone ?? "nil")' to '\(phone)' - updating")
      huntDataManager.setUserPhone(phone)
    }

    // Join the hunt with phone number
    if let huntData = huntDataManager.huntData {
      print("🔥 DEBUG: Joining hunt '\(huntData.id)' with updated user data")
      huntDataManager.joinHunt(huntId: huntData.id, phoneNumber: phone)

      // Mark hunt as confirmed - AR initialization will happen after join completes
      confirmedHuntId = huntData.id

      print("🔥 DEBUG: Hunt participation confirmed for huntId: \(huntData.id), loading loot...")
    }
  }
  
  private func cancelHuntParticipation() {
    print("🔥 DEBUG: cancelHuntParticipation called")

    // Reset hunt data and state
    withAnimation(.easeInOut(duration: 0.3)) {
      showingHuntConfirmation = false
      isLoadingLoot = false
    }
    userConfirmedHunt = false
    confirmedHuntId = nil
    huntDataManager.huntData = nil

    // Clear hunt-related state
    currentHuntType = nil
    objectLocations = []
    proximityMarkers = []
    pinData = []
    selectedObject = .none

    print("🔥 DEBUG: Hunt participation cancelled, returning to initial state")
  }
  
  private func handleSelectedObjectChange(_ oldValue: ARObjectType, _ newValue: ARObjectType) {
    // Clear locations when object type changes to none.
    // This might need adjustment based on how objectType is used with hunt types
    if newValue == .none {
      objectLocations = []  // Only clear geolocation locations here?
      // proximityMarkers = [] // Should proximity markers be cleared? Probably not by objectType change.
      print(
        "ContentView onChange selectedObject: \(newValue.rawValue) - Object type set to None, clearing geolocation locations."
      )
    } else {
      print("ContentView onChange selectedObject: \(newValue.rawValue)")
    }
  }

  private func debugChip(_ text: String) -> some View {
    Text(text)
      .font(.caption.monospacedDigit())
      .foregroundColor(LootaTheme.textPrimary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(Color.white.opacity(0.08))
          .overlay(
            Capsule()
              .stroke(Color.white.opacity(0.18), lineWidth: 1)
          )
      )
  }

  private var dividerLine: some View {
    Rectangle()
      .fill(Color.white.opacity(0.12))
      .frame(height: 1)
  }

  // Method to load hunt data from HuntDataManager
  private func loadHuntData(_ huntData: HuntData) {
    print(
      "ContentView loadHuntData: Received hunt data for ID: \(huntData.id), type: \(huntData.type.rawValue)"
    )
    // huntDataManager.joinHunt(huntId: huntData.id) // This is now called from HuntDataManager
    self.currentHuntType = huntData.type
    self.statusMessage = ""  // Clear any previous error messages

    // Reset session counter when loading a new hunt
    self.coinsCollectedThisSession = 0
    print("ContentView loadHuntData: Reset session counter. Total user collected: \(totalCoinsCollected)")

    switch huntData.type {
    case .geolocation:
      print("ContentView loadHuntData: Processing \(huntData.pins.count) pins for geolocation")
      self.objectLocations = []
      self.pinData = []
      
      for pin in huntData.pins {
        // Skip pins that have already been collected
        if pin.collectedByUserId != nil {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping collected Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Collected by: \(pin.collectedByUserId ?? "unknown")")
          continue
        }
        
        if let lat = pin.lat, let lng = pin.lng {
          let location = CLLocationCoordinate2D(latitude: lat, longitude: lng)
          self.objectLocations.append(location)
          self.pinData.append(pin)
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: AR Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Order: \(pin.order ?? -1) - Lat: \(lat), Lng: \(lng)")
        } else {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Missing coordinates")
        }
      }
      
      self.proximityMarkers = []
      // Use hunt's objectType if specified, otherwise default to coin
      let huntObjectType = huntData.objectType ?? .coin
      if !self.objectLocations.isEmpty {
        self.selectedObject = huntObjectType
      }
      let collectedCount = huntData.pins.filter { $0.collectedByUserId != nil }.count
      print("ContentView loadHuntData: Total pins: \(huntData.pins.count), Collected: \(collectedCount), AR objects created: \(self.objectLocations.count), objectType: \(huntObjectType.rawValue)")

    case .proximity:
      print("ContentView loadHuntData: Processing \(huntData.pins.count) pins for proximity")
      self.proximityMarkers = []
      self.pinData = []
      
      for pin in huntData.pins {
        // Skip pins that have already been collected
        if pin.collectedByUserId != nil {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping collected Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Collected by: \(pin.collectedByUserId ?? "unknown")")
          continue
        }
        
        if let dist = pin.distanceFt, let dir = pin.directionStr {
          let marker = ProximityMarkerData(dist: dist * 0.3048, dir: dir)
          self.proximityMarkers.append(marker)
          self.pinData.append(pin)
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: AR Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Order: \(pin.order ?? -1) - \(dist)ft \(dir)")
        } else {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Missing proximity data")
        }
      }
      
      self.objectLocations = []
      // Use hunt's objectType if specified, otherwise default to coin
      self.selectedObject = huntData.objectType ?? .coin
      let collectedCount = huntData.pins.filter { $0.collectedByUserId != nil }.count
      print("ContentView loadHuntData: Total pins: \(huntData.pins.count), Collected: \(collectedCount), Proximity markers created: \(self.proximityMarkers.count), objectType: \(self.selectedObject.rawValue)")
    }
  }



  // Method to display error messages from AppDelegate
  public func displayErrorMessage(_ message: String) {
    DispatchQueue.main.async {
      self.statusMessage = message
      self.objectLocations = []
      self.proximityMarkers = []
      self.currentHuntType = nil
      self.selectedObject = .none
      print("ContentView displayErrorMessage: \(message)")
    }
  }
}
