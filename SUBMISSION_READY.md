# Loota App Store Submission - Ready Status

## ✅ Completed Pre-Submission Tasks

### Code Preparation
- [x] **Privacy Manifest created** - [`PrivacyInfo.xcprivacy`](loota/loota/PrivacyInfo.xcprivacy) added with required privacy declarations
- [x] **API key secured** - Moved from hardcoded to Info.plist configuration
- [x] **Release build verified** - Project builds successfully in Release configuration
- [x] **Deployment target set** - iOS 18.0 (required for RealityKit BillboardComponent and advanced AR features)
- [x] **Code signing configured** - Development team 8XHKTX9X49, automatic signing enabled

### Project Configuration
- **Bundle ID**: `allballbearings.loota`
- **Version**: 1.0
- **Build**: 1
- **Display Name**: Loota
- **Category**: Games > Adventure
- **Minimum iOS**: 18.0
- **Required Capabilities**: ARKit, Camera, Location

## 📋 Next Steps (Your Action Required)

### 1. Code Signing & Certificates
**Status**: ⚠️ Manual setup needed

Follow instructions in [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md#step-1-code-signing--distribution-certificate):
1. Generate Apple Distribution certificate in Xcode
2. Create App Store provisioning profile at developer.apple.com
3. Select profile in Xcode project settings (or keep automatic signing)

**Estimated Time**: 15-20 minutes

---

### 2. App Store Connect Setup
**Status**: ⚠️ Manual setup needed

Follow instructions in [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md#step-2-app-store-connect-setup):
1. Create new app record in App Store Connect
2. Enter app information (name, category, age rating)
3. Set pricing and availability

**Estimated Time**: 10-15 minutes

---

### 3. Screenshots & Metadata
**Status**: ⚠️ Content needed

Follow checklist in [`SCREENSHOTS_CHECKLIST.md`](SCREENSHOTS_CHECKLIST.md):
1. **Minimum required**: 3 screenshots (1290x2796)
2. **Recommended**: 6 screenshots showing key features
3. **Optional**: App Preview video (30 seconds)

**Screenshot Content**:
- Splash screen with branding
- AR treasure hunting gameplay
- Collection animation
- Hand gesture summoning
- Progress tracking
- Winner celebration screen

**Estimated Time**: 2-4 hours (including design)

---

### 4. Required Web Pages
**Status**: ⚠️ Must create before submission

You MUST create these pages on your website:
- **Privacy Policy URL**: `https://loota.fun/privacy` (REQUIRED by Apple)
- **Terms of Service URL**: `https://loota.fun/terms` (REQUIRED for prize disclaimer)
- **Support URL**: `https://loota.fun/support` (REQUIRED for user assistance)

**Apple Requirements**:
- Privacy policy must explain data collection (location, phone number, name, device ID) and contact sharing
- Terms of Service must include prize disclaimer (Loota is platform only, doesn't guarantee prizes)
- Support page must provide contact method for users

**Prize Disclaimer Requirements**:
- ✅ **In-App Disclaimer Added**: Prize disclaimer now shown in HuntJoinConfirmationView before joining
- ⚠️ **Website Required**: Must create Terms of Service with prize disclaimer language
- ⚠️ **Privacy Policy Update**: Must explain contact sharing for prize communication

**Estimated Time**: 2-3 hours

---

### 5. Test Hunt for Reviewers
**Status**: ⚠️ Must create before submission

Create a demo hunt that Apple reviewers can test:
- **Location**: Accessible to reviewers (suggest common US location)
- **Items**: 5-10 collectible objects
- **Difficulty**: Easy to complete
- **Duration**: 5-10 minutes to finish

Include hunt ID and location in App Review Notes (see [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md#32-app-review-information))

**Estimated Time**: 30 minutes

---

### 6. Build & Upload
**Status**: ⏳ Ready when above steps complete

Once steps 1-5 are done, follow [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md#step-5-build-and-upload):
1. Archive build in Xcode
2. Validate archive
3. Upload to App Store Connect
4. Wait for processing (15-60 minutes)

**Estimated Time**: 30-45 minutes (plus processing)

---

### 7. Submit for Review
**Status**: ⏳ Ready when build uploaded

Complete all App Store Connect sections:
1. Select uploaded build
2. Complete privacy questionnaire
3. Add screenshots and description
4. Submit for review

**Estimated Time**: 15-30 minutes

---

## 📊 Overall Timeline

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| **Code Signing** | Certificates & profiles | 15-20 min |
| **App Store Connect** | App record & settings | 10-15 min |
| **Content Creation** | Screenshots & metadata | 2-4 hours |
| **Web Pages** | Privacy policy & support | 1-2 hours |
| **Test Hunt** | Demo for reviewers | 30 min |
| **Build Upload** | Archive & upload | 30-45 min |
| **Submission** | Final review setup | 15-30 min |
| **Apple Review** | Apple's review process | 24-48 hours |
| **TOTAL** | **5-9 hours + review time** | **1-2 business days** |

## 🎯 Critical Path

These must be completed in order:

1. **Code Signing** → 2. **App Store Connect** → 3. **Screenshots** → 4. **Web Pages** → 5. **Test Hunt** → 6. **Build Upload** → 7. **Submit**

## 📝 App Store Description (Ready to Use)

**App Name**: Loota

**Subtitle**: AR treasure hunting adventure

**Description** (see [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md#31-app-store-description) for full text):
```
Discover hidden treasures in the real world with Loota, an exciting augmented reality treasure hunting game!

🎯 HOW IT WORKS
• Join treasure hunts created by others or create your own
• Use your iPhone's camera and GPS to find virtual treasures
• Cast magical hand gestures to summon nearby collectibles
• Compete to be the first to collect all items and win prizes
```

**Keywords**: `AR,treasure,hunt,augmented reality,game,adventure,scavenger,geocaching,exploration,prizes`

## ⚠️ Important Notes

### iOS 18.0 Requirement
**Why**: The app uses RealityKit's `BillboardComponent` (iOS 18+) and advanced AR features that are not available in earlier iOS versions.

**Impact**: Only devices running iOS 18.0+ can download the app (iPhone XS/XR and newer models released from 2018 onward).

**Alternative**: To support iOS 17 or 16, you would need to:
- Remove or provide fallbacks for `BillboardComponent` usage
- Replace `MeshResource.generateCylinder` with iOS 17-compatible alternatives
- Update `.onChange` modifiers to use iOS 16-compatible syntax
- Test thoroughly on older iOS versions

### Privacy Requirements
The app collects:
- **Location**: Precise location for AR treasure placement
- **Phone Number**: For prize fulfillment between winners and creators
- **Name**: User identification
- **Device ID**: User account management

All data collection must be clearly explained in privacy policy.

### ARKit Requirements
- **Minimum Device**: iPhone 6s or newer (2015+)
- **Real Camera**: App cannot be fully tested in simulator
- **Real Location**: Location-based features require physical device testing

## 📚 Reference Documents

All documentation is ready in this repository:

- **[APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md)** - Complete step-by-step submission guide
- **[SCREENSHOTS_CHECKLIST.md](SCREENSHOTS_CHECKLIST.md)** - Screenshot requirements and creation guide
- **[CLAUDE.md](CLAUDE.md)** - Project overview and architecture documentation
- **[TODO.md](TODO.md)** - Project task tracking (if exists)

## 🆘 Need Help?

- **Apple Documentation**: [App Store Connect Help](https://help.apple.com/app-store-connect/)
- **App Review Guidelines**: [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Common Rejections**: [Apple Common Rejections](https://developer.apple.com/app-store/review/rejections/)

## ✅ Final Pre-Submission Checklist

Use this checklist before uploading:

### Technical
- [x] Release build succeeds
- [x] Privacy Manifest included
- [x] Version/build numbers set
- [x] App icon 1024x1024 present
- [ ] Distribution certificate installed
- [ ] Provisioning profile configured
- [ ] Archive validates successfully

### Content
- [x] Prize disclaimer added to app (in HuntJoinConfirmationView)
- [ ] Privacy policy URL live (must include contact sharing disclosure)
- [ ] Terms of Service URL live (must include prize disclaimer)
- [ ] Support URL live
- [ ] App description written (< 4000 chars) with prize disclaimer
- [ ] Keywords selected (< 100 chars)
- [ ] 3+ screenshots prepared (1290x2796)
- [ ] Age rating completed (4+ with prize disclaimer justification)
- [ ] Test hunt created for reviewers

### App Store Connect
- [ ] App record created
- [ ] Category selected (Games > Adventure)
- [ ] Pricing set
- [ ] Privacy questionnaire completed
- [ ] Build uploaded and processed
- [ ] All sections show checkmarks

**When all items checked**: You're ready to submit! 🚀
