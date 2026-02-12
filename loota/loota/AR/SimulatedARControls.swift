// SimulatedARControls.swift
// On-screen controls for the AR simulator: virtual joysticks for camera movement
// and look direction, plus height/speed controls.

import SwiftUI

// MARK: - Virtual Joystick

struct VirtualJoystick: View {
  let label: String
  let color: Color
  @Binding var xValue: Float
  @Binding var yValue: Float

  @State private var dragOffset: CGSize = .zero
  @State private var isDragging: Bool = false

  private let joystickRadius: CGFloat = 50
  private let knobRadius: CGFloat = 20
  private let sensitivity: Float = 1.0

  var body: some View {
    VStack(spacing: 4) {
      Text(label)
        .font(.caption2)
        .foregroundColor(.white.opacity(0.7))

      ZStack {
        // Background circle
        Circle()
          .fill(Color.white.opacity(0.1))
          .frame(width: joystickRadius * 2, height: joystickRadius * 2)
          .overlay(
            Circle()
              .stroke(color.opacity(0.4), lineWidth: 1)
          )

        // Crosshair
        Path { path in
          path.move(to: CGPoint(x: joystickRadius, y: 0))
          path.addLine(to: CGPoint(x: joystickRadius, y: joystickRadius * 2))
          path.move(to: CGPoint(x: 0, y: joystickRadius))
          path.addLine(to: CGPoint(x: joystickRadius * 2, y: joystickRadius))
        }
        .stroke(color.opacity(0.15), lineWidth: 0.5)

        // Knob
        Circle()
          .fill(color.opacity(isDragging ? 0.8 : 0.5))
          .frame(width: knobRadius * 2, height: knobRadius * 2)
          .shadow(color: color.opacity(0.3), radius: 4)
          .offset(dragOffset)
      }
      .frame(width: joystickRadius * 2, height: joystickRadius * 2)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            isDragging = true
            let maxOffset = joystickRadius - knobRadius
            let clampedX = min(max(gesture.translation.width, -maxOffset), maxOffset)
            let clampedY = min(max(gesture.translation.height, -maxOffset), maxOffset)
            dragOffset = CGSize(width: clampedX, height: clampedY)

            xValue = Float(clampedX / maxOffset) * sensitivity
            yValue = Float(-clampedY / maxOffset) * sensitivity // Invert Y
          }
          .onEnded { _ in
            isDragging = false
            withAnimation(.easeOut(duration: 0.2)) {
              dragOffset = .zero
            }
            xValue = 0
            yValue = 0
          }
      )
    }
  }
}

// MARK: - Simulator Control Panel

struct SimulatedARControlPanel: View {
  // Movement joystick outputs (continuous while dragging)
  @Binding var moveX: Float // Strafe left/right
  @Binding var moveZ: Float // Forward/backward

  // Look joystick outputs (continuous while dragging)
  @Binding var lookX: Float // Yaw
  @Binding var lookY: Float // Pitch

  // Height control
  @Binding var cameraHeight: Float

  // Summoning
  @Binding var isSummoningActive: Bool

  // Camera info
  var cameraYaw: Float
  var cameraPitch: Float
  var cameraX: Float
  var cameraZ: Float
  var focusedLootId: String?
  var focusedLootDistance: Float?

