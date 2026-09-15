import SwiftUI
import UIKit

/// A chrome bat switch: a mounting nut sunk into the panel and a tapered
/// nickel lever thrown up (on) or down (off), like the toggles on the
/// reference gear in image/. RockerSwitch keeps its old name because both
/// LedToggle (section enable) and BypassToggle (power) draw one.
struct RockerSwitch: View {
    var isOn: Bool
    var theme: GearPalette

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let unit = min(rect.width, rect.height * 0.5)
            let pivot = CGPoint(x: rect.midX, y: rect.midY)

            // Escutcheon: the dark plate the switch body is mounted
            // through, so the lever sits on hardware rather than on paint.
            let plateW = unit * 0.95, plateH = unit * 0.62
            context.fill(Path(ellipseIn: CGRect(x: pivot.x - plateW / 2, y: pivot.y - plateH / 2,
                                                 width: plateW, height: plateH)),
                         with: .radialGradient(
                            Gradient(colors: [theme.metalDark, .black.opacity(0.85)]),
                            center: pivot, startRadius: 0, endRadius: plateW * 0.7))

            // Lever: a tapered nickel blade thrown to the top or the bottom.
            let up = isOn
            let length = rect.height * 0.42
            let tipY = up ? pivot.y - length : pivot.y + length
            let baseHalf = unit * 0.17
            let tipHalf = unit * 0.115

            var blade = Path()
            blade.move(to: CGPoint(x: pivot.x - baseHalf, y: pivot.y))
            blade.addLine(to: CGPoint(x: pivot.x + baseHalf, y: pivot.y))
            blade.addLine(to: CGPoint(x: pivot.x + tipHalf, y: tipY))
            blade.addLine(to: CGPoint(x: pivot.x - tipHalf, y: tipY))
            blade.closeSubpath()

            context.fill(blade.offsetBy(dx: unit * 0.1, dy: 0), with: .color(.black.opacity(0.4)))
            context.fill(blade, with: .linearGradient(
                Gradient(colors: [.black.opacity(0.85), theme.metalLight,
                                  theme.metalMid, .black.opacity(0.8)]),
                startPoint: CGPoint(x: pivot.x - baseHalf, y: pivot.y),
                endPoint: CGPoint(x: pivot.x + baseHalf, y: pivot.y)))

            // Ball tip.
            let ballR = unit * 0.18
            let ball = CGRect(x: pivot.x - ballR, y: tipY - ballR, width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: ball.offsetBy(dx: ballR * 0.25, dy: ballR * 0.15)),
                         with: .color(.black.opacity(0.4)))
            context.fill(Path(ellipseIn: ball), with: .radialGradient(
                Gradient(colors: [theme.metalLight, theme.metalMid, theme.metalDark]),
                center: CGPoint(x: ball.midX - ballR * 0.35, y: ball.midY - ballR * 0.4),
                startRadius: 0, endRadius: ballR * 1.6))

            // Hex mounting nut clamping the body to the panel.
            let nutR = unit * 0.27
            var nut = Path()
            for i in 0..<6 {
                let a = Double(i) / 6.0 * 2 * .pi + .pi / 6
                let p = CGPoint(x: pivot.x + CGFloat(cos(a)) * nutR,
                                y: pivot.y + CGFloat(sin(a)) * nutR * 0.8)
                if i == 0 { nut.move(to: p) } else { nut.addLine(to: p) }
            }
            nut.closeSubpath()
            context.fill(nut, with: .linearGradient(
                Gradient(colors: [theme.metalMid, theme.metalDark]),
                startPoint: CGPoint(x: pivot.x, y: pivot.y - nutR),
                endPoint: CGPoint(x: pivot.x, y: pivot.y + nutR)))
            context.stroke(nut, with: .color(.black.opacity(0.65)), lineWidth: 0.8)

        }
    }
}

struct LedToggle: View {
    @Bindable var param: ObservableAUParameter

    var body: some View {
        Button {
            param.boolValue.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            RockerSwitch(isOn: param.boolValue, theme: GearTheme.current)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(param.displayName)
        .accessibilityValue(param.boolValue ? "On" : "Off")
    }
}

struct BypassToggle: View {
    @Binding var isBypassed: Bool

