# M1-16 inert selection/accessibility packet

[Issue #16](https://github.com/redrossa/neomd/issues/16) · [architecture approval](https://github.com/redrossa/neomd/issues/16#issuecomment-5642959049) · [validation and exact unit allowlist](../../m1-16-validation.md).

Triage **ACCEPTED implementation readiness** at `7217b46ac4d69b532dc67b944f2a45407e6f0570` (post-#21 find refresh), not implemented behavior. This packet is inert input/oracle data, **not executable tests**. All pointer/keyboard/clipboard/AX/visual observations are **DEFERRED/UNRUN**. Current worker gates are Debug build and explicitly inspected non-interaction units only. No clipboard-mutating tests, UI/E2E, manual scripted interaction, native event/window/host substitutes, AX actions or appearance switching. No reviewer stage.

## Files and reproducibility

All text files use UTF-8 and LF. Keep exact bytes; `mixed.md` intentionally has trailing code spaces, a literal tab, a blank first/final code line, decomposed `e` + U+0301, and all-space inline code. Do not run whitespace cleanup over fixtures. `projection-cases.json` uses explicit escaped scalars for independent expected strings; its lazy recipe is data, not a runnable generator.

| Input | Purpose / oracle |
| --- | --- |
| `mixed.md` | Metadata; heading levels 1–6; styled/escaped text; hidden comment sentinel; adjacent ordered/unordered lists, nested and empty read-only tasks; quote/alert; exact code; inline/standalone image states; GFM cells; unsupported literal HTML and code comments; footnote. Select actual rendered fragments, never raw source syntax. |
| `table-order.md` | First table has complete independent row-major expected strings including empty cell and reverse partial endpoints in JSON. Second table supplies local wide overflow, with prose outside both surfaces. |
| `recovery.md` | Closed malformed YAML: select displayed explanation and complete literal candidate, retaining delimiter/comment/link spelling as literal data, followed by normal body. Must not execute markup. |
| `refresh-before.md`, `refresh-after.md` | Two independent static versions, no file watcher or writer. Metadata/prose insertion renumbers IDs; selection endpoint paragraph and cell survive, while new interior text participates. Pure tests parse both values and re-derive fresh range identities. |
| `nearby.md` | Local explicit link target and independent-reader content; no automatic opening. |
| `diagram.svg` | Self-contained static 96×48 diagram, no scripts, external resources or actions. Loaded-state pure units may use in-memory state descriptors rather than load an image. |
| `absent.png` | **Intentionally absent. Do not create.** Supplies unavailable image fallback; no network required. |
| `projection-cases.json` | Independent string/range/table/code/metadata/refresh oracles and deterministic 256-paragraph lazy data recipe. Planned expected behavior, not observed output. |

Use existing `m1-15-content` fixtures for BOM/CRLF/CR, empty metadata and complex YAML; existing `m1-19-tables` for richer cell/AX structure; merged `m1-21-find/find-corpus.md` and `long-lazy.md` for independent find/selection mapping and lazy reveal preservation. Search excludes images/metadata separators/container explanations; selection includes actual visible fallback/explanation text and uses its own joins. Preserve the disclosed #21 exact-diacritic oracle discrepancy; do not normalize sibling expectations. Do not copy or rewrite sibling fixtures. A worker may parse copied strings or read these files in permitted pure units, and compare bytes/mtime after reading; never mutate checked-in inputs. Native content opening, refresh observation and document replacement are unrun.

## Future user-owned coverage inventory — not current instructions to execute

- C1: contiguous partial/full selection through >=3 lazy leaves, code, metadata and table cells in both directions; exact plain text/indentation, Unicode boundaries, empty cells and tab/newline joins; all-space code, literal recovery, images transitioning between fallback/loaded states. Verify actual explicit Copy/Select All behavior separately from pure string extraction. No agent clipboard-mutating test is planned.
- C2: ordinary text selection versus link click/drag/Command-click; Shift extension and native granularity; paging and separate text/link/overflow stops; visible link-local focus without an enclosing glow; local code/table overflow; ordinary Retry/find-field controls retain focus/selection precedence.
- C3: heading levels, links, image descriptions in each state, real list/item association and read-only task state-to-description order; empty/nested/adjacent lists; metadata reading order; existing table headers/rows/columns unchanged; hidden comments absent; offscreen content accessible without duplicate prose.
- C4: native File/Open, recent files and Window commands remain discoverable; Copy/Select All follow the active reader, not another window or the find field.
- Cross-story: refreshed presentation resolves fresh endpoint identities, no persisted render IDs, failed refresh preserves last-good state, unresolvable selection clears; no source bytes/mtime changes from reading; independent readers; light/dark, resize, lazy remount and #21 find highlights do not corrupt user selection. Find show/query/next/previous/dismiss must not replace selection, including overlapping matches in metadata/native code/table cells. Selection changes must not erase find decoration; genuine image/text replacement remaps both separately. Find-field Copy/Select All stays local to its ordinary field editor; find reveal remains focus-neutral. Selection gestures must not race automatic find reveal after inset/viewport changes; cancellation and refresh release only their own acquisition/busy state.

These observations require renewed user-owned native verification. Source/model evidence cannot mark them passed. Preserve #14 deferral and #36/#38 known failures/deferrals. Final combined milestone acceptance remains user-owned.
