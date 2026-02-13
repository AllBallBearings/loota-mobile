// SimulatedARViewContainer.swift
// Simulated AR view for testing in iOS Simulator without physical hardware.
// Uses RealityKit in nonAR mode with a programmatic camera that can be controlled
// via on-screen joysticks to simulate phone movement.

import AVFoundation
import CoreLocation
import Foundation
import RealityKit
import SwiftUI
import UIKit

public struct SimulatedARViewContainer: UIViewRepresentable {
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
  @Binding public var debugObjectTypeOverride: ARObjectType?

  // Simulated camera state controlled by external joystick inputs
  @Binding public var simulatedCameraYaw: Float  // Left-right rotation (radians)
  @Binding public var simulatedCameraPitch: Float  // Up-down tilt (radians)
  @Binding public var simulatedCameraX: Float  // World X position
  @Binding public var simulatedCameraY: Float  // World Y position (height)
  @Binding public var simulatedCameraZ: Float  // World Z position

  private func placementKey() -> String {
    let hunt = currentHuntType?.rawValue ?? "none"
    let ref = referenceLocation.map { "\($0.latitude),\($0.longitude)" } ?? "nil"
    let pins = pinData.map { pin in
      let lat = pin.lat.map { String($0) } ?? "nil"
      let lng = pin.lng.map { String($0) } ?? "nil"
      let dist = pin.distanceFt.map { String($0) } ?? "nil"
      let dir = pin.directionStr ?? "nil"
      let pinId = pin.id ?? "nil"
      let order = pin.order.map { String($0) } ?? "nil"
      let lootType = pin.objectType?.rawValue ?? "nil"
      return "\(pinId)|\(order)|\(lootType)|\(lat)|\(lng)|\(dist)|\(dir)"
    }.joined(separator: ";")
    let geo = objectLocations.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
    let prox = proximityMarkers.map { "\($0.dist),\($0.dir)" }.joined(separator: ";")
    return
      "hunt:\(hunt)|ref:\(ref)|objType:\(objectType.rawValue)|pins:\(pins)|geo:\(geo)|prox:\(prox)"
  }

