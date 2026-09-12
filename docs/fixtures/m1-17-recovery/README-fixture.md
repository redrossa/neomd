# M1-17 — inert recovery fixtures

[Canonical issue #17](https://github.com/redrossa/neomd/issues/17) · [approved permissive encoding policy](https://github.com/redrossa/neomd/issues/17#issuecomment-5642959135) · [validation map and non-interaction allowlist](../../m1-17-validation.md).

**Final triage ACCEPTED for implementation readiness**, exact source `c672c090b6c47a7c8247781af9cb4c3ec6b5dd54`. Triage verified bytes and source only. Every app decode/render/test/native outcome is **UNRUN**; native dialogs, alerts, windows, visual and AX coverage **DEFERRED/UNRUN**. This directory contains no executable test or fixture generator. Use owned temporary copies for later permitted filesystem units; never mutate checked-in originals.

## Inventory and reproducibility

The predecessor's byte fixtures were reused unchanged. `cases.json` contains exact sizes/SHA-256 and semantic oracles; the delivery MANIFEST authenticates all artifacts, including this README and `.gitattributes`. Commit these files as supplied. Byte identity, not editor re-creation or a random generator seed, is authoritative. `.gitattributes` disables normalization on BOM/mixed-ending/invalid-byte files and marks binary junk as binary.

| Fixture | Verified physical content | Expected purpose (not executed evidence) |
| --- | --- | --- |
| `empty.md` | Zero bytes. | Successful empty document. |
| `bom-only.md` | Exactly EF BB BF, 3 bytes. | Initial UTF-8 BOM stripped to empty. |
| `whitespace-only.md` | 11 bytes; hex `0d0a0a2020200d090a200a`. | Normalize to `\n\n   \n\t\n \n`; no rendered roots. |
| `utf8-emoji-endings.md` | 1,046 valid UTF-8 bytes; 17 CRLF, 4 bare CR, 6 bare LF; no final newline. | ZWJ/flag/skin tone/keycap/combining/RTL/CJK, internal invisible scalars, quote/list/code/table and final emoji. Preserve Unicode scalars except line-ending normalization. |
| `invalid-utf8.md` | 277 bytes; E9, lone 80, overlong C0 AF, surrogate ED A0 80, F5/FE/FF, Windows-1252 bytes. | Strict UTF-8 fails, existing permissive decoder should still produce text; ASCII prefix/tail retained. |
| `truncated-utf8.md` | 70 bytes ending F0 9F 8E (3 of 4 UTF-8 sequence bytes). | Existing fallback, not a rejection example; complete ASCII prefix survives. |
| `binary-junk.md` | 4,096 bytes; 15 NUL bytes; invalid UTF-8. | Bounded permissive decode/render compatibility with no exact legibility oracle. Never execute or launch anything from it. |
| `deep-nesting.md` | 58,369 UTF-8 bytes; 222 lines; 3,000 nested quote markers, 200 list levels (398-space maximum indent), 5,000 unmatched `[` before `inner`, 5,000 `*`, unclosed code fence. | Bounded best-effort render/release preserves sentinels. The standalone asterisks are a thematic break, not unmatched emphasis. No extreme stress/performance or arbitrary-input no-crash claim. |
| `folder-named.md/inside.txt` | Actual `.md` directory with a 113-byte inert child. | Explicit document-open rejects a folder; never treats inside.txt as its document. Existing local directory-link external-opening behavior is not changed. |

No actual unsupported-encoding rejection fixture was found or invented. Approval retains BOM / UTF-8 / Foundation inference / Latin-1. Non-UTF8/binary files are compatibility inputs, not a new filtering policy. Platform inference may vary: do not pin exact inferred non-ASCII scalars or promise every possible byte stream always decodes. Inject the defensive decoder failure to test failure text/state. Discrepancies must be reported, not “fixed” by making the decoder stricter.

Missing, permission-denied, nonregular and inert executable cases are logical recipes in `cases.json`, not checked-in denied/FIFO/executable files. Owned temporary setup/cleanup only. Inject permission errors for deterministic units; chmod(0) cannot prove TCC denial and privileged credentials may still read. Existing allowed FIFO test uses O_NONBLOCK plus validation; no arbitrary blocking FIFO read is authorized.

## Permitted later model/unit use

Follow the validation allowlist, not blanket test selection. Compare data after fixture setup and before teardown. Repeated cycles use `RegularMarkdownRead`, decoder, renderer and model `DocumentReadSession.close()` only; this establishes descriptor/read/model invariants, not native window-close behavior. Record exact source bytes and nanosecond mtime, ensure no sidecars. Intentional setup writes/chmod may change mtime/ctime and must not be misattributed to the reader. atime is not an acceptance invariant.

Native routing tests must inject a recording error sink and copied state: no actual NSAlert, window, picker, application launch, NSWorkspace action, presenter registration, host event, clipboard, theme or AX substitute. Retain #23 quiet deduplicated background retry status; explicit-open native-error intent is separate. New tests and actual evidence are worker-owned, not supplied by triage.

## Future user-owned native recipe — DEFERRED/UNRUN

This is documentation for later authorized final testing, **not permission to execute now**.

1. Work from disposable fixture copies. Record bytes and high-resolution modification times. Open zero-byte, BOM-only and whitespace files; compare their titled reader and subtle empty message with startup-picker cancellation/windowless no-file state. Do not reintroduce an instruction window.
2. Open the mixed-ending UTF-8 fixture. Inspect complete emoji/combining/RTL/CJK content, literal code lines, table cells and final emoji in both appearances. Open invalid/truncated/binary copies as permissive compatibility inputs; do not expect unsupported-encoding rejection alerts. Open the bounded malformed fixture and check readable sentinels without claiming performance coverage.
3. Retain a readable document and reading position. Attempt a known absent path via applicable Open Recent/Finder/local-link routes, an actually inaccessible owned file, and an explicit folder-as-document route. Expect concise native error with complete attempted path and an actionable explanation; never replace the readable document. Picker restrictions may prevent selection of a directory: that is not native error coverage by itself.
4. With multiple readers, use ordinary and additional-reader link failures, change active reader during the pending operation, cancel/close/replace the source where meaningful. Observe error ownership and no redirected or duplicate alerts; another reader remains untouched. Verify native keyboard dismissal, focus restoration, long path wrapping and VoiceOver. Actual privacy/volume scenarios require user-owned authorization/resources; do not alter system security to force them.
5. Temporarily move/delete/deny an already displayed owned file and restore readable content. Observe #23's quiet retrying status and last rendering, not repeated modal alerts. Same-content and changed-content recovery clear status. Presenter-delivery behavior is not established by unit injection.
6. Repeat real opening/closing, including failures, and compare bytes/mtime; no save prompt or source-side metadata/sidecar writes. Intentional external edits are separate baselines. Native read-only/closing behavior cannot be inferred from model close tests.

All steps remain deferred; no UI/E2E/manual scripted interaction or host/event substitute is authorized. Preserve #14 deferral and #36/#38 known failure records; no business/milestone acceptance is implied.
