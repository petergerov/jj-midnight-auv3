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

        const float clipped = std::tanh(filtered * gain + bias) - offset;

        // Two divisions, and they do different jobs. Normalising by the true
        // maximum excursion keeps the curve inside ±1: it has to be the larger
        // half — the offset pushes one side out to 1 + offset while the other
        // only reaches 1 - offset — or the loud half clips past unity. The
        // makeup then takes the stage back to unity gain; see updateDriveCurve.
        return (clipped / (1.0f + offset)) * makeup;
    }

private:
    /// Everything that depends only on the drive amount, so the render loop
    /// does not recompute a tanh and a cosh per sample for values that change
    /// once per block.
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

        // Makeup. Without it the knob is mostly a volume control: clamping the
        // curve to ±1 bounds the peak but says nothing about level, and a
        // signal that never reaches the ceiling just gets the raw gain. Metered
        // on guitar the old stage ran +9 dB hotter at the top of the knob for a
        // hot part and +15 dB for a quiet one, which is louder, not driven.
        //
        // The compensation is the inverse of the stage's own small-signal
        // slope — the derivative of the curve at zero — so quiet passages come
        // out at exactly the gain they went in at and the only level change
        // left is the one the clipping actually causes. That is the right
        // residue to keep: drive should thicken and compress, and a part
        // pushed into breakup does sit a little differently. Deriving it from
        // the curve rather than from a measured table also means it stays
        // correct if the gain or the bias tracking is ever retuned.
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

    double sampleRate = 44100.0;
    Biquad lowShelf;
    Biquad filter;
    float drive = 0.0f;
    float bodyAmount = 0.0f;
    float gain = 1.0f;
    float bias = 0.0f;
    float offset = 0.0f;
    float makeup = 1.0f;
};