  public func makeUIView(context: Context) -> ARView {
    #if targetEnvironment(simulator)
      let isSimulatorBuild = true
    #else
      let isSimulatorBuild = false
    #endif

    let screenBounds = UIScreen.main.bounds
    let arView = ARView(
      frame: screenBounds, cameraMode: .nonAR, automaticallyConfigureSession: false)
    // Simulator harness uses SwiftUI controls, so ARView should never intercept touches.
    arView.isUserInteractionEnabled = false

    // Dark environment background to simulate outdoor scene
    arView.environment.background = .color(UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0))
    arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    if !isSimulatorBuild {
      // Add lighting on device builds only. Simulator keeps unlit materials for performance.
      let lightAnchor = AnchorEntity(world: .zero)
      let directionalLight = DirectionalLight()
      directionalLight.light.color = .white
      directionalLight.light.intensity = 3000
      directionalLight.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0, 0])
      lightAnchor.addChild(directionalLight)

      let ambientLight = DirectionalLight()
      ambientLight.light.color = UIColor(white: 0.6, alpha: 1.0)
      ambientLight.light.intensity = 1000
      ambientLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, 0, 0])
      lightAnchor.addChild(ambientLight)
      arView.scene.addAnchor(lightAnchor)
    }

    // Create camera
    let cameraAnchor = AnchorEntity(world: .zero)
    let camera = PerspectiveCamera()
    camera.camera.fieldOfViewInDegrees = 60
    cameraAnchor.addChild(camera)
    arView.scene.addAnchor(cameraAnchor)
    context.coordinator.cameraAnchor = cameraAnchor
    context.coordinator.cameraEntity = camera

    // Create ground plane grid for spatial reference
    context.coordinator.createGroundPlane(in: arView)

    // Create base anchor for objects (same as real AR system)
    let baseAnchor = AnchorEntity(world: .zero)
    arView.scene.addAnchor(baseAnchor)
    context.coordinator.baseAnchor = baseAnchor

    context.coordinator.arView = arView
    context.coordinator.onCoinCollected = self.onCoinCollected

    // Setup display link for animations
    let displayLink = CADisplayLink(
      target: context.coordinator, selector: #selector(SimCoordinator.updateFrame))
    displayLink.preferredFramesPerSecond = isSimulatorBuild ? 30 : 60
    displayLink.add(to: .main, forMode: .common)
    context.coordinator.displayLink = displayLink

    // Initial camera position
    context.coordinator.updateCameraTransform(
      yaw: simulatedCameraYaw, pitch: simulatedCameraPitch,
      x: simulatedCameraX, y: simulatedCameraY, z: simulatedCameraZ)

    // Attempt placement after a short delay to let models load
    let placementDelay: TimeInterval = isSimulatorBuild ? 0.1 : 0.5
    DispatchQueue.main.asyncAfter(deadline: .now() + placementDelay) {
      context.coordinator.attemptPlacementIfReady()
    }

    return arView
  }

  public func updateUIView(_ uiView: ARView, context: Context) {
    // Update camera transform from bindings
    context.coordinator.updateCameraTransform(
      yaw: simulatedCameraYaw, pitch: simulatedCameraPitch,
      x: simulatedCameraX, y: simulatedCameraY, z: simulatedCameraZ)

    // Update reference location if changed
    if context.coordinator.referenceLocation?.latitude != self.referenceLocation?.latitude
      || context.coordinator.referenceLocation?.longitude != self.referenceLocation?.longitude
    {
      context.coordinator.referenceLocation = self.referenceLocation
    }

    context.coordinator.onCoinCollected = self.onCoinCollected

    let newPlacementKey = placementKey()
    if context.coordinator.lastPlacementKey != newPlacementKey {
      context.coordinator.lastPlacementKey = newPlacementKey
      context.coordinator.hasPlacedObjects = false
      context.coordinator.clearAnchors()
    }

    // Attempt placement if not already done
    if !context.coordinator.hasPlacedObjects {
      DispatchQueue.main.async {
        context.coordinator.attemptPlacementIfReady()
      }
    }
  }

  public func makeCoordinator() -> SimCoordinator {
    SimCoordinator(
      referenceLocation: self.referenceLocation,
      objectLocations: $objectLocations,
      objectType: $objectType,
      statusMessage: $statusMessage,
      currentHuntType: $currentHuntType,
      proximityMarkers: $proximityMarkers,
      pinData: $pinData,
      isSummoningActive: $isSummoningActive,
      focusedLootId: $focusedLootId,
      focusedLootDistance: $focusedLootDistance,
      nearestLootDistance: $nearestLootDistance,
      nearestLootDirection: $nearestLootDirection,
      isDebugMode: $isDebugMode,
      isPerformanceMode: $isPerformanceMode,
      isLoadingModels: $isLoadingModels,
      debugObjectTypeOverride: $debugObjectTypeOverride
    )
  }
}

// MARK: - Simulated Coordinator

public class SimCoordinator: NSObject {
  #if targetEnvironment(simulator)
    private let usesLightweightSimulatorAssets = true
  #else
    private let usesLightweightSimulatorAssets = false
  #endif
  // Location
  public var referenceLocation: CLLocationCoordinate2D?

  // Bindings (same as real coordinator)
  @Binding var objectLocations: [CLLocationCoordinate2D]
  @Binding var objectType: ARObjectType
  @Binding var statusMessage: String
  @Binding var currentHuntType: HuntType?
  @Binding var proximityMarkers: [ProximityMarkerData]
  @Binding var pinData: [PinData]
  @Binding var isSummoningActiveBinding: Bool
  @Binding var focusedLootIdBinding: String?
  @Binding var focusedLootDistanceBinding: Float?
  @Binding var nearestLootDistanceBinding: Float?
  @Binding var nearestLootDirectionBinding: Float
  @Binding var isDebugMode: Bool
  @Binding var isPerformanceMode: Bool
  @Binding var isLoadingModels: Bool
  @Binding var debugObjectTypeOverride: ARObjectType?

  // AR view and scene
  weak var arView: ARView?
  var baseAnchor: AnchorEntity?
  var cameraAnchor: AnchorEntity?
  var cameraEntity: PerspectiveCamera?
  var displayLink: CADisplayLink?

  // Simulated camera state
  var simulatedCameraTransform: simd_float4x4 = matrix_identity_float4x4

  // Entity tracking (same as real coordinator)
  var coinEntities: [ModelEntity] = []
  var baseOrientations: [ModelEntity: simd_quatf] = [:]
  var anchors: [AnchorEntity] = []
  var entityToPinId: [ModelEntity: String] = [:]
  var collectedEntities: Set<ModelEntity> = []
  var onCoinCollected: ((String) -> Void)?
  var hasPlacedObjects = false
  var animationTime: Float = 0
  var frameCounter: Int = 0
  var audioPlayer: AVAudioPlayer?
  var cachedCoinStarModel: ModelEntity?
  var didAttemptCoinStarLoad = false
  var lastPlacementKey: String?

