// AppClipContentView.swift
// Streamlined version of ContentView for App Clip - no splash, no simulator, no debug UI

import CoreLocation
import SwiftUI

struct AppClipContentView: View {
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
  @State private var nearestLootDirection: Float = 0
  @State private var smoothedCompassAngle: Float = 0
  @State private var isDebugMode: Bool = false
  @State private var showHorizonLine: Bool = false
  @State private var isPerformanceMode: Bool = false
  @State private var debugObjectTypeOverride: ARObjectType? = nil

  @StateObject private var locationManager = LocationManager()
  @StateObject private var huntDataManager = HuntDataManager.shared
  @StateObject private var huntTracker = AppClipHuntTracker.shared
  @State private var showingHuntConfirmation = false
  @State private var userName = ""
  @State private var phoneNumber = ""
  @State private var isInitializing = true
  @State private var userConfirmedHunt = false
  @State private var confirmedHuntId: String? = nil
  @State private var isLoadingLoot = false
  @State private var isLoadingModels = false
  @State private var showDownloadPrompt = false

  private var remainingLootCount: Int {
    guard let huntData = huntDataManager.huntData else { return 0 }
    let totalPins = huntData.pins.count
    let collectedPins = huntData.pins.filter { $0.collectedByUserId != nil }.count
    return totalPins - collectedPins
  }

  private var totalCoinsCollected: Int {
    guard let huntData = huntDataManager.huntData, let userId = huntDataManager.userId else { return 0 }
    return huntData.pins.filter { $0.collectedByUserId == userId }.count + coinsCollectedThisSession
  }

  private func updateSmoothedAngle() {
    let targetAngle = nearestLootDirection
    var delta = targetAngle - smoothedCompassAngle
    while delta > .pi { delta -= 2 * .pi }
    while delta < -.pi { delta += 2 * .pi }
    let smoothingFactor: Float = 0.4
    smoothedCompassAngle += delta * smoothingFactor
    while smoothedCompassAngle > .pi { smoothedCompassAngle -= 2 * .pi }
    while smoothedCompassAngle < -.pi { smoothedCompassAngle += 2 * .pi }
  }

