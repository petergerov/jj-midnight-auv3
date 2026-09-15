# Space

Slapback and spring, the last block in the chain.

## Slapback

One repeat. There is **no feedback** — the delay line is a single tap, not a decaying echo train — because that is what a slapback is. Turning Echo up gives you a louder repeat, never more of them.

The tap carries a little wobble of its own (about 0.3 ms at a third of a hertz, the two sides out of phase with each other). That is tape flutter, and it is what keeps a single dry repeat from sounding like a digital copy pasted behind the note. The right side is 4 % longer than the left, which is barely wider than mono.

**80–120 ms is the window** for the classic sound. Shorter gets you doubling; past about 150 ms it stops being a slap and becomes a tape echo.

## Spring

Two things separate a spring from a plate or a room, and both are here.

**Dispersion.** A real spring is a mechanical transmission line, and high frequencies travel along it faster than low ones. Hit it and the reflection arrives smeared into the characteristic descending chirp — the "boing". That is what the chain of allpass filters in front of the tank does: a cascade of short allpasses is a frequency-dependent delay, which is exactly the physics. A real tank behaves like a hundred-odd stages; eight gets the character at a fraction of the cost, and the ear reads the chirp long before it counts the stages.

**Bandwidth.** A spring is a narrow, resonant thing with almost no bass and very little above a few kHz. The bandpass in front of the tank (170 Hz to 4.2 kHz) matters more to *sounds like a spring* than the tank itself does — reverb fed full-range input just sounds like a cheap plate.

Behind that sits a plain Schroeder tank: three combs in parallel into two allpasses in series, with delay times chosen so the modes do not stack into a ringing pitch.

There is no decay control, on purpose. On a real amp the reverb knob is a mix control and the tank's decay is fixed, so here decay follows Spring: turning it up lengthens the tail as well as raising it.

## Controls

| Control | Range | What it does |
|---|---|---|
| **Slap** | 40 … 250 ms | Time of the single repeat. |
| **Echo** | 0 … 100 % | Level of that repeat. |
| **Spring** | 0 … 100 % | Tank level, and its decay with it. |
| **On/Off** | | Bypasses slapback and spring together. |

The slapback feeds the spring, not the other way round — so the repeat is reverberated along with the dry note rather than the reverb being echoed into mush.

## How to use it

- **Classic slap** — Slap around 100 ms, Echo 25 %, Spring low. **Laid Back**.
- **Dry and close** — Spring under 10 %, let the echo do the room work. **Escondido**.
- **Amp reverb, no echo** — Echo at 0, Spring 30 %+. **Porch Light**.
- **Wide open** — Spring 60 %+ for an ambient tail. **Night Drive**.
