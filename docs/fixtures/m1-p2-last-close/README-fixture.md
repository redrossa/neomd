# M1-P2 last-close fixtures

Issue: https://github.com/redrossa/neomd/issues/41
Inspection base: `823809000f25a2c45ac4c2c8510d36962c6cdcbc`.
Status: **DEFERRED/UNRUN** behavior validation; authored reuse data only.

Reuse the three committed M1-P1 documents, without redundant copies in version control. `manifest.json` gives exact repository-relative paths, byte counts and SHA256 values, verified against the M1-P1 manifest at triage.

- `../m1-p1-startup/launch.md`: first reader; exact rendered paragraph `M1-P1 EXPLICIT FILE CONTENT.`.
- `../m1-p1-startup/Meeting café.MD`: independent second reader/reopen target; exact paragraph `M1-P1 UNICODE FILE CONTENT.`; filename includes a space, NFC U+00E9 and uppercase extension.
- `../m1-p1-startup/empty.md`: zero-byte real document; expect a filename-titled reader and `This document is empty.`, never confuse it with no windows.

No links, images, network, clipboard or permission setup is needed. No new document bytes are authored for M1-P2.

## Future setup only — not authorization to execute

After renewed user authorization, copy these documents to a fresh owned temporary folder, set copied mtimes to Unix 1700000000, and snapshot exact bytes plus nanosecond mtime before opening. Compare after each close/reopen/cancel cycle and explicit Quit. Never open the repository originals as mutable test fixtures; remove only the owned copies afterward. Keep unrelated NeoMD sessions and user preferences untouched.

The cumulative catalog M1-P2 entry records criterion-linked scenarios. All app interactions, source-immutability observations, screenshots and window timelines remain **DEFERRED/UNRUN, not passed**. Existing M1-P1 historical results are not M1-P2 evidence. No UI/E2E/manual scripted flow, appearance change, permission grant or clipboard operation is currently authorized.
