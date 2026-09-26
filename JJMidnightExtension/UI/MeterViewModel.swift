import Foundation
import Observation

/// Everything the panel's meters show, advanced by one clock.
///
/// Each meter used to run its own `TimelineView`, and the header ladder and
/// the preset dot two more timers, so five clocks drained the same kernel at
/// different rates. One `tick` now reads every accumulator once per frame and
/// runs the ballistics; the views only draw what is here. Values are written
/// only when they change, so a silent input costs no redraws.
@MainActor
@Observable
final class MeterViewModel {
    private(set) var headerInput: Float = 0
    private(set) var headerOutput: Float = 0
    private(set) var gainReductionDb: Double = 0
    private(set) var input = InputFollower.State(db: -120, holdDb: -120)
    private(set) var output = OutputFollower.State(leftDb: -120, rightDb: -120,
                                                   leftHoldDb: -120, rightHoldDb: -120,
                                                   holdDb: -120, clipped: false)

    private let audioUnit: JJMidnightAudioUnit?
    // Per panel, not shared: every plug-in instance in the extension process
    // has its own panel, and they must not animate each other's bars.
    @ObservationIgnored private let headerEnvelope = HeaderLevelEnvelope()
    @ObservationIgnored private let gainReductionFollower = GainReductionFollower()
    @ObservationIgnored private let inputFollower = InputFollower()
    @ObservationIgnored private let outputFollower = OutputFollower()
    @ObservationIgnored private var lastTick: Date?

    init(audioUnit: JJMidnightAudioUnit?) {
        self.audioUnit = audioUnit
    }

    func tick(now: Date) {
        guard let audioUnit else { return }
        let dt = min(max(lastTick.map { now.timeIntervalSince($0) } ?? 1.0 / 60.0, 0), 0.1)
        lastTick = now

        headerEnvelope.tick(dt: dt, peaks: audioUnit.takeMeterPeaks())
        assign(\.headerInput, headerEnvelope.input)
        assign(\.headerOutput, headerEnvelope.output)
        assign(\.gainReductionDb,
               gainReductionFollower.tick(now: now, target: audioUnit.gainReductionDb()))
        assign(\.input, inputFollower.tick(now: now, peak: audioUnit.takeInputPeak()))
        assign(\.output, outputFollower.tick(now: now, peaks: audioUnit.takeOutputPeaks()))
    }

    private func assign<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<MeterViewModel, Value>,
                                          _ value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
