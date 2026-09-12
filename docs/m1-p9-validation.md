# M1-P9 / #65 — momentum-scroll repair validation

Refreshed triage base: `445ed2b897934d339eb01b750d37b03edf392dce` after #64 / PR #66; supersedes predecessor `1738b1d2e9e7f74411f0d63e4aab401c1522109b` for dispatch.
Issue: https://github.com/redrossa/neomd/issues/65.
Runtime verified: `openai-codex/gpt-6-astra/high`.

**ACCEPTED for bounded source-backed implementation; native cause and outcome remain unconfirmed.** No triage build, test, prototype or interaction was run. The reported upward trackpad flick stops abruptly; Command-Up/Home has not been tried. The accompanying fixture is not a demonstrated reproduction of that report.

## Scope / oracles

Separate passive geometry/frame/anchor observations from view-driving command state; prevent automatic viewport restoration/existing-find reveal from taking control during tracking/interacting/decelerating. Preserve explicit navigation/size/refresh/history, lazy roots, native selection, margins and local overflow. There is no app-owned estimated-height table to stabilize at this base. Do not replace the lazy stack, clamp during passive observation or infer a history restoration from capture.

Source evidence: `DocumentReaderView.swift:38–43,372–432,824–914`; actual layout `MarkdownContainerLayout.swift:215–247`; capture/request separation `DocumentReadSession.swift:168–184,226–232`. Automatic viewport restoration currently lacks a user-scroll guard, while ordinary geometry capture has no scroll call. Full root-cause evidence and implementation boundaries are retained in the external triage DESIGN/HANDOFF packet.

## Refresh integration boundaries

PR #66 leaves reader capture/restoration, session/history/size and numeric layout unchanged. Its owner-scoped selection tracking now survives origin unmount and token-gates finish; its native layout manager shares only the current reader's responder predicate. Preserve `selection.interaction`, `selection.dragging`, operation lifetime, native find attributes and bridge `isOwned`/`ownsSelectionScroller`. Scroll-idle is not selection-idle. Do not release refresh/queued size while drag or other interactive work remains; do not gate restoration on its own busy counter.

Refresh includes the stale detached-find seam: `runFind` may return unchanged-query results after a newer scroll, so automatic reveal authority must be checked after that await, not only when starting viewport restoration. Keep valid results/highlights separate from permission to scroll; preserve new explicit find/navigation commands. Recheck generation, user ownership and current/open presentation at each post-delay scroll boundary, including after phase returns to idle. These are bounded reader changes, not authorization to modify #64's native implementation.

The existing four P9 suites were reread at this base. Two precise pure #64 methods below add busy/operation preservation coverage; they are not a native-selection regression run. The catalog now contains P8; install the insertion-only P9 payload only against its refreshed destination hash and preserve P8 byte-for-byte.

## Permitted worker gates

Run from the worker's isolated exact-head checkout. Obtain proactive source diagnostics before builds; sourcekit availability is not a substitute for an Xcode build. Use unique externally owned `P9_DERIVED_DATA`, `P9_RESULT`, and log paths; serialize Xcode use with the coordinator.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$P9_DERIVED_DATA" build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$P9_DERIVED_DATA" -resultBundlePath "$P9_RESULT" \
  -only-testing:NeoMDTests/DocumentReaderLayoutTests \
  -only-testing:NeoMDTests/ReadingSizeRestorationTests \
  -only-testing:NeoMDTests/DocumentRefreshCommitTests \
  -only-testing:NeoMDTests/ReadingHistorySessionTests \
  '-only-testing:NeoMDTests/DocumentSelectionPointerTests/unmountAndStaleTokensDoNotFinishSuccessor()' \
  '-only-testing:NeoMDTests/DocumentSelectionPointerTests/ownerInvalidationAndBusySizeQueueAreTokenBound()' \
  -only-testing:NeoMDTests/DocumentReaderScrollPolicyTests test
