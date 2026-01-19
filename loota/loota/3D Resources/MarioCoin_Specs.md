# Mario-Style Gold Coin Specifications

## Reference
Inspired by the gold coin from "The New Super Mario Bros."

## Design Description

### Physical Characteristics
- **Overall Style**: Chunky profile with good thickness (not a thin coin)
- **Raised Border Rim**: Extends about 20% into the diameter of the coin with a flat outer edge
- **Recessed Center**: Main face of the coin is lower than the border rim
- **Vertical Rectangle Emblem**: Pressed into the center, going about twice as deep as the center recess from the border edge

### Depth Layers (from highest to lowest)
1. **Border rim** (highest/outermost)
2. **Center face** (recessed from rim)
3. **Vertical rectangle** (deepest - 2x deeper than center recess)

This creates a dimensional, "stamped" look that gives the coin character.

## Creation Plan

### Geometry
1. **Base cylinder** - chunky proportions for the main coin body
2. **Border rim modeling** - raised edge that extends 20% into the diameter with flat outer surface
3. **Center recess** - Boolean/extrusion to create the recessed main face
4. **Vertical rectangle emblem** - Deep inset (2x the depth of center recess)
5. **Clean topology** - Optimized geometry for AR performance

### Material
- **Bright golden yellow color** - Shiny, almost cartoonish appearance
- **Smooth, polished look** - Not overly detailed/realistic
- **Metallic properties** - Gold material with appropriate reflectivity

### Export
- **Format**: USDZ for iOS ARKit compatibility
- **Optimization**: Lightweight for AR performance
- **Naming**: To be integrated with Loota AR app

## Technical Specifications
- Target file format: `.usdz`
- Performance: Optimized for iOS ARKit
- Integration: Loota mobile AR treasure hunting app
