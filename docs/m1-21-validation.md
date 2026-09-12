# M1-21 find — validation map

Triage **ACCEPTED for implementation readiness only** at `c672c090b6c47a7c8247781af9cb4c3ec6b5dd54` (includes merged #19 tables, #23 refresh, #24 history). [Canonical issue #21](https://github.com/redrossa/neomd/issues/21), all four criteria read; zero issue comments at research. Runtime anthropic/claude-fable-5-1, high (coordinator-approved fallback; primary openai-codex/gpt-6-astra unavailable to this launch). [Inert packet](fixtures/m1-21-find/README-fixture.md). No builds/tests/prototypes/interactions run by triage. Native and business acceptance remain user-owned.

## Complete contract and criterion evidence

As a reader looking for a detail, I want Command-F search so that I can find visible text quickly.

| Criterion, unchanged | Exact-base implementation evidence and worker scope | Allowed evidence / outstanding native evidence |
| --- | --- | --- |
| C1 Command-F and the menu bar open a temporary native find interface; no permanent search control occupies the reading window. | No find command, menu item or bar exists (`NativeReaderMenus.swift` Edit menu has Copy/Select All only). Add Edit > Find > Find…/Find Next/Find Previous (⌘F/⌘G/⇧⌘G) routed by custom selectors to `DocumentWindowController`, a `DocumentReadSession` find request/query, and a `DocumentFindBar` inserted with `safeAreaInset(edge: .top)` only while `isFindPresented`. No toolbar/searchable modifier. | Model: command consumed once, requires open document, presentation flag cleared by a new-document `commit` and kept by `commitRefresh`. Actual menu, key equivalent, bar appearance/absence and focus DEFERRED/UNRUN. |
| C2 Search rendered text, including code and table cells, without matching hidden comments or formatting markup. | `block.text` already excludes comments (`MarkdownHTMLComments`, verified by `MarkdownHTMLCommentsTests`) and markup (cmark); URLs/image sources are attributes. Add pure `DocumentFindIndex` over `leafIDs` (cells are leaves; code blocks and `.metadata` included), excluding image runs and metadata row/separator crossings. | Pure: `find-cases.json` 29 cases and order invariants; independent source assertions. Visual confirmation that highlighted text is the visible text DEFERRED/UNRUN. |
| C3 Highlight the current match, scroll it into view, and support next/previous match through keyboard commands. | No highlight/reveal exists. Add `documentFindHighlight` environment (SwiftUI leaves: background attribute; native leaves: layout-manager temporary attribute via `MarkdownCellDisplayProjection.displayRange`; cells via `MarkdownTableCellEnvironment`; metadata via per-row mapping), `DocumentNavigationBridge.revealText` (extension only; `isOwned`/`Marker.Kind` untouched) and a `revealCurrentMatch` loop mirroring `navigate`/`traverse` lazy materialization. ⌘G/⇧⌘G, Return/⇧Return in the field, chevron buttons. | Pure: cursor `step` wrap/no-wrap/empty, projection range mapping across image segments. Actual highlight visibility, scroll-into-view (incl. lazy `long-lazy.md` and table cell), keyboard stepping DEFERRED/UNRUN. |
| C4 Show a clear no-results state; Escape dismisses find and returns focus to reading. | No state exists. Status text "Not found" for a non-empty query with zero matches (+ accessibility announcement, beep only on ⌘G with no matches); empty query shows neutral status. Escape (`onExitCommand`)/Done dismiss: bar removed, highlight cleared, `keyboardFocus = .reader`. Existing Escape meanings at link/code/table stops preserved. | Model: empty vs whitespace vs no-match distinctions in `DocumentFindIndex`. Actual Escape, focus return, VoiceOver announcement DEFERRED/UNRUN. |

All issue checkboxes remain unchecked at triage. Do not check a full criterion merely because its model portion passes.

## Concrete implementation boundary

Pure `DocumentFindIndex` (arena only, UTF-16 ranges, default case- and diacritic-insensitive literal matching, non-overlapping, wrap by default). Find state in `DocumentReadSession` (request + query + presented flag), reader-local matches/cursor/highlight. Current match only is highlighted with `NSColor.findHighlightColor`; temporary attributes never mutate native text storage, selection or AX. Table cell addresses are re-derived from each new arena; nothing about a match is persisted or written to reading history. No `NSTextFinder`, no `.searchable`, no toolbar, no ⌘E/Replace/regex/whole-word, no new `DocumentReaderFocusTarget` case, no relaxation of `isOwned`, no source writes. Full design: external `DESIGN.md` in the triage staging packet (coordinator holds the hash).

Shared-file notice for the coordinator: this story edits `NativeReaderMenus.swift`, `DocumentReaderView.swift`, `DocumentReadSession.swift`, `DocumentWindowController.swift` and native leaf/table files that #22 (size commands/menus), #16 (selection/AX) and #17 (recovery) may also touch. Lease overlapping methods; #21 does not depend on any unmerged sibling.

## Inspected existing non-interaction selector allowlist

Source bodies inspected, not run. Add `-only-testing:` to each selector passed to Xcode:

- `NeoMDTests/MarkdownHTMLCommentsTests` — all four methods: pure token-provenance/comment removal; proves "hidden comments absent from `block.text`".
- `NeoMDTests/MarkdownCellDisplayProjectionTests` — all nine methods: projection/range mapping with no window; `hiddenCommentsAndSwatchesAddNoDisplayIndexes` is the direct precedent for display-range mapping.
- `NeoMDTests/MarkdownTableAddressTests` — all six methods: pure row-major cell addresses and generation validity.
- `NeoMDTests/KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops` — pure candidates; guards that the focus-target enum is unchanged.
- `NeoMDTests/DocumentRefreshCommitTests` — all eight methods: model sessions; guards that find state added to `DocumentReadSession` does not disturb refresh tickets/restoration.
- `NeoMDTests/DocumentReaderLayoutTests` — all six methods: pure geometry used by block-level reveal.

Excluded as host/event substitutes: `KeyboardTraversalTests/weakIdentityGenerationDetachAndTwoOwnerIsolation`, `KeyboardTraversalTests/exactNativeChordAndClipboardFreeSelection`, `MarkdownLinkedImageTextTests/textSystemMeasuresAndPreservesSelectionOnUnchangedUpdates` (construct `NSWindow`/views). Do not run whole `NeoMDTests`.

## Planned new tests — not executable or already present

Worker authors meaningful tests; inspect actual bodies before adding selectors. Proposed suite names below are not claims that they exist.

**DocumentFindIndexTests (pure):** `fixtureCasesMatchAuthoredCounts`, `matchesFollowLeafOrderAndCursorSteps`, `hiddenCommentsMarkupURLsAndImageAltNeverMatch`, `metadataMatchesStayInsideOneKeyOrValue`, `rangesAreUTF16AndComposedCharacterSafe`, `nativeProjectionMapsFindRangesAcrossImagesAndSwatches`.

**DocumentFindSessionTests (model, no hosting):** `findCommandsAreConsumedOnceAndRequireAnOpenDocument`, `findQueryAndPresentationSurviveRefreshButNotANewDocument`, `stepWrapsAndRefusesEmptyMatches`.

## Worker evidence slot — UNRUN at triage

Record actual exact head, commands, nonzero tests/failures/skips and artifact corrections here. All native/visual/AX/keyboard/focus/scroll/refresh-while-open interaction evidence remains **DEFERRED/UNRUN**, not passed by index/model tests. Preserve #14/#36/#38 deferrals.
