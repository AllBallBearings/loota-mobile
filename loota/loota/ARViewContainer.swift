// ARViewContainer.swift

import ARKit
import AVFoundation
import Combine  // Import Combine for sink
import CoreLocation
//import DataModels  // Import DataModels to access ARObjectType, HuntType, ProximityMarkerData
import Foundation  // For UUID
import RealityKit
import SwiftUI
import UIKit
// Removed Vision import - no longer using hand tracking

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
  @Binding public var isDebugMode: Bool
  @Binding public var showHorizonLine: Bool

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
    isDebugMode: Binding<Bool>,
    showHorizonLine: Binding<Bool>
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
    self._isDebugMode = isDebugMode
    self._showHorizonLine = showHorizonLine
  }

  // MARK: - UIViewRepresentable Methods

  public func makeUIView(context: Context) -> ARView {
    print("ARViewContainer makeUIView called.")

    // CRITICAL FIX: Reset placement flag when creating new ARView
    // This allows objects to be placed again if the view is recreated
    context.coordinator.hasPlacedObjects = false
    print("🔧 AR_SETUP: Reset hasPlacedObjects to false for new ARView")

    let arView = ARView(frame: .zero)

    // CRITICAL FIX: Ensure camera feed is rendered
    arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
    arView.environment.background = .cameraFeed()

    print("🎥 AR_SETUP: ARView created with camera feed background")

    // Configure AR session for world tracking
    let worldConfig = ARWorldTrackingConfiguration()
    worldConfig.worldAlignment = .gravityAndHeading  // Let ARKit automatically align to North
    worldConfig.environmentTexturing = .automatic
    worldConfig.planeDetection = [.horizontal, .vertical]  // Keep plane detection if needed

    // Assign the coordinator as the session delegate
    arView.session.delegate = context.coordinator
    context.coordinator.arView = arView  // Assign weak reference

    // Check if AR World Tracking is supported on this device
    if ARWorldTrackingConfiguration.isSupported {
      print("ARViewContainer: AR World Tracking is supported. Starting AR session...")
      context.coordinator.statusMessage = "Starting AR camera..."
      // Start the AR session immediately to show camera feed
      // Object placement will wait for North alignment, but camera should be visible
      arView.session.run(worldConfig, options: [])

      // Update status after a short delay to allow AR to initialize
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        context.coordinator.statusMessage = "AR Ready - Looking for objects..."
        // Automatically attempt to place objects after AR initializes
        context.coordinator.attemptPlacementIfReady()
      }
    } else {
      print("ARViewContainer: AR World Tracking is NOT supported on this device.")
      context.coordinator.statusMessage = "AR not supported on this device"
    }

    // Setup display link for animations
    let displayLink = CADisplayLink(
      target: context.coordinator, selector: #selector(Coordinator.updateRotation))
    displayLink.add(to: .main, forMode: .default)

    // Assign callbacks and initial properties to coordinator
    context.coordinator.onCoinCollected = self.onCoinCollected
    context.coordinator.revolutionDuration = 1.5  // Example duration

    // The Coordinator is initialized with all necessary bindings and actions in makeCoordinator().
    // Re-assigning them in makeUIView is generally redundant.
    // placeObjectsAction is set in makeCoordinator and captures the necessary bindings.

    // Initial placement of objects will be triggered via attemptPlacementIfReady
    // once heading is available and alignment is done.
    // Removed direct call to placeObjectsInARView(arView: arView) from here.

    return arView
  }

  public func updateUIView(_ uiView: ARView, context: Context) {
    print(
      "ARViewContainer updateUIView: Called. Struct's refLoc=\(String(describing: referenceLocation)), Struct's heading=\(String(describing: heading?.trueHeading))"
    )
    // Explicitly update Coordinator's copy of referenceLocation if it changed in the struct's binding
    if context.coordinator.referenceLocation?.latitude != self.referenceLocation?.latitude
      || context.coordinator.referenceLocation?.longitude != self.referenceLocation?.longitude
    {
      context.coordinator.referenceLocation = self.referenceLocation
      print(
        "ARViewContainer updateUIView: Updated coordinator.referenceLocation to \(String(describing: self.referenceLocation))"
      )
    }
    print(
      "ARViewContainer updateUIView: Coordinator's refLoc after potential update=\(String(describing: context.coordinator.referenceLocation)), Coord's heading=\(String(describing: context.coordinator.heading?.trueHeading))"
    )

    context.coordinator.onCoinCollected = self.onCoinCollected

    let oldCoordHeading = context.coordinator.heading?.trueHeading
    let newStructHeading = self.heading?.trueHeading
    if oldCoordHeading != newStructHeading {
      context.coordinator.heading = self.heading
      print(
        "ARViewContainer updateUIView: Updated coordinator.heading to \(String(describing: newStructHeading))"
      )
    }

    context.coordinator.attemptPlacementIfReady()

    // beyond what @Binding provides, that would be handled here or via Combine publishers.
    // For now, the Coordinator's heading.didSet is the main trigger for initial placement.
    // The assignment context.coordinator.heading = self.heading is already handled earlier
    // if oldCoordHeading != newStructHeading.
    // Removing redundant assignment:
    // if let heading = self.heading {
    //     context.coordinator.heading = heading
    // }
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
      isDebugMode: $isDebugMode,
      showHorizonLine: $showHorizonLine
    )
    // Set the placeObjectsAction on the newly created coordinator instance
    // The coordinator&#x27;s placeObjectsAction will call its own placeObjectsInARView method.
    coordinator.placeObjectsAction = coordinator.placeObjectsInARView
    return coordinator
  }

  // placeObjects, createEntity, convertToARWorldCoordinate are now moved to Coordinator

  // MARK: - Coordinator Class

  public class Coordinator: NSObject, ARSessionDelegate {
    // referenceLocation is now a simple var, updated by ARViewContainer.updateUIView
    public var referenceLocation: CLLocationCoordinate2D?
    // These remain bindings
    @Binding public var objectLocations: [CLLocationCoordinate2D]
    @Binding public var objectType: ARObjectType
    @Binding public var statusMessage: String
    @Binding public var currentHuntType: HuntType?  // Added binding
    @Binding public var proximityMarkers: [ProximityMarkerData]  // Added binding
    @Binding public var pinData: [PinData]
    @Binding public var isSummoningActiveBinding: Bool
    @Binding public var focusedLootIdBinding: String?
    @Binding public var focusedLootDistanceBinding: Float?
    @Binding public var isDebugMode: Bool
    @Binding public var showHorizonLineBinding: Bool
    // Removed the redundant @Binding for heading here. We use the simple var heading below.

    public var onCoinCollected: ((String) -> Void)?
    public var coinEntities: [ModelEntity] = []
    public var anchors: [AnchorEntity] = []
    public var entityToPinId: [ModelEntity: String] = [:]  // Map entities to their pin IDs
    public var revolutionDuration: TimeInterval = 1.5
    public var accumulatedAngle: Float = 0
    public var lastTimestamp: CFTimeInterval?
    public weak var arView: ARView?
    public var audioPlayer: AVAudioPlayer?  // Moved audio player here

    // Button-based summoning properties
    public var focusedEntity: ModelEntity? = nil
    public var focusRange: Float = 5.0  // 5 meters focus range
    public var summoningEntity: ModelEntity?
    public var originalEntityPosition: SIMD3<Float>?
    public var summonStartTime: CFTimeInterval?
    public let summonSpeed: Float = 0.8  // Meters per second - faster, more dramatic movement
    public let proximityThreshold: Float = 30.48  // 100 feet in meters
    public var collectedEntities: Set<ModelEntity> = []  // Track collected entities
    public var frameCounter: Int = 0
    // Focus detection properties
    public var lastFocusUpdateTime: Date = Date()
    // Removed hand position tracking

    // Hand visualization properties removed - no longer needed

    // Base anchor for world alignment
    public var baseAnchor: AnchorEntity?

    // Horizon line properties
    public var horizonEntity: ModelEntity?

    // Action to trigger object placement from the Coordinator
    public var placeObjectsAction: ((ARView?) -> Void)?  // This will be set to self.placeObjectsInARView

    // Properties for heading alignment
    public var heading: CLHeading? {  // Observe heading changes
      didSet {
        let newTrueHeading = heading?.trueHeading
        let newAccuracy = heading?.headingAccuracy
        let oldTrueHeading = oldValue?.trueHeading
        let oldAccuracy = oldValue?.headingAccuracy

        print(
          "Coordinator heading.didSet: New heading: \(String(describing: newTrueHeading)) (acc: \(String(describing: newAccuracy))), Old: \(String(describing: oldTrueHeading)) (acc: \(String(describing: oldAccuracy))), hasAlignedToNorth: \(hasAlignedToNorth)"
        )

        // With .gravityAndHeading, ARKit automatically handles North alignment
        // Just attempt placement if conditions are ready
        attemptPlacementIfReady()
      }
    }
    public var hasAlignedToNorth = false  // True when user is physically pointing North with good accuracy.
    public var hasPlacedObjects = false  // New flag to ensure placement happens only once

    // Combine cancellables for observing changes
    public var cancellables: Set<AnyCancellable> = []

    // GPS conversion constants
    public let metersPerDegree: Double = 111319.5

    // Initializer - receives initial referenceLocation value and other bindings
    public init(
      initialReferenceLocation: CLLocationCoordinate2D?,  // Changed from Binding
      objectLocations: Binding<[CLLocationCoordinate2D]>,
      objectType: Binding<ARObjectType>,
      statusMessage: Binding<String>,
      currentHuntType: Binding<HuntType?>,  // Added parameter
      proximityMarkers: Binding<[ProximityMarkerData]>,
      pinData: Binding<[PinData]>,
      isSummoningActive: Binding<Bool>,
      focusedLootId: Binding<String?>,
      focusedLootDistance: Binding<Float?>,
      isDebugMode: Binding<Bool>,
      showHorizonLine: Binding<Bool>
    ) {
      print("Coordinator init: Setting up.")
      self.referenceLocation = initialReferenceLocation  // Assign initial value
      self._objectLocations = objectLocations
      self._objectType = objectType
      self._statusMessage = statusMessage
      self._currentHuntType = currentHuntType  // Assign binding
      self._proximityMarkers = proximityMarkers  // Assign binding
      self._pinData = pinData
      self._isSummoningActiveBinding = isSummoningActive
      self._focusedLootIdBinding = focusedLootId
      self._focusedLootDistanceBinding = focusedLootDistance
      self._isDebugMode = isDebugMode
      self._showHorizonLineBinding = showHorizonLine

      // Removed problematic referenceLocationObserver

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
      
      // Now place objects
      self.placeObjectsAction?(arView)  // This will call placeObjectsInARView
      self.hasPlacedObjects = true  // Mark as placed
    }

    // Wrapper function to match the expected signature for placeObjectsAction
    public func placeObjectsInARView(arView: ARView?) {
      guard let arView = arView else {
        print("Coordinator placeObjectsInARView: arView is nil.")
        return
      }
      // Now call the main placement logic, using the Coordinator's own bindings
      self.placeObjects(arView: arView)
    }

    // Main object placement logic, now using Coordinator's bindings
    private func placeObjects(arView: ARView) {
      print(
        "Coordinator placeObjects: Checking referenceLocation. Current referenceLocation = \(String(describing: self.referenceLocation))"
      )
      guard let refLoc = self.referenceLocation else {
        print("Coordinator placeObjects: Guard FAILED - self.referenceLocation is nil.")
        return
      }

      self.clearAnchors()

      var newEntities: [ModelEntity] = []
      var newAnchors: [AnchorEntity] = []

      // Check the hunt type
      switch self.currentHuntType {  // Access wrapped value directly
      case .geolocation:
        print("Coordinator placeObjects: Handling Geolocation hunt.")
        guard !self.objectLocations.isEmpty else {  // Access wrapped value directly
          print(
            "Coordinator placeObjects: Guard FAILED - objectLocations is empty for geolocation hunt."
          )
          return
        }
        guard self.objectType != .none else {  // Access wrapped value directly
          print(
            "Coordinator placeObjects: Guard FAILED - objectType is .none for geolocation hunt.")
          return
        }

        print(
          "Coordinator placeObjects: Placing \(self.objectLocations.count) objects of type \(self.objectType.rawValue)"
        )  // Access wrapped values directly

        for (index, location) in self.objectLocations.enumerated() {  // Iterate with index
          print("Coordinator placeObjects: Processing location \(index + 1): \(location)")
          let arPositionInBaseFrame = convertToARWorldCoordinate(
            objectLocation: location, referenceLocation: refLoc)

          let objectAnchor = AnchorEntity()
          objectAnchor.position = arPositionInBaseFrame

          // Get pin data for this index (moved before entity creation)
          let pin = index < self.pinData.count ? self.pinData[index] : nil
          let markerNumber = (pin?.order ?? index) + 1
          let pinId = pin?.id ?? "unknown"
          let shortId = pinId.prefix(8)

          // Use pin's objectType if available, otherwise fall back to default
          let lootType = pin?.objectType ?? self.objectType
          guard let entity = createEntity(for: lootType) else { continue }
          objectAnchor.addChild(entity)

          // Store the mapping between entity and pin ID
          self.entityToPinId[entity] = pinId
          self.coinEntities.append(entity)

          // Add labels only in debug mode
          if self.isDebugMode {
            // Add marker number label
            let numberLabel = createLabelEntity(text: "\(markerNumber)")
            numberLabel.position = [0, 0.25, 0]  // Higher position for number
            objectAnchor.addChild(numberLabel)

            // Add ID label
            let idLabel = createLabelEntity(text: String(shortId))
            idLabel.position = [0, 0.1, 0]  // Lower position for ID
            objectAnchor.addChild(idLabel)
          }

          print(
            "Coordinator placeObjects: Added labels - Marker: \(markerNumber), ID: \(shortId), Entity mapped to pinId: \(pinId)"
          )

          if let baseAnchor = self.baseAnchor {
            baseAnchor.addChild(objectAnchor)  // Add object's anchor to the main rotated baseAnchor
            
            // Debug final placement for geolocation
            let finalWorldPosition = objectAnchor.position(relativeTo: nil)
            print("📍 GEO_PLACEMENT_DEBUG: Added to baseAnchor at local pos: \(arPositionInBaseFrame)")
            print("📍 GEO_PLACEMENT_DEBUG: Final world position: \(finalWorldPosition)")
            print("📍 GEO_PLACEMENT_DEBUG: BaseAnchor world pos: \(baseAnchor.position(relativeTo: nil))")
            
            // Verify distance from camera
            if let frame = arView.session.currentFrame {
              let cameraPos = SIMD3<Float>(frame.camera.transform.columns.3.x, frame.camera.transform.columns.3.y, frame.camera.transform.columns.3.z)
              let distanceFromCamera = simd_distance(finalWorldPosition, cameraPos)
              print("📍 GEO_PLACEMENT_DEBUG: Distance from camera: \(distanceFromCamera)m")
            }
          } else {
            // This case should ideally not happen if alignment occurs first
            // If it does, objectAnchor.position will be interpreted as world coordinates
            arView.scene.addAnchor(objectAnchor)
            print(
              "⚠️ GEO_PLACEMENT_WARNING: Added directly to scene (no baseAnchor). Position \(arPositionInBaseFrame) as world coords."
            )
          }
          newEntities.append(entity)
          newAnchors.append(objectAnchor)  // Store the objectAnchor
        }

      case .proximity:
        print("Coordinator placeObjects: Handling Proximity hunt.")
        guard !self.proximityMarkers.isEmpty else {  // Access wrapped value directly
          print(
            "Coordinator placeObjects: Guard FAILED - proximityMarkers is empty for proximity hunt."
          )
          return
        }
        // For proximity, we'll default to placing Coin entities as discussed
        let objectTypeForProximity: ARObjectType = .coin
        guard objectTypeForProximity != .none else {
          print("Coordinator placeObjects: Guard FAILED - objectType for proximity is .none.")
          return
        }

        print(
          "Coordinator placeObjects: Placing \(self.proximityMarkers.count) objects for proximity hunt (type: \(objectTypeForProximity.rawValue))"
        )  // Access wrapped value directly

        for (index, marker) in self.proximityMarkers.enumerated() {  // Iterate with index
          print(
            "Coordinator placeObjects: Processing proximity marker \(index + 1): Dist=\(marker.dist), Dir=\(marker.dir)"
          )

          guard let headingRadians = self.heading?.trueHeading.degreesToRadians else {
            print(
              "Coordinator placeObjects: Skipping proximity marker placement - Heading not available."
            )
            continue  // Cannot place proximity markers without a valid heading
          }

          guard let markerAngleRadians = parseDirectionStringToRadians(dir: marker.dir) else {
            print(
              "Coordinator placeObjects: Skipping proximity marker placement - Failed to parse direction string: \(marker.dir)"
            )
            continue  // Cannot place proximity markers without a valid direction
          }

          // Calculate the position relative to the base anchor (which is rotated to align Z with North)
          // A marker at distance D and direction M degrees from North should be placed at:
          // x_local = D * sin(M_radians) (East component)
          // z_local = -D * cos(M_radians) (South component, as baseAnchor's +Z is South)
          // Y is typically 0 for objects on the ground plane.

          let x_local = Float(marker.dist * sin(Double(markerAngleRadians)))
          let z_local = Float(-marker.dist * cos(Double(markerAngleRadians)))  // Negative Z for South component

          let arPositionInBaseFrame = SIMD3<Float>(x_local, 0, z_local)  // Position relative to the base anchor
          
          print("🧭 PROXIMITY_DEBUG: === Proximity Marker Placement ===")
          print("🧭 PROXIMITY_DEBUG: Marker \(index): Dist=\(marker.dist)m, Dir=\(marker.dir)")
          print("🧭 PROXIMITY_DEBUG: Parsed angle: \(markerAngleRadians) radians (\(markerAngleRadians * 180 / .pi) degrees)")
          print("🧭 PROXIMITY_DEBUG: Calculated position (x=East, z=-North): (\(x_local), 0, \(z_local))")
          print("🧭 PROXIMITY_DEBUG: Distance from origin: \(sqrt(x_local*x_local + z_local*z_local))m")

          let objectAnchor = AnchorEntity()  // Create a new anchor, positioned relative to its parent
          objectAnchor.position = arPositionInBaseFrame  // Set its position within baseAnchor's coordinate system

          // Get pin data for this index (moved before entity creation)
          let pin = index < self.pinData.count ? self.pinData[index] : nil
          let markerNumber = (pin?.order ?? index) + 1
          let pinId = pin?.id ?? "unknown"
          let shortId = pinId.prefix(8)

          // Use pin's objectType if available, otherwise fall back to default
          let lootType = pin?.objectType ?? objectTypeForProximity
          guard let entity = createEntity(for: lootType) else { continue }
          objectAnchor.addChild(entity)

          // Store the mapping between entity and pin ID
          self.entityToPinId[entity] = pinId
          self.coinEntities.append(entity)

          // Add labels only in debug mode
          if self.isDebugMode {
            // Add marker number label
            let numberLabel = createLabelEntity(text: "\(markerNumber)")
            numberLabel.position = [0, 0.25, 0]  // Higher position for number
            objectAnchor.addChild(numberLabel)

            // Add ID label
            let idLabel = createLabelEntity(text: String(shortId))
            idLabel.position = [0, 0.1, 0]  // Lower position for ID
            objectAnchor.addChild(idLabel)
          }

          print(
            "Coordinator placeObjects: Added proximity labels - Marker: \(markerNumber), ID: \(shortId), Entity mapped to pinId: \(pinId)"
          )

          if let baseAnchor = self.baseAnchor {
            baseAnchor.addChild(objectAnchor)
            
            // Debug final placement
            let finalWorldPosition = objectAnchor.position(relativeTo: nil)
            print("📍 PLACEMENT_DEBUG: Added to baseAnchor at local pos: \(arPositionInBaseFrame)")
            print("📍 PLACEMENT_DEBUG: Final world position: \(finalWorldPosition)")
            print("📍 PLACEMENT_DEBUG: BaseAnchor world pos: \(baseAnchor.position(relativeTo: nil))")
            
            // Verify distance from camera
            if let frame = arView.session.currentFrame {
              let cameraPos = SIMD3<Float>(frame.camera.transform.columns.3.x, frame.camera.transform.columns.3.y, frame.camera.transform.columns.3.z)
              let distanceFromCamera = simd_distance(finalWorldPosition, cameraPos)
              print("📍 PLACEMENT_DEBUG: Distance from camera: \(distanceFromCamera)m")
            }
          } else {
            // This case should ideally not happen if alignment occurs first
            // If it does, objectAnchor.position will be interpreted as world coordinates
            arView.scene.addAnchor(objectAnchor)
            print(
              "⚠️ PLACEMENT_WARNING: Added directly to scene (no baseAnchor). Position \(arPositionInBaseFrame) as world coords."
            )
          }
          newEntities.append(entity)
          newAnchors.append(objectAnchor)  // Store the objectAnchor
        }

      case .none:
        print("Coordinator placeObjects: No hunt type specified.")
        self.statusMessage = "No hunt data loaded."
        return  // Exit if no hunt type
      case .some(let actualHuntType):  // Handle any other potential future hunt types
        print("Coordinator placeObjects: Unhandled hunt type: \(actualHuntType)")  // Use the unwrapped value
        self.statusMessage = "Unsupported hunt type."
        return
      }

      // Status message and entity/anchor updates are done after the switch
      self.statusMessage = "Loot placed successfully!"
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.statusMessage = ""
      }

      self.coinEntities = newEntities  // Rename this to placedEntities or similar? Keeping for now.
      self.anchors = newAnchors
      print("Coordinator updated with \(newAnchors.count) anchors/entities.")
    }

    // Helper to create model entity based on type
    private func createEntity(for type: ARObjectType) -> ModelEntity? {
      switch type {
      case .coin:
        return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
      case .dollarSign:
        do {
          let dollarSign = try ModelEntity.loadModel(named: "DollarSign")
          dollarSign.scale = SIMD3<Float>(repeating: 0.02)
          return dollarSign
        } catch {
          print("Error loading DollarSign model: \(error). Falling back to coin.")
          return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)  // Fallback
        }
      case .giftCard:
        return GiftCardEntityFactory.makeGiftCard()
      case .none:
        return nil
      }
    }

    // More accurate GPS conversion function with debugging
    private func convertToARWorldCoordinate(
      objectLocation: CLLocationCoordinate2D, referenceLocation: CLLocationCoordinate2D
    ) -> SIMD3<Float> {
      let referenceCLLocation = CLLocation(
        latitude: referenceLocation.latitude, longitude: referenceLocation.longitude)
      let objectCLLocation = CLLocation(
        latitude: objectLocation.latitude, longitude: objectLocation.longitude)
      let lat1 = referenceCLLocation.coordinate.latitude
      let lon1 = referenceCLLocation.coordinate.longitude
      let lat2 = objectCLLocation.coordinate.latitude
      let lon2 = objectCLLocation.coordinate.longitude
      
      // More accurate meters per degree calculation based on latitude
      let latitudeRadians = Coordinator.degreesToRadians(lat1)
      let metersPerDegreeLat = 111132.92 - 559.82 * cos(2 * latitudeRadians) + 1.175 * cos(4 * latitudeRadians)
      let metersPerDegreeLon = 111412.84 * cos(latitudeRadians) - 93.5 * cos(3 * latitudeRadians)
      
      let deltaNorth = (lat2 - lat1) * metersPerDegreeLat
      let deltaEast = (lon2 - lon1) * metersPerDegreeLon
      
      print("🗺️ GPS_CONVERSION: === GPS to AR Coordinate Conversion ===")
      print("🗺️ GPS_CONVERSION: Reference: (\(lat1), \(lon1))")
      print("🗺️ GPS_CONVERSION: Object: (\(lat2), \(lon2))")
      print("🗺️ GPS_CONVERSION: Latitude difference: \(lat2 - lat1) degrees")
      print("🗺️ GPS_CONVERSION: Longitude difference: \(lon2 - lon1) degrees")
      print("🗺️ GPS_CONVERSION: Meters per degree - Lat: \(metersPerDegreeLat), Lon: \(metersPerDegreeLon)")
      print("🗺️ GPS_CONVERSION: Delta North: \(deltaNorth)m, Delta East: \(deltaEast)m")
      print("🗺️ GPS_CONVERSION: AR Position (East, Y, -North): (\(deltaEast), 0, \(-deltaNorth))")
      
      return SIMD3<Float>(Float(deltaEast), 0, Float(-deltaNorth))  // East, Y=0, -North for AR coordinates
    }

    // Helper to create a glowing, billboarded text label
    private func createLabelEntity(text: String) -> ModelEntity {
      let textMesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.01,
        font: .systemFont(ofSize: 0.3),  // Increased size from 0.1
        containerFrame: .zero,  // No container frame
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )

      // Use UnlitMaterial for a simple, glowing effect
      let material = UnlitMaterial(color: UIColor.yellow)  // Changed to yellow for a "glowing" look

      let labelEntity = ModelEntity(mesh: textMesh, materials: [material])

      // Add BillboardComponent to make the text always face the camera
      labelEntity.components.set(BillboardComponent())

      return labelEntity
    }

    // Helper to create horizon line entity as a continuous 360-degree torus
    private func createHorizonLineEntity() -> ModelEntity {
      // Create a continuous 360-degree horizon ring using torus geometry
      let majorRadius: Float = 30.0    // 30 meter radius from user
      let minorRadius: Float = 0.05    // Thin ring thickness (5cm)

      // Generate a torus mesh for a continuous ring
      let torusMesh = MeshResource.generateBox(width: 0.1, height: 0.1, depth: 0.1) // Fallback mesh

      // Since RealityKit doesn't have built-in torus generation, we'll create a custom mesh
      let horizonRingEntity = createTorusEntity(majorRadius: majorRadius, minorRadius: minorRadius)

      print("🌅 HORIZON_CREATE: Created continuous 360° torus - Major radius: \(majorRadius)m, Minor radius: \(minorRadius)m")
      print("🌅 HORIZON_CREATE: Color: Light blue with 50% opacity")

      return horizonRingEntity
    }

    // Helper to create a true continuous torus using custom mesh generation
    private func createTorusEntity(majorRadius: Float, minorRadius: Float) -> ModelEntity {
      // Generate a mathematically continuous torus mesh
      let torusMesh = generateTorusMesh(majorRadius: majorRadius, minorRadius: minorRadius)

      // Light blue color with 50% opacity
      let horizonColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.5) // Light blue, 50% transparent
      let material = UnlitMaterial(color: horizonColor)

      let horizonRingEntity = ModelEntity(mesh: torusMesh, materials: [material])
      horizonRingEntity.name = "horizon_torus_continuous"

      print("🌅 HORIZON_CREATE: Generated continuous torus mesh with \(majorRadius)m major radius, \(minorRadius)m minor radius")

      return horizonRingEntity
    }

    // Generate a continuous torus mesh using parametric equations
    private func generateTorusMesh(majorRadius: Float, minorRadius: Float) -> MeshResource {
      let majorSegments = 64  // Resolution around the major circle
      let minorSegments = 16  // Resolution around the minor circle (tube thickness)

      var vertices: [SIMD3<Float>] = []
      var normals: [SIMD3<Float>] = []
      var indices: [UInt32] = []

      // Generate vertices and normals using torus parametric equations
      for i in 0..<majorSegments {
        let u = Float(i) * 2.0 * .pi / Float(majorSegments)  // Major angle (around the ring)

        for j in 0..<minorSegments {
          let v = Float(j) * 2.0 * .pi / Float(minorSegments)  // Minor angle (around the tube)

          // Parametric torus equations:
          // x = (R + r*cos(v)) * cos(u)
          // y = r * sin(v)
          // z = (R + r*cos(v)) * sin(u)
          let cosV = cos(v)
          let sinV = sin(v)
          let cosU = cos(u)
          let sinU = sin(u)

          let x = (majorRadius + minorRadius * cosV) * cosU
          let y = minorRadius * sinV
          let z = (majorRadius + minorRadius * cosV) * sinU

          vertices.append(SIMD3<Float>(x, y, z))

          // Calculate normal vector for smooth shading
          let normalX = cosV * cosU
          let normalY = sinV
          let normalZ = cosV * sinU
          normals.append(normalize(SIMD3<Float>(normalX, normalY, normalZ)))
        }
      }

      // Generate triangle indices for the torus surface
      for i in 0..<majorSegments {
        let i1 = (i + 1) % majorSegments

        for j in 0..<minorSegments {
          let j1 = (j + 1) % minorSegments

          // Current quad vertices
          let a = UInt32(i * minorSegments + j)
          let b = UInt32(i1 * minorSegments + j)
          let c = UInt32(i1 * minorSegments + j1)
          let d = UInt32(i * minorSegments + j1)

          // Create two triangles per quad
          indices.append(contentsOf: [a, b, c])  // Triangle 1
          indices.append(contentsOf: [a, c, d])  // Triangle 2
        }
      }

      // Create mesh descriptor
      var meshDescriptor = MeshDescriptor()
      meshDescriptor.positions = MeshBuffers.Positions(vertices)
      meshDescriptor.normals = MeshBuffers.Normals(normals)
      meshDescriptor.primitives = .triangles(indices)

      do {
        let mesh = try MeshResource.generate(from: [meshDescriptor])
        print("🌅 MESH_GEN: Generated continuous torus with \(vertices.count) vertices, \(indices.count/3) triangles")
        return mesh
      } catch {
        print("🌅 MESH_ERROR: Failed to generate torus mesh: \(error)")
        // Fallback to a simple box if mesh generation fails
        return MeshResource.generateBox(width: 0.1, height: 0.1, depth: 0.1)
      }
    }

    // Method to setup horizon line
    private func setupHorizonLine(in arView: ARView) {
      guard showHorizonLineBinding, horizonEntity == nil, let baseAnchor = baseAnchor else {
        print("🌅 HORIZON: Skipping horizon setup - showHorizonLine: \(showHorizonLineBinding), horizonEntity exists: \(horizonEntity != nil), baseAnchor exists: \(baseAnchor != nil)")
        return
      }

      print("🌅 HORIZON: Setting up horizon line")

      // Create horizon entity
      horizonEntity = createHorizonLineEntity()

      guard let horizon = horizonEntity else { return }

      // Position horizon ring at origin - it will be updated dynamically to camera Y level
      // The torus is already sized to 30m radius, so it surrounds the user
      horizon.position = SIMD3<Float>(0, 0, 0)

      // Add to base anchor for consistent world alignment
      baseAnchor.addChild(horizon)

      print("🌅 HORIZON: Horizon line added to baseAnchor at position: \(horizon.position)")
    }

    // Method to update horizon line position based on camera
    private func updateHorizonLine(arView: ARView) {
      guard showHorizonLineBinding, let horizon = horizonEntity,
            let cameraTransform = arView.session.currentFrame?.camera.transform else {
        // Debug every 300 frames (~5 seconds) to avoid spam
        if frameCounter % 300 == 0 {
          print("🌅 HORIZON_UPDATE: Skipped - showHorizonLine: \(showHorizonLineBinding), horizonEntity: \(horizonEntity != nil), camera: \(arView.session.currentFrame?.camera != nil)")
        }
        return
      }

      // Get camera position
      let cameraPosition = SIMD3<Float>(
        cameraTransform.columns.3.x,
        cameraTransform.columns.3.y,
        cameraTransform.columns.3.z
      )

      // Position horizon ring at camera's Y level
      // Since the ring is a child of baseAnchor, we need to convert camera position to baseAnchor space
      if let baseAnchor = baseAnchor {
        // Convert camera world position to baseAnchor local space
        let cameraWorldTransform = Transform(matrix: cameraTransform)
        let cameraLocalY = baseAnchor.convert(position: cameraPosition, from: nil).y

        // Keep the ring centered at XZ origin of baseAnchor, only adjust Y
        horizon.position = SIMD3<Float>(0, cameraLocalY, 0)
      }

      // Debug every 150 frames (~2.5 seconds) to avoid spam
      if frameCounter % 150 == 0 {
        print("🌅 HORIZON_UPDATE: Camera pos: \(cameraPosition)")
        print("🌅 HORIZON_UPDATE: Horizon local pos: \(horizon.position)")
        print("🌅 HORIZON_UPDATE: Horizon world pos: \(horizon.position(relativeTo: nil))")
        print("🌅 HORIZON_UPDATE: Horizon enabled: \(horizon.isEnabled)")
        print("🌅 HORIZON_UPDATE: Continuous torus entity: \(horizon.name ?? "unnamed")")
      }

      // No rotation needed for 360-degree ring - it's symmetric in all directions
    }

    // Method to toggle horizon line visibility
    public func toggleHorizonLine() {
      let oldValue = showHorizonLineBinding
      showHorizonLineBinding.toggle()
      let newValue = showHorizonLineBinding

      print("🌅 HORIZON_TOGGLE: Changed from \(oldValue) to \(newValue)")
      print("🌅 HORIZON_TOGGLE: horizonEntity exists: \(horizonEntity != nil)")

      if showHorizonLineBinding {
        // Show horizon line
        horizonEntity?.isEnabled = true
        print("🌅 HORIZON_TOGGLE: Horizon line enabled, entity enabled: \(horizonEntity?.isEnabled ?? false)")

        // If no entity exists yet, try to create it
        if horizonEntity == nil, let arView = arView {
          print("🌅 HORIZON_TOGGLE: No entity exists, trying to setup...")
          setupHorizonLine(in: arView)
        }
      } else {
        // Hide horizon line
        horizonEntity?.isEnabled = false
        print("🌅 HORIZON_TOGGLE: Horizon line disabled")
      }
    }

    // Method to ensure baseAnchor exists and check AR world alignment
    private func ensureBaseAnchorExists(in arView: ARView) {
      print("⚓ ANCHOR_DEBUG: === Base Anchor Setup ===")
      
      // Check current AR session alignment
      if let frame = arView.session.currentFrame {
        let cameraTransform = frame.camera.transform
        print("⚓ ANCHOR_DEBUG: Camera transform: \(cameraTransform)")
        print("⚓ ANCHOR_DEBUG: Camera position: \(cameraTransform.columns.3)")
        
        // Check if we have heading info
        if let heading = self.heading {
          print("⚓ ANCHOR_DEBUG: True heading: \(heading.trueHeading)°")
          print("⚓ ANCHOR_DEBUG: Magnetic heading: \(heading.magneticHeading)°")
          print("⚓ ANCHOR_DEBUG: Heading accuracy: \(heading.headingAccuracy)°")
        } else {
          print("⚓ ANCHOR_DEBUG: No heading available")
        }
      }
      
      if baseAnchor == nil {
        baseAnchor = AnchorEntity(world: .zero)  // Create anchor at world origin
        arView.scene.addAnchor(baseAnchor!)
        print("⚓ ANCHOR_DEBUG: Created baseAnchor at world origin")
        print("⚓ ANCHOR_DEBUG: BaseAnchor transform: \(baseAnchor!.transform)")
        print("⚓ ANCHOR_DEBUG: BaseAnchor world position: \(baseAnchor!.position(relativeTo: nil))")

        // Setup horizon line after base anchor is created
        setupHorizonLine(in: arView)
      } else {
        if baseAnchor?.scene == nil {
          arView.scene.addAnchor(baseAnchor!)
        }
        print("⚓ ANCHOR_DEBUG: BaseAnchor already exists")
        print("⚓ ANCHOR_DEBUG: BaseAnchor transform: \(baseAnchor!.transform)")
        print("⚓ ANCHOR_DEBUG: BaseAnchor world position: \(baseAnchor!.position(relativeTo: nil))")

        // Setup horizon line if it doesn't exist yet
        setupHorizonLine(in: arView)
      }
    }

    // New method to start the AR session for the first time and then place objects
    public func startSessionAndPlaceObjects() {
      guard let arView = self.arView else {
        print("startSessionAndPlaceObjects: ARView is nil. Cannot proceed.")
        self.hasAlignedToNorth = false  // Allow another attempt
        return
      }

      // Always configure and run. If session is already running, run with new config will update it.
      // Using .gravityAndHeading to let ARKit attempt to align to North.
      print(
        "startSessionAndPlaceObjects: Configuring and running AR Session with .gravityAndHeading.")
      let worldConfig = ARWorldTrackingConfiguration()
      worldConfig.worldAlignment = .gravityAndHeading  // ARKit attempts to align -Z to North.
      worldConfig.planeDetection = [.horizontal, .vertical]
      worldConfig.environmentTexturing = .automatic

      // Run the session. If it's the first time, it starts. If already running, it reconfigures.
      // Using .resetTracking and .removeExistingAnchors to ensure a fresh start with the new alignment.
      arView.session.run(worldConfig, options: [.resetTracking, .removeExistingAnchors])
      print("startSessionAndPlaceObjects: AR Session run/reconfigured with .gravityAndHeading.")

      // After session starts/reconfigures, ensure baseAnchor and place objects
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Short delay for session to stabilize
        print("startSessionAndPlaceObjects: Ensuring baseAnchor and attempting placement.")
        self.ensureBaseAnchorExists(in: arView)

        self.hasPlacedObjects = false  // Ensure we can place objects

        self.statusMessage = "AR Session started. Placing objects..."
        self.attemptPlacementIfReady()
      }
    }

    // alignARWorldToNorth is no longer used for rotation. Its role is to ensure baseAnchor exists.
    // It's called from heading.didSet before startSessionAndPlaceObjects.
    // However, ensureBaseAnchorExists is now called *after* session start.
    // So, this function can be simplified or its call removed from heading.didSet.
    // For now, let's make it just call ensureBaseAnchorExists if arView is present.
    private func alignARWorldToNorth(arView: ARView, heading: CLLocationDirection) {
      print(
        "alignARWorldToNorth: Called (now primarily ensures base anchor after session start via other paths)."
      )
      // The actual ensureBaseAnchorExists call is now in startSessionAndPlaceObjects.
      // This function is called from heading.didSet before startSessionAndPlaceObjects,
      // so baseAnchor might be created here, then re-checked/re-added in startSessionAndPlaceObjects.
      // This is slightly redundant but safe.
      ensureBaseAnchorExists(in: arView)
    }

    @objc public func updateRotation(displayLink: CADisplayLink) {
      let frameStartTime = CACurrentMediaTime()
      
      guard !coinEntities.isEmpty else { 
        if frameCounter % 300 == 0 { // Every 5 seconds
          print("⚠️ UPDATE_ROTATION: Skipped - no coinEntities")
        }
        return 
      }
      
      // Update focus detection for button-based summoning
      updateFocusDetection()

      // Update horizon line position and handle setup
      if let arView = arView {
        // If horizon line should be shown but doesn't exist, create it
        if showHorizonLineBinding && horizonEntity == nil {
          setupHorizonLine(in: arView)
        }

        // Update position if it exists and toggle visibility
        updateHorizonLine(arView: arView)

        // Handle visibility toggle
        if let horizon = horizonEntity {
          horizon.isEnabled = showHorizonLineBinding
          if frameCounter % 300 == 0 { // Debug every 5 seconds
            print("🌅 HORIZON_VISIBILITY: showHorizonLineBinding=\(showHorizonLineBinding), entity.isEnabled=\(horizon.isEnabled)")
          }
        }
      }

      // Handle button-based summoning state changes
      if isSummoningActiveBinding && summoningEntity == nil && focusedEntity != nil {
        // Button pressed and we have a focused entity - start summoning
        startObjectSummoning()
      } else if !isSummoningActiveBinding && summoningEntity != nil {
        // Button released - stop summoning
        stopObjectSummoning()
      }
      
      let now = displayLink.timestamp
      let dt: Float
      if let last = lastTimestamp {
        dt = Float(now - last)
        
        // Debug frame timing during summoning
        if isSummoningActiveBinding && frameCounter % 30 == 0 {
          let fps = dt > 0 ? (1.0 / dt) : 0
          print("🔄 FRAME_TIMING: Frame \(frameCounter), Delta: \(dt)s, FPS: \(fps)")
          print("🔄 FRAME_TIMING: DisplayLink timestamp: \(now), Current time: \(frameStartTime)")
        }
      } else {
        dt = 0  // First frame
      }
      lastTimestamp = now

      // Angle increment for this frame
      let anglePerSecond: Float = 2 * .pi / Float(revolutionDuration)
      accumulatedAngle += anglePerSecond * dt

      // Spin all entities and handle summoning movement
      let yRot = simd_quatf(angle: accumulatedAngle, axis: [0, 1, 0])
      for entity in coinEntities {
        // Handle summoned entity movement and rotation
        if entity == summoningEntity {
          // Apply smooth rotation even during summoning
          if self.objectType == .coin {
            let xRot = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            entity.transform.rotation = yRot * xRot
          } else {
            entity.transform.rotation = yRot
          }
          
          // Move toward camera only if summoning button is pressed
          if isSummoningActiveBinding, let cameraTransform = arView?.session.currentFrame?.camera.transform {
            let cameraPosition = SIMD3<Float>(
              cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            
            let currentWorldPosition = entity.position(relativeTo: nil)
            let currentLocalPosition = entity.transform.translation
            let direction = normalize(cameraPosition - currentWorldPosition)
            let distance = simd_distance(currentWorldPosition, cameraPosition)
            
            // Debug logging every 30 frames for detailed analysis
            if frameCounter % 30 == 0 {
              print("🔍 COORDINATE_DEBUG: === Frame \(frameCounter) ===")
              print("🔍 COORDINATE_DEBUG: Camera World Pos: \(cameraPosition)")
              print("🔍 COORDINATE_DEBUG: Entity World Pos: \(currentWorldPosition)")
              print("🔍 COORDINATE_DEBUG: Entity Local Pos: \(currentLocalPosition)")
              print("🔍 COORDINATE_DEBUG: Direction Vector: \(direction)")
              print("🔍 COORDINATE_DEBUG: Distance: \(distance)m")
              
              // Check entity's parent hierarchy
              if let parent = entity.parent {
                print("🔍 COORDINATE_DEBUG: Entity Parent: \(type(of: parent))")
                if let anchor = parent as? AnchorEntity {
                  print("🔍 COORDINATE_DEBUG: Parent Anchor World Pos: \(anchor.position(relativeTo: nil))")
                }
              }
            }
            
            // Only move if not too close (stop at 0.3 meters - much closer to camera)
            if distance > 0.3 {
              let moveDistance = summonSpeed * dt  // Move based on frame time
              let newWorldPosition = currentWorldPosition + direction * moveDistance
              
              // FIX: Set world position correctly instead of local translation
              entity.setPosition(newWorldPosition, relativeTo: nil)
              
              // Debug the movement
              if frameCounter % 30 == 0 {
                print("🎯 SUMMONING: Moving \(moveDistance)m toward camera")
                print("🎯 SUMMONING: New World Pos: \(newWorldPosition)")
                print("🎯 SUMMONING: Speed: \(summonSpeed)m/s, DT: \(dt)s")
              }
            } else {
              // Close enough - auto collect
              print("🎯 SUMMONING: Object reached user at close range \(distance)m, auto-collecting")
              autoCollectSummonedEntity(entity)
            }
          }
          continue  // Skip normal rotation for summoned entity
        }
        
        // Normal rotation for non-summoned entities
        if self.objectType == .coin {
          let xRot = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
          entity.transform.rotation = yRot * xRot
        } else {
          entity.transform.rotation = yRot
        }
      }

      // Proximity check
      guard let arView = arView,
        let cameraTransform = arView.session.currentFrame?.camera.transform
      else { return }
      let cameraPosition = SIMD3<Float>(
        cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

      // Debug: Log collection detection details every 60 frames (~1 second)
      if frameCounter % 60 == 0 && isSummoningActiveBinding {
        print("🔍 COLLECTION_DEBUG: Running collection check (frame \(frameCounter))")
        print("🔍 COLLECTION_DEBUG: Camera position: \(cameraPosition)")
        print("🔍 COLLECTION_DEBUG: Summoning entity exists: \(summoningEntity != nil)")
        print("🔍 COLLECTION_DEBUG: Arrays - anchors: \(anchors.count), entities: \(coinEntities.count)")
      }

      // Iterate backwards safely for removal
      for index in anchors.indices.reversed() {
        guard index < coinEntities.count else { 
          print("⚠️ COLLECTION_DEBUG: Index \(index) out of bounds for coinEntities (count: \(coinEntities.count))")
          continue 
        }

        let anchor = anchors[index]
        let entity = coinEntities[index]  // Get corresponding entity
        let entityWorldPosition = entity.position(relativeTo: nil)  // Use entity's world position

        let distance = simd_distance(cameraPosition, entityWorldPosition)

        // Check for collection - either normal proximity or summoned object
        let normalCollectionDistance: Float = 0.25
        let summonedCollectionDistance: Float = 0.8  // Larger collection area for summoned objects
        let isSummonedObject = (entity == summoningEntity)
        let collectionThreshold =
          isSummonedObject ? summonedCollectionDistance : normalCollectionDistance

        // Debug summoned object positions every few frames
        if isSummonedObject && frameCounter % 60 == 0 {
          print("🎯 SUMMONED_OBJECT_DEBUG: Index \(index), Position: \(entityWorldPosition), Distance: \(distance)m, Threshold: \(collectionThreshold)m")
        }

        if distance < collectionThreshold {
          if isSummonedObject {
            print("🎯 SUMMONED_OBJECT: Proximity collection disabled - object will be auto-collected after animation")
            // Skip proximity-based collection for summoned objects
            // They will be collected by autoCollectSummonedEntity() after animation completes
            continue
          } else {
            print("Object collected at distance: \(distance)")
          }

          // Mark as collected to hide labels (only for non-summoned objects)
          collectedEntities.insert(entity)
          hideLabelsForEntity(entity, anchor: anchor)

          playCoinSound()

          // Get the pin ID for this specific entity
          let pinId = entityToPinId[entity] ?? "unknown"
          print("🪙 COLLECTION: Collecting entity with pinId: \(pinId) at index \(index)")
          print("🪙 COLLECTION: Arrays before removal - anchors: \(anchors.count), entities: \(coinEntities.count), locations: \(objectLocations.count)")

          // Remove anchor from the base anchor
          anchor.removeFromParent()

          // Remove from coordinator arrays and mapping
          anchors.remove(at: index)
          let removedEntity = coinEntities.remove(at: index)
          
          // Only remove from objectLocations if this is a geolocation hunt
          if currentHuntType == .geolocation && index < objectLocations.count {
            objectLocations.remove(at: index)
            print("🪙 COLLECTION: Removed from objectLocations at index \(index)")
          } else {
            print("🪙 COLLECTION: Skipped objectLocations removal (hunt type: \(String(describing: currentHuntType)), index: \(index), count: \(objectLocations.count))")
          }
          
          entityToPinId.removeValue(forKey: removedEntity)
          
          print("🪙 COLLECTION: Arrays after removal - anchors: \(anchors.count), entities: \(coinEntities.count), locations: \(objectLocations.count)")

          // Trigger callback with the specific pin ID
          print("🪙 COLLECTION: Calling onCoinCollected with pinId: \(pinId)")
          onCoinCollected?(pinId)
        }
      }
    }

    public func playCoinSound() {
      guard let url = Bundle.main.url(forResource: "coin", withExtension: "mp3") else {
        print("Missing coin.mp3 in app bundle")
        return
      }
      do {
        // Stop previous sound if playing
        audioPlayer?.stop()
        // Create and play new instance
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        print("🔊 HAPTIC: Played haptic feedback for coin collection")
      } catch {
        print("Failed to play coin sound: \(error)")
      }
    }

    // MARK: - Focus Detection

    private func setupFocusDetection() {
      print("🎯 FOCUS_DETECTION: Setting up loot focus detection")
      isSummoningActiveBinding = false
      focusedLootIdBinding = nil
      print("🎯 FOCUS_DETECTION: Ready - aim at loot to focus")
    }

    private func updateFocusDetection() {
      guard let arView = arView, let camera = arView.session.currentFrame?.camera else { return }
      
      let now = Date()
      // Update focus detection 10 times per second
      guard now.timeIntervalSince(lastFocusUpdateTime) >= 0.1 else { return }
      lastFocusUpdateTime = now
      
      let cameraTransform = camera.transform
      let cameraPosition = SIMD3<Float>(
        cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
      
      // Camera forward direction (negative Z column)
      let forwardVector = normalize(
        SIMD3<Float>(
          -cameraTransform.columns.2.x,
          -cameraTransform.columns.2.y,
          -cameraTransform.columns.2.z
        )
      )

      // Focus cone angle (in radians) that defines "center"
      let focusConeAngle: Float = 8.0 * (.pi / 180.0)  // About 8° field around center

      var centerEntity: ModelEntity? = nil
      var closestDistance: Float = Float.infinity
      var smallestAngle: Float = Float.infinity

      for entity in coinEntities {
        let entityWorldPosition = entity.position(relativeTo: nil)
        let toEntity = entityWorldPosition - cameraPosition
        let distance = simd_length(toEntity)

        guard distance <= focusRange else { continue }

        let direction = normalize(toEntity)
        let dotProduct = simd_dot(forwardVector, direction)
        let clampedDot = max(min(dotProduct, 1.0), -1.0)
        let angle = acos(clampedDot)

        guard angle <= focusConeAngle else { continue }

        if angle < smallestAngle || (abs(angle - smallestAngle) < 0.5 * (.pi / 180.0) && distance < closestDistance) {
          centerEntity = entity
          closestDistance = distance
          smallestAngle = angle
        }
      }
      
      // Update focused entity and binding
      let previousFocusedEntity = focusedEntity
      focusedEntity = centerEntity

      if let entity = centerEntity, let pinId = entityToPinId[entity] {
        focusedLootIdBinding = pinId
        // Update distance to focused loot
        focusedLootDistanceBinding = closestDistance
        // Add glow effect if newly focused
        if previousFocusedEntity != centerEntity {
          // Remove glow from previously focused entity
          if let previousEntity = previousFocusedEntity {
            removeGlowEffect(from: previousEntity)
          }
          // Add glow to newly focused entity
          addGlowEffect(to: entity)
        }
      } else {
        focusedLootIdBinding = nil
        focusedLootDistanceBinding = nil
        // Remove glow effect if focus lost
        if let previousEntity = previousFocusedEntity {
          removeGlowEffect(from: previousEntity)
        }
      }
    }

    // MARK: - Halo Effects
    
    private func addGlowEffect(to entity: ModelEntity) {
      // Remove any existing glow to avoid stacking
      removeGlowEffect(from: entity)

      // Use the entity's visual bounds to size the glow so it wraps the mesh
      let bounds = entity.visualBounds(relativeTo: entity)
      let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
      let baseDiameter = max(maxExtent * 1.3, 0.3)  // Keep large enough for small meshes

      guard
        let outerMaterial = makeGlowMaterial(style: .outer),
        let innerMaterial = makeGlowMaterial(style: .inner)
      else {
        print("✨ GLOW: Failed to create glow materials")
        return
      }

      // Outer soft haze
      let outerPlane = ModelEntity(
        mesh: MeshResource.generatePlane(width: baseDiameter * 1.6, depth: baseDiameter * 1.6),
        materials: [outerMaterial]
      )
      outerPlane.name = "glow_outer"
      outerPlane.position = .zero
      outerPlane.components.set(BillboardComponent())

      // Inner tighter ring
      let innerPlane = ModelEntity(
        mesh: MeshResource.generatePlane(width: baseDiameter, depth: baseDiameter),
        materials: [innerMaterial]
      )
      innerPlane.name = "glow_inner"
      innerPlane.position = .zero
      innerPlane.components.set(BillboardComponent())

      entity.addChild(outerPlane)
      entity.addChild(innerPlane)
      print("✨ GLOW: Added layered glow planes around focused loot")
    }

    private func removeGlowEffect(from entity: ModelEntity) {
      // Find and remove glow planes from entity
      for child in entity.children {
        if child.name == "glow_outer" || child.name == "glow_inner" {
          child.removeFromParent()
          print("✨ GLOW: Removed glow effect")
        }
      }
    }

    private enum GlowStyle {
      case outer
      case inner
    }

    private static var cachedOuterGlowTexture: TextureResource?
    private static var cachedInnerGlowTexture: TextureResource?

    private func makeGlowMaterial(style: GlowStyle) -> UnlitMaterial? {
      guard let texture = Self.glowTexture(for: style) else { return nil }

      let tint = UIColor(red: 1.0, green: 0.88, blue: 0.3, alpha: style == .outer ? 0.35 : 0.6)
      var material = UnlitMaterial()
      material.color = .init(tint: tint, texture: .init(texture))
      return material
    }

    private static func glowTexture(for style: GlowStyle) -> TextureResource? {
      switch style {
      case .outer:
        if let texture = cachedOuterGlowTexture { return texture }
        guard let generated = generateRadialGlowTexture(innerAlpha: 0.75, outerAlpha: 0.0) else { return nil }
        cachedOuterGlowTexture = generated
        return generated
      case .inner:
        if let texture = cachedInnerGlowTexture { return texture }
        guard let generated = generateRadialGlowTexture(innerAlpha: 1.0, outerAlpha: 0.08) else { return nil }
        cachedInnerGlowTexture = generated
        return generated
      }
    }

    private static func generateRadialGlowTexture(innerAlpha: CGFloat, outerAlpha: CGFloat) -> TextureResource? {
      let size = CGSize(width: 256, height: 256)
      let format = UIGraphicsImageRendererFormat()
      format.opaque = false
      format.scale = 1.0
      let renderer = UIGraphicsImageRenderer(size: size, format: format)
      let image = renderer.image { context in
        guard let gradient = CGGradient(
          colorsSpace: CGColorSpaceCreateDeviceRGB(),
          colors: [
            UIColor(white: 1.0, alpha: innerAlpha).cgColor,
            UIColor(white: 1.0, alpha: outerAlpha).cgColor,
          ] as CFArray,
          locations: [0.0, 1.0]
        ) else { return }

        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.cgContext.drawRadialGradient(
          gradient,
          startCenter: center,
          startRadius: 0,
          endCenter: center,
          endRadius: max(size.width, size.height) / 2.0,
          options: [.drawsAfterEndLocation]
        )
      }

      guard let cgImage = image.cgImage else { return nil }
      do {
        let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        return texture
      } catch {
        print("✨ GLOW: Failed to generate texture: \(error)")
        return nil
      }
    }

    // MARK: - Object Summoning

    private func startObjectSummoning() {
      print("🧙‍♂️ SUMMONING: Button summoning started")
      
      // Use focused entity if available
      guard let targetEntity = focusedEntity else {
        print("🧙‍♂️ SUMMONING: ❌ No focused loot to summon")
        return
      }
      
      // Don't start if already summoning the same object
      guard summoningEntity != targetEntity else {
        print("🧙‍♂️ SUMMONING: Already summoning this object")
        return
      }
      
      let pinId = entityToPinId[targetEntity] ?? "unknown"
      let shortId = pinId.prefix(8)
      print("🧙‍♂️ SUMMONING: Starting summoning of loot ID:\(shortId)")
      
      // Get camera position for distance calculation
      guard let arView = arView, let camera = arView.session.currentFrame?.camera else {
        print("🧙‍♂️ SUMMONING: ❌ No camera available")
        return
      }
      let cameraPosition = SIMD3<Float>(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
      let entityPosition = targetEntity.position(relativeTo: nil)
      let distance = simd_distance(entityPosition, cameraPosition)

      print("🧙‍♂️ SUMMONING: ✅ Found center target entity at distance: \(distance) meters")

      // Store the original position and start summoning
      summoningEntity = targetEntity
      originalEntityPosition = targetEntity.position(relativeTo: nil)
      summonStartTime = CACurrentMediaTime()
      
      // Validate entity is in our tracking arrays
      if let entityIndex = coinEntities.firstIndex(of: targetEntity) {
        print("🧙‍♂️ SUMMONING: Target entity found at index \(entityIndex) in coinEntities")
        if let pinId = entityToPinId[targetEntity] {
          print("🧙‍♂️ SUMMONING: Entity has pinId: \(pinId)")
        } else {
          print("⚠️ SUMMONING: WARNING - Entity has no pinId mapping!")
        }
      } else {
        print("⚠️ SUMMONING: ERROR - Target entity NOT found in coinEntities array!")
      }
      
      print("🧙‍♂️ SUMMONING: Summoning state set - starting animation...")
      print("🧙‍♂️ SUMMONING: Current state - buttonActive: \(isSummoningActiveBinding), summoningEntity != nil: \(summoningEntity != nil)")

      // Start the summoning animation
      print("🧙‍♂️ SUMMONING: About to call animateObjectTowardsUser...")
      animateObjectTowardsUser(targetEntity, cameraPosition: cameraPosition)
      print("🧙‍♂️ SUMMONING: animateObjectTowardsUser call completed")
      
      // Schedule a state check to verify summoning is still active
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        print("🧙‍♂️ SUMMONING: 1s state check - buttonActive: \(self.isSummoningActiveBinding), entity exists: \(self.summoningEntity != nil)")
      }
    }

    private func stopObjectSummoning() {
      guard let entity = summoningEntity,
        let originalPosition = originalEntityPosition
      else {
        // Clear summoning entity
        summoningEntity = nil
        originalEntityPosition = nil
        summonStartTime = nil
        return
      }

      // Return object to original position instantly
      entity.setPosition(originalPosition, relativeTo: nil)

      // Clear summoning state
      summoningEntity = nil
      originalEntityPosition = nil
      summonStartTime = nil

      print("🧙‍♂️ SUMMONING: Object summoning stopped, returned to original position")
    }

    private func animateObjectTowardsUser(_ entity: ModelEntity, cameraPosition: SIMD3<Float>) {
      let entityPosition = entity.position(relativeTo: nil)
      let totalDistance = simd_distance(entityPosition, cameraPosition)
      
      print("🧙‍♂️ SUMMONING: Starting button-controlled summoning")
      print("🧙‍♂️ SUMMONING: Entity at: \(entityPosition), Camera at: \(cameraPosition)")
      print("🧙‍♂️ SUMMONING: Distance: \(totalDistance)m, Speed: \(summonSpeed)m/s")

      // Store this entity as the summoning entity
      summoningEntity = entity
      originalEntityPosition = entityPosition
      summonStartTime = CACurrentMediaTime()
      
      // Movement will be handled frame-by-frame in updateRotation
      // No pre-defined animation - it responds to button state
      print("🧙‍♂️ SUMMONING: Summoning setup complete, object will move when button is held")
    }


    private func autoCollectSummonedEntity(_ entity: ModelEntity) {
      print("🎯 AUTO_COLLECT: Attempting auto-collection")
      print("🎯 AUTO_COLLECT: Current summoningEntity: \(summoningEntity?.debugDescription ?? "nil")")
      print("🎯 AUTO_COLLECT: Target entity: \(entity.debugDescription)")
      print("🎯 AUTO_COLLECT: Entities match: \(entity == summoningEntity)")
      
      // Make auto-collection more robust - don't require exact entity match
      // Instead, check if this entity is in our tracking arrays and has a valid pin ID
      guard let pinId = entityToPinId[entity], pinId != "unknown" else {
        print("🎯 AUTO_COLLECT: No valid pin ID found for entity")
        return
      }
      
      print("🎯 AUTO_COLLECT: Auto-collecting entity with pinId: \(pinId)")
      
      // Find the entity index and anchor
      guard let entityIndex = coinEntities.firstIndex(of: entity),
            let anchor = findAnchorForEntity(entity) else {
        print("🎯 AUTO_COLLECT: Could not find entity in arrays")
        return
      }
      
      // Clear summoning state first to allow subsequent summoning
      print("🎯 AUTO_COLLECT: Clearing summoning state to allow subsequent summoning")
      summoningEntity = nil
      originalEntityPosition = nil
      summonStartTime = nil
      
      // Add to collected entities for consistency
      collectedEntities.insert(entity)
      
      // Play sound and hide labels
      playCoinSound()
      hideLabelsForEntity(entity, anchor: anchor)
      
      // Remove from arrays
      anchor.removeFromParent()
      anchors.remove(at: entityIndex)
      coinEntities.remove(at: entityIndex)
      if currentHuntType == .geolocation && entityIndex < objectLocations.count {
        objectLocations.remove(at: entityIndex)
      }
      entityToPinId.removeValue(forKey: entity)
      
      print("🎯 AUTO_COLLECT: Collection completed - triggering callback")
      
      // Trigger UI update with callback
      onCoinCollected?(pinId)
    }
    
    private func findAnchorForEntity(_ entity: ModelEntity) -> AnchorEntity? {
      // Find the anchor that contains this entity
      for anchor in anchors {
        if anchor.children.contains(where: { child in
          if let modelEntity = child as? ModelEntity {
            return modelEntity == entity
          }
          return false
        }) {
          return anchor
        }
      }
      return nil
    }

    private func hideLabelsForEntity(_ entity: ModelEntity, anchor: AnchorEntity) {
      // Hide all label children of the anchor
      for child in anchor.children {
        if child != entity {  // Don't hide the main entity, just the labels
          child.isEnabled = false
        }
      }
    }

    private func addFloatingAnimation(to entity: ModelEntity, duration: TimeInterval) {
      let floatDistance: Float = 0.1
      let floatDuration: TimeInterval = 1.5

      let startPosition = entity.transform.translation
      let upPosition = startPosition + SIMD3<Float>(0, floatDistance, 0)
      let downPosition = startPosition - SIMD3<Float>(0, floatDistance, 0)

      var upAnimationDefinition = FromToByAnimation<Transform>(
        from: Transform(translation: downPosition),
        to: Transform(translation: upPosition),
        duration: floatDuration,
        timing: .easeInOut
      )
      upAnimationDefinition.repeatMode = .autoReverse // Set repeat mode on the definition

      var downAnimationDefinition = FromToByAnimation<Transform>(
        from: Transform(translation: upPosition),
        to: Transform(translation: downPosition),
        duration: floatDuration,
        timing: .easeInOut
      )
      downAnimationDefinition.repeatMode = .autoReverse // Set repeat mode on the definition

      let floatSequence = try! AnimationResource.sequence(with: [
        AnimationResource.generate(with: upAnimationDefinition),
        AnimationResource.generate(with: downAnimationDefinition)
      ])

      let floatingAnimation = try! floatSequence.repeat(duration: .infinity) // This will make the sequence repeat forever

      entity.playAnimation(floatingAnimation, transitionDuration: 0.5, startsPaused: false)
    }

    // Method to clear all previously placed anchors
    public func clearAnchors() {
      print("Coordinator clearAnchors: Clearing \(anchors.count) previously placed anchors.")
      for anchor in self.anchors {
        anchor.removeFromParent()  // Removes anchor from its parent (either baseAnchor or arView.scene)
      }
      self.anchors.removeAll()
      self.coinEntities.removeAll()  // Assuming coinEntities are children of these anchors

      // Clear horizon line but keep it for reuse
      horizonEntity?.removeFromParent()
      horizonEntity = nil

      print("Coordinator clearAnchors: All tracked anchors removed from scene and internal lists.")
    }

    // MARK: - ARSessionDelegate Methods
    // Implement if needed, e.g., for error handling or session updates
    public func session(_ session: ARSession, didFailWithError error: Error) {
      print("AR Session Failed: \(error.localizedDescription)")
      DispatchQueue.main.async {
        self.statusMessage = "AR Session Failed: \(error.localizedDescription)"  // Access wrapped value directly
      }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
      print("AR Session Interrupted")
      DispatchQueue.main.async {
        self.statusMessage = "AR Session Interrupted"  // Access wrapped value directly
      }
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
      print("AR Session Interruption Ended")
      DispatchQueue.main.async {
        self.statusMessage = "AR Session Resumed"  // Access wrapped value directly
        // Reset status message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          self.statusMessage = ""  // Access wrapped value directly
        }
      }
      // Consider reloading configuration or resetting tracking
    }

    // Implement didUpdate to capture heading updates and process hand gestures
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
      // This delegate method is called frequently.
      // We only need the heading for initial alignment.
      // The heading is passed via the binding and observed in the Coordinator's didSet.
      // No need to process heading here if it's handled by the binding.

      // Process hand gestures every few frames to avoid performance issues
      frameCounter += 1

      // Process hand pose detection every 6th frame (approximately 10 FPS on 60 FPS camera)
      if frameCounter % 6 == 0 {
        // Only print every 30th frame to reduce spam (every ~2 seconds at 15fps processing)
        if frameCounter % 180 == 0 {
          print("🎯 FOCUS_DEBUG: Processing frame #\(frameCounter) (focusedId: \(focusedLootIdBinding ?? "none"), buttonActive: \(isSummoningActiveBinding))")
        }
        
        // Hand pose processing removed - using button-based summoning instead
      }
      
      // Important: Don't retain the frame beyond this method
      // The frame parameter will be automatically released when this method returns
    }

    // Removed hand pose processing - using button-based summoning

    // Helper function to parse direction string (e.g., "N32E") into radians
    // Assuming format "Cardinal Degrees Cardinal" e.g., "N32E", "S45W", "E90S", "W0N" (pure West)
    // Angle is clockwise from North (positive Z in AR world after alignment)
    private func parseDirectionStringToRadians(dir: String) -> Float? {
      print("--- PARSER CALLED WITH: \(dir) ---")  // Diagnostic print

      let pattern = #"^([NESW])(\d*)?([NESW])?$"#
      guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
        let match = regex.firstMatch(
          in: dir, options: [], range: NSRange(location: 0, length: dir.utf16.count))
      else {
        print("Failed to parse direction string format: \(dir)")
        return nil
      }

      var angleDegrees: Double = 0
      var baseAngle: Double = 0  // Angle for the first cardinal (N=0, E=90, S=180, W=270)
      var deflectionAngle: Double = 0  // Degrees after the first cardinal
      var deflectionDirection: Int = 1  // 1 for E/N (clockwise from base), -1 for W/S (counter-clockwise from base)

      // Extract components
      if match.numberOfRanges > 1, let range1 = Range(match.range(at: 1), in: dir) {
        let cardinal1 = String(dir[range1])
        switch cardinal1 {
        case "N": baseAngle = 0
        case "E": baseAngle = 90
        case "S": baseAngle = 180
        case "W": baseAngle = 270
        default: return nil  // Should not happen with regex
        }
      } else {
        return nil
      }

      if match.numberOfRanges > 2, let range2 = Range(match.range(at: 2), in: dir), !range2.isEmpty
      {
        if let degrees = Double(dir[range2]) {
          deflectionAngle = degrees
        } else {
          // Handle cases like "N" or "E" without degrees
          deflectionAngle = 0
        }
      } else {
        // Handle cases like "N" or "E" without degrees
        deflectionAngle = 0
      }

      if match.numberOfRanges > 3, let range3 = Range(match.range(at: 3), in: dir) {
        let cardinal2 = String(dir[range3])
        // Determine deflection direction based on cardinal1 and cardinal2
        // If cardinal1 is N or S, cardinal2 determines E (+deflection) or W (-deflection)
        // If cardinal1 is E or W, cardinal2 determines N (+deflection from E/W base) or S (-deflection from E/W base)
        switch (dir.prefix(1), cardinal2) {
        case ("N", "E"), ("E", "S"), ("S", "W"), ("W", "N"):
          deflectionDirection = 1  // Clockwise deflection from base
        case ("N", "W"), ("E", "N"), ("S", "E"), ("W", "S"):
          deflectionDirection = -1  // Counter-clockwise deflection from base
        default:
          // Handle pure cardinal directions like "N", "E", "S", "W"
          if dir.count == 1 {
            deflectionAngle = 0  // No deflection for pure cardinal
            deflectionDirection = 1  // Doesn't matter
          } else {
            print("Failed to parse direction string format: \(dir) - Invalid cardinal combination")
            return nil
          }
        }
      } else {
        // Handle pure cardinal directions like "N", "E", "S", "W"
        if dir.count == 1 {
          deflectionAngle = 0  // No deflection for pure cardinal
          deflectionDirection = 1  // Doesn't matter
        } else {
          print("Failed to parse direction string format: \(dir) - Missing second cardinal")
          return nil
        }
      }

      // Calculate final angle
      angleDegrees = baseAngle + (deflectionAngle * Double(deflectionDirection))

      // Normalize angle to be between 0 and 360
      angleDegrees = angleDegrees.truncatingRemainder(dividingBy: 360)
      if angleDegrees < 0 {
        angleDegrees += 360
      }

      print("Parsed direction string \(dir) to \(angleDegrees) degrees")
      return Float(angleDegrees * .pi / 180.0)  // Convert to radians
    }
  }  // End Coordinator Class
}  // End Struct ARViewContainer
