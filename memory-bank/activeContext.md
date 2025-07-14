# Active Context

_This document describes the current work focus, recent changes, next steps, active decisions and considerations, important patterns and preferences, and learnings and project insights._

## Current Work Focus

**COMPLETED MAJOR FEATURES:** Pin ordering, collection system, and hand gesture summoning
**STATUS:** Ready for new tasks - main branch clean and stable with new gesture feature

## Recent Changes

**Pin Order & Collection System (Completed):**
- Added `order` field to PinData model for consistent numbering between web/mobile
- Implemented pin sorting by order field in hunt data processing  
- Created pin-specific collection system using entity-to-pinId mapping
- Added AR object labels showing marker number and first 8 chars of pin ID
- Fixed collection to use specific pin IDs instead of coordinate matching
- Comprehensive debug logging throughout user registration and name sync flow

**Hand Gesture Recognition & Object Summoning (Completed):**
- Integrated Vision framework for hand pose detection in ARViewContainer
- Implemented palm detection using wrist and thumb landmarks
- Created object summoning system for objects within 10-foot radius
- Added floating animation for summoned objects moving toward user
- Enhanced collection system with dual thresholds for normal vs summoned objects
- Frame-rate optimized hand detection (every 6th frame for performance)

**User Name Management (Completed):**
- Added getUser() and updateUserName() API endpoints
- Implemented name sync detection between local storage and database
- Fixed UserResponse model to map API's "id" field to "userId" 
- Updated ContentView to use shouldPromptForName for better detection

## Next Steps

Ready for new development tasks on clean main branch.

## Active Decisions and Considerations

- Backend PUT /api/users/{userId} endpoint needs implementation for name updates
- Pin ordering now relies on database `order` field - no longer uses array indices
- Collection system guarantees pin ID accuracy regardless of collection order

## Important Patterns and Preferences

- Always sort pins by `order` field for consistent numbering  
- Use pin IDs directly for collection, not coordinate matching
- Comprehensive debug logging for AR object creation and collection
- Entity-to-data mapping pattern for AR objects

## Learnings and Project Insights

- Coordinate-based collection was unreliable due to floating-point precision
- Array indices don't guarantee database order consistency  
- Direct ID mapping provides bulletproof object-to-data association
- AR object labeling essential for debugging collection issues
