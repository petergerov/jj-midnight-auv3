import SwiftUI

/// Shared hardware-drawing helpers. Everything the panel is built from is
/// drawn procedurally (no bitmaps) so it stays sharp at any size a host
/// hands the AUv3, and every piece takes its colours from the palette it
/// is handed rather than reading the current theme while it paints.
enum RetroDraw {
    /// A slotted steel screw. `angle` varies per screw so a panel doesn't
    /// look like every screw was driven home by a machine.
    static func screw(_ context: inout GraphicsContext, theme: GearPalette,
                      at centre: CGPoint, radius: CGFloat, angle: Double) {
        let box = CGRect(x: centre.x - radius, y: centre.y - radius,
                         width: radius * 2, height: radius * 2)

        context.fill(Path(ellipseIn: box.offsetBy(dx: 0, dy: radius * 0.28)),
                     with: .color(.black.opacity(0.45)))

        context.fill(Path(ellipseIn: box), with: .radialGradient(
            Gradient(colors: [theme.metalLight, theme.metalMid, theme.metalDark]),
            center: CGPoint(x: centre.x - radius * 0.35, y: centre.y - radius * 0.4),
            startRadius: 0, endRadius: radius * 1.6))
        context.stroke(Path(ellipseIn: box), with: .color(.black.opacity(0.55)), lineWidth: 0.8)

        var slotted = context
        slotted.translateBy(x: centre.x, y: centre.y)
        slotted.rotate(by: .radians(angle))
        slotted.translateBy(x: -centre.x, y: -centre.y)

        let slotHeight = max(1.2, radius * 0.3)
        let slot = CGRect(x: centre.x - radius * 0.78, y: centre.y - slotHeight / 2,
                          width: radius * 1.56, height: slotHeight)
        slotted.fill(Path(roundedRect: slot, cornerRadius: slotHeight / 2),
                     with: .color(.black.opacity(0.62)))
        slotted.fill(Path(roundedRect: slot.offsetBy(dx: 0, dy: slotHeight * 0.55),
                          cornerRadius: slotHeight / 2),
                     with: .color(theme.metalLight.opacity(0.22)))
    }

    /// Hammered enamel: overlapping soft light/dark dimples over a flat
    /// coat, the finish on most 60s-70s rack gear.
    static func hammeredPaint(_ context: inout GraphicsContext, in rect: CGRect,
                              seed: UInt64, dimples: Int) {
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<dimples {
            let x = Double.random(in: rect.minX...rect.maxX, using: &rng)
            let y = Double.random(in: rect.minY...rect.maxY, using: &rng)
            let r = Double.random(in: 4...10, using: &rng)
            let lit = Double.random(in: 0...1, using: &rng) > 0.5
            let strength = Double.random(in: 0.025...0.065, using: &rng)
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(
                    Gradient(colors: [(lit ? Color.white : Color.black).opacity(strength), .clear]),
                    center: CGPoint(x: x - r * 0.3, y: y - r * 0.35),
                    startRadius: 0, endRadius: r))
        }
    }
}

/// The front plate: hammered enamel, lit from above, worn darker towards
/// the edges.
struct ChassisBackground: View {
    var theme: GearPalette

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)

            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [theme.paintTop, theme.paintBottom]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

            RetroDraw.hammeredPaint(&context, in: rect, seed: 0xBEE2E,
                                    dimples: min(900, Int(size.width * size.height / 700)))

            // Fine horizontal brush grain left by the paint roller.
            var rng = SeededGenerator(seed: 12345)
            var y: CGFloat = 0
            while y < rect.height {
                let alpha = Double.random(in: 0...0.022, using: &rng)
                var line = Path()
                line.move(to: CGPoint(x: rect.minX, y: y))
                line.addLine(to: CGPoint(x: rect.maxX, y: y))
                context.stroke(line, with: .color(.white.opacity(alpha)), lineWidth: 1)
                y += 3
            }

            // Vignette — the plate is lit from the front centre.
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(0.42)]),
                center: CGPoint(x: rect.midX, y: rect.height * 0.34),
                startRadius: min(rect.width, rect.height) * 0.28,
                endRadius: max(rect.width, rect.height) * 0.78))
        }
        .allowsHitTesting(false)
    }
}

/// Deterministic PRNG (splitmix64-style) — keeps the paint texture, screw
/// angles and rivet spacing stable across redraws. Not for anything
/// security- or audio-relevant.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A rack-mount ear: the dark steel side rail the plate is bolted to, with
/// two mounting screws.
struct RackEar: View {
    var theme: GearPalette

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [theme.chassisTop, theme.chassisBottom]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))

            // Rolled edge catching the light.
            var edge = Path()
            edge.move(to: CGPoint(x: rect.minX + 1, y: rect.minY))
            edge.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY))
            context.stroke(edge, with: .color(theme.metalMid.opacity(0.35)), lineWidth: 1)

            let radius = size.width * 0.2
            RetroDraw.screw(&context, theme: theme,
                            at: CGPoint(x: rect.midX, y: rect.height * 0.16),
                            radius: radius, angle: 0.6)
            RetroDraw.screw(&context, theme: theme,
                            at: CGPoint(x: rect.midX, y: rect.height * 0.84),
                            radius: radius, angle: -0.9)
        }
        .allowsHitTesting(false)
    }
}

