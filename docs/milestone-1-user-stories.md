# Milestone 1 brainstorm: Open and read Markdown

Status: Draft for review. These are proposed stories and acceptance criteria, not published GitHub issues or an implementation commitment.

## Product outcome

A person receives a Markdown file from an AI agent, opens it in NeoMD, and reads a polished document immediately. They do not need to understand Markdown syntax, use a preview toggle, or configure the app.

Milestone 1 establishes the reading experience. Making small edits is part of NeoMD's broader purpose and belongs to a later milestone.

## Working assumptions to review

- **Reading only:** opening, selecting, navigating, and closing a document never changes its contents. Task checkboxes display status but cannot be toggled.
- **Minimal window:** no app toolbar, sidebar, formatting controls, floating buttons, or source/preview switch. Keep native macOS close/minimize/full-screen controls and a discreet document title. “No buttons” is interpreted as no app-specific buttons; confirm whether native window controls should also disappear.
- **Native commands:** opening files and other actions remain available through the macOS menu bar and keyboard shortcuts. Document links remain interactive.
- **System appearance:** automatically follow macOS light/dark appearance, including changes while the app is running. No separate theme setting.
- **Visual target:** recognizable GitHub document typography, spacing, hierarchy, and colors, adapted to a standalone Mac window. Pixel-for-pixel reproduction of GitHub's surrounding website is unnecessary.
- **Local first:** no account, repository connection, or network request is required to render the document itself. Explicitly referenced remote images may need a connection.

## Proposed user stories

All 24 stories are included in Milestone 1 scope. M1-19 through M1-24 were added to the core milestone during review. Acceptance criteria and remaining product decisions are still draft proposals to refine before creating issues.

### M1-01 — Open a document from Finder · Core

As a person reviewing an AI-generated file, I want to open it from Finder so that I can start reading without importing or converting it.

Acceptance ideas:

- Finder's Open With offers NeoMD for `.md` files; double-click opens NeoMD when the user has chosen it as the default app.
- Opening works whether NeoMD is already running or has not launched yet.
- Filenames containing spaces, Unicode, and an uppercase `.MD` extension work.
- The first visible document content is rendered; raw source does not flash during loading.

### M1-02 — Open a document without an on-screen button · Core

As a reader, I want familiar Mac opening commands so that a minimal window is still easy to use.

Acceptance ideas:

- File → Open and Command-O present a native file picker.
- Dropping an `.md` file onto the app's window or Dock icon opens it.
- An empty window contains a quiet instruction such as “Open a Markdown file with ⌘O, or drop one here.”
- Canceling the picker preserves the current document and reading position.

### M1-03 — Know which document I am reading · Core

As a reviewer comparing several outputs, I want each document to be identifiable so that I do not confuse files.

Acceptance ideas:

- Display the filename discreetly in the native title area; make its location available through a standard menu action.
- Different files open in separate windows; reopening an already-open file focuses its existing window and preserves its reading position.
- Two files with identical names in different folders remain distinguishable through their locations.
- Closing a reading window never asks to save changes.

### M1-04 — Read in an uncluttered window · Core

As a reader, I want the document to occupy the window so that my attention stays on its content.

Acceptance ideas:

- The document begins with comfortable margins and has a readable maximum text width.
- Narrow windows reflow prose; long code and other wide content remain accessible without making the whole page scroll sideways.
- Resizing and entering full screen preserve the document and approximate reading position.
- Hovering content does not reveal app-specific edit, copy, or formatting buttons.

### M1-05 — Follow the Mac's appearance · Core

As a reader, I want NeoMD to match the system theme so that it feels comfortable alongside my other apps.

Approved scope split, recorded during implementation: M1-05 is the theme foundation for content and surfaces that already exist, the live appearance switch that keeps the reading position, and the absence of color transforms on document imagery. Image-specific theme acceptance belongs to M1-12 and alert-specific theme acceptance to M1-13. Story order is unchanged.

Acceptance ideas:

