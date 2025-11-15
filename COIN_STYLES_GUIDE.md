# Coin Style Visual Guide

This guide explains the four different coin styles available in the app. Each has a distinct appearance with different rim widths and embossing effects.

## How to Change Coin Style

Edit `CoinConfiguration.swift` and change the `selectedStyle` constant to one of these values:

```swift
static let selectedStyle: CoinStyle = .classic  // Change this!
```

## Available Styles

### 1. Classic Coin (`.classic`)
**Rim Width:** 10% of radius
**Center Height:** 60% of total coin height
**Appearance:** Clean and balanced with subtle embossing

```
Side View:          Top View:
     ___                ___________
    |   |              /           \
====|   |====         |  [center]  |
    |___|              \___________/
      ^                      ^
   Center (60%)           10% rim
```

**Best for:** General use, balanced proportions, subtle detail

---

### 2. Thick Rim Coin (`.thickRim`)
**Rim Width:** 15% of radius
**Center Height:** 50% of total coin height
**Appearance:** Bold and distinct with prominent raised edge

```
Side View:          Top View:
     ___                ___________
    |   |              /           \
======   ======        | [center]  |
    |___|              \___________/
      ^                      ^
   Center (50%)          15% rim
```

**Best for:** Maximum visibility, bold appearance, prominent embossing

---

### 3. Detailed Coin (`.detailed`)
**Rim Width:** 12% of radius (multi-layer)
**Layers:** Outer rim (100%) → Inner rim (75%) → Center (55%)
**Appearance:** Intricate stepped profile with depth

```
Side View:          Top View:
     ___              _______________
    |   |            /               \
  ==|   |==         | [inner rim]    |
====|   |====       |  [center]      |
    |___|            \_______________/
      ^                    ^   ^
   Center             Inner  Outer
   (55%)              rim    rim
```

**Best for:** Maximum detail, stepped appearance, complex geometry

---

### 4. Beveled Coin (`.beveled`)
**Rim Width:** 12% of radius (beveled)
**Layers:** Outer rim → Bevel transition → Center
**Appearance:** Smooth gradual transition, polished look

```
Side View:          Top View:
     ___              _______________
    |   |            /               \
   /|   |\          /  [bevel zone]   \
====|   |====       |    [center]      |
    |___|            \_______________/
      ^                    ^
   Center              Smooth bevel
   (60%)               transition
```

**Best for:** Polished appearance, smooth edges, gradual depth change

---

## Technical Specifications

| Style      | Rim % | Center Height % | Layers | Alpha Variation |
|------------|-------|----------------|--------|----------------|
| Classic    | 10%   | 60%            | 2      | Minimal        |
| Thick Rim  | 15%   | 50%            | 2      | Moderate       |
| Detailed   | 12%   | 55%            | 3      | High           |
| Beveled    | 12%   | 60%            | 3      | Gradual        |

## Implementation Details

All coins are built using layered cylinders with:
- **Metallic material** for realistic shine
- **Varying alpha transparency** to create depth perception
- **Precise radius calculations** for consistent rim widths
- **Vertical orientation** (standing on edge)

The embossed effect is created by:
1. Outer rim at full height (creates the "lip")
2. Inner layers at reduced height (creates the "thinner center")
3. Precise radius offsets (creates the stepped/beveled effect)

## Testing Different Styles

To test different styles:
1. Open `loota/CoinConfiguration.swift`
2. Change `selectedStyle` to `.classic`, `.thickRim`, `.detailed`, or `.beveled`
3. Build and run the app
4. Observe the coins in AR to see the differences
5. Choose your favorite and commit!

---

**Current Style:** Classic (10% rim, balanced proportions)
