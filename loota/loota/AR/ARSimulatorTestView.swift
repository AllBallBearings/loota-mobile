// ARSimulatorTestView.swift
// Complete AR simulator test harness that combines the simulated AR view
// with on-screen controls and mock hunt data for end-to-end testing
// without physical hardware.

import CoreLocation
import SwiftUI

// MARK: - Mock Hunt Data

enum MockHuntScenario: String, CaseIterable, Identifiable {
  case proximitySmall = "Proximity (3 coins nearby)"
  case proximityLarge = "Proximity (10 coins spread)"
  case geolocationCluster = "Geolocation (cluster)"
  case geolocationSpread = "Geolocation (spread out)"
  case mixedObjectTypes = "Mixed object types"
  case singleCoin = "Single coin (simple)"

  var id: String { rawValue }

  var huntType: HuntType {
    switch self {
    case .proximitySmall, .proximityLarge:
      return .proximity
    case .geolocationCluster, .geolocationSpread, .mixedObjectTypes, .singleCoin:
      return .geolocation
    }
  }

  var objectType: ARObjectType {
    switch self {
    case .mixedObjectTypes:
      return .coin // Individual pins override this
    default:
      return .coin
    }
  }

  // Reference location (simulated user position)
  var referenceLocation: CLLocationCoordinate2D {
    // Central Park, New York (arbitrary but realistic)
    CLLocationCoordinate2D(latitude: 40.7829, longitude: -73.9654)
  }

  var pins: [PinData] {
    switch self {
    case .singleCoin:
      return [
        PinData(id: "pin-single-01", huntId: "mock-hunt", lat: 40.7829, lng: -73.9654 + 0.00003,
                distanceFt: nil, directionStr: nil, order: 0, collectedByUserId: nil, objectType: .coin)
      ]

    case .proximitySmall:
      return [
        PinData(id: "pin-prox-01", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 10, directionStr: "N", order: 0, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-02", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 15, directionStr: "N45E", order: 1, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-03", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 8, directionStr: "S30W", order: 2, collectedByUserId: nil, objectType: .coin),
      ]

    case .proximityLarge:
      return [
        PinData(id: "pin-prox-01", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 5, directionStr: "N", order: 0, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-02", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 10, directionStr: "N45E", order: 1, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-03", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 8, directionStr: "E", order: 2, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-04", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 12, directionStr: "S45E", order: 3, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-05", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 6, directionStr: "S", order: 4, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-06", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 15, directionStr: "S45W", order: 5, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-07", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 9, directionStr: "W", order: 6, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-08", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 11, directionStr: "N45W", order: 7, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-09", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 20, directionStr: "N20E", order: 8, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-prox-10", huntId: "mock-hunt", lat: nil, lng: nil,
                distanceFt: 18, directionStr: "S70W", order: 9, collectedByUserId: nil, objectType: .coin),
      ]

    case .geolocationCluster:
      let baseLat = 40.7829
      let baseLng = -73.9654
      // Objects within ~3-5 meters of reference
      return [
        PinData(id: "pin-geo-01", huntId: "mock-hunt", lat: baseLat + 0.00003, lng: baseLng + 0.00002,
                distanceFt: nil, directionStr: nil, order: 0, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-02", huntId: "mock-hunt", lat: baseLat - 0.00002, lng: baseLng + 0.00003,
                distanceFt: nil, directionStr: nil, order: 1, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-03", huntId: "mock-hunt", lat: baseLat + 0.00001, lng: baseLng - 0.00004,
                distanceFt: nil, directionStr: nil, order: 2, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-04", huntId: "mock-hunt", lat: baseLat - 0.00004, lng: baseLng - 0.00001,
                distanceFt: nil, directionStr: nil, order: 3, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-05", huntId: "mock-hunt", lat: baseLat + 0.00002, lng: baseLng + 0.00005,
                distanceFt: nil, directionStr: nil, order: 4, collectedByUserId: nil, objectType: .coin),
      ]

    case .geolocationSpread:
      let baseLat = 40.7829
      let baseLng = -73.9654
      // Objects spread 10-30 meters from reference
      return [
        PinData(id: "pin-geo-01", huntId: "mock-hunt", lat: baseLat + 0.0001, lng: baseLng,
                distanceFt: nil, directionStr: nil, order: 0, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-02", huntId: "mock-hunt", lat: baseLat, lng: baseLng + 0.00015,
                distanceFt: nil, directionStr: nil, order: 1, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-03", huntId: "mock-hunt", lat: baseLat - 0.00012, lng: baseLng - 0.0001,
                distanceFt: nil, directionStr: nil, order: 2, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-geo-04", huntId: "mock-hunt", lat: baseLat + 0.00008, lng: baseLng - 0.00012,
                distanceFt: nil, directionStr: nil, order: 3, collectedByUserId: nil, objectType: .coin),
      ]

    case .mixedObjectTypes:
      let baseLat = 40.7829
      let baseLng = -73.9654
      return [
        PinData(id: "pin-mix-01", huntId: "mock-hunt", lat: baseLat + 0.00003, lng: baseLng,
                distanceFt: nil, directionStr: nil, order: 0, collectedByUserId: nil, objectType: .coin),
        PinData(id: "pin-mix-02", huntId: "mock-hunt", lat: baseLat, lng: baseLng + 0.00004,
                distanceFt: nil, directionStr: nil, order: 1, collectedByUserId: nil, objectType: .dollarSign),
        PinData(id: "pin-mix-03", huntId: "mock-hunt", lat: baseLat - 0.00003, lng: baseLng - 0.00002,
                distanceFt: nil, directionStr: nil, order: 2, collectedByUserId: nil, objectType: .giftCard),
        PinData(id: "pin-mix-04", huntId: "mock-hunt", lat: baseLat + 0.00002, lng: baseLng - 0.00004,
                distanceFt: nil, directionStr: nil, order: 3, collectedByUserId: nil, objectType: .coin),
      ]
    }
  }

