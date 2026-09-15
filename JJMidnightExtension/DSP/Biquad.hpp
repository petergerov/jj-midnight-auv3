#pragma once

#include "DSPCommon.h"
#include <array>

/// Transposed Direct Form II biquad matching juce::dsp::IIR::Filter (JUCE 9.0.1).
/// Coefficients are stored as {b0, b1, b2, a1, a2} after a0-normalisation.
class Biquad
{
public:
    void reset() noexcept
    {
        v1 = 0.0f;
        v2 = 0.0f;
    }

    void setCoefficients(float b0In, float b1In, float b2In, float a0In, float a1In, float a2In) noexcept
    {
        const float invA0 = (a0In != 0.0f) ? 1.0f / a0In : 0.0f;
        b0 = b0In * invA0;
        b1 = b1In * invA0;
        b2 = b2In * invA0;
        a1 = a1In * invA0;
        a2 = a2In * invA0;
    }

    float processSample(float x) noexcept
    {
        const float y = b0 * x + v1;
        v1 = b1 * x - a1 * y + v2;
        v2 = b2 * x - a2 * y;
        return y;
    }

    /// JUCE 9 ArrayCoefficients::makeLowPass (default Q = 1/sqrt(2)).
    static std::array<float, 6> makeLowPass(double sampleRate, float frequency, float Q = 0.7071067811865475f)
    {
        frequency = std::clamp(frequency, 1.0f, (float) (sampleRate * 0.49));
        const float n = 1.0f / std::tan((float) (M_PI * frequency / sampleRate));
        const float nSquared = n * n;
        const float invQ = 1.0f / Q;
        const float c1 = 1.0f / (1.0f + invQ * n + nSquared);
        return { c1, c1 * 2.0f, c1, 1.0f, c1 * 2.0f * (1.0f - nSquared), c1 * (1.0f - invQ * n + nSquared) };
    }

    /// JUCE 9 ArrayCoefficients::makeHighPass (default Q = 1/sqrt(2)).
    static std::array<float, 6> makeHighPass(double sampleRate, float frequency, float Q = 0.7071067811865475f)
    {
        frequency = std::clamp(frequency, 1.0f, (float) (sampleRate * 0.49));
        const float n = std::tan((float) (M_PI * frequency / sampleRate));
        const float nSquared = n * n;
        const float invQ = 1.0f / Q;
        const float c1 = 1.0f / (1.0f + invQ * n + nSquared);
        return { c1, c1 * -2.0f, c1, 1.0f, c1 * 2.0f * (nSquared - 1.0f), c1 * (1.0f - invQ * n + nSquared) };
    }

    /// JUCE 9 ArrayCoefficients::makeLowShelf. gainFactor is linear (not dB).
    static std::array<float, 6> makeLowShelf(double sampleRate, float cutOffFrequency, float Q, float gainFactor)
    {
        cutOffFrequency = std::max(cutOffFrequency, 2.0f);
        const float A = std::sqrt(std::max(gainFactor, 1.0e-15f));
        const float aminus1 = A - 1.0f;
        const float aplus1 = A + 1.0f;
        const float omega = (float) (2.0 * M_PI * cutOffFrequency / sampleRate);
        const float coso = std::cos(omega);
        const float beta = std::sin(omega) * std::sqrt(A) / Q;
        const float aminus1TimesCoso = aminus1 * coso;
        return {
            A * (aplus1 - aminus1TimesCoso + beta),
            A * 2.0f * (aminus1 - aplus1 * coso),
            A * (aplus1 - aminus1TimesCoso - beta),
            aplus1 + aminus1TimesCoso + beta,
            -2.0f * (aminus1 + aplus1 * coso),
            aplus1 + aminus1TimesCoso - beta
        };
    }

    /// JUCE 9 ArrayCoefficients::makePeakFilter. gainFactor is linear (not dB);
    /// below 1.0 it cuts, which is how the cab voicing gets its 3.6 kHz dip.
    static std::array<float, 6> makePeakFilter(double sampleRate, float frequency, float Q, float gainFactor)
    {
        frequency = std::clamp(frequency, 1.0f, (float) (sampleRate * 0.49));
        const float A = std::sqrt(std::max(gainFactor, 1.0e-15f));
        const float omega = (float) (2.0 * M_PI * frequency / sampleRate);
        const float alpha = std::sin(omega) / (2.0f * Q);
        const float c2 = -2.0f * std::cos(omega);
        const float alphaTimesA = alpha * A;
        const float alphaOverA = alpha / A;
        return { 1.0f + alphaTimesA, c2, 1.0f - alphaTimesA,
                 1.0f + alphaOverA,  c2, 1.0f - alphaOverA };
    }

    void setFromArray(const std::array<float, 6>& c) noexcept
    {
        setCoefficients(c[0], c[1], c[2], c[3], c[4], c[5]);
    }

private:
    float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f, a1 = 0.0f, a2 = 0.0f;
    float v1 = 0.0f, v2 = 0.0f;
};