  // Focus and summoning
  var focusedEntity: ModelEntity?
  var summoningEntity: ModelEntity?
  var originalEntityPosition: SIMD3<Float>?
  var originalEntityScale: SIMD3<Float>?
  var originalSummonDistance: Float?
  var wasSummoningActive: Bool = false
  let focusRange: Float = 5.0
  let summonSpeed: Float = 0.8
  let baseHoverHeight: Float = 1.22  // ~4 feet average hover height

  // Ground plane
  var groundEntity: ModelEntity?

  init(
    referenceLocation: CLLocationCoordinate2D?,
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
    isPerformanceMode: Binding<Bool>,
    isLoadingModels: Binding<Bool>,
    debugObjectTypeOverride: Binding<ARObjectType?>
  ) {
    self.referenceLocation = referenceLocation
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
    self._isPerformanceMode = isPerformanceMode
    self._isLoadingModels = isLoadingModels
    self._debugObjectTypeOverride = debugObjectTypeOverride
    super.init()
  }

  deinit {
    displayLink?.invalidate()
  }

  // MARK: - Camera Control

  func updateCameraTransform(yaw: Float, pitch: Float, x: Float, y: Float, z: Float) {
    // Build rotation: yaw around Y, then pitch around X
    let yawRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
    let combinedRotation = yawRotation * pitchRotation

    cameraAnchor?.position = SIMD3<Float>(x, y, z)
    cameraAnchor?.orientation = combinedRotation

    // Build the 4x4 transform matrix for collection/focus detection
    let rotationMatrix = simd_matrix4x4(combinedRotation)
    var translationMatrix = matrix_identity_float4x4
    translationMatrix.columns.3 = SIMD4<Float>(x, y, z, 1)
    simulatedCameraTransform = translationMatrix * rotationMatrix

    // Keep a copy for focus/collection math; rendered camera is driven by cameraAnchor.
  }

  // MARK: - Ground Plane

  func createGroundPlane(in arView: ARView) {
    let groundAnchor = AnchorEntity(world: .zero)

    // Create a large grid ground plane
    let gridSize: Float = usesLightweightSimulatorAssets ? 24.0 : 100.0
    let gridMaterial = UnlitMaterial(color: UIColor(white: 0.25, alpha: 0.8))
    let ground = ModelEntity(
      mesh: .generatePlane(width: gridSize, depth: gridSize),
      materials: [gridMaterial]
    )
    ground.position = SIMD3<Float>(0, -0.01, 0)  // Slightly below origin
    groundAnchor.addChild(ground)
    groundEntity = ground

    // Add grid lines for spatial reference
    let lineColor = UIColor(white: 0.35, alpha: 0.6)
    let lineMaterial = UnlitMaterial(color: lineColor)
    let lineThickness: Float = 0.02
    let lineSpacing: Float = usesLightweightSimulatorAssets ? 2.0 : 1.0
    let lineCount = Int(gridSize / lineSpacing / 2)

    for i in -lineCount...lineCount {
      let offset = Float(i) * lineSpacing

      // Lines along X axis
      let xLine = ModelEntity(
        mesh: .generateBox(width: gridSize, height: 0.005, depth: lineThickness),
        materials: [lineMaterial]
      )
      xLine.position = SIMD3<Float>(0, 0, offset)
      groundAnchor.addChild(xLine)

      // Lines along Z axis
      let zLine = ModelEntity(
        mesh: .generateBox(width: lineThickness, height: 0.005, depth: gridSize),
        materials: [lineMaterial]
      )
      zLine.position = SIMD3<Float>(offset, 0, 0)
      groundAnchor.addChild(zLine)
    }

    if !usesLightweightSimulatorAssets {
      // Add cardinal direction markers
      let directions: [(String, SIMD3<Float>, UIColor)] = [
        ("N", SIMD3<Float>(0, 0.1, -5), .red),
        ("S", SIMD3<Float>(0, 0.1, 5), .blue),
        ("E", SIMD3<Float>(5, 0.1, 0), .green),
        ("W", SIMD3<Float>(-5, 0.1, 0), .yellow),
      ]

      for (text, position, color) in directions {
        let textMesh = MeshResource.generateText(
          text,
          extrusionDepth: 0.02,
          font: .systemFont(ofSize: 0.5),
          containerFrame: .zero,
          alignment: .center,
          lineBreakMode: .byWordWrapping
        )
        let material = UnlitMaterial(color: color)
        let label = ModelEntity(mesh: textMesh, materials: [material])
        label.position = position
        // Rotate to face up
        label.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        groundAnchor.addChild(label)
      }
    }

    // Add origin marker (red/green/blue axes)
    let axisLength: Float = 1.0
    let axisThickness: Float = 0.02

    let xAxis = ModelEntity(
      mesh: .generateBox(width: axisLength, height: axisThickness, depth: axisThickness),
      materials: [UnlitMaterial(color: .red)]
    )
    xAxis.position = SIMD3<Float>(axisLength / 2, 0.01, 0)
    groundAnchor.addChild(xAxis)

    let yAxis = ModelEntity(
      mesh: .generateBox(width: axisThickness, height: axisLength, depth: axisThickness),
      materials: [UnlitMaterial(color: .green)]
    )
    yAxis.position = SIMD3<Float>(0, axisLength / 2, 0)
    groundAnchor.addChild(yAxis)

    let zAxis = ModelEntity(
      mesh: .generateBox(width: axisThickness, height: axisThickness, depth: axisLength),
      materials: [UnlitMaterial(color: .blue)]
    )
    zAxis.position = SIMD3<Float>(0, 0.01, axisLength / 2)
    groundAnchor.addChild(zAxis)

    arView.scene.addAnchor(groundAnchor)
  }

