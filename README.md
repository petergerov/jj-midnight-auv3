# jj-midnight (AUv3)

An electric guitar effect: vintage clean / low-gain chain — optical compressor,
amp breakup, tremolo, slapback and spring — as an Audio Unit (AUv3) for
iPhone and iPad.
Sibling project to [jj-breeze](https://github.com/petergerov/jj-breeze-auv3),
whose AU scaffolding and panel UI this reuses.

**Website:** [petergerov.github.io/jj-midnight-auv3](https://petergerov.github.io/jj-midnight-auv3)
**Support:** [GitHub Issues](https://github.com/petergerov/jj-midnight-auv3/issues)

## What it is

Four macro blocks in signal order, each with its own on/off, plus a master strip:

```
In → trim → [COMP] → [DRIVE → cab] → [WOBBLE] → [SPACE: slap + spring] → Mix → Out
```

- **COMP** — optical compressor with program-dependent release. One knob for
  threshold/ratio/make-up, the way a real opto box works. This is the block the
  whole plug-in is built around.
- **DRIVE** — asymmetric soft clipping (second harmonic, not fizz), tone
  rolloff, and a 1x12 cabinet voicing with a movable mic position.
- **WOBBLE** — amp-style amplitude tremolo, LFO morphing from sine to chop.
- **SPACE** — one slapback repeat (no feedback) into a spring tank with
  dispersion allpasses for the chirp.

The master strip sits above the four blocks, not below them: its Input trim is
the first thing to set, because every threshold downstream is an absolute
dBFS number and a guitar into an interface arrives 15–20 dB below them.

**AU identity:** type `aufx`, subtype `Jjm1`, manufacturer `Grov` — listed in
hosts as **jj-midnight** (Gerov).

## Naming

The name is **jj-midnight**, baked into the bundle IDs, the AU subtype, the
repo and the site. It shipped in 1.0.0, so it is now fixed: hosts store the
AU identity in every saved project, and changing it would break every session
a customer has saved. The App Store listing is titled *J.J.Midnight AUv3
Plugin*; hosts still list the plug-in as **jj-midnight**.
[marketing.md](marketing.md) keeps the candidates and the reasoning. What is
*not* settled is trademark clearance; that is still on the list below.

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
open JJMidnight.xcodeproj
```

**`project.yml` and the committed `project.pbxproj` are kept in step by
hand.** The project was edited in Xcode after it was last generated, so the
two are not byte-for-byte what `xcodegen generate` would produce. As of 1.0.1
the difference is cosmetic — XcodeGen names the app's product reference
`JJMidnight.app` where the committed project says `jj-midnight.app` (the built
app is `jj-midnight.app` either way, from `PRODUCT_NAME`), and the app target
carries its own copy of `CURRENT_PROJECT_VERSION` — but that only holds while
every setting change is made in both. So:

- Change settings in `project.yml` **and** the matching place in
  `project.pbxproj`, rather than in one of them.
- New source files have to be added to `project.pbxproj` too; it lists files
  explicitly, not by folder. Files under `JJMidnightExtension/UI`,
  `Parameters`, `DSP` and `Common` belong to **both** targets — the app hosts
  the same code in-process — except `Common/UI/AudioUnitViewController.swift`,
  which is the extension's alone.
- Before running `xcodegen generate`, regenerate into a scratch copy and diff
  `project.pbxproj` and the three schemes against the committed ones. Commit a
  regenerated project only once that diff is empty or understood.

Version numbers have their own procedure — four places, and a trap in
Xcode's General tab. See *Bumping the version* in
[APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md).

Supported Destinations is the setting that bites: Xcode's editor writes
`TARGETED_DEVICE_FAMILY`, `SUPPORTS_MACCATALYST`,
`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` and
`SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD`, and all four live in `project.yml`'s
`settings.base` so both targets get them identically. Change them there and
at project level in `project.pbxproj`, not in the target editor.

1. Select the **jj-midnight** scheme.
2. Set your Development Team on both **JJMidnight** and **JJMidnightExtension**.
3. Run on an iPhone, iPad, or simulator.

Open the app once so the Audio Unit registers.

## Factory presets

Thirteen, in panel order: Default, Laid Back, Escondido, Porch Light,
Whisper Trem, Magnolia, Breeze, Midnight, Sensitive Kind, Faded, Cassette,
Night Drive, Flat & Even.

The first run aims at the laid-back end the chain was designed around; Faded,
Cassette and Night Drive point the same engine at the compressed, washed-out
guitar sound a younger audience is buying. Further preset packs are the
intended way to grow this, not further DSP.

Names get shortened rather than lengthened when they drift near a song title
— *Call Me The Breeze* became **Breeze** and *After Midnight* became
**Midnight**. A preset name should point at a feel or a place; the shorter it
is, the less it can be read as a claim about a particular record. The same
instinct is why *Cocaine* became *Magnolia*, though that one was Review
Guideline 1.1.6 rather than trademark. See [marketing.md](marketing.md).

User presets: tap the preset window → **Save As…**; swipe left to rename or delete.
They are stored in the App Group, so the companion app and the plug-in in
any host see the same list. A preset chosen from a host's own preset menu
shows in the panel's window too.

Factory presets never set Input trim: it belongs to the rig, not the sound,
so changing preset leaves it where the player put it. User presets do store
it, since those are saved on the rig they were made for.

## Project layout

```
JJMidnight/                    Container app (test host)
JJMidnightExtension/
  Parameters/               AUParameterTree, presets, StoreKit unlock
  DSP/                      C++ kernel (real-time; no Swift)
  UI/                       SwiftUI editor, its view models, GearTheme finishes
  Common/                   AUAudioUnit / process glue
docs/                       Marketing site + privacy (GitHub Pages)
icon/ loop/ screenshots/    Asset generators (see below)
```

The editor is MVVM. Views draw and forward taps; state lives in three
`@Observable`, `@MainActor` view models, created by whoever hosts the panel
(`AudioUnitViewController` in the extension, `SimplePlayEngine` in the app)
with `EntitlementService` passed in:

- `MainPanelViewModel` — bypass, the licence gate, the paywall, and the one
  display loop that drives everything that moves on its own.
- `PresetBarViewModel` — the preset list and actions. It follows the audio
  unit's `currentPreset` and `userPresets` through KVO, which is how a
  host-side preset change reaches the panel.
- `MeterViewModel` — every meter's ballistics, advanced once per frame from
  the kernel's accumulators.

The panel itself is split by region: `PanelHeader`, `MasterStrip`, and
`PanelSections` (the four blocks, their shared chrome and `PanelMetrics`).
Parameters are looked up by address — `parameterTree[.compOn]` — so a wrong
name fails to compile.

Everything the render thread shares with the UI — parameters, the bypass and
licence flags, meter peaks — goes through relaxed atomics in the kernel
(`std::atomic_ref`, because Swift holds the kernel by value and
`std::atomic` is not copyable). Keep new shared state on the same footing.

`docs/` also carries one Markdown page per block — `comp.md`, `drive.md`,
`wobble.md`, `space.md`, plus `master.md` for Mix, Output and the output
metering — with the ranges, the measured behaviour, and what to reach for.

The screenshots under `docs/images/` are generated, not cropped by hand:
`screenshots/make-screenshots.sh` drives the app on a simulator and writes
both the site images and the App Store set. See
[APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md) for what the store wants.

Only edit `Parameters`, `DSP`, and `UI` for plug-in behaviour. The render
thread lives entirely in `JJMidnightDSPKernel.hpp`.

## Shared code with jj-breeze

`Common/`, the UI kit, and the trial/unlock plumbing are a copy of
jj-breeze's, not a shared dependency. At two plug-ins, copying is cheaper than
the abstraction; at three, pull the common parts out into a local SwiftPM
package (`JJKit`) rather than copying a third time. Fixes made here to shared
files should be carried back by hand until then.

## Demo parts

The container app bundles two real recordings, picked with the source
selector. Both are dry: no reverb, no compression, no saturation, because
this plug-in *is* the compressor, the breakup, the tremolo and the space, and
anything baked into a part would be heard twice.

| Segment | File | Length |
|---|---|---|
| **1** | `loop/loop_3.mp3` | 24 s |
| **2** | `loop/loop_1.mp3` | 15 s |

The segment numbers are positions, not file names — `loop_3` leads because it
is the take that shows the whole chain off best, and the picker opens on it.
`SimplePlayEngine.Source` spells this out; its cases are named `partOne` and
`partTwo` for exactly that reason, so nobody later "fixes" the mapping back
into file order.

`loop_2.mp3` was dropped. Three parts is more than the point needs, and the
two that stayed are the ones worth hearing the effect on.

Labels are bare numbers because "Guitar 1" truncates even in a segment this
wide; `Source.spokenName` keeps the full name for VoiceOver.

They are decoded on demand rather than at launch: both as PCM would be about
15 MB for audio the user may never select.

Raw takes (`loop/*.wav`) are gitignored; only the mixed-down MP3s ship.

## Generated assets

```sh
swift icon/make-icon.swift         # -> JJMidnight/Assets.xcassets/AppIcon.appiconset/AppIcon.png
python3 loop/make-loop.py          # -> loop/synthetic-test.mp3  (needs numpy and ffmpeg)
screenshots/make-screenshots.sh    # -> screenshots/store/ + docs/images/
```

`make-screenshots.sh` runs the `ScreenshotTests` UI target on a 6.9" iPhone
and a 13" iPad, pulls the frames out of the result bundles, and crops the
site's JPEGs from the same images. The store PNGs land at the exact pixel
sizes App Store Connect demands, with no device frames and no text over the
top — App Review rejects screenshots showing UI the app does not have.

Two things it does that are not obvious and should not be removed:

- **It pins the device to portrait before launching.** A simulator remembers
  how it was last left, so without that the frame size depends on what the
  previous run did to it. Landscape on the iPad is the better crop and does
  not work: rotating from inside a UI test flips the frame before the window
  relayouts, and the shot comes back with a black band down one side and
  Space clipped off the other.
- **It strips EXIF from everything it writes.** The simulator stamps an
  orientation tag that does not always agree with the pixels under it, and
  browsers honour it — which puts the panel on its side on the website.

Its build directory is `DerivedData/screenshots`, which `.gitignore` already
covers. `screenshots/store/` is committed: it is what gets uploaded.

`make-icon.swift` draws the same composition as jj-breeze's icon — panel,
corner screws, meter arc, serif wordmark, jewel lamps — in the Tweed
colourway, so the two read as one family. Its colours are the hex values from
`GearPalette.tweed`; change them together.

`make-loop.py` synthesises a dry fingerpicked guitar part with extended
Karplus-Strong. It is **not** bundled — it produced the placeholder the real
recordings replaced, and is kept because a synthetic part is useful for
testing against known material: exact pitch, known timing, and a seamless
loop, none of which a recording gives you. Its output is gitignored.

## Releases

| Version | Status |
|---|---|
| 1.0.0 (3) | Live on the [App Store](https://apps.apple.com/app/id6812455527) since 22 September 2026. |
| 1.0.1 (1) | On `main`, not uploaded. Under-the-hood fixes; no change to the sound. |

[APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md) carries every store field,
the 1.0.1 *What's New* text and its device checks, and the checklist for
each release. The Pages site is live at
[petergerov.github.io/jj-midnight-auv3](https://petergerov.github.io/jj-midnight-auv3)
— suffix included, the same shape as `jj-breeze-auv3`, and the part that gets
dropped by accident. Its download buttons point at the listing.

Still open:

- [ ] **Trademark clearance on the name** — `jj-midnight` is decided and
      shipped, not cleared. Focusrite's withdrawn Midnight plug-in suite and
      the current Midnight Plaza AUv3 were both checked and neither
      disqualifies it, but that was a web search; see
      [marketing.md](marketing.md).
- [ ] **Google Search Console** — the verification file is deployed
      (`docs/google3377e2442f8b8fe3.html`); confirm the property shows as
      verified.
- [ ] **Privacy policy** — `docs/privacy.html` is linked from the listing, so
      it has to keep describing the app that actually ships. Re-read it each
      release.
- [ ] **Cab convolution** — deliberately not in v1. `CabVoicing.h` is four
      biquads behind an interface convolution could take over later without
      anything upstream changing.
