import SwiftUI
import AudioToolbox
import UIKit

/// Max knob diameter for the whole panel, computed once from the panel
/// width (see JJMidnightMainView.knobDiameter(forPanelWidth:)) and read by
/// every KnobView. Warmth lays its knobs out two per row rather than three,
/// so its slots are wider; without a shared cap its knobs would draw
/// visibly larger than Shift's and Vibrato's.
private struct KnobDiameterKey: EnvironmentKey {
    static let defaultValue: CGFloat = 96
}

extension EnvironmentValues {
    var knobDiameter: CGFloat {
        get { self[KnobDiameterKey.self] }
        set { self[KnobDiameterKey.self] = newValue }
    }
}

struct KnobView: View {
    @Bindable var param: ObservableAUParameter
    var caption: String
    var skew: Float = 1
    var symmetric: Bool = false
    var helpText: String? = nil
    /// When set, the knob snaps to this many evenly spaced positions instead
    /// of turning continuously — a rotary selector with detents rather than a
    /// pot. Used by the tempo-sync division knob.
    var detents: Int? = nil
    var linkedPeer: ObservableAUParameter? = nil
    var linkEnabled: Bool = false

    @State private var dragging = false
    @State private var startNormalized: Float = 0
    @State private var peerStart: Float = 0
    @State private var showValueEditor = false
    @State private var typedValue = ""
    @State private var showHelp = false
    @Environment(\.knobDiameter) private var knobDiameter

    private var range: SkewedRange {
        SkewedRange(min: param.min, max: param.max, skew: skew, symmetric: symmetric)
    }

    private var normalized: Float {
        range.toNormalized(param.value)
    }

