# Loota Mobile - Todo List

## App Store Submission Requirements

### Critical Requirements (Must Fix Before Submission)

#### 1. App Icons Missing ❌
- **Issue**: No app icon images found in `Assets.xcassets/AppIcon.appiconset/`
- **Required**: 1024x1024px icon in PNG format
- **Impact**: App Store will reject without proper icons
- **Priority**: CRITICAL

#### 2. API Key Security Issue ⚠️
- **Issue**: Hardcoded API key in `Environment.swift:27`
- **Required**: Move to Xcode build settings or secure keychain storage
- **Impact**: Exposes sensitive data, security vulnerability
- **Priority**: HIGH

#### 3. Privacy Policy Required ❌
- **Issue**: App collects location data and uses camera but no privacy policy URL
- **Required**: Add `NSPrivacyPolicyURL` to Info.plist
- **Impact**: Apple requires privacy policy for location/camera permissions
- **Priority**: CRITICAL

### Important Items

#### 4. iOS Deployment Target ⚠️
- **Current**: iOS 18.0 (very recent)
- **Recommendation**: Lower to iOS 16.0+ for broader device compatibility
- **Impact**: Current target excludes many devices
- **Priority**: MEDIUM

#### 5. Bundle Identifier
- **Current**: `allballbearings.loota`
- **Required**: Ensure this matches your Apple Developer account
- **Priority**: MEDIUM

#### 6. Code Signing & Provisioning
- **Required**: 
  - Valid Apple Developer account
  - App Store distribution certificate
  - App Store provisioning profile
- **Priority**: HIGH

### App Store Listing Requirements

#### 7. Marketing Materials Needed
- **Screenshots**: iPhone + iPad (if supporting iPad)
- **App Preview Video**: Optional but recommended for AR apps
- **App Description**: Compelling description with keywords
- **App Category**: Select appropriate category
- **Age Rating**: Complete age rating questionnaire
- **Priority**: MEDIUM

#### 8. App Store Metadata
- **App Name**: Primary app name
- **Subtitle**: Short descriptive subtitle
- **Promotional Text**: Marketing copy
- **Release Notes**: Version release information
- **Support URL**: Customer support website
- **Copyright**: Copyright information
- **Priority**: MEDIUM

### Testing & Quality Assurance

#### 9. Physical Device Testing
- **Requirement**: AR features must be tested on physical iOS device
- **Issue**: Simulator cannot test ARKit functionality properly
- **Priority**: HIGH

#### 10. App Store Review Guidelines Compliance
- **Check**: Location services properly justified
- **Check**: AR experience doesn't encourage dangerous behavior
- **Check**: No hardcoded credentials or test data in production
- **Priority**: HIGH

## Implementation Priority Order

### Phase 1: Critical Blockers
1. ✅ Create and add app icons (1024x1024px)
2. ✅ Add privacy policy URL to Info.plist
3. ✅ Move API key to secure build settings

### Phase 2: Important Setup
4. ✅ Configure code signing and provisioning profiles
5. ✅ Test thoroughly on physical iOS device
6. ✅ Review iOS deployment target (consider lowering)

### Phase 3: App Store Preparation
7. ✅ Create marketing screenshots and materials
8. ✅ Write app description and metadata
9. ✅ Complete App Store listing information
10. ✅ Final compliance review

## Notes

- **Current Status**: App is technically complete but missing critical App Store requirements
- **Architecture**: Well-designed with proper AR implementation
- **Main Blockers**: App icons, privacy policy, and API key security
- **Estimated Timeline**: 1-2 days for critical fixes, 1 week for full submission preparation