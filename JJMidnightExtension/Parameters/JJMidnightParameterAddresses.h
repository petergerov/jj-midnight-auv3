#pragma once

#include <AudioToolbox/AUParameters.h>

/// Four macro blocks in signal order, then the master strip. The order here
/// is the order of the chain, and the UI reads it the same way.
typedef NS_ENUM(AUParameterAddress, JJMidnightParameterAddress) {
    // Comp — optical, first in the chain. This is what makes everything
    // downstream sit back.
    compAmount = 0,
    compAttack,
    compRelease,
    compOn,

    // Drive — low-gain breakup, tone rolloff, and the cabinet.
    driveAmount,
    driveTone,
    driveCab,
    driveOn,

    // Wobble — amp-style amplitude tremolo.
    wobbleRate,
    wobbleDepth,
    wobbleShape,
    wobbleOn,
    wobbleSync,
    wobbleDivision,

    // Space — slapback plus spring tank.
    slapTime,
    slapMix,
    springMix,
    spaceOn,

    // Master. Prefixed because the unprefixed names would be global
    // constants in the C++ kernel and are too generic to leave unqualified.
    masterMix,
    masterOutput
};

/// Number of note divisions the tempo-synced tremolo offers. The names live in
/// Parameters.swift and the cycles-per-beat multipliers in the kernel; this
/// constant is shared so the two lists cannot fall out of step unnoticed.
#define JJMidnightWobbleDivisionCount 7
