import SwiftUI

struct JJMidnightMainView: View {
    var parameterTree: ObservableAUParameterGroup
    var audioUnit: JJMidnightAudioUnit?

    @State private var isBypassed = false
    @State private var showPaywall = false
    @Bindable private var entitlement = EntitlementService.shared

    // Rack-panel geometry — matches the desktop design's headerHeight/
    // earWidth/footerStripHeight constants, scaled down for a
    // host-embedded extension view.
    private let earWidth: CGFloat = 18
    private let footerHeight: CGFloat = 12
    private let contentGutter: CGFloat = 12
    // Four sections of three knobs need three breakpoints. Four across only
    // fits on an iPad-width host; a 2x2 grid is the shape that works for most
    // of the range; a phone stacks. Comp carries a gain-reduction bar under
    // its knobs, so it runs a little taller than the other three and the
    // equal-height plates leave them slightly short — a bar's worth, which is
    // what a needle in the same place would have cost several times over.
    private let gridThreshold: CGFloat = 520
    private let wideThreshold: CGFloat = 900

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ChassisBackground(theme: GearTheme.current)

                HStack(spacing: 0) {
                    RackEar(theme: GearTheme.current).frame(width: earWidth)
                    Spacer(minLength: 0)
                    RackEar(theme: GearTheme.current).frame(width: earWidth)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    // Spacers above/below the panel content, plus a
                    // minHeight matching the full container: when the host
                    // gives more height than the panel needs, this centres
                    // it in the chassis rather than pinning it to the top
                    // and leaving a dead expanse of chassis below; when the
                    // host is short, the spacers collapse and it scrolls.
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        panelContent(width: geo.size.width)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                FooterRivetStrip(theme: GearTheme.current)
                    .frame(width: geo.size.width, height: footerHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            isBypassed = audioUnit?.shouldBypassEffect ?? false
            Task {
                await entitlement.refresh()
                audioUnit?.applyLicenseFromStore()
            }
        }
        .onChange(of: isBypassed) { _, newValue in
            audioUnit?.shouldBypassEffect = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .jjMidnightAccessChanged)) { _ in
            audioUnit?.applyLicenseFromStore()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(entitlement: entitlement, showsCloseWhenAllowed: true) {
                showPaywall = false
            }
            .presentationDetents([.large])
        }
    }

    // The panel's actual content — header, divider, sections, footer — at
    // its natural size for a given width, with no outer chassis/scrolling
    // wrapper. `body` embeds this inside the always-fills GeometryReader/
    // ScrollView above; `AudioUnitViewController` also hosts it standalone
    // to *measure* the height a host should be asked for via
    // `preferredContentSize`, so that initial request reflects this view's
    // real layout instead of a hand-tuned guess that drifts out of sync
    // with it.
    func panelContent(width: CGFloat) -> some View {
        let sideInset = earWidth + contentGutter
        return VStack(spacing: 0) {
            header
                .padding(.horizontal, sideInset)
                .padding(.top, 10)
                .padding(.bottom, 8)

            // Engraved groove: a scored line with the light catching its
            // lower lip, rather than a flat hairline.
            VStack(spacing: 0) {
                Rectangle().fill(.black.opacity(0.45)).frame(height: 1)
                Rectangle().fill(GearTheme.panelEdgeLight.opacity(0.35)).frame(height: 1)
            }
            .padding(.horizontal, sideInset)

            // Above the four blocks, not under them. Input is the first
            // thing to set on a live rig — every threshold downstream is
            // absolute, so nothing below is worth judging until this is
            // right — and at the bottom of a scrolling panel it was off
            // screen at the moment it mattered.
            masterStrip(width: width)
                .padding(.horizontal, sideInset)
                .padding(.top, 12)

            sectionsLayout(width: width)
                .environment(\.knobDiameter, knobDiameter(forPanelWidth: width))
                .padding(.horizontal, sideInset)
                .padding(.top, 10)
                .padding(.bottom, 8)

            versionFooter
                .padding(.horizontal, sideInset)
                .padding(.bottom, footerHeight + 6)
        }
        .frame(width: width)
    }

    // MARK: - Header

    // One row: wordmark (+ category strapline), preset selector, IN/OUT
    // meters, power switch. The preset selector is the only flexible item.
    // The longer "VINTAGE CLEAN / LOW-GAIN CHAIN" line stays on the model
    // plate at the foot — short category up here, tone description down there.
    private var header: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                FinishSelector(theme: GearTheme.current)
                    .frame(width: 26, height: 26)
                    .padding(.trailing, 5)
                    .layoutPriority(1)

                wordmark
                    .layoutPriority(1)

                PresetBar(audioUnit: audioUnit)
                    .frame(minWidth: 96, maxWidth: 340)

                LevelMeterView(audioUnit: audioUnit)
                    .layoutPriority(1)

                BypassToggle(isBypassed: $isBypassed)
                    .frame(width: 22, height: 38)
                    .layoutPriority(1)
            }

            if showsAccessBanner, entitlement.accessState.bannerText != nil {
                AccessBanner(state: entitlement.accessState) {
                    showPaywall = true
                }
            }
        }
    }

    // Category under the name only — not a second full-width header row —
    // so the preset window and meters keep their single-line slot.
    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("j.j.midnight")
                .font(.custom("Georgia-BoldItalic", size: 18))
                .foregroundStyle(GearTheme.textLight)
                .shadow(color: .black.opacity(0.75), radius: 0, x: 0, y: 1.5)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                .lineLimit(1)
                // Keeps its full size while there is room and only
                // compresses on a narrow phone, so the preset window
                // beside it never has to truncate first.
                .minimumScaleFactor(0.6)

            Text("ELECTRIC GUITAR")
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .tracking(1.1)
                // Same cream silkscreen as the wordmark — textMuted sits too
                // close to the Tweed lacquer and washes out there.
                .foregroundStyle(GearTheme.textLight.opacity(0.88))
                .shadow(color: .black.opacity(0.75), radius: 0, x: 0, y: 1)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("j.j.midnight, electric guitar effect")
    }

    // The companion app puts its own trial banner in the chrome above the
    // panel, so a second copy inside the panel header just says the same
    // thing twice. A host has no such chrome, so there the panel keeps it —
    // it is the only way into the paywall from inside a DAW.
    private var showsAccessBanner: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }

    private var versionFooter: some View {
        ModelPlate(text: "MODEL JJM-1  ·  VINTAGE CLEAN / LOW-GAIN CHAIN  ·  \(appVersionString)")
            .frame(maxWidth: .infinity)
    }

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }


    // MARK: - Sections (Comp / Drive / Wobble / Space)

    private let columnSpacing: CGFloat = 20

    /// The knob size the three-in-a-row sections draw at. Comp's column runs
    /// at its own smaller fixed size (`stackedKnobDiameter`), so it is not
    /// part of this.
    private func knobDiameter(forPanelWidth width: CGFloat) -> CGFloat {
        let content = width - (earWidth + contentGutter) * 2
        let columns = CGFloat(sectionColumns(forPanelWidth: width))
        let columnWidth = (content - columnSpacing * (columns - 1)) / columns
        let slot = (columnWidth - plateInset * 2 - knobRowSpacing * 2) / 3
        return min(96, max(42, slot))
    }

    /// How many sections sit side by side at this width.
    private func sectionColumns(forPanelWidth width: CGFloat) -> Int {
        if width >= wideThreshold { return 4 }
        if width >= gridThreshold { return 2 }
        return 1
    }

    @ViewBuilder
    private func sectionsLayout(width: CGFloat) -> some View {
        switch sectionColumns(forPanelWidth: width) {
        case 4:
            // fixedSize resolves the row to its tallest column's ideal
            // height, and maxHeight lets the shorter plates stretch to it —
            // four modules cut to the same height, as they would be in a
            // real rack.
            HStack(alignment: .top, spacing: columnSpacing) {
                plate(stretch: true) { compColumn }
                plate(stretch: true) { driveColumn }
                plate(stretch: true) { wobbleColumn }
                plate(stretch: true) { spaceColumn }
            }
            .fixedSize(horizontal: false, vertical: true)
        case 2:
            // Two rows of two, each levelled the same way. Signal order still
            // reads left-to-right, top-to-bottom.
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    plate(stretch: true) { compColumn }
                    plate(stretch: true) { driveColumn }
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: columnSpacing) {
                    plate(stretch: true) { wobbleColumn }
                    plate(stretch: true) { spaceColumn }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        default:
            VStack(spacing: 14) {
                plate { compColumn }
                plate { driveColumn }
                plate { wobbleColumn }
                plate { spaceColumn }
            }
        }
    }

    // Each section rides on its own sub-plate, screwed onto the front
    // panel — so the sections read as separate modules the way they do on
    // the reference hardware, and the hairline dividers the old layout
    // needed are no longer necessary.
    private let plateInset: CGFloat = 17

    private func plate<Content: View>(stretch: Bool = false,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, plateInset)
            .padding(.top, 11)
            .padding(.bottom, 15)
            // The stretch has to happen inside the background, or the plate
            // would draw at its content height and merely sit centred in a
            // taller slot.
            .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .top)
            .background(PanelPlate(theme: GearTheme.current))
    }

    private func sectionHeader<Accessory: View>(
        _ title: String,
        enabled: ObservableAUParameter,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        HStack(spacing: 7) {
            JewelLamp(isOn: enabled.boolValue, color: GearTheme.accent, theme: GearTheme.current)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(2.0)
                .foregroundStyle(enabled.boolValue ? GearTheme.textLight : GearTheme.textMuted)
                .shadow(color: .black.opacity(0.7), radius: 0, x: 0, y: 1)
                .lineLimit(1)
            accessory()
            Spacer(minLength: 4)
            LedToggle(param: enabled)
                .frame(width: 26, height: 40)
        }
    }

    private let knobRowSpacing: CGFloat = 8


    private func knob(_ param: ObservableAUParameter, _ caption: String, skew: Float = 1,
                       symmetric: Bool = false, help: String? = nil,
                       detents: Int? = nil) -> some View {
        KnobView(param: param, caption: caption, skew: skew, symmetric: symmetric,
                 helpText: help, detents: detents)
            .frame(maxWidth: .infinity)
    }

    /// A small labelled lamp for a secondary switch inside a section header —
    /// the same lamp-and-silkscreen idiom as `sectionHeader`, at the size a
    /// second switch can have without crowding the bat switch beside it.
    private func modeTab(_ title: String, param: ObservableAUParameter) -> some View {
        Button {
            param.value = param.boolValue ? 0 : 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
    }

    /// Wraps a section's knob row in the shared enable/disable treatment.
    /// `.allowsHitTesting` blocks all touch input — drag, tap, and
    /// long-press-for-help — not just the Button-based controls; `.disabled()`
    /// alone would not stop KnobView's raw `.gesture()`-based recognisers.
    @ViewBuilder
    private func sectionBody<Content: View>(enabled: ObservableAUParameter,
                                            @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .opacity(enabled.boolValue ? 1 : 0.42)
            .allowsHitTesting(enabled.boolValue)
    }

    // Each section binds its enable parameter to a concretely-typed local
    // rather than chaining `parameterTree.comp.compOn.boolValue` inline —
    // @dynamicMemberLookup here only resolves reliably one hop at a time
    // (see ObservableAUParameter.swift).

    private var compColumn: some View {
        let compOn: ObservableAUParameter = parameterTree.comp.compOn
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("COMP", enabled: compOn)

            sectionBody(enabled: compOn) {
                // A row of three at the same size as every other section —
                // the knobs are the same class of control, so they are the
                // same size — with the meter alongside, in the block whose
                // behaviour it reports rather than at the far end of the
                // panel. Comp ends up taller than the others because the
                // meter is taller than a knob, which reads as the hero block
                // rather than as a mistake.
                VStack(spacing: 10) {
                    HStack(spacing: knobRowSpacing) {
                        knob(parameterTree.comp.compAmount, "COMP",
                             help: "One control for threshold, ratio and make-up together, the way an optical box works. Up is more squash, not more level.")
                        knob(parameterTree.comp.compAttack, "ATTACK", skew: 0.5,
                             help: "How fast the cell grabs. Slow by design — a fast attack here would flatten the pick and take the life out of it.")
                        knob(parameterTree.comp.compRelease, "RELEASE", skew: 0.5,
                             help: "The fast end of the release. Deeper gain reduction recovers slower on its own, as a real opto cell does.")
                    }
                    // Under its own knobs: the bar reports what they are
                    // doing, and it is flat enough to sit here without making
                    // this block a different shape from the other three.
                    GainReductionMeter(audioUnit: audioUnit)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var driveColumn: some View {
        let driveOn: ObservableAUParameter = parameterTree.drive.driveOn
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DRIVE", enabled: driveOn)

            sectionBody(enabled: driveOn) {
                HStack(spacing: knobRowSpacing) {
                    knob(parameterTree.drive.driveAmount, "DRIVE",
                         help: "Low-gain breakup. The whole range stays between clean and the edge of it; body comes up with it, the way it does on an amp.")
                    knob(parameterTree.drive.driveTone, "TONE", skew: 0.3,
                         help: "Tone rolloff after the clipper. Turn it down for the classic rolled-back tone control.")
                    knob(parameterTree.drive.driveCab, "MIC",
                         help: "Mic position on the 1x12. Up moves off-axis: deeper 3.6 kHz dip, earlier rolloff, darker.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wobbleColumn: some View {
        let wobbleOn: ObservableAUParameter = parameterTree.wobble.wobbleOn
        let wobbleSync: ObservableAUParameter = parameterTree.wobble.wobbleSync
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("WOBBLE", enabled: wobbleOn) {
                modeTab("SYNC", param: wobbleSync)
            }

            sectionBody(enabled: wobbleOn) {
                HStack(spacing: knobRowSpacing) {
                    // One slot, two parameters. Free-running shows Rate in Hz;
                    // synced shows the note division, as a detented selector.
                    // They stay separate parameters so each means one thing to
                    // a host's automation.
                    if wobbleSync.boolValue {
                        knob(parameterTree.wobble.wobbleDivision, "DIV",
                             help: "Note division, locked to the host tempo. Falls back to the Rate knob in a host that reports no tempo — the companion app has no transport at all.",
                             detents: JJMidnightWobbleDivisions.names.count)
                    } else {
                        knob(parameterTree.wobble.wobbleRate, "RATE", skew: 0.4,
                             help: "Free-running tremolo speed. Turn SYNC on to lock it to the host tempo instead.")
                    }
                    knob(parameterTree.wobble.wobbleDepth, "DEPTH",
                         help: "Tremolo depth. The gain peaks at unity, so turning this up never makes the track louder.")
                    knob(parameterTree.wobble.wobbleShape, "SHAPE",
                         help: "Morphs the LFO from a rounded sine towards a chop. Down is blackface-ish sway, up is harder optical chop.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spaceColumn: some View {
        let spaceOn: ObservableAUParameter = parameterTree.space.spaceOn
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SPACE", enabled: spaceOn)

            sectionBody(enabled: spaceOn) {
                HStack(spacing: knobRowSpacing) {
                    knob(parameterTree.space.slapTime, "SLAP", skew: 0.4,
                         help: "Slapback time. One repeat, no feedback. 80–120 ms is the useful window; longer gets you a tape echo.")
                    knob(parameterTree.space.slapMix, "ECHO",
                         help: "Level of the single repeat.")
                    knob(parameterTree.space.springMix, "SPRING",
                         help: "Spring tank level. The tank lengthens as you turn it up, the way a real amp's one control does.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Master

    // Input, Mix and Output live on their own strip rather than inside one of
    // the blocks: they act on the whole chain, and a fifth section plate
    // would have implied a fifth stage in the signal path. Gain reduction is
    // not here — it belongs in Comp, next to the knobs that cause it. What is
    // here is level in and level out, both properties of the whole chain.
    //
    // Aligned to the top, because the input knob carries a meter under it and
    // the other two do not: centring would float MIX and OUTPUT half a meter
    // down the plate and break the line their captions share.
    @ViewBuilder
    private func masterStrip(width: CGFloat) -> some View {
        Group {
            if width >= gridThreshold {
                HStack(alignment: .top, spacing: 20) {
                    meterStack(stretched: true)
                    Spacer(minLength: 8)
                    masterKnobs
                }
                // Resolves the row to the knobs' ideal height, which is what
                // the meter column then stretches into to put Output on the
                // bottom edge. Without it the column sizes to its own content
                // and both meters bunch at the top.
                .fixedSize(horizontal: false, vertical: true)
            } else {
                // Three knobs plus a scale-labelled stereo meter do not fit a
                // phone in one row: the meter collapses to about a hundred
                // points, its caption wraps to three lines and the dB labels
                // print on top of each other. Stacked, both get the full
                // plate width. Knobs first, because the meter below the INPUT
                // knob is the one being read while the trim is set.
                VStack(spacing: 14) {
                    masterKnobs
                    meterStack(stretched: false)
                }
            }
        }
        .padding(.horizontal, plateInset)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(PanelPlate(theme: GearTheme.current))
    }

    /// Both meters as one column, in signal order: what arrives on top, what
    /// leaves underneath, drawn to the same width and the same scale so the
    /// two bars can be read against each other.
    ///
    /// Input is pinned to the top of the column and output to the bottom, so
    /// on a wide panel the pair brackets the knob row instead of floating in
    /// the middle of it. Output is the one that needs watching for a clip —
    /// this chain can add a lot of level by itself, the compressor's make-up
    /// reaches +13 dB and Drive adds more — and the bottom edge is where the
    /// eye returns to.
    /// `stretched` only in the wide layout, where the column stands beside the
    /// knobs and has their height to fill. Stacked under them on a phone there
    /// is no height to divide, and stretching there would pull the two meters
    /// to opposite ends of a plate that has grown to make room for the gap.
    private func meterStack(stretched: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            InputMeter(audioUnit: audioUnit)
            if stretched {
                Spacer(minLength: 0)
            }
            OutputMeter(audioUnit: audioUnit)
        }
        .frame(maxWidth: 440,
               maxHeight: stretched ? .infinity : nil,
               alignment: .leading)
        .padding(.top, 6)
    }

    private var masterKnobs: some View {
        HStack(alignment: .top, spacing: 20) {
            knob(parameterTree.master.masterInput, "INPUT",
                 help: "Input trim, −12 to +24 dB, before the whole chain. A guitar straight into an interface lands well below the Comp threshold. Turn this up until the INPUT meter sits in the marked band on your loudest playing, and the GR meter will start to move.")
                .frame(maxWidth: 130)
            knob(parameterTree.master.masterMix, "MIX",
                 help: "Dry/wet for the entire chain. Leave it at 100% on a guitar track; pull it back to use this as a parallel colour.")
                .frame(maxWidth: 130)
            knob(parameterTree.master.masterOutput, "OUTPUT", symmetric: true,
                 help: "Output trim, ±12 dB.")
                .frame(maxWidth: 130)
        }
    }
}
