# Screenshot Roll Saving Pipeline
Updated: 2026-05-27

## Principle

Saving is a first-class product path, not a side effect of OCR.

Every imported screenshot should move through the same durable stages:

1. Capture image bytes from the native iOS entry point.
2. Save those bytes to a stable local location.
3. Skip exact duplicates where possible.
4. Index OCR, entities, actions, topics, and relationships.
5. Surface the saved item in the library.

## Entry Points

### PhotosPicker

- `LibraryView` receives selected `PhotosPickerItem` values.
- `LibraryViewModel.importSingleImageData` preserves the selected image bytes.
- `ImportService.saveImageDataToLibrary` writes the image into app support storage.
- `IndexingService.processImportedImage` runs OCR and intelligence extraction.

### Share Extension

- `ShareViewController` extracts image data from shared `NSItemProvider` objects.
- `ScreenshotInboxStore.enqueueImageData` writes each image plus a JSON manifest into the App Group inbox.
- `ShareInboxProcessor.processPending` drains the inbox from the main app or background task.
- The same `ImportService` and `IndexingService` path handles final library save and indexing.

## Storage

- App Group inbox: `SharedInbox/`
- Failed inbox quarantine: `FailedInbox/`
- Library assets: app support `ScreenshotRoll/Assets/`
- Database: app support `ScreenshotRoll/screenshot_roll.sqlite`

Library asset filenames are based on the SHA-256 hash of the original image bytes. That gives stable filenames and allows exact duplicate skips before spending OCR/indexing work.

## Metadata

Each share-extension capture writes a manifest with:

- inbox item ID
- capture timestamp
- image filename
- original suggested name
- original type identifier
- byte count

The manifest is written after the image data, so the app only processes complete inbox items.

## Duplicate Behavior

- Exact duplicates share the same hash filename.
- If the database already has an asset for that file path, the inbox item is removed without creating another library record.
- Perceptual duplicate detection still runs inside `IndexingService` for near-duplicates.

## Free-Tier Behavior

- New imports obey the `StoreService` free limit.
- Exact duplicates from the share inbox can still be drained even when the user is at the cap.
- New share items over the cap remain in the inbox so they can be imported after upgrade.

## Files

- `iOS/ShareExtension/ShareViewController.swift`
- `iOS/ScreenshotRoll/Shared/ScreenshotInboxStore.swift`
- `iOS/ScreenshotRoll/Services/ShareInboxProcessor.swift`
- `iOS/ScreenshotRoll/Services/ImportService.swift`
- `iOS/ScreenshotRoll/Services/IndexingService.swift`
- `iOS/ScreenshotRoll/ViewModels/LibraryViewModel.swift`
