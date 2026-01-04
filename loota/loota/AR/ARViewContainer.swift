// ARViewContainer.swift

import ARKit
import CoreLocation
import Foundation
import RealityKit
import SwiftUI
import UIKit

extension CLLocationDirection {
  public var degreesToRadians: Double { return self * .pi / 180 }
}

public struct ARViewContainer: UIViewRepresentable {
  @Binding public var objectLocations: [CLLocationCoordinate2D]
  public var referenceLocation: CLLocationCoordinate2D?
  @Binding public var statusMessage: String
  @Binding public var heading: CLHeading?
  public var onCoinCollected: ((String) -> Void)?
  @Binding public var objectType: ARObjectType
  @Binding public var currentHuntType: HuntType?
  @Binding public var proximityMarkers: [ProximityMarkerData]
  @Binding public var pinData: [PinData]
  @Binding public var isSummoningActive: Bool
  @Binding public var focusedLootId: String?
  @Binding public var focusedLootDistance: Float?
  @Binding public var nearestLootDistance: Float?
  @Binding public var nearestLootDirection: Float
  @Binding public var isDebugMode: Bool
  @Binding public var showHorizonLine: Bool
  @Binding public var isPerformanceMode: Bool
  @Binding public var isLoadingModels: Bool

  public init(
    objectLocations: Binding<[CLLocationCoordinate2D]>,
    referenceLocation: CLLocationCoordinate2D?,
    statusMessage: Binding<String>,
    heading: Binding<CLHeading?>,
    onCoinCollected: ((String) -> Void)? = nil,
    objectType: Binding<ARObjectType>,
    currentHuntType: Binding<HuntType?>,
    proximityMarkers: Binding<[ProximityMarkerData]>,
    pinData: Binding<[PinData]>,
    isSummoningActive: Binding<Bool>,
    focusedLootId: Binding<String?>,
    focusedLootDistance: Binding<Float?>,
    nearestLootDistance: Binding<Float?>,
    nearestLootDirection: Binding<Float>,
    isDebugMode: Binding<Bool>,
    showHorizonLine: Binding<Bool>,
    isPerformanceMode: Binding<Bool>,
    isLoadingModels: Binding<Bool>
  ) {
    print(
      "ARViewContainer init: objectType=\(objectType.wrappedValue.rawValue), objectLocations.count=\(objectLocations.wrappedValue.count), refLocation=\(String(describing: referenceLocation)), heading=\(String(describing: heading.wrappedValue?.trueHeading)), huntType=\(String(describing: currentHuntType.wrappedValue)), proximityMarkers.count=\(proximityMarkers.wrappedValue.count))"
    )
    self._objectLocations = objectLocations
    self.referenceLocation = referenceLocation
    self._statusMessage = statusMessage
    self._heading = heading
    self.onCoinCollected = onCoinCollected
    self._objectType = objectType
    self._currentHuntType = currentHuntType
    self._proximityMarkers = proximityMarkers
    self._pinData = pinData
    self._isSummoningActive = isSummoningActive
    self._focusedLootId = focusedLootId
    self._focusedLootDistance = focusedLootDistance
    self._nearestLootDistance = nearestLootDistance
    self._nearestLootDirection = nearestLootDirection
    self._isDebugMode = isDebugMode
    self._showHorizonLine = showHorizonLine
    self._isPerformanceMode = isPerformanceMode
    self._isLoadingModels = isLoadingModels
  }

  // MARK: - UIViewRepresentable Methods

