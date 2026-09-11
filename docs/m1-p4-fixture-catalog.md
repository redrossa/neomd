# M1-P4 / #43 — staged fixture catalog

Status: **Research inputs only; every new interaction is DEFERRED/UNRUN.** No executable tests/prototypes, app launch, build, unit run, UI/E2E or manual scripted interaction was performed. These fixtures do not establish implementation correctness. This catalog supplements rather than replaces the historical cumulative fixture catalog and its failures/deferrals.

Base: `9db15f86682dcd8c0c97290d541186c006d8f5bb`. Contract: https://github.com/redrossa/neomd/issues/43. Design/default proposals: [native navigation plan](m1-p4-native-navigation-plan.md). [Binding approval](https://github.com/redrossa/neomd/issues/43#issuecomment-5626782971) settles Command-N single-file picker and one-file-at-a-time batch rejection. Historical research status above describes fixture authorship, not subsequent worker validation; see [worker evidence](m1-p4-validation.md).

## Minimal inert packet

Relative root: `docs/fixtures/m1-p4-navigation/`.

| File | Purpose/oracle |
| --- | --- |
| `source.md` | Distinct source marker; links, image and linked image; failed opens must leave this committed reader/state. |
| `targets/Shared notes.MD` | Space/uppercase extension, first/second fragments, same-target links and return via `../`. |
| `other/Shared notes.MD` | Same basename, different directory and body; native title/location and content must agree. |
| `empty.md` | Exactly zero bytes; succeeds as an actual empty document, not no-reader UI. |
| `restricted.md` | Ordinary readable specimen; later access-denial setup is on a disposable copy only. No denial exists just because of this filename. |
| `notes.txt` | Inert safe external file. Native embedded reading must not expand to plain text. |
| `directory.md/README.txt` | Nonregular Markdown-looking path. Document open/drop must not read a directory as data; linked directories retain Finder handling. |
| `images/diagram.png` | Byte-for-byte copy of existing `m1-10-nearby-links/docs/img/diagram.png`, not a new decoder or color fixture. |

`intentionally-missing.md`, `images/intentionally-missing.png` and the authored missing section are intentionally absent. Do not create them while preparing the normal packet. No real executable, app bundle, shell command, permission-altered fixture, symlink or OS-protected file is added. The new packet is small; it is not a long-scroll/performance fixture.

The handoff's `MANIFEST.json` records all staged artifact SHA-256/size/modes and source-base blob/SHA-256 values. The copied PNG's base hash is included. Manifest excludes itself to avoid circular hashes. Staged file creation mtimes are not portable expected mtimes: later authorized unit setup must snapshot its **own disposable copies** before opening and compare exact bytes plus mtime afterward. Original/staged inputs must not be mutated by validation.

Reuse, without duplicating/reinterpreting, existing `docs/fixtures/m1-10-nearby-links/`: `docs/guide.md`, `docs/intro.md`, parent `README.md`, `docs/root-target.md` versus root `root-target.md`, `docs/my notes.md`, `docs/café.md`, `docs/100%.md`, and nested `docs/sub/deep.md`. They provide leading-slash/parent/percent/Unicode and sufficiently long fragment-scroll text. Their old same/new-window/folder-grant instructions are historical and superseded only by revised #43; they are not new-policy oracles.

## Criterion matrix and future non-interaction units

