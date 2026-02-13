import ARKit
import AVFoundation
import CoreLocation
import Foundation
import RealityKit
import SwiftUI
import UIKit

extension ARViewContainer {
  public class Coordinator: NSObject, ARSessionDelegate {
    // referenceLocation is now a simple var, updated by ARViewContainer.updateUIView
    public var referenceLocation: CLLocationCoordinate2D?
    // These remain bindings
    @Binding public var objectLocations: [CLLocationCoordinate2D]
    @Binding public var objectType: ARObjectType
    @Binding public var statusMessage: String
    @Binding public var currentHuntType: HuntType?
    @Binding public var proximityMarkers: [ProximityMarkerData]
    @Binding public var pinData: [PinData]
    @Binding public var isSummoningActiveBinding: Bool
    @Binding public var focusedLootIdBinding: String?
    @Binding public var focusedLootDistanceBinding: Float?
    @Binding public var nearestLootDistanceBinding: Float?
    @Binding public var nearestLootDirectionBinding: Float
    @Binding public var isDebugMode: Bool
    @Binding public var showHorizonLineBinding: Bool
    @Binding public var isPerformanceMode: Bool
    @Binding public var isLoadingModels: Bool
    @Binding public var debugObjectTypeOverride: ARObjectType?

    public var onCoinCollected: ((String) -> Void)?
    public var coinEntities: [ModelEntity] = []
    public var baseOrientations: [ModelEntity: simd_quatf] = [:]
    public var anchors: [AnchorEntity] = []
    public var entityToPinId: [ModelEntity: String] = [:]
    public var revolutionDuration: TimeInterval = 1.5
    public var accumulatedAngle: Float = 0
    public var lastTimestamp: CFTimeInterval?
    var animationTime: Float = 0
    public weak var arView: ARView?
    public var audioPlayer: AVAudioPlayer?

    // Button-based summoning properties
    public var focusedEntity: ModelEntity? = nil
    public var focusRange: Float = 5.0
    public var summoningEntity: ModelEntity?
    public var originalEntityPosition: SIMD3<Float>?
    public var originalEntityScale: SIMD3<Float>?
    public var originalSummonDistance: Float?
    public var summonStartTime: CFTimeInterval?
    public let summonSpeed: Float = 0.8
    public let proximityThreshold: Float = 30.48
    public var collectedEntities: Set<ModelEntity> = []
    public var frameCounter: Int = 0
    public var lastFocusUpdateTime: Date = Date()
    public var wasSummoningActive: Bool = false

    // Base anchor for world alignment
    public var baseAnchor: AnchorEntity?

    // Horizon line properties
    public var horizonEntity: ModelEntity?
    public var isHorizonSetupInProgress: Bool = false

    // Compass arrow properties
    public var compassArrowEntity: ModelEntity?
    public var compassArrowAnchor: AnchorEntity?

    // FPS tracking for performance monitoring
    public var fpsCounter: Int = 0
    public var fpsLastUpdate: CFTimeInterval = 0
    public var currentFPS: Double = 0

    // Camera frame tracking for diagnostics
    public var cameraFrameCount: Int = 0
    public var lastCameraFrameTime: CFTimeInterval = 0
    public var cameraFPS: Double = 0

    // UpdateUIView tracking
    public var updateUIViewCount: Int = 0

    // Action to trigger object placement from the Coordinator
    public var placeObjectsAction: ((ARView?) -> Void)?

    // Properties for heading alignment
    public var heading: CLHeading? {
      didSet {
        let newTrueHeading = heading?.trueHeading
        let newAccuracy = heading?.headingAccuracy
        let oldTrueHeading = oldValue?.trueHeading
        let oldAccuracy = oldValue?.headingAccuracy

        print(
          "Coordinator heading.didSet: New heading: \(String(describing: newTrueHeading)) (acc: \(String(describing: newAccuracy))), Old: \(String(describing: oldTrueHeading)) (acc: \(String(describing: oldAccuracy))), hasAlignedToNorth: \(hasAlignedToNorth)"
        )

        // With .gravityAndHeading, ARKit automatically handles North alignment
        attemptPlacementIfReady()
      }
    }
    public var hasAlignedToNorth = false
    public var hasPlacedObjects = false
    public var didStartSession = false

