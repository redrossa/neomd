# M1-P2 implementation evidence

Issue: https://github.com/redrossa/neomd/issues/41
Base: `823809000f25a2c45ac4c2c8510d36962c6cdcbc`.
Worker runtime: `openai-codex/gpt-6-astra`, low.

## Implementation and criteria

- C1/C2: `DocumentWindowLifecycle.documentWindowDidDisappear` removes tracked IDs and returns `.none`; the reader no longer schedules a delayed instruction window. All existing reader cleanup and coordinator notification remain. Lifecycle units cover final/multiple/duplicate/unknown closes, repeated reopen cycles and termination; coordinator forwarding and canonical section requests are covered.
- C3: native viewing `DocumentGroup`, dormant launch-suppressed instruction scene and its `ReadOnlyFileCommands` registration remain unchanged. No Open panel is requested by disappearance. Windowless File > Open/Command-O interaction is **deferred/unverified**.
- C4: read-only document and close policy are unchanged. `MarkdownDocumentTests` is supporting policy coverage, not proof of actual serialization rejection or native close bytes/mtime preservation. Save-dialog absence and source immutability during native interaction are **deferred/unverified**.
- Explicit Quit, native Dock/startup behavior, the nonterminating last-window delegate and termination-only folder-session cleanup remain unchanged.

`shouldShowNoDocumentWindow` is retained because dormant `NoDocumentView.onAppear` still uses it to dismiss ineligible instruction windows. The show directive and reader `openWindow` dependency are removed. No UI selectors or UI test sources changed. The obsolete expectations/setup listed in the cumulative catalog remain preserved for later migration, not passing tests.

## Validation

Proactive diagnostics on the three changed Swift files: zero diagnostics. Separate Debug build succeeded. The five selected unit suites executed **28 tests: 28 passed, zero failures/skips/expected failures**. No UI/E2E/manual scripted interaction test was run. Historical evidence and deferrals remain unchanged.

Commands (from the story checkout; output outside the repository):

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/neomd-41-worker/DerivedData build
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/neomd-41-worker/DerivedData \
  -resultBundlePath /tmp/neomd-41-worker/units.xcresult \
  -only-testing:NeoMDTests/DocumentOpeningTests \
  -only-testing:NeoMDTests/MarkdownDocumentTests \
  -only-testing:NeoMDTests/MarkdownFileTypeTests \
  -only-testing:NeoMDTests/MarkdownTextDecoderTests \
  -only-testing:NeoMDTests/DocumentLinkResolverTests test
```

Initial logs: `/tmp/neomd-41-worker/{build.log,units.log,unit-summary.json,units.xcresult}`. The worker handoff and PR record the exact committed/pushed head and post-commit repeat results; this avoids a self-referential commit hash in tracked documentation.

Triage artifact byte counts/SHA256 values, reused fixture hashes and both destination base hashes were verified before installation. The cumulative catalog's original 134989-byte prefix is preserved exactly. Fixture authorship belongs to triage; this document records worker evidence only. Implementation is ready for coordinator consideration, not native interaction acceptance or milestone acceptance.