  var objectLocations: [CLLocationCoordinate2D] {
    guard huntType == .geolocation else { return [] }
    return pins.compactMap { pin in
      guard let lat = pin.lat, let lng = pin.lng else { return nil }
      return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
  }

  var proximityMarkers: [ProximityMarkerData] {
    guard huntType == .proximity else { return [] }
    return pins.compactMap { pin in
      guard let distFt = pin.distanceFt, let dir = pin.directionStr else { return nil }
      let distMeters = distFt * 0.3048
      return ProximityMarkerData(dist: distMeters, dir: dir)
    }
  }
}

// MARK: - AR Simulator Test View

struct ARSimulatorTestView: View {
  @State private var selectedScenario: MockHuntScenario = .proximitySmall
  @State private var showScenarioSelector = false
  @State private var coinsCollected = 0
  @State private var totalCoins = 0

  // Hunt state
  @State private var objectLocations: [CLLocationCoordinate2D] = []
  @State private var statusMessage: String = ""
  @State private var heading: CLHeading? = nil
  @State private var objectType: ARObjectType = .coin
  @State private var currentHuntType: HuntType? = nil
  @State private var proximityMarkers: [ProximityMarkerData] = []
  @State private var pinData: [PinData] = []
  @State private var isSummoningActive: Bool = false
  @State private var focusedLootId: String? = nil
  @State private var focusedLootDistance: Float? = nil
  @State private var nearestLootDistance: Float? = nil
  @State private var nearestLootDirection: Float = 0
  @State private var isDebugMode: Bool = true
  @State private var showHorizonLine: Bool = false
  @State private var isPerformanceMode: Bool = false
  @State private var isLoadingModels: Bool = false
  @State private var debugObjectTypeOverride: ARObjectType? = nil

  // Camera controller
  @StateObject private var cameraController = SimulatedCameraController()

  // Joystick inputs
  @State private var moveX: Float = 0
  @State private var moveZ: Float = 0
  @State private var lookX: Float = 0
  @State private var lookY: Float = 0

  // Display link for camera updates
  @State private var displayLink: CADisplayLink?

  @SwiftUI.Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      // Simulated AR View
      SimulatedARViewContainer(
        objectLocations: $objectLocations,
        referenceLocation: selectedScenario.referenceLocation,
        statusMessage: $statusMessage,
        heading: $heading,
        onCoinCollected: { pinId in
          coinsCollected += 1
          print("[SIM TEST] Collected pin: \(pinId) (\(coinsCollected)/\(totalCoins))")
        },
        objectType: $objectType,
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
        debugObjectTypeOverride: $debugObjectTypeOverride,
        simulatedCameraYaw: $cameraController.yaw,
        simulatedCameraPitch: $cameraController.pitch,
        simulatedCameraX: $cameraController.positionX,
        simulatedCameraY: $cameraController.positionY,
        simulatedCameraZ: $cameraController.positionZ
      )
      .edgesIgnoringSafeArea(.all)

