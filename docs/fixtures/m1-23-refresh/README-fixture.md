# M1-23 inert external-refresh fixture packet

Source base `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`; issue https://github.com/redrossa/neomd/issues/23. Triage accepted implementation readiness only. **No app, watcher experiment, build, executable test or interaction was run.** [Validation map](../../m1-23-validation.md) holds full criteria, inspected unit allowlist and worker evidence slots.

These UTF-8 Markdown snapshots and JSON recipes are data, not programs. `empty.md` is deliberately zero bytes. No network, linked applications, scripts, HTML execution or credentials are needed. Changes to the fixtures are test-writer actions only on disposable copies, never on the checked-in originals or a user's documents.

## Snapshot oracles

| Snapshot | Purpose |
| --- | --- |
| v1.md | Initial body; uniquely marked watched paragraph; two identical passages under duplicate headings distinguished by SOUTH/EAST vs NORTH neighbors; nested quotation/list/task/code. |
| v2-metadata-insert.md | Same watched paragraph and fraction after metadata/body insertion shifts render-local IDs. Leading YAML is intentional existing #15 content, not a new table feature. |
| v3-target-deleted.md | Target removed, immediate BEFORE WATCH / AFTER WATCH neighbors survive. Fallback should remain nearby. |
| v4-recovered.md | Short readable recovery after a missing/access failure. Not an encoding-rejection fixture. |
| empty.md | Successful settled empty external save, distinct from unavailable content. |
| cases.json | Logical burst/stale/ownership/recovery and copied-locator scenarios. Worker may implement pure/injected models and direct owned-file read tests; no host watcher experiment. |

Exact line endings are LF; accents/Japanese are Unicode fixture content. Literal code indentation is meaningful. The watched paragraph in v1 and v2 is identical. Tests should locate it by text and derive current IDs from each rendered snapshot, not embed old node numbers. The duplicate passage occurs twice; its neighbors establish the intended second occurrence.

## Current allowed use

Worker can read/render fixture strings in pure units, supply logical clock/revision/stamp/failure values to the refresh model, and call the low-level refresh snapshot reader directly on owned temporary files before/after deliberate replacement. No presenter registration and host-event waiting, NSWindow/NSHostingController, interaction driver or native event callback can be used as a substitute for deferred UI testing. No test implementation is supplied by triage.

Every filesystem test creates a unique owned temporary directory and removes only that directory. Snapshot bytes plus precise mtime **after each deliberate setup/external replacement** and assert the read-under-test changes neither. Do not reset timestamps on a source to conceal writes. Tests that deliberately set an owned fixture mtime or executable/permission mode must mark that as setup and compare subsequent reader behavior against the new baseline. For EACCES use injected errors; credentials may bypass an owned chmod denial. Never change actual user ACLs/TCC settings.

## Future user-owned native procedure — DEFERRED/UNRUN

This is a final-milestone recipe, not current authorization. Execute only after renewed user authorization in an isolated usable graphical session; record actual head, OS/Xcode, fixture hashes, timing, screenshots/observations and any limitations. Triage did not execute any step.

1. Copy v1 to a unique disposable local folder as `live.md`. Record bytes/hash and precise mtime. Open it in NeoMD through a normal explicit route. Scroll until WATCHED PASSAGE is near the viewport's reading line; record the visible passage/fraction. Open an additional independent reader of the same file and position it at the second repeated passage near SOUTH/EAST. Do not confuse this with #24 reopen-history acceptance.
2. From an external writer, replace the owned `live.md` with v2 using a temp sibling plus atomic replacement at the same pathname. Record the post-writer bytes/mtime. After it settles, expect revision TWO/metadata to appear in the existing viewers, each near its own original passage. No new reader, frontmost-window change, repeated jumps or stale original rendering. Compare source bytes/mtime again after NeoMD updates.
3. Exercise a rapid burst of deliberate owned v1/v2/v3 writes, including in-place truncate/write and atomic replacements, ending on a known snapshot. Observe that coalescing avoids a sequence of repeated interruptions and ultimately displays the settled final snapshot. A genuinely prolonged pause can be treated as a settled intermediate save; no finite debounce proves the author's intent. Record actual latency without inventing an approved performance SLA.
4. While viewing the watched passage, save v3. Expect BEFORE WATCH or AFTER WATCH nearby, not an unrelated old integer-ID target or an invalid/out-of-range position. Check nested quote reading point, top and bottom positions separately. Repeat amid explicit section navigation/user scrolling: newer user intent must override older automatic restoration. Do not make historical reflow/cue hangs disappear by omitting failures from the record.
5. Temporarily remove only the owned file, then restore v4 at the same pathname. Expect last successful rendering to remain, with a quiet nonmodal status, then automatic readable recovery. Repeat identical-content recovery and an owned access-failure case only where safe/authorized; no user permission/TCC mutation. Status must not announce repeatedly on every retry, erase a link notice or require reopening. Save stable empty.md and expect a legitimate empty-document state, not an error.
6. While preparation is pending, navigate one reader to another owned Markdown file or close it. Its old source must not overwrite the new document or revive its window. The other reader must continue to update independently. Closing the last viewer stops observation; quitting must not save the Markdown source.
7. Inspect light/dark quiet status, native keyboard reading/link navigation, selection/focus and VoiceOver announcement/reading order after refresh; no noisy enclosing-focus regression. Native images/lazy layout may settle after install, so inspect eventual position too. This remains deferred/unrun and is not established by pure locator math.
8. Verify no Save/Autosave/Versions prompts or source sidecars, unchanged bytes/mtime between intentional external writes, and no automatic link/application launches. Record failures/skips honestly; restore/remove only the owned fixture folder.

#36 native selection/reflow and #38 larger-size cue failures retain their existing dispositions; neither is fixed, equivalent or newly waived here. Known applicable defects block affected acceptance; do not infer a pass from this packet or from a later isolated test. #14 remains entirely deferred/open. Final combined milestone business acceptance stays with the user.
