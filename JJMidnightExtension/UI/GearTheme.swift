import SwiftUI

/// One complete panel colourway. Everything the UI draws — chassis paint,
/// sub-plates, chrome, bakelite, lamps, glass readouts — comes from here,
/// so a whole different piece of hardware is one struct away. The JUCE
/// sibling project jj-breeze carries the same idea in GearPalette::Theme.
struct GearPalette: Identifiable, Equatable {
    let id: String
    let name: String

    // Steel chassis the front plate is bolted into.
    let chassisTop: Color
    let chassisBottom: Color

    // The painted front plate, and the sub-plates screwed onto it.
    let paintTop: Color
    let paintBottom: Color
    let panelFill: Color
    let panelEdgeLight: Color
    let panelEdgeDark: Color

    // Chrome / nickel hardware: knob collars, bat switches, screws.
    let metalLight: Color
    let metalMid: Color
    let metalDark: Color

    // Knob body.
    let bakeliteLight: Color
    let bakeliteDark: Color

    // Pointer accent and its switched-off version.
    let accent: Color
    let accentDim: Color

    // Silkscreen lettering.
    let textLight: Color
    let textMuted: Color

    // Glass readout windows.
    let ledBackground: Color
    let ledText: Color

    // Jewel lamps and the segmented level ladder.
    let lampRed: Color
    let lampRedDim: Color
    let meterGreen: Color
    let meterAmber: Color
    let meterRed: Color
    let meterOff: Color
}

private func rgb(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xff) / 255,
          green: Double((hex >> 8) & 0xff) / 255,
          blue: Double(hex & 0xff) / 255)
}

extension GearPalette {
    /// 1960s-70s military-green outboard gear: hammered enamel over steel,
    /// cream silkscreen, black bakelite knobs, amber lamps.
    static let fieldGreen = GearPalette(
        id: "green", name: "Field Green",
        chassisTop: rgb(0x2b2c28), chassisBottom: rgb(0x121311),
        paintTop: rgb(0x5b6950), paintBottom: rgb(0x333e2d),
        panelFill: rgb(0x3d4936), panelEdgeLight: rgb(0x7d8a70), panelEdgeDark: rgb(0x1b2118),
        metalLight: rgb(0xe4e6df), metalMid: rgb(0x9b9f96), metalDark: rgb(0x30332e),
        bakeliteLight: rgb(0x4a4c48), bakeliteDark: rgb(0x0b0c0b),
        accent: rgb(0xe8a33d), accentDim: rgb(0x7d5a24),
        textLight: rgb(0xf1e9d4), textMuted: rgb(0xa9ad95),
        ledBackground: rgb(0x120d08), ledText: rgb(0xffb24e),
        lampRed: rgb(0xff3b2a), lampRedDim: rgb(0x4a120d),
        meterGreen: rgb(0x74e05c), meterAmber: rgb(0xffc03a),
        meterRed: rgb(0xff4e35), meterOff: rgb(0x1a1e18))

    /// The blue-grey rack finish carried over from the JUCE build's "slate"
    /// colourway: gunmetal plate, nickel hardware, brass accent.
    static let slate = GearPalette(
        id: "slate", name: "Slate",
        chassisTop: rgb(0x2a2c2e), chassisBottom: rgb(0x141618),
        paintTop: rgb(0x51616a), paintBottom: rgb(0x2c363c),
        panelFill: rgb(0x3a464e), panelEdgeLight: rgb(0x7f8d97), panelEdgeDark: rgb(0x1a2126),
        metalLight: rgb(0xdde1e5), metalMid: rgb(0x8f959a), metalDark: rgb(0x2a2c2e),
        bakeliteLight: rgb(0x474d51), bakeliteDark: rgb(0x0c0e10),
        accent: rgb(0xc9974a), accentDim: rgb(0x7a5b2c),
        textLight: rgb(0xf2efe4), textMuted: rgb(0xaab0ac),
        ledBackground: rgb(0x111310), ledText: rgb(0xe0b876),
        lampRed: rgb(0xff4436), lampRedDim: rgb(0x451512),
        meterGreen: rgb(0x6fd6a0), meterAmber: rgb(0xe8c05a),
        meterRed: rgb(0xff5f45), meterOff: rgb(0x171b1e))