  // Speed multiplier
  @State private var speedMultiplier: Float = 1.0

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // Top info bar
      HStack {
        // Camera position info
        VStack(alignment: .leading, spacing: 2) {
          Text("Pos: (\(String(format: "%.1f", cameraX)), \(String(format: "%.1f", cameraHeight)), \(String(format: "%.1f", cameraZ)))")
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
          Text("Yaw: \(String(format: "%.0f", cameraYaw * 180 / .pi))  Pitch: \(String(format: "%.0f", cameraPitch * 180 / .pi))")
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
        }

        Spacer()

        // Focus info
        if let lootId = focusedLootId {
          VStack(alignment: .trailing, spacing: 2) {
            Text("Focused: \(lootId.prefix(8))")
              .font(.system(size: 10, design: .monospaced))
              .foregroundColor(.green)
            if let dist = focusedLootDistance {
              Text("Dist: \(String(format: "%.2f", dist))m")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green)
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 6)
      .background(Color.black.opacity(0.5))

      // Control area
      HStack(alignment: .bottom, spacing: 0) {
        // Left: Movement joystick
        VStack(spacing: 8) {
          VirtualJoystick(
            label: "MOVE",
            color: .blue,
            xValue: $moveX,
            yValue: $moveZ
          )

          // Height controls
          HStack(spacing: 12) {
            Button(action: { cameraHeight = max(cameraHeight - 0.5, 0.0) }) {
              Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }

            Text("\(String(format: "%.1f", cameraHeight))m")
              .font(.system(size: 10, design: .monospaced))
              .foregroundColor(.white.opacity(0.6))

            Button(action: { cameraHeight += 0.5 }) {
              Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
          }
        }
        .padding(.leading, 16)

        Spacer()

        // Center: Summon button and speed
        VStack(spacing: 8) {
          // Summon button
          Button(action: {}) {
            Text("SUMMON")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(focusedLootId != nil ? .white : .gray)
              .frame(width: 80, height: 44)
              .background(
                focusedLootId != nil
                  ? (isSummoningActive ? Color.orange : Color.purple.opacity(0.7))
                  : Color.gray.opacity(0.3)
              )
              .cornerRadius(12)
          }
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { _ in
                if focusedLootId != nil {
                  isSummoningActive = true
                }
              }
              .onEnded { _ in
                isSummoningActive = false
              }
          )

          // Speed control
          HStack(spacing: 4) {
            Text("Speed:")
              .font(.system(size: 9))
              .foregroundColor(.white.opacity(0.5))
            ForEach([0.5, 1.0, 2.0, 5.0], id: \.self) { speed in
              Button(action: { speedMultiplier = Float(speed) }) {
                Text("\(speed, specifier: "%.0f")x")
                  .font(.system(size: 9, weight: speedMultiplier == Float(speed) ? .bold : .regular))
                  .foregroundColor(speedMultiplier == Float(speed) ? .white : .white.opacity(0.4))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 3)
                  .background(speedMultiplier == Float(speed) ? Color.blue.opacity(0.5) : Color.clear)
                  .cornerRadius(4)
              }
            }
          }
        }

        Spacer()

        // Right: Look joystick
        VStack(spacing: 8) {
          VirtualJoystick(
            label: "LOOK",
            color: .orange,
            xValue: $lookX,
            yValue: $lookY
          )

          // Reset button
          Button(action: {}) {
            Text("RESET")
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.white.opacity(0.7))
              .frame(width: 60, height: 28)
              .background(Color.white.opacity(0.1))
              .cornerRadius(6)
          }
        }
        .padding(.trailing, 16)
      }
      .padding(.vertical, 12)
      .background(
        LinearGradient(
          colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
    .environment(\.colorScheme, .dark)
  }

  var effectiveSpeedMultiplier: Float {
    speedMultiplier
  }
}

// MARK: - Camera Controller

/// Manages continuous camera movement based on joystick inputs.
/// Call `update(deltaTime:)` each frame from a display link or timer.
class SimulatedCameraController: ObservableObject {
  @Published var yaw: Float = 0
  @Published var pitch: Float = 0
  @Published var positionX: Float = 0
  @Published var positionY: Float = 1.5 // Default eye height
  @Published var positionZ: Float = 2.0 // Start slightly back from origin

  var moveInputX: Float = 0
  var moveInputZ: Float = 0
  var lookInputX: Float = 0
  var lookInputY: Float = 0

  var moveSpeed: Float = 2.0   // meters per second
  var lookSpeed: Float = 1.5   // radians per second
  var speedMultiplier: Float = 1.0

  func update(deltaTime: Float) {
    // Update look direction
    yaw += lookInputX * lookSpeed * deltaTime * speedMultiplier
    pitch += lookInputY * lookSpeed * deltaTime * speedMultiplier
    pitch = max(min(pitch, .pi / 2.5), -.pi / 2.5) // Clamp pitch

    // Calculate forward/right vectors from yaw (ignoring pitch for movement)
    let forwardX = -sin(yaw)
    let forwardZ = -cos(yaw)
    let rightX = cos(yaw)
    let rightZ = -sin(yaw)

    // Apply movement relative to camera facing direction
    let effectiveSpeed = moveSpeed * speedMultiplier * deltaTime
    positionX += (forwardX * moveInputZ + rightX * moveInputX) * effectiveSpeed
    positionZ += (forwardZ * moveInputZ + rightZ * moveInputX) * effectiveSpeed
  }

  func reset() {
    yaw = 0
    pitch = 0
    positionX = 0
    positionY = 1.5
    positionZ = 2.0
  }
}
