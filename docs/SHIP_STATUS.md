# Screenshot Roll Ship Status
Updated: 2026-05-27

## Validated

- `ScreenshotRoll` builds successfully for `generic/platform=iOS Simulator` on the Mac Studio with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- `ScreenshotRollV2` builds successfully for `generic/platform=iOS Simulator` on the Mac Studio with full Xcode
- `ScreenshotRoll` creates an unsigned Release archive for `generic/platform=iOS`; this confirms the Release app and ShareExtension compile for device
- both apps install and cold-launch on the iPhone 17 Pro simulator on the Mac Studio
- bundle IDs, App Group IDs, app icons, launch screen, and privacy manifests are present in the clean repo
- StoreKit is no longer hardcoded unlocked in `v1`
- Mac Studio has valid code signing identities:
  - `Apple Development: Jose Villamil (ZQL5C5WHQP)`
  - `Apple Distribution: Jose Villamil (RPKMKV2TZ6)`

## Current Blockers

- signed archive over headless SSH fails at the ShareExtension `CodeSign` step with `errSecInternalComponent`
- `security show-keychain-info ~/Library/Keychains/login.keychain-db` over SSH returns `User interaction is not allowed`, so this is currently a keychain/private-key access problem rather than a missing certificate problem
- App Store export/upload still has to be rerun after signed archive succeeds

## What That Means

- this is no longer a source-code compile blocker
- this is no longer blocked by a missing Apple Distribution certificate
- TestFlight / App Store distribution is still blocked until the Mac Studio signing key can be used from the build session or the archive is produced from an unlocked GUI Xcode session

## Next Actions

- unlock the Mac Studio login keychain or run the archive from an unlocked GUI Xcode session
- if archiving from SSH/CI, grant codesign access to the private key with `security set-key-partition-list` after unlocking the keychain
- rerun a signed `xcodebuild archive`
- rerun `xcodebuild -exportArchive`
- upload to TestFlight
- run end-to-end import/OCR/share checks on a real device