    private var readout: String {
        JJMidnightAudioUnit.format(address: param.address, value: param.value)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(caption)
                .font(.system(size: 10, weight: .heavy, design: .default))
                .tracking(1.4)
                .foregroundStyle(GearTheme.textLight.opacity(0.92))
                .shadow(color: .black.opacity(0.65), radius: 0, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minHeight: 16)
                .contentShape(Rectangle())
                .onLongPressGesture {
                    if helpText != nil {
                        showHelp = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }

            AnalogKnob(normalized: normalized, accent: GearTheme.accent, theme: GearTheme.current)
                .aspectRatio(1, contentMode: .fit)
                // Capped so a host that hands us far more space than we
                // asked for (or ignores preferredContentSize entirely)
                // doesn't blow the knobs up to an absurd size — a real
                // hardware knob doesn't grow just because its rack panel
                // has more headroom. The cap is shared panel-wide so a row
                // of two knobs draws them at the same size as a row of three.
                .frame(minWidth: 44, maxWidth: knobDiameter, minHeight: 44, maxHeight: knobDiameter)
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(TapGesture(count: 2).onEnded(resetToDefault))

            Button {
                typedValue = String(format: "%g", param.value)
                showValueEditor = true
            } label: {
                Text(readout)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GearTheme.ledText)
                    .shadow(color: GearTheme.ledText.opacity(0.75), radius: 3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(minHeight: 26)
                    .background(LedWindow())
                    // Same reason as PresetBar: without this only the digits
                    // themselves accept a tap, not the window around them.
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
        .accessibilityValue(readout)
        .accessibilityHint(helpText ?? "Double-tap to reset. Drag vertically for coarse, horizontally for fine.")
        .accessibilityAdjustableAction { direction in
            let step: Float = 0.02
            let next = (normalized + (direction == .increment ? step : -step)).clamped01()
            applyNormalized(next, fromStart: normalized, peerStart: linkedPeer?.value ?? 0)
        }
        .sheet(isPresented: $showValueEditor) {
            valueEditor
        }
        .alert(caption, isPresented: $showHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(helpText ?? "")
        }
    }

    private var valueEditor: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Range \(formatBound(param.min)) – \(formatBound(param.max))")
                    .font(.system(size: 13))
                    .foregroundStyle(GearTheme.textMuted)
                TextField("Value", text: $typedValue)
                    .keyboardType(.decimalPad)
                    .padding(10)
                    .background(GearTheme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GearTheme.metalDark, lineWidth: 1)
                    )
                    .foregroundStyle(GearTheme.textLight)
                Spacer()
            }
            .padding(16)
            .background(GearTheme.chassisBottom)
            .navigationTitle(caption)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showValueEditor = false }
                        .foregroundStyle(GearTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") { commitTypedValue() }
                        .foregroundStyle(GearTheme.accent)
                }
            }
        }
        .presentationDetents([.height(200), .medium])
        .tint(GearTheme.accent)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !dragging {
                    dragging = true
                    startNormalized = normalized
                    peerStart = linkedPeer?.value ?? 0
                    param.onEditingChanged(true)
                    linkedPeer?.onEditingChanged(true)
                }
                let vertical = Float(-value.translation.height)
                let horizontal = Float(value.translation.width)
                let fine = abs(horizontal) > abs(vertical) * 1.15
                let delta: Float
                if fine {
                    delta = horizontal / 900.0
                } else {
                    delta = vertical / 220.0
                }
                applyNormalized((startNormalized + delta).clamped01(), fromStart: startNormalized, peerStart: peerStart)
            }
            .onEnded { _ in
                param.onEditingChanged(false)
                linkedPeer?.onEditingChanged(false)
                dragging = false
            }
    }

    private func applyNormalized(_ next: Float, fromStart: Float, peerStart: Float) {
        let newValue = snapped(range.fromNormalized(next))
        let oldValue = range.fromNormalized(fromStart)
        param.value = newValue
        if linkEnabled, let peer = linkedPeer {
            let delta = newValue - oldValue
            peer.value = min(peer.max, max(peer.min, peerStart + delta))
        }
    }

    /// Rounds to the nearest detent when this knob is a selector. Applied in
    /// `applyNormalized`, which is the single funnel for drag and for the
    /// accessibility increment action, so the pointer can never come to rest
    /// between marks.
    private func snapped(_ value: Float) -> Float {
        guard let detents, detents > 1 else { return value }
        let step = (param.max - param.min) / Float(detents - 1)
        guard step > 0 else { return value }
        return param.min + (((value - param.min) / step).rounded() * step)
    }

    private func resetToDefault() {
        param.onEditingChanged(true)
        let old = param.value
        param.value = param.defaultValue
        if linkEnabled, let peer = linkedPeer {
            peer.onEditingChanged(true)
            peer.value = min(peer.max, max(peer.min, peer.value + (param.defaultValue - old)))
            peer.onEditingChanged(false)
        }
        param.onEditingChanged(false)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func commitTypedValue() {
        if let value = JJMidnightAudioUnit.parse(typedValue, address: param.address, min: param.min, max: param.max) {
            param.onEditingChanged(true)
            let old = param.value
            param.value = value
            if linkEnabled, let peer = linkedPeer {
                peer.onEditingChanged(true)
                peer.value = min(peer.max, max(peer.min, peer.value + (value - old)))
                peer.onEditingChanged(false)
            }
            param.onEditingChanged(false)
        }
        showValueEditor = false
    }

    private func formatBound(_ value: AUValue) -> String {
        JJMidnightAudioUnit.format(address: param.address, value: value)
    }
}

/// A black bakelite pointer knob in a chrome collar, sitting inside a
/// cream scale printed on the panel — the knob on most 60s-70s outboard
/// gear (see image/IK-T-Racks-Tape-Echo.jpg). The only concession to the
/// screen is the thin amber arc tracking the printed scale, which reads at
/// a glance where a bare pointer would not.
private struct AnalogKnob: View {
    var normalized: Float
    var accent: Color
    var theme: GearPalette

    private let startAngle = -135.0 * .pi / 180.0
    private let endAngle = 135.0 * .pi / 180.0

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            let diameter = min(rect.width, rect.height)
            let radius = diameter / 2
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let angle = startAngle + Double(normalized) * (endAngle - startAngle)
            let unit = diameter / 78.0 // the design's reference knob size

