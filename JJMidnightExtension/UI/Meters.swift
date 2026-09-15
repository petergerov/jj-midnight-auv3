import SwiftUI

// Two bar meters that share their chrome: gain reduction in the Comp block,
// and output level on the master strip.
//
// Both are bars rather than needles or LED ladders. A bar keeps what actually
// made the needle readable — damped ballistics, a non-linear scale, and a
// clear rest position — while being flat instead of tall, which is what lets
// the Comp block sit at the same height as the other three sections.

// MARK: - Shared chrome

/// The recessed slot a bar sits in. Both meters draw their fill inside this.
private struct BarTrack: View {
    var theme: GearPalette
    var radius: CGFloat = 2

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(theme.ledBackground)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(.black.opacity(0.7), lineWidth: 1)
            )
            .overlay(
                // Light catching the lower lip, so the slot reads as cut into
                // the plate rather than painted on it.
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.panelEdgeLight.opacity(0.18), lineWidth: 0.6)
                    .padding(.top, 1.5)
            )
    }
}

/// Silkscreened tick labels above a bar, placed by a caller-supplied mapping
/// from value to fraction across the track.
private struct BarScale: View {
    var labels: [(value: Double, text: String)]
    var fraction: (Double) -> Double
    var theme: GearPalette

    var body: some View {
        GeometryReader { geo in
            // enumerated() rather than `indices`, which now resolves
            // ambiguously against the `indices(where:)` overload.
            ForEach(Array(labels.enumerated()), id: \.offset) { _, entry in
                Text(entry.text)
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textMuted.opacity(0.85))
                    .fixedSize()
                    // Nudged in at the ends so the outermost label is not
                    // half off the plate — a silkscreened scale does the same
                    // thing. 9 pt covers the widest label here at 7 pt
                    // monospaced.
                    .position(x: min(max(geo.size.width * fraction(entry.value), 9),
                                     geo.size.width - 9),
                              y: geo.size.height / 2)
            }
        }
        .frame(height: 9)
    }
}

// MARK: - Gain reduction

/// Gain reduction in the Comp block: one bar, filling **right to left**.
///
/// It rests empty at the right and grows leftwards as the compressor takes
/// hold. A bar that filled left-to-right would read as *level*, which is the
/// opposite of what this shows.
///
/// Two things carry over from the needle it replaces, because they are what
/// made it readable rather than what made it look old:
///
/// - **Ballistics.** The fill is a damped mass on a spring, so it overshoots
///   slightly and settles instead of tracking the value exactly. Measured at
///   99% in 233 ms with 2.4% overshoot.
/// - **A non-linear scale.** Position goes as `(dB / 20)^0.7`, so the first
///   few dB take up far more of the bar than the last few — 0–6 dB is where
///   the work happens and 20 dB just means "too much".
struct GainReductionMeter: View {
    let audioUnit: JJMidnightAudioUnit?

    private let fullScaleDb: Double = 20

    var body: some View {
        TimelineView(.animation) { context in
            let target = audioUnit?.gainReductionDb() ?? 0
            let shown = GainReductionFollower.shared.tick(now: context.date, target: target)
            content(reductionDb: shown)
        }
        .accessibilityElement()
        .accessibilityLabel("Gain reduction")
        .accessibilityValue(String(format: "%.1f decibels", max(0, audioUnit?.gainReductionDb() ?? 0)))
    }

    /// dB to a fraction of the track measured from the **right** edge.
    private func fill(_ db: Double) -> Double {
        pow(min(max(db, 0), fullScaleDb) / fullScaleDb, 0.7)
    }

