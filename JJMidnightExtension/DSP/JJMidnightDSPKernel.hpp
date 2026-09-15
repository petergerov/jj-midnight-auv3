#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <algorithm>
#include <cmath>
#include <span>
#include <vector>

#include "JJMidnightParameterAddresses.h"
#include "CompressorStage.h"
#include "DriveStage.h"
#include "CabVoicing.h"
#include "Tremolo.h"
#include "ModulatedDelay.h"
#include "SpringReverb.h"
#include "Biquad.hpp"

/**
    The chain, in order:

        Comp → Drive → Cab → Wobble → Slapback + Spring → Mix → Output

    Two things are shared rather than per-channel, on purpose. The compressor
    runs one stereo-linked detector, so a loud left channel does not pull the
    image sideways. The tremolo runs one LFO for both channels, because an
    amp's tremolo circuit modulates the whole output stage — offsetting the
    two sides would put the guitar in two places at once.

    Everything else is a pair.
*/
class JJMidnightDSPKernel
{
public:
    void initialize(int inputChannelCount, int outputChannelCount, double inSampleRate)
    {
        mSampleRate = inSampleRate;
        mInputChannelCount = inputChannelCount;
        mOutputChannelCount = outputChannelCount;

        compressor.prepare(inSampleRate);
        tremolo.prepare(inSampleRate);

        driveL.prepare(inSampleRate);
        driveR.prepare(inSampleRate);
        cabL.prepare(inSampleRate);
        cabR.prepare(inSampleRate);
        springL.prepare(inSampleRate);
        springR.prepare(inSampleRate);

        slapL.prepare(inSampleRate);
        slapR.prepare(inSampleRate);
        // A hair of wobble on the repeat, and the two sides out of phase with
        // each other: that is tape flutter, and it keeps a single dry repeat
        // from sounding like a digital copy pasted behind the note.
        slapL.lfoRateHz = 0.27f;
        slapR.lfoRateHz = 0.31f;
        slapL.lfoDepthMs = 0.35f;
        slapR.lfoDepthMs = 0.35f;
        slapL.setLfoStartPhase(0.0f);
        slapR.setLfoStartPhase(0.5f);

        mInitialized = true;
    }

    void deInitialize()
    {
        compressor.reset();
        tremolo.reset();
        driveL.reset();
        driveR.reset();
        cabL.reset();
        cabR.reset();
        slapL.reset();
        slapR.reset();
        springL.reset();
        springR.reset();
        mInitialized = false;
    }

    bool isBypassed() const { return mBypassed; }
    void setBypass(bool shouldBypass) { mBypassed = shouldBypass; }

    bool isLicensed() const { return mLicensed; }
    void setLicensed(bool licensed) { mLicensed = licensed; }

    void setParameter(AUParameterAddress address, AUValue value)
    {
        switch (address)
        {
            case JJMidnightParameterAddress::compAmount:   mCompAmount = value; break;
            case JJMidnightParameterAddress::compAttack:   mCompAttack = value; break;
            case JJMidnightParameterAddress::compRelease:  mCompRelease = value; break;
            case JJMidnightParameterAddress::compOn:       mCompOn = value; break;
            case JJMidnightParameterAddress::driveAmount:  mDriveAmount = value; break;
            case JJMidnightParameterAddress::driveTone:    mDriveTone = value; break;
            case JJMidnightParameterAddress::driveCab:     mDriveCab = value; break;
            case JJMidnightParameterAddress::driveOn:      mDriveOn = value; break;
            case JJMidnightParameterAddress::wobbleRate:   mWobbleRate = value; break;
            case JJMidnightParameterAddress::wobbleDepth:  mWobbleDepth = value; break;
            case JJMidnightParameterAddress::wobbleShape:  mWobbleShape = value; break;
            case JJMidnightParameterAddress::wobbleOn:     mWobbleOn = value; break;
            case JJMidnightParameterAddress::wobbleSync:   mWobbleSync = value; break;
            case JJMidnightParameterAddress::wobbleDivision: mWobbleDivision = value; break;
            case JJMidnightParameterAddress::slapTime:     mSlapTime = std::clamp(value, 0.0f, 250.0f); break;
            case JJMidnightParameterAddress::slapMix:      mSlapMix = value; break;
            case JJMidnightParameterAddress::springMix:    mSpringMix = value; break;
            case JJMidnightParameterAddress::spaceOn:      mSpaceOn = value; break;
            case JJMidnightParameterAddress::masterMix:    mMasterMix = value; break;
            case JJMidnightParameterAddress::masterOutput: mMasterOutput = value; break;
            default: break;
        }
    }

