Screenshot Roll (iOS MVP)

Privacy‑first, offline, AI‑organized library for screenshots. iOS 16+, SwiftUI, Vision OCR, SQLite FTS5, zero Photos permission (Photo Picker + Share Extension), on‑device processing only.

Project layout

- iOS app sources: `iOS/ScreenshotRoll`
- Share Extension sources: `iOS/ShareExtension`
- Ticker whitelist data: `Shared/TickerWhitelist/whitelist.csv`

Key capabilities

- Import only selected screenshots via Photo Picker (no full Photos access)
- Share Extension writes imports into App Group container
- On‑device OCR (Vision) → SQLite FTS5 index
- Auto‑tagging (Tweet/Chart/Meme/Receipt/Doc) via heuristics
- Ticker extraction with regex + whitelist
- De‑duplication via 64‑bit perceptual hash (aHash) + Hamming distance
- Fast search with filter chips (tags/tickers/date) and sort (Date/Relevance)
- BackgroundTasks for resilient indexing
- Settings: Delete All Data; privacy notice

How to open and run (Xcode 15+ on macOS)

1) Open `iOS/ScreenshotRoll` as a project folder in Xcode.
2) In Signing & Capabilities:
   - Add App Groups and create one, e.g. `group.com.yourcompany.screenshotroll`.
   - Enable Background Modes: Background processing and background fetch.
   - Enable File Protection and set default to `NSFileProtectionComplete`.
3) Update bundle identifiers for the app and the share extension.
4) Add the App Group ID string to `SharedContainer.sharedAppGroupId` in `SharedContainer.swift`.
5) Build & run on iOS 16+ device/simulator.

Dependencies

- Uses system SQLite (`import SQLite3`), no external DB package
- Uses Apple Vision (`Vision`, `VisionKit`) for OCR
- No networking or analytics

Data model (SQLite)

- Table `assets(asset_id INTEGER PRIMARY KEY, file_path TEXT, created_at REAL, width INTEGER, height INTEGER, kind TEXT, tickers TEXT, phash INTEGER, source TEXT, import_batch_id TEXT)`
- Virtual table `ocr_fts` (FTS5): `CREATE VIRTUAL TABLE ocr_fts USING fts5(text, tags, asset_id UNINDEXED, tokenize = 'unicode61 remove_diacritics 2');`
- Optional `boards` tables added post‑MVP

Search

- FTS5 BM25 ranking (`bm25(ocr_fts)`) with optional boosts in code
- Filters: tags (via `assets.kind`), tickers (CSV LIKE), date ranges, duplicates toggle

Build notes

- The repo is source‑only; create Xcode targets as needed. Files are organized for easy addition to targets.
- Share Extension target must be created in Xcode, then include the files under `iOS/ShareExtension` and add the App Group capability.

Security & privacy

- All processing on device; no network calls
- Files and DB written with `NSFileProtectionComplete`

License

Proprietary – for MVP prototyping.

