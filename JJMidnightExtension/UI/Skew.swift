import Foundation

/// Matches juce::NormalisableRange (JUCE 9) so knobs feel like the desktop AU.
struct SkewedRange {
    var min: Float
    var max: Float
    var skew: Float = 1
    var symmetric: Bool = false

    func toNormalized(_ value: Float) -> Float {
        let span = max - min
        guard span > 0 else { return 0 }
        let proportion = ((value - min) / span).clamped(to: 0...1)
        if abs(skew - 1) < 1e-6 { return proportion }
        if !symmetric {
            return pow(proportion, skew)
        }
        let distance = 2 * proportion - 1
        let skewed = pow(abs(distance), skew) * (distance < 0 ? -1 : 1)
        return (1 + skewed) / 2
    }

    func fromNormalized(_ t: Float) -> Float {
        var proportion = t.clamped(to: 0...1)
        if !symmetric {
            if abs(skew - 1) > 1e-6, proportion > 0 {
                proportion = exp(log(proportion) / skew)
            }
            return min + (max - min) * proportion
        }
        var distance = 2 * proportion - 1
        if abs(skew - 1) > 1e-6, abs(distance) > 0 {
            distance = exp(log(abs(distance)) / skew) * (distance < 0 ? -1 : 1)
        }
        return min + (max - min) / 2 * (1 + distance)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