  // MARK: - Entity Creation (shared with real AR system)

  func createEntity(for type: ARObjectType) -> ModelEntity? {
    let effectiveType: ARObjectType
    if isDebugMode, let override = debugObjectTypeOverride, override != .none {
      effectiveType = override
    } else {
      effectiveType = type
    }

    if usesLightweightSimulatorAssets {
      return createLightweightEntity(for: effectiveType)
    }

    switch effectiveType {
    case .coin:
      return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
    case .dollarSign:
      return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
    case .giftCard:
      return GiftCardEntityFactory.makeGiftCard()
    case .none:
      return nil
    }
  }

  private func createLightweightEntity(for type: ARObjectType) -> ModelEntity? {
    switch type {
    case .coin:
      return makeSimulatorCoinEntity()
    case .dollarSign:
      return makeSimulatorCoinEntity()
    case .giftCard:
      return GiftCardEntityFactory.makeGiftCard()
    case .none:
      return nil
    }
  }

  private func makeSimulatorCoinEntity() -> ModelEntity {
    if let cachedCoinStarModel {
      let clone = cachedCoinStarModel.clone(recursive: true)
      clone.scale = SIMD3<Float>(repeating: 0.12)
      clone.name = "coin_star_model"
      return clone
    }

    if !didAttemptCoinStarLoad {
      didAttemptCoinStarLoad = true
      if let loadedEntity = try? Entity.load(named: "CoinStar") {
        if let coinStarModel = loadedEntity as? ModelEntity {
          cachedCoinStarModel = coinStarModel
          let clone = coinStarModel.clone(recursive: true)
          clone.scale = SIMD3<Float>(repeating: 0.12)
          clone.name = "coin_star_model"
          return clone
        }

        if let firstModelChild = loadedEntity.children.first(where: { $0 is ModelEntity })
          as? ModelEntity
        {
          cachedCoinStarModel = firstModelChild
          let clone = firstModelChild.clone(recursive: true)
          clone.scale = SIMD3<Float>(repeating: 0.12)
          clone.name = "coin_star_model"
          return clone
        }
      }
      print("⚠️ SIM: Failed to load CoinStar.usdz, falling back to default coin model")
    }

    return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
  }

  // MARK: - Placement

  func attemptPlacementIfReady() {
    guard !hasPlacedObjects else { return }
    guard self.referenceLocation != nil else { return }

    if usesLightweightSimulatorAssets {
      preloadLightweightAssetsIfNeeded()
      hasPlacedObjects = true
      clearAnchors()
      placeObjects()
      return
    }

    // Preload models if needed
    let needsCoinModel = (self.currentHuntType == .proximity) || (self.objectType == .coin)
    if needsCoinModel && CoinEntityFactory.shouldDeferPlacementForCoinModel {
      if !CoinEntityFactory.isCoinModelLoading {
        self.isLoadingModels = true
        CoinEntityFactory.preloadCoinModel { [weak self] _ in
          DispatchQueue.main.async {
            self?.isLoadingModels = false
            self?.attemptPlacementIfReady()
          }
        }
      }
      return
    }

    let needsGiftCardModel =
      (self.objectType == .giftCard)
      || self.pinData.contains(where: { $0.objectType == .giftCard })
    if needsGiftCardModel && GiftCardEntityFactory.shouldDeferPlacementForGiftCardModel {
      if !GiftCardEntityFactory.isGiftCardModelLoading {
        self.isLoadingModels = true
        GiftCardEntityFactory.preloadGiftCardModel { [weak self] _ in
          DispatchQueue.main.async {
            self?.isLoadingModels = false
            self?.attemptPlacementIfReady()
          }
        }
      }
      return
    }

    hasPlacedObjects = true
    clearAnchors()
    placeObjects()
  }

