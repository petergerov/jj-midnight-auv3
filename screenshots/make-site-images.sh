#!/bin/bash
#
# Crops the App Store screenshots down to the marketing site's images.
#
# Called by make-screenshots.sh; safe to run on its own once
# screenshots/store/ is populated.
#
# The site wraps its own chrome around these, so they lose the status bar and
# the container app's transport bar and keep only the panel — the part that
# is the same in every AUv3 host, and the part being sold. JPEG rather than
# PNG: these are photographs of a heavily textured wooden panel, where PNG
# costs four times the bytes for no visible gain.

set -euo pipefail

cd "$(dirname "$0")/.."
STORE="screenshots/store"
OUT="docs/images"
mkdir -p "$OUT"

# crop <src> <dst> <top> <bottom> <quality>
#
# top/bottom are fractions of the source height to cut off. The chrome above
# and below the panel is a fixed number of points, but the two device classes
# differ in height, so fractions are measured per device below rather than
# shared.
crop () {
  local src="$1" dst="$2" top="$3" bottom="$4" quality="${5:-72}"
  [ -f "$src" ] || { echo "   skip $(basename "$dst") — no $src"; return 0; }

  local h w y newh
  w=$(sips -g pixelWidth  "$src" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
  y=$(python3 -c "print(int($h * $top))")
  newh=$(python3 -c "print(int($h * (1 - $top - $bottom)))")

  sips --cropToHeightWidth "$newh" "$w" --cropOffset "$y" 0 "$src" \
       --setProperty format jpeg \
       --setProperty formatOptions "$quality" \
       --out "$dst" >/dev/null
  strip_exif "$dst"
  echo "   $(basename "$dst")  $(sips -g pixelWidth -g pixelHeight "$dst" | awk '/pixel/{printf "%s ", $2}')"
}

# Removes the Exif segment from a JPEG.
#
# sips writes one even when the source PNG has none, and on the landscape
# iPad frames it writes orientation 8 — "rotate 90" — onto pixels that are
# already the right way up. Browsers honour that tag, so the panel arrives on
# the site lying on its side. The pixels are correct; only the metadata lies,
# so the whole segment goes.
strip_exif () {
  python3 - "$1" <<'PY'
import struct, sys

path = sys.argv[1]
d = open(path, "rb").read()
out, i = bytearray(d[:2]), 2
while i < len(d):
    if d[i] != 0xFF:
        out += d[i:]
        break
    marker = d[i + 1]
    if marker == 0xDA:          # start of scan — the rest is entropy-coded
        out += d[i:]
        break
    length = struct.unpack(">H", d[i + 2:i + 4])[0]
    if not (marker == 0xE1 and d[i + 4:i + 10] == b"Exif\x00\x00"):
        out += d[i:i + 2 + length]
    i += 2 + length
open(path, "wb").write(bytes(out))
PY
}

# iPhone: 1320x2868. The foot is the transport bar (≈300 px) on both shots,
# but the two need different tops, because they are cut to different things.
#
# The unscrolled shot starts at the master plate, just under the wordmark row
# — 0.245 cut into the knobs once the master strip moved to the top of the
# panel, so the site showed INPUT, MIX and OUTPUT with their captions sliced
# off. The scrolled shot has no strip and no wordmark above it, so its own
# 0.245 still lands on bare chassis and stays.
crop "$STORE/iphone-6.9/01-panel.png"        "$OUT/panel-iphone.jpg"   0.197 0.105
crop "$STORE/iphone-6.9/02-wobble-space.png" "$OUT/panel-iphone-2.jpg" 0.245 0.105

# iPad: 2064x2752 portrait. Much more to cut here than on the phone — the
# panel is wide and short, so a portrait window centres it with bare chassis
# above and below, and the site wants the panel rather than the furniture.
#
# The foot is cut just under the JJM-1 type plate. It was 0.320 while the
# master strip was the last thing on the panel; with the strip moved up, the
# blocks end higher and 0.320 sliced the type plate in half lengthways.
crop "$STORE/ipad-13/01-panel.png"           "$OUT/panel-ipad.jpg"     0.285 0.308
# The presets shot needs its own pair. The open menu starts above the panel
# plate, so it wants a higher top than the plain panel shot or the "Factory"
# heading is sliced off; and it kept 0.100 at the foot, which on a portrait
# iPad left some 600 px of bare chassis under the type plate.
crop "$STORE/ipad-13/03-presets.png"         "$OUT/presets-ipad.jpg"   0.262 0.306

# One close-up for the site's detail slot: Comp and Drive off the iPad panel
# — the gain-reduction meter, and enough brass and bakelite to show how the
# thing is drawn.
#
# The offset is measured against the 2064x2752 iPad frame and has to be
# re-measured whenever the panel's vertical order changes. It was 960 while
# the master strip sat at the foot of the panel; moving the strip to the top
# pushed the blocks down by its height, and the old offset then framed the
# strip with the tops of Comp and Drive sliced off — a file still named
# detail-comp showing no Comp knobs at all.
if [ -f "$STORE/ipad-13/01-panel.png" ]; then
  sips --cropToHeightWidth 620 1000 --cropOffset 1300 60 \
       "$STORE/ipad-13/01-panel.png" \
       --setProperty format jpeg --setProperty formatOptions 80 \
       --out "$OUT/detail-comp.jpg" >/dev/null
  strip_exif "$OUT/detail-comp.jpg"
  echo "   detail-comp.jpg  1000 620"
fi
