# App Store Submission Guide for Loota

## Step 1: Code Signing & Distribution Certificate

### 1.1 Generate App Store Distribution Certificate
1. Open Xcode
2. Go to **Xcode > Settings > Accounts**
3. Select your Apple Developer account (Team: 8XHKTX9X49)
4. Click **Manage Certificates**
5. Click **+** and select **Apple Distribution**
6. Certificate will be created and installed automatically

### 1.2 Create App Store Provisioning Profile
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Profiles** > **+** (Create new profile)
4. Choose **App Store** under Distribution
5. Select App ID: `allballbearings.loota`
6. Select the distribution certificate you just created
7. Name it: `Loota App Store Distribution`
8. Download and double-click to install

### 1.3 Update Xcode Project Settings
1. Open `loota.xcodeproj` in Xcode
2. Select the **loota** target
3. Go to **Signing & Capabilities** tab
4. **Release Configuration**:
   - **Automatically manage signing**: UNCHECK for manual control
   - **Provisioning Profile**: Select "Loota App Store Distribution"
   - **Code Signing Identity**: Apple Distribution
   - OR keep **Automatically manage signing** CHECKED (Xcode will handle it)

**Recommended**: Keep automatic signing enabled for easier management.

## Step 2: App Store Connect Setup

### 2.1 Create New App Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Apps** > **+** > **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: Loota
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: allballbearings.loota
   - **SKU**: loota-mobile-001 (or any unique identifier)
   - **User Access**: Full Access

### 2.2 App Information
Navigate to **App Information** section:

- **Category**: Primary: **Games > Adventure**
- **Age Rating**: Complete questionnaire (likely 4+)

### 2.3 Pricing and Availability
- **Price**: Free (or set your price)
- **Availability**: All countries or select specific regions

## Step 3: Prepare App Metadata

### 3.1 App Store Description
**Name**: Loota (max 30 characters)

**Subtitle** (max 30 chars): AR treasure hunting adventure

**Description** (max 4000 chars):
```
Discover hidden treasures in the real world with Loota, an exciting augmented reality treasure hunting game!

🎯 HOW IT WORKS
• Join treasure hunts created by others or create your own
• Use your iPhone's camera and GPS to find virtual treasures
• Cast magical hand gestures to summon nearby collectibles
• Compete to be the first to collect all items and win prizes

✨ FEATURES
• Immersive AR experience using ARKit
• Real-world geolocation treasure placement
• Magical hand gesture detection for summoning objects
• Multiple hunt types: GPS-based and proximity-based
• Winner rewards and contact system
• Beautiful 3D collectible coins and treasures

🏆 COMPETE & WIN
Be the first to complete a hunt and win real prizes! Contact information is securely shared between winners and hunt creators for prize fulfillment.

📍 REQUIRES
• iPhone with ARKit support (iPhone 6s or newer)
• iOS 16.0 or later
• Location and camera permissions

Start your treasure hunting adventure today!
```

**Keywords** (max 100 chars):
```
AR,treasure,hunt,augmented reality,game,adventure,scavenger,geocaching,exploration,prizes
```

**Promotional Text** (max 170 chars - can be updated without review):
```
New hand gesture summoning! Cast spells to collect nearby treasures. Join the hunt and win real prizes in this AR adventure game!
```

**Support URL**: https://loota.fun/support (create this page)

**Marketing URL** (optional): https://loota.fun

**Privacy Policy URL**: https://loota.fun/privacy (REQUIRED - create this page)

### 3.2 App Review Information
**Contact Information**:
- First Name: [Your First Name]
- Last Name: [Your Last Name]
- Phone Number: [Your Phone]
- Email: [Your Email]

**Demo Account** (if login required):
- Username: [N/A - no login required]
- Password: [N/A]

**Notes**:
```
TESTING INSTRUCTIONS:

1. LOCATION: App requires real-world location access. Please enable location permissions when prompted.

2. CAMERA: App uses ARKit for augmented reality. Please enable camera access.

3. DEMO HUNT: A test hunt is available for review:
   - Hunt ID: [INSERT TEST HUNT ID]
   - Location: [Accessible to reviewers]
   - The hunt contains 5-10 collectible items

4. HAND GESTURES: The app detects hand poses to "summon" nearby objects. Wave your hand in front of the camera when near a collectible.

5. COMPLETION: Complete the hunt to see the winner screen and contact features.

6. PHONE NUMBER: App collects phone numbers for prize fulfillment between winners and hunt creators. This is clearly explained during signup.

Thank you for reviewing Loota!
```

**Attachment** (optional): Add screenshots or demo video if needed

## Step 4: Required Screenshots

### 4.1 iPhone 6.9" Display (1290x2796) - REQUIRED
Create at least 3, up to 10 screenshots showing:
1. **Splash Screen / App Launch** - Shows Loota branding
2. **AR View with Treasure** - Main gameplay with AR coins/objects visible
3. **Collection Animation** - Moment of collecting a treasure
4. **Hunt Progress** - UI showing progress through a hunt
5. **Winner Screen** - Completion celebration screen
6. **Hand Gesture Summoning** - Demonstrating the hand gesture feature (optional)