| ID / criterion | Data and later unit oracle | Native interaction evidence |
| --- | --- | --- |
| P4-01 / C1 | Source → target first/second via normal and Command activation **same destination intent**. Inject dispatcher/window identities; assert no new-window intent and one winning commit. Linked image/keyboard/context/AX URL callback policy is the same. | Same physical NSWindow, text selection/hover, actual gestures and source-window focus DEFERRED. |
| P4-02 / C2 | Open-panel request captures reader A before panel becomes key; target choice commits to A even if key status changes. Cancel changes no snapshot. Drop captures receiving reader; unsupported URLs filtered. | File menu/Command-O, picker, Dock/window drop and active/native focus DEFERRED. |
| P4-03 / C2 | Zero-reader reservation creates first reader only on successful acquisition. Command-N reservation never replaces existing readers. Generation checks prevent duplicate cold-window creation. **Picker-on-N and batch-rejection outcomes are approved requirements; actual native behavior remains unverified.** | Startup, no blank/transient window, Command-N actual creation, multi-file Finder/Dock delivery DEFERRED. |
| P4-04 / C1/C2/C5 | A and B already show the same native target; A replacement gets its own presentation/fragment request and does not focus/reset B. Verify per-window consume-once tokens, no-fragment clearing, old cancel not clearing new. Source self no-fragment retains current session. | Two real windows, positions, represented URLs/title popup and location reveal DEFERRED. |
| P4-05 / C3 | Static app Debug/Release setting diff and later signed-product entitlement inspection show sandbox removed without unrelated security edits. No folder-access callback/action/grant record remains. Image retry only retries loader. | Actual ordinary-folder access without app-managed dialogs, system privacy prompting/recovery DEFERRED. An entitlement inspection is not TCC evidence. |
| P4-06 / C4 | Missing file, denied access, directory-as-document, injected read/decode failure after successful probe, and canceled render retain old committed content/URL/title intent/generation. Error contains useful target/path and recovery direction. Retry image preserves text. | Real readable feedback, keyboard announcement/timing, old selection/scroll, native failure panels DEFERRED. |
| P4-07 / C4 | A starts slow request B then newer C; complete in reverse order. Only C commits. Close during acquisition; no commit/window recreation. Reject stale error and stale section. Shared candidate reserved by two destinations survives cancellation of one. Last reservation/window release closes only abandoned native document. | Actual rapid clicking, cross-window activation, native controller transfer/lifetime behavior DEFERRED. |
| P4-08 / C4 | On owned temporary files, compare exact data+mtime across success, failures, close model and actual rejected native write/rename/move/lock paths. A mere `Failure.readOnly` string assertion is not a write-path test. Inject workspace spy to verify executable/app targets reveal rather than open, including explicit file URLs and symlinks. | Close/Quit save prompts, native title mutation affordances, real Finder/default-app dispatch DEFERRED. No real executable/app should be launched to test this. |
| P4-09 / C5 | Existing resolver/decoder tests plus packet links retain current-folder `/`, `../`, spaces, Unicode, percent and exact-once fragments; missing section opens successful target then notices missing section. Literal file-scheme URLs are not reinterpreted as relative. | Actual scrolling and footnote return, keyboard/AX, light/dark, resizing DEFERRED; preserve #36/#38 history. |

### Access/race cases are not static-file magic

- Future non-root POSIX units may create a disposable copy, deny/read/restore its permissions in guaranteed cleanup. Do not chmod original/staged packets. Existing `LocalFileAccessTests` already demonstrates owned chmod/FIFO checks; a FIFO path must never be opened by a new loader. No FIFO or executable is created in this research.
- TCC-denied folders, disconnected volumes and privacy re-grants cannot be faithfully encoded in Git. Inject categorized read failures for policy tests. Real OS evidence remains deferred; never claim an injected `.inaccessible` proves sandbox/TCC behavior.
- `MarkdownTextDecoder` tries BOM, UTF-8, inferred encodings and ISO-Latin-1 fallback; do not fabricate a supposedly guaranteed “invalid UTF-8 means open failure” binary fixture. Inject decode failure at the loader boundary without altering accepted encoding behavior.
- Controlled loader suspension/completion is required to reproduce race order; large Markdown is not a deterministic race fixture and no executable race harness is supplied.
- Under the current user instruction, later units must not drive Open panels, mouse/keyboard events, actual NSWorkspace dispatch or synthetic end-to-end app sessions. Existing hosting tests with scrolling/native event injection are not automatically allowed just because their target is named `NeoMDTests`.

## Historical coverage requiring care after implementation

- `NeoMDTests/DocumentOpeningTests.swift`: current URL-global section expectations must become destination-specific; retain canonical identity/consume-once/cancel/newest invariants. Preserve lifecycle and drop-filter unit coverage under new ownership rather than deleting coverage wholesale.
- `NeoMDTests/LocalFileAccessTests.swift`: retain filesystem error/special-file coverage; retire only the obsolete `FolderAccessSession.suggestedFolder` expectation.
- `NeoMDTests/MarkdownImageHostingTests.swift`: obsolete access environment injection will need a compile adaptation if the key is removed. Do not run its scripted scrolling under this waiver or call it passed.
- `NeoMDTests/MarkdownDocumentTests.swift`, `MarkdownTextDecoderTests`, `DocumentLinkResolverTests`, `MarkdownImagesTests` remain preservation pointers, not proof of native transfer. Inspect individual tests before choosing a non-interaction subset.
- `NeoMDUITests/DocumentOpeningUITests.swift`, `NearbyFileLinkUITests.swift` and `DocumentImageUITests.swift` include historical new-window/refocus/folder-prompt assumptions. Annotate the superseded contract in documentation, preserve old failure evidence, and do not run or weaken these tests to get a green result. No UI test source is authored in this research.
- Catalog entries/P1 validation recorded before the waiver remain historical; all #43 native behavior is unverified. #36/#38 and final user-owned milestone acceptance are unchanged.