- Opening in either light or dark mode produces a coherent page for existing rendered content, including code, links, quotes, selection, and existing empty/error states.
- A system appearance change updates an open document without reopening it or losing my place.
- The theme foundation does not apply page-wide color inversion or color transforms to document imagery; image rendering and appearance-specific source verification belong to M1-12.
- Labels and structure keep important distinctions understandable without relying on color alone.

Implemented: the reader draws its surfaces with adaptive system styles rather than a fixed palette, so an appearance change repaints an open document in place instead of re-rendering it. Distinctions carry structure as well as color — headings differ in scale, quotations keep a rule and indent, code keeps a monospaced face in its own container, list items keep their markers — and a link is a tinted label that is always underlined, in either appearance and with no accessibility setting to switch on first. `docs/appearance-ui-tests.md` records how the live light/dark switch is exercised and how the tester's own setting is restored.

### M1-06 — Understand document structure and emphasis · Core

As someone scanning a report, I want its structure and emphasis to be visible so that I can quickly find the important parts.

Acceptance ideas:

- Distinguish six heading levels, paragraphs, bold, italic, combined emphasis, and strikethrough.
- Render subscript, superscript, and underlining rather than exposing their HTML wrappers.
- Render unordered, ordered, and nested lists with consistent indentation; preserve an explicitly chosen ordered-list starting number.
- Preserve intended paragraph boundaries and explicit line breaks while allowing ordinary wrapped source lines to flow as prose.
- Keep mixed content legible, including emphasized text and links inside list items.

Implemented: six heading levels and inline emphasis retain their native text styling. Matched inline `<sub>`, `<sup>`, and `<ins>` wrappers become smaller lowered/raised text or underlining; malformed wrappers and unsupported HTML remain literal, and code stays untouched. Lists preserve their starting ordinal and nested indentation, align single- and two-digit markers, and keep continuation paragraphs in the same text column without repeating a marker. Paragraph boundaries, explicit breaks, and links within list items are preserved.

### M1-07 — Read quotations and code comfortably · Core

As a reviewer of technical output, I want quoted material and code to remain distinct so that I can separate explanation from examples.

Acceptance ideas:

- Quotes have clear visual boundaries, including nested quotations.
- Inline code and code blocks preserve literal content, indentation, and whitespace.
- Code fences and language markers do not appear as surrounding document syntax.
- Long code lines remain readable through horizontal scrolling within the block.
- Proposed highlighting baseline: Swift, Python, JavaScript/TypeScript, JSON, shell, and Markdown. Unknown or absent languages use readable plain code.

Syntax highlighting is a proposed implementation baseline inspired by GitHub's [code-block guidance](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks), not a promise to support every language GitHub recognizes.

Implemented: quotations and list items retain their ordered hierarchy, with continuous nested quote rules. Inline code is monospaced with an adaptive background; code blocks preserve parser-provided whitespace (including boundary blank lines) and scroll horizontally. Supplementary local syntax colors cover Swift, Python (`py`), JavaScript (`js`), TypeScript (`ts`), JSON, shell (`sh`, `bash`, `zsh`), and Markdown (`md`), using the lowercased first info-string word. Unknown/absent languages remain plain. This is a small lexical baseline, not full compiler grammars. Blocks above 262,144 Unicode scalars skip tokenization without dropping content; empty fences produce no fabricated block.

### M1-08 — See checklist progress without changing it · Core

As someone reviewing an agent's task plan, I want to distinguish completed and unfinished work so that I can assess progress.

Acceptance ideas:

- Checked and unchecked items have distinct, accessible visual states, including nested items.
- Clicking or pressing Space on an item never changes its status or the file.
- Task descriptions retain links and inline formatting.

Implemented: literal `[ ]`, `[x]`, and `[X]` markers at the start of a list item's first direct paragraph become read-only task glyphs when followed by whitespace or the end of the paragraph. Checked and unchecked states differ by shape and accessible labels, including nested and quoted tasks; ordered tasks keep their visible ordinals. Escaped, code, formatted, linked, mid-text, and later-paragraph look-alikes remain literal. Descriptions retain links, inline formatting, and code-span whitespace. The glyphs are not controls: clicking or pressing Space cannot change status or source files.

