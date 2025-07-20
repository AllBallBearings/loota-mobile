import SwiftUI
import SceneKit
import CoreLocation

struct PathVisualizationView: View {
    let surveyData: [SurveyDataPoint]
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // 3D Scene View
                SceneKitView(surveyData: surveyData)
                    .edgesIgnoringSafeArea(.all)
                
                // Control overlay
                VStack {
                    HStack {
                        Spacer()
                        
                        // Close button
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Info panel
                    VStack(spacing: 8) {
                        Text("3D Quest Path")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Pinch to zoom • Drag to rotate • Two-finger pan to move")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text("Points: \(surveyData.count)")
                            Spacer()
                            if let totalDistance = surveyData.last?.distanceFromStart {
                                Text("Distance: \(String(format: "%.1f ft", totalDistance * 3.28084))")
                            }
                            Spacer()
                            if let elevationChange = calculateTotalElevationChange() {
                                Text("Elevation Δ: \(String(format: "%.1f ft", elevationChange * 3.28084))")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func calculateTotalElevationChange() -> Double? {
        guard surveyData.count >= 2 else { return nil }
        
        let firstElevation = surveyData.first?.barometricElevation ?? surveyData.first?.elevation ?? 0.0
        let lastElevation = surveyData.last?.barometricElevation ?? surveyData.last?.elevation ?? 0.0
        
        return lastElevation - firstElevation
    }
}

struct SceneKitView: UIViewRepresentable {
    let surveyData: [SurveyDataPoint]
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = createScene()
        sceneView.backgroundColor = UIColor.black
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = false
        sceneView.autoenablesDefaultLighting = true
        
        // Set up camera
        setupCamera(in: sceneView)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if needed
    }
    
    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        // Convert survey data to 3D coordinates
        let pathPoints = convertSurveyDataTo3D()
        
        if pathPoints.count >= 2 {
            // Create the ribbon path
            createRibbonPath(points: pathPoints, in: scene)
            
            // Add data point markers
            addDataPointMarkers(points: pathPoints, in: scene)
            
            // Add start/end markers
            addStartEndMarkers(points: pathPoints, in: scene)
        }
        
        // Add lighting
        addLighting(to: scene)
        
        return scene
    }
    
    private func convertSurveyDataTo3D() -> [SCNVector3] {
        guard !surveyData.isEmpty else { return [] }
        
        // Use the first point as origin
        let originLat = surveyData[0].latitude
        let originLng = surveyData[0].longitude
        let originElevation = surveyData[0].barometricElevation ?? surveyData[0].elevation
        
        return surveyData.map { point in
            // Convert lat/lng to local coordinates (meters from origin)
            let deltaLat = point.latitude - originLat
            let deltaLng = point.longitude - originLng
            
            // Convert to meters (approximate)
            let x = deltaLng * 111320.0 * cos(originLat * .pi / 180.0) // meters east
            let z = -deltaLat * 111320.0 // meters north (negative Z in SceneKit)
            
            // Use barometric elevation if available, otherwise GPS
            let elevation = point.barometricElevation ?? point.elevation
            let y = elevation - originElevation // relative elevation
            
            return SCNVector3(Float(x), Float(y), Float(z))
        }
    }
    
    private func createRibbonPath(points: [SCNVector3], in scene: SCNScene) {
        let ribbonWidth: Float = 0.5 // 0.5 meters wide
        
        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            
            // Calculate segment properties
            let direction = SCNVector3(
                end.x - start.x,
                end.y - start.y,
                end.z - start.z
            )
            let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
            
            // Create ribbon segment
            let ribbonGeometry = SCNBox(width: CGFloat(ribbonWidth), height: 0.05, length: CGFloat(length), chamferRadius: 0.02)
            
            // Create material with gradient from start to end
            let material = SCNMaterial()
            let progress = Float(i) / Float(points.count - 1)
            material.diffuse.contents = UIColor(
                red: CGFloat(0.2 + progress * 0.6), // Red component increases along path
                green: CGFloat(0.6 - progress * 0.4), // Green component decreases
                blue: CGFloat(0.8),
                alpha: 0.9
            )
            material.specular.contents = UIColor.white
            material.shininess = 0.5
            ribbonGeometry.materials = [material]
            
            let ribbonNode = SCNNode(geometry: ribbonGeometry)
            
            // Position at midpoint between start and end
            ribbonNode.position = SCNVector3(
                (start.x + end.x) / 2,
                (start.y + end.y) / 2,
                (start.z + end.z) / 2
            )
            
            // Orient the ribbon along the path direction
            let normalizedDirection = SCNVector3(
                direction.x / length,
                direction.y / length,
                direction.z / length
            )
            
            // Calculate rotation to align with direction
            let up = SCNVector3(0, 1, 0)
            let forward = SCNVector3(0, 0, -1) // Default forward in SceneKit
            
            if length > 0.001 { // Avoid division by zero
                // Calculate angle between forward and direction
                let dot = forward.x * normalizedDirection.x + forward.y * normalizedDirection.y + forward.z * normalizedDirection.z
                let angle = acos(max(-1, min(1, dot)))
                
                // Calculate rotation axis (cross product)
                let axis = SCNVector3(
                    forward.y * normalizedDirection.z - forward.z * normalizedDirection.y,
                    forward.z * normalizedDirection.x - forward.x * normalizedDirection.z,
                    forward.x * normalizedDirection.y - forward.y * normalizedDirection.x
                )
                
                let axisLength = sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z)
                if axisLength > 0.001 {
                    ribbonNode.rotation = SCNVector4(
                        axis.x / axisLength,
                        axis.y / axisLength,
                        axis.z / axisLength,
                        angle
                    )
                }
            }
            
            scene.rootNode.addChildNode(ribbonNode)
        }
    }
    
