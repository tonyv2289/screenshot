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

Differentiation may include:

- OCR-powered retrieval
- semantic or topic-based recall
- ticker extraction / finance-aware parsing
- duplicate handling
- frictionless ingestion from the iPhone share sheet
- paid utility positioning instead of ad-supported commodity software

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
| Share extension | Present | Not implemented | Defer pending moat decision |
| Background indexing | Present in partial form | Not implemented | Defer pending UX validation |
| Knowledge graph / topic recall | Present | Not implemented | Defer pending differentiation decision |
| Ticker extraction | Present | Not implemented | Defer pending target-user decision |
| Perceptual dedup | Present | Replaced by exact-hash flagging only | Defer; compare quality vs complexity |
| “Brain” surface / advanced recall UI | Present | Not implemented | Defer pending product review |

## Replacement Criteria

`ScreenshotRollV2` should not replace `v1` unless all of the following are true:

1. It builds in full Xcode, not just via syntax parsing.
2. It runs on simulator or device without startup regressions.
3. Import, OCR, search, and detail flows work end-to-end.
4. The omitted capabilities above have explicit decisions.
5. The team agrees whether `v2` is:
   - the new shipping app
   - a stripped core to extend
   - or just a reference implementation

## Repo Hygiene

This repo has historical contamination from unrelated Condo Ledger work.

That cleanup is a separate task. Until then:

- do not assume every directory belongs to Screenshot Roll
- do not use repo sprawl as evidence that a product feature is unnecessary
- prefer `project.yml` plus explicit product docs as the source of intent
