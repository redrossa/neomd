# M1-19 / #19 — table validation map

Status: **ACCEPTED for implementation readiness only; all implementation gates UNRUN at triage.** Exact base `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`; runtime openai-codex/gpt-6-astra/high verified. Canonical [issue #19](https://github.com/redrossa/neomd/issues/19), body and all paginated comments read (zero comments). Source unchanged from adopted DAG source `53a8c243b8359bacebee5887f4d8b2f6d200fe0c` by documentation-only PR #55. [M1-DAG-001](milestone-1-dependency-plan.md) governs scheduling, not historical numeric order.

## Complete contract and evidence mapping

As a reader of generated comparisons, I want tables so that I can compare options easily.

| Criterion, verbatim | Base evidence / implementation scope | Permitted later evidence | Native result |
| --- | --- | --- | --- |
| Render header rows, column alignment, and inline formatting within cells. | cmark table extension is attached, but adapter flattens rows/cells and prunes empty cells; parity test expects A/B/C/D roots. Preserve a flat owned table/row/column/header descriptor and attributed cell leaves. | Parser structure fixtures, attributed run assertions, stable addresses, header/alignment presentation conversion. | DEFERRED/UNRUN |
| Wide tables scroll horizontally within their own area without forcing the whole document to scroll sideways. | Reader has bounded vertical-only column; code overflow is precedent. Table needs atomic bounded surface and local horizontal scroller, keyboard overflow stop and correct nested-owner cell reveal. | Pure column/row geometry and overflow-action calculations, traversal candidate order. | DEFERRED/UNRUN |
| Cell borders, text, and backgrounds remain readable in both themes and at larger text sizes. | ReaderTheme(scale:) exists; add adaptive table surfaces/rules/header weight and scaled finite cell widths/heights. No #22 command dependency. | Numeric 1/1.5/2 scaling, adaptive token/conversion data, no dropped text/attributes. | DEFERRED/UNRUN; #36/#38 not a passing oracle or expanded waiver |
| Preserve table structure and header associations for assistive technology. | No table AX exists. Metadata label/value layout is not general table evidence. Native table/row/column/cell identity and actual header element associations are required. | Pure row/column/cell association/address descriptors only; source/API inspection. | Actual AX tree/VoiceOver DEFERRED/UNRUN |

Do not check a full issue criterion based only on readiness, pure data or a build. Coordinator may record reduced implementation acceptance separately; user retains native and business acceptance. Known implementation defects and failed permitted gates block affected work. No #14 work or #36/#38 repair is authorized; neither equivalence nor larger-size waiver is implied.

## Inert packet

[Fixture README](fixtures/m1-19-tables/README-fixture.md), `comparison.md`, `wide.md`, `contexts.md`, `nearby.md`, `badge.svg`, `structure-cases.json` under `docs/fixtures/m1-19-tables/`. These are inputs and intended oracles, **not executed tests or observed parser output**. The fixture JSON has eleven independent structural cases, including empty/missing/excess cells, header-only, duplicate/empty headers, escaped pipes/code spaces, comment/anchor-only cells, LF/CRLF/CR, Unicode and literal task markers, mismatched delimiters and fenced controls. No image network request is required; `absent.png` is deliberately absent. The explicit example.com link is not to be activated during permitted units.

`contexts.md` keeps YAML metadata separate and covers table-in-task/quote/alert/footnote, collision-safe generated footnotes returning to distinct cells, empty-cell custom anchors, adjacent same-URL images, empty alt and missing fallback. Add attributed run expectations in unit code rather than translating cells to opaque strings. Worker records any fixture correction with explanation and rehashed manifest; do not silently rewrite an oracle to a failing implementation.

## Inspected existing non-interaction allowlist

The following suite bodies were read in full at the exact base. Whole-suite selectors below contain only parser, immutable data, numeric policy or font/attributed conversion checks; no windows, events, native focus/AX actions or clipboard mutation. Reinspect if another story changes their bodies before execution.

- `-only-testing:NeoMDTests/CMarkParityTests` — update only obsolete flattened table expectations; retain autolinks/images/HTML/concurrency/deep ownership controls.
- `-only-testing:NeoMDTests/MarkdownBlockRendererTests` — inline provenance/scalars, literal recovery, paths, container identity.
- `-only-testing:NeoMDTests/MarkdownFootnotesTests` — generated collisions, reference eligibility, anchors, flat note bodies.
- `-only-testing:NeoMDTests/MarkdownHTMLCommentsTests` — hidden comments and token provenance; metadataFixtureCases is inert fixture reading.
- `-only-testing:NeoMDTests/MarkdownFrontMatterTests` — YAML boundary and non-Markdown metadata isolation.
- `-only-testing:NeoMDTests/TaskListRenderingTests` — real list task preservation and literal controls.
- `-only-testing:NeoMDTests/EmojiCueTests` — pinned offline corpus/provenance and concurrent parser values.
- `-only-testing:NeoMDTests/ColorCueTests` — only the two pure methods in this type; **not** the separate NativeColorCueTests in the same file.
- `-only-testing:NeoMDTests/AlertCueTests` — parser arena and numeric layout only.
- `-only-testing:NeoMDTests/MarkdownContainerLayoutTests` — numeric geometry, bounded view-entry plan and linear flat ownership; includes 50,000-depth inputs without hosting a view.
- `-only-testing:NeoMDTests/ReaderThemeTests` — attributed policy/font resolution, no live appearance change.

Only these individual methods from mixed suites are allowed:

- `-only-testing:NeoMDTests/KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops`
- `-only-testing:NeoMDTests/MarkdownLinkedImageTextTests/headingFormattingAndAdjacentImageOccurrencesSurviveNativeConversion`
- `-only-testing:NeoMDTests/MarkdownImagesTests/pictureBlockBecomesAnImageParagraph`
- `-only-testing:NeoMDTests/MarkdownImagesTests/pictureSourcesUseTheDocumentPathPolicy`
- `-only-testing:NeoMDTests/MarkdownImagesTests/pictureWithoutImgOrWithExtraContentStaysLiteral`
- `-only-testing:NeoMDTests/MarkdownImagesTests/malformedPicturesStayLiteralAndAdjacentImagesRemainSeparate`
- `-only-testing:NeoMDTests/MarkdownImagesTests/emptyAltImagesKeepACarrierRunAndContextsRetainImages`
- `-only-testing:NeoMDTests/MarkdownImagesTests/adjacentSameURLImagesRetainDistinctAttachmentRuns`
- `-only-testing:NeoMDTests/MarkdownImagesTests/malformedPictureAttributesRemainLiteral`
- `-only-testing:NeoMDTests/MarkdownImagesTests/appearanceSelectionPrefersMatchingSourceThenFallback`
- `-only-testing:NeoMDTests/MarkdownImagesTests/displaySizeClampsToWidthPreservingAspectRatio`

The linked-image method creates an in-memory bitmap and attributed conversion only; it never instantiates a text view/window. The image methods above parse/resolve or calculate values; exclude loader networking, chmod, store lifecycle and native-host tests not needed for this change.

Explicit exclusions: whole `NeoMDTests`, whole mixed KeyboardTraversalTests/MarkdownLinkedImageTextTests/MarkdownImagesTests, NativeColorCueTests, NativeColorLeafTests, NativeInlineLeafTests, all Hosting/Feasibility/NativeNavigation/native bridge action suites, all NeoMDUITests, appearance controllers, window/scroll hosting probes, synthetic/real events, direct native movement/selection/focus/AX actions and clipboard mutation. In particular, `KeyboardTraversalTests.exactNativeChordAndClipboardFreeSelection` synthesizes events, and `MarkdownLinkedImageTextTests.textSystemMeasuresAndPreservesSelectionOnUnchangedUpdates` opens a window and performs AX press; their names are not an allowlist. `dismantlingReleasesOwnedStateAndDisablesRetainedAccessibilityActions` also calls AX press. Preserve these tests for future authorization, do not delete or relabel them passed.

## Planned new non-interaction tests (worker writes, triage did not)

Recommended dedicated types, valid as whole-suite selectors only while every method stays non-interaction:

1. `NeoMDTests/MarkdownTableRenderingTests`: consume all 11 structural cases with nonzero asserted case count; full attributed styles/code scalar ranges/links/images/cues, empty header/cell retention, row/header/alignment values, parser-normalized body width, cells' parent/preorder/subtree/lazyRoot identity; no double flattening/text duplication. Add nested quote/list/task/alert/footnote contexts and very deep table-under-quote ownership without native views. Assert anchor-only cell targets itself; repeated references return to their own cells and generated collisions resolve. Assert tables following metadata remain separate. Parser-rejected controls remain readable and script markup never becomes active.
2. `NeoMDTests/MarkdownTableLayoutTests`: pure finite-input/output policy over numeric cell measurements, width 0/1/240/320/760 and invalid proposals; scale 1/1.5/2; default/left/center/right positions, single-column and 12-column local overflow; tallest-cell row sizing, nonzero empty rows, no height truncation; wrapped/unbroken-text measurement inputs, independently clamped offsets, fitting/overflow transition, atomic table placement inside compressed containers. Assert outer width never expands and no duplicate outer cell views. Numeric action planner tests exercise allowed key intents as enums/modifier values, **not NSEvent**. Candidate order has one overflow stop before row-major text/link stops, skipped if fitting.
3. `NeoMDTests/MarkdownTableAddressTests`: pure stable tableID/leafID/row/column mapping, repeated strings and empty headers remain distinct, descriptor row-major reading order, bounds-safe lookup, correct column-header cell identity and no invented row header, generation rejection as value policy. This proves descriptors only, not native AX.
4. `NeoMDTests/MarkdownCellDisplayProjectionTests`: source attributed UTF-16 to actual native attributed payload maps for text, styled Unicode/surrogates/combining scalars, loaded image attachment, loading/unavailable fallback/status, empty-alt carrier and adjacent same-URL occurrences. In-memory bitmap conversion allowed, no loader/view/layout host. Map text exactly and replacement spans atomically; preserve links and cue attributes, no hidden-comment segment or added swatch index. Test a pure range-remapping function across image states/width/theme/scale, clamping stale boundaries and retaining immutable source. Header weight/alignment combines with inline bold/italic/code/sub/sup/link policy. Do not mutate a live selection to test this data policy.

Names may be refined by worker, but record exact final selectors and inspect every method; adding a native host/action to one requires method-level exclusion, not a blanket new-suite allowlist.

## Later worker commands and evidence

No commands in this section were run by triage. Coordinator grants one Xcode invocation lease; use unique story worktree, DerivedData, fresh result bundle and logs outside the repository. From that worktree:

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-19-DerivedData build
```

For tests use the same project/scheme/destination and DerivedData, a fresh `-resultBundlePath`, and **every intended exact `-only-testing:` selector from the allowlist above plus inspected new types**, followed by `test`. Do not replace the selectors with whole NeoMDTests or run a full-suite command. Confirm nonzero case counts and actual selector execution; a successful zero-tests invocation is not evidence. No signing/team/target/security changes to bypass toolchain limits. Build failures or unavailable required non-interaction tests are blocking, not assumed pass.

Worker evidence slot (all **UNRUN**): source PR/head SHA; synchronized integration base; Debug command/status/log; full selector command; per-type expanded cases/pass/failure/skip counts; xcresult path; fixture hash/corrections; source inspection of native table associations/overflow ownership; outstanding limits. Include exact resulting head evidence after any integration rebase. Record evidence here and a concise catalog entry without modifying historical failures. No reviewer/duplicate test stage.

## Worker evidence — RECORDED (implementation gates only)

Runtime: user-approved **fallback** worker `anthropic/claude-opus-5`, thinking `high` (primary `openai-codex/gpt-6-astra` unavailable; a first fallback attempt ended on a transient provider rate limit and left this worktree's work uncommitted, which this run reviewed, completed and validated). Worktree `/tmp/NeoMD-19-structured-tables`, branch `story/19-structured-tables`, base `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`. No integration rebase was required: `main` had not advanced past the base at validation time. Exact validated head SHA is recorded in the PR description.

**Artifact integrity — no corrections.** All seven `docs/fixtures/m1-19-tables/` files and `docs/m1-19-validation.md` were installed at the manifest SHA-256 values and reverified byte-for-byte before use; `MANIFEST.json` itself hashes to `3917fcae57f7c2523f1887a8418176e4ffced67e1128c589da2d0e4aeaf45c82`. The catalog base matched `8c444788a3583f1c810d1ccb6712f6305bce09e90556aa876b38f363f2671533`, and `CATALOG-ENTRY-PATCH.md` was inserted verbatim as an entry immediately before the M1-15 historical authority heading; no historical entry, `#36`/`#38` failure or deferral record was altered. This evidence section is the only worker modification to this file, as its evidence slot directs.

**Debug build** — `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-19-DerivedData build` → `** BUILD SUCCEEDED **`, no warnings from story code. Logs `/tmp/neomd-19-build-1.log`, `/tmp/neomd-19-build-2.log`.

**Non-interaction units** — the 11 allowlisted whole suites, the 11 individually allowlisted methods from mixed suites and the 4 new table suites, as exact `-only-testing:` selectors, same project/scheme/destination/DerivedData, `-resultBundlePath /tmp/neomd-19-results-2.xcresult`, `test`. Result **Passed**: 18 suites, **110 test functions / 149 executed test runs, 0 failed, 0 skipped, 0 expected failures** (8 parameterized tests contributed 47 runs). Command `/tmp/neomd-19-test-cmd.sh`, log `/tmp/neomd-19-test-2.log`.

Executed cases per suite: CMarkParityTests 5, MarkdownBlockRendererTests 22, MarkdownFootnotesTests 6, MarkdownHTMLCommentsTests 4, MarkdownFrontMatterTests 2, TaskListRenderingTests 7, EmojiCueTests 5, ColorCueTests 2, AlertCueTests 3, MarkdownContainerLayoutTests 5, ReaderThemeTests 7, KeyboardTraversalTests 1, MarkdownLinkedImageTextTests 1, MarkdownImagesTests 9, MarkdownTableRenderingTests 7, MarkdownTableLayoutTests 10, MarkdownTableAddressTests 6, MarkdownCellDisplayProjectionTests 8.

**Selector correction:** Swift Testing method selectors require the trailing `()` (`-only-testing:'NeoMDTests/MarkdownImagesTests/pictureBlockBecomesAnImageParagraph()'`). A first invocation without it silently executed **zero** cases for all 11 individual methods while still reporting `TEST SUCCEEDED`; that run (`/tmp/neomd-19-results-1.xcresult`) is not evidence and was superseded. Whole-suite selectors need no parentheses.

**Source inspection, not native proof.** Native table/row/column/cell AX elements, header association, local overflow ownership and the narrowed nested-scroller ownership check were verified by reading the actual implementation and the installed SDK declarations only.

**Outstanding limits.** `NeoMDTests/DocumentNavigationBridgeTests` — which owns the nested-scroller-rejection assertion this change had to preserve — creates an `NSWindow` and is on this map's explicit exclusion list, so the narrowed `isOwned` ancestry check is argued from source and left **UNRUN**; it rejects any enclosing scroller that is not the reader's own viewport or the app's own bounded `MarkdownTableScrollView`. Everything in the section below, including all rendering, overflow scrolling, keyboard reach, selection, link/image behavior, adaptive appearance at larger sizes, actual accessibility trees and VoiceOver, stays **DEFERRED/UNRUN**. No `#36`/`#38` work, waiver or equivalence is implied.

## Final native acceptance — DEFERRED/UNRUN, future user-owned only

The fixture README contains the future observations. They are not permission for worker/triage scripted interaction or host substitutes. Actual header alignment and inline formatting, overflow containment/keyboard reach/selection/link policy, adaptive borders/backgrounds/text at each internal scale, native AX associations and VoiceOver, resize/position retention, image-state changes, and read-only bytes/mtime all remain unverified. #22 commands/persistence are not implemented here. Preserve #36/#38 known failures and obtain user direction if an applicable defect blocks table behavior. Never close the milestone or report combined business acceptance from implementation completion.
