# P9 internal-navigation fixture and setup amendment

Status: **ACCEPTED inert fixture amendment; geometry-oracle revision PROPOSED to coordinator, not approved or executed.** Only P9's two existing generic-scroll selectors and their common setup are affected. This additive document preserves the original plan, failed setup records and P8 repairs. No catalog replacement, app change, external-fragment product fix, new test hook or momentum claim is authorized here.

Research runtime: openai-codex/gpt-6-astra/high. Adopted main foundation 445ed2b897934d339eb01b750d37b03edf392dce; actual read-only implementation checkout HEAD dc9056c5a3b47f802bfb9bcc30688e14009753a1 plus dirty diff SHA-256 2760105dc002199633a26acf313c01b75432420c8cb65d0206f3095d974de645. Exact file hashes accompany the external handoff. This is a coordinator-authorized refresh of the in-flight P9 testing exception, not clean-main story acceptance.

## Why the setup must change

The retained fragment trace records NSWorkspace submission with #p9-top-4, but the actual application(openFiles:) filename lacks a fragment before URL reconstruction; coordinator explicitFragment and section are nil. There was no navigation request. A controller forwarding repair cannot restore metadata absent on this delivery path. Both earlier setup failures remain FAIL, before measured scroll: fraction 0 and heading top delta +40. Neither establishes a P9 momentum failure or fifth-copy identity.

## Smallest fixture change

Keep mixed-heights.md unchanged. Materialize a NEW priority-scroll-navigation.md from its exact eight-copy, one-extra-LF-between-copies recipe, then apply only these insertion-only amendments:

