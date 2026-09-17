# Master

Input, Mix and Output act on the whole chain, and the two meters report what
enters and leaves it. Not a fifth stage in the signal path — a strip carrying
the four blocks, which is why it has no on/off switch of its own.

It sits **above** the blocks rather than below them. Every threshold
downstream is absolute, so nothing under it is worth judging until Input is
right; at the bottom of a scrolling panel it was off screen at the moment it
mattered most.

## Controls

| Control | Range | What it does |
|---|---|---|
| **Input** | −12 … +24 dB | Trim before the whole chain, dry path included. The first thing to set on a live rig; see below. |
| **Mix** | 0 … 100 % | Dry/wet for the **entire** chain, not for one block. Leave it at 100 % on a guitar track. |
| **Output** | −12 … +12 dB | Trim after the mix. |

## Input, and why it is asymmetric

The compressor threshold is an absolute dBFS number, and so is the point where
the drive curve starts to bend. Neither of them knows how loud the instrument
is — they only meet it where it is loud enough to arrive. A mixed file peaks
near 0 dBFS and reaches everything; an electric guitar into an interface
arrives 15–20 dB lower and reaches almost none of it.

With Comp at its default 55 % the threshold is −17.4 dBFS and the 9 dB knee
means nothing at all happens below −21.9 dBFS. Measured, maximum gain
reduction on a guitar part:

| Guitar peak | Trim 0 | +6 dB | +12 dB | +18 dB | +24 dB |
|---|---|---|---|---|---|
| −18 dBFS | 0.1 dB | 1.4 dB | 4.7 dB | 9.8 dB | 14.1 dB |
| −24 dBFS | 0.0 dB | 0.1 dB | 1.4 dB | 4.7 dB | 9.8 dB |
| −30 dBFS | 0.0 dB | 0.0 dB | 0.1 dB | 1.4 dB | 4.7 dB |

Untrimmed, a live rig gets the Comp knob's make-up — up to +13 dB — and none
of its compression. That is audible as the track getting louder and the drive
stage breaking up earlier, which is easy to mistake for the compressor
working, while the GR meter correctly reports the nothing that is happening.
The trim is what closes that gap, and it boosts far more than it cuts because
being too quiet is the case that actually occurs.

It sits **ahead of the dry split**, not inside the wet path, so Mix goes on
blending two signals that agree about how loud the input was.

## The input meter

Directly above the output meter, drawn to the same width and the same −54 dBFS
scale, so the two bars can be read against each other: what arrived on top,
what left underneath, and the distance between them is what the chain did. On
a wide panel the pair brackets the knob row, input pinned to the top of the
column and output to the bottom.

Numeric first, because the header's IN ladder cannot do this job. Ten segments over 48 dB is 4.8 dB each, so −14, −12 and −10 dBFS
all light exactly seven — the entire useful target falls inside one segment.
A guitar arriving 20 dB too quiet still shows three lit lamps, which reads as
"signal is there" rather than "nothing downstream will trigger".

So the number is the instrument and the bar is the glance. Both read
**post-trim**: this is the meter you set the trim by, not a record of what the
host sent. Ballistics match the output meter too — instant rise, 20 dB/s fall,
1.5 s peak hold — so nothing about the pair is comparable only approximately.

The band painted into the track is −15 to −8 dBFS, which is where Comp's
make-up assumption and the bend in the drive curve both live. It is not a clip
warning; the top of it is 8 dB below full scale. The readout goes grey below
the band, green inside it, amber above. Aim for the band on your loudest
playing and the GR meter starts to move.

The kernel keeps a second input accumulator for it (`mPeakInTrim`). Reading a
peak clears it, so one accumulator with two readers would have the header
ladder and this meter taking turns seeing silence.

Factory presets do not carry a value for it. Trim is a property of the rig,
not of the sound, so changing preset leaves it where you set it. Your own
saved presets do store it, since those are tied to your rig.

Every block has its own switch, so Mix is not the way to take one out — it is
the way to put the whole chain in parallel with the dry signal. That is worth
having on something other than a guitar: at 30–40 % the compressor and the
cabinet colour a keyboard or a drum loop without swallowing it.

## The output meter

Two bars, left over right, with a dB scale, peak-hold ticks and a clip lamp.

It is here rather than only in the header's small IN/OUT ladders because this
chain adds a lot of level on its own. The compressor's make-up reaches
**+13 dB** at the top of the Comp knob, and Output can add another 12. A clip
after all of that is easy to miss, and the render path does not hard-limit —
samples can and do exceed 0 dBFS.

| | |
|---|---|
| Scale | −54 … 0 dBFS, linear in dB |
| Rise | instant |
| Fall | 20 dB/s |
| Peak hold | 1.5 s |
| Clip lamp | latches 1.5 s from the last sample at or above −0.1 dBFS |

**The ballistics differ from the gain-reduction bar on purpose.** Gain
reduction gets spring inertia — it accelerates, overshoots slightly and
settles — because without that a bar looks plotted rather than connected to
the sound. Output level gets instant rise and a fixed fall, which is how a
peak programme meter behaves: for level you want to see the peak, not a mass
chasing it. Reading a compressor and reading a level are different jobs.

The peak-hold tick matters more than it looks. A pick attack through this
chain can clip on a single transient and be gone before the eye catches the
bar; the tick stays put for a second and a half so you see what happened.

## How to use it

- **On a guitar** — Mix at 100 %, Output to taste, and watch the bars rather
  than the host's channel meter: what you set here is what the host receives.
- **As a parallel colour** — Mix 30–40 % on a keyboard, a drum loop, or a
  vocal. The compressor and the cabinet do the work; the dry signal keeps the
  transients.
- **If the clip lamp latches** — pull Output down first. If it still latches,
  the Comp knob is high enough that its make-up is doing it, and that is the
  control to back off.
