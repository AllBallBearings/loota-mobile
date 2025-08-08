# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Loota Mobile is an iOS AR treasure hunting app built with Swift and SwiftUI. It allows users to discover and collect virtual markers placed in real-world locations using Augmented Reality. The app works with two hunt types: geolocation-based (GPS coordinates) and proximity-based (distance/direction from player).

## Development Commands

### Building and Running

- Open `loota/loota.xcodeproj` in Xcode
- Build and run with Xcode (⌘+R)
- Command line build: `cd loota && xcodebuild -project loota.xcodeproj -scheme loota -configuration Debug build`
- Run tests with Xcode (⌘+U)
- Command line test: `cd loota && xcodebuild test -project loota.xcodeproj -scheme loota -destination 'platform=iOS Simulator,name=iPhone 15'`

### Testing

- Unit tests: `lootaTests/lootaTests.swift`
- UI tests: `lootaUITests/lootaUITests.swift` and `lootaUITests/lootaUITestsLaunchTests.swift`
- **Write tests for all new features** unless explicitly told not to
- **Run tests before committing** to ensure code quality and functionality

## Architecture

### Core Components

**ContentView.swift**: Main SwiftUI view that orchestrates the AR experience

- Manages hunt data loading and AR object placement
- Handles location updates and compass heading
- Switches between geolocation and proximity hunt modes
- Implements app startup flow: splash screen → loading indicator → main content
- Contains user name prompt and initialization state management

**ARViewContainer.swift**: UIViewRepresentable wrapper for RealityKit ARView

- Contains Coordinator class that manages AR session and object placement
- Handles North alignment for consistent AR world orientation
- Manages 3D entity creation and coin collection detection

**DataModels.swift**: Core data structures

- `HuntData`: Hunt information with type and pin data
- `PinData`: Individual treasure location/marker data
- `ARObjectType`: Enum for 3D object types (coin, dollar sign)
- `ProximityMarkerData`: Distance/direction marker data

**APIService.swift**: Network layer for backend communication

- Fetches hunt data from Next.js backend
- Handles user registration and hunt participation
- Manages pin collection API calls

**HuntDataManager.swift**: Observable object managing hunt state

- Coordinates user registration and hunt joining
- Publishes hunt data changes to SwiftUI views
- Handles error states and user persistence

**LocationManager.swift**: Core Location wrapper

- Provides GPS coordinates and compass heading
- Handles location permission requests
- Publishes location updates to SwiftUI

### AR System Architecture

1. **Automatic North Alignment**: App uses `.gravityAndHeading` world alignment for automatic North orientation without user intervention
2. **Base Anchor System**: Creates base anchor at world origin aligned with magnetic North for consistent object placement
3. **Coordinate Systems**:
   - Geolocation: GPS coordinates converted to AR world positions relative to user location
   - Proximity: Distance/direction strings (e.g., "N32E") parsed into angles and positioned relative to base anchor
4. **Entity Management**: 3D objects anchored to base anchor with entity-to-pinId mapping for accurate collection
5. **Collection Detection**: Dual threshold system (0.25m normal, 0.8m summoned objects) using camera position

### Hunt Types

**Geolocation Hunt**: Uses GPS coordinates to place AR objects at specific real-world locations
**Proximity Hunt**: Uses distance/direction data relative to player position

### Hand Gesture Detection & Object Summoning

The app integrates Vision framework for hand pose detection to enable "spell casting" object summoning:

1. **Detection**: Uses `VNDetectHumanHandPoseRequest` to detect wrist landmarks with >60% confidence
2. **Performance**: Processes every 6th frame (~10 FPS) to maintain AR performance
3. **Proximity**: Objects within 10 feet (3.048m) are eligible for summoning
4. **Animation**: 10-second staged animation (8s slow approach + 2s fast collection) with magical floating effects
5. **Collection**: Enhanced collection system with larger threshold (0.8m) for summoned objects

### Pin Ordering & Collection System

**Critical Architecture**: The app uses database-driven pin ordering and ID-based collection:

- **Pin Sorting**: Pins sorted by `order` field from database for consistent numbering across platforms
- **Entity Mapping**: Direct `entityToPinId: [ModelEntity: String]` mapping ensures accurate collection
- **Visual Debug**: AR labels show marker numbers and pin ID prefixes for debugging
- **Collection Logic**: Uses specific pin IDs instead of coordinate matching to avoid floating-point precision issues

### User Management Flow

**Registration & State**: Uses device UUID for identification with sophisticated name management:

- **Detection**: `shouldPromptForName` determines when to show name prompt vs. rejoin existing user
- **Sync**: Compares local `@AppStorage` names with database for consistency
- **Name Prompt**: Alert dialog with OK/Cancel options, defaults to "Anonymous" for empty/cancelled input
- **Backend**: POST `/api/users/register` and PUT `/api/users/{userId}` (pending implementation)

