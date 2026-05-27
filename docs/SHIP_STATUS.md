# Screenshot Roll Ship Status
Updated: 2026-05-27

## Validated

- `ScreenshotRoll` builds successfully for `generic/platform=iOS Simulator`
- `ScreenshotRollV2` builds successfully for `generic/platform=iOS Simulator`
- both apps install and cold-launch on the iPhone 17 Pro simulator on the Mac Studio
- bundle IDs, App Group IDs, app icons, launch screen, and privacy manifests are present in the clean repo
- StoreKit is no longer hardcoded unlocked in `v1`

## Current Blocker

- device archive for `ScreenshotRoll` fails during `ShareExtension.appex` codesign on the Mac Studio with `errSecInternalComponent`

## What That Means

- this is no longer a source-code compile blocker
- this is a signing/keychain/provisioning-session blocker on the build machine
- TestFlight upload is blocked until the Mac Studio can complete a signed archive

## Next Actions

- fix Mac Studio signing so headless or GUI archive can access the Apple Development certificate
- rerun `xcodebuild ... archive`
- if archive succeeds, upload to TestFlight and run end-to-end import/OCR/share checks on a device
