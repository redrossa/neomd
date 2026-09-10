# Milestone 1 priority pivot after M1-13

Status: **User-requested goals and order approved; published.** Detailed unresolved decisions in M1-P4 remain open, not approved implementation choices. This amendment takes precedence over the original planning document's historical starter-window and local-link behavior where explicitly stated below.

## Business outcome

Make launching, closing and following links behave like a minimal native Mac reader before adding the remaining Markdown features.

## Approved order and publications

After completed #13, implement sequentially:

1. [#40 — M1-P1: Native startup Open dialog](https://github.com/redrossa/neomd/issues/40)
2. [#41 — M1-P2: Stay running without windows after last close](https://github.com/redrossa/neomd/issues/41)
3. [#42 — M1-P3: Pointing-hand link cursor](https://github.com/redrossa/neomd/issues/42)
4. [#43 — M1-P4: Local links in place and permission setup](https://github.com/redrossa/neomd/issues/43)

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

### M1-P4 — Local navigation and access

As a reader following local file links, I want a normal click to open the target in the same window without repeated folder-permission requests, and Command-click to open it in a new window, so that navigating local documents feels direct.

- [ ] Normal click opens a supported local document in the same window.
- [ ] Command-click opens it in a new window without replacing the source.
- [ ] Replace per-link folder requests with an explicitly agreed supported macOS permission/setup flow where access requires it.
- [ ] Failed/missing/inaccessible opens preserve the readable document with actionable feedback and source immutability.
- [ ] Preserve existing path/fragment resolution and explicit-only activation unless further changes are agreed.

Ordered after P3; revises #10 access/opening and #3 separate-window behavior for link navigation only. Labels: `enhancement`, `user-story`.

**Unresolved before P4 implementation:**

- Markdown-only in-place viewing versus additional local file types; other formats currently open in default apps.
- Supported macOS access model, denial/revocation and setup flow. Full Disk Access is not assumed to bypass App Sandbox. Sandbox removal, expanded entitlements or persisted broad access require an explicitly approved design; no automatic execution.
- Already-open target handling if document identity conflicts with requested same/new-window navigation.

P4 decisions do not block starting P1–P3. No scope expansion into images/other viewers or path semantics is implied.

## Delivery and validation

Use the authorized sequential triage → worker → coordinator merge loop, without a reviewer stage. Triage owns reproducible fixtures/final-testing documentation; workers report actual evidence. The latest user instruction, “pls dont do e2e testing”, supersedes the earlier per-story interaction mandate and #13-only waiver wording: build and relevant units are the current implementation gates. Further UI/E2E and manual scripted end-to-end testing is stopped; interactions remain DEFERRED/UNRUN and unverified, not passed, pending renewed user authorization. Preserve #40 pre-waiver evidence and unresolved outcomes in `docs/m1-p1-validation.md`, as well as #13 C5/#38 and #36 deferrals, historical failures, and user-owned final combined milestone acceptance. No automatic milestone closure.