  var body: some View {
    Group {
      if showDownloadPrompt {
        DownloadFullAppView()
      } else {
        ZStack {
          LootaTheme.backgroundGradient
            .ignoresSafeArea()

          mainAppContent
            .disabled(isInitializing || isLoadingLoot || isLoadingModels || huntDataManager.isFetchingHunt)

          // Loading indicators
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
        .onAppear {
          initializeApp()
        }
      }
    }
  }

  private var mainAppContent: some View {
    ZStack {
      // AR View - only after user confirmed hunt
      if userConfirmedHunt && currentHuntType != nil {
        ARViewContainer(
          objectLocations: $objectLocations,
          referenceLocation: locationManager.currentLocation,
          statusMessage: $statusMessage,
          heading: $locationManager.heading,
          onCoinCollected: { collectedPinId in
            coinsCollectedThisSession += 1
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
              animate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
              animate = false
            }
            if let huntId = huntDataManager.huntData?.id {
              huntDataManager.collectPin(huntId: huntId, pinId: collectedPinId)
            }
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
        .id("ar-view-\(currentHuntType?.rawValue ?? "none")")
        .edgesIgnoringSafeArea(.all)
      } else {
        // Placeholder when AR is not ready
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
              Text("Waiting for hunt link...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LootaTheme.textSecondary)
                .multilineTextAlignment(.center)
            }
          }
          .padding(.top, 8)
        }
        .lootaGlassBackground()
        .padding(.horizontal, 36)
      }

      // Distance Display - Center of Screen (only when loot is >20ft and focused)
      if let distance = focusedLootDistance, distance > 6.096 {
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

      // Compass Needle - Bottom Center (hide when summoning)
      if let distance = nearestLootDistance, focusedLootId == nil {
        VStack {
          Spacer()
          VStack(spacing: 12) {
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

            // Compass needle
            ZStack {
              Ellipse()
                .fill(
                  LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.45)],
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
                    colors: [LootaTheme.neonCyan.opacity(0.12), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .padding(8)

              Capsule().fill(Color.white.opacity(0.25)).frame(width: 72, height: 6).blur(radius: 2).offset(y: -22)
              Capsule().fill(Color.black.opacity(0.6)).frame(width: 85, height: 12).blur(radius: 6).offset(y: 30)

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
          .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: nearestLootDirection) { _ in
          updateSmoothedAngle()
        }
      }

      // Summoning Button
      if let focusedId = focusedLootId {
        let shortId = String(focusedId.suffix(4)).uppercased()
        VStack {
          Spacer()
          VStack(spacing: 8) {
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
            }) {}
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSummoningActive)

            VStack(spacing: 4) {
              Text("Hold to Summon")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(LootaTheme.textPrimary)
              Text("Focus ID \u{00B7} \(shortId)")
                .font(.caption.monospacedDigit())
                .foregroundColor(LootaTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                  Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                )
            }
          }
          .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity)
      }

      // UI Overlay
      VStack {
        HStack(alignment: .top) {
          // Loot counter
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

          Spacer()

          // Remaining loot
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
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            )
          }
          .lootaGlassBackground(
            cornerRadius: 26,
            padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
          )
          .padding([.top, .trailing], 16)
        }

        Spacer()

        // "Get Full App" banner at bottom
        if huntTracker.remainingHunts <= 1 {
          HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
              .font(.title3)
              .foregroundColor(LootaTheme.neonCyan)
            VStack(alignment: .leading, spacing: 2) {
              Text("Get the Full App")
                .font(.subheadline.weight(.bold))
                .foregroundColor(LootaTheme.textPrimary)
              Text("\(huntTracker.remainingHunts) free hunt\(huntTracker.remainingHunts == 1 ? "" : "s") remaining")
                .font(.caption)
                .foregroundColor(LootaTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.bold))
              .foregroundColor(LootaTheme.textSecondary)
          }
          .padding(.horizontal, 18)
          .padding(.vertical, 14)
          .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .fill(.ultraThinMaterial)
              .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .stroke(LootaTheme.neonCyan.opacity(0.3), lineWidth: 1)
              )
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
          .onTapGesture {
            showDownloadPrompt = true
          }
        }
      }

      // Hunt join confirmation overlay
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
        .zIndex(1000)
      }

      // Hunt completion overlay
      if huntDataManager.showCompletionScreen,
         let huntData = huntDataManager.huntData,
         let userId = huntDataManager.userId {
        HuntCompletionView(
          huntData: huntData,
          currentUserId: userId,
          isPresented: $huntDataManager.showCompletionScreen
        )
        .transition(.opacity)
        .zIndex(999)
      }
    }
    .onChange(of: selectedObject) { newValue in
      if newValue == .none {
        objectLocations = []
      }
    }
    .onReceive(locationManager.$currentLocation) { location in
      currentLocation = location
    }
    .onReceive(huntDataManager.$huntData) { huntData in
      if let huntData = huntData {
        loadHuntData(huntData)
        if let existingName = huntDataManager.userName {
          userName = existingName
        }
        if confirmedHuntId != huntData.id {
          // Check hunt limit before showing confirmation
          if huntTracker.canStartNewHunt {
            showingHuntConfirmation = true
          } else {
            showDownloadPrompt = true
          }
        }
      }
    }
    .onReceive(huntDataManager.$joinStatusMessage) { joinMessage in
      if joinMessage != nil {
        withAnimation(.easeInOut(duration: 0.5)) {
          isLoadingLoot = false
          userConfirmedHunt = true
        }
      }
    }
    .onReceive(huntDataManager.$errorMessage) { errorMessage in
      if isLoadingLoot && errorMessage != nil {
        withAnimation(.easeInOut(duration: 0.3)) {
          isLoadingLoot = false
        }
      }
    }
    .onChange(of: huntDataManager.showCompletionScreen) { showCompletion in
      if showCompletion, let huntId = huntDataManager.huntData?.id {
        huntTracker.recordHuntCompleted(huntId: huntId)
      }
    }
  }

  // MARK: - App Initialization

  private func initializeApp() {
    locationManager.requestAuthorization()
    locationManager.startUpdating()

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      withAnimation(.easeInOut(duration: 0.5)) {
        isInitializing = false
      }
    }
  }

  // MARK: - Hunt Participation

  private func confirmHuntParticipation(name: String, phone: String) {
    withAnimation(.easeInOut(duration: 0.3)) {
      isLoadingLoot = true
      showingHuntConfirmation = false
    }

    userName = name
    phoneNumber = phone

    let currentName = huntDataManager.userName
    if currentName != name {
      huntDataManager.setUserName(name)
    }

    let currentPhone = huntDataManager.userPhone
    if currentPhone != phone {
      huntDataManager.setUserPhone(phone)
    }

    if let huntData = huntDataManager.huntData {
      huntDataManager.joinHunt(huntId: huntData.id, phoneNumber: phone)
      confirmedHuntId = huntData.id
    }
  }

  private func cancelHuntParticipation() {
    withAnimation(.easeInOut(duration: 0.3)) {
      showingHuntConfirmation = false
      isLoadingLoot = false
    }
    userConfirmedHunt = false
    confirmedHuntId = nil
    huntDataManager.huntData = nil
    currentHuntType = nil
    objectLocations = []
    proximityMarkers = []
    pinData = []
    selectedObject = .none
  }

  // MARK: - Hunt Data Loading

  private func loadHuntData(_ huntData: HuntData) {
    self.currentHuntType = huntData.type
    self.statusMessage = ""
    self.coinsCollectedThisSession = 0

    switch huntData.type {
    case .geolocation:
      self.objectLocations = []
      self.pinData = []

      for pin in huntData.pins {
        if pin.collectedByUserId != nil { continue }
        if let lat = pin.lat, let lng = pin.lng {
          self.objectLocations.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
          self.pinData.append(pin)
        }
      }

      self.proximityMarkers = []
      let huntObjectType = huntData.objectType ?? .coin
      if !self.objectLocations.isEmpty {
        self.selectedObject = huntObjectType
      }

    case .proximity:
      self.proximityMarkers = []
      self.pinData = []

      for pin in huntData.pins {
        if pin.collectedByUserId != nil { continue }
        if let dist = pin.distanceFt, let dir = pin.directionStr {
          self.proximityMarkers.append(ProximityMarkerData(dist: dist * 0.3048, dir: dir))
          self.pinData.append(pin)
        }
      }

      self.objectLocations = []
      self.selectedObject = huntData.objectType ?? .coin
    }
  }
}
