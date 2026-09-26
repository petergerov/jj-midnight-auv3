import SwiftUI

struct JJMidnightMainView: View {
    var parameterTree: ObservableAUParameterGroup
    @Bindable var model: MainPanelViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ChassisBackground(theme: GearTheme.current)

                HStack(spacing: 0) {
                    RackEar(theme: GearTheme.current).frame(width: PanelMetrics.earWidth)
                    Spacer(minLength: 0)
                    RackEar(theme: GearTheme.current).frame(width: PanelMetrics.earWidth)
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
                    .frame(width: geo.size.width, height: PanelMetrics.footerHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task {
            await model.panelAppeared()
        }
        .task {
            await model.runDisplayLoop()
        }
        .onChange(of: model.entitlement.accessState) {
            model.syncLicense()
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView(entitlement: model.entitlement, showsCloseWhenAllowed: true) {
                model.showPaywall = false
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
        let sideInset = PanelMetrics.sideInset
        return VStack(spacing: 0) {
            PanelHeader(model: model)
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
            MasterStrip(parameterTree: parameterTree, meters: model.meters, width: width)
                .padding(.horizontal, sideInset)
                .padding(.top, 12)

            sectionsLayout(width: width)
                .environment(\.knobDiameter, PanelMetrics.knobDiameter(forPanelWidth: width))
                .padding(.horizontal, sideInset)
                .padding(.top, 10)
                .padding(.bottom, 8)

            versionFooter
                .padding(.horizontal, sideInset)
                .padding(.bottom, PanelMetrics.footerHeight + 6)
        }
        .frame(width: width)
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

    @ViewBuilder
    private func sectionsLayout(width: CGFloat) -> some View {
        switch PanelMetrics.sectionColumns(forPanelWidth: width) {
        case 4:
            // fixedSize resolves the row to its tallest column's ideal
            // height, and maxHeight lets the shorter plates stretch to it —
            // four modules cut to the same height, as they would be in a
            // real rack.
            HStack(alignment: .top, spacing: PanelMetrics.columnSpacing) {
                SectionPlate(stretch: true) { CompSection(parameterTree: parameterTree, meters: model.meters) }
                SectionPlate(stretch: true) { DriveSection(parameterTree: parameterTree) }
                SectionPlate(stretch: true) { WobbleSection(parameterTree: parameterTree) }
                SectionPlate(stretch: true) { SpaceSection(parameterTree: parameterTree) }
            }
            .fixedSize(horizontal: false, vertical: true)
        case 2:
            // Two rows of two, each levelled the same way. Signal order still
            // reads left-to-right, top-to-bottom.
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: PanelMetrics.columnSpacing) {
                    SectionPlate(stretch: true) { CompSection(parameterTree: parameterTree, meters: model.meters) }
                    SectionPlate(stretch: true) { DriveSection(parameterTree: parameterTree) }
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: PanelMetrics.columnSpacing) {
                    SectionPlate(stretch: true) { WobbleSection(parameterTree: parameterTree) }
                    SectionPlate(stretch: true) { SpaceSection(parameterTree: parameterTree) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        default:
            VStack(spacing: 14) {
                SectionPlate { CompSection(parameterTree: parameterTree, meters: model.meters) }
                SectionPlate { DriveSection(parameterTree: parameterTree) }
                SectionPlate { WobbleSection(parameterTree: parameterTree) }
                SectionPlate { SpaceSection(parameterTree: parameterTree) }
            }
        }
    }
}
