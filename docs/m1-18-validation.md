# M1-18 / #18 — performance validation and evidence boundary

Triage: **ACCEPTED implementation readiness**, exact main `7217b46ac4d69b532dc67b944f2a45407e6f0570`; runtime `openai-codex/gpt-6-astra/high`. No triage build, executable test, prototype, app interaction or GitHub edit. Fixtures are [small and inert](fixtures/m1-18-performance/README-fixture.md); generation is specified by [declarative recipe](fixtures/m1-18-performance/generator-recipe.json), not a committed megabyte file.

## Contract and authority

[Issue #18](https://github.com/redrossa/neomd/issues/18) has four criteria. [Performance baseline APPROVED](https://github.com/redrossa/neomd/issues/18#issuecomment-5642959225) resolves the [earlier hold](https://github.com/redrossa/neomd/issues/18#issuecomment-5629473661): this development Mac on macOS 26.2, first readable content for ~1 MB within 1 s excluding remote image downloads; #36/#38 deferrals extend to overlapping no-freeze criteria, not repairs here. This supersedes the stale hold wording in [M1-DAG-001](milestone-1-dependency-plan.md), not the original criterion evidence requirements. #14 remains deferred/open; no reviewer or interaction-test stage.

**Environment discrepancy:** triage observed Mac16,8 / Apple M4 Pro / 12 CPUs / 24 GiB RAM with macOS **26.5.1 (25F80)**, not approved 26.2. Worker records its actual environment and labels timing **nonbaseline/informational** unless the approved environment is actually available. Coordinator/user reconciliation is required before baseline-qualified acceptance. Do not infer that the approved baseline was changed, alter deployment targets or change the host OS to run a gate.

## Criterion map

| Criterion | Source assessment at triage | Planned permitted evidence | Native disposition |
| --- | --- | --- | --- |
| C1 1 MB/1 s first readable | GAP: no measurements; adapter renders leaves twice even without reachable footnotes (`CMarkBlockAdapter.swift:49-74`). Detached preparation/index already exists (`DocumentOpeningCoordinator.swift:126-133`; `DocumentReadSession.swift:4-18`). | Skip only the unnecessary no-footnote second pass; exact-size preparation measurements and semantic regressions. | First-readable/first-paint timing DEFERRED/UNRUN; parser timing is not a substitute. |
| C2 10 MB responsive/render or explain limit | GAP: no stress evidence. Flat arena/linear geometry and lazy roots exist (`MarkdownRenderDocument.swift:6-45`; `MarkdownContainerLayout.swift:60-199`; `DocumentReaderView.swift:193-234`), but reads and native leaf size are unbounded. | Retain full rendering; generate 10 MB report/unbroken/code and verify full content, anchors, indexes and teardown. Record timings. No undocumented truncation or invented limit. | Interface/scroll responsiveness DEFERRED/UNRUN. New failure blocks; only known overlapping #36/#38 hangs carry the explicit deferral. |
| C3 unbroken text/large code/missing assets do not freeze | GAP for no-freeze evidence; existing highlighting budget and async fallback foundations are ALREADY_SATISFIED by source (`CodeSyntaxHighlighter.swift:30-47`; `MarkdownImageLoader.swift:15-38`; `MarkdownImageStore.swift:19-60`; `MarkdownImageParagraph.swift:87-100`). TextKit whole-leaf layout remains synchronous (`MarkdownLinkedImageText.swift:234-241`). | Whole-scalar retention, budget boundary tests, injected pending/failing/cancelled asset state, no network calls. | Native leaf/code/resize/large-size behavior DEFERRED/UNRUN; #36/#38 remain open, not fixed or passed. |
| C4 offline text/styles/local assets | ALREADY_SATISFIED by architecture: local parser and system styles (`MarkdownBlockRenderer.swift:119-127`; `ReaderTheme.swift:32-88`); local decode (`MarkdownImageLoader.swift:15-24,40-65`). | Offline-control parsing and copied local SVG decode; owned-copy bytes/mtime unchanged. Existing local format decode units. | Real offline rendering/appearance/AX DEFERRED/UNRUN; no networking or appearance toggles allowed. |

## Worker scope

Only expected production change is the no-reachable-footnote fast path in `NeoMD/Rendering/CMarkBlockAdapter.swift`: keep authored anchors, heading slugs, metadata/table structure, comments, inline attributes, code bytes and image identity unchanged. If reachable occurrences exist, preserve the complete existing generated-anchor second pass. Preserve the cmark global parsing lock. No planned DocumentReaderView/native selection/table surface, Documents opening/routing, refresh/history, theme, image transport, project/security settings or dependency changes.

#16 owns reader/native selection seams; #17 owns opening/read/recovery seams; #22 follows #16 and touches reading size/reader restoration. Coordinate narrow leases if evidence requires such edits rather than silently broadening this plan. No new semantic prerequisite. The catalog update is insertion-only; coordinator reconciles/re-hashes changed bases.

## Inspected existing non-interaction allowlist

Every listed suite/method body was read at the exact base. These are allowed selectors, not a command to run the whole NeoMDTests target. Use exact Xcode `-only-testing:NeoMDTests/<suite>` or method selectors shown below; record discovered/executed nonzero counts, not only exit status.

Whole suites (all methods inspected, parser/value/numeric model only):

- `NeoMDTests/CMarkDocumentTests`
- `NeoMDTests/CMarkParityTests` — includes `concurrentParsingPreservesExtensions`; run separately from timing samples because it deliberately contends the global parser lock.
- `NeoMDTests/MarkdownFootnotesTests`
- `NeoMDTests/CodeSyntaxHighlighterTests` — existing 1 MiB scalar fallback is not the new decimal-MB benchmark.
- `NeoMDTests/DocumentContentLocatorTests`
- `NeoMDTests/MarkdownTableRenderingTests`
- `NeoMDTests/MarkdownContainerLayoutTests` — fixed supplied numeric measurements, no native leaf measurement; not scroll proof.
- `NeoMDTests/DocumentRefreshStateTests` — logical clock/state, no presenter/event callbacks or observing host.

Exact individual methods only:

- `NeoMDTests/MarkdownFrontMatterTests/metadataAndRecoveryArePlainNonemptyLeadingLeaves`
- `NeoMDTests/DocumentFindIndexTests/fixtureCasesMatchAuthoredCounts`
- `NeoMDTests/DocumentFindIndexTests/matchesFollowLeafOrderAndCursorSteps`
- `NeoMDTests/DocumentFindIndexTests/hiddenCommentsMarkupURLsAndImageAltNeverMatch`
- `NeoMDTests/DocumentFindIndexTests/metadataMatchesStayInsideOneKeyOrValue`
- `NeoMDTests/DocumentFindIndexTests/rangesAreUTF16AndComposedCharacterSafe`
- `NeoMDTests/MarkdownImagesTests/systemFormatsDecodeConcurrentlyAndVectorsKeepNaturalSize` — local data/system decoder only, no view/window host.
- `NeoMDTests/MarkdownImagesTests/resetRejectsOldSameURLLoadsAndReleasesStore` — injected in-memory gate/observable state only; no real HTTP.

Do **not** select all MarkdownImagesTests: `loaderClassifiesMissingInaccessibleUndecodableAndUnavailable` includes a real loopback URL request and is not needed here. Do not select native hosting/navigation, linked-image feasibility, clipboard, window, event, AX or UI test suites. Broad NeoMDTests, NeoMDUITests, E2E/manual scripted interactions and host/event substitutes are prohibited. No heartbeat/NSRunLoop responsiveness surrogate.

## New non-interaction tests to author (not present or run at triage)

Proposed `NeoMDTests/MarkdownPerformanceTests` must contain only the following pure/injected responsibilities. Worker confirms exact names and selector discovery in its evidence:

1. `generatedCorporaHaveExactBytesAndCompleteContent`: declarative recipe helper generates report/unbroken/code at 1,000,000 and 10,000,000 bytes; assert bytes, whole long payload/code literal, heading/section/table/terminal retention, valid arena IDs/edges/subtree/lazy-root/index targets and sentinel find. Iterate sequentially; release prior arenas.
2. `noFootnoteFastPathPreservesSemanticControl`: offline-control and small report with no eligible occurrences; assert attributes/anchors/metadata/cell/image occurrence and comment exclusion; unused/disconnected/ineligible footnotes stay hidden/literal as appropriate. Existing reachable-footnote/collision/cycle/table regressions must still pass; add staged reachable-footnotes control coverage without altering second-pass semantics.
3. `largeCodeKeepsEveryScalarAcrossHighlightBudget`: limit-1/limit/limit+1 plus generated long code, plain above the existing limit and full content at every size; no native code layout.
4. `pendingAssetsDoNotGateTextPreparation`: inject suspended/failing loader into MarkdownImageStore, prepare offline-control off-main while pending, assert end text and loading state, then failure fallback; reset and stale completion must not publish. Release every continuation and cancel owned tasks; no real URLSession, server, window, events or UI work.
5. `localAssetsLoadWithoutChangingOwnedFixtureCopies`: copy small inert Markdown/SVG to a uniquely owned temporary directory; loader reads local SVG as detached bitmap/natural size (64×32), nonexistent local path yields missing. Compare bytes and modification times before/after reads; remove only owned temporary files. Do not chmod/read/write user sources or toggle network settings.
6. `recordsPreparationMeasurements`: isolated serial measurement selector described below. No hard 1 s assertion on ambient CI/Debug timing; hard correctness assertions still apply. Test is NOT a first-paint test.

The worker authors executable tests/helper; triage supplied only inert content and a recipe. If any test implementation introduces a host/event/network seam, it is outside this allowlist and needs coordinator correction before running.

## Timing protocol

Use generated UTF-8 Strings made before the timer. Detached monotonic-clock stages: (A) `MarkdownBlockRenderer.render` including YAML + parse + adapter + arena + parser teardown; (B) `DocumentContentIndex`; (C) `DocumentFindIndex` build/sentinel search separately. A+B is real preparation/index scope. Find is constructed only when requested in production (`DocumentReaderView.swift:408-429`), so A+B+C is an optional **extended** figure, not a reason to make opening eager. Do not add a standalone parse duration twice.

For each corpus/size, record first/cold-in-process sample and five serial warm samples, stage/raw durations and min/median/max, source SHA-256, byte/scalar/node/root/leaf counts, exact code head and Debug settings. Measure pre/post change with identical fixtures/configuration where feasible. Capture actual macOS/build, hardware/RAM, Xcode/Swift, load and power/thermal caveats. Use one coordinator-granted Xcode/timing slot and do not overlap parser-contention units. Do not promise a physically cold disk/cache or controlled thermal state without evidence.

Record the soft comparison `budgetSeconds=1`, `overBudget` and all samples. Native 1 s target is unchanged. A timing warning is not a flaky unit failure or permission to omit it: repeat clearly excessive results in an isolated batch, retain all evidence and escalate consistent preparation over-budget findings. A failed permitted unit, new stress hang/resource failure or confirmed defect blocks worker completion. Do not silently choose a new size cap, loosen target, drop cases, suppress errors or count interrupted runs as passes. If a broader optimization/size-limit design is necessary, obtain refreshed triage/coordination before changing contended seams.

## Commands and worker evidence — UNRUN

Run only after worker implementation, with unique external DerivedData/log/xcresult paths and the coordinator's exclusive Xcode slot. No machine-specific output is committed.

- Debug build: `xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug -destination 'platform=macOS' -derivedDataPath <owned-external-path> build`
- Functional units: same project/scheme/Debug/destination, fresh result bundle, explicit `-only-testing:` flags from above, then `test`.
- Timing: separate invocation with `-only-testing:NeoMDTests/MarkdownPerformanceTests/recordsPreparationMeasurements`; retain all samples, no concurrent workload. Adjust a proposed method selector only to its actual discovered worker-authored equivalent and document the correction.
- Check changed-source diagnostics before build; `git diff --check`; no reviewer or duplicate coordinator test stage.

Worker fills: exact validated HEAD and integration base; commands/configuration/environment; nonzero selected/executed/pass/fail/skip counts; log/result paths; generated corpus and helper hashes; before/after raw timing table and soft-budget disposition; baseline mismatch resolution if any; corrections to fixture oracles; confirmed remaining defects. At triage **all these results are UNRUN**.

## Final acceptance remains user-owned

Keep issue C1-C3 unchecked absent actual complete evidence; source/model evidence does not establish native C4 use either. The [fixture packet](fixtures/m1-18-performance/README-fixture.md) supplies a future human recipe, not current interaction authorization. All native first paint, scroll, size/reflow, selection, AX/VoiceOver and combined find/refresh/history behavior is DEFERRED/UNRUN. Preserve #36/#38 original failures; their extension does not prove a shared cause or waive final repairs/business acceptance. Do not close/accept milestone 1 from worker gates.
