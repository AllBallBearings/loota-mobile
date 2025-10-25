# App Store Screenshots Checklist

## Required Screenshot Specifications

### iPhone 6.9" Display (iPhone 15 Pro Max)
- **Resolution**: 1290 x 2796 pixels
- **Format**: PNG or JPEG
- **Color Space**: sRGB or P3
- **Minimum Required**: 3 screenshots
- **Maximum Allowed**: 10 screenshots

### iPhone 6.7" Display (iPhone 14 Pro Max)
- **Resolution**: 1290 x 2796 pixels
- Same specifications as 6.9" (can often reuse same screenshots)

## Screenshot Content Plan

### 1. App Launch / Splash Screen ✨
**Purpose**: Show branding and first impression
- **Scene**: Loota splash screen with purple gradient and glow
- **Text Overlay**: "AR Treasure Hunting Adventure"
- **Tips**: Capture during 2-second splash animation at peak visual appeal

### 2. AR Main Gameplay 🎯
**Purpose**: Show core AR treasure hunting experience
- **Scene**: AR view with 3D coins floating in real-world environment
- **Elements to Show**:
  - At least 2-3 visible AR coins/objects
  - Real-world background (outdoor or indoor)
  - Collection counter/UI at top
  - Distance indicators to treasures
- **Text Overlay**: "Find & Collect Virtual Treasures in the Real World"

### 3. Collection Animation 💰
**Purpose**: Demonstrate the collection mechanic
- **Scene**: Moment of collecting a coin (close-up view)
- **Elements**:
  - Hand visible in frame reaching toward coin
  - Coin collection animation/effect
  - Score update or progress indicator
- **Text Overlay**: "Collect All Items to Win"

### 4. Hand Gesture Summoning 🪄
**Purpose**: Highlight unique hand gesture feature
- **Scene**: Hand performing summoning gesture with coin approaching
- **Elements**:
  - Hand clearly visible making gesture
  - Coin/object moving toward player
  - Visual effects (floating, approaching animation)
- **Text Overlay**: "Use Hand Gestures to Summon Treasures"

### 5. Hunt Progress View 📊
**Purpose**: Show progression and game state
- **Scene**: UI showing collected vs total items
- **Elements**:
  - Progress indicators (e.g., "3/5 collected")
  - Hunt information (name, creator)
  - Remaining items counter
  - Map or location hints (if visible in UI)
- **Text Overlay**: "Track Your Progress Through Each Hunt"

### 6. Winner Celebration Screen 🏆
**Purpose**: Show completion and rewards
- **Scene**: "Totally Looted!" completion screen
- **Elements**:
  - Celebration message
  - Winner status
  - Contact buttons (if applicable)
  - Hunt completion details
- **Text Overlay**: "Complete Hunts & Win Real Prizes"

### 7. Hunt List / Selection (Optional) 📋
**Purpose**: Show available hunts and social aspect
- **Scene**: List of available treasure hunts
- **Elements**:
  - Multiple hunt cards/items
  - Hunt details (location, items, rewards)
  - Join/start buttons
- **Text Overlay**: "Join Hunts or Create Your Own"

## How to Capture Screenshots

### Method 1: iOS Simulator (Easiest)
1. Open Xcode
2. Select **iPhone 15 Pro Max** simulator
3. Build and run the app (Cmd+R)
4. Navigate to desired screen
5. Press **Cmd+S** to save screenshot
6. Screenshots saved to Desktop

### Method 2: Physical Device
1. Run app on iPhone 14/15 Pro Max
2. Navigate to desired screen
3. Press **Volume Up + Side Button** simultaneously
4. Screenshots saved to Photos app
5. AirDrop or sync to Mac

### Method 3: Xcode Debug Menu
1. Run app on device or simulator
2. Click **Debug > View Debugging > Take Screenshot of [Device]**
3. Screenshot saved to Desktop

## Screenshot Enhancement

