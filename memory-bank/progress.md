# Progress

_This document describes what works, what's left to build, the current status, known issues, and the evolution of project decisions._

## What Works

**Core AR Treasure Hunt Experience:**
- AR object placement for geolocation and proximity hunts
- User registration and hunt joining flow  
- Object collection with haptic/audio feedback
- Deep linking from web platform to specific hunts
- Hunt data fetching and processing from Next.js backend
- Location services and compass heading integration

**Pin Order & Collection System:**
- Consistent pin numbering between web interface and mobile app
- Pin sorting by database `order` field 
- Pin-specific collection using entity-to-pinId mapping
- AR object labels showing marker numbers and pin IDs
- Debug logging for object creation and collection

**Hand Gesture Recognition & Object Summoning:**
- Palm detection using Vision framework for hand pose recognition
- Object summoning within 10-foot proximity radius
- Floating animation system for summoned objects
- Enhanced collection system supporting both proximity and gesture-based collection
- Integrated hand pose detection with AR camera frames

**User Management:**
- Name prompt system for blank/anonymous users
- User registration with device ID
- Name sync detection between local and database
- Hunt participation tracking and rejoining

## What's Left to Build

**Backend Dependencies:**
- PUT /api/users/{userId} endpoint for updating user names
- Any additional hunt types or features from web platform

**Potential Enhancements:**
- More AR object types beyond coins and dollar signs
- Enhanced AR effects and animations
- Leaderboard or scoring system integration

## Current Status

✅ **Stable and ready for new development**
- Main branch clean with all completed features
- Build successful with comprehensive test coverage
- Pin collection system working accurately
- No blocking issues

## Known Issues

**Backend Limitation:**
- User name updates return 405 Method Not Allowed (backend needs implementation)
- Names sync detection works, but actual updates require backend support

**Minor:**
- Some debug logs could be cleaned up for production
- Xcode workspace state files in git (cosmetic)

## Evolution of Project Decisions

**Major Architectural Changes:**

1. **Collection System Redesign:** Moved from coordinate-based to ID-based collection for accuracy
2. **Pin Ordering:** Added database `order` field to ensure consistent numbering across platforms  
3. **User Registration Flow:** Separated name prompting from automatic registration to improve UX
4. **Entity Mapping:** Implemented direct AR entity-to-data mapping for reliable object association

**Key Turning Points:**
- Discovery that coordinate matching was causing wrong pin collection
- Realization that array indices don't guarantee database order consistency  
- Decision to add visual pin ID labels for debugging and verification
