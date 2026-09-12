# M1-P9 scroll fixtures

Status: inert triage material; native scrolling **DEFERRED / UNRUN**. Refreshed exact base: `445ed2b897934d339eb01b750d37b03edf392dce` after #64 / PR #66 (predecessor `1738b1d2e9e7f74411f0d63e4aab401c1522109b`).

- `mixed-heights.md`: short deterministic corpus with many uneven roots, wrapping prose, tall literal code, quote/list containers and explicit top/end links. No remote images, scripts, executable payloads or missing dependencies. It is not the user's original file and is not a confirmed reproduction.
- `policy-cases.json`: scalar/rectangle app-policy oracles for worker-authored non-interaction units. Numeric content-height changes are hypothetical lazy-layout observations, not measurements of SwiftUI's estimates. Refreshed sequence oracles cover stale restoration/find continuations, first-observed deceleration, new explicit intent and #64 selection busy surviving scroll-idle. They are declarative values, not an event stream, native-host substitute or physics model.

The mixed-height Markdown bytes are unchanged from predecessor triage. PR #66's P8 fixture/validation artifacts are separate and must remain untouched; no P9 fixture requires executing P8 native recipes.

If the small corpus is too short for the user's native comparison, an optional deterministic long copy can be assembled outside the repository: read the UTF-8 bytes of `mixed-heights.md`, concatenate exactly 24 copies in source order, with exactly one additional LF byte between copies, and no added prefix/suffix. Record the resulting byte count and SHA-256 in the user's evidence. Repeated headings intentionally get parser duplicate slugs; only the first copy owns the ordinary `#p9-top` / `#p9-end` destinations. Worker units may build this data in memory; triage supplies no executable generator. Do not commit the generated document or alter the source fixture.

For future user-owned comparison, record the exact source hash, initial approximate heading/offset, width, reading size, find visibility and whether an external write/image load occurred. Distinguish normal endpoint contact from a stop before the top, a jump, or an application hang. Compare an upward flick through first-seen roots with repeat travel through already-seen roots. See `../../m1-p9-validation.md` for the full coverage boundary. No UI/scripted event/host testing is authorized by these descriptions.

#36/#38 remain separate known deferred failures with unproven equivalence. No fixture result is currently passed.
