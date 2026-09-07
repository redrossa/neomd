# Working in NeoMD

This file applies to the entire repository. Run the commands below from this directory, which contains `.git` and `NeoMD.xcodeproj`; the enclosing `neomd` directory is not the Git root.

The canonical remote is <https://github.com/redrossa/neomd>. Issues and milestones live there; a task that names an issue number refers to that repository.

## Project context

NeoMD is a native macOS app for reading Markdown as polished documents. The app opens Markdown files through a read-only SwiftUI `DocumentGroup`, so Finder's Open With, double-clicking, and `File > Open` all work. Rendering is a deliberately small first pass: block structure and inline emphasis are presented, and the GitHub-style typography, layout, and appearance work remains to be done.

Read `docs/milestone-1-user-stories.md` before feature work. It describes all 24 stories in the proposed first milestone, but its acceptance criteria and unresolved product choices are still draft. Use the current task to determine what to implement; do not treat the backlog as an instruction to implement every story or silently turn proposals into settled requirements.

The current milestone direction is:

- A rendered, read-only experience with GitHub-inspired document styling, system light/dark appearance, and a minimal native window.
- Native menu commands and keyboard shortcuts for opening and navigation, with attention to selection, accessibility, and readable error states.
- Local-first reading without an account or a network dependency for document text and bundled rendering resources.
- No editing, saving, mutable task checkboxes, formatting toolbar, or source/preview switch in milestone 1.
- No GitHub authentication, publishing, issue/PR enrichment, or repository-configured ticket autolinks. Ordinary explicit hyperlinks remain in scope.

## Repository map

- `NeoMD/NeoMDApp.swift`: SwiftUI app entry point; declares the read-only `DocumentGroup`.
- `NeoMD/Info.plist`: imported Markdown type declaration and document types, merged with the generated Info.plist. This is what makes Finder offer NeoMD for `.md` files.
- `NeoMD/Documents/`: file type declaration, byte decoding, and the read-only `FileDocument`.
- `NeoMD/Rendering/`: cmark-gfm AST to presentable blocks and internal-link destinations; pure, main-actor free, unit tested.
- `ThirdParty/cmark-gfm/`: pinned offline C parser package, complete notices, isolated patches and hash inventories. Verify with `Scripts/verify-cmark-vendoring.sh`.
- `NeoMD/Views/`: reading surface and block layout.
- `NeoMD/Assets.xcassets/`: app icon, accent color, and other visual assets.
- `NeoMDTests/`: unit tests using Swift Testing (`import Testing`, `@Test`, `#expect`).
- `NeoMDUITests/`: UI and launch tests using XCTest and `XCUIApplication`.
- `NeoMD.xcodeproj/`: targets, build settings, signing, and project configuration.
- `docs/`: product planning and supporting documentation.

The project uses Xcode file-system-synchronized source groups. Place new files in the appropriate app or test directory; avoid adding redundant manual file references to `project.pbxproj`.

## Build and validation

Use Xcode and `xcodebuild`, rather than `swift build` or `swift test`; the app is not a standalone Swift package (the local package only builds the vendored C parser). The project was created with Xcode 26.3 and currently targets macOS 26.2. Use an Xcode installation and macOS test host compatible with those settings. The targets use Swift 5 language mode; the app enables approachable concurrency and default `MainActor` isolation.

```sh
# Inspect the available scheme and targets.
xcodebuild -list -project NeoMD.xcodeproj

# Build the app; keep generated output outside the repository.
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData build

# Run unit tests.
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-DerivedData \
  -only-testing:NeoMDTests test

# Run the full suite, including UI tests.
xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-DerivedData test
```

UI tests require a usable macOS graphical session. If signing or the local toolchain prevents validation, report the exact limitation; do not change the checked-in development team, bundle identifiers, deployment target, or sandbox settings just to make a local check pass.

For code changes, build and run the tests relevant to the behavior changed. Add meaningful regression coverage for new logic and bug fixes; the existing template tests do not establish feature correctness. Use unit tests for parsing, path handling, and state logic, and UI tests for app interactions. For visual changes, inspect light/dark appearance, resizing, and keyboard accessibility as applicable. Documentation-only changes do not require an app build.

## Implementation guidance

- Follow the existing Swift style: four-space indentation, `UpperCamelCase` type names, and `lowerCamelCase` members. Prefer focused types and views with descriptive names.
- Keep file access, document state, and rendering logic separate from view layout as these features are introduced. Avoid speculative frameworks and unrelated refactors.
- Prefer native SwiftUI and macOS APIs where they fit. Add dependencies only when the task benefits from them, and explain the choice.
- Respect the app's actor-isolation settings. Keep expensive file or rendering work off the UI thread through explicit concurrency boundaries, and update UI state on the main actor.
- Preserve the app sandbox and its current read-only user-selected file access. Handle security-scoped access and permission failures when introducing file operations.
- Reading, navigation, refresh, and restoring reading position must not modify document bytes or modification times. Keep app preferences and reading history separate from source files.
- Treat document content as untrusted input. Rendering must not execute embedded scripts or automatically launch linked apps. If introducing a web-based renderer, separate trusted renderer code from document-provided markup and validate navigation destinations.
- Keep local text rendering usable offline. Load any supported remote images without blocking the document, with useful fallback text when unavailable.
- Preserve readable content and the last successful document state when an operation fails. Make errors actionable without exposing implementation details in the reading UI.

## Change hygiene

- Inspect `git status` before editing and preserve unrelated local work.
- Keep changes scoped to the task. Update product documentation when an implemented decision changes the documented behavior, retaining draft labels for unresolved proposals.
- Keep this `AGENTS.md` in version control at the repository root.
- Do not add build output, DerivedData, `.DS_Store`, machine-specific paths, credentials, or Xcode user state (`xcuserdata`) to commits.
- Review the final diff and run `git diff --check`. Report what changed, what was verified, and any remaining validation limits accurately.