/// A sub-plate screwed onto the front panel — each effect section sits on
/// one, the way 70s consoles bolted a separate engraved plate over every
/// module.
struct PanelPlate: View {
    var theme: GearPalette
    var cornerRadius: CGFloat = 5
    var screwInset: CGFloat = 9
    var screwRadius: CGFloat = 3.4

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            let plate = Path(roundedRect: rect, cornerRadius: cornerRadius)

            context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 2.5), cornerRadius: cornerRadius),
                         with: .color(.black.opacity(0.38)))
            context.fill(plate, with: .linearGradient(
                Gradient(colors: [theme.panelFill.opacity(0.98),
                                  theme.panelEdgeDark.opacity(0.92)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

            RetroDraw.hammeredPaint(&context, in: rect, seed: 0x51DE_91A7,
                                    dimples: min(420, Int(size.width * size.height / 900)))

            // Bevel: a bright top lip and a dark bottom shadow line.
            context.stroke(plate, with: .color(theme.panelEdgeDark), lineWidth: 1)
            let inner = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: cornerRadius - 1)
            context.stroke(inner, with: .linearGradient(
                Gradient(colors: [theme.panelEdgeLight.opacity(0.55), .clear]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.midY)), lineWidth: 1)

            var rng = SeededGenerator(seed: 0x5C4E4)
            for corner in [CGPoint(x: rect.minX + screwInset, y: rect.minY + screwInset),
                           CGPoint(x: rect.maxX - screwInset, y: rect.minY + screwInset),
                           CGPoint(x: rect.minX + screwInset, y: rect.maxY - screwInset),
                           CGPoint(x: rect.maxX - screwInset, y: rect.maxY - screwInset)] {
                RetroDraw.screw(&context, theme: theme, at: corner, radius: screwRadius,
                                angle: Double.random(in: -1.2...1.2, using: &rng))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A small engraved nameplate — the "MODEL / SERIAL" tag riveted to the
/// bottom of the panel.
struct ModelPlate: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(GearTheme.metalDark.opacity(0.9))
            .shadow(color: GearTheme.metalLight.opacity(0.35), radius: 0, x: 0, y: 0.6)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [GearTheme.metalLight.opacity(0.85), GearTheme.metalMid.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(GearTheme.metalDark.opacity(0.7), lineWidth: 0.8)
            )
            .accessibilityHidden(true)
    }
}

/// A recessed readout window: smoked glass in a chrome bezel, with the
/// light falling across it. Used behind every numeric readout, the preset
/// display and the level meters.
struct LedWindow: View {
    var cornerRadius: CGFloat = 2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(GearTheme.ledBackground)

            // Light falling into the recess from above.
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(
                    colors: [.black.opacity(0.65), .clear, .white.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom))

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(LinearGradient(
                    colors: [GearTheme.metalDark, GearTheme.metalMid.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// A jewel indicator lamp in a chrome bezel.
struct JewelLamp: View {
    var isOn: Bool
    var color: Color
    var theme: GearPalette

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let radius = min(rect.width, rect.height) / 2
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let bezel = CGRect(x: centre.x - radius, y: centre.y - radius,
                               width: radius * 2, height: radius * 2)

            context.fill(Path(ellipseIn: bezel), with: .radialGradient(
                Gradient(colors: [theme.metalMid, theme.metalDark]),
                center: CGPoint(x: centre.x - radius * 0.4, y: centre.y - radius * 0.5),
                startRadius: 0, endRadius: radius * 1.4))

            let glassR = radius * 0.72
            let glass = CGRect(x: centre.x - glassR, y: centre.y - glassR,
                               width: glassR * 2, height: glassR * 2)
            if isOn {
                context.fill(Path(ellipseIn: glass.insetBy(dx: -glassR * 0.9, dy: -glassR * 0.9)),
                             with: .radialGradient(
                                Gradient(colors: [color.opacity(0.45), .clear]),
                                center: centre, startRadius: 0, endRadius: glassR * 2))
            }
            context.fill(Path(ellipseIn: glass), with: .radialGradient(
                Gradient(colors: isOn ? [.white.opacity(0.9), color, color.opacity(0.85)]
                                      : [theme.lampRedDim, .black.opacity(0.9)]),
                center: CGPoint(x: centre.x - glassR * 0.3, y: centre.y - glassR * 0.35),
                startRadius: 0, endRadius: glassR * 1.5))
            context.stroke(Path(ellipseIn: glass), with: .color(.black.opacity(0.5)), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }
}

/// The steel base rail along the bottom edge, riveted to the plate. Drawn
/// on top of everything else, same as on the real thing.
struct FooterRivetStrip: View {
    var theme: GearPalette
    var rivetCount: Int = 16

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [theme.chassisTop, theme.chassisBottom]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

            var top = Path()
            top.move(to: CGPoint(x: rect.minX, y: rect.minY + 0.5))
            top.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 0.5))
            context.stroke(top, with: .color(.black.opacity(0.55)), lineWidth: 1)

            let step = rect.width / CGFloat(rivetCount + 1)
            let radius = min(2.2, rect.height * 0.18)
            for i in 1...rivetCount {
                let centre = CGPoint(x: step * CGFloat(i), y: rect.midY)
                context.fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                                     width: radius * 2, height: radius * 2)),
                             with: .radialGradient(
                                Gradient(colors: [theme.metalLight.opacity(0.8), theme.metalDark]),
                                center: CGPoint(x: centre.x - radius * 0.3, y: centre.y - radius * 0.4),
                                startRadius: 0, endRadius: radius * 1.5))
            }
        }
        .allowsHitTesting(false)
    }
}
