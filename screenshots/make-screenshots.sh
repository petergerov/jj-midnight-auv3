#!/bin/bash
#
# Regenerates every screenshot the site and the App Store listing use.
#
#   screenshots/make-screenshots.sh
#
# Runs the ScreenshotTests UI target on one iPhone and one iPad simulator,
# unpacks the attachments out of the result bundles, and writes:
#
#   screenshots/store/iphone-6.9/*.png    1320x2868 — App Store, required
#   screenshots/store/ipad-13/*.png       2064x2752 — App Store, required
#   docs/images/*.jpg                     the marketing site
#
# The store PNGs are what App Store Connect wants: exact pixel sizes, no
# device frames, no added text. The site JPEGs are the same frames cropped to
# the panel and compressed, because the site has its own chrome around them
# and does not need the status bar.
#
# Takes about three minutes from cold. Both simulators are left booted.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

# Result bundles and logs are throwaway; the build directory is not. A fresh
# mktemp for both meant a full clean build of the app, the appex and the C++
# kernel on every run — three minutes of rebuilding code that had not
# changed, twice, once per device.
WORK="$(mktemp -d)"
DD="$ROOT/DerivedData/screenshots"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DD"

# 6.9" iPhone and 13" iPad are the two sizes App Store Connect still demands
# outright; everything else it scales from them.
IPHONE="iPhone 17 Pro Max"
IPAD="iPad Pro 13-inch (M5)"

echo "==> Generating project"
xcodegen generate >/dev/null

run_device () {
  local name="$1" outdir="$2"
  local udid
  udid=$(xcrun simctl list devices available \
        | grep -F "$name (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  if [ -z "$udid" ]; then
    echo "!! No simulator named '$name' — skipping" >&2
    return 0
  fi

  echo "==> $name"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null

  # The stock status bar carries the wall clock, a random carrier and
  # whatever battery the host happens to have. Apple's own 9:41 is the
  # convention and it keeps two runs a day apart pixel-identical.
  xcrun simctl status_bar "$udid" override \
      --time "9:41" \
      --cellularMode active --cellularBars 4 \
      --dataNetwork wifi --wifiMode active --wifiBars 3 \
      --batteryState charged --batteryLevel 100

  xcodebuild -project JJMidnight.xcodeproj \
             -scheme screenshots \
             -configuration Debug \
             -sdk iphonesimulator \
             -destination "platform=iOS Simulator,id=$udid" \
             -derivedDataPath "$DD" \
             -resultBundlePath "$WORK/$outdir.xcresult" \
             test >"$WORK/$outdir.log" 2>&1 \
    || { echo "!! Test run failed; see $WORK/$outdir.log" >&2; tail -40 "$WORK/$outdir.log" >&2; return 1; }

  xcrun xcresulttool export attachments \
        --path "$WORK/$outdir.xcresult" \
        --output-path "$WORK/$outdir-att" >/dev/null

  mkdir -p "$ROOT/screenshots/store/$outdir"
  python3 - "$WORK/$outdir-att" "$ROOT/screenshots/store/$outdir" <<'PY'
import json, os, struct, sys

src, dst = sys.argv[1], sys.argv[2]


def strip_exif(data):
    """Drop the eXIf chunk, returning (png, orientation_it_claimed).

    The simulator stamps an EXIF orientation onto every screenshot, and it
    does not always agree with the pixels underneath it. Anything that
    honours the tag — browsers do, for PNG — then shows a panel that is
    already the right way up rotated onto its side. Nothing downstream of
    here needs EXIF, so the whole chunk goes rather than being rewritten
    to 1, and what the file says it is becomes what it is.
    """
    out, i, orientation = bytearray(data[:8]), 8, None
    while i < len(data):
        length = struct.unpack(">I", data[i:i + 4])[0]
        kind = data[i + 4:i + 8]
        if kind == b"eXIf":
            e = data[i + 8:i + 8 + length]
            bo = ">" if e[:2] == b"MM" else "<"
            off = struct.unpack(bo + "I", e[4:8])[0]
            for k in range(struct.unpack(bo + "H", e[off:off + 2])[0]):
                f = off + 2 + k * 12
                if struct.unpack(bo + "H", e[f:f + 2])[0] == 0x0112:
                    orientation = struct.unpack(bo + "H", e[f + 8:f + 10])[0]
        else:
            out += data[i:i + 12 + length]
        i += 12 + length
    return bytes(out), orientation


for test in json.load(open(os.path.join(src, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a["suggestedHumanReadableName"].split("_")[0] + ".png"
        raw = open(os.path.join(src, a["exportedFileName"]), "rb").read()
        clean, orientation = strip_exif(raw)
        open(os.path.join(dst, name), "wb").write(clean)
        w, h = struct.unpack(">II", clean[16:24])
        note = "" if orientation in (None, 1) else f"  (dropped orientation {orientation})"
        print(f"    {name}  {w}x{h}{note}")
PY
}

run_device "$IPHONE" iphone-6.9
run_device "$IPAD"   ipad-13


# The scroll shot is skipped by the test itself on any device where the panel
# already fits, so there is no duplicate to clean up here. It used to be
# dropped by byte-comparing the two PNGs, which missed: a live meter and the
# LED lamps differ by a pixel or two between two captures of the same screen,
# so the compare said "different" and the same picture shipped twice.

echo "==> Site images"
"$ROOT/screenshots/make-site-images.sh"

echo
echo "Done."
echo "  App Store:  screenshots/store/"
echo "  Site:       docs/images/"
