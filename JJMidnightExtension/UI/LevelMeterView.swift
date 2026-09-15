import SwiftUI

struct LevelMeterView: View {
    let audioUnit: JJMidnightAudioUnit?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { context in
            let peaks = audioUnit?.takeMeterPeaks() ?? (0, 0)
            let env = Envelope.shared.tick(now: context.date, peaks: peaks)
            MeterBars(input: env.input, output: env.output, theme: GearTheme.current)
        }
        .frame(width: 58, height: 32)
        .accessibilityHidden(true)
    }
}

/// A segmented LED ladder, the way outboard gear showed level before
/// screens: ten lamps per row, green through amber into red, dark when the
/// signal is below their threshold.
private struct MeterBars: View {
    var input: Float
    var output: Float
    var theme: GearPalette

    private let segments = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            meterRow(label: "IN", level: input)
            meterRow(label: "OUT", level: output)
        }
    }

    private func meterRow(label: String, level: Float) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(theme.textLight.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 0, y: 0.5)
                .frame(width: 18, alignment: .leading)

            Canvas { context, size in
                let lit = Int((displayLevel(level) * Float(segments)).rounded(.down))
                let gap = size.width * 0.055 / CGFloat(segments - 1) * CGFloat(segments)
                let cellWidth = (size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)

                for i in 0..<segments {
                    let x = CGFloat(i) * (cellWidth + gap)
                    let cell = CGRect(x: x, y: 0, width: cellWidth, height: size.height)
                    let path = Path(roundedRect: cell, cornerRadius: min(1.5, cellWidth * 0.35))
                    let colour = segmentColour(i)
                    if i < lit {
                        context.fill(path.strokedPath(.init(lineWidth: 2.4)),
                                     with: .color(colour.opacity(0.35)))
                        context.fill(path, with: .color(colour))
                    } else {
                        context.fill(path, with: .color(theme.meterOff))
                        context.stroke(path, with: .color(.black.opacity(0.55)), lineWidth: 0.6)
                    }
                }
            }
            .frame(height: 7)
            .padding(.horizontal, 2.5)
            .padding(.vertical, 2)
            .background(LedWindow(cornerRadius: 2))
        }
    }

    private func segmentColour(_ index: Int) -> Color {
        switch index {
        case 0..<6: return theme.meterGreen
        case 6..<8: return theme.meterAmber
        default: return theme.meterRed
        }
    }

    private func displayLevel(_ peak: Float) -> Float {
        let db = 20 * log10(max(peak, 0.000_1))
        return min(1, max(0, (db + 48) / 48))
    }
}

/// Holds decaying peak envelopes so the DSP can reset peaks each poll.
private final class Envelope: @unchecked Sendable {
    static let shared = Envelope()
    private var input: Float = 0
    private var output: Float = 0
    private var lastDate = Date.distantPast

    func tick(now: Date, peaks: (input: Float, output: Float)) -> (input: Float, output: Float) {
        // TimelineView may evaluate the view builder more than once per frame.
        // Only consume DSP peaks on a real time step.
        if now.timeIntervalSince(lastDate) > 0.02 {
            lastDate = now
            input = max(input * 0.72, peaks.input)
            output = max(output * 0.72, peaks.output)
        }
        return (input, output)
    }
}
