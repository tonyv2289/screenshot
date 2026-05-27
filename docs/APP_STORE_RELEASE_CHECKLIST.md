# Screenshot Roll Release Checklist

## Build Surface

- Regenerate the project: `./scripts/generate_xcodeproj.sh`
- Open `/Users/pelayopro/projects/screenshot-clean/iOS/ScreenshotRoll.xcodeproj`
- Build `ScreenshotRoll`
- Build `ScreenshotRollV2`
- Build `ShareExtension`
- Run `./scripts/release_preflight.sh`

## Manual Product Validation

- Import screenshots from `PhotosPicker`
- Verify OCR text appears in search results
- Verify duplicate screenshots are flagged correctly
- Verify `Share to Screenshot Roll` writes into the shared inbox and the app drains it
- Verify free-plan cap blocks imports after 120 assets
- Verify paywall loads product metadata and restore flow returns gracefully
- Verify Delete All Data clears files and the database

## Signing And Distribution

- Confirm App ID: `com.tonyv2289.screenshotroll`
- Confirm extension App ID: `com.tonyv2289.screenshotroll.share`
- Confirm App Group: `group.com.tonyv2289.screenshotroll`
- Confirm Developer Team: `RPKMKV2TZ6`
- Confirm StoreKit products exist in App Store Connect:
  - `com.tonyv2289.screenshotroll.pro.yearly`
  - `com.tonyv2289.screenshotroll.lifetime`
- Archive from Xcode
- Upload to TestFlight

## Metadata

- App name, subtitle, and keywords
- App Store screenshots
- Support URL
- Privacy policy URL
- In-app purchase review notes if Apple asks about the paywall
