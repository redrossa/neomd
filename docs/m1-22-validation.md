# M1-22 — Reading-size validation map

Triage: **ACCEPTED implementation readiness** on canonical main `cc9c3ddc7653dc35e8e8b03e16c9dc78cf2ceab2`, verified `openai-codex/gpt-6-astra/high`. No builds/tests/prototypes or app interactions were run in triage. Native outcomes are **DEFERRED/UNRUN**, not passed by this document.

Authority: [issue #22](https://github.com/redrossa/neomd/issues/22), [Reading-size policy APPROVED](https://github.com/redrossa/neomd/issues/22#issuecomment-5642959310), [M1-DAG-001](milestone-1-dependency-plan.md). The approval resolves persistence and overlapping #38 size-change reflow hold; keep #38 unresolved for final validation, #36 equivalence unproven, #14 deferred/open. No reviewer or interaction gate. #19 tables merged/implementation accepted before this triage; #23 locator and #24 separate history are also merged.

## Contract and evidence boundaries

| Criterion | Worker implementation/pure evidence | Final native evidence — all DEFERRED/UNRUN |
| --- | --- | --- |
| C1 native menu/shortcuts increase/decrease/reset; no window buttons | Bounded 1/1.5/2 command-state policy, endpoint validation and source inspection of AppKit selectors/equivalents | View menu, responder dispatch, Command-plus/minus/zero and equals alternate from reading/native text/find focus; no added window controls |
| C2 hierarchy/usability for headings/prose/code/lists/tables | Existing semantic theme, pure native attributed-font conversion and finite table/container geometry at each supported size; unchanged characters/formatting/table addresses | Actual font hierarchy, wrapping, local overflow, cue/metadata/table readability in Light/Dark at 900/480; selection and AX integration |
| C3 approximate position; no source mutation | Locator capture/resolve and ordering/generation/busy-state tests; unchanged prepared UUID/text/index; owned temporary-file byte/mtime comparison around model command operations | Real scroll preservation for top/middle/nested/table/bottom, rapid commands/user intent/find/refresh/reopen; actual source bytes/mtime after interactions |
| C4 approved app-wide remembered size | Isolated UserDefaults suite reload, shared service/two model consumers, new reader initial value, reset/corrupt input; no size field in source/history | Two real reader windows, replacement/open, normal quit and actual relaunch persistence; clear-history does not clear size |

Public supported sizes remain exactly **1×, 1.5×, 2×**, default/reset **1×** (existing bounded engineering policy, not an unapproved proposal). Saturation does not wrap. App-wide choice applies to existing/new readers with independent reading locators. File contents, parser input and prepared presentation identity do not change just to resize text. Preference persistence uses UserDefaults, never reading-history records or source files.

## Inspected existing non-interaction allowlist

The original nine suites and the additional container selector below were inspected for the prior accepted packet; their files are byte-identical between c672c090 and this refreshed base. The four find/selection suites added below were read in full during this refresh, including helpers. They use render/value/state calculations or native attributed-string/font conversion without creating native views/windows, synthesizing events, performing AX actions or modifying the clipboard/appearance. Importing AppKit/SwiftUI is not in itself interaction evidence. Reinspect any suite whose source changes on the worker's refreshed exact base; do not assume newly added methods are allowed.

- `-only-testing:NeoMDTests/ReaderThemeTests` — seven inline-policy/font/underline/character-preservation functions.
- `-only-testing:NeoMDTests/FontPolicyParityTests` — one font resolution/CoreText/native attributed conversion function, no native host.
- `-only-testing:NeoMDTests/DocumentContentLocatorTests` — eleven locator/index/content identity/edge/fraction functions; fixture reads only.
- `-only-testing:NeoMDTests/DocumentReaderLayoutTests` — six pure column/anchor/offset/restoration generation functions.
- `-only-testing:NeoMDTests/DocumentRefreshCommitTests` — eight session/ticket/capture/remap functions; `Task {}` does not host a UI.
- `-only-testing:NeoMDTests/ReadingHistorySessionTests` — five model-only restoration/observer/priority functions; no real history storage.
- `-only-testing:NeoMDTests/MarkdownTableLayoutTests` — ten pure geometry/action/token/descriptor functions; numeric measurements supplied, no views instantiated.
- `-only-testing:NeoMDTests/MarkdownTableAddressTests` — six pure cell/header/generation functions.
- `-only-testing:NeoMDTests/MarkdownTableRenderingTests` — seven parser/arena/fixture functions, no image loading or hosted cells.

These nine suites retain **61 test functions before parameter expansion**. Add these relevant merged-seam regressions, inspected at the refreshed exact base:

- `-only-testing:NeoMDTests/DocumentFindIndexTests` — six parser/index/UTF-16/native attributed-projection functions; in-memory NSImage is conversion data, not a native host.
- `-only-testing:NeoMDTests/DocumentFindSessionTests` — three model request/refresh/cursor functions.
- `-only-testing:NeoMDTests/DocumentSelectionStateTests` — seven value scope/registration/operation/refresh/find-independence functions; “fake mounts” are value tokens, not views or event simulation.
- `-only-testing:NeoMDTests/DocumentSelectionProjectionTests` — six pure text/slice/Unicode/attachment/table-join functions, fixture reads only.

The resulting 13-suite allowlist has **83 functions before parameter expansion**; that is source inventory, not an execution count. No blanket authorization for DocumentSelectionIntegrationTests or any native host suite is implied. Record actual runner counts rather than inferring them. A targeted additional regression selector, if needed for container geometry, is `-only-testing:NeoMDTests/MarkdownContainerLayoutTests/shallowQuoteTaskFootnotePreservesWidthsAndBaselines` (read; numeric measurements only). The new size suite should supply scale-specific container assertions rather than broadening to deep stress tests gratuitously.

## Planned new units — worker must implement and inspect; NOT existing/passed selectors

Suggested names: `NeoMDTests/ReadingSizePolicyTests`, `NeoMDTests/ReadingSizePreferenceTests`, `NeoMDTests/ReadingSizeRestorationTests`, `NeoMDTests/ReadingSizePresentationTests`. Names are a concrete suggested organization, not a claim these symbols exist. Update this map to actual selectors before claiming a gate. Every helper must remain non-interaction.

1. **Policy**: consume `fixtures/m1-22-reading-size/policy-cases.json` or equivalent checked independent assertions; all nine transitions, endpoints/no redundant changes, reset, supported order; menu-enabled state represented as plain values for missing/closed/unprepared reader. Test rejected input kinds, including nonfinite and Boolean values, not only valid doubles. Do not construct NSMenu, NSWindowController or send selectors/events as a substitute for native tests.
2. **Preference**: inject unique `UserDefaults(suiteName:)`, initialize/clear only the owned suite, clean it in defer. One size key, valid round-trip through a newly created preference object, reset to 1, malformed values default safely, no unwanted writes at endpoints. Two model consumers share current preference; fresh consumer starts with it. No `UserDefaults.standard`, real bundle-domain deletion, app relaunch, NSDocumentController, native menus, real history service or windows. A reload unit is NOT relaunch proof. Pure preference/storage dependencies must accept no Markdown URL or file writer. Verify unrelated defaults remain intact.
3. **Restoration/model state**: unchanged presentation UUID/text/index/content digests across scale changes; same-index locator round trips for AMBER, nested CHARLIE and JADE table cell at 0/0.25/0.65/1 plus top/bottom. Two sessions keep distinct captures with shared desired size. Ensure prepare-before-apply ordering, pending anchor retained across 1→1.5→2→reset, generation supersession, latest-size coalescing during busy work, cancellation by newer navigation/scroll, presentation replacement/close rejection and no stuck refresh-busy flag. Preserve preexisting history/refresh restoration until a valid scale transition can reuse it; no consume-then-drop or initial-top overwrite. Test real production value/session seams, not a fake view simulator or sleep-driven host proxy.
4. **Presentation**: loop the supported policy values through ReaderTheme and native attributed conversion; compare to independent baseline semantic font sizes × scale (not outputs derived from the same calculation), retain weights/monospacing/script offsets and exact character/code indentation/link/intent data. Cover heading levels 1–6, body, code, list/quote/alert metrics, table headers/body/minima/padding/rows and fixed outer viewport width with local overflow. Existing table structure/associations remain identical. Use font objects/attributed strings/numeric geometry only; no NSTextView, NSHostingView, layout display, window or screenshots.
5. **Merged selection/find reflow regressions**: keep the same DocumentSelectionState/projection presentation and logical endpoints on attribute-only conversion across all three scales; verify current slices/copied text (including code and row-major table separators), remount registration authority and image source/display correspondence. For width/scale-dependent depth captions, re-derive projection membership and verify a removed endpoint clears rather than jumps; ordinary endpoints remain. Use pure state/projection/numeric container geometry, not DocumentSelectionController/native mounts. Keep find query/matches/cursor/source UTF-16 ranges unchanged across size conversions, including metadata part offsets and images; test production ownership policy that incidental viewport change cannot let an existing find highlight preempt size restoration, while a new find command can supersede it. A dragging selection/acquisition/find reveal queues size until idle; an idle selected range/find bar does not. Test consume-before-busy guard retains requests and an idle retry consumes once, with explicit newer intent invalidating obsolete requests. No temporary-attribute display or scroll simulation claim.
6. **Source immutability model regression**: read fixtures in memory or copy to a unique temporary directory owned by this unit, snapshot Data and modification-date resource value, call only pure/model scale paths, compare exact bytes/date and dispose own copy. No actual app open/scroll/close sequence. Production source path must have no write dependency. Legitimate reading-history locator updates are separate; no size field in its envelope/record/locator.

## Later worker gate commands — NOT executed by triage

Run from the worker's isolated exact-head checkout with a coordinator Xcode lease and unique external DerivedData, logs and result path. Use proactive LSP diagnostics before build; a missing/broken language server does not replace xcodebuild evidence. Preserve deployment/signing/security settings.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:NeoMDTests/ReaderThemeTests \
  -only-testing:NeoMDTests/FontPolicyParityTests \
  -only-testing:NeoMDTests/DocumentContentLocatorTests \
  -only-testing:NeoMDTests/DocumentReaderLayoutTests \
  -only-testing:NeoMDTests/DocumentRefreshCommitTests \
  -only-testing:NeoMDTests/ReadingHistorySessionTests \
  -only-testing:NeoMDTests/MarkdownTableLayoutTests \
  -only-testing:NeoMDTests/MarkdownTableAddressTests \
  -only-testing:NeoMDTests/MarkdownTableRenderingTests \
  -only-testing:NeoMDTests/DocumentFindIndexTests \
  -only-testing:NeoMDTests/DocumentFindSessionTests \
  -only-testing:NeoMDTests/DocumentSelectionStateTests \
  -only-testing:NeoMDTests/DocumentSelectionProjectionTests test
```

Add the **actual newly implemented and inspected** pure size selectors to the selected unit run; the existing regression command alone does not verify new behavior. Record nonzero functions/runs, failures, skips and command exit codes from xcresult/logs. A zero-test run, filter typo or skipped suite is not evidence. Reconcile current main and rerun permitted gates on the resulting exact head before integration. Coordinator integrates using worker evidence, no duplicate reviewer stage.

Explicit exclusions: whole `NeoMDTests`, `NeoMDUITests`, window/controller/NSHosting/NSTextView probes, synthetic or physical app events, menu invocation, clipboard mutation, appearance switching, AX queries/actions, manual scripted scrolling/opening/relaunch, benchmark scripts and existing #36/#38 reproduction tests. Do not run old UI commands just because a historical document contains them. #38 reflow overlap is deferred rather than a pre-merge gate; unrelated known defects or failures in permitted gates still block and must be escalated.

## Deferred final packet

[Reproducible inert fixtures and future user recipe](fixtures/m1-22-reading-size/README-fixture.md) cover both documents, all supported sizes, both appearances/widths, menu focus contexts, approximate content anchors, rapid changes, refresh/find/selection/relaunch and before/after source integrity. This is future user-owned testing, not permission to run it now. Do not mark original C1–C4 complete from parser/model tests alone; preserve reduced implementation acceptance versus unverified native outcome.

## Worker evidence — UNRUN at triage

- Implementation PR / actual runtime: pending.
- Exact validated source head and integration base: pending.
- Debug command / exit / external log: UNRUN.
- Existing/new unit selectors and source inspection: pending.
- Actual functions / expanded runs / failures / skips / external xcresult: UNRUN.
- Staged artifact installation / hash corrections / catalog reconciliation: pending.
- Known defects: #38 overlapping larger-size reflow deferred; #36 equivalence unproven; no new defect diagnosed by source triage.
- Native menu/key/scroll/visual/AX/relaunch/source-interaction observations: DEFERRED/UNRUN.
- Final milestone business acceptance: user-owned, not granted.
