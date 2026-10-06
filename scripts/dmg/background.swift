// Draws the fall-themed background of Dockorate's drag-to-Applications installer window, in the app
// icon's colors: a peach sky with a pale moon, falling leaves, and pumpkins on a strip of earth.
//
//   swift scripts/dmg/background.swift <output folder>
//
// Writes background.png (1x) and background@2x.png, sized for a 660 × 420 pt window with the app
// icon centered at (170, 215) and Applications at (490, 215).
import AppKit

let width: CGFloat = 660, height: CGFloat = 420
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let peachTop = color(0xFCE9D5), peachBottom = color(0xF7D7B6)
let moon = color(0xFBF4EA), earth = color(0x46271C), grass = color(0x86913F)
let rust = color(0xC8703A), orange = color(0xDD7A33), mustard = color(0xD4A23E), stem = color(0x8F4F2A)
let ink = color(0x4A2A1E)

func leaf(_ ctx: CGContext, at p: CGPoint, size s: CGFloat, angle: CGFloat, fill: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y)
    ctx.rotate(by: angle * .pi / 180)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: -s))
    path.addQuadCurve(to: CGPoint(x: 0, y: s), control: CGPoint(x: s * 0.95, y: 0))
    path.addQuadCurve(to: CGPoint(x: 0, y: -s), control: CGPoint(x: -s * 0.95, y: 0))
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
    // The midrib and stem.
    ctx.setStrokeColor(stem)
    ctx.setLineWidth(max(1, s * 0.09))
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 0, y: s * 0.75))
    ctx.addLine(to: CGPoint(x: 0, y: -s * 1.25))
    ctx.strokePath()
    ctx.restoreGState()
}

func pumpkin(_ ctx: CGContext, center x: CGFloat, ground y: CGFloat, height h: CGFloat, body: CGColor, ribs: CGColor) {
    let w = h * 1.3
    // Side lobes behind, then the middle lobe in front.
    ctx.setFillColor(body)
    ctx.fillEllipse(in: CGRect(x: x - w / 2, y: y, width: w * 0.62, height: h))
    ctx.fillEllipse(in: CGRect(x: x + w / 2 - w * 0.62, y: y, width: w * 0.62, height: h))
    ctx.setFillColor(body.copy(alpha: 1)!)
    ctx.fillEllipse(in: CGRect(x: x - w * 0.27, y: y, width: w * 0.54, height: h * 1.02))
    ctx.setStrokeColor(ribs)
    ctx.setLineWidth(max(1, h * 0.06))
    ctx.setLineCap(.round)
    for dx in [-0.33, -0.12, 0.12, 0.33] {
        let bx = x + w * CGFloat(dx)
        ctx.move(to: CGPoint(x: bx, y: y + h * 0.2))
        ctx.addQuadCurve(to: CGPoint(x: bx, y: y + h * 0.82), control: CGPoint(x: bx + (dx < 0 ? -1 : 1) * h * 0.08, y: y + h * 0.5))
    }
    ctx.strokePath()
    // Stem.
    ctx.setStrokeColor(stem)
    ctx.setLineWidth(h * 0.13)
    ctx.move(to: CGPoint(x: x, y: y + h * 0.95))
    ctx.addQuadCurve(to: CGPoint(x: x + h * 0.12, y: y + h * 1.22), control: CGPoint(x: x - h * 0.02, y: y + h * 1.15))
    ctx.strokePath()
}

func draw(scale: CGFloat) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    // Bottom-left origin from here on.

    // Sky.
    let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [peachBottom, peachTop] as CFArray,
                         locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])

    // A pale moon, top right, with a soft halo.
    ctx.setFillColor(moon.copy(alpha: 0.35)!)
    ctx.fillEllipse(in: CGRect(x: 552, y: 318, width: 84, height: 84))
    ctx.setFillColor(moon)
    ctx.fillEllipse(in: CGRect(x: 562, y: 328, width: 64, height: 64))

    // Earth and grass along the bottom.
    let groundTop: CGFloat = 46
    ctx.setFillColor(earth)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: groundTop))
    ctx.setFillColor(grass)
    ctx.fill(CGRect(x: 0, y: groundTop - 1, width: width, height: 5))

    // Pumpkins resting on the grass in the corners.
    pumpkin(ctx, center: 52, ground: groundTop + 2, height: 34, body: orange, ribs: color(0xA9532A))
    pumpkin(ctx, center: 96, ground: groundTop + 2, height: 20, body: mustard, ribs: color(0x9A6A25))
    pumpkin(ctx, center: 604, ground: groundTop + 2, height: 28, body: rust, ribs: color(0x95492A))
    pumpkin(ctx, center: 568, ground: groundTop + 2, height: 17, body: mustard, ribs: color(0x9A6A25))

    // Leaves drifting down.
    leaf(ctx, at: CGPoint(x: 46, y: 360), size: 13, angle: -35, fill: mustard)
    leaf(ctx, at: CGPoint(x: 118, y: 300), size: 9, angle: 25, fill: rust)
    leaf(ctx, at: CGPoint(x: 330, y: 132), size: 10, angle: 60, fill: mustard)
    leaf(ctx, at: CGPoint(x: 520, y: 290), size: 8, angle: -15, fill: orange)
    leaf(ctx, at: CGPoint(x: 620, y: 150), size: 11, angle: 40, fill: rust)
    leaf(ctx, at: CGPoint(x: 236, y: 92), size: 8, angle: -55, fill: orange)

    // The title.
    let title = "Drag Dockorate into your\nApplications folder"
    let font = NSFont.systemFont(ofSize: 26, weight: .heavy)
    let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 26) } ?? font
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineSpacing = 2
    let text = NSAttributedString(string: title, attributes: [
        .font: rounded, .foregroundColor: NSColor(cgColor: ink)!, .paragraphStyle: paragraph,
    ])
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    text.draw(in: CGRect(x: 40, y: 300, width: width - 80, height: 80))
    NSGraphicsContext.restoreGraphicsState()

    // The arrow from Dockorate to Applications (icons sit at y = 420 − 215 = 205 from the bottom).
    let y: CGFloat = 205
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 290, y: y))
    ctx.addLine(to: CGPoint(x: 366, y: y))
    ctx.move(to: CGPoint(x: 350, y: y + 15))
    ctx.addLine(to: CGPoint(x: 368, y: y))
    ctx.addLine(to: CGPoint(x: 350, y: y - 15))
    ctx.strokePath()

    return ctx.makeImage()!
}

for (scale, name) in [(CGFloat(1), "background.png"), (2, "background@2x.png")] {
    let rep = NSBitmapImageRep(cgImage: draw(scale: scale))
    rep.size = NSSize(width: width, height: height)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/" + name))
}
