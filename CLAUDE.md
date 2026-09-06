# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Read this first

**[`AGENTS.md`](AGENTS.md) is the canonical contract for this repository.** Read it in full
before making any change. It covers project context, the repository map, build and test
commands, implementation guidance, and change hygiene, and it applies to the entire repo.
This file only adds Claude Code-specific notes and a fast orientation; where the two
overlap, `AGENTS.md` wins.

Also read [`docs/milestone-1-user-stories.md`](docs/milestone-1-user-stories.md) before
feature work. It is a **draft** backlog with unresolved product decisions — implement what
the current task asks for, and do not treat the backlog as a mandate or silently promote a
proposal into a settled requirement.

## Orientation

NeoMD is a native macOS SwiftUI app for reading Markdown as a polished, GitHub-styled
document. Read-only by design in milestone 1: no editing, no source view, no GitHub
account. Opening a document works end to end through a read-only `DocumentGroup`; the
Markdown renderer is a deliberate first pass over block structure and inline emphasis, so
the GitHub-style typography, layout, and appearance work is still ahead.

- Git root: this directory (contains `.git`, `AGENTS.md`, `NeoMD.xcodeproj`). The enclosing
  `neomd` folder is **not** the repo root — run every command from here.
- `NeoMD/` app sources · `NeoMDTests/` Swift Testing · `NeoMDUITests/` XCTest · `docs/` planning.
- Xcode 26.3 project, macOS 26.2 deployment target, Swift 5 language mode, approachable
  concurrency with default `MainActor` isolation, app sandbox on with read-only
  user-selected file access.
- Xcode uses file-system-synchronized groups: add files to the right directory; do not hand-edit
  `project.pbxproj` to register them.

## Commands

No SwiftPM here — `swift build` / `swift test` do not apply. Use `xcodebuild`, keeping
derived data out of the repo:

```sh
xcodebuild -list -project NeoMD.xcodeproj

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/NeoMD-DerivedData build

xcodebuild -project NeoMD.xcodeproj -scheme NeoMD \
  -destination 'platform=macOS' -derivedDataPath /tmp/NeoMD-DerivedData \
  -only-testing:NeoMDTests test
```

Drop `-only-testing:` to include UI tests; those need a real macOS graphical session. See
`AGENTS.md` for the full command set and validation expectations.

## Working agreements for Claude

- **Verify, don't assume.** Build and run the tests relevant to what changed, and say
  plainly what was verified and what could not be. If signing or the local toolchain blocks
  validation, report the exact limitation rather than editing the development team, bundle
  identifiers, deployment target, or sandbox settings to make a check pass.
- **Cover new logic.** The template tests prove nothing. Unit-test parsing, path handling,
  and state; UI-test app interactions. For visual work, check light/dark, resizing, and
  keyboard accessibility.
- **Stay in scope.** No speculative abstractions, no drive-by refactors, no new dependencies
  without a stated reason. Check `git status` first and preserve unrelated local work.
- **Respect the product invariants.** Reading, navigation, refresh, and position restore must
  never modify document bytes or modification times; document content is untrusted input and
  must not execute scripts or auto-launch apps; local reading stays usable offline; failures
  preserve the last good rendering with actionable, non-technical error text.
- **Keep architecture layered.** File access, document state, and rendering stay separate from
  view layout. Heavy file or rendering work goes off the UI thread with explicit concurrency
  boundaries; UI state updates on the main actor.
- **Never commit** build output, DerivedData, `.DS_Store`, machine-specific paths, credentials,
  or `xcuserdata`. Review the diff and run `git diff --check` before finishing.
