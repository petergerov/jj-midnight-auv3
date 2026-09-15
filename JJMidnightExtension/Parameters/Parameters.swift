import Foundation
import AudioToolbox

/// Note divisions for the tempo-synced tremolo, slowest first so the knob
/// sweeps in one direction. The cycles-per-beat multipliers that go with these
/// names live in the kernel; `JJMidnightWobbleDivisionCount` in the shared header
/// keeps the two lists the same length.
enum JJMidnightWobbleDivisions {
    static let names = ["1/2", "1/4", "1/8.", "1/4T", "1/8", "1/8T", "1/16"]
    /// 1/8 — the division a tremolo most often wants.
    static let defaultIndex = 4
}

/// Slapback range. The 80–120 ms window is the useful part; the range runs
/// wider so presets can reach a tighter doubling or a longer tape echo.
let JJMidnightSlapMaxMs: AUValue = 250

let JJMidnightParameterSpecs = ParameterTreeSpec {
    ParameterGroupSpec(identifier: "comp", name: "Comp") {
        // Percent rather than a threshold in dB, deliberately. A VCA
        // compressor exposes threshold and ratio separately and should be
        // marked in dB; an optical one cannot, because the cell sets both
        // itself and does it program-dependently. The LA-2A's single control
        // is marked 0-10 with no unit for exactly this reason, and this knob
        // moves threshold, ratio and make-up together (see the kernel).
        // Marking it with any one of those would be a half-truth. The dB
        // figure the user wants is the GR meter, which is already on the
        // panel. Documented in docs/comp.md.
        ParameterSpec(address: .compAmount, identifier: "compAmount", name: "Comp",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 55.0, unitName: "%")
        ParameterSpec(address: .compAttack, identifier: "compAttack", name: "Attack",
                      units: .milliseconds, valueRange: 5.0...80.0, defaultValue: 28.0, unitName: "ms")
        ParameterSpec(address: .compRelease, identifier: "compRelease", name: "Release",
                      units: .milliseconds, valueRange: 40.0...400.0, defaultValue: 140.0, unitName: "ms")
        ParameterSpec(address: .compOn, identifier: "compOn", name: "Comp On",
                      units: .boolean, valueRange: 0.0...1.0, defaultValue: 1.0)
    }
    ParameterGroupSpec(identifier: "drive", name: "Drive") {
        ParameterSpec(address: .driveAmount, identifier: "driveAmount", name: "Drive",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 30.0, unitName: "%")
        ParameterSpec(address: .driveTone, identifier: "driveTone", name: "Tone",
                      units: .hertz, valueRange: 800.0...8_000.0, defaultValue: 3_000.0, unitName: "Hz")
        ParameterSpec(address: .driveCab, identifier: "driveCab", name: "Mic",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 50.0, unitName: "%")
        ParameterSpec(address: .driveOn, identifier: "driveOn", name: "Drive On",
                      units: .boolean, valueRange: 0.0...1.0, defaultValue: 1.0)
    }
    ParameterGroupSpec(identifier: "wobble", name: "Wobble") {
        ParameterSpec(address: .wobbleRate, identifier: "wobbleRate", name: "Rate",
                      units: .hertz, valueRange: 0.2...12.0, defaultValue: 4.6, unitName: "Hz")
        ParameterSpec(address: .wobbleDepth, identifier: "wobbleDepth", name: "Depth",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 32.0, unitName: "%")
        ParameterSpec(address: .wobbleShape, identifier: "wobbleShape", name: "Shape",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 20.0, unitName: "%")
        ParameterSpec(address: .wobbleOn, identifier: "wobbleOn", name: "Wobble On",
                      units: .boolean, valueRange: 0.0...1.0, defaultValue: 1.0)
        // Sync and Rate are separate parameters rather than one knob that
        // changes meaning, so each stays a single thing to a host's
        // automation. The panel shows whichever one Sync selects.
        ParameterSpec(address: .wobbleSync, identifier: "wobbleSync", name: "Wobble Sync",
                      units: .boolean, valueRange: 0.0...1.0, defaultValue: 0.0)
        ParameterSpec(address: .wobbleDivision, identifier: "wobbleDivision", name: "Division",
                      units: .indexed,
                      valueRange: 0.0...AUValue(JJMidnightWobbleDivisions.names.count - 1),
                      defaultValue: AUValue(JJMidnightWobbleDivisions.defaultIndex),
                      valueStrings: JJMidnightWobbleDivisions.names)
    }
    ParameterGroupSpec(identifier: "space", name: "Space") {
        ParameterSpec(address: .slapTime, identifier: "slapTime", name: "Slap",
                      units: .milliseconds, valueRange: 40.0...JJMidnightSlapMaxMs, defaultValue: 98.0, unitName: "ms")
        ParameterSpec(address: .slapMix, identifier: "slapMix", name: "Echo",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 24.0, unitName: "%")
        ParameterSpec(address: .springMix, identifier: "springMix", name: "Spring",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 16.0, unitName: "%")
        ParameterSpec(address: .spaceOn, identifier: "spaceOn", name: "Space On",
                      units: .boolean, valueRange: 0.0...1.0, defaultValue: 1.0)
    }
    ParameterGroupSpec(identifier: "master", name: "Master") {
        ParameterSpec(address: .masterMix, identifier: "masterMix", name: "Mix",
                      units: .percent, valueRange: 0.0...100.0, defaultValue: 100.0, unitName: "%")
        ParameterSpec(address: .masterOutput, identifier: "masterOutput", name: "Output",
                      units: .decibels, valueRange: -12.0...12.0, defaultValue: 0.0, unitName: "dB")
    }
}

extension ParameterSpec {
    init(
        address: JJMidnightParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        defaultValue: AUValue,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [.flag_IsWritable, .flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        var resolvedFlags = flags
        if units != .boolean {
            resolvedFlags.insert(.flag_CanRamp)
        }
        self.init(
            address: address.rawValue,
            identifier: identifier,
            name: name,
            units: units,
            valueRange: valueRange,
            defaultValue: defaultValue,
            unitName: unitName,
            flags: resolvedFlags,
            valueStrings: valueStrings,
            dependentParameters: dependentParameters
        )
    }
}

/// Distinct from jj-breeze on every axis that iOS keys on: a different
/// four-character subtype, a different bundle ID, and a different App Group.
/// Reusing any of them would make the two plug-ins collide — sharing the
/// trial clock at best, failing to register side by side at worst.
enum AudioUnitIdentity {
    static let type = "aufx"
    static let subtype = "Jjm1"
    static let manufacturer = "Grov"
    static let componentName = "Gerov: jj-midnight"
}
