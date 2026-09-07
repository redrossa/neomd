#!/bin/sh
# Offline integrity check, including reverse-patch comparison to pinned originals.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
vendor="$root/ThirdParty/cmark-gfm"
work=$(mktemp -d "${TMPDIR:-/tmp}/neomd-cmark-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cd "$vendor"
shasum -a 256 -c SOURCES.sha256
cp -R Sources/CMarkGFM "$work/source"
for patch in $(printf '%s\n' patches/*.patch | sort -r); do
    (cd "$work/source" && patch --batch -R -p1 < "$vendor/$patch")
done
(cd "$work/source" && shasum -a 256 -c "$vendor/PRISTINE.sha256")
# Reject added source/header files, not merely edits to known files.
python3 - "$vendor" <<'PY'
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
expected = {line.rstrip().split('  ', 1)[1] for line in (root / 'SOURCES.sha256').read_text().splitlines()}
actual = {str(p.relative_to(root)) for p in (root / 'Sources').rglob('*') if p.is_file()}
if actual != {p for p in expected if p.startswith('Sources/')}:
    raise SystemExit('Source inventory drift')
PY
cmp COPYING "$root/NeoMD/CMarkGFM-LICENSE.txt"
printf '%s\n' 'Pinned cmark-gfm source, patch, inventory, and bundled notice checks passed.'
