import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// `Sofaonmac --cutout <photo> <out.png> [--lift x]`: frees a piece of furniture from its product photo
/// and crops to it. Used by scripts/add-sofa.sh.
///
/// Vision's subject mask finds the furniture, but it is soft and keeps faint floor shadows. So the mask is
/// hardened (anything Vision isn't sure about goes), on white studio photos the white is keyed out as well,
/// and edge pixels get the background color taken back out of them, so no halo or rim is left.
enum Cutout {
    /// `lift` (0…1) brightens the photo's own shadows, for pictures that were lit too darkly.
    static func run(input: String, output: String, lift: Float = 0) -> Bool {
        guard let original = CIImage(contentsOf: URL(fileURLWithPath: input)) else {
            print("can't read \(input)"); return false
        }
        let extent = original.extent
        let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        do {
            // 1. where's the furniture
            let handler = VNImageRequestHandler(ciImage: original)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])
            guard let result = request.results?.first else { print("no subject found in \(input)"); return false }
            let maskImage = CIImage(cvPixelBuffer: try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler))

            // 2. pixels: the untouched photo (for keying), the lifted photo (what we keep), the mask
            var photo = original
            if lift > 0 {
                let adjust = CIFilter.highlightShadowAdjust()
                adjust.inputImage = original
                adjust.shadowAmount = lift
                adjust.highlightAmount = 1
                adjust.radius = 12
                // lifting shadows washes colors out a little; give some back
                let color = CIFilter.colorControls()
                color.inputImage = adjust.outputImage
                color.saturation = 1 + lift * 0.18
                photo = (color.outputImage ?? original).cropped(to: extent)
            }
            let w = Int(extent.width), h = Int(extent.height)
            let src = rgba(original, ctx, extent), keep = rgba(photo, ctx, extent)
            let mask = gray(maskImage, ctx, extent)

            // 3. alpha, depending on what kind of picture it is
            enum Kind { case alreadyCut, studioWhite, photo }
            let kind: Kind = cornersAreTransparent(src, w, h) ? .alreadyCut : cornersAreWhite(src, w, h) ? .studioWhite : .photo
            var alpha = [Float](repeating: 0, count: w * h)
            switch kind {
            case .alreadyCut:
                // keep the picture's own cut, but drop its soft drop shadow, and pull the edge in by two pixels:
                // such pictures were usually cut on white, and that white still clings to the outline
                for i in 0..<(w * h) { alpha[i] = smoothstep(0.6, 0.92, Float(src[i * 4 + 3]) / 255) }
                alpha = boxBlur(minFilter(minFilter(alpha, w, h), w, h), w, h)
            case .studioWhite:
                // white that is connected to the border is background; white highlights inside the furniture stay.
                // Vision's mask (lenient) still removes floor shadows.
                let distance = (0..<(w * h)).map { i in
                    max(255 - Float(src[i * 4]), 255 - Float(src[i * 4 + 1]), 255 - Float(src[i * 4 + 2])) / 255
                }
                let background = flood(from: distance, below: 0.12, w, h)
                for i in 0..<(w * h) {
                    let key: Float = background[i] ? smoothstep(0.03, 0.12, distance[i]) : 1
                    alpha[i] = key * smoothstep(0.2, 0.5, Float(mask[i]) / 255)
                }
            case .photo:
                for i in 0..<(w * h) { alpha[i] = smoothstep(0.35, 0.65, Float(mask[i]) / 255) }
                // pull the edge in by a pixel, then soften it by one
                alpha = boxBlur(minFilter(alpha, w, h), w, h)
            }

            // 4. compose (premultiplied): straight colors from the (lifted) photo; on white photos, edge pixels
            // were mixed with the white, take that back out
            var out = [UInt8](repeating: 0, count: w * h * 4)
            for i in 0..<(w * h) {
                let a = alpha[i]
                guard a > 0.004 else { continue }
                let srcA = max(Float(keep[i * 4 + 3]) / 255, 0.001)
                for c in 0..<3 {
                    var v = min(Float(keep[i * 4 + c]) / 255 / srcA, 1)
                    if kind == .studioWhite && a < 0.98 { v = min(max((v - (1 - a)) / a, 0), 1) }
                    out[i * 4 + c] = UInt8((v * a * 255).rounded())
                }
                out[i * 4 + 3] = UInt8((a * 255).rounded())
            }
            guard let cg = makeImage(&out, w, h) else { return false }

            // 5. crop to the furniture, with a pixel of air
            let bounds = opaqueBounds(alpha, w, h).insetBy(dx: -2, dy: -2).intersection(CGRect(x: 0, y: 0, width: w, height: h))
            guard let cropped = cg.cropping(to: bounds),
                  let png = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:]) else { return false }
            try png.write(to: URL(fileURLWithPath: output))
            print("\(cropped.width)×\(cropped.height) → \(output) (\(kind))")
            return true
        } catch {
            print("cutout failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Pixel helpers (rows top to bottom)

    private static func rgba(_ image: CIImage, _ ctx: CIContext, _ extent: CGRect) -> [UInt8] {
        let w = Int(extent.width), h = Int(extent.height)
        var data = [UInt8](repeating: 0, count: w * h * 4)
        ctx.render(image, toBitmap: &data, rowBytes: w * 4, bounds: extent, format: .RGBA8,
                   colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return data
    }

    private static func gray(_ image: CIImage, _ ctx: CIContext, _ extent: CGRect) -> [UInt8] {
        let w = Int(extent.width), h = Int(extent.height)
        var data = [UInt8](repeating: 0, count: w * h)
        ctx.render(image, toBitmap: &data, rowBytes: w, bounds: extent, format: .L8, colorSpace: nil)
        return data
    }

    private static func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Studio product shots: all four corners (nearly) pure white.
    private static func cornersAreWhite(_ px: [UInt8], _ w: Int, _ h: Int) -> Bool {
        let corners = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]
        return corners.allSatisfy { x, y in
            let i = (y * w + x) * 4
            return min(px[i], px[i + 1], px[i + 2]) > 235
        }
    }

    /// Pictures that come already cut out (transparent corners).
    private static func cornersAreTransparent(_ px: [UInt8], _ w: Int, _ h: Int) -> Bool {
        [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)].allSatisfy { x, y in px[(y * w + x) * 4 + 3] < 10 }
    }

    /// Everything reachable from the image border through pixels whose value is below `limit`.
    private static func flood(from value: [Float], below limit: Float, _ w: Int, _ h: Int) -> [Bool] {
        var seen = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
        for y in 0..<h { stack.append(y * w); stack.append(y * w + w - 1) }
        while let i = stack.popLast() {
            guard !seen[i], value[i] < limit else { continue }
            seen[i] = true
            let x = i % w, y = i / w
            if x > 0 { stack.append(i - 1) }
            if x < w - 1 { stack.append(i + 1) }
            if y > 0 { stack.append(i - w) }
            if y < h - 1 { stack.append(i + w) }
        }
        return seen
    }

    private static func minFilter(_ a: [Float], _ w: Int, _ h: Int) -> [Float] {
        var out = a
        for y in 0..<h {
            for x in 0..<w {
                var m: Float = 1
                for dy in -1...1 { for dx in -1...1 {
                    let xx = min(max(x + dx, 0), w - 1), yy = min(max(y + dy, 0), h - 1)
                    m = min(m, a[yy * w + xx])
                } }
                out[y * w + x] = m
            }
        }
        return out
    }

    private static func boxBlur(_ a: [Float], _ w: Int, _ h: Int) -> [Float] {
        var out = a
        for y in 0..<h {
            for x in 0..<w {
                var s: Float = 0
                for dy in -1...1 { for dx in -1...1 {
                    let xx = min(max(x + dx, 0), w - 1), yy = min(max(y + dy, 0), h - 1)
                    s += a[yy * w + xx]
                } }
                out[y * w + x] = s / 9
            }
        }
        return out
    }

    private static func makeImage(_ data: inout [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        data.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }

    /// The smallest rectangle (top-left origin, as CGImage.cropping wants it) holding all visible pixels.
    private static func opaqueBounds(_ alpha: [Float], _ w: Int, _ h: Int) -> CGRect {
        var minX = w, minY = h, maxX = 0, maxY = 0
        for y in 0..<h {
            for x in 0..<w where alpha[y * w + x] > 0.03 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return CGRect(x: 0, y: 0, width: w, height: h) }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
