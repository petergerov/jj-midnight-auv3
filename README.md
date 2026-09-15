# jj-midnight (AUv3)

A vintage clean / low-gain guitar chain — optical compressor, amp breakup,
tremolo, slapback and spring — as an Audio Unit (AUv3) for iPhone and iPad.
Sibling project to [jj-breeze](https://github.com/petergerov/jj-breeze-auv3),
whose AU scaffolding and panel UI this reuses.

**Website:** [petergerov.github.io/jj-midnight](https://petergerov.github.io/jj-midnight)
**Support:** [GitHub Issues](https://github.com/petergerov/jj-midnight/issues)

## What it is

Four macro blocks in signal order, each with its own on/off, plus a master strip:

```
In → [COMP] → [DRIVE → cab] → [WOBBLE] → [SPACE: slap + spring] → Mix → Out
```

- **COMP** — optical compressor with program-dependent release. One knob for
  threshold/ratio/make-up, the way a real opto box works. This is the block the
  whole plug-in is built around.
- **DRIVE** — asymmetric soft clipping (second harmonic, not fizz), tone
  rolloff, and a 1x12 cabinet voicing with a movable mic position.
- **WOBBLE** — amp-style amplitude tremolo, LFO morphing from sine to chop.
- **SPACE** — one slapback repeat (no feedback) into a spring tank with
  dispersion allpasses for the chirp.

**AU identity:** type `aufx`, subtype `Jjm1`, manufacturer `Grov` — listed in
hosts as **jj-midnight** (Gerov).

## Naming

The product name is **not settled** — see [marketing.md](marketing.md) for the
candidates, the reasoning, and why the decision is cheap now and impossible
after the first App Store submission.

The engine is generic and the presets are the flavour. Preset names describe a
*feel* or a place, never a person or a record; the plug-in is not affiliated
with any artist or third-party vendor. Keep it that way in the App Store
listing too — describe the sound, not who made it famous.

## Pricing

Same model as jj-breeze: free download, 7-day trial from first launch, then a
one-time unlock (`com.gerov.jjmidnight.unlock`).

## Requirements

- Xcode 16 or later
- iOS 17+
- Apple Developer team (set in Xcode Signing & Capabilities)
- App Group **`group.com.gerov.jjmidnight`** on app + extension (for shared
  trial/unlock state)

## Open and build

```sh
xcodegen generate
open JJMidnight.xcodeproj
```

**`project.yml` is the source of truth.** `xcodegen generate` rewrites
`project.pbxproj` from it, so anything set only in Xcode's GUI is gone at the
next run. Supported Destinations is the one that bites: Xcode's editor writes
`TARGETED_DEVICE_FAMILY`, `SUPPORTS_MACCATALYST`,
`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` and
`SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD`, and all four live in `project.yml`'s
`settings.base` so both targets get them identically. Change them there, not
in the target editor.

1. Select the **jj-midnight** scheme.
2. Set your Development Team on both **JJMidnight** and **JJMidnightExtension**.
3. Run on an iPhone, iPad, or simulator.

Open the app once so the Audio Unit registers.

## Factory presets

Default, Laid Back, Escondido, Porch Light, Whisper Trem, Faded, Cassette,
Night Drive, Flat & Even.

The first half aims at the laid-back end the chain was designed around; the
second half is the same engine pointed at the compressed, washed-out guitar
sound a younger audience is buying. Further preset packs are the intended way
to grow this, not further DSP.

User presets: tap the preset window → **Save As…**; swipe left to rename or delete.

## Project layout

```
JJMidnight/                    Container app (test host)
JJMidnightExtension/
  Parameters/               AUParameterTree, presets, StoreKit unlock
  DSP/                      C++ kernel (real-time; no Swift)
  UI/                       SwiftUI editor + GearTheme finishes
  Common/                   AUAudioUnit / process glue
docs/                       Marketing site + privacy (GitHub Pages)
icon/ loop/                 Asset generators (see below)
```

`docs/` also carries one Markdown page per block — `comp.md`, `drive.md`,
`wobble.md`, `space.md`, plus `master.md` for Mix, Output and the output
metering — with the ranges, the measured behaviour, and what to reach for. The screenshots under `docs/images/` come from the simulator;
regenerate them by running the app and cropping to the panel.

Only edit `Parameters`, `DSP`, and `UI` for plug-in behaviour. The render
thread lives entirely in `JJMidnightDSPKernel.hpp`.

## Shared code with jj-breeze

`Common/`, the UI kit, and the trial/unlock plumbing are a copy of
jj-breeze's, not a shared dependency. At two plug-ins, copying is cheaper than
the abstraction; at three, pull the common parts out into a local SwiftPM
package (`JJKit`) rather than copying a third time. Fixes made here to shared
files should be carried back by hand until then.

## Demo parts

The container app bundles three real recordings — `loop/loop_1.mp3` (15 s),
`loop_2.mp3` (27 s) and `loop_3.mp3` (24 s) — picked with the source selector
as **1**, **2** and **3**. All three are dry: no reverb, no compression, no
saturation, because this plug-in *is* the compressor, the breakup, the
tremolo and the space, and anything baked into a part would be heard twice.

Labels are bare numbers because four segments on a phone leave about 80 pt
each and "Guitar 1" truncates; `Source.spokenName` keeps the full name for
VoiceOver.

They are decoded on demand rather than at launch: all three as PCM would be
about 22 MB for audio the user may never select.

Raw takes (`loop/*.wav`) are gitignored; only the mixed-down MP3s ship.

## Generated assets

```sh
swift icon/make-icon.swift     # -> JJMidnight/Assets.xcassets/AppIcon.appiconset/AppIcon.png
python3 loop/make-loop.py      # -> loop/synthetic-test.mp3  (needs numpy and ffmpeg)
```

`make-icon.swift` draws the same composition as jj-breeze's icon — panel,
corner screws, meter arc, serif wordmark, jewel lamps — in the Tweed
colourway, so the two read as one family. Its colours are the hex values from
`GearPalette.tweed`; change them together.

`make-loop.py` synthesises a dry fingerpicked guitar part with extended
Karplus-Strong. It is **not** bundled — it produced the placeholder the real
recordings replaced, and is kept because a synthetic part is useful for
testing against known material: exact pitch, known timing, and a seamless
loop, none of which a recording gives you. Its output is gitignored.

## To do before shipping

- [ ] **App Store Connect** — new app record, new IAP for
      `com.gerov.jjmidnight.unlock`, marketing copy that describes the sound
      rather than naming anyone.
- [ ] **Trademark clearance on the name** — `jj-midnight` is decided, not
      cleared. Focusrite's withdrawn Midnight plug-in suite and the current
      Midnight Plaza AUv3 were both checked and neither disqualifies it, but
      that was a web search; see [marketing.md](marketing.md).
- [ ] **Rename the repository** — this repo and its Pages site are still
      `jj-tulsa`, so the `jj-midnight` links here and in `docs/` 404 until
      it is renamed. GitHub redirects the old URLs afterwards.
- [ ] **Store link** — `APP_STORE_URL` in `docs/index.html` is empty, so the
      buttons fall back to the repository. Fill it in once there is a listing.
- [ ] **Google Search Console** — `docs/` has no verification file; jj-breeze's
      token belongs to that property and cannot be reused.
- [ ] **Cab convolution** — deliberately not in v1. `CabVoicing.h` is four
      biquads behind an interface convolution could take over later without
      anything upstream changing.
