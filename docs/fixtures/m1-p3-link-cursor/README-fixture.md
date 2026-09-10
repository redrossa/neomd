# M1-P3 pointing-hand cursor fixture

Issue: https://github.com/redrossa/neomd/issues/42
Inspection base: `56ca6e622ae4e6c1996c160347f4624a3bbb3d1b`.
Status: **DATA AND PLAN ONLY; all interactions UNRUN/DEFERRED.** No UI/E2E or manual scripted interaction is authorized by this recipe. Renew user authorization before final testing.

## Files and authority

- `cursor.md`: exact UTF-8 source, ordinary/long styled external-local-internal links, repeated footnote references and generated returns, linked image-only/mixed leaves, linked missing-image fallback, quote/task links and negative controls.
- `nearby.md`: local Markdown target with heading fragment `local-target`.
- `img/badge.png`: unchanged 64x32 green PNG reused from `docs/fixtures/m1-12-images/img/small.png`, rather than creating a new binary asset. The manifest records original path/hash.
- `img/absent.png`: deliberately absent. Do not create it. Fallback text retains the authored link under the existing renderer.
- `manifest.json`: SHA256 and byte lengths. This is an inventory, not a test result.

No remote images, network service, fixture generator or executable tests are added. The explicit example.com links are only destinations: hovering must not open them. Rendering local images may require the existing explicit session-only folder grant in a plain sandboxed build; absence of that grant should produce existing fallback text. Do not change permissions or sandbox to force display. A missing local destination still has the existing click-to-notice semantics; cursor policy must not probe files or request grants on hover.

## Future setup and isolation (UNRUN/DEFERRED)

After renewed authorization, copy the entire folder to a fresh owned temporary directory, never open the repository originals. Record all source bytes/SHA256 and nanosecond mtimes before opening and compare after. A fixed source mtime of Unix 1700000000 may be set on owned copies before the snapshot. Open the copied `cursor.md` using normal File > Open or Finder Open With with the exact tested NeoMD build; record source SHA/macOS/build and restore any changed host settings. Preserve other NeoMD/browser sessions and clipboard. Only remove the owned copy and windows afterwards.

## Criterion-linked future observations (all DEFERRED, not passed)

C1: hover each text-link label, both footnote references and each generated return. Expect native pointing hand. Include all fragments of the long styled label after a narrow resize. Hover alone leaves document position and window count unchanged and launches no destination/panel.

C2: with local bitmap access already granted through the existing explicit flow, hover the displayed clickable image extents, including top/bottom of the image, not merely its text baseline. Linked image-only and mixed local/external images show hand. When missing/loading, hover the existing linked fallback text; it remains linked, with the same cursor policy. No automatic resource permission request or link activation on hover.

C3: move from each link onto adjacent prose, line-end whitespace, margins, and unlinked images. No whole-paragraph/whole-image-container hand region; normal selectable text has native text cursor. Repeated entry/exit, scrolling and 900/480 window widths must not leave a stuck hand. Pure unlinked image path stays unchanged.

C4: after cursor observation, separately verify existing mouse click, native Option-Tab/arrows/Return/Space and Escape behavior, ordinary text selection across a link, and authored-link context menus. Generated footnotes currently do not receive authored-link menus; preserve that policy. No copy/pasteboard action is needed to inspect selection ranges/menu contents. Do not reinterpret Command-click routing here: #43 owns changes. Record real interaction evidence only after authorized execution, not from direct method calls or attribute inspection.

Repeat representative cases in both appearances. Native cursor image observation is required at final testing; AX link roles or screenshots without a pointer are not proof of cursor shape. No new AX controls, hit-test overlays or routing behavior are required. Existing larger-scale/#38 and reflow/#36 deferrals remain separate; do not run them now.
