import SwiftUI

// The four signal-chain blocks — Comp, Drive, Wobble, Space — and the chrome
// they share. Each block is its own view so a knob turning in one does not
// re-evaluate the other three.

/// Rack-panel geometry — matches the desktop design's headerHeight/
/// earWidth/footerStripHeight constants, scaled down for a
/// host-embedded extension view.
enum PanelMetrics {
    static let earWidth: CGFloat = 18
    static let footerHeight: CGFloat = 12
    static let contentGutter: CGFloat = 12
    static var sideInset: CGFloat { earWidth + contentGutter }

    /// Four sections of three knobs need three breakpoints. Four across only
    /// fits on an iPad-width host; a 2x2 grid is the shape that works for most
    /// of the range; a phone stacks. Comp carries a gain-reduction bar under
    /// its knobs, so it runs a little taller than the other three and the
    /// equal-height plates leave them slightly short — a bar's worth, which is
    /// what a needle in the same place would have cost several times over.
    static let gridThreshold: CGFloat = 520
    static let wideThreshold: CGFloat = 900

    static let columnSpacing: CGFloat = 20

    /// Each section rides on its own sub-plate, screwed onto the front
    /// panel — so the sections read as separate modules the way they do on
    /// the reference hardware, and the hairline dividers the old layout
    /// needed are no longer necessary.
    static let plateInset: CGFloat = 17

    static let knobRowSpacing: CGFloat = 8

    /// The knob size the three-in-a-row sections draw at. Comp's column runs
    /// at its own smaller fixed size (`stackedKnobDiameter`), so it is not
    /// part of this.
    static func knobDiameter(forPanelWidth width: CGFloat) -> CGFloat {
        let content = width - sideInset * 2
        let columns = CGFloat(sectionColumns(forPanelWidth: width))
        let columnWidth = (content - columnSpacing * (columns - 1)) / columns
        let slot = (columnWidth - plateInset * 2 - knobRowSpacing * 2) / 3
        return min(96, max(42, slot))
    }

    /// How many sections sit side by side at this width.
    static func sectionColumns(forPanelWidth width: CGFloat) -> Int {
        if width >= wideThreshold { return 4 }
        if width >= gridThreshold { return 2 }
        return 1
    }
}

// MARK: - Section chrome

/// The sub-plate a section rides on. `stretch` lets it fill a row whose
/// height was set by a taller neighbour.
struct SectionPlate<Content: View>: View {
    var stretch = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, PanelMetrics.plateInset)
            .padding(.top, 11)
            .padding(.bottom, 15)
            // The stretch has to happen inside the background, or the plate
            // would draw at its content height and merely sit centred in a
            // taller slot.
            .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .top)
            .background(PanelPlate(theme: GearTheme.current))
    }
}

/// Jewel lamp, silkscreened title, optional accessory, bat switch.
struct SectionHeader<Accessory: View>: View {
    let title: String
    let enabled: ObservableAUParameter
    let accessory: Accessory

    init(_ title: String, enabled: ObservableAUParameter,
         @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.enabled = enabled
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 7) {
            JewelLamp(isOn: enabled.boolValue, color: GearTheme.accent, theme: GearTheme.current)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(2.0)
                .foregroundStyle(enabled.boolValue ? GearTheme.textLight : GearTheme.textMuted)
                .shadow(color: .black.opacity(0.7), radius: 0, x: 0, y: 1)
                .lineLimit(1)
            accessory
            Spacer(minLength: 4)
            LedToggle(param: enabled)
                .frame(width: 26, height: 40)
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String, enabled: ObservableAUParameter) {
        self.init(title, enabled: enabled) { EmptyView() }
    }
}

/// Wraps a section's knob row in the shared enable/disable treatment.
/// `.allowsHitTesting` blocks all touch input — drag, tap, and
/// long-press-for-help — not just the Button-based controls; `.disabled()`
/// alone would not stop KnobView's raw `.gesture()`-based recognisers.
struct SectionBody<Content: View>: View {
    let enabled: ObservableAUParameter
    let content: Content

    init(enabled: ObservableAUParameter, @ViewBuilder _ content: () -> Content) {
        self.enabled = enabled
        self.content = content()
    }

    var body: some View {
        content
            .opacity(enabled.boolValue ? 1 : 0.42)
            .allowsHitTesting(enabled.boolValue)
    }
}

/// A knob that takes an equal share of its row.
struct SectionKnob: View {
    let param: ObservableAUParameter
    let caption: String
    var skew: Float = 1
    var symmetric = false
    var help: String?
    var detents: Int?

    var body: some View {
        KnobView(param: param, caption: caption, skew: skew, symmetric: symmetric,
                 helpText: help, detents: detents)
            .frame(maxWidth: .infinity)
    }
}

/// A small labelled lamp for a secondary switch inside a section header —
/// the same lamp-and-silkscreen idiom as `SectionHeader`, at the size a
/// second switch can have without crowding the bat switch beside it.
struct ModeTab: View {
    let title: String
    let param: ObservableAUParameter
    // Counts taps, so the haptic answers the player's hand only — never a
    // host automating the same parameter.
    @State private var taps = 0

