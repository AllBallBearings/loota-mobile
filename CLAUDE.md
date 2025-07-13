# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Loota Mobile is an iOS AR treasure hunting app built with Swift and SwiftUI. It allows users to discover and collect virtual markers placed in real-world locations using Augmented Reality. The app works with two hunt types: geolocation-based (GPS coordinates) and proximity-based (distance/direction from player).

## Development Commands

### Building and Running

- Open `loota/loota.xcodeproj` in Xcode
- Build and run with Xcode (⌘+R)
- Run tests with Xcode (⌘+U)

### Testing

- Unit tests: `lootaTests/lootaTests.swift`
- UI tests: `lootaUITests/lootaUITests.swift` and `lootaUITests/lootaUITestsLaunchTests.swift`

## Architecture

### Core Components

### Code Commits

- Don't co-author with Claude or Claude-Code

**ContentView.swift**: Main SwiftUI view that orchestrates the AR experience

- Manages hunt data loading and AR object placement
- Handles location updates and compass heading
- Switches between geolocation and proximity hunt modes

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

1. **North Alignment**: App waits for user to point device North before starting AR
2. **Coordinate Systems**:
   - Geolocation: GPS coordinates converted to AR world positions
   - Proximity: Distance/direction strings (e.g., "N32E") converted to AR positions
3. **Entity Management**: 3D objects are anchored to a base anchor aligned with North
4. **Collection Detection**: Proximity-based collection using camera position

### Hunt Types

**Geolocation Hunt**: Uses GPS coordinates to place AR objects at specific real-world locations
**Proximity Hunt**: Uses distance/direction data relative to player position

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

## Environment Configuration

The app uses `Environment.swift` to manage different API endpoints for development and production.

## Audio Assets

Coin collection sound effect: `Audio Resources/coin.mp3`

## 3D Assets

Dollar sign model: `3D Resources/DollarSign.usdz`
