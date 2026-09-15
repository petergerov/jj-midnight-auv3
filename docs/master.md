# Master

Mix and Output act on the whole chain, and the output meter reports what
leaves it. Not a fifth stage in the signal path — a strip under the four
blocks, which is why it has no on/off switch of its own.

## Controls

| Control | Range | What it does |
|---|---|---|
| **Mix** | 0 … 100 % | Dry/wet for the **entire** chain, not for one block. Leave it at 100 % on a guitar track. |
| **Output** | −12 … +12 dB | Trim after the mix. |

Every block has its own switch, so Mix is not the way to take one out — it is
the way to put the whole chain in parallel with the dry signal. That is worth
having on something other than a guitar: at 30–40 % the compressor and the
cabinet colour a keyboard or a drum loop without swallowing it.

## The output meter

Two bars, left over right, with a dB scale, peak-hold ticks and a clip lamp.

It is here rather than only in the header's small IN/OUT ladders because this
chain adds a lot of level on its own. The compressor's make-up reaches
**+13 dB** at the top of the Comp knob, Drive adds more on top of that, and
Output can add another 12. A clip after all of that is easy to miss, and the
render path does not hard-limit — samples can and do exceed 0 dBFS.

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
