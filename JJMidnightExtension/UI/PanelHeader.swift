import SwiftUI

// One row: wordmark (+ category strapline), preset selector, IN/OUT
// meters, power switch. The preset selector is the only flexible item.
// The longer "VINTAGE CLEAN / LOW-GAIN CHAIN" line stays on the model
// plate at the foot — short category up here, tone description down there.
struct PanelHeader: View {
    @Bindable var model: MainPanelViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                FinishSelector(theme: GearTheme.current)
                    .frame(width: 26, height: 26)
                    .padding(.trailing, 5)
                    .layoutPriority(1)

                wordmark
                    .layoutPriority(1)

                PresetBar(model: model.presets)
                    .frame(minWidth: 96, maxWidth: 340)

                LevelMeterView(meters: model.meters)
                    .layoutPriority(1)

                BypassToggle(isBypassed: $model.isBypassed)
                    .frame(width: 22, height: 38)
                    .layoutPriority(1)
            }

            if let state = model.accessBannerState {
                AccessBanner(state: state) {
                    model.showPaywall = true
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
}
