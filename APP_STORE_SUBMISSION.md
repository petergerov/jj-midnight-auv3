# App Store submission — jj-midnight

Everything App Store Connect asks for, written down once so the answers do
not get improvised at the upload screen. Copy the fenced blocks verbatim;
they are already inside Apple's character limits.

Two rules from [marketing.md](marketing.md) govern every line of copy here
and are worth restating before anything gets pasted:

- **No song titles, artist names, or band names in the listing.** They are
  tolerable on preset names inside the app and are not tolerable on a store
  page, which is the surface a trademark holder actually reads. Describe the
  sound instead.
- **Never claim the plug-in reproduces a particular record or rig.** The
  presets are original settings arrived at by ear.

---

## Status

| | |
|---|---|
| Binary | Builds and runs. Not archived or uploaded yet. |
| App Store Connect record | **Not created.** |
| IAP record | **Not created.** Must ship attached to v1.0.0. |
| Screenshots | iPhone 6.9" done. iPad 13" needs one re-run — see below. |
| Copy | Drafted here, not entered. |
| Privacy policy | Live at `docs/privacy.html`, one stale sentence to fix. |
| Repo/Pages rename | **Outstanding** — every `jj-midnight` URL 404s until done. |

The repository rename is the one that blocks the others: the support and
marketing URLs below point at a repo still named `jj-tulsa`, and a listing
cannot go in with dead links.

---

## Identifiers

Set in `project.yml`, which is the source of truth — `xcodegen generate`
rewrites `project.pbxproj` from it, so anything changed in Xcode's GUI is
gone at the next run.

| Field | Value |
|---|---|
| App bundle ID | `com.gerov.jjmidnight` |
| Extension bundle ID | `com.gerov.jjmidnight.AUv3` |
| App Group | `group.com.gerov.jjmidnight` |
| Team ID | `C9LBGZNZ6P` |
| Version / build | `1.0.0` (`1`) |
| Deployment target | iOS 17.0 |
| Devices | iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`) |
| Mac (Designed for iPad) | Yes |
| Mac Catalyst / visionOS | No |

**AU identity:** type `aufx`, subtype `Jjm1`, manufacturer `Grov`. Hosts list
it as **jj-midnight** under manufacturer **Gerov**.

These four-character codes are permanent in practice. A host saves them into
every project file that uses the plug-in, so changing one after release
silently breaks every session a customer has already saved.

---

## App information

**Name** (30 char limit, currently 11):

```
jj-midnight
```

**Subtitle** (30 char limit, currently 29):

```
Vintage guitar chain for AUv3
```

**Primary category:** Music
**Secondary category:** Entertainment

**Age rating:** 4+. Nothing in the app triggers a higher band — worth a
second look at the preset names before each release, though, because they
are visible in screenshots and Guideline 1.1.6 covers references to illegal
drugs. That is why the preset once called *Cocaine* is now *Magnolia*.

---

## Description

4000 char limit; this is about 1,900.

```
Squashed until nothing jumps out. Just past clean. Wobbling a little. One
repeat behind.

That sound is not one pedal — it is a whole chain, and jj-midnight is all of
it in a single insert. Four blocks in signal order, each with its own on/off
switch, plus a master strip.

COMP — An optical compressor with program-dependent release, the way a real
opto box behaves: one knob for threshold, ratio and make-up together, so it
squashes without asking you to think about it. A gain-reduction meter reads
out what it is doing. This is the block the whole plug-in is built around.

DRIVE — Asymmetric soft clipping voiced for second harmonic rather than
fizz, a tone rolloff, and a 1x12 cabinet with a movable mic position. Low
gain on purpose. It goes from clean with weight to the edge of breakup and
stops there.

WOBBLE — Amp-style amplitude tremolo with an LFO that morphs from a sine
sway to a hard chop, free-running or synced to your host's tempo.

SPACE — One slapback repeat with no feedback, into a spring tank with
dispersion allpasses for the chirp a real tank makes.

THIRTEEN FACTORY PRESETS
Default, Laid Back, Escondido, Porch Light, Whisper Trem, Magnolia, Breeze,
Midnight, Sensitive Kind, Faded, Cassette, Night Drive, Flat & Even. Save
your own from the preset window; swipe left to rename or delete.

WORKS WHERE YOU WORK
An Audio Unit v3 effect: GarageBand, Logic for iPad, AUM, Cubasis,
BeatMaker, and any other AUv3 host. The included app is a working player, so
you can hear the plug-in on a real guitar part before you open a DAW at all
— two dry recordings are bundled, or run your own playing in through the
microphone.

