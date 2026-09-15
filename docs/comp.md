# Comp

The optical compressor at the front of the chain, and the reason everything after it sits back in the track.

It is not a mastering compressor and it will not behave like one. Optical cells have no sharp threshold and no adjustable ratio — they just start to lean on the signal — so this block gives you one **Comp** knob that moves threshold, ratio and make-up together, and two ballistics controls.

## What makes it optical

The release. In a real photocell the recovery is not a fixed time constant: it snaps back from a light squeeze and crawls back from a heavy one. Here the release coefficient is recomputed every sample from how much gain reduction is currently applied.

With **Release** at its default 140 ms:

| Gain reduction | Recovery |
|---|---|
| ~1.5 dB | ~340 ms |
| ~17 dB | ~1.9 s |

That program dependence is what you hear as *the compressor is never caught working*. Picked transients get rounded off, but the tail of a note never pumps back up at you.

The knee is soft (9 dB) and the ratio is gentle — 2:1 at the bottom of the Comp knob, about 4.5:1 at the top.

## Why one knob in %, and not a threshold in dB

A reasonable objection: compressors normally have a threshold in dB. Two conventions exist, and which one is right depends on what kind of compressor it is.

A VCA compressor — an 1176, a dbx 160, the one in your channel strip — gives you threshold, ratio, attack and release separately. There, dB is correct: you want to place the knee exactly.

An **optical** compressor does not work that way and is not built that way. The LA-2A has exactly one control, *Peak Reduction*, marked 0 to 10 with no unit at all — no threshold knob, no ratio knob, because the photocell decides both for itself and does it differently depending on what you feed it. Guitar compressors follow the same pattern: the Ross and the Dyna Comp label their single control "Sustain" or "Comp".

This block models a cell, so it follows that side. One knob moves three things at once:

| Comp | Threshold | Ratio | Make-up |
|---|---|---|---|
| 0 % | −2.0 dB | 2.00:1 | 0 dB |
| 25 % | −9.0 dB | 2.62:1 | 0 dB |
| 55 % | −17.4 dB | 3.38:1 | +4.4 dB |
| 75 % | −23.0 dB | 3.88:1 | +8.2 dB |
| 100 % | −30.0 dB | 4.50:1 | +13.2 dB |

Make-up stays at zero over the bottom quarter of the travel because it is
referred to a −10 dBFS source: until the threshold drops below that, there is
nothing being taken off to give back.

Labelling the knob with any one of those numbers would be a half-truth: you would see the threshold move and not the ratio or the make-up. And splitting them into separate controls would only let you build settings that no optical box can produce, which defeats the point of modelling one.

**The dB figure you actually want is right beside the knobs.** The needle in this section shows, in dB and in real time, how much the compressor is taking right now. That is the same division of labour the LA-2A has: an unmarked dial for *how much*, and a meter for *what is happening*. Set the knob by the meter and by ear, not by arithmetic.

## Controls

| Control | Range | What it does |
|---|---|---|
| **Comp** | 0 … 100 % | Threshold from −2 dB down to −30 dB, ratio from 2:1 to 4.5:1, and automatic make-up, all on one knob. Turning it up is more squash, not more level. |
| **Attack** | 5 … 80 ms | How fast the cell grabs. Slow on purpose — the range starts where a mastering compressor's would already be over. A fast attack here flattens the pick and takes the life out of it. |
| **Release** | 40 … 400 ms | The *fast* end of the release, for light gain reduction. The slow end is derived from it (about fourteen times longer), because on a real cell the two are not independently adjustable. |
| **On/Off** | | Bypass for Comp only. |

The detector is **stereo-linked**: it looks at max(|L|, |R|) and applies one gain to both channels, so a louder left side never pulls the image sideways.

## The GR meter

A single bar under Comp's own knobs, filling **right to left**: empty at the right with no reduction, growing leftwards as the compressor takes hold. A bar that filled left-to-right would read as *level*, which is the opposite of what this shows. Full scale is 20 dB; past that the setting is wrong rather than loud.

It replaced a moving-coil needle, and kept the two things that made the needle readable rather than the ones that made it look old:

- **Ballistics.** The fill is a damped mass on a spring, not a smoothed value: it accelerates towards the target, overshoots slightly and settles. Measured, 99 % in 233 ms with 2.4 % overshoot — a little quicker than a real VU movement's 300 ms, because a 300 ms movement blurs a 28 ms attack entirely. Without inertia a bar looks plotted rather than connected to the sound.
- **A non-linear scale.** Position goes as `(dB / 20)^0.7`, so the first few dB take up far more of the bar than the last few. That is how a real gain-reduction scale is printed, because 0–6 dB is where you work and 20 dB just means "too much".

What the bar dropped was height. A needle needs several times the depth of a bar, which forced Comp into a different shape from the other three sections; flat, it sits under its knobs and Comp stays a section like any other.

Set the Comp knob by this and by ear, not by arithmetic.

If the bar barely moves while the compressor still seems to be doing
something, the input is too quiet rather than the meter wrong: the threshold
is absolute, so a guitar arriving 20 dB below a mixed file never reaches it,
and what is left to hear is the make-up gain. Master's **Input** trim is the
fix; `docs/master.md` has the measurements.

## How to use it

- **Front-end glue on a DI** — Comp around 60 %, everything else off. That is the **Flat & Even** preset.
- **The Tulsa squash** — Comp 70–80 %, Attack up around 35–40 ms, Release 180–220 ms. **Laid Back** and **Sensitive Kind**.
- **Tight and grabby** — Comp 85 %+, Attack down near 18 ms, Release short. **Faded**.

If the part sounds lifeless, Attack is too fast: let more of the pick through before the cell closes.
