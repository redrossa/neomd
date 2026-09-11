# M1-24 inert history fixture packet

Readiness: ACCEPTED at `acc932318bda21a9cafde3e2ea53d612d1bcbe5a`. Every outcome below is a planned oracle, not a passing test. No app interaction was performed. See [validation map](../../m1-24-validation.md).

## Inventory and reproducibility

- `alpha/Report.MD` and `beta/Report.MD`: distinct local locations sharing the exact basename/case. Alpha includes a named checkpoint, explicit empty/missing fragments, a long code target, duplicates, nested text and Unicode. Beta supplies a different checkpoint.
- `changed-prefix.txt`: exact UTF-8 insertion. A changed alpha version is this file's bytes concatenated with the unchanged `alpha/Report.MD` bytes. This adds #15 metadata plus new content and shifts integer IDs while retaining alpha's saved content. Construct only in worker-owned temporary storage, never overwrite the catalog fixture or a user's document.
- Deleted-target variant: from an owned alpha copy, remove the entire paragraph beginning “The amber checkpoint paragraph” while retaining its preceding heading and following code block. Capture that paragraph before removal. Expect a surviving nearby content boundary, not an old integer-ID match. `mapping-cases.json` specifies exact target/neighbor tie policy independently of parser-generated integers.
- `mapping-cases.json`: complete before/after text-entry arrays with expected ordinal/fraction or edge. Treat strings as semantic snapshot entries; compute digests using the implementation normalization. These are not app-schema fixtures or executable code. Add rendered-document integration cases for metadata/nesting rather than only synthetic arrays.
- `state-cases.json`: owned-store/injected-model event scenarios. Ordering, clearing, fragment and fresh-reopen input expectations are independent of native AppKit timing. Do not implement them by sending UI events or constructing native hosts.
- `absent/Report.MD` is intentionally absent. No network image, executable file, permission prompt, bookmark or folder grant is needed.

## Owned non-interaction setup (later worker only)

Create a unique temporary fixture root, copy only these inert bytes and point the history storage dependency at a different owned subdirectory. Keep URL identity assertions relative to that root. Prepare changed/deleted/renamed snapshots directly under that root; invoking the pure loader/remapper is allowed, registering observers or waiting for host notifications is not. For missing/moved failure, rename an owned copy then call the injected read/stage boundary; do not open Finder, menus or windows. Source immutability oracle compares exact bytes and modification times before/after actual owned read/capture/store/resolve calls; source setup changes occur before the baseline. Never reset a source timestamp to make an assertion pass.

State tests use fixed serials, owned session IDs and manually released continuations/logical time. Recreate the store instance against the same owned storage to establish durable round-trip; that is not a real app relaunch pass. Clear only the injected store. Never call production `clearRecentDocuments`, load the real recents list, change user defaults, or touch production Application Support during a unit run.

## Future user-owned native recipe — DEFERRED/UNRUN

Requires renewed authorization; not an instruction for the current worker to interact with the app.

1. In an isolated user-approved history environment, open alpha and beta, observe native Open Recent location labels, read at different places, close, and reopen each through the native menu. Confirm independent positions and no source bytes/mtime changes.
2. Quit successfully, relaunch, deliberately reopen alpha (do not expect automatic reopen-all-windows), and confirm its last captured paragraph/code fraction or edge. Confirm window title/location, keyboard access and no save prompts.
3. Reopen owned alpha after prefix insertion, target deletion and complete rewrite. Expect retained content where available and deterministic nearby valid fallback otherwise. Verify real lazy layout across narrow/wide windows and table cells when #19 is integrated; do not infer this from pure geometry tests.
4. Open two independent alpha readers; read A then B, close B then A, reopen. B's later successful captured position should win, not last-close order. Other live readers must not jump. Repeat close/quit during pending navigation/storage and cancel delayed restoration through genuine user scroll.
5. Navigate to an explicit checkpoint/empty fragment/missing fragment when history points elsewhere. Explicit intent wins; a missing fragment gives existing feedback, not silent history fallback. Re-selecting the same displayed URL without a fragment preserves that reader's live place.
6. Rename/remove an owned recently opened file and attempt reopen while another document is readable. Expect concise path/recovery feedback and retained other reader; do not search by basename or open an unrelated file. Restore the owned file and retry.
7. Clear native recent history. Confirm both menu and private remembered positions clear, existing readers stay where they are, and delayed pre-clear work/idle close cannot resurrect history. Newly opened/read content can subsequently be remembered.
8. Include native keyboard/menu discovery, VoiceOver/AX, appearance, real reopen/relaunch/scroll, asynchronous quit flush and source immutability observations in final user-owned evidence. All remain DEFERRED/UNRUN. Preserve #14/#36/#38 and their exact existing deferrals; no equivalence or extended waiver is implied.
