# M1-11 web-links fixture

Reproducible fixture for [issue #11](https://github.com/redrossa/neomd/issues/11). Copy the folder to a temporary location before testing so app launches never touch the repository:

```sh
FIX=$(mktemp -d /tmp/NeoMD-M1-11.XXXXXX)/web-links
cp -R docs/fixtures/m1-11-web-links "$FIX"
open -a /path/to/NeoMD.app "$FIX/web-links.md"
```

Source document: `web-links.md`. `nearby.md` only exists so the M1-10 sibling link resolves.

| Link text in `web-links.md` | Form | Destination (exact string the menu shows / Copy Link copies) | Purpose |
|---|---|---|---|
| `Example site` | inline labeled | `https://example.com/path?q=1` | criterion 1 labeled; criterion 3 single-link menu |
| `Spec reference` | reference, full `[text][gfm]` | `https://github.github.com/gfm/` | criterion 1 reference-style |
| `GFM spec` | reference, collapsed `[GFM spec][]` | `https://github.github.com/gfm/#links` | criterion 1 reference-style |
| `CommonMark` | reference, shortcut `[CommonMark]` | `https://commonmark.org/` | criterion 1 reference-style |
| `https://autolink.example/bare` | bare autolink (cmark-gfm `autolink` extension) | `https://autolink.example/bare` | criterion 1 ordinary URL; link label equals the URL |
| `https://angle.example/path` | angle autolink `<…>` | `https://angle.example/path` | criterion 1 ordinary URL |
| `www.plain.example/site` | bare `www.` autolink | `http://www.plain.example/site` | criterion 1; label differs from destination scheme |
| `First site`, `Second site` | two links in one paragraph | `https://first.example/`, `https://second.example/?x=1&y=2` | criterion 3 multi-link menu lists both destinations, `&` shown literally |
| `Heading site`, `List site`, `Quote site` | links inside heading, list item, quotation | `https://heading.example/`, `https://list.example/`, `https://quote.example/` | criterion 1/3 inside container blocks |
| `Section link` | internal `#far-section` | `#far-section` | M1-09 regression; menu `Open Link` must navigate in place |
| `Nearby` | `nearby.md` | `nearby.md` | M1-10 regression (unchanged local branch) |
| `Far link` | inline labeled, below 30 filler paragraphs | `http://127.0.0.1:1/neomd-m1-11-far` | criterion 2: default browser opens without network dependence (connection-refused page), NeoMD scroll position unchanged |
| `Plain paragraph without any link…` | no link | — | right-click still shows the native text menu (Copy/Look Up), proving no global override |

`FAR END.` is the reading-position marker used after the far link is activated.

## Keyboard targeting revision

[Approved revision](https://github.com/redrossa/neomd/issues/11#issuecomment-5578543964): retain the Far-link mouse check. Open `keyboard-links.md` separately for keyboard activation. Click the reader margin, then use native Option-Tab and Right until `MarkdownLinkBlock-0` changes from `Link 1 of 2: First web link` to `Link 2 of 2: Keyboard web link` (bounded at 20 iterations). Unlike mere label existence, this change proves the block handled a selection key. Record the selected link and `KEYBOARD POSITION MARKER.` frames, press Return, expect the default browser frontmost within 10 seconds, reactivate NeoMD and compare both frames within 1 point. Preserve a browser that was already running.

The original keyboard failure reproduced on the accepted base. The [approved dispatch correction](https://github.com/redrossa/neomd/issues/11#issuecomment-5578594417) routes external keyboard activation through the reader's inherited SwiftUI `openURL` action rather than relying on `.systemAction` fallback from a custom environment key. The unchanged test now passes. The separate overlay-related M1-09 regression was resolved by the [approved background attachment revision](https://github.com/redrossa/neomd/issues/11#issuecomment-5579096053), following [user-authorized investigation](https://github.com/redrossa/neomd/issues/11#issuecomment-5579017450). The non-hit-testing attachment preserves native selectable Text and scopes menu events to its own visible bounds/window.

## Worker execution

Final Debug build, 115 Swift Testing tests plus 4 XCTest hosting tests, and all 17 serialized WebLink/DocumentLinkNavigation/NearbyFileLink UI tests passed. Evidence: `/tmp/neomd-11-accepted-build.log`, `/tmp/neomd-11-accepted-units.xcresult`, `/tmp/neomd-11-accepted-ui-complete.xcresult`; complete commands and historical failures are preserved in `docs/milestone-1-e2e-fixtures.md`.

`WebLinkUITests.testContextualMenuRevealsDestinationWithoutOpening` uses fresh right-click in Light and Control-click in Dark, checks full destinations, Copy Link, section Open Link, multiple links and the link-free native menu. `testNativeSelectionInLinkBearingParagraphStillCopiesText` selects/drags the leading `Labeled` word and verifies Command-C copies text, not the URL. `MarkdownLinkAttachmentTests` covers negative event ownership and monitor lifecycle. Final Light/Dark screenshots were inspected. Physical input, selection across a link, full VoiceOver and combined milestone acceptance remain manual/deferred.

One earlier final-run command timed out and interrupted clipboard/fixture cleanup; the catalog records that host-state limitation. The successful rerun completed cleanup and preserves any preexisting browser session (new test tabs remain).
