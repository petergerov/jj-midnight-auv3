#pragma once

#include "Biquad.hpp"

/** A single-channel low-gain breakup stage: low-shelf body, low-pass tone,
    then asymmetric soft clipping.

    Carried over from jj-breeze's WarmthStage, with one change. The original
    ran a symmetric tanh, which is only odd harmonics — the hard, fizzy half
    of distortion. A small DC offset in front of the clipper makes the curve
    asymmetric, so the positive and negative halves round off differently and
    the stage generates second harmonic as well. That is the difference
    between "fuzz pedal at low gain" and "tweed amp just starting to give",
    and it is the whole point of this plug-in's drive block.

    The offset is subtracted back out after clipping so the stage stays DC-free.

    Level: an RMS follower matches the clipper's output loudness to its own
    input (post body/tone), so turning Drive up changes character rather than
    volume. Without that, soft-clip makeup that only restores the small-signal
    slope leaves hot parts quieter as they dig into the curve — which is what
    a guitar after Comp's make-up spends most of its time doing.
*/
class DriveStage
{
public:
    void prepare(double newSampleRate)
    {
        sampleRate = newSampleRate;
        // ~40 ms: fast enough to follow a Drive knob move, slow enough not
        // to pump on individual pick attacks.
        const float tau = 0.04f;
        rmsCoeff = 1.0f - std::exp(-1.0f / (tau * static_cast<float>(sampleRate)));
        updateLowShelf();
        reset();
    }

    void reset()
    {
        lowShelf.reset();
        filter.reset();
        inRmsSq = 0.0f;
        outRmsSq = 0.0f;
        makeup = 1.0f;
    }

    /// Tone is a low-pass corner, not a shelf: turning it down is the
    /// "Tone-Poti zurückgedreht" move, not a gentle de-esser.
    void setToneHz(float hz)
    {
        filter.setFromArray(Biquad::makeLowPass(sampleRate, hz, 0.707f));
    }

    void setDrive(float amount01)
    {
        if (std::abs(amount01 - drive) < 1.0e-4f)
            return;
        drive = amount01;
        updateDriveCurve();
    }

    void setBodyAmount(float amount01)
    {
        if (std::abs(amount01 - bodyAmount) < 1.0e-4f)
            return;
        bodyAmount = amount01;
        updateLowShelf();
    }

    float processSample(float x)
    {
        const float shelved = lowShelf.processSample(x);
        const float filtered = filter.processSample(shelved);

        if (drive < 1.0e-4f)
            return filtered;

        // Peak-normalise to the louder half of the asymmetric curve so the
        // biased side cannot run past ±1.
        const float clipped = (std::tanh(filtered * gain + bias) - offset)
                            / (1.0f + offset);

        // Loudness match against the clipper's own input (body + tone already
        // applied). Matching pre-shelf would cancel the body boost that is
        // supposed to come up with Drive.
        inRmsSq += rmsCoeff * (filtered * filtered - inRmsSq);
        outRmsSq += rmsCoeff * (clipped * clipped - outRmsSq);

        const float inRms = std::sqrt(std::max(inRmsSq, 0.0f));
        if (inRms > silenceFloor)
        {
            const float outRms = std::sqrt(std::max(outRmsSq, 0.0f));
            const float target = inRms / std::max(outRms, silenceFloor);
            // Same time constant as the RMS window: the ratio is already
            // smoothed by the followers, so a second pole would lag a knob
            // move. Clamp so a near-silent clipped sample cannot explode.
            makeup = std::clamp(target, makeupMin, makeupMax);
        }

        return clipped * makeup;
    }

private:
    /// Everything that depends only on the drive amount, so the render loop
    /// does not recompute a tanh per sample for values that change once per
    /// block.
    void updateDriveCurve()
    {
        // Gain tops out well below a fuzz: the knob's whole range stays in
        // clean-to-edge-of-breakup territory.
        gain = 1.0f + drive * 11.0f;

        // The bias grows with drive. A fixed bias would be swamped as the
        // tanh saturates — a fully clipped wave is symmetric no matter what
        // you offset it by — so the even harmonics would fade out exactly as
        // the stage starts to break up, which is backwards. Letting it track
        // drive is also what the tube does: grid conduction shifts the
        // operating point as the stage is pushed. Measured over the knob's
        // range this puts second harmonic at 2.5% of the fundamental at the
        // bottom and 11% at the top, always well under the odd content.
        bias = biasTracking * drive;
        offset = std::tanh(bias);

        // Seed makeup at the small-signal inverse slope so a Drive knob move
        // does not dip for a moment while the RMS followers catch up. The
        // follower then takes over for whatever level is actually playing.
        const float coshBias = std::cosh(bias);
        const float slope = gain / (coshBias * coshBias * (1.0f + offset));
        makeup = 1.0f / slope;
    }

    void updateLowShelf()
    {
        static constexpr float bodyHz = 150.0f;
        static constexpr float maxBoostDb = 6.0f;
        const float linearGain = std::pow(10.0f, (bodyAmount * maxBoostDb) / 20.0f);
        lowShelf.setFromArray(Biquad::makeLowShelf(sampleRate, bodyHz, 0.707f, linearGain));
    }

    static constexpr float biasTracking = 0.7f;
    static constexpr float silenceFloor = 1.0e-5f;
    // Floor below the full-Drive small-signal seed (~0.21): clamping at 0.25
    // left quiet parts a couple of dB hot. Ceiling is a runaway guard only —
    // steady guitar stays well under it.
    static constexpr float makeupMin = 0.05f;
    static constexpr float makeupMax = 8.0f;

    double sampleRate = 44100.0;
    Biquad lowShelf;
    Biquad filter;
    float drive = 0.0f;
    float bodyAmount = 0.0f;
    float gain = 1.0f;
    float bias = 0.0f;
    float offset = 0.0f;
    float makeup = 1.0f;
    float rmsCoeff = 0.001f;
    float inRmsSq = 0.0f;
    float outRmsSq = 0.0f;
};