```

`DocumentReaderScrollPolicyTests` is a **proposed new suite**, not an existing passing selector. Implement it (or record the exact renamed suite/individual methods after inspecting their bodies) before executing the command. Verify every selected suite executes with nonzero counts; a zero-test selector is not evidence. Preserve actual failures/skips. No retry/restart/skip may turn a failure into a pass.

### Inspected existing suite allowlist

- `NeoMDTests/DocumentReaderLayoutTests`: six pure sizing/anchor/generation tests; CoreGraphics/Foundation values, no native host.
- `NeoMDTests/ReadingSizeRestorationTests`: seven tests of in-memory preferences/session/restoration and an owned temporary Markdown file byte/mtime check. `ReadingSizePreference()` uses nil/in-memory defaults. No menu, event, window or real preferences/history.
- `NeoMDTests/DocumentRefreshCommitTests`: eight parser/session ticket, capture, remap and quiet-status tests. No window, host, event or filesystem access.
- `NeoMDTests/ReadingHistorySessionTests`: five parser/session/capture-observer tests; no real history service/storage or opening interaction.
- `NeoMDTests/DocumentSelectionPointerTests/unmountAndStaleTokensDoNotFinishSuccessor()`: pure projection/state/operation tokens; origin unregister does not finish a current operation, stale finish cannot end a successor. No native mount/event/host.
- `NeoMDTests/DocumentSelectionPointerTests/ownerInvalidationAndBusySizeQueueAreTokenBound()`: pointer lifetime Boolean policy plus in-memory preference/reflow queue. No actual window, drag, preference persistence or clipboard.
- Thus **28 existing test methods** are selected before worker-authored policy tests (26 unchanged P9 methods plus two exact #64 methods). Verify actual xcresult executions; do not infer that count from selector acceptance.
- Optional **only if numeric container layout changes are separately justified**: `NeoMDTests/MarkdownContainerLayoutTests`, five declarations including parameterized large-depth numeric geometry. Inspected bodies use synthetic measurements/parser values, no native layout host. This is not required for the intended reader-only patch and does not authorize container changes.

Do not run broad `NeoMDTests`, `NeoMDUITests`, `DocumentNavigationBridgeTests`, `DocumentSelectionIntegrationTests`, presentation/host suites or uninspected native-text tests by analogy. No UI/E2E/manual scripted flows, real/synthetic NSEvents, NSWindow/NSHostingView probes, AX actions, clipboard mutation, screenshot automation or app-launch substitutes. Ordinary Xcode unit-test hosting is not authorization to construct/drive native surfaces inside tests. No scratch reproduction was performed by triage.

## New non-interaction expectations (worker-authored, not yet run)

Wire the value policy to production callbacks; a parallel unused model does not validate a repair. New tests must use scalars/rectangles/phase values and injected counters only, never fabricate an event stream or host a ScrollView.

1. `passiveGeometryKeepsLatestCoordinatesWithoutCommands`: feed unchanged-viewport offset/content-height changes, including upwards progression and estimate expansion/contraction. Latest metrics/frames are retained; automatic restore/reveal decisions and command counters remain zero. Equal snapshots do not produce duplicate work. This asserts the app policy, not actual LazyVStack estimates.
2. `userPhasesRejectAutomaticViewportRestoration`: tracking, interacting and decelerating with a changed viewport and old find highlight never issue automatic old-anchor/find commands. Include deceleration arriving without an observed interacting callback. Idle resize remains eligible; programmatic animation is distinguished from user takeover.
3. `userTakeoverInvalidatesDelayedPasses`: schedule restoration/automatic find correction, transfer ownership to the user, then inspect stale generations before/during deceleration and after idle. The old pass stays invalid; idle does not resurrect it. Include detached find-search results arriving with unchanged query after newer scroll/explicit navigation, and closed/replaced presentations. Valid results may remain usable but issue no stale reveal. A genuinely newer explicit find/section command obtains fresh authority and is still interrupted by a subsequent user scroll. Keep the existing exact-anchor and generation assertions.
4. `idleReconciliationPreservesQueuedExplicitRequests`: size/history/refresh requests remain presentation scoped and blocked while active; when eligible they are consumed once under existing precedence. An explicit section or new user scroll wins. Do not cancel intended programmatic scrolling merely because phase is animating. Add `selectionBusySurvivesScrollIdle`: a current owner operation and interactive work still block refresh/queued size despite scroll-idle; origin unmount/stale finish cannot release them. After current operation finish and all other work drains, latest queued size reconciles once using the latest user anchor. Do not instantiate a native selection controller with real mounts or simulate its event loop; use production-wired values and inspect callback balance.
5. `passiveCacheRetainsIdentityAndSemanticAnchor`: two references to one non-observable per-reader cache see latest values without replacing the cache object; separate reader caches do not leak. No delayed callback uses superseded frames. Preserve the last pre-resize semantic anchor when frames arrive before viewport metrics, and latest user anchor after idle.
6. `captureNeverRequestsRestoration`: accepted in-memory locator capture updates observer/captured position, but leaves `readingPosition`, section, generation and synthetic command counter unchanged. Include .top and a changing within-block fraction; no real persistence.
7. Preserve top/bottom, short-content, insets and distant-block math. Passive content-height changes do not trigger clamping commands; explicit page/restoration may clamp normally. Do not add a new guessed-height expectation.

The declarative `fixtures/m1-p9-scroll/policy-cases.json` supplies representative inputs and decision oracles. It is not executable. Code inspection of production wiring must additionally confirm that only the cache identity, not its changing metric/frame/anchor properties, is retained in SwiftUI `@State`; pure tests cannot measure SwiftUI invalidation counts or native momentum.

## Fixture and future user-owned native coverage — DEFERRED / UNRUN

`fixtures/m1-p9-scroll/mixed-heights.md` is inert local text: uneven prose/code/list/quote roots, heading anchors, no images or network. `README-fixture.md` gives an optional deterministic long-document assembly recipe and explains why it is not a proven reproduction. Do not edit the original user's Markdown source to create a test.

User-owned observations after an implementation build (not a worker script):

- Original failing document and fixture, starting in the middle/lower region: upward trackpad flick decelerates naturally rather than stopping well before the top; distinguish normal endpoint contact/rubber-banding from a freeze or jump. Compare downward travel and repeat upward travel through newly seen versus previously seen roots.
- Record file/fixture hash, approximate starting heading, reading scale, window size, find visibility, and whether images/external writes were in play. The initial report does not contain those details.
- At actual 1×/1.5×/2× and narrow/wide widths, retain initial top margin, readable content, approximate position on explicit resize/size command and local code/table overflow. Applicable historical #36/#38 hangs remain failures/deferred, not repaired by assertion.
- Explicit fragment/footnote/top navigation, selection/traversal, find reveal, reopen history and settled refresh still work and stop fighting a newer user scroll. Find bar visibility and refresh-status overlay are distinct cases. No real external write is needed for the worker model tests.
- Separately observe Command-Up/Home with the current responder; these were untried, and Home inside code may be local horizontal navigation. Do not report keyboard behavior as evidence of trackpad feel.
- Confirm document bytes/mtime remain unchanged. Native selection, focus, AX/VoiceOver, resize/appearance and combined milestone behavior remain user-owned.

No source/unit result proves smooth native deceleration or resolves the earlier reported “OnScrollGeometryChange multiple updates” warning. If the symptom persists, return original/sanitized reproduction details and observed geometry/phase/request evidence for new triage; do not silently broaden this repair. #65 must not be declared fixed from model gates alone. #14/#36/#38 deferrals and all historical failed/incomplete evidence are unchanged; no new waiver is granted.

## Worker evidence slot

- Exact tested head / integration base: **UNRUN**.
- Debug command/log/result: **UNRUN**.
- Existing/new exact selectors, per-suite nonzero counts, failures/skips and xcresult: **UNRUN**.
- Production wiring / final diff / `git diff --check`: **UNRUN**.
- Artifact hashes checked, catalog insertion reconciled, any corrections: **UNRUN**.
- Native scroll feel / warning reproduction / #36/#38 / visual/AX/business acceptance: **DEFERRED / UNRUN**, not passed.