    var body: some View {
        Button {
            param.value = param.boolValue ? 0 : 1
            taps += 1
        } label: {
            HStack(spacing: 5) {
                JewelLamp(isOn: param.boolValue, color: GearTheme.accent, theme: GearTheme.current)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(param.boolValue ? GearTheme.textLight : GearTheme.textMuted)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(GearTheme.chassisBottom.opacity(0.55))
                    .overlay(Capsule().stroke(.black.opacity(0.5), lineWidth: 1))
            )
            // The pill is the target, not the lamp and lettering inside it.
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) mode")
        .accessibilityValue(param.boolValue ? "On" : "Off")
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

// MARK: - Sections

struct CompSection: View {
    let parameterTree: ObservableAUParameterGroup
    let meters: MeterViewModel

    var body: some View {
        let compOn = parameterTree[.compOn]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("COMP", enabled: compOn)

            SectionBody(enabled: compOn) {
                // A row of three at the same size as every other section —
                // the knobs are the same class of control, so they are the
                // same size — with the meter alongside, in the block whose
                // behaviour it reports rather than at the far end of the
                // panel. Comp ends up taller than the others because the
                // meter is taller than a knob, which reads as the hero block
                // rather than as a mistake.
                VStack(spacing: 10) {
                    HStack(spacing: PanelMetrics.knobRowSpacing) {
                        SectionKnob(param: parameterTree[.compAmount], caption: "COMP",
                                    help: "One control for threshold, ratio and make-up together, the way an optical box works. Up is more squash, not more level.")
                        SectionKnob(param: parameterTree[.compAttack], caption: "ATTACK", skew: 0.5,
                                    help: "How fast the cell grabs. Slow by design — a fast attack here would flatten the pick and take the life out of it.")
                        SectionKnob(param: parameterTree[.compRelease], caption: "RELEASE", skew: 0.5,
                                    help: "The fast end of the release. Deeper gain reduction recovers slower on its own, as a real opto cell does.")
                    }
                    // Under its own knobs: the bar reports what they are
                    // doing, and it is flat enough to sit here without making
                    // this block a different shape from the other three.
                    GainReductionMeter(meters: meters)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DriveSection: View {
    let parameterTree: ObservableAUParameterGroup

    var body: some View {
        let driveOn = parameterTree[.driveOn]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("DRIVE", enabled: driveOn)

            SectionBody(enabled: driveOn) {
                HStack(spacing: PanelMetrics.knobRowSpacing) {
                    SectionKnob(param: parameterTree[.driveAmount], caption: "DRIVE",
                                help: "Low-gain breakup. The whole range stays between clean and the edge of it; body comes up with it. Level stays put — the knob changes character, not volume.")
                    SectionKnob(param: parameterTree[.driveTone], caption: "TONE", skew: 0.3,
                                help: "Tone rolloff after the clipper. Turn it down for the classic rolled-back tone control.")
                    SectionKnob(param: parameterTree[.driveCab], caption: "MIC",
                                help: "Mic position on the 1x12. Up moves off-axis: deeper 3.6 kHz dip, earlier rolloff, darker.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WobbleSection: View {
    let parameterTree: ObservableAUParameterGroup

    var body: some View {
        let wobbleOn = parameterTree[.wobbleOn]
        let wobbleSync = parameterTree[.wobbleSync]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("WOBBLE", enabled: wobbleOn) {
                ModeTab(title: "SYNC", param: wobbleSync)
            }

            SectionBody(enabled: wobbleOn) {
                HStack(spacing: PanelMetrics.knobRowSpacing) {
                    // One slot, two parameters. Free-running shows Rate in Hz;
                    // synced shows the note division, as a detented selector.
                    // They stay separate parameters so each means one thing to
                    // a host's automation.
                    if wobbleSync.boolValue {
                        SectionKnob(param: parameterTree[.wobbleDivision], caption: "DIV",
                                    help: "Note division, locked to the host tempo. Falls back to the Rate knob in a host that reports no tempo — the companion app has no transport at all.",
                                    detents: JJMidnightWobbleDivisions.names.count)
                    } else {
                        SectionKnob(param: parameterTree[.wobbleRate], caption: "RATE", skew: 0.4,
                                    help: "Free-running tremolo speed. Turn SYNC on to lock it to the host tempo instead.")
                    }
                    SectionKnob(param: parameterTree[.wobbleDepth], caption: "DEPTH",
                                help: "Tremolo depth. The gain peaks at unity, so turning this up never makes the track louder.")
                    SectionKnob(param: parameterTree[.wobbleShape], caption: "SHAPE",
                                help: "Morphs the LFO from a rounded sine towards a chop. Down is blackface-ish sway, up is harder optical chop.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SpaceSection: View {
    let parameterTree: ObservableAUParameterGroup

    var body: some View {
        let spaceOn = parameterTree[.spaceOn]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("SPACE", enabled: spaceOn)

            SectionBody(enabled: spaceOn) {
                HStack(spacing: PanelMetrics.knobRowSpacing) {
                    SectionKnob(param: parameterTree[.slapTime], caption: "SLAP", skew: 0.4,
                                help: "Slapback time. One repeat, no feedback. 80–120 ms is the useful window; longer gets you a tape echo.")
                    SectionKnob(param: parameterTree[.slapMix], caption: "ECHO",
                                help: "Level of the single repeat.")
                    SectionKnob(param: parameterTree[.springMix], caption: "SPRING",
                                help: "Spring tank level. The tank lengthens as you turn it up, the way a real amp's one control does.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