  private func preloadLightweightAssetsIfNeeded() {
    let needsGiftCardModel =
      (self.objectType == .giftCard)
      || self.pinData.contains(where: { $0.objectType == .giftCard })
    if needsGiftCardModel && GiftCardEntityFactory.shouldDeferPlacementForGiftCardModel
      && !GiftCardEntityFactory.isGiftCardModelLoading
    {
      GiftCardEntityFactory.preloadGiftCardModel { [weak self] loaded in
        guard loaded, let self = self else { return }
        DispatchQueue.main.async {
          self.hasPlacedObjects = false
          self.clearAnchors()
          self.attemptPlacementIfReady()
        }
      }
    }
  }

  private func placeObjects() {
    guard let baseAnchor = baseAnchor, let refLoc = referenceLocation else { return }

    switch currentHuntType {
    case .geolocation:
      for (index, location) in objectLocations.enumerated() {
        let arPosition = convertToARWorldCoordinate(
          objectLocation: location, referenceLocation: refLoc)
        placeEntityAt(position: arPosition, index: index, baseAnchor: baseAnchor)
      }
      statusMessage = "Loot placed successfully! (\(objectLocations.count) objects)"

    case .proximity:
      for (index, marker) in proximityMarkers.enumerated() {
        guard let angle = parseDirectionStringToRadians(dir: marker.dir) else { continue }
        let x = Float(marker.dist * sin(Double(angle)))
        let z = Float(-marker.dist * cos(Double(angle)))
        let position = SIMD3<Float>(x, 0.0, z)
        placeEntityAt(position: position, index: index, baseAnchor: baseAnchor)
      }
      statusMessage = "Loot placed successfully! (\(proximityMarkers.count) objects)"

    default:
      statusMessage = "No hunt data loaded."
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.statusMessage = ""
    }
  }

  private func placeEntityAt(position: SIMD3<Float>, index: Int, baseAnchor: AnchorEntity) {
    let pin = index < pinData.count ? pinData[index] : nil
    let lootType = pin?.objectType ?? objectType
    let pinId = pin?.id ?? "unknown"
    let markerNumber = (pin?.order ?? index) + 1

    guard let entity = createEntity(for: lootType) else { return }

    let objectAnchor = AnchorEntity()
    objectAnchor.position = position
    objectAnchor.addChild(entity)
    entity.position.y = baseHoverHeight

    entityToPinId[entity] = pinId
    baseOrientations[entity] = entity.transform.rotation
    coinEntities.append(entity)

    // Always show labels in simulator for debugging
    let numberLabel = createLabelEntity(text: "\(markerNumber)")
    numberLabel.position = SIMD3<Float>(0, baseHoverHeight + 0.25, 0)
    objectAnchor.addChild(numberLabel)

    let shortId = pinId.prefix(8)
    let idLabel = createLabelEntity(text: String(shortId))
    idLabel.position = SIMD3<Float>(0, baseHoverHeight + 0.1, 0)
    objectAnchor.addChild(idLabel)

    baseAnchor.addChild(objectAnchor)
    anchors.append(objectAnchor)
  }

  func clearAnchors() {
    for anchor in anchors {
      anchor.removeFromParent()
    }
    anchors.removeAll()
    coinEntities.removeAll()
    baseOrientations.removeAll()
    entityToPinId.removeAll()
    collectedEntities.removeAll()
  }

  // MARK: - Animation Loop