### M1-09 — Follow links within a document · Core

As a reader of a long document, I want section and footnote links to work so that I can move between an explanation and its supporting material.

Acceptance ideas:

- Heading links reach the correct section, including duplicate headings and headings containing formatting or Unicode.
- Custom anchor destinations work without displaying empty anchor markup.
- Footnote references reach their notes; return links bring me back to the reference.
- A missing destination leaves the document usable and gives unobtrusive feedback.
- Keyboard users can focus and activate these links.

Implemented in the M1-09 branch (independent acceptance pending): every document is parsed offline by pinned cmark-gfm, then mapped into native attributed text and existing block views. Heading slugs include formatting/Unicode and deterministic duplicate suffixes. Complete inline `<a name|id>` pairs without `href` supply hidden custom destinations; unsupported, unclosed, escaped and code markup remains literal. Reachable footnotes retain structured bodies, repeated references and return links; unused definitions and disconnected cycles stay hidden. Generated destinations are collision-safe without changing authored first-wins fragments. Missing fragments show a transient notice rather than launching another app. Option-Tab focuses link-bearing blocks, arrows cycle links, Return/Space activates, and Escape returns to reading. Return targets are containing blocks, not individual text runs. cmark soft/hard breaks in link labels are intentional; tables remain flattened cells and images remain alt text until their later stories. Source files are never rewritten. See the cumulative fixture catalog for exact test selectors and validation status.

### M1-10 — Follow links to nearby files · Core

As someone reading a folder of generated documentation, I want relative links to work so that the folder remains useful outside GitHub.

Acceptance ideas:

- Resolve ordinary paths from the current document's directory, including `./`, `../`, spaces, and encoded filenames.
- Open a linked Markdown file in NeoMD, including navigation to its requested section.
- Open other local file types through the appropriate macOS application after an explicit click.
- Missing or inaccessible targets produce a readable message while retaining the current document.
- Apply the same path policy to linked images.

