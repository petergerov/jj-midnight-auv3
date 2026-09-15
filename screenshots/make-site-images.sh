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
  echo "   $(basename "$dst")  $(sips -g pixelWidth -g pixelHeight "$dst" | awk '/pixel/{printf "%s ", $2}')"
}

# iPhone: 1320x2868. Chrome is the status bar plus the "Standalone player"
# label and trial banner (≈700 px), and the transport bar at the foot
# (≈300 px).
crop "$STORE/iphone-6.9/01-panel.png"        "$OUT/panel-iphone.jpg"   0.245 0.105
crop "$STORE/iphone-6.9/02-space-master.png" "$OUT/panel-iphone-2.jpg" 0.245 0.105
crop "$STORE/iphone-6.9/03-presets.png"      "$OUT/presets-iphone.jpg" 0.245 0.105

# iPad: 2752x2064 landscape. The same chrome is a much smaller fraction of a
# shorter frame.
crop "$STORE/ipad-13/01-panel.png"           "$OUT/panel-ipad.jpg"     0.165 0.105
crop "$STORE/ipad-13/03-presets.png"         "$OUT/presets-ipad.jpg"   0.165 0.105

# One close-up for the site's detail slot: Comp and Drive off the iPad panel
# — the gain-reduction meter, and enough brass and bakelite to show how the
# thing is drawn.
if [ -f "$STORE/ipad-13/01-panel.png" ]; then
  sips --cropToHeightWidth 760 1120 --cropOffset 700 150 \
       "$STORE/ipad-13/01-panel.png" \
       --setProperty format jpeg --setProperty formatOptions 80 \
       --out "$OUT/detail-comp.jpg" >/dev/null
  echo "   detail-comp.jpg  1120 760"
fi