The panel is drawn procedurally rather than assembled from bitmaps, so it
stays sharp at whatever size your host gives it, on a phone or a 13-inch
iPad.

FREE TO TRY
Seven days free from first launch. No account, no signup, no subscription.
After that, one purchase unlocks it permanently on all your devices. If you
do not buy it, the editor keeps working and audio passes through dry —
nothing you built disappears.

jj-midnight is an original effect. Preset names point at a feel or a place.
It is not affiliated with, endorsed by, or associated with any artist,
label, or other plug-in maker, and does not recreate any particular
recording.
```

**Promotional text** (170 char limit, editable without a new build — use it
for launch notes rather than burning a release on a copy change):

```
Compressor, amp breakup, tremolo, slapback and spring in one AUv3 insert.
Seven days free, then one purchase — no subscription.
```

**Keywords** (100 char limit, comma-separated, no spaces after commas — a
space costs a character and buys nothing):

```
guitar,auv3,audio unit,compressor,tremolo,spring,reverb,slapback,amp,pedal,lofi,effect,plugin
```

Do not repeat words already in the name or subtitle; Apple indexes those
anyway, so "midnight", "vintage" and "chain" would be wasted.

**What's New:** leave empty. It does not appear on a first release.

---

## URLs

| Field | Value |
|---|---|
| Marketing URL | `https://petergerov.github.io/jj-midnight` |
| Support URL | `https://github.com/petergerov/jj-midnight/issues` |
| Privacy Policy URL | `https://petergerov.github.io/jj-midnight/privacy.html` |

All three are dead until the repository is renamed from `jj-tulsa`. GitHub
redirects the old URLs afterwards, so the rename is safe to do late — but it
has to happen before these are entered.

`docs/privacy.html` also still says the app bundles **three** guitar parts.
It bundles two. Fix that before submitting: the privacy policy is a document
Apple links to from the listing, and it should not describe an app that does
not exist.

---

## In-app purchase

One non-consumable. It must be submitted **attached to the v1.0.0 build** —
an IAP left unattached sits in "Ready to Submit" forever while the app ships
without a way to buy it.

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Product ID | `com.gerov.jjmidnight.unlock` |
| Reference name | jj-midnight Unlock |
| Price tier | $2.99 (USD) |
| Family Sharing | Enabled |

**Display name** (30 char limit, currently 18):

```
jj-midnight Unlock
```

**Description** (45 char limit — far shorter than the app description field,
and the usual place a submission trips):

```
Unlock the effect forever. One purchase.
```

