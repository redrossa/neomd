# M1-13 durable cue fixtures

Status: accepted fixture/implementation baseline, **not executed app evidence**. See [`../../m1-13-cues-plan.md`](../../m1-13-cues-plan.md) and [issue #13](https://github.com/redrossa/neomd/issues/13). Triage staged only Markdown, JSON, a newly authored PNG, license text and documentation; the worker authors executable tests separately.

## Inventory and authority

- `alerts.md`: exactly five alert kinds in order NOTE/TIP/IMPORTANT/WARNING/CAUTION, with separated roots, multiblock/list/task/nested ordinary quote/code/link bodies; C1/C2/C5.
- `alert-cases.json`: 31 independent source vectors, including CRLF, indentation/trailing whitespace, marker-only, escaped/entity/formatted/reference-linked/nested/later-line/definition-first negatives. Parse **each JSON source independently**; definitions must not leak between cases. `alert-controls.md` is a visual collection of the negatives, not a standalone oracle for each cmark literal spelling.
- `emoji.md` and `emoji-cases.json`: 22 exact source/output vectors, direct Unicode/ZWJ/skin-tone/variation/combining scalars, aliases, escaped colon/name controls, even/odd backslashes, entities, code, links/autolinks and script style. Expected text is the leaf text, excluding fixture headings; code-block newline is meaningful. C3.
- `emoji-corpus.md`: all 1,913 aliases with literal-code name, prose token and exact Unicode reference per row. `corpus/expected-aliases.json` is the exhaustive lookup oracle. Corpus/hash/license/provenance files are pinned offline data, not permission to fetch at runtime.
- `colors.md` and `color-cases.json`: 49 normalized-code parser vectors, 15 valid/34 invalid, with finite sRGB oracles. Color comparison tolerance for pure Double conversion can be 1e-6; screenshot sampling has a separately justified rendering tolerance. `normalized_code` is a **direct parser input**, not raw Markdown. Where the Markdown fixture uses double spaces, the expected single leading/trailing space survives cmark's one-pair normalization. Do not trim parser input. C4.
- `context-cases.json`: 9 independent heading/duplicate-anchor, reference URL, image metadata, linked color text, whitespace, break-boundary and raw-markup vectors. Image alt strings remain literal metadata; adjacent ordinary prose transforms. C3/C4/C5 and preservation.
- `mixed-cues.md`: plain Text; unlinked-image SwiftUI composition; linked-image native NSTextView; ordinary/native headings; missing image states; image-only and picture; alert/list/task/quote/footnote; distant `#mixed-target` and explicit `#mixed-start` return. Loaded and unavailable states are in the file; loading states should use controlled native-host/store inputs, not a public network race. C1–C5.
- `img/badge.png`: newly authored opaque 16×8 RGB #28a745 image, no ancillary/script data, deterministic pixels. `img/absent.png` must remain absent. No app icon or DMG artifact is included.
- `MANIFEST.json`: SHA256 and byte length of each fixture artifact (excluding the self-referential manifest). Newline/Unicode/escape bytes matter. Outer staging `MANIFEST.json` also covers staged docs and records accepted-base hashes of the two existing docs.

## Reproduction, isolation and cleanup

Copy this entire folder, preserving relative paths, to a fresh owned temporary directory (NSWorkspace opening like current image/link tests); never open repository originals for testing. Record every file's exact bytes/SHA256 and `st_mtime_ns` before opening. Set a known mtime if the test needs a deterministic snapshot. `img/absent.png` must not be created. Test products may have the existing Xcode file-read exception; this is not new sandbox/grant proof. For human plain-build reproduction, use the existing explicit image-folder access action if necessary, never change sandbox settings or prompt automatically.

No fixture uses a runtime network endpoint for images. Corpus acquisition was research-only; emoji reading must work offline. The example.com destinations in literal/parser controls are **not to be activated**. Mixed document actions are internal anchors and launch no other app.

Serialize UI; own/terminate only the test app and temporary directory; preserve unrelated NeoMD sessions. Opening themes may use existing per-app overrides; actual live-system check uses the existing authorized appearance host/controller and restores the initial system state even on failure. Denied automation or failed restoration is a blocker, not a pass. Do not read email, touch clipboard, publish a DMG or modify original/icon worktrees.

After each test's opening/scroll/resize/theme/close sequence, compare **every** fixture file's bytes and mtime to its snapshot before removing only the owned directory. No new file/preferences should be stored beside the source.

## Criterion-linked actions and expected observations

| Criterion | Actions | Required outcome/evidence |
| --- | --- | --- |
| C1 | Open `alerts.md` Light and Dark; traverse five bodies and multiblock IMPORTANT | Exactly one persistent word label of each type, with meaningful distinct symbol/treatment; ordered intact body, tasks/code/link preserved; controls are ordinary content with no deleted marker text. |
| C2 | Open in each real/app appearance; actual system Light→Dark→Light while the same alert remains at a recorded reading point | Adaptive label/rule/text coherent and readable; meaning remains through word/shape, same snapshot/IDs/window and approximate reading point, original appearance restored. Inspect actual screenshots rather than merely attaching them. |
| C3 | Evaluate all alias/vector data, then view `emoji.md`/mixed cues offline | Exact Unicode scalar output (including ZWJ/VS16), every alias recognized; unknown/custom/escaped/code/URL/metadata controls remain readable. Preserve style, anchors and native links. |
| C4 | Evaluate 49 values; inspect blue/white/black and invalid code in both inline/image paths | Small baseline-aligned swatch only on valid whole inline code; exact value still selectable/AX-readable. Black/white retain border contrast; swatches add zero controls/link actions/duplicate AX announcements. |
| C5 | Both appearances at actual scales 1×/1.5×/2×, widths900/480, with alerts and mixed paths | Measured actual fonts grow proportionally, labels reserve height, glyphs/swatches align and wrap without clipping/overlap, task/ordinal markers stay aligned, code stays literal, bitmap natural-size policy unchanged. AX text/roles and keyboard/mouse links remain usable. |

Use a 12-cell appearance×scale×width matrix in deterministic native-host measurements and visibly exercise all three scales/both SwiftUI and native paths in story UI. Screenshot/geometry evidence should identify the fixture row/alert, scale, width, appearance and actual measured font points. Frame comparisons should distinguish allocated column width from glyph bounds. Scroll to offscreen samples rather than treating their initial invisibility as failure. Include normal wide→narrow→wide reading-point preservation without attempting to relabel #36 as passed.

Keyboard actions: Option-Tab to existing link-bearing leaf, arrows select link, Return/Space activate `#mixed-target`, Escape returns to reader; click actual native badge and authored code-text link in an isolated context case. The swatch is not a separate focus/action target. Selection regression uses native selected-range/attributed-content checks or drag visuals **without copy**. Fresh exclusive-window approval is necessary before any clipboard-mutating selector, even one that restores it.

## Tests and evidence status

**No executable selectors or app results were created/run by triage.** Suggested worker group names only: `MarkdownCueParsingTests`, `MarkdownCuePresentationTests`, `MarkdownCueHostingTests`, `DocumentCueUITests`. Worker may choose focused names and must replace these suggestions with actual `-only-testing` selectors, exact commands, positive pass counts (no zero-selection results), SHA/PR links, xcresults and inspected screenshot names in the cumulative catalog. Build/unit/story UI gates and relevant preservation needs are in the accepted plan. Do not copy historical broad class commands that include clipboard tests.

## Final user-owned combined milestone checks (not completed)

Combine alerts/emoji/colors with native image loading, distant links/tasks/footnotes, multiple documents, resizing and real system appearance. Human VoiceOver must hear alert label before its body once, literal color values/emoji meaning without duplicate decorative speech, correct link/task roles and context exit. Record actual utterances and tested SHA/macOS/VoiceOver settings, restore original host state, and recheck bytes/mtime. Comprehensive E2E/manual speech is deferred, **not passed**; current-story AX and required live/scale UI are not deferred. Preserve #36's unchanged full-reflow test as BLOCKED/deferred for final investigation. Do not close milestone or start #14 from this fixture catalog.