    AUValue getParameter(AUParameterAddress address)
    {
        switch (address)
        {
            case JJMidnightParameterAddress::compAmount:   return mCompAmount;
            case JJMidnightParameterAddress::compAttack:   return mCompAttack;
            case JJMidnightParameterAddress::compRelease:  return mCompRelease;
            case JJMidnightParameterAddress::compOn:       return mCompOn;
            case JJMidnightParameterAddress::driveAmount:  return mDriveAmount;
            case JJMidnightParameterAddress::driveTone:    return mDriveTone;
            case JJMidnightParameterAddress::driveCab:     return mDriveCab;
            case JJMidnightParameterAddress::driveOn:      return mDriveOn;
            case JJMidnightParameterAddress::wobbleRate:   return mWobbleRate;
            case JJMidnightParameterAddress::wobbleDepth:  return mWobbleDepth;
            case JJMidnightParameterAddress::wobbleShape:  return mWobbleShape;
            case JJMidnightParameterAddress::wobbleOn:     return mWobbleOn;
            case JJMidnightParameterAddress::wobbleSync:   return mWobbleSync;
            case JJMidnightParameterAddress::wobbleDivision: return mWobbleDivision;
            case JJMidnightParameterAddress::slapTime:     return mSlapTime;
            case JJMidnightParameterAddress::slapMix:      return mSlapMix;
            case JJMidnightParameterAddress::springMix:    return mSpringMix;
            case JJMidnightParameterAddress::spaceOn:      return mSpaceOn;
            case JJMidnightParameterAddress::masterMix:    return mMasterMix;
            case JJMidnightParameterAddress::masterOutput: return mMasterOutput;
            default: return 0.f;
        }
    }