    var body: some View {
        Button {
            isBypassed.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            // Drawn state is the inverse of the flag — a power switch reads
            // on when the effect is actually processing, i.e. not bypassed.
            VStack(spacing: 2) {
                JewelLamp(isOn: !isBypassed, color: GearTheme.lampRed, theme: GearTheme.current)
                    .frame(width: 10, height: 10)
                RockerSwitch(isOn: !isBypassed, theme: GearTheme.current)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Power")
        .accessibilityValue(isBypassed ? "Off" : "On")
    }
}

/// A small round link/unlink badge sitting in the gap between a pair of
/// knobs (e.g. PITCH L/PITCH R) rather than in a separate row above them —
/// toggles whether dragging one of the pair moves the other by the same
/// amount (see KnobView's linkedPeer/linkEnabled).
struct LinkIconBadge: View {
    @Binding var isOn: Bool
    var title: String

    var body: some View {
        Button {
            isOn.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: isOn ? "link" : "link.badge.plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isOn ? GearTheme.accent : GearTheme.textMuted)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(RadialGradient(
                        colors: [GearTheme.metalMid, GearTheme.metalDark],
                        center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 16))
                )
                .overlay(
                    Circle().stroke(isOn ? GearTheme.accent.opacity(0.75) : .black.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) link")
        .accessibilityValue(isOn ? "Linked" : "Unlinked")
    }
}

/// The panel-finish selector: a small rotary switch sitting left of the
/// wordmark, its cap painted in whatever finish is currently fitted and its
/// pointer standing at that finish's detent. Tapping turns it to the next
/// one — the same gesture as reaching up and turning the knob on the front
/// of the real thing, and it keeps the choice out of the preset list where
/// it has no business being.
struct FinishSelector: View {
    var theme: GearPalette

    private var finishes: [GearPalette] { GearPalette.all }
    private var index: Int { finishes.firstIndex { $0.id == theme.id } ?? 0 }

    // Detents spread over a 70° arc, centred — two finishes sit at ±35°,
    // and more would simply divide the same sweep.
    private var pointerAngle: Double {
        let steps = max(1, finishes.count - 1)
        let t = Double(index) / Double(steps)
        return (-35 + t * 70) * .pi / 180
    }

    private func detentAngle(_ i: Int) -> Double {
        let steps = max(1, finishes.count - 1)
        return (-35 + Double(i) / Double(steps) * 70) * .pi / 180
    }

    var body: some View {
        Button {
            let next = finishes[(index + 1) % finishes.count]
            ThemeStore.shared.select(next)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } label: {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let centre = CGPoint(x: rect.midX, y: rect.midY)
                let radius = min(rect.width, rect.height) / 2

                func point(_ a: Double, _ r: CGFloat) -> CGPoint {
                    CGPoint(x: centre.x + CGFloat(sin(a)) * r, y: centre.y - CGFloat(cos(a)) * r)
                }

                // Detent marks printed on the panel, one per finish.
                for i in finishes.indices {
                    let a = detentAngle(i)
                    var tick = Path()
                    tick.move(to: point(a, radius * 0.82))
                    tick.addLine(to: point(a, radius * 0.99))
                    context.stroke(tick, with: .color(theme.textLight.opacity(i == index ? 0.9 : 0.45)),
                                   lineWidth: 1.4)
                }

                // Chrome bezel.
                let bezelR = radius * 0.74
                let bezel = CGRect(x: centre.x - bezelR, y: centre.y - bezelR,
                                   width: bezelR * 2, height: bezelR * 2)
                context.fill(Path(ellipseIn: bezel.offsetBy(dx: 0, dy: 1.4)),
                             with: .color(.black.opacity(0.45)))
                context.fill(Path(ellipseIn: bezel), with: .linearGradient(
                    Gradient(colors: [theme.metalLight, theme.metalMid, theme.metalDark]),
                    startPoint: CGPoint(x: bezel.minX, y: bezel.minY),
                    endPoint: CGPoint(x: bezel.maxX, y: bezel.maxY)))

                // Cap, painted in the fitted finish so the switch reads as a
                // colour swatch as well as a control.
                let capR = bezelR * 0.78
                let cap = CGRect(x: centre.x - capR, y: centre.y - capR,
                                 width: capR * 2, height: capR * 2)
                context.fill(Path(ellipseIn: cap), with: .linearGradient(
                    Gradient(colors: [theme.paintTop, theme.paintBottom]),
                    startPoint: CGPoint(x: cap.midX, y: cap.minY),
                    endPoint: CGPoint(x: cap.midX, y: cap.maxY)))
                context.stroke(Path(ellipseIn: cap), with: .color(.black.opacity(0.55)),
                               lineWidth: 0.8)

                // Pointer standing at the fitted finish's detent.
                var rotated = context
                rotated.translateBy(x: centre.x, y: centre.y)
                rotated.rotate(by: .radians(pointerAngle))
                rotated.translateBy(x: -centre.x, y: -centre.y)
                let width: CGFloat = 2.0
                let pointer = CGRect(x: centre.x - width / 2, y: centre.y - capR * 0.92,
                                     width: width, height: capR * 0.92)
                rotated.fill(Path(roundedRect: pointer, cornerRadius: width / 2),
                             with: .color(theme.textLight))

                // Gloss.
                context.fill(Path(ellipseIn: CGRect(x: centre.x - capR * 0.55, y: centre.y - capR * 0.72,
                                                     width: capR * 0.9, height: capR * 0.5)),
                             with: .radialGradient(
                                Gradient(colors: [.white.opacity(0.22), .clear]),
                                center: CGPoint(x: centre.x - capR * 0.1, y: centre.y - capR * 0.47),
                                startRadius: 0, endRadius: capR * 0.6))
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Panel finish")
        .accessibilityValue(theme.name)
        .accessibilityHint("Switches the panel colourway")
    }
}