### App Startup Flow

**Multi-stage Initialization**: Polished startup experience with visual feedback:

1. **Splash Screen**: 2-second animated "Loota" branding with purple gradient and glow effects
2. **Loading Overlay**: Progress indicator during location services and hunt data initialization
3. **Name Prompt**: User registration dialog if needed (can be dismissed with Cancel)
4. **Main Content**: Transitions to AR experience when ready

### Hunt Completion & Winner Contact System

**Hunt Completion Detection**: Automatic polling system that detects when hunts are completed

- **Polling Logic**: Every 10 seconds after joining, checks hunt completion status
- **Completion Trigger**: When `isCompleted` changes from false to true
- **Winner Detection**: Compares `winnerId` with current user ID
- **Contact Information**: Shows creator contact details for winners

**Phone Number Requirement**: All participants must provide phone number for prize transfers

- **Collection Point**: Required during hunt joining process
- **Validation**: Client-side phone number format validation
- **Purpose**: Apple Pay prize transfers and winner contact
- **User Flow**: Name prompt → Phone prompt → Hunt participation

**"Totally Looted!" Completion Screen**: Celebration screen with contact actions

- **Winner View**: Shows creator contact information with call/text/email buttons
- **Non-Winner View**: Shows completion message and winner information
- **Contact Actions**: Direct integration with iOS dialer, messages, and mail apps
- **Dismissal**: Returns to hunt list or main app flow

### Deep Linking

The app handles deep links from the web platform to launch directly into specific hunts. Launch arguments are configured in the Xcode scheme for testing.

## Key Files

- `ContentView.swift`: Main UI and hunt coordination
- `ARViewContainer.swift`: AR rendering and interaction
- `DataModels.swift`: Data structures and API models
- `APIService.swift`: Network communication
- `HuntDataManager.swift`: Hunt state management
- `LocationManager.swift`: GPS and compass functionality
- `CoinEntity.swift`: 3D coin model factory
- `AppDelegate.swift`: App lifecycle and deep link handling
- `SplashScreen.swift`: Animated startup screen with Loota branding
- `LoadingIndicator.swift`: Progress overlay for hunt initialization
- `HuntCompletionView.swift`: Hunt completion and winner contact screens

## Network Architecture

**Environment Management**: `Environment.swift` manages API endpoints and API key:

- Production: `https://www.loota.fun`
- Staging: `https://staging.loota.fun` (used in DEBUG builds)
- API key is currently hardcoded but should be moved to secure storage

**Key API Endpoints**:

- `GET /api/hunts/{huntId}` - Fetch hunt data
- `GET /api/hunts/{huntId}?userId={userId}` - Fetch hunt with user context (completion status, contact info)
- `POST /api/users/register` - User registration with device UUID
- `POST /api/hunts/{huntId}/participants` - Join hunt (requires phone number)
- `POST /api/hunts/{huntId}/pins/{pinId}/collect` - Collect specific pin
- `GET /api/users/{userId}` - Get user info
- `PUT /api/users/{userId}` - Update user name (backend pending implementation)

**State Management**: Uses `HuntDataManager` singleton with `@Published` properties for reactive UI updates.

## Audio Assets

Coin collection sound effect: `Audio Resources/coin.mp3`

## 3D Assets

Dollar sign model: `3D Resources/DollarSign.usdz`

## Key Architectural Patterns

**Coordinator Pattern**: ARViewContainer.Coordinator manages AR session lifecycle and separates UI logic from 3D object management

**Reactive State Management**: Extensive use of `@Published` properties with Combine and SwiftUI bindings for real-time updates

**Entity-Component System**: RealityKit entities with components for rotation, collection detection, and visual labels

**Factory Pattern**: `CoinEntityFactory` abstracts 3D object creation from placement logic

## Performance Considerations

**AR Optimizations**:

- CADisplayLink for smooth entity rotation animations
- SIMD distance calculations for efficient proximity checking
- Frame-rate limited hand detection (every 6th frame)

**Memory Management**:

- Weak references in AR delegate closures
- Proper anchor cleanup when objects collected
- Audio player reuse for coin collection sounds

## Permissions & Privacy

The app requires these iOS permissions (defined in Info.plist):

- **Camera**: "This app uses the camera for augmented reality treasure hunting experiences."
- **Location When In Use**: "This app uses location services to place virtual treasures at real-world locations."

## Current Status

**Stability**: Main branch stable and ready for new development. All major features implemented including hand gesture summoning, pin ordering system, and user management flow.

**Pending Dependencies**: Backend PUT endpoint for user name updates.

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
