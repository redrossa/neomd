# libyaml 0.2.5

Upstream: https://github.com/yaml/libyaml

- Commit: `2c891fc7a770e8ba2fec34fc6b545c672beb37e6`
- Annotated tag `0.2.5`: `65d19898a301b817261003b00d1dcef00895a7b4`
- License: MIT; full upstream `License` preserved, also shipped as `NeoMD/Resources/libyaml-License.txt`.
- `SHA256.json` authenticates the unchanged eight `src/*.c` files, private/public headers and license against this checkout. No upstream bytes patched.
- NeoMD-owned `Package.swift` builds all upstream C sources as a local static module with the release version defines normally supplied by upstream's build configuration. No remote or transitive package dependencies.

NeoMD calls the parser-event API only, with a bounded input buffer and iterative owned metadata assembly/projection. Tags are inert data; no constructors, loaders, emitters, external includes, network or executable dispatch is used by the app. Limits reduce resource risks; they are not a C-library vulnerability audit.
