// Renders JJMidnight/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
//
// Same composition as jj-breeze's icon — painted panel, four corner screws,
// a meter arc with ticks, serif italic wordmark, three jewel lamps — in the
// Tweed colourway from GearTheme.swift, so the two read as one product
// family wearing different finishes. Colours here are the same hex values
// as GearPalette.tweed; if that palette changes, change these with it.
//
//   swift icon/make-icon.swift
//
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024

// MARK: - GearPalette.tweed
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: a)
}

let panelTop = rgb(0x6b3229)      // oxblood, lifted a little for the top of the gradient
let panelBottom = rgb(0x3a1a16)
let brass = rgb(0xf0c96a)
let brassDim = rgb(0x7f6730)
let cream = rgb(0xf7eeda)
let metalLight = rgb(0xf0e2c2)
let metalMid = rgb(0xb99a5e)
let metalDark = rgb(0x3a2d18)
let lampGreen = rgb(0x8fd96a)
let lampAmber = rgb(0xf5bd45)
let lampRed = rgb(0xff4030)

// Opaque: the App Store rejects an icon with an alpha channel.
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("could not create bitmap context")
}

// MARK: - Panel paint
let paint = CGGradient(colorsSpace: cs, colors: [panelTop, panelBottom] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(paint, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0),
                       options: [])

// MARK: - Tweed weave
// Lacquered cloth, not a flat painted panel: two sets of diagonal threads
// crossing at right angles. Kept very low contrast — at 40 pt it should read
// as texture, never as stripes.
ctx.saveGState()
let threadSpacing: CGFloat = 9
for direction in [CGFloat(1), CGFloat(-1)] {
    ctx.setLineWidth(3)
    var offset: CGFloat = -size
    while offset < size * 2 {
        // Alternating light and dark threads give the weave its grain. Kept
        // faint and fine on purpose: crank the alpha or the spacing and the
        // panel stops reading as cloth and starts reading as tartan.
        let light = Int(offset / threadSpacing) % 2 == 0
        ctx.setStrokeColor(light ? rgb(0xd8bc8a, 0.040) : rgb(0x1a0c0a, 0.055))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: offset, y: 0))
        ctx.addLine(to: CGPoint(x: offset + direction * size, y: size))
        ctx.strokePath()
        offset += threadSpacing
    }
}
ctx.restoreGState()

// MARK: - Vignette
// Pulls the corners down so the wordmark and arc sit in the light, the way
// the jj-breeze icon's panel does.
let vignette = CGGradient(colorsSpace: cs,
                          colors: [rgb(0x000000, 0), rgb(0x000000, 0.42)] as CFArray,
                          locations: [0.45, 1])!
ctx.drawRadialGradient(vignette,
                       startCenter: CGPoint(x: size / 2, y: size * 0.56), startRadius: 0,
                       endCenter: CGPoint(x: size / 2, y: size * 0.56), endRadius: size * 0.78,
                       options: [.drawsAfterEndLocation])

// MARK: - Corner screws
func screw(at p: CGPoint, radius r: CGFloat, slotAngle: CGFloat) {
    let head = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)

    ctx.saveGState()
    ctx.addEllipse(in: head)
    ctx.clip()
    let body = CGGradient(colorsSpace: cs, colors: [metalLight, metalMid, metalDark] as CFArray,
                          locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(body,
                           start: CGPoint(x: p.x - r, y: p.y + r),
                           end: CGPoint(x: p.x + r, y: p.y - r), options: [])
    ctx.restoreGState()

    ctx.setStrokeColor(rgb(0x000000, 0.55))
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: head)

    // Slot, rotated so the screws don't look machine-placed.
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y)
    ctx.rotate(by: slotAngle)
    ctx.setFillColor(rgb(0x120a06, 0.85))
    ctx.fill(CGRect(x: -r * 0.72, y: -r * 0.14, width: r * 1.44, height: r * 0.28))
    ctx.setFillColor(rgb(0xd8bc8a, 0.30))
    ctx.fill(CGRect(x: -r * 0.72, y: r * 0.10, width: r * 1.44, height: r * 0.08))
    ctx.restoreGState()
}

let screwInset: CGFloat = 124
let screwRadius: CGFloat = 23
screw(at: CGPoint(x: screwInset, y: size - screwInset), radius: screwRadius, slotAngle: 0.55)
screw(at: CGPoint(x: size - screwInset, y: size - screwInset), radius: screwRadius, slotAngle: -0.7)
screw(at: CGPoint(x: screwInset, y: screwInset), radius: screwRadius, slotAngle: -0.35)
screw(at: CGPoint(x: size - screwInset, y: screwInset), radius: screwRadius, slotAngle: 0.85)

// MARK: - Meter arc
// Geometry lifted from the jj-breeze icon so the two sit side by side in a
// home screen folder without one looking redrawn.
let arcCenter = CGPoint(x: size / 2, y: size - 572)
let arcRadius: CGFloat = 332
let startAngle = CGFloat.pi * (202.0 / 180.0)
let endAngle = CGFloat.pi * (338.0 / 180.0)