  @objc func updateFrame(displayLink: CADisplayLink) {
    frameCounter += 1

    // Handle summoning state changes
    if isSummoningActiveBinding != wasSummoningActive {
      if isSummoningActiveBinding {
        startObjectSummoning()
      } else {
        stopObjectSummoning()
      }
      wasSummoningActive = isSummoningActiveBinding
    }

    guard !coinEntities.isEmpty else { return }

    let focusInterval = usesLightweightSimulatorAssets ? 12 : 6
    let nearestInterval = usesLightweightSimulatorAssets ? 18 : 9
    let collectionInterval = usesLightweightSimulatorAssets ? 6 : 3

    // Focus detection
    if frameCounter % focusInterval == 0 {
      updateFocusDetection()
    }

    // Nearest loot tracking
    if frameCounter % nearestInterval == 0 {
      updateNearestLoot()
    }

    // Bobbing and spinning
    let bobHeight: Float = 0.3048
    let bobCycleDuration: Float = 2.0
    let deltaTime = Float(displayLink.duration)
    animationTime += deltaTime

    let bobPhase = animationTime / bobCycleDuration * 2.0 * .pi
    let bobOffset = sin(bobPhase) * bobHeight / 2.0
    let spinAngle = (animationTime / bobCycleDuration) * .pi

    for entity in coinEntities {
      guard !collectedEntities.contains(entity) else { continue }
      guard entity != summoningEntity else { continue }

      let spinRotation = simd_quatf(angle: spinAngle, axis: SIMD3<Float>(0, 1, 0))
      let baseRotation =
        baseOrientations[entity] ?? simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
      entity.transform.rotation = spinRotation * baseRotation
      entity.position.y = baseHoverHeight + bobOffset
    }

    // Summoning movement
    if isSummoningActiveBinding, let entity = summoningEntity {
      let cameraPosition = SIMD3<Float>(
        simulatedCameraTransform.columns.3.x,
        simulatedCameraTransform.columns.3.y,
        simulatedCameraTransform.columns.3.z)

      let entityPosition = entity.position(relativeTo: nil)
      let toCamera = cameraPosition - entityPosition
      let distance = simd_length(toCamera)

      let summonedCollectionDistance: Float = 0.8
      if distance < summonedCollectionDistance {
        autoCollectSummonedEntity(entity)
      } else {
        let direction = simd_normalize(toCamera)

        var easedSpeed = summonSpeed
        if let originalDistance = originalSummonDistance {
          let distanceRemaining = max(distance - summonedCollectionDistance, 0)
          let totalTravelDistance = max(originalDistance - summonedCollectionDistance, 0.1)
          let progress = 1.0 - (distanceRemaining / totalTravelDistance)
          let easedProgress = progress * progress * progress
          let minSpeed: Float = 0.3
          let maxSpeed: Float = 4.0
          easedSpeed = minSpeed + (maxSpeed - minSpeed) * easedProgress
        }

        let moveAmount = easedSpeed * deltaTime
        let newPosition = entityPosition + direction * moveAmount
        entity.setPosition(newPosition, relativeTo: nil)

        // Scale effect
        if let originalScale = originalEntityScale,
          let originalDistance = originalSummonDistance
        {
          let distanceRemaining = max(distance - summonedCollectionDistance, 0)
          let totalTravelDistance = max(originalDistance - summonedCollectionDistance, 0.1)
          let progress = 1.0 - (distanceRemaining / totalTravelDistance)
          let scaleFactor: Float = 1.0 + 2.0 * progress
          entity.scale = originalScale * scaleFactor
        }
      }
    }

    // Collection detection
    if frameCounter % collectionInterval == 0 {
      checkCollections()
    }
  }

  // MARK: - Collection Detection

  private func checkCollections() {
    let cameraPosition = SIMD3<Float>(
      simulatedCameraTransform.columns.3.x,
      simulatedCameraTransform.columns.3.y,
      simulatedCameraTransform.columns.3.z)

    for index in anchors.indices.reversed() {
      guard index < coinEntities.count else { continue }

      let anchor = anchors[index]
      let entity = coinEntities[index]
      let entityWorldPosition = entity.position(relativeTo: nil)
      let distance = simd_distance(cameraPosition, entityWorldPosition)

      let normalCollectionDistance: Float = 0.25
      let summonedCollectionDistance: Float = 0.8
      let isSummonedObject = (entity == summoningEntity)
      let collectionThreshold =
        isSummonedObject ? summonedCollectionDistance : normalCollectionDistance

      if isSummonedObject { continue }  // Handled by summoning movement

      if distance < collectionThreshold {
        collectedEntities.insert(entity)
        playCoinSound()

        let pinId = entityToPinId[entity] ?? "unknown"
        print("[SIM] Collected \(pinId.prefix(8)) at dist: \(String(format: "%.2f", distance))m")

        anchor.removeFromParent()
        anchors.remove(at: index)
        let removedEntity = coinEntities.remove(at: index)
        baseOrientations.removeValue(forKey: removedEntity)

        if currentHuntType == .geolocation && index < objectLocations.count {
          objectLocations.remove(at: index)
        }

        entityToPinId.removeValue(forKey: removedEntity)
        onCoinCollected?(pinId)
      }
    }
  }