    AUAudioFrameCount maximumFramesToRender() const { return mMaxFramesToRender; }
    void setMaximumFramesToRender(const AUAudioFrameCount& maxFrames) { mMaxFramesToRender = maxFrames; }

    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock)
    {
        mMusicalContextBlock = contextBlock;
    }

    void process(std::span<float const*> inputBuffers,
                 std::span<float*> outputBuffers,
                 AUEventSampleTime,
                 AUAudioFrameCount frameCount)
    {
        if (! mInitialized || inputBuffers.empty() || outputBuffers.empty())
            return;

        if (mBypassed || ! mLicensed)
        {
            float peak = 0.f;
            float channelPeak[2] = { 0.f, 0.f };
            for (size_t channel = 0; channel < outputBuffers.size(); ++channel)
            {
                const float* src = inputBuffers[std::min(channel, inputBuffers.size() - 1)];
                std::copy_n(src, frameCount, outputBuffers[channel]);
                float thisChannel = 0.f;
                for (AUAudioFrameCount n = 0; n < frameCount; ++n)
                    thisChannel = std::max(thisChannel, std::abs(src[n]));
                peak = std::max(peak, thisChannel);
                if (channel < 2)
                    channelPeak[channel] = thisChannel;
            }
            if (outputBuffers.size() == 1)
                channelPeak[1] = channelPeak[0];
            capturePeaks(peak, channelPeak[0], channelPeak[1]);
            mGainReductionDb = 0.f;
            return;
        }

        FlushDenormals denormals;

        const bool compIsOn   = mCompOn > 0.5f;
        const bool driveIsOn  = mDriveOn > 0.5f;
        const bool wobbleIsOn = mWobbleOn > 0.5f;
        const bool spaceIsOn  = mSpaceOn > 0.5f;

        // COMP. One knob moves threshold, ratio and makeup together, because
        // an optical cell sets its own ratio and has a single control — the
        // LA-2A's is marked 0-10 with no unit. Separating them here would let
        // the user build settings no such box can produce, which would defeat
        // the point of modelling one; marking the knob in dB would show the
        // threshold moving and hide the other two. The dB readout the user
        // wants is the GR meter. The mapping:
        //
        //     Comp     0%        55%       100%
        //     thresh  -2.0 dB   -17.4 dB  -30.0 dB
        //     ratio    2.00:1     3.38:1    4.50:1
        //     makeup   0 dB      +4.4 dB   +13.2 dB
        const float compAmt = std::clamp(mCompAmount * 0.01f, 0.0f, 1.0f);
        const float thresholdDb = -2.0f - compAmt * 28.0f;
        const float ratio = 2.0f + compAmt * 2.5f;
        // Give back roughly what the threshold takes away at a nominal -10 dBFS
        // source, so turning Comp up does not also turn the track down.
        const float makeupDb = std::max(0.0f, (-10.0f - thresholdDb)) * (1.0f - 1.0f / ratio) * 0.85f;
        compressor.setThresholdDb(thresholdDb);
        compressor.setRatio(ratio);
        compressor.setMakeupDb(makeupDb);
        compressor.setAttackMs(mCompAttack);
        compressor.setReleaseMs(mCompRelease);

        // DRIVE. Body tracks drive rather than being its own control: on a
        // real amp, pushing the front end always thickens the bottom, and an
        // independent body knob just invites settings that sound like a
        // console EQ rather than an amp.
        const float driveAmt = std::clamp(mDriveAmount * 0.01f, 0.0f, 1.0f);
        driveL.setDrive(driveAmt);
        driveR.setDrive(driveAmt);
        driveL.setBodyAmount(driveAmt * 0.3f);
        driveR.setBodyAmount(driveAmt * 0.3f);
        driveL.setToneHz(mDriveTone);
        driveR.setToneHz(mDriveTone);

        const float cabPosition = std::clamp(mDriveCab * 0.01f, 0.0f, 1.0f);
        cabL.setOffAxis(cabPosition);
        cabR.setOffAxis(cabPosition);

        // WOBBLE.
        tremolo.setRateHz(wobbleRateHz());
        tremolo.setDepth(wobbleIsOn ? std::clamp(mWobbleDepth * 0.01f, 0.0f, 1.0f) : 0.0f);
        tremolo.setShape(std::clamp(mWobbleShape * 0.01f, 0.0f, 1.0f));

        // SPACE. One repeat, no feedback — the delay line is a single tap.
        slapL.setBaseDelayMs(mSlapTime);
        slapR.setBaseDelayMs(mSlapTime * 1.04f); // barely wider than mono
        const float slapAmt = spaceIsOn ? std::clamp(mSlapMix * 0.01f, 0.0f, 1.0f) : 0.0f;
        const float springAmt = spaceIsOn ? std::clamp(mSpringMix * 0.01f, 0.0f, 1.0f) : 0.0f;
        // A real amp's reverb control is a mix knob and the tank decay is
        // fixed, so decay follows the mix instead of being exposed.
        springL.setDecay(0.30f + springAmt * 0.45f);
        springR.setDecay(0.30f + springAmt * 0.45f);

        const float masterMix = std::clamp(mMasterMix * 0.01f, 0.0f, 1.0f);
        const float outputGain = std::pow(10.0f, mMasterOutput / 20.0f);

        const float* inL = inputBuffers[0];
        const float* inR = inputBuffers.size() > 1 ? inputBuffers[1] : inputBuffers[0];
        float* outLPtr = outputBuffers[0];
        float* outRPtr = outputBuffers.size() > 1 ? outputBuffers[1] : outputBuffers[0];

        float peakIn = 0.f;
        float peakOutL = 0.f;
        float peakOutR = 0.f;

        for (AUAudioFrameCount n = 0; n < frameCount; ++n)
        {
            const float dryL = inL[n];
            const float dryR = inR[n];

            // --- Comp (stereo-linked detector) ---
            float wetL = dryL;
            float wetR = dryR;
            if (compIsOn)
            {
                const float detector = std::max(std::abs(dryL), std::abs(dryR));
                const float gain = compressor.nextGain(detector);
                wetL *= gain;
                wetR *= gain;
            }

            // --- Drive + cab ---
            if (driveIsOn)
            {
                wetL = cabL.processSample(driveL.processSample(wetL));
                wetR = cabR.processSample(driveR.processSample(wetR));
            }

            // --- Wobble (one LFO, both channels) ---
            {
                const float trem = tremolo.nextGain();
                wetL *= trem;
                wetR *= trem;
            }

            // --- Space: slapback then spring, both fed from the dry-of-here
            // signal so the repeat is not itself reverberated into mush ---
            const float slapWetL = slapL.processSample(wetL);
            const float slapWetR = slapR.processSample(wetR);
            const float withSlapL = wetL + slapAmt * slapWetL;
            const float withSlapR = wetR + slapAmt * slapWetR;

            const float springWetL = springL.processSample(withSlapL);
            const float springWetR = springR.processSample(withSlapR);
            wetL = withSlapL + springAmt * springWetL;
            wetR = withSlapR + springAmt * springWetR;

            // --- Master ---
            const float outL = (dryL + masterMix * (wetL - dryL)) * outputGain;
            const float outR = (dryR + masterMix * (wetR - dryR)) * outputGain;
            outLPtr[n] = outL;
            outRPtr[n] = outR;

            peakIn = std::max(peakIn, std::max(std::abs(dryL), std::abs(dryR)));
            peakOutL = std::max(peakOutL, std::abs(outL));
            peakOutR = std::max(peakOutR, std::abs(outR));
        }

        mGainReductionDb = compIsOn ? compressor.currentGainReductionDb() : 0.f;
        capturePeaks(peakIn, peakOutL, peakOutR);
    }

    /// Left and right output peaks since the last read, then reset. Separate
    /// from readPeaks so the header ladders and the master bars can each
    /// consume at their own rate without starving the other.
    void readOutputPeaks(float* leftPeak, float* rightPeak)
    {
        if (leftPeak)
        {
            *leftPeak = mPeakOutL;
            mPeakOutL = 0.f;
        }
        if (rightPeak)
        {
            *rightPeak = mPeakOutR;
            mPeakOutR = 0.f;
        }
    }

    void readPeaks(float* inPeak, float* outPeak)
    {
        if (inPeak)
        {
            *inPeak = mPeakIn;
            mPeakIn = 0.f;
        }
        if (outPeak)
        {
            *outPeak = mPeakOut;
            mPeakOut = 0.f;
        }
    }

    /// Current gain reduction in dB for the UI's GR lamp. Not reset on read:
    /// it is a level, not a peak-hold.
    float gainReductionDb() const { return mGainReductionDb; }

    /// Cycles per beat for each note division, slowest first. Index order must
    /// match JJMidnightWobbleDivisions.names in Parameters.swift; the shared
    /// JJMidnightWobbleDivisionCount keeps the lengths in step.
    ///
    /// A dotted eighth lasts 1.5 eighths, so its *rate* is 2 / 1.5 = 4/3 —
    /// dotted values slow down where triplets speed up.
    static constexpr float kWobbleCyclesPerBeat[JJMidnightWobbleDivisionCount] = {
        0.5f,        // 1/2
        1.0f,        // 1/4
        4.0f / 3.0f, // 1/8.
        1.5f,        // 1/4T
        2.0f,        // 1/8
        3.0f,        // 1/8T
        4.0f         // 1/16
    };

    /// The tremolo rate to actually use: the host's tempo times the selected
    /// division when Sync is on, otherwise the Rate knob.
    ///
    /// Falls back to the knob whenever the host cannot supply a tempo — the
    /// companion app has no transport at all, and some hosts return false.
    /// Freezing or going silent there would be much worse than simply not
    /// being in sync.
    float wobbleRateHz()
    {
        if (mWobbleSync <= 0.5f || mMusicalContextBlock == nullptr)
            return mWobbleRate;

        double tempo = 0.0;
        // Safe to call from the render thread: that is what this block is for.
        // Queried once per process() call, never per sample.
        if (! mMusicalContextBlock(&tempo, nullptr, nullptr, nullptr, nullptr, nullptr))
            return mWobbleRate;
        if (! (tempo > 0.0))
            return mWobbleRate;

        const int index = std::clamp((int) std::lround(mWobbleDivision),
                                     0, JJMidnightWobbleDivisionCount - 1);
        return (float) (tempo / 60.0) * kWobbleCyclesPerBeat[index];
    }

    void handleOneEvent(AUEventSampleTime now, AURenderEvent const* event)
    {
        switch (event->head.eventType)
        {
            case AURenderEventParameter:
                handleParameterEvent(now, event->parameter);
                break;
            default:
                break;
        }
    }

    void handleParameterEvent(AUEventSampleTime, AUParameterEvent const& parameterEvent)
    {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }

