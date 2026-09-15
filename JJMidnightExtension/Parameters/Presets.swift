import Foundation
import AudioToolbox

struct FactoryPreset: Sendable {
    let number: Int
    let name: String
    let compAmount: AUValue
    let compAttack: AUValue
    let compRelease: AUValue
    let driveAmount: AUValue
    let driveTone: AUValue
    let driveCab: AUValue
    let wobbleRate: AUValue
    let wobbleDepth: AUValue
    let wobbleShape: AUValue
    let wobbleDivision: AUValue
    let slapTime: AUValue
    let slapMix: AUValue
    let springMix: AUValue
    let masterMix: AUValue
    let masterOutput: AUValue
    let compOn: Bool
    let driveOn: Bool
    let wobbleOn: Bool
    let wobbleSync: Bool
    let spaceOn: Bool

    var auPreset: AUAudioUnitPreset {
        let preset = AUAudioUnitPreset()
        preset.number = number
        preset.name = name
        return preset
    }
}

/// The engine underneath is a generic vintage clean / low-gain chain; these
/// are destinations for it — the laid-back end it was designed around, four
/// named after songs of that era, and the compressed, washed-out end the same
/// chain produces for a different audience.
///
/// Naming rule: song titles and places, never an artist or band name, and
/// never a claim that a preset reproduces a particular recording. Titles are
/// too short to carry copyright, which is why they are the tolerable end of
/// this; an artist's name in a product is a false-endorsement problem and
/// stays out. The same names must not appear in the App Store listing text —
/// in-app is a much smaller surface than the store entry itself.
enum FactoryPresets {
    static let all: [FactoryPreset] = [
        FactoryPreset(number: 0, name: "Default",
                      compAmount: 55, compAttack: 28, compRelease: 140,
                      driveAmount: 30, driveTone: 3000, driveCab: 50,
                      wobbleRate: 4.6, wobbleDepth: 32, wobbleShape: 20, wobbleDivision: 4,
                      slapTime: 98, slapMix: 24, springMix: 16,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // --- The laid-back end ---

        // Everything sits back: heavy comp, slow release, drive barely past
        // clean, tone rolled off. Nothing in this preset jumps out.
        FactoryPreset(number: 1, name: "Laid Back",
                      compAmount: 72, compAttack: 34, compRelease: 180,
                      driveAmount: 26, driveTone: 2600, driveCab: 60,
                      wobbleRate: 4.2, wobbleDepth: 28, wobbleShape: 15, wobbleDivision: 4,
                      slapTime: 105, slapMix: 28, springMix: 14,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // Darker and drier — mic further off-axis, less spring, the echo
        // doing the room work instead.
        FactoryPreset(number: 2, name: "Escondido",
                      compAmount: 65, compAttack: 30, compRelease: 160,
                      driveAmount: 34, driveTone: 2200, driveCab: 78,
                      wobbleRate: 3.8, wobbleDepth: 22, wobbleShape: 10, wobbleDivision: 4,
                      slapTime: 112, slapMix: 32, springMix: 8,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // Clean and open: no breakup to speak of, spring carrying it.
        FactoryPreset(number: 3, name: "Porch Light",
                      compAmount: 48, compAttack: 40, compRelease: 200,
                      driveAmount: 10, driveTone: 4200, driveCab: 38,
                      wobbleRate: 5.2, wobbleDepth: 18, wobbleShape: 5, wobbleDivision: 4,
                      slapTime: 88, slapMix: 18, springMix: 30,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // Tremolo forward, everything else out of the way.
        FactoryPreset(number: 4, name: "Whisper Trem",
                      compAmount: 60, compAttack: 32, compRelease: 150,
                      driveAmount: 18, driveTone: 3200, driveCab: 45,
                      wobbleRate: 6.4, wobbleDepth: 68, wobbleShape: 55, wobbleDivision: 4,
                      slapTime: 92, slapMix: 12, springMix: 20,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // --- Named for the songs, set by ear from the records ---
        // These are original settings that land in the same neighbourhood,
        // not transcriptions of anyone's signal chain.

        // Slow and close. Barely any breakup, tone well down, and the
        // slowest tremolo in the set on a pure sine — a sway rather than a
        // pulse. Drier than Sensitive Kind and lighter on the compressor:
        // this one is intimate where that one is spacious.
        FactoryPreset(number: 9, name: "Magnolia",
                      compAmount: 66, compAttack: 36, compRelease: 190,
                      driveAmount: 15, driveTone: 2500, driveCab: 62,
                      wobbleRate: 2.8, wobbleDepth: 30, wobbleShape: 0, wobbleDivision: 4,
                      slapTime: 90, slapMix: 14, springMix: 16,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // The rolling boogie shuffle: brighter, bouncier, barely any
        // breakup, mic close to the dust cap. Tremolo quick enough to sit
        // with the shuffle rather than sway against it.
        FactoryPreset(number: 10, name: "Call Me The Breeze",
                      compAmount: 58, compAttack: 30, compRelease: 120,
                      driveAmount: 22, driveTone: 3800, driveCab: 40,
                      wobbleRate: 6.8, wobbleDepth: 30, wobbleShape: 20, wobbleDivision: 4,
                      slapTime: 82, slapMix: 26, springMix: 12,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // Clean and funky with the tremolo well forward — the one preset
        // here where Wobble is the loudest thing in the chain.
        FactoryPreset(number: 11, name: "After Midnight",
                      compAmount: 64, compAttack: 26, compRelease: 150,
                      driveAmount: 16, driveTone: 3400, driveCab: 45,
                      wobbleRate: 5.8, wobbleDepth: 52, wobbleShape: 45, wobbleDivision: 4,
                      slapTime: 95, slapMix: 18, springMix: 18,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // The slow one. Heaviest compression and the slowest release in the
        // set, tone right down, tank open — everything sits back and nothing
        // moves quickly.
        FactoryPreset(number: 12, name: "Sensitive Kind",
                      compAmount: 80, compAttack: 40, compRelease: 220,
                      driveAmount: 14, driveTone: 2000, driveCab: 72,
                      wobbleRate: 3.4, wobbleDepth: 20, wobbleShape: 8, wobbleDivision: 4,
                      slapTime: 118, slapMix: 22, springMix: 34,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // --- The same chain, aimed at the other market ---

        // Squashed flat and rolled right off: the bedroom-pop guitar sound.
        FactoryPreset(number: 5, name: "Faded",
                      compAmount: 88, compAttack: 18, compRelease: 90,
                      driveAmount: 22, driveTone: 1800, driveCab: 85,
                      wobbleRate: 3.2, wobbleDepth: 24, wobbleShape: 30, wobbleDivision: 4,
                      slapTime: 120, slapMix: 20, springMix: 42,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // Wobble doing the tape-warble job, slapback long and loud.
        FactoryPreset(number: 6, name: "Cassette",
                      compAmount: 76, compAttack: 22, compRelease: 110,
                      driveAmount: 42, driveTone: 2000, driveCab: 70,
                      wobbleRate: 1.8, wobbleDepth: 44, wobbleShape: 0, wobbleDivision: 4,
                      slapTime: 145, slapMix: 38, springMix: 24,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: true, wobbleSync: false, spaceOn: true),

        // Ambient: no tremolo, tank wide open, drive just enough to bloom.
        FactoryPreset(number: 7, name: "Night Drive",
                      compAmount: 68, compAttack: 45, compRelease: 240,
                      driveAmount: 16, driveTone: 3600, driveCab: 40,
                      wobbleRate: 4.0, wobbleDepth: 0, wobbleShape: 0, wobbleDivision: 4,
                      slapTime: 160, slapMix: 26, springMix: 68,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: true, wobbleOn: false, wobbleSync: false, spaceOn: true),

        // Chain off except the compressor — a clean, level DI with the
        // front-end glue and nothing else.
        FactoryPreset(number: 8, name: "Flat & Even",
                      compAmount: 62, compAttack: 26, compRelease: 130,
                      driveAmount: 0, driveTone: 8000, driveCab: 20,
                      wobbleRate: 4.6, wobbleDepth: 0, wobbleShape: 0, wobbleDivision: 4,
                      slapTime: 98, slapMix: 0, springMix: 0,
                      masterMix: 100, masterOutput: 0,
                      compOn: true, driveOn: false, wobbleOn: false, wobbleSync: false, spaceOn: false)
    ]
}

enum JJMidnightPresetError: LocalizedError {
    case emptyName
    case persistFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Enter a preset name."
        case .persistFailed:
            return "Could not save the preset on this device."
        case .notFound:
            return "That preset is no longer on this device."
        }
    }
}