            func point(_ a: Double, _ r: CGFloat) -> CGPoint {
                CGPoint(x: centre.x + CGFloat(sin(a)) * r, y: centre.y - CGFloat(cos(a)) * r)
            }

            // --- Scale printed on the panel around the knob -------------
            for i in 0..<11 {
                let t = Double(i) / 10.0
                let tickAngle = startAngle + t * (endAngle - startAngle)
                let major = i % 5 == 0
                var tick = Path()
                tick.move(to: point(tickAngle, radius * (major ? 0.80 : 0.86)))
                tick.addLine(to: point(tickAngle, radius * 0.97))
                context.stroke(tick,
                               with: .color(theme.textLight.opacity(major ? 0.9 : 0.55)),
                               lineWidth: (major ? 2.2 : 1.4) * unit)
            }

            // --- Value arc ---------------------------------------------
            let arcRadius = radius * 0.885
            var arc = Path()
            arc.addArc(center: centre, radius: arcRadius,
                       startAngle: .radians(startAngle - .pi / 2),
                       endAngle: .radians(angle - .pi / 2), clockwise: false)
            context.stroke(arc, with: .color(accent.opacity(0.18)), lineWidth: 4.6 * unit)
            context.stroke(arc, with: .color(accent.opacity(0.92)), lineWidth: 2.0 * unit)

            // --- Chrome collar the knob is seated in --------------------
            let collarR = radius * 0.74
            let collarBox = CGRect(x: centre.x - collarR, y: centre.y - collarR,
                                   width: collarR * 2, height: collarR * 2)
            context.fill(Path(ellipseIn: collarBox.offsetBy(dx: 0, dy: 2.6 * unit)),
                         with: .color(.black.opacity(0.45)))
            context.fill(Path(ellipseIn: collarBox), with: .linearGradient(
                Gradient(colors: [theme.metalLight, theme.metalMid,
                                  theme.metalDark, theme.metalMid]),
                startPoint: CGPoint(x: collarBox.minX, y: collarBox.minY),
                endPoint: CGPoint(x: collarBox.maxX, y: collarBox.maxY)))

            // --- Bakelite cap ------------------------------------------
            let capR = collarR * 0.86
            let capBox = CGRect(x: centre.x - capR, y: centre.y - capR,
                                width: capR * 2, height: capR * 2)
            context.fill(Path(ellipseIn: capBox), with: .radialGradient(
                Gradient(colors: [theme.bakeliteLight, theme.bakeliteDark]),
                center: CGPoint(x: centre.x - capR * 0.4, y: centre.y - capR * 0.5),
                startRadius: 0, endRadius: capR * 1.5))
            context.stroke(Path(ellipseIn: capBox), with: .color(.black.opacity(0.7)),
                           lineWidth: 1.2 * unit)

            // Gloss on the moulded top surface.
            let gloss = CGRect(x: centre.x - capR * 0.62, y: centre.y - capR * 0.78,
                               width: capR * 1.05, height: capR * 0.62)
            context.fill(Path(ellipseIn: gloss), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.20), .clear]),
                center: CGPoint(x: gloss.midX, y: gloss.midY),
                startRadius: 0, endRadius: gloss.width * 0.6))

            // --- Pointer, rotating with the value ----------------------
            var rotated = context
            rotated.translateBy(x: centre.x, y: centre.y)
            rotated.rotate(by: .radians(angle))
            rotated.translateBy(x: -centre.x, y: -centre.y)

            let pointerWidth = 3.4 * unit
            let pointer = CGRect(x: centre.x - pointerWidth / 2, y: centre.y - capR * 0.94,
                                 width: pointerWidth, height: capR * 0.94)
            rotated.fill(Path(roundedRect: pointer.offsetBy(dx: 0, dy: 1.2 * unit),
                              cornerRadius: pointerWidth / 2),
                         with: .color(.black.opacity(0.55)))
            rotated.fill(Path(roundedRect: pointer, cornerRadius: pointerWidth / 2),
                         with: .color(theme.textLight))
        }
    }
}

private extension Float {
    func clamped01() -> Float { min(1, max(0, self)) }
}
