// Renders the app icon: a camera lens with a green glowing ring on a dark tile.
// usage: swift scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

let green = NSColor(red: 0.27, green: 0.84, blue: 0.17, alpha: 1)

func render(_ size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: size / 1024, y: size / 1024)

    // Tile, on the macOS icon grid (824pt inside 1024).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    ctx.addPath(tilePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: nil, colors: [
        NSColor(white: 0.17, alpha: 1).cgColor, NSColor(white: 0.04, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let c = CGPoint(x: 512, y: 512)
    func circle(_ r: CGFloat) -> CGRect { CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r) }

    // Metal barrel.
    ctx.saveGState()
    ctx.addEllipse(in: circle(300))
    ctx.clip()
    let metal = CGGradient(colorsSpace: nil, colors: [
        NSColor(white: 0.55, alpha: 1).cgColor, NSColor(white: 0.18, alpha: 1).cgColor,
        NSColor(white: 0.35, alpha: 1).cgColor] as CFArray, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(metal, start: CGPoint(x: 300, y: 812), end: CGPoint(x: 724, y: 212), options: [])
    ctx.restoreGState()
    ctx.setFillColor(NSColor(white: 0.03, alpha: 1).cgColor)
    ctx.fillEllipse(in: circle(262))

    // Green glowing ring.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40, color: green.cgColor)
    ctx.setStrokeColor(green.cgColor)
    ctx.setLineWidth(20)
    ctx.strokeEllipse(in: circle(228))
    ctx.restoreGState()

    // Iris: dark blades around a hexagonal opening onto blue glass.
    ctx.saveGState()
    ctx.addEllipse(in: circle(200))
    ctx.clip()
    let blades = CGGradient(colorsSpace: nil, colors: [
        NSColor(white: 0.16, alpha: 1).cgColor, NSColor(white: 0.05, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(blades, startCenter: c, startRadius: 90, endCenter: c, endRadius: 200, options: [.drawsAfterEndLocation])

    let vertices = (0..<6).map { i -> CGPoint in
        let a = CGFloat(i) * .pi / 3 + .pi / 6
        return CGPoint(x: c.x + 105 * cos(a), y: c.y + 105 * sin(a))
    }
    let hex = CGMutablePath()
    hex.addLines(between: vertices)
    hex.closeSubpath()

    // Blade edges: each runs from a corner of the opening along the next side, out to the barrel.
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
    ctx.setLineWidth(4)
    for i in 0..<6 {
        let a = vertices[i], b = vertices[(i + 1) % 6]
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let len = hypot(d.x, d.y)
        ctx.move(to: b)
        ctx.addLine(to: CGPoint(x: b.x + d.x / len * 220, y: b.y + d.y / len * 220))
    }
    ctx.strokePath()

    ctx.addPath(hex)
    ctx.clip()
    let glass = CGGradient(colorsSpace: nil, colors: [
        NSColor(red: 0.16, green: 0.26, blue: 0.48, alpha: 1).cgColor,
        NSColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glass, startCenter: CGPoint(x: 490, y: 535), startRadius: 0,
                           endCenter: c, endRadius: 110, options: [])
    ctx.setFillColor(NSColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1).cgColor)
    ctx.fillEllipse(in: circle(42))
    ctx.restoreGState()

    // Reflections.
    ctx.saveGState()
    ctx.translateBy(x: 430, y: 610)
    ctx.rotate(by: .pi / 5)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.fillEllipse(in: CGRect(x: -70, y: -24, width: 140, height: 48))
    ctx.restoreGState()
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
    ctx.fillEllipse(in: CGRect(x: 548, y: 452, width: 20, height: 20))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns")
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try render(CGFloat(base * scale)).representation(using: .png, properties: [:])!
            .write(to: iconset.appending(path: name))
    }
}
try render(1024).representation(using: .png, properties: [:])!.write(to: out.deletingPathExtension().appendingPathExtension("png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
print("wrote \(out.path)")
