#!/bin/sh
# Adds a chair from a product photo: cuts it out and stores it as Resources/sofa-<id>.png.
# Usage: scripts/add-sofa.sh <photo> <id> [lift]   (lift 0…1 brightens a darkly lit photo; the cord chair uses 0.45)
# Then add an entry for <id> to SofaStyle.all (name, where the seat is) and rebuild.
set -e
cd "$(dirname "$0")/.."
[ $# -ge 2 ] || { echo "Usage: $0 <photo> <id> [lift]"; exit 1; }
swift build -c release
TMP=$(mktemp -d)
"$(swift build -c release --show-bin-path)/Sofaonmac" --cutout "$1" "$TMP/cut.png" --lift "${3:-0}"
sips -Z 760 "$TMP/cut.png" --out "Resources/sofa-$2.png" >/dev/null
rm -rf "$TMP"
echo "Wrote Resources/sofa-$2.png"
