# Screenshot Roll v2 — First-Principles Rewrite

## Provenance

This repo is not a clean single-product history anymore.

- The canonical GitHub repo for Screenshot Roll is `tonyv2289/screenshot`.
- The best local working copy on this machine is `/Users/pelayopro/Documents/New project`.
- That local repo still contains the Screenshot Roll iOS app under `iOS/ScreenshotRoll`, but it also contains later Condo Ledger work in the same history.
- Vault notes from `2026-04-10` confirm the same story: Screenshot Roll is the iOS app, Condo Ledger was accidentally layered into the same repo.

Practical conclusion: use `/Users/pelayopro/Documents/New project` as the current working baseline, but treat the original `ScreenshotRoll` target as a noisy `v1`, not as an architecture to extend.

## What v2 Is

`ScreenshotRollV2` is a clean sibling app target that keeps the real product idea and drops speculative complexity.

Core scope:

- import screenshots with `PhotosPicker`
- run on-device OCR with Vision
- save files locally in app support
- store explicit JSON metadata
- flag exact duplicates via SHA-256
- search OCR text, tags, and category
- relabel screenshot category in a detail view

Intentionally omitted:

- paywall logic
- “brain” / constellation UI
- background task scheduling
- knowledge graph features
- share extension coupling
- app-group dependency

## Architecture

`v1` spreads behavior across global services and mixes product ideas into one target.

`v2` is much narrower:

1. `ImportPipeline`
   - owns import orchestration
   - decodes image data
   - hashes it
   - runs OCR
   - classifies it
   - hands a finished record to storage

2. `LibraryStore`
   - is the only persistence boundary
   - writes image files and `library.json`
   - loads items
   - updates category edits
   - deletes the library

3. `ScreenshotRollV2LibraryViewModel`
   - owns UI state only
   - filtering
   - sort mode
   - duplicate visibility
   - import progress
   - status messages

4. Views
   - one library screen
   - one detail screen
   - one thumbnail helper

## v1 vs v2

| Area | v1 | v2 |
|---|---|---|
| Product scope | Screenshot app + paywall + “brain” UI + extension + background work + extra repo noise | Screenshot library only |
| Persistence | SQLite + FTS + multiple global services | Local files + one JSON snapshot |
| Duplicate logic | perceptual hash + duplicate linking | exact hash only, simple and deterministic |
| Search | FTS-driven and feature-rich | in-memory text filtering over explicit metadata |
| Architecture style | service-heavy, shared-singleton oriented | small pipeline + one store + one view model |
| Shipping posture | ambitious, coupled, harder to reason about | smaller, calmer, easier to verify |
| Risk profile | lots of moving pieces | intentionally boring |

## Why This Rewrite Is Better

Because it makes the product legible again.

- You can explain the whole import path in one minute.
- There is a single persistence boundary.
- There are no hidden side quests like StoreKit, share inbox draining, or knowledge-graph writes.
- Bugs should be easier to localize because the number of stateful systems is much smaller.

## What To Compare In Xcode

Open `/Users/pelayopro/Documents/New project/ScreenshotRoll.xcodeproj` and compare:

- `ScreenshotRoll`
- `ScreenshotRollV2`

Suggested evaluation:

1. Which target is easier to understand cold?
2. Which import path is easier to debug?
3. Which storage model would you trust to change safely next week?
4. Which UI feels like the app you actually want to ship first?

## Next Good Steps

If `v2` feels directionally right, the next upgrades should be:

1. move metadata from JSON to SQLite only when scale proves it necessary
2. add share extension support as a separate integration layer
3. add near-duplicate detection only after exact duplicates are solid
4. add monetization only after the core retrieval loop feels great