func strokeArc(radius: CGFloat, width: CGFloat, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.beginPath()
    // Negative y in the arc because the context's origin is bottom-left but
    // the geometry above is written top-down.
    ctx.addArc(center: arcCenter, radius: radius,
               startAngle: -startAngle, endAngle: -endAngle, clockwise: true)
    ctx.strokePath()
}

strokeArc(radius: arcRadius, width: 30, color: rgb(0x000000, 0.30))   // shadow under the arc
strokeArc(radius: arcRadius, width: 22, color: brassDim)              // dim outer edge
strokeArc(radius: arcRadius, width: 14, color: brass)                 // lit face

// Ticks, radiating outward past the arc.
ctx.setLineCap(.butt)
ctx.setLineWidth(9)
ctx.setStrokeColor(rgb(0xd8bc8a, 0.62))
let tickCount = 9
for i in 0..<tickCount {
    let t = CGFloat(i) / CGFloat(tickCount - 1)
    let angle = startAngle + (endAngle - startAngle) * t
    let dx = cos(angle), dy = -sin(angle)
    let inner = arcRadius + 28, outer = arcRadius + 64
    ctx.beginPath()
    ctx.move(to: CGPoint(x: arcCenter.x + dx * inner, y: arcCenter.y + dy * inner))
    ctx.addLine(to: CGPoint(x: arcCenter.x + dx * outer, y: arcCenter.y + dy * outer))
    ctx.strokePath()
}

// MARK: - Wordmark
// Georgia Bold Italic, the same face the panel's wordmark uses.
let text = "J.J.Midnight"

// Shrink to fit rather than hard-coding a size for one name. J.J.Tulsa was
// nine characters and sat comfortably at 150; J.J.Midnight is twelve and ran
// off both edges, which iOS then clips again when it rounds the corners.
// Anything that fits keeps the full 150, so this is a no-op for short names.
let maxFontSize: CGFloat = 150
let wordmarkMaxWidth: CGFloat = 800      // of 1024 — matches the old margins

func wordmarkFont() -> CTFont {
    var pt = maxFontSize
    while pt > 40 {
        let candidate = CTFontCreateWithName("Georgia-BoldItalic" as CFString, pt, nil)
        let attrs: [NSAttributedString.Key: Any] =
            [kCTFontAttributeName as NSAttributedString.Key: candidate]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attrs))
        if CTLineGetBoundsWithOptions(line, .useOpticalBounds).width <= wordmarkMaxWidth {
            return candidate
        }
        pt -= 1
    }
    return CTFontCreateWithName("Georgia-BoldItalic" as CFString, 40, nil)
}

let font = wordmarkFont()

func drawWordmark(dy: CGFloat, colour: CGColor) {
    // CoreText keys rather than the AppKit/UIKit ones — this script links
    // neither.
    let attrs: [NSAttributedString.Key: Any] = [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: colour,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: (size - bounds.width) / 2 - bounds.minX,
                               y: size - 672 + dy)
    CTLineDraw(line, ctx)
}

drawWordmark(dy: -6, colour: rgb(0x120a06, 0.55))   // drop shadow
drawWordmark(dy: 0, colour: cream)

// MARK: - Jewel lamps
func lamp(at p: CGPoint, radius r: CGFloat, colour: CGColor) {
    // Bezel
    ctx.saveGState()
    let bezel = CGRect(x: p.x - r - 5, y: p.y - r - 5, width: (r + 5) * 2, height: (r + 5) * 2)
    ctx.addEllipse(in: bezel)
    ctx.clip()
    let ring = CGGradient(colorsSpace: cs, colors: [metalLight, metalDark] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(ring,
                           start: CGPoint(x: bezel.minX, y: bezel.maxY),
                           end: CGPoint(x: bezel.maxX, y: bezel.minY), options: [])
    ctx.restoreGState()

    // Glass
    ctx.setFillColor(colour)
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))

    // Highlight, offset up-left so the lamps read as domed
    ctx.setFillColor(rgb(0xffffff, 0.42))
    ctx.fillEllipse(in: CGRect(x: p.x - r * 0.52, y: p.y + r * 0.06,
                               width: r * 0.62, height: r * 0.52))
}

let lampY = size - 783
let lampRadius: CGFloat = 23
lamp(at: CGPoint(x: size / 2 - 82, y: lampY), radius: lampRadius, colour: lampGreen)
lamp(at: CGPoint(x: size / 2, y: lampY), radius: lampRadius, colour: lampAmber)
lamp(at: CGPoint(x: size / 2 + 82, y: lampY), radius: lampRadius, colour: lampRed)

// MARK: - Write
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "JJMidnight/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
guard let image = ctx.makeImage() else { fatalError("could not render") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not open \(outPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(outPath)") }
print("wrote \(outPath)")