    private func addDataPointMarkers(points: [SCNVector3], in scene: SCNScene) {
        for (index, point) in points.enumerated() {
            // Create small sphere for each data point
            let markerGeometry = SCNSphere(radius: 0.05)
            let material = SCNMaterial()
            
            // Color code by position along path
            let progress = Float(index) / Float(max(1, points.count - 1))
            material.diffuse.contents = UIColor(
                red: CGFloat(1.0 - progress),
                green: CGFloat(progress),
                blue: 0.5,
                alpha: 0.8
            )
            
            markerGeometry.materials = [material]
            
            let markerNode = SCNNode(geometry: markerGeometry)
            markerNode.position = SCNVector3(point.x, point.y + 0.1, point.z) // Slightly above the ribbon
            
            scene.rootNode.addChildNode(markerNode)
        }
    }
    
    private func addStartEndMarkers(points: [SCNVector3], in scene: SCNScene) {
        guard !points.isEmpty else { return }
        
        // Start marker (green)
        let startGeometry = SCNSphere(radius: 0.15)
        let startMaterial = SCNMaterial()
        startMaterial.diffuse.contents = UIColor.green
        startMaterial.emission.contents = UIColor.green.withAlphaComponent(0.3)
        startGeometry.materials = [startMaterial]
        
        let startNode = SCNNode(geometry: startGeometry)
        startNode.position = SCNVector3(points[0].x, points[0].y + 0.2, points[0].z)
        scene.rootNode.addChildNode(startNode)
        
        // End marker (red)
        if points.count > 1 {
            let endGeometry = SCNSphere(radius: 0.15)
            let endMaterial = SCNMaterial()
            endMaterial.diffuse.contents = UIColor.red
            endMaterial.emission.contents = UIColor.red.withAlphaComponent(0.3)
            endGeometry.materials = [endMaterial]
            
            let endNode = SCNNode(geometry: endGeometry)
            let lastPoint = points[points.count - 1]
            endNode.position = SCNVector3(lastPoint.x, lastPoint.y + 0.2, lastPoint.z)
            scene.rootNode.addChildNode(endNode)
        }
    }
    
    private func addLighting(to scene: SCNScene) {
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.4, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Directional light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor(white: 0.8, alpha: 1.0)
        directionalLight.castsShadow = true
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(directionalNode)
    }
    
    private func setupCamera(in sceneView: SCNView) {
        guard let scene = sceneView.scene else { return }
        
        // Calculate bounding box of all points
        let pathPoints = convertSurveyDataTo3D()
        guard !pathPoints.isEmpty else { return }
        
        var minX = pathPoints[0].x, maxX = pathPoints[0].x
        var minY = pathPoints[0].y, maxY = pathPoints[0].y
        var minZ = pathPoints[0].z, maxZ = pathPoints[0].z
        
        for point in pathPoints {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        
        // Calculate center and size
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let centerZ = (minZ + maxZ) / 2
        
        let sizeX = maxX - minX
        let sizeY = maxY - minY
        let sizeZ = maxZ - minZ
        let maxSize = max(sizeX, max(sizeY, sizeZ))
        
        // Position camera to show entire path
        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // Position camera at an angle above and behind the path
        let cameraDistance = max(10.0, maxSize * 2.0)
        cameraNode.position = SCNVector3(
            centerX - Float(cameraDistance * 0.7),
            centerY + Float(cameraDistance * 0.5),
            centerZ + Float(cameraDistance * 0.7)
        )
        
        // Look at the center of the path
        cameraNode.look(at: SCNVector3(centerX, centerY, centerZ))
        
        scene.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
    }
}

#Preview {
    // Sample data for preview
    let sampleData = [
        SurveyDataPoint(latitude: 40.7128, longitude: -74.0060, elevation: 0.0, barometricElevation: 0.0, timestamp: Date(), distanceFromStart: 0.0, distanceFromOrigin: 0.0, segmentDistance: 0.0),
        SurveyDataPoint(latitude: 40.7129, longitude: -74.0059, elevation: 1.0, barometricElevation: 1.0, timestamp: Date(), distanceFromStart: 10.0, distanceFromOrigin: 10.0, segmentDistance: 10.0),
        SurveyDataPoint(latitude: 40.7130, longitude: -74.0058, elevation: 2.0, barometricElevation: 2.0, timestamp: Date(), distanceFromStart: 20.0, distanceFromOrigin: 15.0, segmentDistance: 10.0)
    ]
    
    PathVisualizationView(surveyData: sampleData)
}