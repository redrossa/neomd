# M1-15 validation map — accepted readiness, implementation UNRUN

[Issue #15](https://github.com/redrossa/neomd/issues/15) · [plan](m1-15-content-plan.md) · [fixtures/future recipe](fixtures/m1-15-content/README-fixture.md).

Exact triage base: `f0bd08806013ae8cb4ac994676b30bbe19dc19f5`, clean detached checkout. Runtime verified `openai-codex/gpt-6-astra`, high, before original research and resumed triage. Live body/all four comments/milestone order read. [D1](https://github.com/redrossa/neomd/issues/15#issuecomment-5628830891) approves offline pinned libyaml event parsing; [D2](https://github.com/redrossa/neomd/issues/15#issuecomment-5628889673) approves delimiter precedence and literal recovery. Both earlier blockers are resolved. **ACCEPTED means feasible and ready for coordinator scope approval/worker handoff, not implementation or criterion verification.** No app/executable-test edit, build, test, prototype, app/browser interaction or GitHub publication was performed by triage.

## Authority and validation boundary

#52 completed; sequential #15–24 authorized, #15 next, #14 explicitly skipped/deferred/open. No reviewer. Worker gates are separate Debug app build and relevant NON-INTERACTION units only. No `NeoMDUITests`, E2E, manual scripted flows, native window-host probes, real/synthetic events, AX actions, picker, NSWorkspace launch, browser/remote image request, clipboard or system appearance operations. Do not select the entire `NeoMDTests` target: it includes host/event/native interaction suites. No silent permissions/signing/deployment/sandbox changes to make validation pass.

All native/visual/AX/VoiceOver and interaction evidence is **DEFERRED/UNRUN**, not passed. Unit assertions of text/row labels or configured style do not prove native reading order, spoken output, wrapping, selection, no startup source flash, native no-auto-launch or interacted file immutability. Existing #36 full-reflow failure/defer and #38 cue C5 unchecked/deferred remain unchanged and unproven related. Combined milestone acceptance is user-owned, requires renewed authority for deferred testing, and is not implied by closing stories.

## Seven verbatim criteria and evidence plan

| C | Canonical criterion | Base source assessment | Required implementation/unit evidence | Deferred native oracle |
|---|---|---|---|---|
| 1 | Hide HTML comments from both the page and accessibility reading order. | Missing: adapter preserves html_inline/html_block; renderer test explicitly expects a comment literal. | True-token filtering before text/alt/label/slug/anchor projection; update only obsolete comment expectation. `comments.md` and `comment-cases.json`; check no HIDDEN sentinel in any owned visible/AX-facing projection while original source stays exact. | Actual page and spoken/tree order omit true comments, not code/data/escape controls. |
| 2 | Escaped punctuation appears literally without its escape character. | Existing cmark decoding/parity coverage. | Preserve parser provenance; punctuation vector and escaped/entity comment controls, Unicode neighbors. Never global-unescape/reparse sanitized text. | Literal punctuation readable/selectable without backslash or accidental style/action. |
| 3 | Markdown examples inside code remain literal, even when they contain headings, links, or comments. | Existing parser-literal code and exact code-whitespace tests. | Inline/fenced/indented/unclosed fence regressions, comment/front-matter/code controls; no comment preprocessing across whole source. | Code examples remain literal/legible, code overflow local. |
| 4 | Do not provide a raw-source mode or require source inspection to recover from a problem. | Existing rendered-only reader/menu architecture. | Keep reader/opening route unchanged; metadata/fallback-only documents nonempty; recovery has plain in-document text plus quiet separate explanation, no source mode. Source/diff audit supplements units. | No source toggle/toolbar, parse failure readable in normal reader. |
| 5 | Treat incomplete or unsupported syntax as best-effort readable content; preserve text rather than silently discarding it. Intentional literal syntax can still appear as document content. | Existing malformed/unsupported literal behavior; new metadata recovery needed. | `recovery.md`, invalid aliases/tags/YAML, resource recipes, unclosed envelope unchanged. Exact original candidate retained with no Markdown/HTML/link/image/cue attributes; body still parsed and source lines intact. | Quiet lossless fallback, usable following body, no accidental hidden content or source-mode requirement. |
| 6 | Render supported HTML formatting without executing embedded scripts or allowing document content to replace the app's UI. | Existing narrow sub/sup/ins/custom-anchor/picture support, native presentation. | Preserve supported grammar without widening HTML authority; quoted attributes/rawtext/code remain literal, comments have true parser provenance; metadata/fallback data never execute. Existing picture selectors retained. | Supported styles readable; unsupported scripts literal, no UI replacement/automatic launch. |
| 7 | Render document-leading YAML front matter as a readable metadata table, like GitHub, rather than hiding it or displaying raw YAML delimiters and source. | Missing: all source enters cmark unchanged; no metadata block. | Offline pinned event parser; exact D2 scanner; flat bounded ordered nested table/empty/scalar projection; provenance feed and arena IDs; metadata, alias/tag, boundary, byte and resource fixtures. | Native key/value/index context/table, wrapping and theme/scale readable; no raw delimiters for valid tables; nested data not lost. |

A malformed/over-budget candidate intentionally falls back under C5. Record that as a recovery result, **not a passing valid-table C7 case**. Exact D2 recognizes one leading closed envelope after at most one BOM: column-zero `---`, optional ASCII space/tab suffix; first `---` or `...` matching closer; LF/CRLF/CR. Scalar/empty precedence is approved, no leading blank/preamble/later/code/container detection. Unclosed input is passed unchanged to ordinary cmark. TOML/independent JSON front matter and general pipe-table layout are outside this story.

## Implementation sequence and inspected preservation surface

1. Vendor the approved full MIT libyaml 0.2.5 source pin `2c891fc7a770e8ba2fec34fc6b545c672beb37e6`, local static C package and minimal clean-branch Xcode product linkage. Preserve source/provenance hashes and complete source/shipped license. No package registry/runtime fetch, external execution or constructors. Worker verifies pin/source checksums and installed app resource, not a claimed vulnerability audit.
2. Implement scanner and bounded event parser → owned flat metadata arena → bounded plain ordered row projection. Exact input/root/depth/event/visit/output accounting and abort cleanup are in the plan. No recursive object graph/destruction or SwiftUI view hierarchy; aliases are edges until bounded traversal.
3. Separate original source from line-break-preserving cmark feed before parsing references/footnotes/cues/headings. Metadata/fallback creates a leading draft before arena materialization. Original source is immutable; alerts use correct original physical lines; image occurrences retain original body line/columns. Metadata cannot allocate anchors/slugs/references.
4. Filter complete genuine parser HTML comments with original token identity and narrow attribute/raw-literal state before visible/AX-facing text; no sanitized-string reparse. Preserve code/escape/entity/rawtext/metadata/fallback data and unsupported wrapper text. Retain anchor-only/task-empty carriers.
5. Add one focused native metadata leaf/table with adaptive theme/font scale, wrapping/plain cells and contextual accessibility labels. Literal fallback is non-executing ordinary read-only content, never fed back into cmark. No general #19 table feature, #16 selection overhaul or speculative architecture.
6. Worker writes meaningful executable non-interaction regressions, installs triage-owned inert docs/data without silent changes, runs diagnostics then gates below, reviews scoped diff and records honest evidence/corrections. No production/executable tests were written by triage.

Inspected files: `MarkdownBlockRenderer`, `CMarkDocument`, `CMarkBlockAdapter`, `MarkdownBlockView`, `DocumentReaderView`, `DocumentOpeningCoordinator`, `NativeReaderMenus`, `MarkdownAlert`, `MarkdownPictureParser` and named suites below. Deep source/line/upstream evidence is retained in the plan. Current GitHub Contents HTML of pinned existing documents supports key/value rows and nested values, not pixel/AX parity or undocumented universal YAML policies.

## Existing non-interaction selector allowlist

Triage inspected these suites for pure parsing/data/attributed-style/numeric checks. These selector strings refer to existing source; worker verifies actual Swift Testing discovery and nonzero executed cases (a zero-test command is not a pass):

- `-only-testing:NeoMDTests/MarkdownBlockRendererTests`
- `-only-testing:NeoMDTests/CMarkDocumentTests`
- `-only-testing:NeoMDTests/CMarkParityTests`
- `-only-testing:NeoMDTests/MarkdownAnchorsTests`
- `-only-testing:NeoMDTests/MarkdownFootnotesTests`
- `-only-testing:NeoMDTests/QuotationsAndCodeTests`
- `-only-testing:NeoMDTests/TaskListRenderingTests`
- `-only-testing:NeoMDTests/AlertCueTests`
- `-only-testing:NeoMDTests/EmojiCueTests`
- `-only-testing:NeoMDTests/MarkdownTextDecoderTests`

Only these pure image methods, not the whole image suite (which also has loaders/network/filesystem cases):

- `-only-testing:NeoMDTests/MarkdownImagesTests/pictureBlockBecomesAnImageParagraph`
- `-only-testing:NeoMDTests/MarkdownImagesTests/pictureWithoutImgOrWithExtraContentStaysLiteral`
- `-only-testing:NeoMDTests/MarkdownImagesTests/malformedPicturesStayLiteralAndAdjacentImagesRemainSeparate`
- `-only-testing:NeoMDTests/MarkdownImagesTests/emptyAltImagesKeepACarrierRunAndContextsRetainImages`
- `-only-testing:NeoMDTests/MarkdownImagesTests/adjacentSameURLImagesRetainDistinctAttachmentRuns`

Proposed new suite names **not yet implemented/runnable**: `MarkdownFrontMatterTests`, `YAMLMetadataParserTests`, `MarkdownMetadataTests`, `MarkdownHTMLCommentsTests`. Worker may choose focused equivalent names and must publish real selectors after source inspection. They must exercise actual production scanner/parser/row projection, not a mock policy that duplicates expected output. Read fixture JSON independently; materialize its source scalars exactly. Resource recipes require real parsing/limit enforcement, not just checking a constants struct. Internal injection of smaller limits is acceptable for otherwise dominated limit gates; no app flags or app interactions.

Required new integration checks: all body alert/anchor/footnote/image/cue/task identities after masked metadata versus independently specified body oracles; original source and line endings exact; metadata-only/fallback-only empty-state behavior; contiguous arena IDs/parents/root/leaf/subtree and lookup after metadata prefix; no link/image/color/emoji attributes on metadata/fallback; empty/tag/structured-key/order/duplicates; alias reuse/shadow/cycle/undefined and output amplification; concurrent parser/context independence and clean abort/release. Add explicit parser-token controls for comment termination, raw-literal context across adjacent tokens/HTML leaves, attributes containing `>`, and no manufactured wrapper after removal. Report fixture corrections with evidence rather than silently weakening them.

## Later worker commands — UNRUN by triage

Run in the dedicated worker branch from repository root; keep output outside it. Perform primary Swift diagnostics before building. Example fixed prefixes (fresh result bundle on each run):

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-M1-15-Build build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-M1-15-Units \
  -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/MarkdownBlockRendererTests \
  -only-testing:NeoMDTests/CMarkDocumentTests \
  -only-testing:NeoMDTests/CMarkParityTests \
  -resultBundlePath /tmp/neomd-15-parser-units.xcresult test
```

The second command is a parser subset, not the entire gate. Repeat its test prefix with the remaining exact allowlisted selectors and implemented new suites, supplying fresh bundle paths. Record every selected case/count and all failures/skips/restarts. No broad test target, full suite, host or UI run. Run `git diff --check` and session diagnostics on the actual worker diff; report original upstream authenticated whitespace separately if applicable rather than rewriting vendor bytes. A unavailable gate remains blocked, not a pass; native deferral remains explicitly separate.

## Worker evidence — fill after actual implementation

| Field | Status at triage |
|---|---|
| PR / branch / implementation and exact tested head SHA | NOT CREATED |
| Installed triage packet manifest + replacement base-hash checks | Worker pending |
| Actual changed files / criterion-to-code map | Worker pending |
| libyaml source pin/checksums/local linkage + full bundled license evidence | Worker pending |
| Debug command, exit/result, log and tested SHA | UNRUN |
| Existing selector commands, passed/failed/skipped counts, logs/xcresults | UNRUN |
| New real selectors, fixture coverage, adversarial/concurrency results | NOT IMPLEMENTED / UNRUN |
| Diagnostics and scoped diff hygiene | Worker pending |
| Fixture deviations/corrections with rationale and new hashes | None implemented; worker must record |
| Actual table/AX/VoiceOver/light-dark/scale/reflow/selection/interactions | DEFERRED/UNRUN |
| Read-only interacted file bytes + nanosecond mtime | DEFERRED/UNRUN |
| Known new failure/validation limit | No executable research; not an absence-of-defects claim |
| #36 / #38 | Preserve original separate failure/deferred states |
| Combined milestone business acceptance | User-owned, NOT ACCEPTED |