      // Status overlay
      VStack {
        // Top bar
        HStack {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
              .font(.title2)
              .foregroundColor(.white.opacity(0.7))
          }

          Spacer()

          // Collection counter
          HStack(spacing: 4) {
            Image(systemName: "star.circle.fill")
              .foregroundColor(.yellow)
            Text("\(coinsCollected)/\(totalCoins)")
              .font(.system(size: 14, weight: .bold, design: .monospaced))
              .foregroundColor(.white)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.black.opacity(0.6))
          .cornerRadius(20)

          Spacer()

          // Scenario selector
          Button(action: { showScenarioSelector = true }) {
            HStack(spacing: 4) {
              Image(systemName: "list.bullet")
              Text("Scenario")
                .font(.system(size: 12))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.5))
            .cornerRadius(8)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        // Status message
        if !statusMessage.isEmpty {
          Text(statusMessage)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .padding(.top, 4)
        }

        // Loading indicator
        if isLoadingModels {
          HStack(spacing: 8) {
            ProgressView()
              .tint(.white)
            Text("Loading 3D models...")
              .font(.system(size: 12))
              .foregroundColor(.white.opacity(0.8))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.black.opacity(0.7))
          .cornerRadius(8)
        }

        Spacer()
      }

      // Controls overlay
      SimulatedARControlPanel(
        moveX: $moveX,
        moveZ: $moveZ,
        lookX: $lookX,
        lookY: $lookY,
        cameraHeight: $cameraController.positionY,
        isSummoningActive: $isSummoningActive,
        cameraYaw: cameraController.yaw,
        cameraPitch: cameraController.pitch,
        cameraX: cameraController.positionX,
        cameraZ: cameraController.positionZ,
        focusedLootId: focusedLootId,
        focusedLootDistance: focusedLootDistance
      )
    }
    .onAppear {
      loadScenario(selectedScenario)
      startCameraUpdateLoop()
    }
    .onDisappear {
      stopCameraUpdateLoop()
    }
    .onChange(of: moveX) { newVal in cameraController.moveInputX = newVal }
    .onChange(of: moveZ) { newVal in cameraController.moveInputZ = newVal }
    .onChange(of: lookX) { newVal in cameraController.lookInputX = newVal }
    .onChange(of: lookY) { newVal in cameraController.lookInputY = newVal }
    .sheet(isPresented: $showScenarioSelector) {
      scenarioSelectorSheet
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Scenario Selector

  private var scenarioSelectorSheet: some View {
    NavigationView {
      List(MockHuntScenario.allCases) { scenario in
        Button(action: {
          selectedScenario = scenario
          loadScenario(scenario)
          showScenarioSelector = false
        }) {
          VStack(alignment: .leading, spacing: 4) {
            Text(scenario.rawValue)
              .font(.body)
              .foregroundColor(.primary)
            Text("Type: \(scenario.huntType.rawValue) | \(scenario.pins.count) pins")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
      .navigationTitle("Test Scenarios")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Cancel") { showScenarioSelector = false }
        }
      }
    }
  }

  // MARK: - Scenario Loading

  private func loadScenario(_ scenario: MockHuntScenario) {
    // Reset state
    coinsCollected = 0
    isSummoningActive = false
    focusedLootId = nil
    focusedLootDistance = nil
    cameraController.reset()

    // Load hunt data
    currentHuntType = scenario.huntType
    objectType = scenario.objectType
    pinData = scenario.pins
    objectLocations = scenario.objectLocations
    proximityMarkers = scenario.proximityMarkers
    totalCoins = scenario.pins.count

    statusMessage = "Loading \(scenario.rawValue)..."
    print("[SIM TEST] Loaded scenario: \(scenario.rawValue) with \(scenario.pins.count) pins")
  }

  // MARK: - Camera Update Loop

  private func startCameraUpdateLoop() {
    let link = CADisplayLink(target: CameraUpdateTarget(controller: cameraController, view: self),
                             selector: #selector(CameraUpdateTarget.update))
    link.add(to: .main, forMode: .default)
    displayLink = link
  }

  private func stopCameraUpdateLoop() {
    displayLink?.invalidate()
    displayLink = nil
  }
}

// Helper class to bridge CADisplayLink to camera controller (avoids @objc on struct)
private class CameraUpdateTarget: NSObject {
  weak var controller: SimulatedCameraController?
  var getInputs: (() -> (Float, Float, Float, Float))?

  init(controller: SimulatedCameraController, view: ARSimulatorTestView) {
    self.controller = controller
    super.init()
  }

  @objc func update(displayLink: CADisplayLink) {
    guard let controller = controller else { return }
    let deltaTime = Float(displayLink.duration)
    controller.update(deltaTime: deltaTime)
  }
}

// MARK: - Extension to feed joystick inputs to camera controller

extension ARSimulatorTestView {
  // Bridge joystick state to camera controller via onChange
  func updateCameraInputs() {
    cameraController.moveInputX = moveX
    cameraController.moveInputZ = moveZ
    cameraController.lookInputX = lookX
    cameraController.lookInputY = lookY
  }
}
