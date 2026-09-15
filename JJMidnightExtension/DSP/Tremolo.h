#pragma once

#include "DSPCommon.h"

/**
    Amplitude tremolo — one LFO shared by both channels, the way an amp's
    tremolo circuit works. (A stereo-offset tremolo is a studio effect, not
    an amp, and it would put the guitar in two places at once.)

    `shape` morphs the LFO from a sine towards a softened square. Those are
    the two tremolo circuits worth having: blackface amps modulate the
    bias and give a rounded sine-ish sway, brownface/optical circuits chop
    harder and land closer to a square. Everything in between is useful, so
    it is a knob rather than a switch.

    The waveform is squared off by running the sine through a tanh and
    renormalising, so the corners stay band-limited and the modulation never
    clicks — which a real square LFO would.
*/
class Tremolo
{
public:
    void prepare(double newSampleRate)
    {
        sampleRate = newSampleRate;
        reset();
    }

    void reset()
    {
        phase = 0.0f;
        smoothedGain = 1.0f;
    }

    void setRateHz(float hz) { rateHz = std::clamp(hz, 0.05f, 20.0f); }
    void setDepth(float amount01) { depth = std::clamp(amount01, 0.0f, 1.0f); }
    void setShape(float amount01) { shape = std::clamp(amount01, 0.0f, 1.0f); }

    /// Advances the LFO one sample and returns the gain both channels get.
    float nextGain() noexcept
    {
        const float sine = std::sin(phase);

        phase += (float) (2.0 * M_PI * rateHz / sampleRate);
        if (phase > (float) (2.0 * M_PI))
            phase -= (float) (2.0 * M_PI);

        float wave = sine;
        if (shape > 1.0e-4f)
        {
            const float k = 1.0f + shape * 7.0f;
            const float squared = std::tanh(sine * k) / std::tanh(k);
            wave = sine + shape * (squared - sine);
        }

        // Map [-1, 1] to a gain that peaks at unity and dips by `depth`, so
        // turning depth up never makes the track louder.
        const float target = 1.0f - depth * (0.5f - 0.5f * wave);

        // A short smoother on the final gain: cheap insurance against a
        // click if rate, depth or shape is moved while audio is running.
        smoothedGain += smoothing * (target - smoothedGain);
        return smoothedGain;
    }

private:
    double sampleRate = 44100.0;
    float rateHz = 4.5f;
    float depth = 0.0f;
    float shape = 0.0f;
    float phase = 0.0f;
    float smoothedGain = 1.0f;
    static constexpr float smoothing = 0.02f;
};
