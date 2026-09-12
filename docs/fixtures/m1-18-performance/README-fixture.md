# M1-18 performance packet

Inert, triage-owned fixtures at main `7217b46ac4d69b532dc67b944f2a45407e6f0570`. No generated corpus or timing result is committed. See [validation and allowed units](../../m1-18-validation.md). All native use is **DEFERRED/UNRUN** pending user-owned final validation; these instructions do not authorize agents to interact with NeoMD.

## Files and oracles

- `generator-recipe.json`: language-neutral byte-exact recipe. Worker implements a nonisolated deterministic Swift test helper, not triage. UTF-8/LF/no BOM; decimal 1 MB = 1,000,000 bytes, 10 MB = 10,000,000 bytes. Do not substitute repeated invisible HTML comments for visible report content.
- `report-section.md`: small template of heading/prose/task/quote/code/table leaves. Six-digit ordinals keep stable byte sizes. It intentionally has no reachable footnotes, exercising the safe no-second-pass branch. Hidden-comment decoy must not appear in visible text or find results.
- `offline-control.md`: local text/styles/cues, local SVG, absent local image, inert `.invalid` remote image, image-occurrence identity, table, literal code and end sentinel. Read it as data, never follow its URLs during units. Copy its SVG alongside it when generating future temporary packets. `absent.png` must remain absent.
- `reachable-footnotes.md`: repeated/cyclic/table references and authored collisions must still resolve after optimization; unreferenced text remains hidden. Assert generated links resolve to correct note/reference identities, not hard-coded generated spelling. Footnotes append after the authored end heading, so that heading is not the document's last visible leaf in this control.
- `local-diagram.svg`: original static 64×32 blue/orange rectangles; no script, linked external asset, embedded executable or network reference.

## Deterministic functional checks for the worker

Generate each report/unbroken/code corpus at both target sizes outside timing. Assert emitted byte count, start/end headings, all numbered report sections and terminal text, continuous preorder/valid parent-child/subtree/lazy-root relationships, finite index counts and index target validity. Check representative first/middle/last sections, table cells and code literals in addition to counts. Search START/END sentinels and confirm hidden decoy absent using `DocumentFindIndex`; image alt is deliberately excluded from that search by #21.

For unbroken text, compare the whole paragraph to the expected repeated payload, not just a prefix. For code, compare every literal scalar, indentation and newline to the expected generated body; above the highlighter budget token attributes are absent, not source bytes. Dispose each large rendering before the next corpus/repetition; do not retain all 10 MB generations to manufacture a memory stress unrelated to production.

Use only in-memory injected image completion/pending/cancellation, or read/decode owned local copies. Do not use real HTTP, loopback servers, OS networking toggles, windows, native layout/scroll probes, events, clipboard or accessibility actions. Generation/timing ownership and exact-head raw evidence are recorded in the validation document by the worker, not asserted here.

## Future user-owned native recipe — deferred, not performed

After explicit final-testing authorization, create external copies from the same recipe and record generator hash, corpus hashes, bytes/mtime, hardware/OS/Xcode/configuration and exact app head. On the approved baseline, observe first readable content of the report near 1 MB from opening until rendered content appears; record cold/warm trials with remote downloads excluded, without substituting parser timing. Read/scroll the 10 MB report, long paragraph and large code, noting full rendering or an actual documented readable limit. Check pending/missing assets never hide local text, and offline local text/styles/local SVG remain usable. Check bytes and mtimes unchanged afterward.

Carry #36 reflow and #38 larger-size hang scenarios and their existing blocked evidence unchanged. Native resize/scroll/selection/find/history/refresh combinations, 1×/1.5×/2×, both themes and VoiceOver remain user-owned deferred work. Any newly observed defect is recorded independently, not assumed covered by the extension. Do not count a hung, interrupted, skipped or restarted run as passing.
