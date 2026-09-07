# cmark-gfm for NeoMD

Pinned upstream: <https://github.com/github/cmark-gfm/tree/499789b49373bfa045d0e7547e5ee63444c77bca>, version 0.29.0.gfm.13.

Source obtained from the commit-addressed codeload archive (not the synthetic Git history in the triage scratch directory):

```
https://codeload.github.com/github/cmark-gfm/tar.gz/499789b49373bfa045d0e7547e5ee63444c77bca
SHA-256 f30454a8fcda0baf6f487da0e099fca08824063f19c816be9b8933e4d1bd26ba
```

## Offline integration and inventory

`Package.swift` exposes a static C library. Xcode references this local package; app builds neither fetch dependencies nor generate parser code. The package enables the two upstream static-export definitions, with private header search paths for `src`, `extensions`, and `generated`. No signing, sandbox, deployment, or app identity settings change.

`PRISTINE.sha256` inventories and hashes every copied upstream `.c`, `.h`, and `.inc` file before patches. The inventory was checked against the pinned `src/CMakeLists.txt` and `extensions/CMakeLists.txt`. `src/main.c` (CLI) is excluded. Generated scanners are included; re2c inputs, test/spec files, build systems and tooling are not. All core extension implementations are linked because registration references them; tagfilter is not attached to parsers.

`generated/config.h`, `cmark-gfm_export.h`, and `cmark-gfm_version.h` are the static-only CMake configure outputs for the pinned tree on macOS/Clang. They are committed, not regenerated during builds. There is no separate extension export header in this tree: its public API uses the core export header. Public headers are copied into `include`; internal upstream headers remain under their original source directories. `SOURCES.sha256` covers all source/header copies, generated headers, package manifest, patches, pristine manifest, and notices. Run from the repository root:

```sh
Scripts/verify-cmark-vendoring.sh
```

The check is offline: verify post-patch hashes, reverse patches in an owned temporary copy, compare pristine hashes, reject source inventory additions, and compare the app-bundled notice with `COPYING`. It does not modify vendored sources.

## Isolated modifications

1. `0001-tasklist-nested-and-empty-items.patch`: parser-owned recognition relative to the newly opened item's first nonspace offset, not raw line start. Supports quoted and empty tasks; rejects formatted, escaped, code and later-paragraph lookalikes. `CMarkDocumentTests` pins 17 positive and 13 negative cases.
2. `0002-retain-reference-spelling.patch`: immediately before a resolved footnote reference's literal is replaced with an ordinal, copy that reference's original label into its otherwise unused node user-data slot. The node allocator allocates/frees the copy via the stock user-data destructor API. Definition identity still comes exclusively from `cmark_node_parent_footnote_def`. No source positions, reconstructed definition labels, parser re-entry, or source rewriting. The Swift adapter must copy the spelling while the tree lives; no caller may replace this reserved user-data slot. Tests cover different case and Unicode spellings inside links and image alt text.

`CMarkDocument` registers extensions once, then holds a private static `NSLock` across parser creation, attachment, feed and finish, releasing with `defer` before adaptation. Pinned `blocks.c:process_inlines` toggles process-global `SPECIAL_CHARS`/`SKIP_CHARS` in `inlines.c`; once-only registration alone is insufficient. This [approved concurrency correction](https://github.com/redrossa/neomd/issues/9#issuecomment-5573078799) trades simultaneous C-parse throughput for deterministic semantics. Rendering stays off-main and trees remain per-render; independent Swift adaptation remains concurrent.

Audit: adapter calls in `node.c` read node links/type/heading/list/footnote/user-data fields. Literal, fence-info and URL getters call `chunk.h:cmark_chunk_to_cstr`, which may allocate/mutate only the owning node's chunk. Extension type-string/task-state getters read fixed registered type IDs and node fields. `cmark_node_free`/`S_free_nodes`, table opaque destructors, the reference-spelling destructor, `cmark_parser_free`/`cmark_parser_dispose`, and reference/footnote map destructors free only owned nodes/buffers/lists. None touches inline classification tables or unregisters shared extensions. The default allocator (`cmark.c`) delegates to libc allocation/free, not the optional global arena allocator. Thus cleanup needs no additional lock and cannot nest the parsing lock. One tree must not be adapted by multiple callers. No Sendable C-pointer wrapper is exposed; the adapter returns owned Swift values before document destruction. The unchanged 16-worker × 40-parse regression verifies exact strike text/attributes while adaptation and cleanup overlap.

## Notices

`COPYING` is preserved verbatim, including the complete core and incorporated-code notices. The same bytes ship as `NeoMD/CMarkGFM-LICENSE.txt` in the app resources. This distribution includes the two modifications above. The upstream spec and test software mentioned in the full notice are not vendored.

## Universal adapter

`MarkdownBlockRenderer` uses this package for every document. `CMarkBlockAdapter` iteratively maps the AST into owned Swift blocks and attributed text; no Foundation Markdown parser or source-position bridge remains. Reachable footnotes are discovered by actual definition identity with a visited set. Generated anchors are globally allocated after authored destinations are collected, and references/backlinks use the exact identity-mapped allocations. The adapter preserves original ineligible reference spelling before releasing the parser tree. Rendering tests, including the 30-case task matrix, exercise the packaged sources.