  // MARK: - Focus Detection

  private func updateFocusDetection() {
    let cameraPosition = SIMD3<Float>(
      simulatedCameraTransform.columns.3.x,
      simulatedCameraTransform.columns.3.y,
      simulatedCameraTransform.columns.3.z)

    let forwardVector = normalize(
      SIMD3<Float>(
        -simulatedCameraTransform.columns.2.x,
        -simulatedCameraTransform.columns.2.y,
        -simulatedCameraTransform.columns.2.z
      ))

    let focusConeAngle: Float = 8.0 * (.pi / 180.0)

    var centerEntity: ModelEntity? = nil
    var closestDistance: Float = Float.infinity
    var smallestAngle: Float = Float.infinity

    for entity in coinEntities {
      guard !collectedEntities.contains(entity) else { continue }
      let entityWorldPosition = entity.position(relativeTo: nil)
      let toEntity = entityWorldPosition - cameraPosition
      let distance = simd_length(toEntity)

      guard distance <= focusRange else { continue }

      let direction = normalize(toEntity)
      let dotProduct = simd_dot(forwardVector, direction)
      let clampedDot = max(min(dotProduct, 1.0), -1.0)
      let angle = acos(clampedDot)

      guard angle <= focusConeAngle else { continue }

      if angle < smallestAngle
        || (abs(angle - smallestAngle) < 0.5 * (.pi / 180.0) && distance < closestDistance)
      {
        centerEntity = entity
        closestDistance = distance
        smallestAngle = angle
      }
    }

    focusedEntity = centerEntity

    if let entity = centerEntity, let pinId = entityToPinId[entity] {
      focusedLootIdBinding = pinId
      focusedLootDistanceBinding = closestDistance
    } else {
      focusedLootIdBinding = nil
      focusedLootDistanceBinding = nil
    }
  }

  // MARK: - Nearest Loot Tracking

  private func updateNearestLoot() {
    let cameraPosition = SIMD3<Float>(
      simulatedCameraTransform.columns.3.x,
      simulatedCameraTransform.columns.3.y,
      simulatedCameraTransform.columns.3.z)

    var nearestDistance: Float = .infinity

    for entity in coinEntities {
      guard !collectedEntities.contains(entity) else { continue }
      let entityPosition = entity.position(relativeTo: nil)
      let distance = simd_distance(cameraPosition, entityPosition)
      if distance < nearestDistance {
        nearestDistance = distance
      }
    }

    if nearestDistance < .infinity {
      nearestLootDistanceBinding = nearestDistance
    } else {
      nearestLootDistanceBinding = nil
      nearestLootDirectionBinding = 0
    }
  }

  // MARK: - Summoning

  func startObjectSummoning() {
    guard let targetEntity = focusedEntity else { return }
    guard summoningEntity != targetEntity else { return }

    let cameraPosition = SIMD3<Float>(
      simulatedCameraTransform.columns.3.x,
      simulatedCameraTransform.columns.3.y,
      simulatedCameraTransform.columns.3.z)
    let entityPosition = targetEntity.position(relativeTo: nil)
    let distance = simd_distance(entityPosition, cameraPosition)

    let summonedCollectionDistance: Float = 0.8
    if distance <= summonedCollectionDistance {
      autoCollectSummonedEntity(targetEntity)
      return
    }

    summoningEntity = targetEntity
    originalEntityPosition = entityPosition
    originalEntityScale = targetEntity.scale
    originalSummonDistance = distance
  }

  func stopObjectSummoning() {
    guard let entity = summoningEntity,
      let originalPosition = originalEntityPosition
    else {
      summoningEntity = nil
      originalEntityPosition = nil
      originalEntityScale = nil
      originalSummonDistance = nil
      return
    }

    entity.setPosition(originalPosition, relativeTo: nil)
    if let originalScale = originalEntityScale {
      entity.scale = originalScale
    }

    summoningEntity = nil
    originalEntityPosition = nil
    originalEntityScale = nil
    originalSummonDistance = nil
  }

