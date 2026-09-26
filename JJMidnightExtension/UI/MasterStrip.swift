import SwiftUI

// Input, Mix and Output live on their own strip rather than inside one of
// the blocks: they act on the whole chain, and a fifth section plate
// would have implied a fifth stage in the signal path. Gain reduction is
// not here — it belongs in Comp, next to the knobs that cause it. What is
// here is level in and level out, both properties of the whole chain.
//
// Aligned to the top, because the input knob carries a meter under it and
// the other two do not: centring would float MIX and OUTPUT half a meter
// down the plate and break the line their captions share.
struct MasterStrip: View {
    let parameterTree: ObservableAUParameterGroup
    let meters: MeterViewModel
    let width: CGFloat

    var body: some View {
        Group {
            if width >= PanelMetrics.gridThreshold {
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
        .padding(.horizontal, PanelMetrics.plateInset)
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
    /// this chain can add a lot of level by itself — the compressor's make-up
    /// reaches +13 dB — and the bottom edge is where the
    /// eye returns to.
    /// `stretched` only in the wide layout, where the column stands beside the
    /// knobs and has their height to fill. Stacked under them on a phone there
    /// is no height to divide, and stretching there would pull the two meters
    /// to opposite ends of a plate that has grown to make room for the gap.
    private func meterStack(stretched: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            InputMeter(meters: meters)
            if stretched {
                Spacer(minLength: 0)
            }
            OutputMeter(meters: meters)
        }
        .frame(maxWidth: 440,
               maxHeight: stretched ? .infinity : nil,
               alignment: .leading)
        .padding(.top, 6)
    }

    private var masterKnobs: some View {
        HStack(alignment: .top, spacing: 20) {
            SectionKnob(param: parameterTree[.masterInput], caption: "INPUT",
                        help: "Input trim, −12 to +24 dB, before the whole chain. A guitar straight into an interface lands well below the Comp threshold. Turn this up until the INPUT meter sits in the marked band on your loudest playing, and the GR meter will start to move.")
                .frame(maxWidth: 130)
            SectionKnob(param: parameterTree[.masterMix], caption: "MIX",
                        help: "Dry/wet for the entire chain. Leave it at 100% on a guitar track; pull it back to use this as a parallel colour.")
                .frame(maxWidth: 130)
            SectionKnob(param: parameterTree[.masterOutput], caption: "OUTPUT", symmetric: true,
                        help: "Output trim, ±12 dB.")
                .frame(maxWidth: 130)
        }
    }
}