1. First copy: wrap the existing first AMBER in [AMBER](#p9-top-4). Its visible text, paragraph count and position remain unchanged. This ordinary in-document link is available in the opening viewport; no leading spacer, new root or guessed positioning is needed.
2. Fifth copy only: insert ` P9-FIFTH-ONLY` immediately after its first AMBER. The exact following paragraph identifies copy five independently of the repeated P9 top headings. All eight headings remain byte-identical, so p9-top-4 retains its original duplicate-slug meaning. No custom-anchor parser behavior is needed.

The inert recipe and equivalent two-hunk patch are triage artifacts, not executable generators/tests. Assemble the new static document once at worker integration, verify its final hash, then let the existing fixture helper copy it with copies=1. Do not compose it eight times again. Do not transform an already-open file or mutate a tracked source fixture. New output is 33,234 bytes, SHA-256 88f03d5174bff5835947df57964fbad1bffe23c471427520f3bf1ae83adfde09. Removing exactly the link markup and unique label restores the complete original 33,207-byte corpus/hash.

Preserved: all original words, eight complete copies, root order/types/count, heading levels/slugs, code bytes/line counts, emphasis, quotes, lists, horizontal overflow, end/top links, absence of network/images and read-only semantics. Only 27 UTF-8 bytes are added. The fifth paragraph may wrap one extra line: exact pixel-identical height is NOT claimed. Do not compensate by deleting prose/roots, shortening code or adding padding. Middle fraction and actual geometry must still pass under the real workload.

## One shared native setup path, including trial-two reopen

Worker-owned changes belong in PriorityScrollUITests.swift; leave shared PriorityInteractionSupport, selection tests and production untouched unless a separately justified lease is approved.

- Use the same common open/resize/reacquire/link-activation/gate helper from prepare() (therefore both tests) AND generic-upward trial two. Pass through the existing 1500 ms restoration-delay launch configuration unchanged.
- For every positioning invocation stage identical fixture bytes under a fresh run-owned URL, e.g. priority-scroll-0.md then priority-scroll-1.md. Use support.fixture with the new static fixture and copies=1, before opening, so its existing bytes/mtime bookkeeping covers every copy. Trial two replaces the current document with an identical newly named copy in the SAME owned reader; it does not test history restoration. A unique path prevents previous-trial history from hiding the launch link. Do not clear history/preferences or rely on reopening the old URL to reset its offset. This repeat remains through the same corpus region, but does NOT claim retained lazy-view materialization across document replacement; preserving that additional property would require a separately designed reachable return control, not a silent equivalence claim.
- Checkpoint the preceding window BEFORE replacement. Open the fresh URL without fragment through support.open; verify same owned PID/start/path/hash, original window membership/CFEqual, window count and new exact document identity. Do not checkpoint the old wrapper's former document URL after intentional replacement. Re-size only as necessary to 900x720. A bare same-URL reopen may retain the existing reconciliation step; both returned wrappers then refer to the new URL, so existing reconcile() can be retained unchanged.
- Reacquire the actual current XCUI window and PID-scoped AX window/document rather than reusing a stale wrapper. Prove unique reader and key owned window. Snapshot initial top position (scrollbar exactly 0 with successful AX reads), first heading and initial paragraph. Missing or offscreen launch link is a setup failure; no scroll-to-top, find, Home, repeated wheel calls or programmatic navigation fallback.
- In the reader, locate the unique initial link-bearing block whose authored native link-action value is `Link 1 of 2: AMBER` (MarkdownBlockView's existing accessibility value), then its exact initial paragraph text leaf. Repeated paragraph text alone is insufficient. Require successful finite AXBoundsForRange for AMBER's UTF-16 [0,5), verify range/position identity and a point strictly within its actual visible glyph rectangle and reader clip. Record link label/range, expected fragment from the hashed fixture, AX ownership/coordinates and any available native URL metadata. Perform ONE ordinary native XCUI click there, no modifier, no drag, no guessed text offset, no AX value setting, no direct handleLink/navigate/scrollTo invocation.
- After activation reacquire current window/AX/document using queries and axWindow, not another external open. Reconcile it to the current same-document wrapper, check key/window-count/process continuity, and use this newly verified wrapper for all later measurements. Missing link notices or extra/replaced windows fail setup.
- Start the existing 700 ms gate after the actual click. Keep original failure final: diagnostic-only late samples cannot enable measured input or retry. Preserve accurate sample start/end durations; synchronous AX reads are not exact 100 ms snapshots. One setup remains <=8 positioning actions and <=10 s; check monotonic deadline before/after each potentially blocking operation and fail before measured input if exceeded. Do not claim an in-flight synchronous call has a strict completion bound it cannot provide.

The fresh-URL approach is the smallest fail-closed way to guarantee a reachable launch link for trial two without adding return links throughout the document or guessing where three scroll gestures left it. It preserves workload and two-trial behavior assertions, but the materialization distinction above must be retained in results. If coordinator requires a same-presentation warm-layout repeat, this plan is BLOCKED on that additional requirement; do not quietly use fresh URLs and call it a warm-layout pass.

## Fifth-copy identity and real travel (mandatory, not just a fragment argument)

At the original gate require the exact unique target-following paragraph from fixture-recipe.json, role AXTextArea, finite successful rectangle, visible glyphs and correct reader ancestry. Find the single P9 top AXHeading immediately above it, not the first globally matched heading. Source LazyVStack spacing is 16 pt; require paragraph.minY - heading.maxY = 16 within the proposed 2 pt screen-geometry precision allowance. Require no intervening content and unique pairing; ambiguous/capped traversal, missing AX values, zero/nonfinite/fallback rectangles fail. Record the pair and continue tracking the same heading AX object for first scroll displacement, never rematch another copy mid-measurement.

Before click require initial fraction 0 and first-copy identity; after click require finite fraction STRICTLY >0.3 AND <0.7. Both actual native windows/readers and rectangles must agree. The unique fifth paragraph plus observed change from 0 to interior fraction demonstrates real middle positioning; submitted fragment/estimated height/target index alone does not. Failure permits no measured scroll. AX normalized fraction is not a pixel offset or content-height/NSClipView telemetry. Do not infer unavailable native channels.

## Geometry oracle: explicit coordinator decision, not a 40-to-50 workaround

The original predicate is abs(heading.minY - reader.minY) < 40. The real observed opening displacement is exactly +40, so it necessarily fails that predicate. Do not pretend this is rounding or use <=40 to conceal absent navigation.

Source separates three coordinates:

- DocumentReaderView applies 32 pt outer vertical padding (verticalMargin=32, lines 122 and 963); MarkdownBlockView adds 8 pt above a level-one heading (line 124). Their sum accounts for the observed +40 at an ordinary top-of-document opening. That observation is NOT a measurement of NSScrollView.contentInsets.top.
- The destination marker is attached to the TOP of the padded heading block, not to the glyphs (MarkdownBlockView lines 53-58). The native heading text frame starts 8 pt below this marker. MarkdownContainerLayout adds no extra root-heading offset.
- DocumentNavigationBridge.position (lines 275-299) aligns that marker to the native content inset I, after constraining bounds. DocumentReaderView.navigate converges using <=1 pt remaining error for three passes. Therefore at an unconstrained interior destination the expected marker delta is I, heading-frame delta is I+8, and the glyph delta is I+8+g, where g is the unchanged native glyph-to-text-frame displacement. Glyph bounds are not AXHeading frame bounds.

Consequently raw <40 is compatible with the expected interior heading only if I+8<40 (and actual measured geometry satisfies it). If I really is 40, the expected heading is +48 and raw <40 is impossible for correct placement. The existing trace did not measure I; do not equate the observed total opening +40 to I, or assume I=0 without qualification.

**Proposed independent AX-only placement oracle, requiring coordinator adoption before replacing the old predicate:** capture H0 (first heading frame), G0 (its P9 top UTF-16 [0,6) glyph bounds), C0 (reader), at verified initial top before activation. Same heading text/font/width and window size must hold after navigation. Predict BEFORE clicking:

- expected target heading delta E_H = (H0.minY - C0.minY) - 32;
- expected target glyph delta E_G = (G0.minY - C0.minY) - 32;
- inferred expected marker delta E_M = E_H - 8.

Require absolute residuals of target heading and target glyph against E_H/E_G <=2 pt, positive visible finite bounds, same native heading dimensions, unchanged reader geometry, unique fifth-copy pairing, and the unchanged strict middle-fraction gate. 2 pt is a proposed screen-geometry allowance (the bridge converges within 1 pt; two independently read screen rectangles can round), NOT 40 pt extra placement freedom. Calibrate before input, never derive expected values from the target's eventual position. At the observed ordinary opening H0-C0=40, E_H=8, not 40; the original <40 should also pass if this prediction holds. A genuine I=40 would yield a different initial baseline and predicted interior heading +48; this is exactly why raw heading-to-clip distance is not the invariant.

This oracle transfers an independently measured first-copy glyph placement using only the source-defined 32 pt DOCUMENT padding difference; it neither moves the app nor modifies layout. The inferred marker is source-derived, NOT directly observed: markers are accessibility-hidden, and AX cannot independently expose I. Record that limitation. If top clipping/insets or changing native geometry make this transfer unprovable, STOP for a separately authorized passive geometry observation. Do not introduce telemetry/hooks here, adapt E_H/E_G after failure, or loosen residuals until green.

Until adoption, retain and report the original raw <40 outcome separately; fixture approval alone does NOT authorize removing it. If correct product placement contradicts raw <40, return a coordinator proposal with H0/G0/C0, H1/G1/C1 and residuals, not an automated pass. Adoption of the residual invariant would be a documented test-oracle correction, not a product margin change or waiver of middle travel. No past failed run becomes passed.

## Existing measured assertions remain unchanged

Generic-upward: two trials; three deltaY=240 inputs, two 100 ms separations; first same-heading displacement >20; first/after/settled fraction below starting fraction; 2 s settle; same surviving native leaf settled displacement <=20.

Restoration: configured 1500 ms delay; resize only height +20, error <=3; actual input elapsed <1.5 s; movement >=80; 2500 ms wait; final-to-new <=20 and final-to-old >=60. Do not extend sleeps, change sign or thresholds, reorder pending-restoration timing, or use another setup gate after starting the measured resize. Native phases/pending generation remain unavailable unless separately authorized. Generic XCUI scroll is not physical trackpad momentum.

## Validation and evidence slots

Triage performed source/doc inspection and inert byte/hash calculations only. New interactions, builds, executable tests, parser executions and prototypes: UNRUN. Existing two failed setup records are retained. Static composition proof is not a parsed/native rendering result.

Later worker gates remain Debug build and previously accepted inspected non-interaction P9 units in m1-p9-validation.md. Additionally inspected here: NeoMDTests/MarkdownAnchorsTests/headingSlugs() uses only AttributedString and the pure slugger, suitable if fixture-anchor regression coverage is added; the existing test does not itself test this corpus. A new worker-authored pure parser fixture check may prove eight root sequences, fifth slug target and unique paragraph without a native host; triage authors no executable test. Do not run the complete navigation bridge/host suites by analogy.

Only after coordinator adoption/lease may the two existing exact PriorityScrollUITests selectors execute under their prior bounded exception. Native/AX/visual/physical trackpad verification and business acceptance remain DEFERRED/UNRUN. No GitHub issue/milestone criteria are checked here.

**Rebuild warning:** all disposable trace source was restored, but persistent DerivedData products remain instrumented. Before any acceptance invocation rebuild build-for-testing from the reconciled restored sources plus approved test changes; record source/fixture/product/dylib/xctestrun hashes and revalidate existing certificate requirements and entitlements. No resetting permissions, signing settings or global state. Preserve other dirty repairs and all retained evidence.

Worker completion slot: exact integrated head/dirty proof; materialized hash; oracle adoption decision; initial/final geometry and copy identity; test commands/counts/results/skips/timings; build/product identity and instrumentation state; original thresholds; bytes/mtime after exit; cleanup/process inventory; fresh-presentation trial-two limitation: all UNRUN.