  func autoCollectSummonedEntity(_ entity: ModelEntity) {
    guard let pinId = entityToPinId[entity], pinId != "unknown" else { return }

    guard let entityIndex = coinEntities.firstIndex(of: entity) else { return }
    let anchor = anchors[entityIndex]

    summoningEntity = nil
    originalEntityPosition = nil
    originalEntityScale = nil
    originalSummonDistance = nil

    collectedEntities.insert(entity)
    playCoinSound()

    print("[SIM] Auto-collected summoned entity: \(pinId.prefix(8))")

    anchor.removeFromParent()
    anchors.remove(at: entityIndex)
    coinEntities.remove(at: entityIndex)
    baseOrientations.removeValue(forKey: entity)

    if currentHuntType == .geolocation && entityIndex < objectLocations.count {
      objectLocations.remove(at: entityIndex)
    }

    entityToPinId.removeValue(forKey: entity)
    onCoinCollected?(pinId)
  }

  // MARK: - Utilities

  func convertToARWorldCoordinate(
    objectLocation: CLLocationCoordinate2D, referenceLocation: CLLocationCoordinate2D
  ) -> SIMD3<Float> {
    let lat1 = referenceLocation.latitude
    let lon1 = referenceLocation.longitude
    let lat2 = objectLocation.latitude
    let lon2 = objectLocation.longitude

    let latitudeRadians = lat1 * .pi / 180.0
    let metersPerDegreeLat =
      111132.92 - 559.82 * cos(2 * latitudeRadians) + 1.175 * cos(4 * latitudeRadians)
    let metersPerDegreeLon =
      111412.84 * cos(latitudeRadians) - 93.5 * cos(3 * latitudeRadians)

    let deltaNorth = (lat2 - lat1) * metersPerDegreeLat
    let deltaEast = (lon2 - lon1) * metersPerDegreeLon

    return SIMD3<Float>(Float(deltaEast), 0.0, Float(-deltaNorth))
  }

  func parseDirectionStringToRadians(dir: String) -> Float? {
    let pattern = #"^([NESW])(\d*)?([NESW])?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
      let match = regex.firstMatch(
        in: dir, options: [], range: NSRange(location: 0, length: dir.utf16.count))
    else { return nil }

    var baseAngle: Double = 0
    var deflectionAngle: Double = 0
    var deflectionDirection: Int = 1

    if match.numberOfRanges > 1, let range1 = Range(match.range(at: 1), in: dir) {
      switch String(dir[range1]) {
      case "N": baseAngle = 0
      case "E": baseAngle = 90
      case "S": baseAngle = 180
      case "W": baseAngle = 270
      default: return nil
      }
    } else {
      return nil
    }

    if match.numberOfRanges > 2, let range2 = Range(match.range(at: 2), in: dir), !range2.isEmpty {
      deflectionAngle = Double(dir[range2]) ?? 0
    }

    if match.numberOfRanges > 3, let range3 = Range(match.range(at: 3), in: dir) {
      let cardinal2 = String(dir[range3])
      switch (String(dir.prefix(1)), cardinal2) {
      case ("N", "E"), ("E", "S"), ("S", "W"), ("W", "N"):
        deflectionDirection = 1
      case ("N", "W"), ("E", "N"), ("S", "E"), ("W", "S"):
        deflectionDirection = -1
      default:
        if dir.count == 1 {
          deflectionAngle = 0
          deflectionDirection = 1
        } else {
          return nil
        }
      }
    } else {
      if dir.count > 1 { return nil }
    }

    var angleDegrees = baseAngle + (deflectionAngle * Double(deflectionDirection))
    angleDegrees = angleDegrees.truncatingRemainder(dividingBy: 360)
    if angleDegrees < 0 { angleDegrees += 360 }

    return Float(angleDegrees * .pi / 180.0)
  }

  func createLabelEntity(text: String) -> ModelEntity {
    let textMesh = MeshResource.generateText(
      text,
      extrusionDepth: 0.01,
      font: .systemFont(ofSize: 0.3),
      containerFrame: .zero,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let material = UnlitMaterial(color: UIColor.yellow)
    return ModelEntity(mesh: textMesh, materials: [material])
  }

  func playCoinSound() {
    guard let url = Bundle.main.url(forResource: "MagicCoin1", withExtension: "mp3") else { return }
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try audioSession.setActive(true)
      audioPlayer?.stop()
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.volume = 1.0
      audioPlayer?.prepareToPlay()
      audioPlayer?.play()
    } catch {
      print("[SIM] Audio error: \(error)")
    }
  }
}
