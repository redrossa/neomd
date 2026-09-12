# M1-16 — selection/accessibility validation map

## Authority and status

[Canonical issue #16](https://github.com/redrossa/neomd/issues/16) · [approved architecture](https://github.com/redrossa/neomd/issues/16#issuecomment-5642959049) · [inert packet](fixtures/m1-16-selection/README-fixture.md).

Triage **ACCEPTED for implementation readiness** on exact main `7217b46ac4d69b532dc67b944f2a45407e6f0570` (includes #19 tables, #23 refresh, #24 history and #21 find, PR #59). Runtime `openai-codex/gpt-6-astra`, high, verified before research. Finalization retained the interrupted Fable 5.1/high predecessor's sound exact-base findings and corrected its stale blocked handoff, #16-before-#21 scheduling and blanket refresh-selection invalidation.

**Nothing has been built or tested by triage. No app/host/event/prototype/clipboard/GitHub interaction was performed.** Implementation tests/builds below are planned worker gates, not results. All pointer, keyboard, clipboard, visual and AX/VoiceOver behavior is **DEFERRED/UNRUN**. No reviewer stage. #14/#36/#38 remain deferred with known failures intact. User owns combined native testing and business acceptance.

#21 is merged and the prior contention wait is satisfied. Its changed source, new index/session unit bodies and find fixture/validation material were inspected for this refresh. Preserve find's UTF-16 source ranges, image/metadata-separator exclusions, temporary-attribute decoration, field-editor commands and refresh-held query/bar independently of selection. Selection's broader visible-text projection and TAB/LF joins must not silently expand or alter search. Coordinate native/table/metadata mapping and reveal/acquisition arbitration; no new semantic dependency or numerical chain is imposed. Refresh acceptance and target hashes if the worker base changes again.

## Full criterion map

| Criterion (verbatim) | Source gap / bounded implementation | Permitted evidence | Native limit |
| --- | --- | --- | --- |
| Text selection and Command-C copy the visible text, including useful code indentation, without adding Markdown delimiters. | Independent text stores; code/metadata/other visible text adapters; one generation/presentation-bound owner; document-wide partial range extraction, native Copy/Select All, table row-major TAB/LF joins, offscreen ranges and refresh re-derivation without persisted IDs. | Pure fragment/range/extraction/remap/refresh tests; exact parser whitespace, metadata and cell-display conversion. | Continuous pointer/Shift selection, actual clipboard payload and highlight behavior UNRUN. |
| Keyboard scrolling and link navigation work with a visible focus indicator. | Add missing real code/metadata text stops, preserve separate link/overflow stops and quiet enclosing focus; correct thick-link conversion and code scroller ownership. | Candidate arrays, pure focus-attribute conversion, generation/ownership value-policy tests. | Actual paging/Tab/link activation/drag/visible focus UNRUN. |
| VoiceOver can identify headings, links, lists, image descriptions, and checklist states in document order. | Add list identity and item/task associations; heading level and fallback image descriptors; preserve existing table AX. | Parser/ordered semantic descriptors and immutable attribute conversion only. | Actual native AX tree/VoiceOver semantics/reading order UNRUN; labels alone not acceptance. |
| File → Open and window commands remain discoverable in the menu bar. | Existing native menus retained; bounded active-reader command fallback must not override find field. | Source preservation and pure command-routing/validation policy; Debug compilation. | Menu visibility/discoverability/responder behavior UNRUN. |

## Worker gates

Only Debug build plus relevant **non-interaction** units. Use an isolated worktree at the accepted base, unique external DerivedData/log/xcresult paths, and coordinator's one-Xcode-invocation lease. Check source diagnostics before building. Do not alter signing, deployment, hardened runtime, ATS, build-script sandboxing or approved app-security policy to pass local gates.

Command shapes (not run):

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$STORY_DERIVED_DATA" build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$STORY_DERIVED_DATA" \
  -parallel-testing-enabled NO -resultBundlePath "$FRESH_STORY_RESULT" \
  -only-testing:NeoMDTests/KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops \
  test
```

For the unit invocation, append each relevant exact selector from the allowlist below before `test`, along with inspected new method selectors. The one-selector example is **not sufficient story coverage**. Record nonzero discovered/executed counts; zero selection, failure or skip is not a passing gate. Reinspect bodies after changes, especially post-#21 integration. Never substitute the whole `NeoMDTests`, `KeyboardTraversalTests` or an uninspected suite.

## Inspected existing non-interaction allowlist

Each line is an exact `-only-testing:` value. The original 23 bodies/helpers were inspected in the prior accepted packet and their complete source-file hashes are unchanged at this base. All nine added #21 bodies/helpers below were read during this refresh; **none executed**. Reinspect any worker-modified body before running it.

### Traversal, literal code, task association and metadata

- `NeoMDTests/KeyboardTraversalTests/semanticCandidatesKeepSeparateTextAndActionStops` — parser/candidate arrays; deliberately update for new code text stops. Contrary to the interrupted predecessor note, this method's current fixture has no table; add a new pure table/metadata stop case.
- `NeoMDTests/QuotationsAndCodeTests/codePreservesExactParserScalarsAndBoundaryBlankLines` — exact tabs/spaces/newlines.
- `NeoMDTests/QuotationsAndCodeTests/inlineCodeBoundaryScalarsSurviveInEveryLeafContext` — all-space and boundary code scalars.
- `NeoMDTests/QuotationsAndCodeTests/fencesAndLanguageHintsAreNotDocumentSyntax` — fence removal vs literal nested examples.
- `NeoMDTests/QuotationsAndCodeTests/ancestryOrderAndMarkerOwnership` — parsed list/quote/code ownership.
- `NeoMDTests/TaskListRenderingTests/hierarchyIdentityAndOrdinals` — list/task nesting and ordinal data.
- `NeoMDTests/TaskListRenderingTests/onlyFirstDirectParagraphOwnsMarker` — first description vs continuation.
- `NeoMDTests/MarkdownMetadataTests/bodySemanticsAndArenaAreUnaffectedByMetadata` — flat arena/body semantics and shifted image occurrences.
- `NeoMDTests/MarkdownMetadataTests/rowLabelsAndDescriptorsShareTheOutputBudget` — YAML rows/labels, no AX action.
- `NeoMDTests/DocumentFocusEffectTests/fixtureReadRenderPreservesBytesModificationTimeAndLinkCandidates` — temporary copied fixture read/render and bytes/mtime; no app actions.

### #19 per-cell adapter preservation

These construct in-memory attributed values/NSImage descriptors, not NSTextViews, windows, layout hosts, events or loaders. Pure conversion under main-actor AppKit attributes is permitted; it is not native selection proof.

- `NeoMDTests/MarkdownCellDisplayProjectionTests/plainTextSegmentsMapPositionForPosition`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/unicodeScalarsKeepComposedCharacterBoundaries`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/aReplacedImageMapsAtomicallyToItsWholeSpan`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/fallbackAndStatusTextIsDescribedAsItsOwnSegment`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/adjacentSameURLOccurrencesStayDistinctSegments`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/rangesRemapAcrossImageStateWidthAndThemeChanges`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/headerWeightAndAlignmentCombineWithInlineStyles`
- `NeoMDTests/MarkdownCellDisplayProjectionTests/hiddenCommentsAndSwatchesAddNoDisplayIndexes`

### #23 session replacement preservation

Plain session/renderer/value state; no files, windows, events or host controller.

- `NeoMDTests/DocumentRefreshCommitTests/refreshTicketRequiresAnIdleViewerBoundToThisDocument`
- `NeoMDTests/DocumentRefreshCommitTests/commitRefreshReplacesContentWithoutStartingAUserRequest`
- `NeoMDTests/DocumentRefreshCommitTests/aStaleOrForeignTicketIsRefused`
- `NeoMDTests/DocumentRefreshCommitTests/restorationIsConsumedOnceByItsOwnPresentation`
- `NeoMDTests/DocumentRefreshCommitTests/aRemappedPositionSurvivesInsertedMetadataAndProse`

These protect reading position and refresh authority, **not selection restoration**; add dedicated pure selection re-derivation tests.

### #21 find coexistence preservation — nine newly inspected selectors

These parse local fixture bytes or manipulate in-memory indices/session/attributed values only; no view/window/event/clipboard operations. Preserve sibling fixture bytes. `fixtureCasesMatchAuthoredCounts` explicitly records the authored `diacritic-exact` discrepancy: lowercase `café` cannot match capitalized `Café` with exact case sensitivity; this is not a new #16 search-policy decision.

- `NeoMDTests/DocumentFindIndexTests/fixtureCasesMatchAuthoredCounts`
- `NeoMDTests/DocumentFindIndexTests/matchesFollowLeafOrderAndCursorSteps`
- `NeoMDTests/DocumentFindIndexTests/hiddenCommentsMarkupURLsAndImageAltNeverMatch`
- `NeoMDTests/DocumentFindIndexTests/metadataMatchesStayInsideOneKeyOrValue`
- `NeoMDTests/DocumentFindIndexTests/rangesAreUTF16AndComposedCharacterSafe`
- `NeoMDTests/DocumentFindIndexTests/nativeProjectionMapsFindRangesAcrossImagesAndSwatches`
- `NeoMDTests/DocumentFindSessionTests/findCommandsAreConsumedOnceAndRequireAnOpenDocument`
- `NeoMDTests/DocumentFindSessionTests/findQueryAndPresentationSurviveRefreshButNotANewDocument`
- `NeoMDTests/DocumentFindSessionTests/stepWrapsAndRefusesEmptyMatches`

## Required pure additions — provisional names, not existing selectors

Worker supplies actual names and inspectable bodies before including them in an allowlist. Triage did not write executable tests.

- `DocumentSelectionProjectionTests`: structured document-order fragments, whole and partial/reversed cross-leaf extraction, TAB/LF table/metadata joins including empty cells, exact code indentation/trailing newline, hidden-vs-literal syntax, visible labels/fallback text, attachment atomic selection with zero copy characters, all-space inline code. Consume independent JSON strings, not expectations generated by the implementation under test.
- `DocumentSelectionRangeTests`: grapheme-safe UTF-16 caret/range boundaries; logical ranges spanning unmounted content; immutable fake registration records for mount/remount, stale-token/detach and two-reader isolation; no native views or selection actions.
- `DocumentSelectionRefreshTests`: static before/after parse with shifted IDs and fresh cell addresses; exact endpoint re-derivation, new interior content, ambiguous/deleted endpoint clearing; failed refresh keeps old state; one-shot transfer scoped to new presentation; old-host cleanup cannot clear new command owner. No watcher, live file replacement or history writes.
- `DocumentAccessibilitySemanticsTests`: distinct adjacent lists, nesting/count/ordinal, empty/continuation tasks associated with descriptions, heading levels, link/image states, hidden content excluded and existing table structure preserved. These test data, not VoiceOver.
- New exact traversal method: code text + overflow, metadata parts, empty/whitespace cells and links, forward/reverse order; copied routing policy ensures reader Copy does not override a find/ordinary field editor.
- Pure native attribute conversion: thick focused-link underline/background survives without altering characters or #21 match decoration; not a view-rendering/appearance/action test.
- Find/selection coexistence values: query/step/dismiss cannot change a logical selection; selection revisions cannot change match ranges/cursor; metadata leaf-to-part offsets remain distinct from clipboard TAB/LF offsets; image-state remap updates both display mappings independently; overlap/removal yields separate find/selection decoration descriptors without attribute loss. Refresh preserves find query/bar/pending command while re-deriving selection with new IDs; stale acquisition/cancel values cannot clear a newer owner or busy token. These must be pure model/conversion tests, never calls to native highlight/selection/reveal methods.

**No clipboard-mutating test is planned or allowed**, including a private/named pasteboard. Do not invoke `copy`, `selectAll`, native movement or AX press in units as substitutes; inspect pure extraction/routing instead. Excluded after source inspection: `KeyboardTraversalTests/exactNativeChordAndClipboardFreeSelection` synthesizes NSEvents/invokes selection, and `weakIdentityGenerationDetachAndTwoOwnerIsolation` hosts NSWindows and drains lifecycle. Their names do not make them permitted. Other uninspected/native-host suites and all UI/E2E remain excluded. Existing tests are preserved, not weakened or deleted.

## Final-milestone evidence inventory — all DEFERRED/UNRUN

The fixture README lists expected user-owned observations, not executable current recipes: actual cross-leaf pointer and Shift selection, link-origin click-vs-drag, explicit Copy/Select All, native focus/scroll/overflow, metadata/table/image states, active find-field precedence, independent readers, refresh replacement and lazy remount, AX/VoiceOver ordering, menu discoverability, light/dark/reflow, and interacted source bytes/mtime. No agent interaction run is authorized by this document. No pure model or compile pass checks a full issue criterion automatically.

## Worker evidence slot

- Worker runtime / accepted base / exact tested head: **UNRUN**.
- Debug command, log, exit status: **UNRUN**.
- Exact existing/new selectors, method/case counts, failures/skips and fresh xcresult: **UNRUN**.
- Post-#21 source/base reconciliation: triage refreshed at `7217b46ac4d69b532dc67b944f2a45407e6f0570`; worker integration/gate head: **UNRUN**.
- Fixture/oracle corrections with triage/coordinator reconciliation: **NONE REPORTED**.
- Diff/whitespace integrity: **worker pending**; preserve intentional literal-code whitespace in `mixed.md` rather than normalize fixture bytes.
- Pointer/keyboard/clipboard/visual/AX/native menus: **DEFERRED/UNRUN**.
- Final user-owned milestone business acceptance: **NOT CLAIMED**.