The longer wording in `Configuration/Products.storekit` ("Permanent unlock
for jj-midnight on all your devices…") is fine where it is — that file is a
local test fixture with no length limit — but it will not fit this field.

These otherwise match `Configuration/Products.storekit`, the local StoreKit
configuration the scheme runs against. The product ID also appears in
`JJMidnightExtension/Parameters/PurchaseProducts.swift`; all three have to
agree or the paywall shows "Unlock product not available yet."

The IAP review screenshot can be `screenshots/store/iphone-6.9/01-panel.png`
— Apple only requires that the reviewer can see where the purchase lives.

---

## Screenshots

Generated by `screenshots/make-screenshots.sh`, which runs the app on a
stock simulator and unpacks the frames. No device frames, no composited
backgrounds, no marketing text over the top: App Review rejects screenshots
showing UI the app does not have, and this panel is its own best
advertisement.

| Slot | Path | Size |
|---|---|---|
| iPhone 6.9" (required) | `screenshots/store/iphone-6.9/` | 1320 x 2868 |
| iPad 13" (required) | `screenshots/store/ipad-13/` | 2752 x 2064 |

Apple scales every other size from these two, so no other set is needed.

Order to upload them in — the first is the one shown in search results, so
it is the whole panel:

1. `01-panel` — the panel as it opens.
2. `02-space-master` — Wobble, Space and the master strip (iPhone only; on
   an iPad the panel already fits and the script drops this as a duplicate).
3. `03-presets` — the preset window open over the panel.

**There is deliberately no paywall screenshot.** The price on that sheet is
whatever the viewer's storefront charges, and a screenshot freezes one
currency onto a listing sold in every country. The trial terms live in the
description, where they can be edited without a new binary.

⚠️ **The iPad set needs one more run.** The iPad shots are taken in
landscape, and the first attempts came back as portrait pixels carrying an
EXIF rotation tag — which previews render correctly and App Store Connect,
which reads pixel dimensions, would read as the wrong size. The fix (taking
`app.screenshot()` rather than `XCUIScreen.main.screenshot()`) is committed
but has not been run to completion. Re-run the script and confirm the iPad
PNGs are **2752 x 2064 with no `eXIf` chunk** before uploading:

```sh
screenshots/make-screenshots.sh
python3 - <<'PY'
import glob, struct
for p in sorted(glob.glob("screenshots/store/*/*.png")):
    d = open(p, "rb").read(3000)
    w, h = struct.unpack(">II", d[16:24])
    print(f"{w}x{h}", "EXIF-TAGGED" if b"eXIf" in d else "ok", p)
PY
```

---

## App privacy

Answer **Data Not Collected**. There is no account, no analytics, no
advertising SDK, and no crash reporter that phones home. The only things
stored are the install date and the cached unlock state, both in
`UserDefaults` and the App Group, both on-device, neither leaving it.

Purchases go through StoreKit, which is Apple's own transaction — it does
not make the developer a data collector.

**Microphone:** the container app asks for it so you can hear the effect on
live input. The usage string is in `JJMidnight/Info.plist`. Audio is
processed on-device, never written to disk by this app and never uploaded.
Permission is optional — the two bundled guitar parts work without it.

---

## Export compliance

`ITSAppUsesNonExemptEncryption` is already `false` in `JJMidnight/Info.plist`,
so App Store Connect will not ask at upload. The app uses no encryption
beyond what iOS itself provides for HTTPS.

---

## App Review notes

Paste into the review notes field. An AUv3 is not obvious to review — the
part being sold is invisible until it is loaded inside a different app, and
reviewers have failed plug-ins for that alone.

```
No account or login is required. Nothing is gated behind a signup.

jj-midnight is an Audio Unit (AUv3) effect plug-in. The app you have
downloaded contains the plug-in and also works as a standalone player, so
the effect can be reviewed without installing a DAW:

1. Open the app. It opens on guitar part 1 — tap Play.
2. Turn any knob on the panel. Comp, Drive, Wobble and Space each have an
   on/off switch so their contribution can be heard individually.
3. Tap the preset window at the top to load any of the 13 factory presets.

To review it as a plug-in inside another app (optional):

1. Open jj-midnight once, so iOS registers the Audio Unit.
2. Open GarageBand, create an Audio Recorder track.
3. Plug-ins & EQ -> Edit -> Audio Unit Extensions -> jj-midnight.

TRIAL AND PURCHASE
The effect is free for 7 days from first launch, with no signup. After that
it can be unlocked with a single non-consumable purchase
(com.gerov.jjmidnight.unlock). There is no subscription. When the trial ends
and the app has not been unlocked, the editor stays fully usable and audio
passes through unprocessed rather than the app locking the user out.

The trial start date is written to the app's App Group container on first
launch, so the app and the plug-in extension agree on how much trial is left
whichever one the user opens first.

MICROPHONE
The microphone is optional and used only to feed live audio through the
effect in the standalone player. Two dry guitar recordings are bundled so
the app can be reviewed without granting it.
```

---

## Before you hit submit

- [ ] Rename the repository and Pages site from `jj-tulsa`, then confirm all
      three URLs above resolve.
- [ ] Fix "three guitar parts" in `docs/privacy.html`.
- [ ] Re-run `screenshots/make-screenshots.sh`; verify the iPad PNGs are
      2752 x 2064 with no EXIF tag.
- [ ] Create the App Store Connect record and the IAP; attach the IAP to the
      v1.0.0 build.
- [ ] Set `APP_STORE_URL` in `docs/index.html` once the listing exists —
      until then the download buttons fall back to the repository.
- [ ] Archive with the **jj-midnight** scheme, Release config. Do not archive
      the extension as its own product; that produces a generic archive with
      no App Store Connect record behind it.
- [ ] Confirm the archived build registers the AU on a real device, not just
      the simulator — extension registration fails on iPad often enough to be
      worth checking every release.
- [ ] Trademark clearance on the name. Focusrite's withdrawn Midnight suite
      and the current Midnight Plaza AUv3 were both checked and neither
      disqualifies it, but that was a web search, not clearance. See
      [marketing.md](marketing.md).

---

## Things that are not settled

**Google Search Console.** `docs/` carries no verification file. jj-breeze's
token belongs to that property and cannot be reused, so the site will not be
indexed until a new one is added.

**Preset packs, not more DSP.** The engine is generic and the presets are the
flavour; that is the intended way to grow this. Worth keeping the listing
copy free of anything that boxes it into one genre.
