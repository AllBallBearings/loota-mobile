# Loota Mobile - App Store Submission Checklist

The items below still need to be completed or verified before the app can ship to the Apple App Store.

Bugs

- Joining after entering name and phone sometimes doesn't respond
- Joining Hunt but then just returns to default screen and ARVIew never loads
- collected count goes from 1 to 0

## Immediate Blockers

1. **Secure the API Key** (`loota/loota/Environment.swift:24`)

   - Remove the hardcoded production key from source.
   - Load secrets from build settings, XCConfig, or the Keychain at runtime.
   - Add a lightweight runtime guard to crash/log if the key is missing to avoid shipping a build without credentials.

2. **Publish and Reference a Privacy Policy**
   - Host a publicly accessible privacy policy covering camera and location usage.
   - Add `NSPrivacyPolicyURL` to `loota/loota/Info.plist` pointing at that page.
   - Re-run the App Privacy questionnaire in App Store Connect with consistent answers.

## Release Configuration

3. **Lower the Deployment Target**

   - Project settings currently target iOS 18.0/18.2 (`loota/loota.xcodeproj/project.pbxproj`).
   - Drop to at least iOS 16.0 unless a hard dependency blocks it, then QA on devices running the minimum OS.

4. **Finalize Bundle Identifier & Signing**

   - Confirm the bundle ID (`allballbearings.loota`) is registered in the Apple Developer account.
   - Create App Store distribution certificate & provisioning profile, then enable automatic signing in Xcode or add the profiles to CI.

5. **Archive & Verify Release Build**
   - Produce an `Archive` build with the App Store provisioning profile.
   - Validate in Organizer for bitcode, app thinning, and ensure no debug artifacts (debug logging for API key, etc.).

## App Store Connect Assets

6. **Prepare Marketing Materials**

   - Capture required device screenshots for all supported display classes (iPhone Pro/Max, standard, iPad if supported).
   - Record an optional AR preview video to strengthen the listing.
   - Draft polished description, subtitle, keywords, and release notes.
   - Select category/subcategory and complete the age-rating questionnaire.

7. **Fill Required Metadata**
   - Supply Support URL, Marketing URL (optional), and contact email.
   - Set pricing/availability and regions.
   - Configure in-app events or promotional text if desired.

## QA & Compliance

8. **Test on Physical Hardware**

   - Exercise AR flows on at least one A12+ device running the minimum OS and the latest release candidate build.
   - Verify location permissions, camera usage, battery impact, and background behavior.

9. **Guideline & Permission Audit**
   - Double-check usage descriptions for camera/location are precise and match in-app behavior.
   - Ensure onboarding clearly explains location usage to satisfy App Review.
   - Remove debug-only endpoints, test accounts, and verbose logging before final build.

## Recently Completed

- **Expand App Icon Set** – Generated the full suite of iOS icon sizes and updated `AppIcon.appiconset/Contents.json` so the asset catalog now passes App Store requirements.
