# M1-P4 / #43 — worker validation

Contract: [#43](https://github.com/redrossa/neomd/issues/43), [binding approval](https://github.com/redrossa/neomd/issues/43#issuecomment-5626782971). Base: `9db15f86682dcd8c0c97290d541186c006d8f5bb`.

## Implementation and evidence boundary

| Criterion | Implementation / non-interaction evidence | Deferred evidence |
| --- | --- | --- |
| C1 | Public AppKit document/controller shell; `addWindowController` transfers the existing controller to a prepared native identity. Window-bound requests and prepared SwiftUI subtree. Session and reservation tests. | Actual same NSWindow, selection, focus, scroll and sibling-viewer behavior. |
| C2 | Captured destinations before panels/awaits; single-selection Open/New; explicit new reservations; one-file batch policy; Finder replies after completion; native Recent and menus. Generation/cancel/closed-session and cardinality tests. | Native menu/picker/Command-N/Command-click, Finder/Dock/drop, startup arbitration and windowless close. |
| C3 | Exactly app Debug/Release sandbox YES → NO. Folder manager and all consumers removed; image Retry invokes existing loader only. Signed Debug/Release products have no sandbox entitlement. Image retry test. | OS privacy prompts/access recovery; no claim of unrestricted access or Mac App Store compatibility. |
| C4 | Off-main read/decode/render, regular opened-file validation, immutable staged presentation, late/canceled preparation rejection and candidate reservations. Native write/save/duplicate/move/lock/rename guards; owned-copy bytes/mtime/mode assertions. | Actual native registry/presenter lifetime, window transfer and failure feedback/selection preservation. |
| C5 | Renderer, path resolver and anchor policy unchanged. Per-window one-shot fragments; same-document actions supersede pending replacement. Every explicit file dispatch uses conservative executable/application disposition, including absolute file URLs and symlinks. Resolver/decoder/anchor/dispatch tests. | Physical section scrolling, keyboard/context/AX activation and Finder/default-app dispatch. |

No UI/E2E or manual scripted interaction was run. No NSOpenPanel/NSWorkspace dispatch, synthetic events, clipboard changes or system appearance changes were exercised by the selected tests. Hosted unit runs explicitly suppress the startup picker. Xcode builds the scheme's test products, including the existing UI test product, but **no UI test is selected or executed**. Native behavior is **DEFERRED/UNVERIFIED**, not accepted from these builds or model tests. Preserve historical UI tests and #36/#38 failures/deferrals; final milestone acceptance belongs to the user.

The small Objective-C category `ReadOnlyMarkdownLegacyGuards.m` rejects public pre-Swift NSDocument write selectors. The SDK makes those overrides unavailable in Swift, and explicit Swift Objective-C selectors also conflict with the inherited methods. The category extends only the same app-owned document class, uses its Xcode-generated Swift header, and needs no project settings or private APIs. Two actual legacy selectors are exercised alongside current native write/metadata APIs. Compiler deprecation-implementation warnings are intentional for these guards.

## Commands and results

Run from the story checkout with Xcode 26.3 / macOS 26.5.1 (arm64). No signing/team/bundle/deployment override is used.

```sh
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-43-DerivedData build
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-43-DerivedData build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-43-DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:NeoMDTests/NativeNavigationTests \
  -only-testing:NeoMDTests/DocumentOpeningTests \
  -only-testing:NeoMDTests/LocalFileAccessTests \
  -only-testing:NeoMDTests/MarkdownDocumentTests \
  -only-testing:NeoMDTests/MarkdownTextDecoderTests \
  -only-testing:NeoMDTests/MarkdownFileTypeTests \
  -only-testing:NeoMDTests/DocumentLinkResolverTests \
  -only-testing:NeoMDTests/MarkdownAnchorsTests \
  '-only-testing:NeoMDTests/MarkdownImagesTests/resetRejectsOldSameURLLoadsAndReleasesStore()' \
  -resultBundlePath /tmp/neomd-43-units-3.xcresult test
```

Debug and Release builds passed. Selected final implementation-tree run: **42 passed, 0 failed, 0 skipped**, from `xcresulttool get test-results summary`. Earlier selected runs also passed; initial build iterations failed on SDK-imported method names and deprecated Swift override restrictions, then were corrected. No failed unit assertion was removed or weakened. The obsolete folder-suggestion policy assertion was retired; the image hosting environment injection was adapted for compilation but its scrolling assertions were retained and unrun. All unlisted test suites/methods, including hosting/keyboard/scroll tests and all `NeoMDUITests`, are excluded rather than reported as passed or skipped.

`NativeNavigationTests` exercises batch rejection, prompt-free image retry, captured sessions, panel cancellation state, closed-session rejection, controlled suspended late preparation, injected preparation failure/cancellation, canonical shared-candidate reservation policy, safe regular reads including FIFO rejection, conservative file dispatch, and actual native read-only guards on owned disposable files. Reservation/session tests are policy evidence, **not physical native-window or file-presenter integration evidence**.

## Signed products, without standalone launch

```sh
codesign -d --entitlements :- /tmp/NeoMD-43-DerivedData/Build/Products/Debug/NeoMD.app
codesign -d --entitlements :- /tmp/NeoMD-43-DerivedData/Build/Products/Release/NeoMD.app
codesign -dv --verbose=4 /tmp/NeoMD-43-DerivedData/Build/Products/Debug/NeoMD.app
codesign -dv --verbose=4 /tmp/NeoMD-43-DerivedData/Build/Products/Release/NeoMD.app
```

Both actual products are Apple Development signed, identifier `io.neomd.NeoMD`, team `LZGG9FBBNV`. Both entitlement dictionaries contain `com.apple.security.files.user-selected.read-only`, `com.apple.security.network.client`, and `com.apple.security.get-task-allow` (true), and **do not contain `com.apple.security.app-sandbox`**. Retained capability entitlements are not an unsandboxed filesystem read-only guarantee. No app was launched for entitlement inspection.

Proactive Swift LSP diagnostics were clean. Standalone clang reports three generated-header/interface lookup diagnostics for the Objective-C category because it lacks Xcode's DerivedSources include path; both actual Xcode builds compile/link it, and the selected legacy-selector test passes. These are recorded tooling false positives, not suppressed source errors. Existing CMark actor-isolation/test warnings remain outside this story. Final `lens_diagnostics(mode=all)` and `git diff --check` are part of the handoff.

## Artifact provenance

Verified all **101** staged-deliverable/base SHA-256 hashes against `/tmp/neomd-priority43-revised/MANIFEST.json` before import; imported only its 13 `staged/` deliverables. The eight inert fixture files are unchanged, including the existing PNG copy. Only approved status settlement and cumulative catalog linking amend triage documents. No evidence/platform/research/agent data was imported. Untracked `docs/research/` and the original checkout's unrelated work remain untouched.

Build logs, signed-entitlement plists and xcresult bundles are outside Git under `/tmp/neomd-43-*`. The PR and durable `/tmp/neomd-43-worker-handoff.md` record the exact committed/validated head and final command artifacts. No issue acceptance boxes, merge, issue closure or milestone acceptance are performed by the worker.