    private func content(reductionDb: Double) -> some View {
        let theme = GearTheme.current
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("GAIN REDUCTION")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(theme.textLight.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 0, y: 0.5)
                Spacer(minLength: 4)
                Text(reductionDb >= 0.15 ? String(format: "−%.1f dB", reductionDb) : "0.0 dB")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.ledText)
                    .shadow(color: theme.ledText.opacity(0.7), radius: 2)
            }

            // Scale labels sit above the bar, positioned by the same
            // non-linear mapping the fill uses, so they cannot disagree.
            BarScale(labels: [(0, "0"), (2, "2"), (4, "4"), (8, "8"), (20, "20")],
                     fraction: { 1 - self.fill($0) },
                     theme: theme)

            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    BarTrack(theme: theme)
                    // Amber for the working range, red past 10 dB — deep
                    // reduction is a setting to notice, not a clip to avoid,
                    // so only the far end goes red.
                    let width = geo.size.width * fill(reductionDb)
                    LinearGradient(
                        colors: [theme.meterAmber, theme.meterAmber, theme.meterRed],
                        startPoint: .trailing, endPoint: .leading
                    )
                    .mask(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 1.5).frame(width: width)
                    }
                    .padding(1.5)
                }
            }
            .frame(height: 13)
        }
    }
}

// MARK: - Output level

/// Output level on the master strip: two bars, left over right, so you can
/// see what the plug-in is actually handing back.
///
/// Worth having here rather than trusting the header's small IN/OUT ladders,
/// because this chain can add a lot of level on its own — the compressor's
/// make-up reaches +13 dB and Drive adds more — and a clip after all that is
/// easy to miss. Hence the peak-hold ticks and the latching clip lamp.
struct OutputMeter: View {
    let audioUnit: JJMidnightAudioUnit?

    var body: some View {
        TimelineView(.animation) { context in
            let peaks = audioUnit?.takeOutputPeaks() ?? (0, 0)
            let state = OutputFollower.shared.tick(now: context.date, peaks: peaks)
            content(state)
        }
        .accessibilityElement()
        .accessibilityLabel("Output level")
    }

    /// dBFS to a fraction of the track. Linear in dB over a 54 dB window,
    /// which is what a mixing meter wants — unlike gain reduction, every part
    /// of this range gets used.
    private static let floorDb: Double = -54

    private func fill(_ db: Double) -> Double {
        min(max((db - Self.floorDb) / -Self.floorDb, 0), 1)
    }

    private func content(_ state: OutputFollower.State) -> some View {
        let theme = GearTheme.current
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("OUTPUT")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(theme.textLight.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 0, y: 0.5)
                Spacer(minLength: 4)
                Text(state.holdDb > Self.floorDb ? String(format: "%+.1f dB", state.holdDb) : "—")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(state.clipped ? theme.meterRed : theme.ledText)
                    .shadow(color: (state.clipped ? theme.meterRed : theme.ledText).opacity(0.7), radius: 2)
                JewelLamp(isOn: state.clipped, color: theme.lampRed, theme: theme)
                    .frame(width: 7, height: 7)
            }

            BarScale(labels: [(-48, "-48"), (-36, "-36"), (-24, "-24"),
                              (-12, "-12"), (-6, "-6"), (0, "0")],
                     fraction: { self.fill($0) },
                     theme: theme)

