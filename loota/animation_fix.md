# Animation Fix Log

## Problem Summary
The CoinSmooth.usdz has embedded spin and bob animations. When placed in the AR scene:
1. One coin gets stuck to the camera (AnchoringComponent issue)
2. Animations don't play properly (broken animation target paths from reparenting)

## Attempts

- **Attempt 1**: Increased USDZ coin scale in `CoinEntityFactory.makeCoin` from 0.12 to 0.24 to match desired size.
- **Attempt 2**: Temporarily re-enabled per-frame programmatic spin in `ARViewContainer+Animation.swift`, then removed it after confirming spin should come from USDZ.
- **Attempt 3**: Switched USDZ loading from `ModelEntity.loadModelAsync` to `Entity.loadAsync` to preserve embedded USDZ animation tracks.
- **Attempt 4**: Added recursive anchoring removal to strip `AnchoringComponent` from loaded USDZ entities to prevent camera anchoring.
- **Attempt 5**: Loaded only the `MarioCoin` `ModelEntity` (or first `ModelEntity`) from the USDZ to avoid anchoring; improved placement but reduced animation fidelity.
- **Attempt 6**: Restored full USDZ scene load, scaled the model node (not root) to preserve animation amplitude; animations still partially missing and one coin still stuck to camera.
- **Attempt 7**: Re-rooted the cloned USDZ scene into a new, non-anchored root entity, replayed root animations on that new root, and kept model-node scaling; goal is to prevent camera anchoring while preserving spin/bob tracks.
- **Attempt 8** (Current - 2026-01-19): Identified root cause - `reparentChildrenToNewRoot()` breaks animation target paths because USDZ animations reference entities by hierarchy path. New approach:
  1. Clone the USDZ entity recursively (preserving hierarchy)
  2. Strip `AnchoringComponent` recursively from the clone (don't reparent)
  3. Scale the `MarioCoin` ModelEntity directly (not the animated root) to preserve animation amplitude
  4. Add the cloned entity to a container (keeps original hierarchy intact)
  5. Call `startAnimations()` AFTER entity is added to scene (animations need scene context)

  Key insight: Animation paths like `/Root/MarioCoin` break when you move `MarioCoin` to a different parent. By keeping the original hierarchy and only stripping the anchoring component, animation paths remain valid.

## Debug Logging Added
- `logEntityHierarchy()` called on clone to show structure
- `startAnimations()` now logs with depth indentation
- `countAnimations()` reports total animations found

- **Attempt 9** (2026-01-19): Animations now play but coin still stuck to camera. Added more debugging:
  1. Added logging to detect if root entity is an `AnchorEntity` subclass (not just has AnchoringComponent)
  2. If root IS an AnchorEntity, extract children to a new plain Entity and replay animations there
  3. Added component debugging in `stripAnchoring()` to see what components exist
  4. Log entity type with `type(of: coinEntity)` and explicit `is AnchorEntity` check

  Hypothesis: The USDZ root might be an `AnchorEntity` subclass which has built-in anchoring behavior that can't be disabled by just removing the component.

- **Attempt 10** (2026-01-19): **ROOT CAUSE FOUND** - The USDZ contains a `Camera` entity (`Camera_001` of type `PerspectiveCamera`)! This embedded camera was causing the coin to render relative to the camera view instead of the AR world position. Also found `Sun`, `Sun_001`, and `env_light` entities.

  Fix implemented:
  1. Added `removeSceneEntities(from:)` function that recursively removes:
     - Camera entities (by type name containing "Camera" or name containing "camera")
     - Light entities (names containing "sun", "light", "env_light")
  2. Call this cleanup BEFORE stripping anchoring
  3. Log removed entities for debugging

  The USDZ hierarchy was:
  ```
  Entity (root)
  └── root
      ├── Sun → Sun_001
      ├── MarioCoin → MarioCoin_001 (ModelEntity - the actual coin)
      ├── Camera → Camera_001 (PerspectiveCamera) ← PROBLEM!
      └── env_light
  ```

- **Attempt 11** (2026-01-19): **SUCCESS** - Animations playing, coins at correct world positions. Final fix: coins were ~3 feet too high (above head level). Adjusted `objectHeight` from `0.0` to `-0.9` in both:
  - `ARViewContainer+Utilities.swift:53` (geolocation placement)
  - `ARViewContainer+Placement.swift:233` (proximity placement)

  This places coins at waist level (~0.9m below camera/eye height).

## Summary of All Fixes Applied
1. **Camera entity removal** - USDZ contained embedded `PerspectiveCamera` causing camera-relative rendering
2. **Light entity removal** - Removed `Sun`, `env_light` to use AR scene lighting
3. **Animation preservation** - Keep original hierarchy intact, don't reparent children
4. **Scale on model entity** - Scale `MarioCoin_001` directly, not animation root
5. **Height adjustment** - Lower placement by 0.9m for waist-level visibility

## Next Steps if Still Broken
- If height still wrong, adjust `objectHeight` value (try -0.7 to -1.1 range)
- If animations break after removal, the camera may have been part of the animation rig
- Consider re-exporting USDZ from Blender without camera/lights in export settings