Approved root-path policy (user email reply, 2026-09-08): resolve a path beginning with `/` from the current document's folder, without repository-root discovery. Apply this same policy to linked images. This deliberately differs from GitHub's repository-relative leading-slash links. [Relative-link reference](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#relative-links).

Local folder navigation does not imply branch switching, private-repository access, or fetching files from another repository. Approved (user email reply, 2026-09-08): when needed, offer an explicit native enclosing-folder permission request for read-only access held only for the current app session. Preserve the sandbox; no persisted bookmarks or access across launches is implied.

### M1-11 — Open web references · Core

As a reader checking a source, I want web links to open in my default browser so that I can inspect the original material.

Acceptance ideas:

- Labeled links, reference-style links, and ordinary web URLs are recognizable and actionable.
- Activating an HTTP(S) link opens the default browser and preserves my NeoMD reading position.
- The destination is inspectable through a contextual menu, without adding permanent window controls.
- Opening a document never automatically opens a browser or launches a linked application.

The user's exclusion of external-resource references means repository-configured shorthand such as ticket identifiers; it does not exclude normal hyperlinks.

Implemented: labeled, reference-style and ordinary web URLs retain underlined native links. Explicit mouse or keyboard activation opens the system handler without changing reading position. Right-click or Control-click a link-bearing leaf to inspect its authored destinations and choose Open Link or Copy Link; link-free text keeps its native menu. A non-hit-testing background attachment leaves selectable text and accessibility links unobstructed. No permanent controls, automatic browser launches or source-file writes are added. See the cumulative fixture catalog for worker evidence and deferred milestone checks.

### M1-12 — View illustrations and screenshots · Core

As someone reviewing an illustrated explanation, I want its images displayed in context so that I can understand the whole document.

Acceptance ideas:

- Display supported local and HTTP(S) images with preserved aspect ratios and sensible sizing.
- Support the documented picture-element use case, including appearance-specific sources and an image fallback.
- Document images retain their original colors in both themes; appearance-specific sources choose the matching asset and update when system appearance changes. (Moved here from M1-05 by the approved scope split.)
- Missing, inaccessible, or offline images show meaningful alternative text or a quiet placeholder without blocking the rest of the document.
- Opening text remains responsive while remote images load.
- Existing links to uploaded assets remain usable; uploading new assets is outside this reading milestone.

Approved decisions (issue #12, 2026-09-08): accept every image format the system decoder accepts and document a tested subset (PNG, JPEG, GIF shown as a static first frame, SVG rendered statically by the system without running scripts); never prompt for folder permission automatically — inaccessible local images show their alternative text or a quiet placeholder with an explicit `Allow folder access` action that reuses the M1-10 session-only read-only grant; load both HTTP and HTTPS images, with the App Transport Security exception required for plain HTTP and the outgoing-network sandbox entitlement; support only GitHub's documented `<picture>`/`prefers-color-scheme` form with an `<img>` fallback, excluding the legacy `#gh-dark-mode-only`/`#gh-light-mode-only` fragments. [Picture-element reference](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#the-picture-element); the `prefers-color-scheme` sun/moon example with its `user-images.githubusercontent.com` assets comes from the earlier revision of that section and is reproduced in `docs/fixtures/m1-12-images/network.md`. Local text rendering stays offline; only explicitly referenced remote images use the network.

Validation boundary approved for M1-12: [option B](https://github.com/redrossa/neomd/issues/12#issuecomment-5589023958) tracks the accepted-base full-reflow hang separately in [#36](https://github.com/redrossa/neomd/issues/36), without changing the ordered story sequence. The unchanged full test remains **BLOCKED/deferred** until final milestone validation, not passed; initial margins and all other image/navigation/resize obligations remain required. [Actual fixture/gate evidence](m1-12-validation.md). Implementation pauses after M1-12; this does not authorize M1-13 or milestone closure.

### M1-13 — Notice alerts, emoji, and color references · Core

As a reader skimming an agent's output, I want visual cues to communicate meaning so that I can notice cautions and useful context.

Acceptance ideas:

- Distinguish NOTE, TIP, IMPORTANT, WARNING, and CAUTION alerts in both themes using labels and visual treatment.
- Alerts remain coherent with the page when opening in either theme and when system appearance changes; labels and structure communicate their distinctions without relying on color alone. (Moved here from M1-05 by the approved scope split.)
- Display Unicode emoji and recognized GitHub emoji shortcodes; leave unknown shortcodes readable.
- Display valid HEX, RGB, and HSL inline-code color references with a small noninteractive swatch and their text value. Invalid values remain ordinary code.
- Keep cues aligned with text and accessible at larger reading sizes.

Color swatches are deliberately proposed as a NeoMD extension: GitHub documents them for conversations rather than `.md` file rendering. They remain included here because the requested scope covers the guide's formats. [Color-model reference](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#supported-color-models).

### M1-14 — Interpret mentions without a GitHub account · Core

As a reader of shared notes, I want people and team mentions to remain meaningful so that I can identify who the document refers to.

Acceptance ideas:

- Proposed treatment: recognize standalone person/team mentions and present them as styled links to the corresponding GitHub destinations.
- Preserve the written handle; resolving display names, checking account existence, or accessing private teams is unnecessary.
- Avoid treating email addresses or code samples as mentions.
- Reading never sends mention notifications. No sign-in or autocomplete is required.

### M1-15 — See intended content rather than formatting machinery · Core

As a nontechnical reader, I want formatting instructions to stay out of the reading experience so that the document feels finished.

Acceptance ideas:

- Hide HTML comments from both the page and accessibility reading order.
- Escaped punctuation appears literally without its escape character.
- Markdown examples inside code remain literal, even when they contain headings, links, or comments.
- Do not provide a raw-source mode or require source inspection to recover from a problem.
- Treat incomplete or unsupported syntax as best-effort readable content; preserve text rather than silently discarding it. Intentional literal syntax can still appear as document content.
- Render supported HTML formatting without executing embedded scripts or allowing document content to replace the app's UI.

### M1-16 — Select and read accessibly · Core

As a reader using a keyboard or assistive technology, I want access to the rendered document so that the minimal interface does not limit me.

Acceptance ideas:

- Text selection and Command-C copy the visible text, including useful code indentation, without adding Markdown delimiters.
- Keyboard scrolling and link navigation work with a visible focus indicator.
- VoiceOver can identify headings, links, lists, image descriptions, and checklist states in document order.
- File → Open and window commands remain discoverable in the menu bar.

### M1-17 — Recover from file problems · Core

As someone opening unfamiliar generated files, I want clear recovery behavior so that a bad file does not derail my review.

Acceptance ideas:

- Empty files open successfully with a subtle empty-document message distinct from the no-file state.
- UTF-8 documents, including emoji and common line-ending variants, render correctly.
- Deleted, unreadable, or unsupported-encoding files produce a concise native error with a path and an actionable explanation.
- A failed open does not replace an already readable document.
- Repeated opening and closing leaves file bytes and modification times unchanged.

### M1-18 — Read substantial outputs smoothly · Core

As a reviewer of a long AI report, I want opening and scrolling to remain responsive so that NeoMD feels lightweight.

Acceptance ideas:

- Proposed benchmark: a 1 MB text document becomes readable within one second on an agreed baseline Mac, excluding remote image downloads. Confirm the machine and target before treating this as a release gate.
- A 10 MB stress document keeps the interface responsive and either renders successfully or explains a documented limit.
- Long unbroken text, large code blocks, and missing remote assets do not freeze the app.
- Local text, bundled rendering styles, and supported local assets work offline.

### M1-19 — Compare information in tables · Core

As a reader of generated comparisons, I want tables so that I can compare options easily.

Acceptance ideas:

- Render header rows, column alignment, and inline formatting within cells.
- Wide tables scroll horizontally within their own area without forcing the whole document to scroll sideways.
- Cell borders, text, and backgrounds remain readable in both themes and at larger text sizes.
- Preserve table structure and header associations for assistive technology.

### M1-20 — Recognize thematic dividers · Core

As a reader of long reports, I want thematic dividers so that major transitions are easy to spot.

Acceptance ideas:

- Render standard Markdown horizontal rules as visual separators with consistent spacing.
- Separators remain visible in both themes and fit the reading column when the window resizes.
- Distinguish divider syntax from list items and heading underlines in context.

### M1-21 — Find text in the document · Core

As a reader looking for a detail, I want Command-F search so that I can find visible text quickly.

Acceptance ideas:

- Command-F and the menu bar open a temporary native find interface; no permanent search control occupies the reading window.
- Search rendered text, including code and table cells, without matching hidden comments or formatting markup.
- Highlight the current match, scroll it into view, and support next/previous match through keyboard commands.
- Show a clear no-results state; Escape dismisses find and returns focus to reading.

### M1-22 — Adjust reading size · Core

As a reader with different vision needs, I want text-size commands so that I can read comfortably.

Acceptance ideas:

- Menu commands and keyboard shortcuts increase, decrease, and reset the reading size without adding window buttons.
- Headings, prose, code, lists, and tables retain their hierarchy and remain usable at each supported size.
- Changing size preserves my approximate reading position and does not modify the file.
- Proposed default: remember the chosen reading size across documents and app launches.

### M1-23 — See externally saved changes · Core

As a reviewer watching an agent's output, I want externally saved changes to appear so that I do not have to reopen the file.

Acceptance ideas:

- Refresh an open document after an external write settles, including when the writer replaces the file atomically.
- Coalesce rapid writes so that intermediate updates do not repeatedly interrupt reading.
- Preserve reading position relative to the current content where possible; use a nearby valid position if that content disappears.
- A temporarily unavailable or unreadable file keeps its last successful rendering with a quiet status message; recover when it becomes readable again.
- Refreshing never writes to the file or prompts to save it.

### M1-24 — Resume reading recent files · Core

As a returning reader, I want recent files and my reading position restored so that I can resume quickly.

Acceptance ideas:

- Recently opened files are available through the native recent-file menu, with a command to clear that history.
- Reopening a file restores its last reading position when possible, including after relaunching NeoMD.
- Remember positions independently for files with identical names in different folders.
- If a file has changed, restore a nearby valid position; if it has moved or disappeared, explain the problem without replacing another open document.
- Store reading history separately from the Markdown files so that their contents and modification times remain unchanged.

Tables are included through M1-19 and are described in GitHub's separate [table guide](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-tables). Thematic breaks and reference links are covered by the broader [GFM specification](https://github.github.com/gfm/). This draft does not expand the entire advanced-formatting guide into required scope.

## Coverage of the requested guide

This compact checklist maps the [basic formatting guide](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax) to the proposed backlog. The standalone-app adaptations above are product proposals.

| Guide topic | Story or disposition |
| --- | --- |
| Headings; styling text | M1-06 |
| Quoting text; quoting code | M1-07 |
| Supported color models | M1-13; explicit extension |
| Links | M1-11 |
| Section links; custom anchors | M1-09 |
| Relative links | M1-10 |
| Line breaks; paragraphs | M1-06 |
| Images; picture element | M1-12 |
| Lists; nested lists | M1-06 |
| Task lists | M1-08 |
| Mentioning people and teams | M1-14; local interpretation |
| Referencing issues and pull requests | Excluded by request |
| Referencing external resources | Excluded by request |
| Uploading assets | Existing assets: M1-12; authoring workflow deferred |
| Using emojis; alerts | M1-13 |
| Footnotes | M1-09 |
| Hiding content with comments; ignoring formatting | M1-15 |
| Disabling Markdown rendering | Omitted to honor the rendered-only product requirement |

The guide's outline menu and authoring shortcuts are website interactions, not additional rendering requirements. No outline button is proposed.

## Explicit boundaries

- No editing, saving, checklist mutation, formatting toolbar, or Markdown source view in Milestone 1.
- No issue/PR enrichment or repository-configured external-ticket autolinks. Their text stays readable, and explicitly written hyperlinks still work.
- No publishing, asset uploads, GitHub authentication, collaboration, or notification delivery.
- No promise of math, Mermaid diagrams, embedded video players, arbitrary HTML applications, or every extension an AI agent might emit.

## Review decisions before creating GitHub issues

1. Confirm that native window controls, the macOS menu bar, temporary system dialogs, and document links fit “no buttons.”
2. Confirm separate windows for distinct documents. M1-10 now uses the current document's folder for leading-slash paths, with on-demand read-only enclosing-folder access for the current session (approved by email, 2026-09-08).
3. Confirm the explicit color-swatch extension and account-free mention treatment.
4. Choose the minimum macOS version, baseline Mac, and performance target; these are not settled by this brainstorm. Supported image formats were settled for M1-12 on issue #12 (all system-decodable formats, documented tested subset).

## Suggested milestone review scenario

Open an agent-generated review packet from Finder containing a summary, nested plan, code, screenshots, relative links, alerts, footnotes, tables, and thematic dividers. Navigate to a second document, return to the first, switch the Mac's appearance, resize the window, find a phrase, increase the reading size, and select a passage. Have an external editor or agent update the file and verify that it refreshes without losing the reading context. Close both files, relaunch NeoMD, and reopen a recent file to verify position restoration. Repeat core navigation with the keyboard and VoiceOver, and repeat local reading offline.

Before declaring the milestone complete, maintain a small fixture set covering every included format plus empty, malformed, missing-resource, duplicate-heading, and large-document cases. Compare representative rendered fixtures against GitHub in both themes, separately checking the intentional local adaptations. Confirm that opening and navigation leave the original files unchanged.

Review outcome: agree on the core stories and open decisions, then split approved stories into GitHub issues. Nothing in this draft has been published.
