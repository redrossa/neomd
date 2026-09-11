# M1-P5 / #48 — focus-decoration fixture packet

Status: **TRIAGE DATA ONLY. All app interaction, visual and assistive-technology checks below are DEFERRED/UNRUN, not passed.** Current authorization is a Debug build and relevant non-interaction units; these instructions do not authorize an app launch, UI test, scripted interaction or system-setting change. See [validation record](../../../m1-p5-focus-validation.md).

## Deterministic content

All text is UTF-8 with LF endings. Preserve exact files; no generated IDs, absolute paths, network resource, executable program or embedded script is required. The SVGs are authored inert rectangles, 96×32, with different colors to distinguish the two local assets.

| File | Purpose / expected content |
| --- | --- |
| `focus.md` | Wrapping two-link paragraph; linked heading/list/task/quote/alert; repeated footnote and generated returns; short and overflowing code; linked and unlinked local images; link-plus-image paragraph capable of displaying the existing Retry button; ordinary selectable text; distant internal destinations. |
| `viewport-control.md` | No links, images or footnotes: ordinary selectable text, vertical overflow and one horizontal code block. Separates reader/native focus from the custom link-block overlay. |
| `img/badge.svg` | Readable green/white local image for linked and unlinked presentation. |
| `img/private.svg` | Readable purple/white local image; only a future disposable copy may be made inaccessible to exercise Retry. A missing image is not a substitute for this permission case. |

The fixtures are not parser or performance additions. The writer deliberately keeps all navigation internal; selecting either destination should never launch another application. Wide code is intentionally much wider than the current 760-point maximum reading column. Actual overflow and distant landing still require future app observation.

## Future user-owned setup and isolation

Only when the user authorizes final interaction testing:

1. Copy this complete directory to a new, uniquely named owned temporary directory. Never open or change the repository fixture copy. Keep both image paths relative to the two Markdown documents.
2. Before opening, inventory each regular file by relative path, exact bytes (or SHA-256), byte length and nanosecond modification time (`Path.stat().st_mtime_ns`). Save the inventory outside the fixture folder. Record app commit, macOS/Xcode versions, appearance, window size and current keyboard/accessibility settings. Do not change system focus or accessibility settings to hide an effect.
3. For the permission-control variant only, record the disposable `img/private.svg` mode, then remove its read permission before the initial inventory/open. Run as an ordinary user, not root. Keep `badge.svg` readable. Verify the app actually reports inaccessible status and displays Retry; if OS permissions prevent this setup or no Retry appears, mark the control check unverified rather than replacing it with a missing image or changing privacy permissions.
4. Open the disposable files through normal File > Open or Finder Open With. Use an explicitly new window only for the optional two-window comparison. Never disturb an unrelated existing reading session. No network, browser or clipboard access is needed.
5. After each permitted session, compare the same relative-file set, bytes/SHA-256 and nanosecond mtimes with the inventory. Both bytes and mtimes must match. Record any source change as a defect; a matching checksum alone is insufficient. Restore only the owned private-image mode before cleanup. Close only fixture windows and delete only the owned copy/inventory.

## Deferred criterion-specific observations

| Criterion | Future action / observable expectation |
| --- | --- |
| C1 | In `focus.md`, traverse into each link-action stop using existing Option-Tab / Option-Shift-Tab. A wrapping paragraph, linked heading, list/task, quote/alert, footnote and linked image must not gain an enclosing blue border/glow. Keep selected-link-local treatment; it is not the removed enclosing rectangle. |
| C2 | Test ordinary Tab separately from NeoMD's existing Option-Tab traversal. At reader focus, link actions, native-text stops and overflowing code, record actual first-responder/focus ownership where observable. Repeat in `viewport-control.md`; no link-block overlay is eligible there. There must be no enclosing viewport/window-content focus glow. Record native-window chrome, content bounds, current target and whether drag targeting is active separately; do not infer that every blue outline has one cause. |
| C3 | Preserve distinct text and link-action stops, exact forward/reverse order, actual native-control handoff at boundaries without wrapping, reader Page Up/Down, horizontal code arrows/Home/End and Escape/page return, and unchanged link Left/Right selection plus single Return/Space activation. A FocusState value or lack of visible outline alone is not proof of focus acquisition. Confirm actual internal landing and generated footnote returns. |
| C4 | Select ordinary and linked prose, including Shift-arrow selection, without using the clipboard. Highlight remains legible. Links retain normal underlines, adaptive color and pointing-hand cursor. Existing Retry and normal native controls retain their ordinary indicators. Intentionally drag a disposable Markdown file over the reader: the drop-target outline remains during targeting and disappears when canceled; do not confuse it with focus or silently drop/replace the document. |
| C5 | Compare every fixture file's exact bytes and modification time before/after permitted reading, navigation, selection, focus and close. No source writes are allowed. |

Repeat relevant observations in light/dark appearances and at 900×720 and 480×720. Appearance changes require renewed user authorization; restore prior state. Include user-observed VoiceOver text/link/heading/task/footnote announcements and ordinary control semantics using already-authorized facilities. Do not grant Accessibility/Automation permissions or change global keyboard/focus settings. No new replacement-focus-indicator design is required by #48.

## Result record

All rows currently: **DEFERRED/UNRUN**. A later tester records exact source head, fixture hashes, each actual action/target/result, visual evidence where available, and failures or unavailable coverage. Unit-model/environment checks cannot mark the above native visual/keyboard/selection/VoiceOver rows passed. Preserve existing #36 and #38 deferrals; neither is diagnosed or fixed by this packet. Completion of #48 does not resume #14–24 or accept/close the milestone.
