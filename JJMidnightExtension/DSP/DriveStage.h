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
*/
class DriveStage
{
public:
    void prepare(double newSampleRate)
    {
        sampleRate = newSampleRate;
        updateLowShelf();
        reset();
    }

    void reset()
    {
        lowShelf.reset();
        filter.reset();
    }

    /// Tone is a low-pass corner, not a shelf: turning it down is the
    /// "Tone-Poti zurückgedreht" move, not a gentle de-esser.
    void setToneHz(float hz)
    {
        filter.setFromArray(Biquad::makeLowPass(sampleRate, hz, 0.707f));
    }

    void setDrive(float amount01) { drive = amount01; }

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

        // Gain tops out well below a fuzz: the knob's whole range stays in
        // clean-to-edge-of-breakup territory.
        const float k = 1.0f + drive * 11.0f;

        // The bias grows with drive. A fixed bias would be swamped as the
        // tanh saturates — a fully clipped wave is symmetric no matter what
        // you offset it by — so the even harmonics would fade out exactly as
        // the stage starts to break up, which is backwards. Letting it track
        // drive is also what the tube does: grid conduction shifts the
        // operating point as the stage is pushed. Measured over the knob's
        // range this puts second harmonic at 2.5% of the fundamental at the
        // bottom and 11% at the top, always well under the odd content.
        const float bias = biasTracking * drive;
        const float offset = std::tanh(bias);
        const float clipped = std::tanh(filtered * k + bias) - offset;

        // Normalise by the true maximum excursion. It has to be the larger
        // half — the offset pushes one side out to 1 + offset while the other
        // only reaches 1 - offset — or the loud half clips past unity and the
        // stage turns into an 11 dB boost.
        return clipped / (1.0f + offset);
    }

private:
    void updateLowShelf()
    {
        static constexpr float bodyHz = 150.0f;
        static constexpr float maxBoostDb = 6.0f;
        const float linearGain = std::pow(10.0f, (bodyAmount * maxBoostDb) / 20.0f);
        lowShelf.setFromArray(Biquad::makeLowShelf(sampleRate, bodyHz, 0.707f, linearGain));
    }

    static constexpr float biasTracking = 0.7f;

    double sampleRate = 44100.0;
    Biquad lowShelf;
    Biquad filter;
    float drive = 0.0f;
    float bodyAmount = 0.0f;
};
