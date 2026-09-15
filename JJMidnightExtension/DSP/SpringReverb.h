#pragma once

#include "DSPCommon.h"
#include "Biquad.hpp"

#include <array>
#include <vector>

/** Fixed-length delay line with allpass feedback. The building block for
    both halves of the spring below. */
class AllpassDelay
{
public:
    void prepare(double sampleRate, float delayMs, float gainIn)
    {
        length = std::max(1, (int) std::round(delayMs * 0.001 * sampleRate));
        buffer.assign((size_t) length, 0.0f);
        writePos = 0;
        gain = gainIn;
    }

    void reset()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        writePos = 0;
    }

    float processSample(float x) noexcept
    {
        const float delayed = buffer[(size_t) writePos];
        const float v = x + gain * delayed;
        buffer[(size_t) writePos] = v;
        writePos = (writePos + 1) % length;
        return delayed - gain * v;
    }

private:
    std::vector<float> buffer;
    int length = 1;
    int writePos = 0;
    float gain = 0.5f;
};

/** Feedback comb with a one-pole lowpass in the loop, so each pass through
    the tank loses a little top end. */
class DampedComb
{
public:
    void prepare(double sampleRate, float delayMs)
    {
        length = std::max(1, (int) std::round(delayMs * 0.001 * sampleRate));
        buffer.assign((size_t) length, 0.0f);
        writePos = 0;
        store = 0.0f;
    }

    void reset()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        writePos = 0;
        store = 0.0f;
    }

    void setFeedback(float f) { feedback = std::clamp(f, 0.0f, 0.98f); }
    void setDamping(float d) { damping = std::clamp(d, 0.0f, 0.95f); }

    float processSample(float x) noexcept
    {
        const float y = buffer[(size_t) writePos];
        store = y + damping * (store - y);
        buffer[(size_t) writePos] = x + store * feedback;
        writePos = (writePos + 1) % length;
        return y;
    }

private:
    std::vector<float> buffer;
    int length = 1;
    int writePos = 0;
    float feedback = 0.7f;
    float damping = 0.4f;
    float store = 0.0f;
};

/**
    A spring tank, per channel.

    Two things separate a spring from a plate or a room, and both are here:

    1. **Dispersion.** A real spring is a mechanical transmission line, and
       high frequencies travel along it faster than low ones. Hit it and the
       reflection arrives smeared into the characteristic descending chirp —
       the "boing". That is what the allpass chain in front of the tank does:
       a cascade of short allpasses is a frequency-dependent delay, which is
       exactly the physics. A real tank behaves like a hundred-odd stages;
       eight gets the character at a fraction of the cost, and the ear reads
       the chirp long before it counts the stages.

    2. **Bandwidth.** A spring is a narrow, resonant thing. It has almost no
       bass and very little above a few kHz. The bandpass in front matters
       more to "sounds like a spring" than the tank itself does — reverb with
       full-range input just sounds like a cheap plate.

    The tank behind it is a plain Schroeder: three combs in parallel into two
    allpasses in series. The delay times are mutually prime-ish so the modes
    do not stack into a ringing pitch.
*/
class SpringReverb
{
public:
    void prepare(double newSampleRate)
    {
        sampleRate = newSampleRate;

        // Dispersion chain. Short, slightly irregular delays: equal spacing
        // would put a comb pattern on top of the chirp.
        static constexpr std::array<float, dispersionStages> dispersionMs
            { 0.62f, 0.87f, 1.13f, 1.41f, 1.72f, 2.06f, 2.43f, 2.84f };
        for (size_t i = 0; i < dispersionStages; ++i)
            dispersion[i].prepare(sampleRate, dispersionMs[i], 0.62f);

        static constexpr std::array<float, combCount> combMs { 29.7f, 37.1f, 41.1f };
        for (size_t i = 0; i < combCount; ++i)
            combs[i].prepare(sampleRate, combMs[i]);

        tankAllpass[0].prepare(sampleRate, 5.0f, 0.5f);
        tankAllpass[1].prepare(sampleRate, 1.7f, 0.5f);

        inputHighPass.setFromArray(Biquad::makeHighPass(sampleRate, 170.0f, 0.707f));
        inputLowPass.setFromArray(Biquad::makeLowPass(sampleRate, 4200.0f, 0.707f));
        outputLowPass.setFromArray(Biquad::makeLowPass(sampleRate, 5500.0f, 0.707f));

        setDecay(0.5f);
        reset();
    }

    void reset()
    {
        for (auto& stage : dispersion) stage.reset();
        for (auto& comb : combs) comb.reset();
        for (auto& ap : tankAllpass) ap.reset();
        inputHighPass.reset();
        inputLowPass.reset();
        outputLowPass.reset();
    }

    /// 0 = short splash, 1 = long tank. Drives comb feedback and damping
    /// together, because on a real tank they are not separable either.
    void setDecay(float amount01)
    {
        const float d = std::clamp(amount01, 0.0f, 1.0f);
        const float feedback = 0.66f + d * 0.26f;
        const float damping = 0.52f - d * 0.20f;
        for (auto& comb : combs)
        {
            comb.setFeedback(feedback);
            comb.setDamping(damping);
        }
    }

    /// Returns the wet signal only; the caller does the dry/wet blend.
    float processSample(float x) noexcept
    {
        float v = inputLowPass.processSample(inputHighPass.processSample(x));

        for (auto& stage : dispersion)
            v = stage.processSample(v);

        float tank = 0.0f;
        for (auto& comb : combs)
            tank += comb.processSample(v);
        tank *= 1.0f / (float) combCount;

        for (auto& ap : tankAllpass)
            tank = ap.processSample(tank);

        return outputLowPass.processSample(tank);
    }

private:
    static constexpr size_t dispersionStages = 8;
    static constexpr size_t combCount = 3;

    double sampleRate = 44100.0;
    std::array<AllpassDelay, dispersionStages> dispersion;
    std::array<DampedComb, combCount> combs;
    std::array<AllpassDelay, 2> tankAllpass;
    Biquad inputHighPass, inputLowPass, outputLowPass;
};