    // Initializer - receives initial referenceLocation value and other bindings
    public init(
      initialReferenceLocation: CLLocationCoordinate2D?,
      objectLocations: Binding<[CLLocationCoordinate2D]>,
      objectType: Binding<ARObjectType>,
      statusMessage: Binding<String>,
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
      isLoadingModels: Binding<Bool>,
      debugObjectTypeOverride: Binding<ARObjectType?>
    ) {
      print("Coordinator init: Setting up.")
      self.referenceLocation = initialReferenceLocation
      self._objectLocations = objectLocations
      self._objectType = objectType
      self._statusMessage = statusMessage
      self._currentHuntType = currentHuntType
      self._proximityMarkers = proximityMarkers
      self._pinData = pinData
      self._isSummoningActiveBinding = isSummoningActive
      self._focusedLootIdBinding = focusedLootId
      self._focusedLootDistanceBinding = focusedLootDistance
      self._nearestLootDistanceBinding = nearestLootDistance
      self._nearestLootDirectionBinding = nearestLootDirection
      self._isDebugMode = isDebugMode
      self._showHorizonLineBinding = showHorizonLine
      self._isPerformanceMode = isPerformanceMode
      self._isLoadingModels = isLoadingModels
      self._debugObjectTypeOverride = debugObjectTypeOverride

      super.init()

      // Initialize focus detection system
      setupFocusDetection()

      print(
        "Coordinator init: Initial referenceLocation = \(String(describing: initialReferenceLocation)))"
      )
    }

    // Helper function for degree to radian conversion
    public static func degreesToRadians(_ degrees: Double) -> Double {
      return degrees * .pi / 180.0
    }

    public func attemptPlacementIfReady() {
      print(
        "Coordinator attemptPlacementIfReady: Checking conditions. referenceLocationIsNil=\(self.referenceLocation == nil), hasPlacedObjects=\(hasPlacedObjects), arViewIsNil=\(self.arView == nil)"
      )

      let needsCoinModel = (self.currentHuntType == .proximity) || (self.objectType == .coin)
      if needsCoinModel && CoinEntityFactory.shouldDeferPlacementForCoinModel {
        if !CoinEntityFactory.isCoinModelLoading {
          print("🪙 COIN_MODEL: Preloading USDZ before placement")
          self.isLoadingModels = true
          CoinEntityFactory.preloadCoinModel { [weak self] success in
            DispatchQueue.main.async {
              self?.isLoadingModels = false
              self?.attemptPlacementIfReady()
            }
          }
        } else {
          print("🪙 COIN_MODEL: Waiting for USDZ preload to finish")
          self.isLoadingModels = true
        }
        return
      }

      let needsGiftCardModel =
        (self.objectType == .giftCard)
        || self.pinData.contains(where: { $0.objectType == .giftCard })
      if needsGiftCardModel && GiftCardEntityFactory.shouldDeferPlacementForGiftCardModel {
        if !GiftCardEntityFactory.isGiftCardModelLoading {
          print("🎁 GIFTCARD_MODEL: Preloading USDZ before placement")
          self.isLoadingModels = true
          GiftCardEntityFactory.preloadGiftCardModel { [weak self] success in
            DispatchQueue.main.async {
              self?.isLoadingModels = false
              self?.attemptPlacementIfReady()
            }
          }
        } else {
          print("🎁 GIFTCARD_MODEL: Waiting for USDZ preload to finish")
          self.isLoadingModels = true
        }
        return
      }

      guard self.referenceLocation != nil, !hasPlacedObjects,
        let arView = self.arView
      else {
        print("Coordinator attemptPlacementIfReady: Conditions not met or already placed.")
        return
      }

      print("Coordinator attemptPlacementIfReady: All conditions MET.")

      // CRITICAL FIX: Ensure baseAnchor exists BEFORE placing objects
      print("🔧 PLACEMENT_FIX: Ensuring baseAnchor exists before object placement...")
      self.ensureBaseAnchorExists(in: arView)

      // Verify baseAnchor was created
      if self.baseAnchor != nil {
        print("🔧 PLACEMENT_FIX: ✅ BaseAnchor confirmed - proceeding with placement")
      } else {
        print("🔧 PLACEMENT_FIX: ❌ BaseAnchor still nil - placement will fail!")
      }

      // CRITICAL FIX: Place objects asynchronously to prevent freezing
      print("🔧 PLACEMENT_FIX: Starting ASYNC object placement...")
      self.hasPlacedObjects = true
      self.placeObjectsAsync(arView: arView)
    }

    // Wrapper function to match the expected signature for placeObjectsAction
    public func placeObjectsInARView(arView: ARView?) {
      guard let arView = arView else {
        print("Coordinator placeObjectsInARView: arView is nil.")
        return
      }
      self.placeObjectsAsync(arView: arView)
    }
  }
}
