import ARKit
import Foundation
import QuartzCore

extension ARViewContainer.Coordinator {
  // New method to start the AR session for the first time and then place objects
  func startSessionAndPlaceObjects() {
    guard let arView = self.arView else {
      print("startSessionAndPlaceObjects: ARView is nil. Cannot proceed.")
      self.hasAlignedToNorth = false
      return
    }
    if didStartSession {
      print("startSessionAndPlaceObjects: Session already started - skipping reset.")
      return
    }
    didStartSession = true

    print(
      "startSessionAndPlaceObjects: Configuring and running AR Session with .gravityAndHeading.")
    let worldConfig = ARWorldTrackingConfiguration()
    worldConfig.worldAlignment = .gravityAndHeading
    worldConfig.planeDetection = [.horizontal, .vertical]
    worldConfig.environmentTexturing = .automatic

    arView.session.run(worldConfig, options: [.resetTracking, .removeExistingAnchors])
    print("startSessionAndPlaceObjects: AR Session run/reconfigured with .gravityAndHeading.")

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      print("startSessionAndPlaceObjects: Ensuring baseAnchor and attempting placement.")
      self.ensureBaseAnchorExists(in: arView)

      self.hasPlacedObjects = false

      self.statusMessage = "AR Session started. Placing objects..."
      self.attemptPlacementIfReady()
    }
  }

  // MARK: - ARSessionDelegate Methods
  public func session(_ session: ARSession, didFailWithError error: Error) {
    print("❌❌❌ AR SESSION FAILED ❌❌❌")
    print("❌ Error: \(error.localizedDescription)")
    print("❌ Full error: \(error)")

    let nsError = error as NSError
    print("❌ Error domain: \(nsError.domain)")
    print("❌ Error code: \(nsError.code)")
    print("❌ Error userInfo: \(nsError.userInfo)")

    DispatchQueue.main.async {
      self.statusMessage = "AR Failed: \(error.localizedDescription)"
    }
  }

  public func sessionWasInterrupted(_ session: ARSession) {
    print("⚠️ AR Session Interrupted")
    DispatchQueue.main.async {
      self.statusMessage = "AR Session Interrupted"
    }
  }

  public func sessionInterruptionEnded(_ session: ARSession) {
    print("✅ AR Session Interruption Ended - resuming")
    DispatchQueue.main.async {
      self.statusMessage = "AR Session Resumed"
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.statusMessage = ""
      }
    }

    if let arView = self.arView {
      let worldConfig = ARWorldTrackingConfiguration()
      worldConfig.worldAlignment = .gravityAndHeading
      worldConfig.environmentTexturing = .none
      worldConfig.planeDetection = []
      arView.session.run(worldConfig, options: [])
      print("✅ AR Session configuration reloaded after interruption")
    }
  }

  // PERFORMANCE FIX: Optimized session:didUpdate to minimize overhead
  public func session(_ session: ARSession, didUpdate frame: ARFrame) {
    // This delegate method is called frequently (60fps).
    // CRITICAL: Keep this method as lightweight as possible to avoid blocking camera feed.

    cameraFrameCount += 1
    let now = CACurrentMediaTime()
    let elapsed = now - lastCameraFrameTime
    if elapsed >= 1.0 {
      cameraFPS = Double(cameraFrameCount) / elapsed
      cameraFrameCount = 0
      lastCameraFrameTime = now

      if isDebugMode {
        print("📷 CAMERA_FPS: \(String(format: "%.1f", cameraFPS)) fps | Tracking: \(trackingStateDescription(frame.camera.trackingState))")
      }
    }

    let currentFrameCount = frameCounter
    if isDebugMode && currentFrameCount % 600 == 0 {
      print("🎯 FOCUS_DEBUG: Frame #\(currentFrameCount) (focusedId: \(focusedLootIdBinding ?? "none"), buttonActive: \(isSummoningActiveBinding))")
      let state = trackingStateDescription(frame.camera.trackingState)
      print("🎥 FRAME_UPDATE: tracking=\(state)")
    }

    // Hand pose processing removed - using button-based summoning instead
  }

  public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    guard isDebugMode else { return }
    let stateDescription = trackingStateDescription(camera.trackingState)
    print("🎥 TRACKING_STATE: \(stateDescription)")
  }
}
