# Screenshot Roll Ship Status
Updated: 2026-05-27

## Validated

- `ScreenshotRoll` builds successfully for `generic/platform=iOS Simulator`
- `ScreenshotRollV2` builds successfully for `generic/platform=iOS Simulator`
- both apps install and cold-launch on the iPhone 17 Pro simulator on the Mac Studio
- `ScreenshotRoll` archives successfully for `generic/platform=iOS` when run from the Mac Studio GUI session
- bundle IDs, App Group IDs, app icons, launch screen, and privacy manifests are present in the clean repo
- StoreKit is no longer hardcoded unlocked in `v1`

## Current Blockers

- App Store export fails with `PLA Update available`
- App Store export fails with `No signing certificate "iOS Distribution" found`
- headless SSH archive/export on the Mac Studio still hits keychain access issues; GUI-session execution is the current workaround

## What That Means

- this is no longer a source-code compile blocker
- this is no longer an archive blocker
- TestFlight / App Store distribution is still blocked until Apple account/legal acceptance and distribution signing are fixed on the Mac Studio

## Next Actions

- accept the latest Apple Program License Agreement for the team account in Apple developer tooling
- install or create a valid `Apple Distribution` certificate for team `RPKMKV2TZ6`
- rerun `xcodebuild -exportArchive` from the Mac Studio GUI session
- upload to TestFlight
- run end-to-end import/OCR/share checks on a real device
