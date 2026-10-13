import AppKit

/// Renders the app icon in Rugonmac's style: the same indigo squircle with glow, glassy sheen and rim,
/// two sparkles, and in the middle the corduroy chair with a photo and a letter thrown on its seat.
/// Run with `Sofaonmac --icon <out.png>`; scripts/make-icon.sh packs it.
enum AppIcon {
    static func render(to path: String) {
        let S: CGFloat = 1024
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
        func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
            CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locations)!
        }
        let squircle = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

        // tile shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
        ctx.addPath(squircle)
        ctx.setFillColor(rgb(0.25, 0.2, 0.7))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()

        // background: bright indigo at the top to deep violet at the bottom, with a soft glow
        ctx.drawLinearGradient(gradient([rgb(0.45, 0.52, 1.0), rgb(0.33, 0.30, 0.92), rgb(0.19, 0.12, 0.52)], [0, 0.5, 1]),
                               start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
        ctx.drawRadialGradient(gradient([rgb(0.75, 0.8, 1, 0.45), rgb(0.75, 0.8, 1, 0)], [0, 1]),
                               startCenter: CGPoint(x: 512, y: 600), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 600), endRadius: 430, options: [])

        drawChair(ctx, rgb: rgb)

        // two sparkles: it's tidy now
        sparkle(ctx, center: CGPoint(x: 770, y: 800), radius: 80, rgb: rgb)
        sparkle(ctx, center: CGPoint(x: 862, y: 700), radius: 44, rgb: rgb)

        // glassy sheen over the top half
        ctx.drawLinearGradient(gradient([rgb(1, 1, 1, 0.20), rgb(1, 1, 1, 0)], [0, 1]),
                               start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.maxY - 360), options: [])
        ctx.restoreGState()

        // glass rim
        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.setLineWidth(6)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(gradient([rgb(1, 1, 1, 0.6), rgb(1, 1, 1, 0.08), rgb(1, 1, 1, 0.22)], [0, 0.55, 1]),
                               start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
        ctx.restoreGState()

        guard let img = ctx.makeImage() else { return }
        try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// The chair standing on a soft floor shadow, with two things lying flat on its seat.
    private static func drawChair(_ ctx: CGContext, rgb: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGColor) {
        let style = SofaStyle.standard
        guard let chair = style.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let aspect = CGFloat(chair.width) / CGFloat(chair.height)
        let w: CGFloat = 610, h = w / aspect
        let rect = CGRect(x: 512 - w / 2 + 6, y: 205, width: w, height: h)

        // floor shadow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 40, color: rgb(0.05, 0.02, 0.2, 0.7))
        ctx.setFillColor(rgb(0.05, 0.02, 0.2, 0.55))
        ctx.fillEllipse(in: CGRect(x: rect.minX + 30, y: rect.minY - 22, width: w - 40, height: 50))
        ctx.restoreGState()

        ctx.interpolationQuality = .high
        ctx.draw(chair, in: rect)

        // seat point in CG coordinates (the style's seat is measured from the top)
        let seat = CGPoint(x: rect.minX + w * style.seat.x, y: rect.maxY - h * style.seat.y)

        /// A sheet lying on the cushion: drawn upright, then flattened for perspective.
        func sheet(at c: CGPoint, size: CGSize, angle: CGFloat, draw: (CGRect) -> Void) {
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.scaleBy(x: 1, y: 0.6)
            ctx.rotate(by: angle)
            let r = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            let path = CGPath(roundedRect: r, cornerWidth: 10, cornerHeight: 10, transform: nil)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 18, color: rgb(0, 0.1, 0.05, 0.45))
            ctx.addPath(path)
            ctx.setFillColor(rgb(1, 1, 1, 1))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.addPath(path)
            ctx.clip()
            draw(r)
            ctx.restoreGState()
        }

        // a letter with a few lines of text
        sheet(at: CGPoint(x: seat.x + 64, y: seat.y + 8), size: CGSize(width: 170, height: 220), angle: -0.42) { r in
            ctx.setFillColor(rgb(0.36, 0.40, 0.85, 1))
            for i in 0..<7 {
                let lw = r.width * [0.7, 0.55, 0.72, 0.6, 0.68, 0.4, 0.5][i]
                ctx.fill(CGRect(x: r.minX + 22, y: r.maxY - 40 - CGFloat(i) * 24, width: lw, height: 9))
            }
        }
        // a holiday photo: sunset over a hill, white border
        sheet(at: CGPoint(x: seat.x - 50, y: seat.y - 18), size: CGSize(width: 230, height: 170), angle: 0.22) { r in
            let inner = r.insetBy(dx: 12, dy: 12)
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: inner, cornerWidth: 4, cornerHeight: 4, transform: nil))
            ctx.clip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let sky = CGGradient(colorsSpace: cs, colors: [rgb(1.0, 0.55, 0.35, 1), rgb(1.0, 0.82, 0.45, 1)] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: inner.maxY), end: CGPoint(x: 0, y: inner.minY), options: [])
            ctx.setFillColor(rgb(1, 0.97, 0.85, 1))
            ctx.fillEllipse(in: CGRect(x: inner.midX + 10, y: inner.midY - 4, width: 46, height: 46))
            ctx.setFillColor(rgb(0.30, 0.55, 0.42, 1))
            ctx.fillEllipse(in: CGRect(x: inner.minX - 60, y: inner.minY - 90, width: inner.width + 40, height: 150))
            ctx.restoreGState()
        }
    }

    /// Four-pointed star with inward-curved sides, white with a soft glow.
    private static func sparkle(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat,
                                rgb: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGColor) {
        let tips = [CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x + r, y: c.y), CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x - r, y: c.y)]
        let path = CGMutablePath()
        path.move(to: tips[0])
        for i in 0..<4 {
            let p = tips[i], q = tips[(i + 1) % 4]
            let mid = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            let ctrl = CGPoint(x: c.x + (mid.x - c.x) * 0.3, y: c.y + (mid.y - c.y) * 0.3)
            path.addQuadCurve(to: q, control: ctrl)
        }
        path.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: r * 0.6, color: rgb(1, 0.95, 0.85, 0.9))
        ctx.addPath(path)
        ctx.setFillColor(rgb(1, 1, 1, 1))
        ctx.fillPath()
        ctx.restoreGState()
    }
}