    /// The default here: a late-50s tweed combo. Lacquered sand-and-brown
    /// cloth over the chassis, oxblood panel, brass hardware instead of
    /// nickel, cream silkscreen, and a green jewel lamp. It is the finish the
    /// whole signal chain is pointing at, so it leads the list.
    static let tweed = GearPalette(
        id: "tweed", name: "Tweed",
        chassisTop: rgb(0x3a2f22), chassisBottom: rgb(0x1b150e),
        paintTop: rgb(0xc2a068), paintBottom: rgb(0x8a6b3c),
        panelFill: rgb(0x5c2b26), panelEdgeLight: rgb(0xd8bc8a), panelEdgeDark: rgb(0x2a120f),
        metalLight: rgb(0xf0e2c2), metalMid: rgb(0xb99a5e), metalDark: rgb(0x3a2d18),
        bakeliteLight: rgb(0x4e4035), bakeliteDark: rgb(0x110c08),
        accent: rgb(0xf0c96a), accentDim: rgb(0x7f6730),
        textLight: rgb(0xf7eeda), textMuted: rgb(0xbda684),
        ledBackground: rgb(0x160e06), ledText: rgb(0xffc46a),
        lampRed: rgb(0xff4030), lampRedDim: rgb(0x4c140e),
        meterGreen: rgb(0x8fd96a), meterAmber: rgb(0xf5bd45),
        meterRed: rgb(0xff5335), meterOff: rgb(0x241a10))

    static let all: [GearPalette] = [.tweed, .fieldGreen, .slate]

    /// Falls back to the default rather than refusing to load, for a state
    /// saved by a build that knows a colourway this one doesn't.
    static func byId(_ id: String) -> GearPalette {
        all.first { $0.id == id } ?? .tweed
    }
}

/// Which colourway the panel is wearing. Observable so that every view
/// reading a GearTheme colour in its body re-renders when it changes; the
/// choice is remembered per process (the app and the appex each keep their
/// own, like their user presets).
@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private static let key = "jjmidnight.theme"

    private(set) var palette: GearPalette

    private init() {
        palette = GearPalette.byId(UserDefaults.standard.string(forKey: Self.key) ?? GearPalette.tweed.id)
    }

    func select(_ palette: GearPalette) {
        guard palette != self.palette else { return }
        self.palette = palette
        UserDefaults.standard.set(palette.id, forKey: Self.key)
    }
}

/// The colours the UI actually reads. Kept as a namespace of properties so
/// call sites stay `GearTheme.accent` — the lookup goes through
/// ThemeStore, so reading one inside a view's body both picks up the
/// current colourway and registers that view for the next change.
///
/// Views that paint inside a `Canvas` closure take a `GearPalette` as a
/// stored property instead (the closure runs after body evaluation, so a
/// read in there would never be observed).
@MainActor
enum GearTheme {
    static var current: GearPalette { ThemeStore.shared.palette }

    static var chassisTop: Color { current.chassisTop }
    static var chassisBottom: Color { current.chassisBottom }
    static var paintTop: Color { current.paintTop }
    static var paintBottom: Color { current.paintBottom }
    static var panelFill: Color { current.panelFill }
    static var panelEdgeLight: Color { current.panelEdgeLight }
    static var panelEdgeDark: Color { current.panelEdgeDark }
    static var metalLight: Color { current.metalLight }
    static var metalMid: Color { current.metalMid }
    static var metalDark: Color { current.metalDark }
    static var bakeliteLight: Color { current.bakeliteLight }
    static var bakeliteDark: Color { current.bakeliteDark }
    static var accent: Color { current.accent }
    static var accentDim: Color { current.accentDim }
    static var textLight: Color { current.textLight }
    static var textMuted: Color { current.textMuted }
    static var ledBackground: Color { current.ledBackground }
    static var ledText: Color { current.ledText }
    static var lampRed: Color { current.lampRed }
    static var lampRedDim: Color { current.lampRedDim }
    static var meterGreen: Color { current.meterGreen }
    static var meterAmber: Color { current.meterAmber }
    static var meterRed: Color { current.meterRed }
    static var meterOff: Color { current.meterOff }
}
