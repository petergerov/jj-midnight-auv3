# Drive

Low-gain breakup and the speaker cabinet behind it. Everything in the Drive block's range sits between clean and the edge of breakup — there is no fuzz at the top of the knob, by design.

## Asymmetric clipping

A symmetric clipper produces only odd harmonics, which is the hard, fizzy half of distortion. A small bias in front of the clipper makes the curve asymmetric so the positive and negative halves round off differently, and the stage generates **second** harmonic as well. That is the difference between a fuzz pedal at low gain and a tweed amp just starting to give.

The bias grows with the Drive knob. A fixed bias would be swamped as the clipper saturates — a fully clipped wave is symmetric no matter what you offset it by — so the even harmonics would fade out exactly as the stage starts to break up, which is backwards. Letting the bias track drive is also what the tube does: grid conduction shifts the operating point as the stage is pushed.

Measured across the knob's range, with the rest of the chain out of the way:

| Drive | 2nd harmonic | 3rd harmonic |
|---|---|---|
| 10 % | 2.5 % | 7 % |
| 30 % | 7.4 % | 18 % |
| 60 % | 10.3 % | 25 % |
| 100 % | 11.4 % | 29 % |

## Level

Clipping the curve to ±1 bounds the peak but says nothing about level. For a while the stage only divided out its own small-signal slope — quiet passages stayed put, and the only level change left was the one the clipping itself caused. Metered on guitar after Comp's make-up (where parts often sit near −6…−3 dBFS) that meant Drive 0 → 100 % ran **−2 to −4.5 dB quieter** exactly when you were pushing into breakup.

The stage now matches RMS before and after the clipper, over a ~40 ms window. Loudness stays put across the knob; what changes is harmonics and compression inside the wave, not the fader. The match is against the clipper's own input — body and tone already applied — so the body shelf that comes up with Drive still thickens the bottom the way an amp does, without the clipper undoing the overall level.

Seeded from the small-signal inverse slope whenever the Drive knob moves, so a turn does not dip for a moment while the followers catch up. The harmonic figures above are ratios and are unaffected.

**Body** is not a separate knob. A low shelf at 150 Hz comes up with Drive, because pushing the front end of a real amp always thickens the bottom — an independent body control only invites settings that sound like a console EQ rather than an amp.

## The cabinet

Deliberately **not** convolution. A cabinet impulse response would be more accurate, but partitioned FFT convolution is the most expensive thing that could go on this render thread, and usable cabinet IRs are almost always named after the cabinet they were taken from.

What a 1×12 and the microphone in front of it do to a signal is five things, and all five are filters:

- nothing below ~85 Hz — a 12" driver in a small box does not reproduce it, and this is what keeps low-gain drive from turning to mud
- a body lift around 400 Hz, more of it the further off the dust cap the mic sits
- a broad presence rise around 1.8 kHz, the cone breaking up — how much of it the mic picks up depends on where the mic is
- a deep, narrow dip near 3.6 kHz — the cancellation that makes a guitar speaker sound like a guitar speaker rather than a hi-fi one
- a steep rolloff from ~5 kHz, which is the "no modern sparkle" part of the sound, sitting in the cab rather than in the tone control

**Mic** moves four of those five together — everything but the 85 Hz corner, which belongs to the box rather than the mic. Turning it up trades presence for body: the dust cap radiates the upper mids, the cone further out radiates less of them and more weight. That trade is the reason anyone moves a mic on a cabinet at all.

Measured end to end, with Drive at 30 % and Tone at its default:

| Band | Mic 0 → 100 |
|---|---|
| 500 Hz | +1.6 dB |
| 1 kHz | −2.0 dB |
| 1.8 kHz | −7.7 dB |
| 2.5 kHz | −6.8 dB |
| 3.6 kHz | −9.7 dB |
| 5 kHz | −5.9 dB |

Overall level barely moves — under 1 dB across the whole sweep on the bundled demo parts — so the knob changes tone rather than loudness.

It did not always. Presence was originally fixed, on the reasoning that the rise belongs to the driver rather than the mic, and everything Mic changed then sat above 2.5 kHz — where a guitar has little energy and these recordings have almost none. Sweeping it end to end moved them by 0.16 dB, which is to say it did nothing you could hear.

## Controls

| Control | Range | What it does |
|---|---|---|
| **Drive** | 0 … 100 % | Clean through to the edge of breakup. Body follows it. |
| **Tone** | 800 Hz … 10 kHz | Low-pass after the clipper — the rolled-back tone control, not a gentle de-esser. Above about 6 kHz the cab's own rolloff is the lower of the two corners, so the last part of the range opens the knob up rather than the sound: with Mic at 0 it is worth +0.3 dB at 5 kHz and +1.8 dB at 8 kHz. The cab corner, not Tone, is what caps the top end. |
| **Mic** | 0 … 100 % | 0 is on the dust cap: present and bright. 100 is well out toward the cone edge: rounder, darker, deeper dip. |
| **On/Off** | | Bypasses breakup *and* cabinet. Switching off the amp switches off the speaker too. |

## How to use it

- **Just past clean** — Drive 20–30 %, Tone around 2600 Hz, Mic at 60 %.
- **Gritty riff** — Drive 40–45 %, Tone down near 2000 Hz. **Cassette**.
- **Clean and open** — Drive under 15 %, Tone up near 4000 Hz, Mic low. **Porch Light**.
- **Clean DI, no speaker** — block off entirely.
