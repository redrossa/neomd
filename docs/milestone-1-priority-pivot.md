# Milestone 1 priority pivot after M1-13

Status: **User-requested goals/order published; M1-P4 formats, replacement intent and sandbox removal explicitly approved.** This staged amendment records the revised live #43 contract, not implemented behavior or acceptance. The concrete [native ownership plan](m1-p4-native-navigation-plan.md), Command-N picker and one-file-at-a-time batch policy are [approved](https://github.com/redrossa/neomd/issues/43#issuecomment-5626782971). This amendment takes precedence over historical starter-window, separate-window and app-managed folder-access policies only as explicitly stated below.

## Business outcome

Make launching, closing and following links behave like a minimal native Mac reader before adding the remaining Markdown features.

## Approved order and publications

After completed #13, implement sequentially:

1. [#40 — M1-P1: Native startup Open dialog](https://github.com/redrossa/neomd/issues/40)
2. [#41 — M1-P2: Stay running without windows after last close](https://github.com/redrossa/neomd/issues/41)
3. [#42 — M1-P3: Pointing-hand link cursor](https://github.com/redrossa/neomd/issues/42)
4. [#43 — M1-P4: Active-window opening without app-managed folder grants](https://github.com/redrossa/neomd/issues/43)

Then resume #14–24 in their original order. The [milestone description](https://github.com/redrossa/neomd/milestone/1) records the full numbered sequence. User explicitly requested creation and the priority pivot; no new milestone was created. Canonical GitHub issue statements/checklists are the implementation contracts.

## Stories and acceptance scope

### M1-P1 — Native startup Open dialog

As a reader launching NeoMD without an open file, I want the native macOS Open dialog instead of a starter blank window so that I can choose a document immediately.

- [ ] Launch without a document presents the native Open dialog without a blank/instruction window.
- [ ] Explicit file-opening launch opens the document without an unnecessary startup panel/window.
- [ ] Cancel leaves the app running without a blank window; File > Open and Command-O remain available.

Supersedes #2's no-file instruction scene. Actual empty files are unaffected. Native file picker, not a custom browser. Labels: `enhancement`, `user-story`. First in the pivot; last-document closure is P2.

### M1-P2 — No-window state after closing

As a reader closing my last document, I want NeoMD to remain running without windows so that closing a document does not create another window or quit the app.

- [ ] Last close leaves the app running without reader/starter windows.
- [ ] Last close does not automatically display an Open dialog.
- [ ] File > Open and Command-O work without windows and create a reader when a file is opened.
- [ ] Close neither prompts to save nor modifies source bytes/mtime.

Depends on P1's opening flow; preserve Quit. Dock reactivation is not a newly specified behavior. Labels: `enhancement`, `user-story`.

### M1-P3 — Link cursor

As a reader following references, I want a pointing-hand cursor when hovering links so that clickable destinations are recognizable.

- [ ] Actionable text links show a native pointing hand, including web, local, internal and footnote links.
- [ ] Actionable linked images show a pointing hand over their clickable area.
- [ ] Leaving links restores the appropriate cursor; ordinary text is not a hand region.
- [ ] Hover never activates links or changes selection, clicks, keyboard or contextual menus.

Ordered after P2, no permission dependency. Cursor-only; P4 owns routing changes. Labels: `enhancement`, `user-story`.

### M1-P4 — Active-window navigation without app-managed folder grants

As a reader opening Markdown files, I want links, File > Open / Command-O and file drops to replace the current window’s document without app-managed folder-permission requests, and only Command-N to explicitly create another window, so that navigation feels direct.

Live #43 acceptance criteria (all remain unverified):

- [ ] A normal click on a supported local document link opens the target in the current reading window rather than creating a new window.
- [ ] File > Open / Command-O and file drops replace the active window’s document. Command-click no longer requests a new window; only Command-N explicitly creates another window. Command-N shows a single-file picker and creates the additional reader only after successful selection/preparation; cancellation leaves existing windows unchanged. A successful open with no windows creates the first reader. Multi-file Finder/Dock/drop requests show one-file-at-a-time feedback without replacing current content or creating extra windows.
- [ ] Disable App Sandbox for the NeoMD app in Debug and Release and remove the app-managed enclosing-folder permission workflow. Do not introduce remembered folder grants. Retain read-only application behavior and handle remaining macOS privacy/filesystem restrictions honestly; sandbox removal is not a promise of unrestricted access.
- [ ] Failed, missing or inaccessible targets retain the last readable document and show actionable feedback; navigation remains read-only.
- [ ] Preserve existing path/fragment resolution and explicit-only link activation unless a further product change is agreed.

Ordered after completed P3/#42 and before #14. Revises #10's opening/session-folder-grant policy and #3's separate-window policy for local links, File > Open / Command-O and drops. Labels: `enhancement`, `user-story`.

**Explicit user decisions recorded in the revised issue:**

- Markdown-only native reading; other safe files use default apps and apps/executables are reveal-only in Finder. No additional embedded viewer.
- “command open or File > open should also change the current window. drag and drop file should also change the current window opened file. you only open a new window if the user does a command n”. This supersedes the former Command-click-new-window criterion. An already-open target does not justify focusing another window instead of replacing this one.
- After App Sandbox/distribution consequences were explained: “ok we need that disabled then”. App Debug/Release sandbox removal is intentional, not a test workaround. No Mac App Store compatibility, writes, arbitrary execution, other security-control changes, remembered-folder setup or bookmarks are approved.

**Necessary design scope:** app-owned public NSDocument/NSWindowController ownership with SwiftUI reader hosting, one staged read/decode/render commit per captured destination window, and per-window fragment delivery. Keep source content/state on failure; no private DocumentGroup manipulation or open-then-close shortcut. Remove `FolderAccessSession` and its local-link and image consumers. Images retain alt/unavailable feedback with honest OS-access guidance instead of Allow-folder UI. OS privacy/POSIX/ACL/volume failures remain possible; NeoMD does not bypass them. Preserve the renderer, existing path semantics, native startup picker and windowless last close.

**Final approved decisions:** The user answered “1. yes, 2. yes”. Command-N presents a native single-file picker and creates the additional reader only on success; zero-window opening creates the first reader on success. Open/New use single selection; multi-Markdown Finder/Dock/drop batches receive “one file at a time; use Command-N” feedback without replacing content or creating windows. Cancel changes no committed reader. These are requirements, not unresolved proposals. See the [design](m1-p4-native-navigation-plan.md) and [fixture catalog](m1-p4-fixture-catalog.md). No grant-persistence or format question remains open.

P1–P3 are already closed; this design does not reopen them or authorize #14.

## Delivery and validation

Use the authorized sequential triage → worker → coordinator merge loop, without a reviewer stage. Triage owns reproducible fixtures/final-testing documentation; workers report actual evidence. The latest user instruction, “pls dont do e2e testing”, supersedes the earlier per-story interaction mandate and #13-only waiver wording: build and relevant units are the current implementation gates. Further UI/E2E and manual scripted end-to-end testing is stopped; interactions remain DEFERRED/UNRUN and unverified, not passed, pending renewed user authorization. Preserve #40 pre-waiver evidence and unresolved outcomes in `docs/m1-p1-validation.md`, as well as #13 C5/#38 and #36 deferrals, historical failures, and user-owned final combined milestone acceptance. No automatic milestone closure.
