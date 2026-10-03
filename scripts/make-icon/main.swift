import AppKit
import SpriteKit

// Draws Fall Dock's app icon with the app's own drawing code (FallDock/Art), at every size
// macOS needs, into FallDock/Assets.xcassets/AppIcon.appiconset. Run scripts/make-icon.sh.

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.appiconset"

/// The icon at 1024 × 1024. Like Apple's icon template, the artwork sits in an 824-point rounded
/// square with room around it for the shadow.
func drawIcon(_ ctx: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // A soft shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(Palette.plum)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // Evening sky, a harvest moon, and a shelf like the Dock.
    ctx.setFillColor(Palette.plum.mixed(with: Palette.rust, 0.18))
    ctx.fill(tile)
    ctx.setFillColor(Palette.mustard.mixed(with: Palette.peach, 0.35))
    ctx.fillEllipse(in: CGRect(x: 600, y: 640, width: 210, height: 210))
    ctx.setFillColor(Palette.rust.mixed(with: Palette.plum, 0.35))
    ctx.fill(CGRect(x: 100, y: 100, width: 824, height: 215))
    ctx.setFillColor(Palette.rust.mixed(with: Palette.plum, 0.15))
    ctx.fill(CGRect(x: 100, y: 300, width: 824, height: 22))

    // The vine along the shelf, with a curl.
    let k: CGFloat = 4.2
    VineArt.taperedVine(ctx, from: 60, to: 964, maxWidth: 7 * k, color: Palette.green) { x in
        318 + sin(x / 90) * 8
    }
    Brush.tendril(ctx, from: CGPoint(x: 236, y: 320), dir: -1, size: 150, color: Palette.green)

    // A small mustard pumpkin and a big orange one.
    let small = PumpkinArt.bodySize(of: .squatMustard, height: 300)
    PumpkinArt.draw(kind: .squatMustard, cx: 735, base: 300, w: small.width, h: small.height, variant: 2, ctx: ctx)
    let big = PumpkinArt.bodySize(of: .roundOrange, height: 470)
    PumpkinArt.draw(kind: .roundOrange, cx: 455, base: 296, w: big.width, h: big.height, variant: 1, ctx: ctx)

    // A falling oak leaf.
    LeafArt.drawWagonLeaf(ctx, kind: .oak, at: CGPoint(x: 245, y: 760), length: 150, angle: -30, flip: false)
    ctx.restoreGState()
}

let master: CGImage = {
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    drawIcon(ctx)
    return ctx.makeImage()!
}()

try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let data = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(output)/\(name)"))
    images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(output)/Contents.json"))
print("Wrote \(images.count) icon sizes to \(output)")