### Tools for Adding Text Overlays
- **Sketch** (Mac app, $99/year)
- **Figma** (Free, web-based)
- **Canva** (Free tier available)
- **Apple Keynote** (Free with Mac)
- **Pixelmator Pro** ($49.99 one-time)

### Design Tips
1. **Keep text minimal**: 5-10 words per screenshot
2. **Use readable fonts**: San Francisco, Helvetica, or similar
3. **High contrast**: Light text on dark backgrounds or vice versa
4. **Consistent style**: Use same font, colors across all screenshots
5. **Show UI clearly**: Don't obscure important app elements
6. **Real device context**: Show app in realistic usage scenarios

### Text Overlay Best Practices
```
- Font size: 60-80pt for headlines, 40-50pt for descriptions
- Text color: White with black shadow/stroke for readability
- Position: Top or bottom third of image (safe zones)
- Background: Semi-transparent overlay behind text if needed
- Localization: Consider if you'll submit in multiple languages
```

## Screenshot Order Recommendation

1. **Splash Screen** - First impression and branding
2. **AR Main Gameplay** - Core feature, most important
3. **Collection Animation** - Action shot, engaging
4. **Hand Gesture Summoning** - Unique selling point
5. **Hunt Progress** - Shows depth and progression
6. **Winner Screen** - Aspirational, shows rewards

## App Preview Video (Optional)

### Video Specifications
- **Duration**: 15-30 seconds
- **Resolution**: 1080x1920 (portrait) or 1200x1600
- **Format**: .mov, .mp4, or .m4v
- **Size**: Up to 500 MB
- **Frame Rate**: 24-30 fps

### Video Content Outline (30 seconds)
```
0:00 - 0:03   Splash screen with logo
0:03 - 0:08   AR view showing treasures in real world
0:08 - 0:13   Player walking, collecting first coin
0:13 - 0:18   Hand gesture summoning demonstration
0:18 - 0:23   Progress indicator updating, 4/5 collected
0:23 - 0:28   Final coin collected, celebration animation
0:28 - 0:30   "Totally Looted!" winner screen
```

### Video Recording Methods
1. **Xcode Simulator Recording**:
   ```bash
   xcrun simctl io booted recordVideo --type=mp4 loota_preview.mp4
   ```
   Press Ctrl+C to stop

2. **QuickTime Screen Recording**:
   - File > New Screen Recording
   - Select iPhone simulator window
   - Record interaction

3. **Physical Device**:
   - Use native screen recording (Control Center)
   - Or connect device to Mac and use QuickTime
   - File > New Movie Recording > Select iPhone

## Localization (If Applicable)

If submitting in multiple languages:
- Create separate screenshots with translated text overlays
- Or use screenshots without text overlays (less effective)
- Upload language-specific sets in App Store Connect

## Pre-Upload Checklist

- [ ] All screenshots are 1290 x 2796 pixels
- [ ] Files are PNG or JPEG format
- [ ] Images are under 500 KB each (compress if needed)
- [ ] Text overlays are readable and professional
- [ ] No pixelation or blurriness
- [ ] Screenshots show actual app functionality (not mockups)
- [ ] No white space or borders around screenshots
- [ ] Consistent visual style across all images
- [ ] Screenshots numbered/ordered correctly
- [ ] Privacy-sensitive info redacted (if any)
- [ ] No placeholder/debug text visible in UI

## Where to Upload

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app > **App Store** tab
3. Scroll to **App Store Screenshots** section
4. Select **6.9" Display** or **6.7" Display**
5. Drag and drop screenshots in desired order
6. Click **Save** in top right

## Resources

- [Apple Screenshot Specifications](https://help.apple.com/app-store-connect/#/devd274dd925)
- [App Preview Specifications](https://help.apple.com/app-store-connect/#/dev4e413fcb8)
- [Screenshot Best Practices](https://developer.apple.com/app-store/product-page/)
