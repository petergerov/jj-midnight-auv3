import SwiftUI

struct LevelMeterView: View {
    let meters: MeterViewModel

    var body: some View {
        MeterBars(input: meters.headerInput, output: meters.headerOutput, theme: GearTheme.current)
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

/// Decaying peak envelopes for the header ladders, so the DSP can reset its
/// peaks on every read.
///
/// Falls to 72 % every 50 ms — the rate the ladder was tuned at when it
/// polled at 20 Hz — scaled to however long it has actually been since the
/// last tick, so the fall looks the same at any frame rate.
final class HeaderLevelEnvelope {
    private(set) var input: Float = 0
    private(set) var output: Float = 0

    func tick(dt: Double, peaks: (input: Float, output: Float)) {
        let decay = Float(pow(0.72, dt / 0.05))
        input = max(input * decay, peaks.input)
        output = max(output * decay, peaks.output)
    }
}
