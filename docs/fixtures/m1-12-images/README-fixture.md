# M1-12 fixture — View illustrations and screenshots

Durable fixture for [issue #12](https://github.com/redrossa/neomd/issues/12). Tests copy this whole folder to a fresh temporary directory and never open the repository copy. Image bytes are deterministic solid colours so a screenshot sample proves the original colour survives both appearances.

## Files

| Path | Bytes | Purpose |
|---|---|---|
| `illustrated.md` | source document | Local images in every authored form plus the failure cases below. Markers: `LOCAL START`, `LOCAL END`. |
| `remote.md` | template | Loopback HTTP cases. The test replaces loopback URL placeholders with the external controller's token-scoped endpoint before writing the copy. Markers: `REMOTE START`, `REMOTE END`. |
| `network.md` | manual only | The exact assets from GitHub's picture documentation plus a retired `user-attachments` address. Needs internet access; never part of the automated gate. |
| `img/wide.png` | 1200×300 PNG, orange `#FF8C00` | Wider than any reading column: must shrink to the column keeping 4:1. |
| `img/small.png` | 64×32 PNG, green `#2EA043` | Narrower than the column: natural size, never stretched. Also used inline, linked, quoted and with an empty alt. |
| `img/photo.jpg` | 320×240 JPEG, magenta | JPEG decoder path; also an inline badge. |
| `img/anim.gif` | 48×48 two-frame GIF (red, then blue) | Accepted by the system decoder; static display shows the first (red) frame. Playback is not a criterion. |
| `img/vector.svg` | 200×100 SVG, purple `#8250DF`, contains a `<script>` | Static system SVG rendering; the script must never run (`document.title` never becomes `SCRIPT EXECUTED`). |
| `img/sun.png` | 160×160 PNG, yellow `#FFD600` | `<picture>` light source. |
| `img/moon.png` | 160×160 PNG, blue `#1F70EB` | `<picture>` dark source. |
| `img/fallback.png` | 160×160 PNG, blue-gray `#8C959F` | `<picture>` `<img>` fallback. |
| `img/private.png` | 64×32 PNG (same bytes as `small.png`) | The test applies `chmod 000` after copying and restores `644` before removal. |
| `img/not-an-image.png` | plain text | No decoder accepts it: alternative-text fallback. |
| `img/absent.png` | deliberately absent | Missing-file fallback. |

## Cases in `illustrated.md`

| Heading | Markdown | Expected |
|---|---|---|
| Wide screenshot | `![Wide orange screenshot](img/wide.png)` | Displayed, width = column width, height = width / 4. |
| Small figure | `![Small green figure](img/small.png)` | Displayed at 64×32 points. |
| Inline badges | JPEG badge and `[![Small linked badge](img/small.png)](https://example.com/badge)` inside a sentence | Both images inline with the surrounding words; the link stays reachable through keyboard link cycling and the contextual menu. |
| Other decodable formats | list items with JPEG, GIF, SVG | Displayed; GIF static red; SVG purple with no script effect. |
| Quoted image | `> ![Quoted small figure](img/small.png)` | Displayed inside the quote indentation. |
| Appearance-specific illustration | documented `<picture>` with dark + light sources and `<img>` fallback | Yellow in Light, blue in Dark, switching live with the appearance. |
| Picture without a matching source | dark source only | Gray fallback in Light, blue in Dark. |
| Picture that is not the documented form | `<picture>` with no `<img>` | Not an image: the literal HTML text remains, as on the accepted base. |
| Unavailable images | absent, private, corrupt | Alternative text (`Missing diagram`, `Private diagram`, `Corrupt diagram`) with a quiet placeholder; `Private diagram` additionally offers `Allow folder access`. |
| Empty alt | `![](img/small.png)` | Displayed; when unavailable, a placeholder without text. |

## Cases in `remote.md`

| Markdown | Server behaviour | Expected |
|---|---|---|
| `http://127.0.0.1:PORT/wide.png` | serves `img/wide.png` immediately | Displayed (plain HTTP through the approved ATS exception). |
| `http://127.0.0.1:PORT/slow.png` | holds `img/small.png` until the test explicitly releases it | Loading state and retained `REMOTE END` are asserted before release; the image appears afterward. |
| `http://127.0.0.1:1/never.png` | connection refused | Alternative text. |
| `https://127.0.0.1:PORT/wide.png` | plain server, TLS handshake fails | Alternative text. |
| `http://127.0.0.1:PORT/not-an-image.png` | 200 with text bytes | Alternative text. |
| `http://127.0.0.1:PORT/absent.png` | 404 | Alternative text. |

## Integrity

Every file's bytes and modification date must be unchanged at teardown; the app never writes to the fixture. Regenerate the bitmaps only with the same solid colours and pixel sizes listed above.
