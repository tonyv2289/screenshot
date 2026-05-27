# Screenshot Roll Product Contract

## Status

This repo currently contains two parallel implementations:

- `ScreenshotRoll` = the existing product attempt (`v1`)
- `ScreenshotRollV2` = a first-principles rewrite for side-by-side comparison

`ScreenshotRollV2` is not the default shipping replacement just because it is simpler.

## Product Thesis

Screenshot Roll is not meant to be a generic screenshot importer.

The intended product is:

- privacy-first
- on-device
- built for screenshot retrieval, not general photo storage
- differentiated by intelligence, not just by a grid view

The product must explicitly win on four pillars:

- iPhone-native capture
- action extraction
- context and memory
- paid utility trust

Differentiation may include:

- OCR-powered retrieval
- semantic or topic-based recall
- ticker extraction / finance-aware parsing
- duplicate handling
- frictionless ingestion from the iPhone share sheet
- immediate actions from detected content
- related-screenshot memory, not just standalone search hits
- paid utility positioning instead of ad-supported commodity software

## Competitive Reality

As of 2026-05-27, Screenshot Roll is entering a real and increasingly crowded category.

What is already common in the market:

- OCR
- categorization
- plain-language search
- generic "AI screenshot organizer" messaging

What is still strategic whitespace:

- the strongest iPhone-native capture loop
- action extraction that turns screenshots into next steps
- context and memory surfaces that connect screenshots together
- privacy-first paid utility positioning

See `docs/COMPETITIVE_MATRIX.md` for the current landscape.
See `docs/SAVING_PIPELINE.md` for the capture and save architecture.

## Must-Win Pillars

### 1. iPhone-native capture

- `PhotosPicker` for library backfill
- share extension for the zero-friction save path
- App Group inbox handoff between extension and app
- background indexing so the import flow survives app switching
- stable local library filenames based on image-byte hashes
- manifest-backed share inbox items so partial writes are not treated as imports

### 2. Action extraction

- surface links, emails, phone numbers, places, dates, and tickers where present
- allow the user to act from the screenshot, not only search it later
- prefer reliable native actions over vague AI summaries

### 3. Context and memory

- cluster by topic, author, and entity
- connect related screenshots
- expose memory exports / context for assistants
- make the user feel the app remembers, not just stores

### 4. Paid utility trust

- on-device first
- privacy made legible in product copy and behavior
- pricing that aligns with a utility, not growth-hacked content software

## What v2 Is For

`ScreenshotRollV2` exists to answer one question:

Can we build a calmer, more legible implementation of the core screenshot-library loop without destroying `v1`?

Its current scope is intentionally narrow:

- import screenshots with `PhotosPicker`
- run on-device OCR
- save local files and metadata
- search OCR text, tags, and categories
- inspect and relabel items
- flag exact duplicates

`v2` may simplify implementation, but it is not allowed to erase the four pillars above.

## What v2 Is Not Allowed To Decide Unilaterally

The following are product decisions, not cleanup decisions:

- paywall / monetization
- share extension
- background indexing
- knowledge graph or semantic recall
- ticker extraction
- perceptual near-duplicate detection
- “brain” or differentiated retrieval UI

If a future rewrite omits any of these, it must mark them as one of:

- `defer`
- `restore`
- `reject`

and give a reason.

Silence does not count as a decision.

## Decision Board

| Capability | v1 Status | v2 Status | Decision |
|---|---|---|---|
| OCR search | Present | Present | Keep |
| Manual screenshot import | Present | Present | Keep |
| Paywall / paid tiers | Present | Not implemented | Defer pending product decision |
| Share extension | Present | Not implemented | Restore before replacement; core moat |
| Background indexing | Present in partial form | Not implemented | Restore before replacement; core UX |
| Knowledge graph / topic recall | Present | Not implemented | Restore or replace with equivalent memory surface |
| Ticker extraction | Present | Not implemented | Keep for finance-aware differentiation unless explicitly rejected |
| Perceptual dedup | Present | Replaced by exact-hash flagging only | Defer; compare quality vs complexity |
| “Brain” surface / advanced recall UI | Present | Not implemented | Restore in some form before replacement |
| Native action extraction | Partial | Not implemented | Must become first-class, not hidden implementation detail |

## Replacement Criteria

`ScreenshotRollV2` should not replace `v1` unless all of the following are true:

1. It builds in full Xcode, not just via syntax parsing.
2. It runs on simulator or device without startup regressions.
3. Import, OCR, search, and detail flows work end-to-end.
4. Share-extension capture, background indexing, action extraction, and memory/context flows work end-to-end.
5. The omitted capabilities above have explicit decisions.
6. The team agrees whether `v2` is:
   - the new shipping app
   - a stripped core to extend
   - or just a reference implementation

## Repo Hygiene

This repo has historical contamination from unrelated Condo Ledger work.

That cleanup is a separate task. Until then:

- do not assume every directory belongs to Screenshot Roll
- do not use repo sprawl as evidence that a product feature is unnecessary
- prefer `project.yml` plus explicit product docs as the source of intent