**Tools to Create Screenshots**:
- Run app on iPhone 15 Pro Max simulator
- Use **Cmd+S** to save screenshots
- Or run on physical device and screenshot
- Use Preview or online tools to add text overlays/descriptions

### 4.2 iPhone 6.7" Display (1290x2796) - Recommended
Same screenshots as 6.9" (can reuse if aspect ratio matches)

### 4.3 App Preview Video (Optional but Recommended)
- Max 30 seconds
- Portrait orientation: 1080x1920 or 1200x1600
- Show key features: AR viewing, collection, gestures, completion
- No audio narration allowed (music/sound effects OK)

## Step 5: Build and Upload

### 5.1 Create Archive Build
1. Open project in Xcode
2. Select **Any iOS Device (arm64)** as build target (not simulator)
3. Go to **Product > Archive**
4. Wait for archive to complete

### 5.2 Validate Archive
1. In Organizer window, select your archive
2. Click **Validate App**
3. Choose options:
   - ✅ Upload app's symbols for crash reports
   - ✅ Manage app version and build numbers
   - (Follow prompts, select distribution certificate)
4. Wait for validation to complete
5. Fix any errors if validation fails

### 5.3 Upload to App Store Connect
1. After validation passes, click **Distribute App**
2. Choose **App Store Connect**
3. Select distribution options (same as validation)
4. Click **Upload**
5. Wait for upload to complete (may take 10-30 minutes)

### 5.4 Processing in App Store Connect
1. Go to App Store Connect > Your App > TestFlight tab
2. Wait for "Processing" to complete (can take 15-60 minutes)
3. Build will appear under **iOS builds** when ready

## Step 6: Submit for Review

### 6.1 Select Build
1. In App Store Connect, go to your app
2. Click **App Store** tab
3. Under **Build**, click **+** to add a build
4. Select the build you just uploaded

### 6.2 Complete All Sections
Ensure all sections show checkmarks:
- ✅ App Information
- ✅ Pricing and Availability
- ✅ App Privacy (complete privacy questionnaire)
- ✅ Prepare for Submission (screenshots, description, etc.)

### 6.3 App Privacy Questionnaire
**Data Collection**:
- ✅ Yes, we collect data
  - **Location**: Precise location (for app functionality)
  - **Contact Info**: Name, Phone number (for app functionality)
  - **Identifiers**: Device ID (for user accounts)
  - **Usage Data**: None
- Data is linked to user identity: YES
- Data is used for tracking: NO

### 6.4 Submit
1. Click **Add for Review** (or **Submit for Review**)
2. Select **Manually release this version** or **Automatically release**
3. Click **Submit**

## Step 7: Review Process

### 7.1 What to Expect
- **Review time**: Typically 24-48 hours
- **Status tracking**: Check App Store Connect for status updates
- **Common statuses**:
  - Waiting for Review
  - In Review
  - Pending Developer Release (if approved)
  - Ready for Sale (if auto-release selected)
  - Rejected (with feedback)

### 7.2 If Rejected
1. Read rejection reason carefully
2. Fix the issues in your code
3. Increment build number (e.g., 1 → 2)
4. Create new archive and upload
5. Reply to review team with changes made
6. Resubmit

### 7.3 Common Rejection Reasons
- Missing or incorrect privacy policy
- Missing test instructions or demo account
- Incomplete metadata
- Crashes or bugs during review
- Misleading screenshots or description
- Privacy violations

## Step 8: Post-Approval

### 8.1 Release
If you selected manual release:
1. Go to App Store Connect > Your App
2. Click **Release this Version**
3. App goes live within a few hours

### 8.2 Monitor
- Check crash reports in Xcode Organizer
- Monitor reviews in App Store Connect
- Track downloads and analytics

## Checklist Before Submission

- [ ] Distribution certificate installed
- [ ] Provisioning profile created and configured
- [ ] App builds successfully in Release configuration
- [ ] Version number set (1.0)
- [ ] Build number set (1)
- [ ] Privacy Manifest (PrivacyInfo.xcprivacy) included
- [ ] Privacy Policy URL live and accessible
- [ ] Support URL created
- [ ] App description written (under 4000 chars)
- [ ] Keywords selected (under 100 chars)
- [ ] Screenshots prepared (minimum 3)
- [ ] App icon 1024x1024 in asset catalog
- [ ] Age rating completed
- [ ] App Store Connect app record created
- [ ] Test hunt created for reviewers
- [ ] Demo instructions written
- [ ] Archive validated successfully
- [ ] Build uploaded and processed
- [ ] Privacy questionnaire completed
- [ ] All App Store Connect sections complete

## Need Help?

- **Apple Documentation**: [App Store Connect Help](https://help.apple.com/app-store-connect/)
- **App Review Guidelines**: [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Common Rejections**: [Apple Common Rejections](https://developer.apple.com/app-store/review/rejections/)
