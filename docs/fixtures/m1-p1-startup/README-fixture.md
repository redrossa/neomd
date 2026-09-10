# M1-P1 startup fixtures

Issue: https://github.com/redrossa/neomd/issues/40
Status: authored fixture data; no app/test execution or acceptance claimed.

- `launch.md`: ordinary UTF-8 LF Markdown; heading `Startup document`, paragraph `M1-P1 EXPLICIT FILE CONTENT.`.
- `Meeting café.MD`: filename uses NFC U+00E9, space and uppercase extension; heading `Unicode startup document`, paragraph `M1-P1 UNICODE FILE CONTENT.`.
- `empty.md`: exactly zero bytes; must open a real filename-titled reader with `This document is empty.`, not be treated as no open file.
- No links, images, permissions changes or network dependency.

Copy all three document files to a fresh owned temporary directory (not the repository). Set copied mtimes to Unix 1700000000, snapshot exact bytes and mtimes before launch, and compare after each scenario before removing only the owned copy. The manifest hashes describe authored bytes, not filesystem mtimes.

Use the cumulative catalog's M1-P1 append entry for cold launch, native panel, cancellation, explicit file request and final-milestone actions. UI tests must load these bytes rather than maintain divergent inline fixture copies. Preserve unrelated app instances and source documents. No clipboard operations or security/Automation permission changes.
