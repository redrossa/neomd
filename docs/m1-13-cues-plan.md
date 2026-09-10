# M1-13 accepted implementation baseline

Status: **ACCEPTED implementation baseline; completed implementation handoff and explicit validation limits recorded in [validation](m1-13-validation.md), not accepted or merged.** Only #13 is authorized; pause before #14.

**Latest keyboard overlay:** [approved semantic policy](https://github.com/redrossa/neomd/issues/13#issuecomment-5612059691) defines separate selectable text/link-action stops and truly overflowing code in document order, reverse traversal, offscreen acquisition and native-control boundaries without wrapping. The latest direct user instruction authorizes integrating the four-source implementation and units while deferring further keyboard-navigation E2E, **not passed**. No Accessibility permission changes or permission-dependent active UI gate. These overrides supersede corresponding historical gates below only; no known implementation defect is waived.

**Approved superseding disposition:** [approval5610876429](https://github.com/redrossa/neomd/issues/13#issuecomment-5610876429) transfers complete C5 to [#38](https://github.com/redrossa/neomd/issues/38) for final milestone validation, unchecked/deferred—not passed. This supersedes C5 pre-merge gates below, not historical failures or C1–C4/ordinary-size regression obligations. Preserve scale plumbing/tests; no further larger-size matrix or architecture experimentation is authorized. #36 remains separate with unproven equivalence; user owns final milestone acceptance.

- Issue: https://github.com/redrossa/neomd/issues/13
- Milestone: https://github.com/redrossa/neomd/milestone/1
- Accepted main SHA: `add27876bca4036ed0c6c023c08cf94f46481e6b`.
- Published accepted baseline: https://github.com/redrossa/neomd/issues/13#issuecomment-5594124438
- D1–D3 approval: https://github.com/redrossa/neomd/issues/13#issuecomment-5594012782; current issue body is the contract.
- Runtime: triage `openai-codex/gpt-6-astra`, high, verified. Worker must independently verify Astra **low**. Current user override: no reviewer; coordinator accepts/merges from exact-head worker evidence, without duplicate testing. Required checks/protection remain binding.
- Triage authored repository-relative `docs/` fixtures, included on the story branch. No production/executable test changes were made by triage.

## Approved outcome and complete criteria

As a reader skimming an agent's output, I want visual cues to communicate meaning so that I can notice cautions and useful context.

C1. Distinguish NOTE, TIP, IMPORTANT, WARNING, and CAUTION alerts in both themes using labels and visual treatment.

C2. Alerts remain coherent with the page when opening in either theme and when system appearance changes; labels and structure communicate their distinctions without relying on color alone.

C3. Display Unicode emoji and recognized Unicode-backed GitHub emoji shortcodes and aliases from a pinned offline corpus; leave unknown and image-only custom shortcodes (such as `:shipit:`) readable as text.

C4. Display valid HEX, RGB, and HSL inline-code color references with a small noninteractive swatch and their text value. Invalid values remain ordinary code.

C5. Keep cues aligned with text and accessible at larger reading sizes.

D1: the NeoMD extension is approved. Exact whole parser-normalized inline-code `#RRGGBB`, lowercase `rgb(R,G,B)` with integer 0–255 channels, or `hsl(H,S%,L%)` with finite hue 0–360 and saturation/lightness 0–100%. Decimal HSL components and interior component spacing are allowed. No outer whitespace, substring matching, clamping, named colors, shorthand/alpha HEX, rgba/hsla or CSS4 space/slash models. Preserve the displayed code string. Use a bounded plain-decimal lexer, not a permissive CSS evaluator; unsupported expressions/exponent notation and nonfinite values remain code. Parser-owned Markdown code-span normalization stays unchanged.

D2: all aliases in the pinned Unicode-backed corpus, with image-only custom entries kept literal; no runtime lookup. D3: actual 1×/1.5×/2× cue/inline font scaling via a small internal input/test mechanism; no public commands, shortcuts or persistence from #22.

## Current implementation evidence (read bodies; no tests executed by triage)

| Criterion | Current state and concrete evidence |
| --- | --- |
| C1 | Missing. `CMarkDocument` attaches autolink/strike/table/tasklist only. `CMarkBlockAdapter.appendBlocks` maps every quote to `.blockQuote`; `MarkdownBlock.Kind` has no alert. `MarkdownContainerView.nodeView` exposes ordinary Block quote context only; `MarkdownQuoteDecoration` draws tertiary rules. `QuotationsAndCodeTests` protects nested hierarchy, markers, IDs and exact code, not alerts. |
| C2 | Adaptive foundation exists, alert behavior missing. `ReaderTheme` uses adaptive NSColor-backed colors; stable `MarkdownContainerGeometry` and passive quote paths avoid recursive views. `AppearanceUITests` has opening-light/dark and actual-system-switch tests, but their fixtures contain ordinary text/quotes rather than alerts. |
| C3 | Unicode is retained; no shortcode corpus/recognizer. `CMarkBlockAdapter.inline` simply copies text literals. Decoder/renderer scalar tests preserve Unicode/ZWJ/skin-tone content. They do not establish new emoji recognition/rendering. |
| C4 | Missing. Inline code is monospaced/background-styled by `ReaderTheme.presentationText`; no strict color parser or swatch semantics/drawing. Exact code whitespace assertions already exist in `QuotationsAndCodeTests`. |
| C5 | Missing cue-specific scale proof. `MarkdownBlockView` overrides local body/heading fonts; `ReaderTheme` fixes script offsets; `MarkdownLinkedImageContent.attributes` reconstructs NSFonts. An outer `.font` or window resize alone cannot enlarge these actual paths. Geometry treats quote contexts as zero-height, so an alert header must be explicitly measured. |

Dependencies #1–#12 are closed; #13 remains first open in the explicit #1–#24 order. Fresh origin/main equals the accepted SHA; worktree `coordinator/m1-story13` is clean; no open PR/13 implementation branch found. Unrelated dirty original/icon worktrees are not part of this task.

## Minimal ordered implementation plan

### 1. Establish offline data and provenance-safe parser semantics first

Bundle a focused derived alias→Unicode resource from `github/gemoji` commit `0eca75db9301421efc8710baf7a7576793ae452a`, preserving every exact Unicode string and all 1,913 aliases (1,870 records). See fixture `corpus/provenance.json`, pristine `gemoji-emoji.json`, `expected-aliases.json` and `gemoji-LICENSE.txt`. Source SHA256 is `b174ae2aeb321b52f64adb9ff412f966a7f338839d780784dd15dcad702c2dd6`. A research-only API cross-check found the same 1,913 Unicode names plus 23 image-only names; it is not a runtime dependency or future-version promise.

Gemoji is MIT licensed. Preserve its complete notice with the vendored/derived data **and in shipped app resources**. Load bundled data deterministically/off-main or initialize an immutable map once; verify the app bundle, not merely test-tree availability. Do not reconstruct Unicode by removing selectors from CDN filenames. System fonts draw glyphs; no custom GitHub/Twemoji images or other Unicode data files are redistributed, so do not invent artwork permissions. Triage's green badge is newly authored fixture data, not app icon work.

**Important actual parser finding:** `inlines.c:handle_backslash` and `handle_entity` emit ordinary TEXT nodes with already-unescaped literals. `blocks.c:cmark_parser_finish` then calls `iterator.c:cmark_consolidate_text_nodes`, which joins adjacent TEXT and frees the originals. `CMarkBlockAdapter` receives this result. Therefore regex replacement in `CMarkDocument.literal`, attributed text, or consolidated visible strings would wrongly promote `\:smile:` / `&#58;smile:`; raw/visible substring searches and guessed UTF-16/source-column offsets are not provenance.

Smallest concrete baseline: use the **existing public cmark inline extension API** to recognize raw shortcode candidates at `:` while parsing, before unescaping/consolidation, rather than forking/replacing the parser or masking/reparsing the source. Register the immutable extension once alongside existing extensions; attach it to each parser inside the existing parsing lock. Keep autolink handling before the new candidate hook. Its raw-byte bounded scan accepts only an exact case-sensitive `:alias:` present in the pinned map (maximum alias length bounds lookahead); no candidate spans escapes, entities, whitespace, newlines or formatting delimiters. Unknown names return no match and preserve normal cmark recovery. An escaped opener is consumed by cmark's backslash handler and never reaches the hook; an escaped/entity closer or name is not an exact raw candidate. Even/odd backslash fixtures distinguish these cases.

Emit a private, identifiable non-TEXT inline candidate using public custom-inline node APIs (owned raw token payload, e.g. `CMARK_NODE_CUSTOM_INLINE` + `on_enter`; do **not** send it to an HTML renderer). This survives TEXT consolidation and later bracket/link resolution. In the iterative Swift adapter, after ancestry is known, copy the exact Unicode into eligible text while retaining inherited strong/emphasis/link/script attributes. Restore the raw token for image-alt ancestry; image metadata, picture HTML attributes, code, raw HTML and URL destinations/titles stay literal. Ordinary authored link labels are eligible; automatic URL labels are not. Do not use the existing footnote `ineligible` flag wholesale, since it blocks links as well as images. Keep custom identity/candidate handling private; never steal the footnote-reference user-data slot. No source rewriting, C-pointer escape, mutable shared per-document callback state, main-actor parse, or runtime network access.

Public support inspected: `cmark-gfm-extension_api.h` special-inline/match-inline hooks and bounded offset/peek APIs, and `cmark-gfm.h` custom-inline owned on-enter APIs. Existing `strikethrough.c` illustrates registration and parser offsets. This is a static feasibility assessment, not a compiled spike. Worker must first prove escape/alias/autolink/reference/image/Unicode vectors against the packaged parser. If the hook cannot preserve existing semantics, stop with evidence and a scoped alternative; do not silently fall back to unescaped-string replacement, source masking, or a broad parser patch. If any vendor bytes are ultimately changed, a documented authenticated patch/inventory/notice update and offline verifier are required, not hand edits to hashed sources.

### 2. Recognize alerts from exact source plus parser-owned structure

Add only a compact five-case alert semantic kind/metadata to the flat model. Eligible: cmark block_quote whose **actual parent is the document root**, whose physical opening line contains only the parser-owned root quote prefix and standalone literal `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` or `[!CAUTION]`, optionally followed by spaces/tabs. The first direct child must be its opening paragraph on that same line; its marker text must be ordinary unstyled/unlinked text followed by the first linebreak/softbreak or end. No nested alert syntax, title dialect, lowercased/unknown marker, formatted/code/link/reference-linked marker, later paragraph/line or quote preceded by a blank/definition.

Retain original source in parser-local storage with an O(source bytes) line-start index (handle LF/CRLF/CR), and inspect **that quote's opening line**, not a global search. Verify the raw marker bytes after the cmark-established `>` prefix and verify the ordinary parsed marker node/first separator before consuming. Root-only syntax avoids guessing arbitrary nested continuation offsets. `cmark_node_get_string_content` on the paragraph retains parser-owned raw inline content and can cross-check the opening line, but cannot alone prove physical quote start after reference-definition removal. Never infer eligibility solely from the unescaped `[!NOTE]` literal. Escaping any marker punctuation or spelling part through an entity must fail promotion even when the displayed text is identical.

Remove exactly the verified marker and its first separator from that paragraph's adapted output; preserve any remaining text, complete subsequent blocks, tasks, code, nested **ordinary** quotations, anchors and footnotes in order. Marker-only alerts still expose a label instead of disappearing in empty-node pruning. Ensure the empty-body representation is handled deliberately by `isLeaf`, materialization and layout. Both leaf-render passes used for anchor allocation must apply identical transformations. Apply the existing slugger to final semantic heading text; swatch decorations must not alter it. Keep root/parent/child/subtree IDs contiguous and stable for the lifetime of a rendered snapshot; theme/scale/width changes must never recreate it.

### 3. Add pure color semantics, then one passive cue contract across every inline path

Use a focused pure full-value parser returning finite sRGB components. The 49 color vectors pin syntax/range/normalization and independent primary/gray/decimal HSL conversion oracles; reject instead of clamp. Tag only parser-authored inline-code runs, preserving text and all existing attributes. Do not scan fenced code or ordinary prose. No dependency/framework is needed.

Draw a small baseline-aligned swatch with a neutral visible border for black/white and retain the original code value as readable/selectable text. The swatch has no independent AX node, focus target, button, link, hover control, popover or copy action. When the code text itself is an authored link, preserve that existing action without adding a swatch-specific one. Keep model characters unmodified; do not inject a square/attachment carrier into model text, link-range indexing or anchors.

Cover all existing paths, not just `MarkdownBlockView`'s plain `Text`:

1. Plain attributed SwiftUI text, headings, lists, quote/alert bodies and footnotes.
2. `MarkdownImageParagraph.composedText`'s **nonimage** segments in mixed unlinked-image paragraphs/headings, for loaded/loading/unavailable images; use the same cue composition rather than raw `Text(segment)`.
3. `MarkdownLinkedImageContent.make`'s **nonimage** runs in native linked-image NSTextView paragraphs/headings, retaining image occurrence identity, attachments, links, typography and selection. Keep swatch attachment/drawing separate from `NeoMD.ImageAlternative` so it does not masquerade as an image or duplicate AX speech. `MarkdownLinkedImageTextView.update` must account for scale/theme input while preserving valid selected ranges; unchanged input must not replace storage.
4. Image-only, linked-image-only and picture paths retain their existing alt/status/permission behavior and bitmap colors/aspect ratios; no new emoji/swatch interpretation inside image metadata. Mixed fixture cases ensure nearby text cues work on both native and SwiftUI branches. Initial/loading/unavailable native states can be deterministic native-host inputs; no external network needed for #13.

**Approved amendment (2026-09-09):** [user approval](https://github.com/redrossa/neomd/issues/13#issuecomment-5595759256) supersedes the original linked-image-only restriction. Route inline leaves containing valid color semantics through the existing native bridge as well, including no-image and mixed unlinked-image leaves. Invalid-only code and other leaves stay SwiftUI. The selectable SwiftUI TextRenderer feasibility probe failed (zero draw calls); the image alternative added unwanted AX children. Remove those failed production routes, retain their honest evidence, and prove the actual native replacement. Do not migrate every leaf to NSTextView or add overlays that intercept native text/links. Swatch presentation must preserve current text-selection behavior; native selected-range assertions/drag visuals can be clipboard-free. Any design requiring new clipboard mutation must wait for explicit exclusive-window approval.

**Subsequent approved amendment (2026-09-09):** [approval5609963406](https://github.com/redrossa/neomd/issues/13#issuecomment-5609963406) supersedes the remaining ordinary-leaf SwiftUI restriction above. Route ordinary inline prose/headings and mixed text-bearing image leaves through the existing selectable read-only native bridge, excluding inherited SwiftUI selection only locally on that representable. Preserve pure-image/picture presentation and selectable SwiftUI labels/markers/fenced code. Preserve parser/flat arena/lazy layout/controller/image store, link/menu policy, exact strings/storage/lifecycle and verify affected cross-block selection. No selection-loss waiver or whole-document/eager renderer is approved. Production implementation and its remaining concrete2× validation blocker are recorded in [validation](m1-13-validation.md); approval is not acceptance.

### 4. Measure labels and preserve the flat layout/decorations

Add five always-visible word labels with distinct passive symbols and adaptive readable treatment/leading rule. Meaning must remain apparent in monochrome; color is supplementary. Expose one readable alert label before its body; hide decorative symbol/rule duplicates, not body links/selection.

Update `MarkdownContainerGeometry.requiresView`, preparation/quoted inheritance, `place`, and `MarkdownContainerLayout.measured/placeSubviews` intentionally: an alert header is a full-available-width measured row, not a zero-height ordinary-quote context or 28pt list marker. Reserve measured header height plus gap **before** child rows, including marker-only alerts. Body foreground should remain readable primary alert text, not accidentally inherit secondary ordinary-quote treatment. Draw alert rules via the existing passive batched decoration model (or a constant number of surfaces per root), not recursive SwiftUI container trees. Do not group alerts into homogeneous compressed ordinary-quote runs. Retain normal quote compression, bounded indentation, list/task baselines, anchor marker identities, layout cache invalidation and linear arena work.

### 5. Thread the approved narrow scale input into actual fonts and metrics

Default scale is exactly 1; test 1, 1.5 and 2. Use an internal value passed through theme/container/inline/native inputs, with a DEBUG-only owned test-launch mechanism if needed. Scale actual body/heading/inline-code/script fonts, script baseline offsets, alert labels/symbols, passive swatch size/baseline, and affected marker font/width metrics so mixed cue rows align. Native `NSFont.pointSize` must really change; outer SwiftUI `.font` alone is insufficient because children override it. Preserve document image natural-size/fit rules (text scale is not image upscaling), hierarchy, literal code and keyboard links. No public size menu, shortcuts, preference storage or across-launch persistence; those remain #22.

Keep this proportional to C5. Do not import a new typography framework or redesign reader reflow. Invalidate measured caches when their font input changes, without mutating document snapshots or producing a geometry/state feedback loop. Normal width/scale cue behavior is required; #36 is not a waiver for new cue layout failures.

### 6. Validate exact production paths, include triage artifacts, and report evidence

Triage authored data only under `docs/fixtures/m1-13-cues/`; do not invent passes or treat case JSON as executable coverage. Worker supplies meaningful tests/actual selectors and fills evidence in the cumulative catalog. Required gates:

- Proactive primary diagnostics before build, explicit Xcode Debug app build with bundled map/notice present, relevant new parser/color/theme/native/layout units and affected cmark parity/quotes/anchors/images tests. Exercise full 1,913 alias mapping plus escape/negative vectors, repeated/concurrent parses and stable flat arena lifetime/layout. If parser registration changes, retain the existing 16-worker concurrency test. No zero-selected-test result counts.
- Native host measurements: actual fonts at 1×/1.5×/2×, header-before-body geometry, baseline/alignment/wrapping, black/white borders, exact native selection ranges and unchanged-update replacement count. Test linked image states loaded/loading/unavailable and both SwiftUI/native mixed branches. Preserve deep ordinary quote operation bounds/sparse views/registry teardown; add alert/body branching without recursive view graphs.
- Serialized story UI on real app: open all five alert kinds in Light and Dark; inspect screenshots/contrast/labels; real live system switch Light→Dark→Light with authorized existing host controller and restoration, keeping the same open document/reading point. App appearance override or debug notification alone is not C2 live-system evidence.
- C5 matrix: both themes × actual scales 1/1.5/2 × wide/narrow (900/480pt window, about 760pt height) using alerts/mixed cues. Native-host assertions may supply precise metrics; story UI must visibly prove all three scales and both rendering paths, not merely AX strings or window resizing. Record actual font points and measured glyph/swatch/header bounds, plus inspected screenshots. Do not require content beyond viewport to be visible without scrolling; compare document-order/spatial bounds for visible samples.
- Existing/native link interactions in mixed headings/alert bodies: mouse and Option-Tab/arrows/Return/Space reach `#mixed-target`, native badge/inline code links still route through app policy, Escape returns to reading; no added swatch focus/action. Native AX text/roles/order, single label, unchanged bytes **and** mtimes for fixture files after opening/scrolling/switching/resizing/closing.
- Relevant normal resize/initial-margin/image/native-link/selection nonregressions are still required. Choose nonclipboard selectors after reading their bodies. No blanket full UI class invocation that includes clipboard tests.
- `git diff --check`, session `lens_diagnostics mode=all`, actual exact-head evidence, pass/fail/skip counts and screenshot names; PR uses `Refs #13`. Worker commits/pushes/opens PR only after required validation passes; no worker merge/closure and no reviewer launch.

Use Xcode (no standalone Swift package build/test for the app), external DerivedData/fresh xcresults and serialized UI. Consult `docs/appearance-ui-tests.md`, `docs/m1-12-validation.md` and current clipboard exclusions. The catalog names suggested new test classes only as proposals; the worker must publish the exact implemented selectors and commands. Unavailable required automation/restoration is a blocker, not a skip-as-pass.

## Remaining risks and strictly bounded deferrals

No unresolved product/readiness blocker remains after D1–D3. Static feasibility is not test evidence: first parser provenance tests and native passive-swatch/scale hosting are the early implementation gates. Surface a concrete failure promptly instead of broadening scope.

- #36 unchanged full reflow hang remains **BLOCKED/deferred**, not fixed or passed; final milestone must investigate/retest it. Keep the unchanged regression. No new cue reflow, initial-margin, normal resize, live appearance or native interaction waiver follows.
- Actual manual VoiceOver speech/order/duplicate speech and comprehensive combined E2E remain user-owned final milestone checks, explicitly unverified. Current-story AX/labels/geometry remain required.
- Clipboard-mutating tests require a new exclusive-window approval even if they save/restore/lease it. None were run here; do not mutate clipboard as a convenient selection oracle.
- No email access, security/signing/sandbox changes, user-worktree/icon/DMG publication, mention interpretation (#14), HTML expansion (#15), public text-size controls (#22), unrelated refactor or milestone closure. Pause after #13.
