#pragma once

#include "Biquad.hpp"

/**
    A 1x12 guitar cabinet, off-axis, as four biquads.

    This is deliberately not convolution. An impulse response would be more
    accurate, but partitioned FFT convolution is the most expensive thing
    that could go on this render thread, and usable cabinet IRs are almost
    always named after the cabinet they were taken from — which is the same
    trademark problem the plug-in's name already has to route around.

    What a guitar cab and a microphone in front of it do to a signal is five
    things, and all five are filters:

      * nothing below ~85 Hz — a 12" driver in a small sealed box simply
        does not reproduce it, and this is what keeps low-gain drive from
        turning to mud;
      * a body lift around 400 Hz, more of it the further off the dust cap
        the microphone sits;
      * a broad presence rise around 1.8 kHz, the driver's cone breakup —
        how much of it reaches the microphone depends on where the microphone
        is;
      * a deep, narrow dip near 3.6 kHz — the cancellation that makes a
        guitar speaker sound like a guitar speaker rather than a hi-fi one;
      * a steep rolloff from ~5 kHz, which is the "no modern sparkle" part
        of the brief, sitting in the cab rather than in the tone control.

    `setOffAxis` moves four of those five together — everything except the
    85 Hz corner, which is the box rather than the mic.

    Convolution can be added behind this same interface later if anyone asks
    for it; nothing upstream would have to change.
*/
class CabVoicing
{
public:
    void prepare(double newSampleRate)
    {
        sampleRate = newSampleRate;
        highPass.setFromArray(Biquad::makeHighPass(sampleRate, 85.0f, 0.707f));
        setOffAxis(0.5f);
        reset();
    }

    void reset()
    {
        highPass.reset();
        body.reset();
        presence.reset();
        dip.reset();
        lowPass.reset();
    }

    /** 0 = mic on the dust cap: present, bright, shallow dip. 1 = well out
        towards the cone edge: rounder, darker, deeper dip. */
    void setOffAxis(float amount01)
    {
        const float a = std::clamp(amount01, 0.0f, 1.0f);
        if (std::abs(a - offAxis) < 1.0e-4f)
            return;
        offAxis = a;

        // Presence is the main thing the mic position buys or spends, and it
        // is why anyone bothers moving a mic on a cabinet at all: the dust cap
        // radiates the upper mids, the cone further out radiates less of them
        // and more body. Trading +5 dB for -2 dB at 1.8 kHz is that move.
        //
        // This used to be fixed at +3 dB on the reasoning that the presence
        // rise belongs to the driver rather than the mic. The rise does — how
        // much of it a microphone picks up does not, and leaving it fixed was
        // why this control was nearly inaudible: everything it changed sat
        // above 2.5 kHz, where a guitar has little energy and the demo parts
        // have almost none. Sweeping it end to end moved the loops by 0.16 dB.
        const float presenceDb = 5.0f - a * 7.0f;
        presence.setFromArray(Biquad::makePeakFilter(sampleRate, 1800.0f, 1.1f, dbToGain(presenceDb)));

        // Body comes up as presence goes away, which is the other half of the
        // same trade and keeps the knob from being merely a tone control:
        // off-axis is not just darker, it is rounder.
        const float bodyDb = a * 2.5f;
        body.setFromArray(Biquad::makePeakFilter(sampleRate, 400.0f, 0.8f, dbToGain(bodyDb)));

        // The dip deepens and the rolloff comes down as the mic moves off.
        const float dipDb = -6.0f - a * 7.0f;
        dip.setFromArray(Biquad::makePeakFilter(sampleRate, 3600.0f, 2.2f, dbToGain(dipDb)));

        const float cornerHz = 6200.0f - a * 1700.0f;
        lowPass.setFromArray(Biquad::makeLowPass(sampleRate, cornerHz, 0.707f));
    }

    float processSample(float x) noexcept
    {
        float v = highPass.processSample(x);
        v = body.processSample(v);
        v = presence.processSample(v);
        v = dip.processSample(v);
        return lowPass.processSample(v);
    }

private:
    static float dbToGain(float db) { return std::pow(10.0f, db / 20.0f); }

    double sampleRate = 44100.0;
    float offAxis = -1.0f;
    Biquad highPass, body, presence, dip, lowPass;
};
