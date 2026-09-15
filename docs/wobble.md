# Wobble

Amplitude tremolo, the way an amp does it.

One LFO drives **both** channels. That is not a simplification — an amp's tremolo circuit modulates the whole output stage, and offsetting the two sides would put the guitar in two places at once. A stereo tremolo is a studio effect, not an amp.

## Shape

There are two tremolo circuits worth having, and **Shape** is the morph between them:

- **Down** — blackface amps modulate the bias and give a rounded, sine-ish sway.
- **Up** — brownface and optical circuits chop harder and land closer to a square.

The waveform is squared off by running the sine through a `tanh` and renormalising, so the corners stay band-limited and the modulation never clicks, which a real square LFO would.

## Gain, not level

The tremolo gain **peaks at unity and dips by Depth**, rather than swinging either side of unity. Turning Depth up therefore never makes the track louder — the part only gets quieter in the troughs. At Depth 80 % the gain range is 0.20 … 1.00.

A short smoother sits on the final gain so that moving Rate, Depth or Shape while audio is running cannot produce a click.

## Tempo sync

**SYNC** in the section header locks the rate to the host's tempo. The Rate knob is then replaced by **DIV**, a detented selector over seven note divisions:

`1/2` · `1/4` · `1/8.` · `1/4T` · `1/8` · `1/8T` · `1/16`

Slowest first, so the knob sweeps in one direction. A dotted eighth lasts one and a half eighths, so its *rate* is 2 / 1.5 = 4/3 of a cycle per beat — dotted values slow down where triplets speed up, which is why `1/8.` sits between `1/4` and `1/4T`.

Rate and Division stay **separate parameters** rather than one knob that changes meaning, so each remains a single thing to a host's automation. The panel shows whichever one SYNC selects.

If the host reports no tempo, the rate falls back to the Rate knob. The companion app has no transport at all, so SYNC does nothing there — freezing or going silent would be far worse than simply not being in sync.

Factory presets all ship with SYNC **off**. A synced tremolo changes speed with the project, which is a per-track decision rather than something a preset should make on your behalf — and free-running is what an amp does.

## Controls

| Control | Range | What it does |
|---|---|---|
| **Rate** | 0.2 … 12 Hz | Slow sway down at the bottom, near-ring-mod flutter at the very top. Most of the useful range for this style is 3–7 Hz. Hidden while SYNC is on. |
| **Div** | 1/2 … 1/16 | Note division when SYNC is on. Detented — the pointer cannot rest between marks. |
| **Sync** | | Locks Rate to the host tempo. |
| **Depth** | 0 … 100 % | How far the troughs dip. 20–35 % is a shimmer you feel rather than hear; 50 %+ is the effect out front. |
| **Shape** | 0 … 100 % | Sine through to a band-limited chop. |
| **On/Off** | | Bypass for Wobble only. The LFO keeps running, so switching back is phase-continuous. |

## How to use it

- **A shimmer under everything** — Rate 4–5 Hz, Depth 25–30 %, Shape low. **Laid Back**.
- **The effect out front** — Depth 50–70 %, Shape 45 %+. **Midnight**, **Whisper Trem**.
- **Tape warble** — Rate down near 1.8 Hz, Depth 40 %, Shape 0. **Cassette**.
- **Off** — some of the best settings here have no tremolo at all. **Night Drive**.

Watch Rate against the tempo of the part. A tremolo that lands on a division of the beat reads as rhythm; one that does not reads as an effect. Both are useful — just pick on purpose.
