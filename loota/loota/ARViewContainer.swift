// ARViewContainer.swift

import ARKit
import AVFoundation
import Combine  // Import Combine for sink
import CoreLocation
//import DataModels  // Import DataModels to access ARObjectType, HuntType, ProximityMarkerData
import Foundation  // For UUID
import RealityKit
import SwiftUI
import Vision  // For hand pose detection

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
  @Binding public var handTrackingStatus: String
  @Binding public var isDebugMode: Bool

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
    handTrackingStatus: Binding<String>,
    isDebugMode: Binding<Bool>
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
    self._handTrackingStatus = handTrackingStatus
    self._isDebugMode = isDebugMode
  }

  // MARK: - UIViewRepresentable Methods

  public func makeUIView(context: Context) -> ARView {
    print("ARViewContainer makeUIView called.")
    // Reset alignment flag for debugging, to ensure alignment is attempted each time view is made
    // context.coordinator.hasAlignedToNorth = false // Potentially problematic if coordinator is reused; better to do this in init if needed
    // For now, let&#x27;s rely on the Coordinator&#x27;s own initialization of hasAlignedToNorth = false

    let arView = ARView(frame: .zero)

    // Configure AR session for world tracking
    let worldConfig = ARWorldTrackingConfiguration()
    worldConfig.worldAlignment = .gravity  // Explicitly set to ensure no ARKit heading alignment
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

      // Update status after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        if context.coordinator.hasAlignedToNorth {
          context.coordinator.statusMessage = "AR Ready - Objects placed"
        } else {
          context.coordinator.statusMessage = "Point North to place objects"
        }
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
      handTrackingStatus: $handTrackingStatus,
      isDebugMode: $isDebugMode
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
    @Binding public var handTrackingStatusBinding: String
    @Binding public var isDebugMode: Bool
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

    // Hand gesture detection properties
    public var handPoseRequest: VNDetectHumanHandPoseRequest?
    public var isHandVisible: Bool = false
    public var isSummoning: Bool = false
    public var summoningEntity: ModelEntity?
    public var originalEntityPosition: SIMD3<Float>?
    public var summonStartTime: CFTimeInterval?
    public let summonDuration: TimeInterval = 10.0  // Increased to 10 seconds for much slower approach
    public let proximityThreshold: Float = 3.048  // 10 feet in meters
    public var collectedEntities: Set<ModelEntity> = []  // Track collected entities
    public var frameCounter: Int = 0
    public var handTrackingStatus: String = "Initializing..."
    public var lastHandDetectionTime: Date?
    public var lastHandPosition: CGPoint?

    // Hand visualization properties removed - no longer needed

    // Base anchor for world alignment
    public var baseAnchor: AnchorEntity?

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

        // Only attempt to mark as "aligned" (user physically aligned to North) once,
        // if we have a sufficiently accurate heading AND user is pointing North.
        let NORTH_ALIGNMENT_TOLERANCE: CLLocationDirection = 10.0  // Degrees
        let ACCURACY_THRESHOLD: CLLocationAccuracy = 30.0  // Degrees (Temporarily relaxed from 20.0 for testing)

        if !hasAlignedToNorth,
          let th = newTrueHeading, th >= 0,  // Valid heading number
          let acc = newAccuracy, acc > 0 && acc < ACCURACY_THRESHOLD,  // Good accuracy
          abs(th) < NORTH_ALIGNMENT_TOLERANCE || abs(th - 360.0) < NORTH_ALIGNMENT_TOLERANCE,  // Pointing North
          let arView = arView
        {

          print(
            "Coordinator heading.didSet: User IS pointing North (Heading: \(th)°, Acc: \(acc)°). Conditions MET."
          )

          self.statusMessage = "North detected. Starting AR session..."
          print("Coordinator heading.didSet: Attempting to start AR session.")

          // Set hasAlignedToNorth to prevent this block from running again.
          hasAlignedToNorth = true

          // Call method to start the session and then place objects.
          startSessionAndPlaceObjects()

        } else {
          // Update status message to guide user or explain why not proceeding
          if hasAlignedToNorth {
            // Already "aligned" and placed, no further status needed from here unless resetting
          } else if let th = newTrueHeading, th >= 0, let acc = newAccuracy,
            acc > 0 && acc < ACCURACY_THRESHOLD
          {
            self.statusMessage = String(
              format: "Point North (0° ±%.0f°). Current: %.1f°", NORTH_ALIGNMENT_TOLERANCE, th)
          } else if let acc = newAccuracy, acc >= ACCURACY_THRESHOLD {
            self.statusMessage = String(
              format: "Improve compass accuracy (current: %.1f°). Try figure-eight motion.", acc)
          } else {
            self.statusMessage = "Point North. Waiting for good heading..."
          }

          let reasonNotReady = """
            hasAlignedToNorth=\(hasAlignedToNorth), \
            newTrueHeading=\(String(describing: newTrueHeading)) (valid: \((newTrueHeading ?? -1) >= 0)), \
            newAccuracy=\(String(describing: newAccuracy)) (sufficient for check: \((newAccuracy ?? -1) > 0 && (newAccuracy ?? 999) < ACCURACY_THRESHOLD)), \
            pointingNorthCheck: \( (abs(newTrueHeading ?? 999) < NORTH_ALIGNMENT_TOLERANCE || abs((newTrueHeading ?? 999) - 360.0) < NORTH_ALIGNMENT_TOLERANCE) ), \
            arView is nil=\(arView == nil)
            """
          print(
            "Coordinator heading.didSet: Conditions for North alignment NOT MET or already aligned. Details: \(reasonNotReady)"
          )
        }
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
      handTrackingStatus: Binding<String>,
      isDebugMode: Binding<Bool>
    ) {
      print("Coordinator init: Setting up.")
      self.referenceLocation = initialReferenceLocation  // Assign initial value
      self._objectLocations = objectLocations
      self._objectType = objectType
      self._statusMessage = statusMessage
      self._currentHuntType = currentHuntType  // Assign binding
      self._proximityMarkers = proximityMarkers  // Assign binding
      self._pinData = pinData
      self._handTrackingStatusBinding = handTrackingStatus
      self._isDebugMode = isDebugMode

      // Removed problematic referenceLocationObserver

      super.init()

      // Setup hand pose detection
      setupHandPoseDetection()

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
        "Coordinator attemptPlacementIfReady: Checking conditions. hasAlignedToNorth=\(hasAlignedToNorth), referenceLocationIsNil=\(self.referenceLocation == nil), hasPlacedObjects=\(hasPlacedObjects), arViewIsNil=\(self.arView == nil)"
      )
      guard hasAlignedToNorth, self.referenceLocation != nil, !hasPlacedObjects,
        let arView = self.arView
      else {
        print("Coordinator attemptPlacementIfReady: Conditions not met or already placed.")
        return
      }

      // Force placement if we have a valid reference location
      if self.referenceLocation != nil {
        self.placeObjectsAction?(arView)
        self.hasPlacedObjects = true
      }

      print("Coordinator attemptPlacementIfReady: All conditions MET. Calling placeObjectsAction.")
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

          guard let entity = createEntity(for: self.objectType) else { continue }
          objectAnchor.addChild(entity)

          // Get pin data for this index
          let pin = index < self.pinData.count ? self.pinData[index] : nil
          let markerNumber = (pin?.order ?? index) + 1
          let pinId = pin?.id ?? "unknown"
          let shortId = pinId.prefix(8)

          // Store the mapping between entity and pin ID
          self.entityToPinId[entity] = pinId
          self.coinEntities.append(entity)

          // Add marker number label
          let numberLabel = createLabelEntity(text: "\(markerNumber)")
          numberLabel.position = [0, 0.25, 0]  // Higher position for number
          objectAnchor.addChild(numberLabel)

          // Add ID label only in debug mode
          if self.isDebugMode {
            let idLabel = createLabelEntity(text: String(shortId))
            idLabel.position = [0, 0.1, 0]  // Lower position for ID
            objectAnchor.addChild(idLabel)
          }

          print(
            "Coordinator placeObjects: Added labels - Marker: \(markerNumber), ID: \(shortId), Entity mapped to pinId: \(pinId)"
          )

          if let baseAnchor = self.baseAnchor {
            baseAnchor.addChild(objectAnchor)  // Add object's anchor to the main rotated baseAnchor
            print(
              "Coordinator placeObjects: Added proximity anchor to self.baseAnchor at local position \(arPositionInBaseFrame)"
            )
          } else {
            // This case should ideally not happen if alignment occurs first
            // If it does, objectAnchor.position will be interpreted as world coordinates
            arView.scene.addAnchor(objectAnchor)
            print(
              "Coordinator placeObjects: WARNING - Added proximity anchor directly to arView.scene (self.baseAnchor not found). Position \(arPositionInBaseFrame) will be world coords."
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

          let objectAnchor = AnchorEntity()  // Create a new anchor, positioned relative to its parent
          objectAnchor.position = arPositionInBaseFrame  // Set its position within baseAnchor's coordinate system

          guard let entity = createEntity(for: objectTypeForProximity) else { continue }
          objectAnchor.addChild(entity)

          // Get pin data for this index
          let pin = index < self.pinData.count ? self.pinData[index] : nil
          let markerNumber = (pin?.order ?? index) + 1
          let pinId = pin?.id ?? "unknown"
          let shortId = pinId.prefix(8)

          // Store the mapping between entity and pin ID
          self.entityToPinId[entity] = pinId
          self.coinEntities.append(entity)

          // Add marker number label
          let numberLabel = createLabelEntity(text: "\(markerNumber)")
          numberLabel.position = [0, 0.25, 0]  // Higher position for number
          objectAnchor.addChild(numberLabel)

          // Add ID label only in debug mode
          if self.isDebugMode {
            let idLabel = createLabelEntity(text: String(shortId))
            idLabel.position = [0, 0.1, 0]  // Lower position for ID
            objectAnchor.addChild(idLabel)
          }

          print(
            "Coordinator placeObjects: Added proximity labels - Marker: \(markerNumber), ID: \(shortId), Entity mapped to pinId: \(pinId)"
          )

          if let baseAnchor = self.baseAnchor {
            baseAnchor.addChild(objectAnchor)
            print(
              "Coordinator placeObjects: Added proximity anchor to self.baseAnchor at local position \(arPositionInBaseFrame)"
            )
          } else {
            // This case should ideally not happen if alignment occurs first
            // If it does, objectAnchor.position will be interpreted as world coordinates
            arView.scene.addAnchor(objectAnchor)
            print(
              "Coordinator placeObjects: WARNING - Added proximity anchor directly to arView.scene (self.baseAnchor not found). Position \(arPositionInBaseFrame) will be world coords."
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
        return CoinEntityFactory.makeCoin()
      case .dollarSign:
        do {
          let dollarSign = try ModelEntity.loadModel(named: "DollarSign")
          dollarSign.scale = SIMD3<Float>(repeating: 0.02)
          return dollarSign
        } catch {
          print("Error loading DollarSign model: \(error). Falling back to coin.")
          return CoinEntityFactory.makeCoin()  // Fallback
        }
      case .none:
        return nil
      }
    }

    // Simplified conversion function
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
      let deltaNorth = (lat2 - lat1) * metersPerDegree
      let deltaEast = (lon2 - lon1) * metersPerDegree * cos(Coordinator.degreesToRadians(lat1))
      print("convertToARWorldCoordinate: Returning (E, -N): (\(deltaEast), \(-deltaNorth))")
      return SIMD3<Float>(Float(deltaEast), 0, Float(-deltaNorth))  // Reverted to original
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

    // Method to ensure baseAnchor exists at world origin with identity rotation.
    private func ensureBaseAnchorExists(in arView: ARView) {
      print("Coordinator ensureBaseAnchorExists: Ensuring baseAnchor exists at identity.")
      if baseAnchor == nil {
        baseAnchor = AnchorEntity(world: .zero)  // Create anchor at world origin, identity rotation
        arView.scene.addAnchor(baseAnchor!)
        print(
          "Coordinator ensureBaseAnchorExists: Created baseAnchor at world origin (identity rotation)."
        )
      } else {
        if baseAnchor?.scene == nil {  // If it was removed (e.g. by session reset not used anymore)
          arView.scene.addAnchor(baseAnchor!)
        }
        baseAnchor!.transform = .identity  // Ensure identity transform
        print(
          "Coordinator ensureBaseAnchorExists: Ensured existing baseAnchor is in scene and at identity."
        )
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
      guard !coinEntities.isEmpty else { return }  // Don't process if no entities

      let now = displayLink.timestamp
      let dt: Float
      if let last = lastTimestamp {
        dt = Float(now - last)
      } else {
        dt = 0  // First frame
      }
      lastTimestamp = now

      // Angle increment for this frame
      let anglePerSecond: Float = 2 * .pi / Float(revolutionDuration)
      accumulatedAngle += anglePerSecond * dt

      // Spin all entities
      let yRot = simd_quatf(angle: accumulatedAngle, axis: [0, 1, 0])
      for entity in coinEntities {
        if self.objectType == .coin {  // Access wrapped value directly
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

      // Iterate backwards safely for removal
      for index in anchors.indices.reversed() {
        guard index < coinEntities.count else { continue }  // Bounds check

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

        if distance < collectionThreshold {
          if isSummonedObject {
            print("Summoned object collected at distance: \(distance)")
            // Clear summoning state since object is being collected
            isSummoning = false
            summoningEntity = nil
            originalEntityPosition = nil
            summonStartTime = nil
          } else {
            print("Object collected at distance: \(distance)")
          }

          // Mark as collected to hide labels
          collectedEntities.insert(entity)
          hideLabelsForEntity(entity, anchor: anchor)

          playCoinSound()

          // Get the pin ID for this specific entity
          let pinId = entityToPinId[entity] ?? "unknown"
          print("Collecting entity with pinId: \(pinId)")

          // Remove anchor from the base anchor
          anchor.removeFromParent()

          // Remove from coordinator arrays and mapping
          anchors.remove(at: index)
          let removedEntity = coinEntities.remove(at: index)
          objectLocations.remove(at: index)
          entityToPinId.removeValue(forKey: removedEntity)

          // Trigger callback with the specific pin ID
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
      } catch {
        print("Failed to play coin sound: \(error)")
      }
    }

    // MARK: - Hand Pose Detection

    private func setupHandPoseDetection() {
      print("🤲 HAND_TRACKING: Setting up hand pose detection")
      handTrackingStatusBinding = "Setting up..."

      handPoseRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
        if let error = error {
          print("🚨 HAND_TRACKING: Hand pose detection error: \(error)")
          DispatchQueue.main.async {
            self?.handTrackingStatusBinding = "Error: \(error.localizedDescription)"
          }
          return
        }

        guard let observations = request.results as? [VNHumanHandPoseObservation] else {
          print("🤲 HAND_TRACKING: No hand observations found")
          DispatchQueue.main.async {
            self?.handTrackingStatusBinding = "No hands detected"
            self?.lastHandDetectionTime = nil
          }
          return
        }

        print("🤲 HAND_TRACKING: Found \(observations.count) hand observation(s)")

        DispatchQueue.main.async {
          self?.lastHandDetectionTime = Date()
          self?.processHandPoseObservations(observations)
        }
      }

      // Configure the request for hand visibility detection
      handPoseRequest?.maximumHandCount = 1
      handTrackingStatusBinding = "Ready - Show hand to summon"
      print("🤲 HAND_TRACKING: Setup complete - maximum hands: 1")
    }

    private func processHandPoseObservations(_ observations: [VNHumanHandPoseObservation]) {
      let currentTime = Date()

      guard let observation = observations.first else {
        // No hand detected - clear summoning state
        if isHandVisible {
          print("🤲 HAND_TRACKING: Hand no longer visible, stopping summoning")
          isHandVisible = false
          if isSummoning {
            stopObjectSummoning()
          }
        }

        // Hand visualization no longer needed

        handTrackingStatusBinding = "No hand detected"
        return
      }

      do {
        // Hand landmarks no longer needed for simplified tracking

        // Get wrist point for position tracking
        let wristPoint = try observation.recognizedPoint(.wrist)

        // Check if hand is visible with good confidence
        guard wristPoint.confidence > 0.6 else {
          print(
            "🤲 HAND_TRACKING: Low confidence wrist detection: \(String(format: "%.2f", wristPoint.confidence))"
          )
          handTrackingStatusBinding = "Hand detection poor quality"
          return
        }

        // Hand is visible and high quality - immediately activate summoning
        let currentHandPosition = wristPoint.location

        if !isHandVisible {
          // Hand just became visible - start summoning immediately
          print("🤲 HAND_TRACKING: Hand detected - immediately activating summoning!")
          isHandVisible = true
          startObjectSummoning()
          if summoningEntity != nil {
            isSummoning = true
            handTrackingStatusBinding = "🚀 SUMMONING ACTIVE!"
          } else {
            handTrackingStatusBinding = "No objects nearby to summon"
          }
        } else if isSummoning && summoningEntity != nil {
          // Continue summoning while hand remains visible
          handTrackingStatusBinding = "🚀 SUMMONING CONTINUES!"
        } else if summoningEntity == nil {
          // Hand is visible but no object to summon
          handTrackingStatusBinding = "Hand visible - no objects nearby"
        }

        // Update last position and time
        lastHandPosition = currentHandPosition
        lastHandDetectionTime = currentTime

      } catch {
        print("🚨 HAND_TRACKING: Error processing hand landmarks: \(error)")
        handTrackingStatusBinding = "Hand tracking error"
      }
    }

    // Removed complex hand landmark processing - now using simple wrist detection only

    // Hand overlay and visualization methods removed - no longer needed for simplified summoning

    // MARK: - Object Summoning

    private func startObjectSummoning() {
      // Don't start if already summoning the same object
      guard summoningEntity == nil else { return }

      guard let arView = arView, let camera = arView.session.currentFrame?.camera else {
        return
      }

      let cameraTransform = camera.transform
      let cameraPosition = SIMD3<Float>(
        cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

      // Find the closest entity within proximity threshold
      var closestEntity: ModelEntity?
      var closestDistance: Float = Float.infinity

      for entity in coinEntities {
        let entityWorldPosition = entity.position(relativeTo: nil)
        let distance = simd_distance(cameraPosition, entityWorldPosition)

        if distance <= proximityThreshold && distance < closestDistance {
          closestDistance = distance
          closestEntity = entity
        }
      }

      guard let targetEntity = closestEntity else {
        print("No objects within \(proximityThreshold) meters for summoning")
        isSummoning = false
        return
      }

      print("Summoning object at distance: \(closestDistance) meters")

      // Store the original position and start summoning
      summoningEntity = targetEntity
      originalEntityPosition = targetEntity.position(relativeTo: nil)
      summonStartTime = CACurrentMediaTime()
      isSummoning = true

      // Start the summoning animation
      animateObjectTowardsUser(targetEntity, cameraPosition: cameraPosition)
    }

    private func stopObjectSummoning() {
      guard let entity = summoningEntity,
        let originalPosition = originalEntityPosition
      else {
        isSummoning = false
        return
      }

      // Stop any ongoing animation and return object to original position
      entity.stopAllAnimations()

      // Animate back to original position
      let returnTransform = Transform(translation: originalPosition)
      entity.move(to: returnTransform, relativeTo: nil, duration: 0.5)

      // Clear summoning state
      isSummoning = false
      summoningEntity = nil
      originalEntityPosition = nil
      summonStartTime = nil

      print("Object summoning stopped, returning to original position")
    }

    private func animateObjectTowardsUser(_ entity: ModelEntity, cameraPosition: SIMD3<Float>) {
      // Calculate direction from entity to camera and initial distance
      let entityPosition = entity.position(relativeTo: nil)
      let direction = normalize(cameraPosition - entityPosition)
      let totalDistance = simd_distance(entityPosition, cameraPosition)

      // Create a very slow-to-fast animation that brings object close to user over 10 seconds
      let stage1Duration: TimeInterval = 8.0  // Very slow start - first 8 seconds
      let stage2Duration: TimeInterval = 2.0  // Fast finish - final 2 seconds
      
      // Stage 1: Move slowly toward user (50% of distance) with gentle upward arc
      let stage1Distance = totalDistance * 0.5
      let stage1Position = entityPosition + direction * stage1Distance
      var stage1Transform = Transform(translation: stage1Position)
      stage1Transform.translation.y += 0.2  // Gentle upward arc for magical effect
      
      // Start very slow animation with easeOut
      entity.move(to: stage1Transform, relativeTo: nil, duration: stage1Duration, timingFunction: .easeOut)
      
      // Stage 2: Move much closer to user for collection detection
      DispatchQueue.main.asyncAfter(deadline: .now() + stage1Duration) { [weak self] in
        guard let self = self, entity == self.summoningEntity else { return }
        
        // Move to within collection range (0.5 meters from camera for clear collection)
        let collectionDistance = totalDistance - 0.5  // Leave 0.5m for collection detection
        let finalPosition = entityPosition + direction * collectionDistance
        let finalTransform = Transform(translation: finalPosition)
        
        // Fast final approach that brings object close enough for collection
        entity.move(to: finalTransform, relativeTo: nil, duration: stage2Duration, timingFunction: .easeIn)
      }

      // Add gentle floating animation throughout
      addFloatingAnimation(to: entity, duration: summonDuration)
      
      // Note: No auto-collection - let the normal proximity detection handle it
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

      // If baseAnchor exists, its children (which were in self.anchors) should now be gone.
      // For sanity, one could also do baseAnchor?.children.removeAll(), but it might be redundant.
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
        print("🤲 HAND_TRACKING: Processing frame #\(frameCounter)")
        processHandPoseInFrame(frame)
      }
    }

    private func processHandPoseInFrame(_ frame: ARFrame) {
      guard let handPoseRequest = handPoseRequest else {
        print("🚨 HAND_TRACKING: handPoseRequest is nil!")
        return
      }

      let pixelBuffer = frame.capturedImage
      let imageRequestHandler = VNImageRequestHandler(
        cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

      do {
        try imageRequestHandler.perform([handPoseRequest])
        print("🤲 HAND_TRACKING: Vision request performed successfully")
      } catch {
        print("🚨 HAND_TRACKING: Failed to perform hand pose detection: \(error)")
      }
    }

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