private:
    CompressorStage compressor;   // stereo-linked
    Tremolo tremolo;              // one LFO for both channels
    DriveStage driveL, driveR;
    CabVoicing cabL, cabR;
    ModulatedDelay slapL, slapR;
    SpringReverb springL, springR;

    AUHostMusicalContextBlock mMusicalContextBlock;

    double mSampleRate = 44100.0;
    int mInputChannelCount = 2;
    int mOutputChannelCount = 2;
    bool mBypassed = false;
    bool mLicensed = false;
    bool mInitialized = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;

    float mCompAmount = 55.0f;
    float mCompAttack = 28.0f;
    float mCompRelease = 140.0f;
    float mCompOn = 1.0f;

    float mDriveAmount = 30.0f;
    float mDriveTone = 3000.0f;
    float mDriveCab = 50.0f;
    float mDriveOn = 1.0f;

    float mWobbleRate = 4.6f;
    float mWobbleDepth = 32.0f;
    float mWobbleShape = 20.0f;
    float mWobbleOn = 1.0f;
    float mWobbleSync = 0.0f;
    float mWobbleDivision = 4.0f;   // 1/8

    float mSlapTime = 98.0f;
    float mSlapMix = 24.0f;
    float mSpringMix = 16.0f;
    float mSpaceOn = 1.0f;

    float mMasterMix = 100.0f;
    float mMasterOutput = 0.0f;

    float mPeakIn = 0.f;
    float mPeakOut = 0.f;
    // Kept per channel as well as summed: the header's IN/OUT ladders want one
    // number, the master strip's stereo bars want two.
    float mPeakOutL = 0.f;
    float mPeakOutR = 0.f;
    float mGainReductionDb = 0.f;

    void capturePeaks(float inPeak, float outPeakL, float outPeakR)
    {
        if (inPeak > mPeakIn)
            mPeakIn = inPeak;
        const float outPeak = std::max(outPeakL, outPeakR);
        if (outPeak > mPeakOut)
            mPeakOut = outPeak;
        if (outPeakL > mPeakOutL)
            mPeakOutL = outPeakL;
        if (outPeakR > mPeakOutR)
            mPeakOutR = outPeakR;
    }
};
