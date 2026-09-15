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
#   screenshots/store/ipad-13/*.png       2752x2064 — App Store, required
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
import json, os, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
for test in json.load(open(os.path.join(src, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a["suggestedHumanReadableName"].split("_")[0]
        shutil.copy(os.path.join(src, a["exportedFileName"]),
                    os.path.join(dst, name + ".png"))
        print("   ", name + ".png")
PY
}

run_device "$IPHONE" iphone-6.9
run_device "$IPAD"   ipad-13

# On an iPad the whole panel already fits, so the scroll shot is a duplicate
# of the panel shot. Drop it rather than ship the same picture twice.
if [ -f "$ROOT/screenshots/store/ipad-13/02-space-master.png" ]; then
  if cmp -s "$ROOT/screenshots/store/ipad-13/01-panel.png" \
            "$ROOT/screenshots/store/ipad-13/02-space-master.png"; then
    rm "$ROOT/screenshots/store/ipad-13/02-space-master.png"
    echo "==> Dropped the iPad scroll shot (identical to the panel shot)"
  fi
fi

echo "==> Site images"
"$ROOT/screenshots/make-site-images.sh"

echo
echo "Done."
echo "  App Store:  screenshots/store/"
echo "  Site:       docs/images/"