            VStack(spacing: 2) {
                bar(db: state.leftDb, hold: state.leftHoldDb, theme: theme, label: "L")
                bar(db: state.rightDb, hold: state.rightHoldDb, theme: theme, label: "R")
            }
        }
    }

    private func bar(db: Double, hold: Double, theme: GearPalette, label: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(theme.textMuted)
                .frame(width: 7)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    BarTrack(theme: theme)
                    LinearGradient(
                        colors: [theme.meterGreen, theme.meterGreen, theme.meterAmber, theme.meterRed],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .mask(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .frame(width: geo.size.width * fill(db))
                    }
                    .padding(1.5)

                    // Peak hold: a thin bright tick at the loudest sample of
                    // the last second and a half. Without it a fast transient
                    // that clips is gone before the eye catches the bar.
                    if hold > Self.floorDb {
                        Rectangle()
                            .fill(theme.metalLight.opacity(0.9))
                            .frame(width: 1.5)
                            .offset(x: min(geo.size.width - 2.5,
                                           max(1, geo.size.width * fill(hold) - 0.75)))
                    }
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Ballistics

/// The gain-reduction fill as a damped mass on a spring.
///
/// A plain smoother would approach the value and stop, which makes a bar look
/// like it is being plotted. Inertia — accelerate, overshoot a little, settle
/// — is what made the needle feel connected to the sound, and it costs the
/// same here.
///
/// Measured at 60 Hz: 99% in 233 ms with 2.4% overshoot. Integrated
/// semi-implicitly (velocity first, then position) because plain Euler goes
/// unstable at this stiffness the moment a frame is dropped.
private final class GainReductionFollower: @unchecked Sendable {
    static let shared = GainReductionFollower()

    private var position: Double = 0
    private var velocity: Double = 0
    private var lastDate: Date?

    private let omega: Double = 13.5
    private let zeta: Double = 0.70

    func tick(now: Date, target: Float) -> Double {
        let dt: Double
        if let lastDate {
            // Clamped: returning from a stalled view must not fling the bar
            // across the track in a single step.
            dt = min(max(now.timeIntervalSince(lastDate), 0), 1.0 / 20.0)
        } else {
            dt = 1.0 / 60.0
        }
        lastDate = now

        let goal = Double(max(target, 0))
        velocity += (omega * omega * (goal - position) - 2 * zeta * omega * velocity) * dt
        position += velocity * dt
        if position < 0 {
            position = 0
            if velocity < 0 { velocity = 0 }
        }
        return position
    }
}

/// Output level ballistics: instant rise, then a fixed fall in dB per second,
/// which is how a peak programme meter behaves. Spring ballistics would be
/// wrong here — for level you want to see the peak, not a mass chasing it.
private final class OutputFollower: @unchecked Sendable {
    struct State {
        var leftDb: Double
        var rightDb: Double
        var leftHoldDb: Double
        var rightHoldDb: Double
        /// Loudest of the two holds, for the numeric readout.
        var holdDb: Double
        var clipped: Bool
    }

    static let shared = OutputFollower()

    private var left: Double = -120
    private var right: Double = -120
    private var leftHold: Double = -120
    private var rightHold: Double = -120
    private var holdUntil: Date = .distantPast
    private var clipUntil: Date = .distantPast
    private var lastDate: Date?

    /// Decay rate. 20 dB/s is the usual PPM fallback — slow enough to read,
    /// fast enough not to lag the part.
    private let fallDbPerSecond: Double = 20
    private let holdSeconds: Double = 1.5
    /// Anything this close to full scale is treated as clipped: the render
    /// path does not hard-limit, so samples can exceed 0 dBFS outright.
    private let clipThresholdDb: Double = -0.1

    func tick(now: Date, peaks: (left: Float, right: Float)) -> State {
        let dt: Double
        if let lastDate {
            dt = min(max(now.timeIntervalSince(lastDate), 0), 1.0 / 10.0)
        } else {
            dt = 1.0 / 60.0
        }
        lastDate = now

        func db(_ linear: Float) -> Double {
            linear > 0 ? 20 * log10(Double(linear)) : -120
        }

        let fall = fallDbPerSecond * dt
        // Instant rise, timed fall. `peaks` is already the max since the last
        // read, so a transient between frames cannot slip past.
        left = max(left - fall, db(peaks.left))
        right = max(right - fall, db(peaks.right))

        if left > leftHold || right > rightHold || now > holdUntil {
            if now > holdUntil {
                leftHold = left
                rightHold = right
            } else {
                leftHold = max(leftHold, left)
                rightHold = max(rightHold, right)
            }
            holdUntil = now.addingTimeInterval(holdSeconds)
        }

        if max(left, right) >= clipThresholdDb {
            clipUntil = now.addingTimeInterval(holdSeconds)
        }

        return State(leftDb: left, rightDb: right,
                     leftHoldDb: leftHold, rightHoldDb: rightHold,
                     holdDb: max(leftHold, rightHold),
                     clipped: now < clipUntil)
    }
}
