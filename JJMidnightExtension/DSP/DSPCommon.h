#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/// Flush-to-zero / denormal flush for the render thread (matches JUCE ScopedNoDenormals).
struct FlushDenormals
{
    FlushDenormals() noexcept
    {
#if defined(__arm64__) || defined(__aarch64__)
        uint64_t fpcr;
        __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
        saved = fpcr;
        fpcr |= (1ull << 24); // FZ
        __asm__ __volatile__("msr fpcr, %0" : : "ri"(fpcr));
#endif
    }

    ~FlushDenormals() noexcept
    {
#if defined(__arm64__) || defined(__aarch64__)
        __asm__ __volatile__("msr fpcr, %0" : : "ri"(saved));
#endif
    }

#if defined(__arm64__) || defined(__aarch64__)
    uint64_t saved = 0;
#endif
};
