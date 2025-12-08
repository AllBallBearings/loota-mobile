# Loota Mobile 🎮

An iOS augmented reality treasure hunting game where players discover and collect virtual markers placed in real-world locations.

[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![ARKit](https://img.shields.io/badge/ARKit-6.0-red.svg)](https://developer.apple.com/augmented-reality/)

## 🌟 Features

### Core Gameplay
- **AR Treasure Hunting**: Find and collect virtual objects using your device's camera in augmented reality
- **Dual Hunt Modes**:
  - **Geolocation Hunts**: Objects placed at specific GPS coordinates
  - **Proximity Hunts**: Objects positioned using distance/direction markers
- **Real-time Collection**: Collect items by walking close to them in the AR world

### Advanced Interactions
- **Gesture Summoning**: Use hand gestures to summon nearby objects to you
  - Detects hand poses using Vision framework
  - Magical floating animation brings objects closer
  - 10-second staged approach with enhanced collection radius
- **Visual Feedback**:
  - Animated coins with bobbing and spinning effects
  - Glowing halos on focused objects
  - Debug labels showing distances and marker numbers
  - Horizon line for spatial reference

### Hunt Management
- **Hunt Completion Detection**: Automatic polling to detect when hunts end
- **Winner Notifications**: Special screens for hunt winners with creator contact info
- **Prize System**: Winners can contact creators via phone, text, or email for prize transfer
- **Phone Number Collection**: Required for Apple Pay prize transfers

### Technical Features
- **Deep Linking**: Launch directly into specific hunts from web URLs
- **Automatic North Alignment**: Consistent AR world orientation using device compass
- **Persistent User State**: Device-based UUID with name management
- **Sound Effects**: Audio feedback for coin collection
- **Custom 3D Models**: Procedural coin generation with fallback support

## 🎯 Hunt Types

### Geolocation Hunt
Objects are placed at specific latitude/longitude coordinates. Players must physically travel to these locations to find and collect items.

### Proximity Hunt
Objects are positioned relative to the player using distance and direction strings (e.g., "N32E" for 32 feet North-East). Perfect for indoor or localized hunts.

## 📱 Requirements

- iOS 16.0 or later
- iPhone with ARKit support (iPhone 6s and later)
- Camera and location permissions
- Active internet connection for hunt data

## 🏗️ Architecture

### Core Components

**ContentView.swift**
- Main SwiftUI coordinator view
- Manages hunt data and AR session lifecycle
- Handles user registration and name prompts
- Coordinates app startup flow (splash → loading → AR)

**ARViewContainer.swift**
- UIViewRepresentable wrapper for RealityKit ARView
- Manages AR session with automatic North alignment
- Handles 3D entity placement and collection detection
- Implements hand gesture detection for summoning
- Manual billboard system for iOS 16+ compatibility

**DataModels.swift**
- Core data structures for hunts, pins, and AR objects
- API response models
- Type definitions for hunt modes

**APIService.swift**
- Network layer for backend communication
- Handles hunt data fetching, user registration, and pin collection
- Environment-based endpoint management (staging/production)

**HuntDataManager.swift**
- Observable state management for hunt data
- Coordinates user registration and hunt joining
- Publishes updates to SwiftUI views

**LocationManager.swift**
- Core Location wrapper with Combine publishers
- GPS coordinates and compass heading
- Location permission handling

**CoinEntity.swift**
- 3D coin model factory with multiple styles
- Custom cylinder mesh generator for iOS 16+ compatibility
- Procedural geometry fallback if models fail to load

### AR System

#### Coordinate Systems
- **World Alignment**: `.gravityAndHeading` for automatic North orientation
- **Base Anchor**: Created at world origin aligned with magnetic North
- **Geolocation**: GPS → local AR positions relative to user
- **Proximity**: Distance/direction strings → angles and positions

#### Entity Management
- Direct entity-to-pinID mapping using `entityToPinId` dictionary
- Database-driven pin ordering for consistent numbering
- Dual threshold collection system (0.25m normal, 0.8m summoned)

#### Hand Gesture System
- Vision framework `VNDetectHumanHandPoseRequest`
- Processes every 6th frame (~10 FPS) for performance
- Detects wrist landmarks with >60% confidence
- 10-foot (3.048m) proximity range for summoning

## 🎨 Visual Features

### Animations
- **Coin Bobbing**: Gentle vertical oscillation (5cm amplitude)
- **Coin Spinning**: Rotation around Z-axis in model space
- **Summoning Animation**: 8s slow approach + 2s fast collection
- **Billboard Labels**: Always face camera using manual rotation

### Materials & Effects
- Metallic materials for realistic coin appearance
- Unlit materials for glowing labels
- Layered glow effects (outer haze + inner ring)
- Semi-transparent horizon line (light blue, 50% opacity)

## 🔧 Configuration

### Environment Variables
Configure in `Environment.swift`:
- `apiBaseURL`: Backend API endpoint
- `apiKey`: Authentication key for API requests
- Debug vs. Release build configurations

### Launch Arguments
For testing deep links in Xcode scheme:
- `huntId`: Direct hunt ID to launch
- Configure in scheme editor → Arguments → Launch Arguments

## 📡 API Integration

### Key Endpoints
```
GET  /api/hunts/{huntId}                    - Fetch hunt data
GET  /api/hunts/{huntId}?userId={userId}    - Hunt with user context
POST /api/users/register                     - Register new user
POST /api/hunts/{huntId}/participants        - Join hunt
POST /api/hunts/{huntId}/pins/{pinId}/collect - Collect pin
GET  /api/users/{userId}                     - Get user info
PUT  /api/users/{userId}                     - Update user name
```

### Request Headers
```
Content-Type: application/json
x-api-key: {apiKey}
```

## 🎮 Gameplay Flow

1. **App Launch**: Splash screen → Location services initialization
2. **User Registration**: Name prompt if first-time user
3. **Hunt Selection**: Load hunt data from API
4. **Phone Collection**: Required for hunt participation
5. **AR Session**: Objects appear in AR based on hunt type
6. **Collection**: Walk close or summon objects to collect
7. **Completion**: Automatic detection when hunt ends
8. **Winner Flow**: Contact information for prize claim

## 🔐 Permissions

### Required
- **Camera**: "This app uses the camera for augmented reality treasure hunting experiences."
- **Location When In Use**: "This app uses location services to place virtual treasures at real-world locations."

Configure in `Info.plist`:
- `NSCameraUsageDescription`
- `NSLocationWhenInUseUsageDescription`

## 🏃‍♂️ Building & Running

### Xcode
1. Open `loota/loota.xcodeproj`
2. Select target device or simulator
3. Build and run (⌘+R)

### Command Line
```bash
cd loota
xcodebuild -project loota.xcodeproj -scheme loota -configuration Debug build
```

### Testing
```bash
# Unit tests
xcodebuild test -project loota.xcodeproj -scheme loota -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode
⌘+U
```

## 🐛 Debugging

### Debug Mode
Enable in app settings to show:
- Marker numbers on AR objects
- Pin ID prefixes for verification
- Distance and direction labels
- Collection radius visualization
- Horizon line reference

### Logging
The app uses emoji-prefixed logging for easy filtering:
- 🪙 Collection events
- 🎁 Loot type detection
- 🔍 Coordinate debugging
- 🎯 Summoning logic
- 🌅 Horizon line
- ✨ Glow effects
- 🔄 Frame timing

## 📊 Performance Considerations

### Optimizations
- **CADisplayLink**: Smooth 60 FPS entity rotation
- **SIMD Calculations**: Efficient proximity checking
- **Frame-Limited Hand Detection**: Every 6th frame
- **Weak References**: Prevent retain cycles in closures
- **Audio Reuse**: Single audio player instance
- **Manual Billboard**: Avoids iOS 18 API dependencies

### Memory Management
- Proper anchor cleanup on collection
- Entity removal from scene and arrays
- Audio player lifecycle management

## 🎨 Asset Management

### 3D Models
- `CoinPlain.usdz`: Primary coin model (from Blender)
- Fallback: Procedural cylinder generation
- Multiple coin styles: classic, thick rim, detailed, beveled

### Audio
- `coin.mp3`: Collection sound effect in `Audio Resources/`

### Images
- App icons in `Assets.xcassets`
- Splash screen graphics

## 🔄 State Management

### User State
- `@AppStorage` for persistent name
- Device UUID for identification
- Name sync with backend

### Hunt State
- `@Published` properties in `HuntDataManager`
- SwiftUI bindings for reactive updates
- Combine publishers from `LocationManager`

### AR State
- Coordinator pattern for AR session
- Entity tracking arrays
- Pin collection state

## 🚀 Future Enhancements

Potential improvements tracked in `TODO.md`:
- Enhanced hunt creation tools
- Multiplayer competition modes
- Leaderboards and achievements
- Social sharing features
- Advanced AR effects

## 🤝 Contributing

This is a private repository. For questions or issues, contact the development team.

## 📄 License

Proprietary - All rights reserved

## 🔗 Related Projects

- **Loota Web**: [loota.fun](https://www.loota.fun) - Web platform for hunt creation
- **Loota Backend**: Next.js API server

## 📞 Support

For technical support or prize claiming assistance, contact hunt creators through the in-app contact system.

---

**Built with ❤️ using Swift, SwiftUI, ARKit, and RealityKit**