  public func makeUIView(context: Context) -> ARView {
    print("🎬 AR_SETUP: ========== makeUIView START ==========")
    let setupStartTime = CACurrentMediaTime()

    // CRITICAL FIX: Reset placement flag when creating new ARView
    context.coordinator.hasPlacedObjects = false
    print("🔧 AR_SETUP: Reset hasPlacedObjects to false for new ARView")

    // CRITICAL FIX: Create ARView with explicit frame to avoid layout calculations
    let screenBounds = UIScreen.main.bounds
    let arView = ARView(frame: screenBounds)
    let creationTime = CACurrentMediaTime() - setupStartTime
    print("🎥 AR_SETUP: ARView instance created (\(String(format: "%.3f", creationTime))s)")

    if creationTime > 1.0 {
      print("⚠️ AR_SETUP: ARView creation took >1s - this is abnormally slow!")
      print("⚠️ AR_SETUP: Check if app is backgrounded or resources are constrained")
    }

    // CRITICAL FIX: Ensure camera feed is rendered with minimal options
    arView.renderOptions = []  // Start with NO render options to minimize overhead
    arView.environment.background = .cameraFeed()
    print("🎥 AR_SETUP: Camera feed background configured (\(String(format: "%.3f", CACurrentMediaTime() - setupStartTime))s)")

    // Ensure ARView resizes correctly with the container
    arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // Configure AR session for world tracking with MINIMAL features initially
    let worldConfig = ARWorldTrackingConfiguration()
    worldConfig.worldAlignment = .gravityAndHeading
    worldConfig.environmentTexturing = .none  // Disable initially for faster startup
    worldConfig.planeDetection = []  // Disable plane detection initially for faster startup
    // Don't set frameSemantics - use default (no scene depth) for better performance

    print("🎥 AR_SETUP: AR configuration created (\(String(format: "%.3f", CACurrentMediaTime() - setupStartTime))s)")

    // Assign the coordinator as the session delegate
    arView.session.delegate = context.coordinator
    context.coordinator.arView = arView
    print("🎥 AR_SETUP: Coordinator assigned (\(String(format: "%.3f", CACurrentMediaTime() - setupStartTime))s)")

    // Check if AR World Tracking is supported on this device
    if ARWorldTrackingConfiguration.isSupported {
      print("🎥 AR_SETUP: AR World Tracking SUPPORTED - starting session...")
      context.coordinator.statusMessage = "Starting AR camera..."

      // Verify configuration is valid
      print("🎥 AR_SETUP: Config - worldAlignment: gravityAndHeading, environmentTexturing: none, planeDetection: []")

      // Start session with minimal options
      arView.session.run(worldConfig, options: [])

      let sessionStartTime = CACurrentMediaTime() - setupStartTime
      print("🎥 AR_SETUP: ✅ Session.run() called (\(String(format: "%.3f", sessionStartTime))s)")
      print("🎥 AR_SETUP: ========== makeUIView COMPLETE ==========")

      // Monitor session state
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        if let frame = arView.session.currentFrame {
          print("🎥 AR_MONITOR: ✅ Camera frame available after 1s, tracking: \(context.coordinator.trackingStateDescription(frame.camera.trackingState))")
        } else {
          print("❌ AR_MONITOR: NO camera frame after 1s - session may have failed")
          print("❌ AR_MONITOR: Check camera permissions and AR session delegates")
        }
      }

      // Wait for camera to stabilize before attempting placement
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        if let frame = arView.session.currentFrame {
          print("🎥 AR_SETUP: Attempting object placement after 3s delay")
          context.coordinator.statusMessage = "AR Ready - Looking for objects..."
          context.coordinator.attemptPlacementIfReady()
        } else {
          print("❌ AR_SETUP: STILL NO camera frame after 3s - AR session failed")
          context.coordinator.statusMessage = "AR camera not responding"
        }
      }
    } else {
      print("❌ AR_SETUP: AR World Tracking NOT SUPPORTED on this device")
      context.coordinator.statusMessage = "AR not supported on this device"
    }

    // Setup display link for animations
    let displayLink = CADisplayLink(
      target: context.coordinator, selector: #selector(Coordinator.updateRotation))
    displayLink.add(to: .main, forMode: .default)

    // Assign callbacks and initial properties to coordinator
    context.coordinator.onCoinCollected = self.onCoinCollected
    context.coordinator.revolutionDuration = 1.5  // Example duration

    return arView
  }

  public func updateUIView(_ uiView: ARView, context: Context) {
    // DIAGNOSTIC: Track how often this is called
    context.coordinator.updateUIViewCount += 1
    let count = context.coordinator.updateUIViewCount
    if count <= 10 || count % 10 == 0 {
      print("🔄 UPDATE_UI_VIEW: Called #\(count)")
    }

    // Explicitly update Coordinator's copy of referenceLocation if it changed
    if context.coordinator.referenceLocation?.latitude != self.referenceLocation?.latitude
      || context.coordinator.referenceLocation?.longitude != self.referenceLocation?.longitude
    {
      context.coordinator.referenceLocation = self.referenceLocation
      print("🔄 UPDATE_UI_VIEW: Reference location updated")
    }

    context.coordinator.onCoinCollected = self.onCoinCollected

    let oldCoordHeading = context.coordinator.heading?.trueHeading
    let newStructHeading = self.heading?.trueHeading
    if oldCoordHeading != newStructHeading {
      context.coordinator.heading = self.heading
      print("🔄 UPDATE_UI_VIEW: Heading updated to \(String(describing: newStructHeading))")
    }

    // CRITICAL: Only attempt placement if session is running
    if uiView.session.currentFrame != nil {
      context.coordinator.attemptPlacementIfReady()
    } else if count <= 10 {
      print("⚠️ UPDATE_UI_VIEW: Skipping placement - no AR frame available yet")
    }

    let debugOptions: ARView.DebugOptions = context.coordinator.isDebugMode
      ? [.showWorldOrigin, .showFeaturePoints]
      : []
    if uiView.debugOptions != debugOptions {
      uiView.debugOptions = debugOptions
    }
  }

  public func makeCoordinator() -> Coordinator {
    // Initialize coordinator with the initial wrapped value of referenceLocation
    let coordinator = Coordinator(
      initialReferenceLocation: self.referenceLocation,  // Pass direct value
      objectLocations: $objectLocations,
      objectType: $objectType,
      statusMessage: $statusMessage,
      currentHuntType: $currentHuntType,  // Pass binding
      proximityMarkers: $proximityMarkers,  // Pass binding
      pinData: $pinData,
      isSummoningActive: $isSummoningActive,
      focusedLootId: $focusedLootId,
      focusedLootDistance: $focusedLootDistance,
      nearestLootDistance: $nearestLootDistance,
      nearestLootDirection: $nearestLootDirection,
      isDebugMode: $isDebugMode,
      showHorizonLine: $showHorizonLine,
      isPerformanceMode: $isPerformanceMode,
      isLoadingModels: $isLoadingModels
    )
    coordinator.placeObjectsAction = coordinator.placeObjectsInARView
    return coordinator
  }
}
