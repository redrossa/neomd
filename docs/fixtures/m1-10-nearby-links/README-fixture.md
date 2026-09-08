# M1-10 nearby-links fixture

Reproducible fixture for [issue #10](https://github.com/redrossa/neomd/issues/10). Copy this whole folder to a temporary location before testing so that permission changes and app launches never touch the repository:

```sh
FIX=$(mktemp -d /tmp/NeoMD-M1-10.XXXXXX)/nearby-links
cp -R docs/fixtures/m1-10-nearby-links "$FIX"
chmod 000 "$FIX/docs/private.md"      # inaccessible scenario (POSIX denial)
open -a /path/to/NeoMD.app "$FIX/docs/guide.md"
```

Layout (source document is `docs/guide.md`; paths in the table are relative to it):

| Link in `docs/guide.md` | Resolves to | Marker text | Purpose |
|---|---|---|---|
| `./intro.md#second-section`, `intro.md` | `docs/intro.md` | `SECOND SECTION LANDED` / `INTRO START` | `./`, section handoff, plain sibling |
| `../README.md#parent-section` | `README.md` | `PARENT SECTION LANDED` | `../` |
| `sub/deep.md#deep-target` | `docs/sub/deep.md` | `DEEP TARGET LANDED` | subfolder |
| `<my notes.md>`, `my%20notes.md` | `docs/my notes.md` | `SPACES TARGET OPENED` | spaces, bracketed and encoded |
| `caf%C3%A9.md`, `café.md` | `docs/café.md` | `UNICODE TARGET OPENED` | encoded filename |
| `100%.md` | `docs/100%.md` | `PERCENT EDGE OPENED` | malformed-escape edge, not a criterion |
| `/root-target.md` | `docs/root-target.md` (never `root-target.md` at the fixture root) | `ROOT POLICY CORRECT` (decoy prints `ROOT POLICY WRONG`) | approved leading-slash policy |
| `notes.txt` | `docs/notes.txt` | `PLAIN TEXT TARGET` | other local type |
| `img/diagram.png` (link, linked image, image) | `docs/img/diagram.png` | 1×1 PNG | other local type; image path policy |
| `missing.md`, `sub/absent/nowhere.md`, `img/absent.png` | absent | — | missing target |
| `intro.md#nowhere` | `docs/intro.md` | existing missing-fragment notice in target | missing section in existing file |
| `private.md` | `docs/private.md` | `PRIVATE CONTENT` | inaccessible target |
| `guide.md#guide-end`, `#guide-end` | this document | `GUIDE END` | already-open refocus, unchanged internal links |
| `https://example.com/` | web | — | remains external (M1-11) |

`docs/100%.md` and `docs/café.md` deliberately carry unusual filenames; the Unicode name is NFC. Nothing in the fixture is executable.
