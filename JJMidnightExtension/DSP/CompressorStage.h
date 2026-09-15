#pragma once

#include "DSPCommon.h"

/**
    A feed-forward compressor with optical-cell ballistics — the first thing
    in the chain and the reason everything downstream sits back in the track.

    What makes this "optical" rather than a generic VCA compressor is the
    release. In a real opto cell the photoresistor's recovery is not a fixed
    time constant: it snaps back quickly from a light squeeze and crawls back
    from a heavy one. So the release coefficient here is recomputed every
    sample from how much gain reduction is currently applied. A 1 dB dip
    recovers in about 80 ms; a 10 dB grab takes well over a second. That
    program dependence is audible as "the compressor is never caught working"
    — transients get rounded, but the tail of a note never pumps back up.

    The knee is soft and the ratio is deliberately gentle. Optical cells have
    no sharp threshold; they just start to lean on the signal.

    Detector is stereo-linked: the caller passes max(|L|, |R|) and applies the
    one returned gain to both channels, so the image never wanders when one
    side is louder.
*/
class CompressorStage
{
public:
    void prepare(double newSampleRate)
    {
        sampleRate = newSampleRate;
        // Instant rise, 2 ms fall: enough to stop the rectifier chattering
        // without putting any audible time constant of its own in the path.
        detectorAttack = 0.0f;
        detectorRelease = coefficientFor(2.0f);
        reset();
    }

    void reset()
    {
        envelope = 0.0f;
        gainReductionDb = 0.0f;
    }

    void setThresholdDb(float db) { thresholdDb = db; }
    void setRatio(float r) { ratio = std::max(1.0f, r); }
    void setMakeupDb(float db) { makeupLinear = std::pow(10.0f, db / 20.0f); }

    /// Attack in ms. Soft by design — the range the UI offers starts where a
    /// mastering compressor's would already be over.
    void setAttackMs(float ms)
    {
        attackCoeff = coefficientFor(std::max(1.0f, ms));
    }

    /// Sets the two ends of the program-dependent release. `ms` is the fast
    /// end (light gain reduction); the slow end is derived from it, because
    /// on a real cell the two are not independently adjustable.
    void setReleaseMs(float ms)
    {
        fastReleaseCoeff = coefficientFor(std::max(10.0f, ms));
        slowReleaseCoeff = coefficientFor(std::max(10.0f, ms) * slowReleaseFactor);
    }

    /// How far into the gain reduction range the release has fully slowed
    /// down, in dB. Below this it interpolates between fast and slow.
    static constexpr float programDepthDb = 9.0f;

    /// Current gain reduction in dB, for the UI's GR meter. Positive = ducking.
    float currentGainReductionDb() const { return gainReductionDb; }

    /** Returns the linear gain to apply to both channels this sample.
        `detectorInput` should be max(|left|, |right|). */
    float nextGain(float detectorInput) noexcept
    {
        // Rectified peak feeding a one-pole smoother. The smoothing here is
        // only to keep the detector from chattering on individual samples;
        // the musical ballistics live in the gain-reduction smoothing below.
        const float rectified = std::abs(detectorInput);
        envelope = rectified > envelope
            ? rectified + detectorAttack * (envelope - rectified)
            : rectified + detectorRelease * (envelope - rectified);

        const float levelDb = 20.0f * std::log10(std::max(envelope, 1.0e-6f));
        const float overDb = levelDb - thresholdDb;

        // Soft knee: quadratic blend across `kneeDb`, so the onset of
        // compression has no corner in it.
        float targetGrDb;
        if (overDb <= -halfKnee)
        {
            targetGrDb = 0.0f;
        }
        else if (overDb >= halfKnee)
        {
            targetGrDb = overDb * (1.0f - 1.0f / ratio);
        }
        else
        {
            const float t = overDb + halfKnee;
            targetGrDb = (1.0f - 1.0f / ratio) * (t * t) / (2.0f * kneeDb);
        }

        // The optical part. Going down (more reduction) uses the attack
        // coefficient. Coming back up, the coefficient is interpolated
        // between fast and slow by how deep the current reduction is.
        float coeff;
        if (targetGrDb > gainReductionDb)
        {
            coeff = attackCoeff;
        }
        else
        {
            const float depth = std::clamp(gainReductionDb / programDepthDb, 0.0f, 1.0f);
            coeff = fastReleaseCoeff + depth * (slowReleaseCoeff - fastReleaseCoeff);
        }

        gainReductionDb = targetGrDb + coeff * (gainReductionDb - targetGrDb);

        return std::pow(10.0f, -gainReductionDb / 20.0f) * makeupLinear;
    }

private:
    /// One-pole coefficient for a time constant in milliseconds.
    float coefficientFor(float ms) const
    {
        return std::exp(-1.0f / (float) (0.001 * ms * sampleRate));
    }

    static constexpr float kneeDb = 9.0f;
    static constexpr float halfKnee = kneeDb * 0.5f;
    /// The slow end of the release is this much longer than the fast end.
    static constexpr float slowReleaseFactor = 14.0f;

    double sampleRate = 44100.0;

    float thresholdDb = -18.0f;
    float ratio = 3.0f;
    float makeupLinear = 1.0f;

    float attackCoeff = 0.999f;
    float fastReleaseCoeff = 0.9999f;
    float slowReleaseCoeff = 0.99999f;

    // Fixed, fast detector smoothing — not a user control.
    float detectorAttack = 0.0f;
    float detectorRelease = 0.9995f;

    float envelope = 0.0f;
    float gainReductionDb = 0.0f;
};
