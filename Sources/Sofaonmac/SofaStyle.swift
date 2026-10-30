import AppKit

/// One chair to choose from. Its picture is a cut-out photo in Resources/sofa-<id>.png
/// (made with `scripts/add-sofa.sh`); `seat` says where on that picture things land.
struct SofaStyle: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    /// Middle of the seat, as a fraction of the picture (0,0 = top left).
    let seat: CGPoint
    /// How far left and right of the middle the pile may spread, as a fraction of the picture's width.
    let spread: CGFloat
    /// How wide the piece is in real life, in cm, as seen in the photo (so a sofa is bigger than an armchair).
    let width: CGFloat

    static let all: [SofaStyle] = [
        SofaStyle(id: "cord", title: "Cord", subtitle: "Grüner Cord-Sessel", seat: CGPoint(x: 0.35, y: 0.47), spread: 0.16, width: 95),
        SofaStyle(id: "togo", title: "Togo", subtitle: "Der Knautsch-Klassiker in braunem Leder", seat: CGPoint(x: 0.64, y: 0.55), spread: 0.14, width: 105),
        SofaStyle(id: "lc2", title: "LC2", subtitle: "Le Corbusiers Würfel in schwarzem Leder", seat: CGPoint(x: 0.30, y: 0.36), spread: 0.08, width: 90),
        SofaStyle(id: "sand", title: "Sandsofa", subtitle: "Weiches Modulsofa in Beige", seat: CGPoint(x: 0.42, y: 0.50), spread: 0.22, width: 220),
    ]

    static let standard = all[0]

    static func named(_ id: String?) -> SofaStyle { all.first { $0.id == id } ?? standard }

    var image: NSImage { Self.images[id] ?? NSImage() }

    private static let images: [String: NSImage] = {
        var out: [String: NSImage] = [:]
        for s in all {
            if let url = Bundle.main.url(forResource: "sofa-\(s.id)", withExtension: "png"), let img = NSImage(contentsOf: url) {
                out[s.id] = img
            } else if let img = NSImage(contentsOfFile: "Resources/sofa-\(s.id).png") {
                out[s.id] = img   // running from .build (snapshots): use the file from the repo
            }
        }
        return out
    }()

    // MARK: Geometry in the sofa window's canvas (top-left origin)

    /// All pieces share one scale, matched to Rugonmac's rugs: a rug at medium size is ~547pt wide,
    /// which stands for a big 4 m living-room rug. So an armchair (~95 cm) covers about a quarter of the
    /// rug's width and a two-seater (~2.2 m) a bit over half, at every size.
    static let pointsPerCm: CGFloat = 547.0 / 400

    /// Free space around the chair inside its window: the glow when something is dragged over it,
    /// the slight grow, and the floor shadow all need room to fade out before the window's edge cuts them.
    static let margin: CGFloat = 48

    /// The chair stands at the bottom of the canvas, with room above it for the pile and around it for the shadow.
    var chair: CGRect {
        let px = image.size
        let aspect = px.height > 0 ? px.width / px.height : 1.2
        let w = width * Self.pointsPerCm
        return CGRect(x: Self.margin, y: 72, width: w, height: w / aspect)
    }

    /// The sofa window's size at medium size.
    var canvas: CGSize {
        CGSize(width: chair.maxX + Self.margin, height: chair.maxY + Self.margin)
    }

    var seatPoint: CGPoint {
        CGPoint(x: chair.minX + chair.width * seat.x, y: chair.minY + chair.height * seat.y)
    }

    var pileSpread: CGFloat { chair.width * spread }

    /// Where the count badge sits: on the chair's own top-right corner (the point of its outline furthest
    /// up and to the right), nudged a little inward. Same rule for every chair, found from the picture.
    var badgePoint: CGPoint {
        let a = Self.badgeAnchors[id] ?? CGPoint(x: 0.9, y: 0.1)
        return CGPoint(x: chair.minX + chair.width * a.x - 4, y: chair.minY + chair.height * a.y + 4)
    }

    private static let badgeAnchors: [String: CGPoint] = {
        var out: [String: CGPoint] = [:]
        for s in all {
            guard let cg = s.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            // look at a small copy: enough to find a corner
            let w = 120, h = max(1, Int(CGFloat(w) * CGFloat(cg.height) / CGFloat(cg.width)))
            var px = [UInt8](repeating: 0, count: w * h * 4)
            guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            var best = (score: -Int.max, x: 0, y: 0)
            for y in 0..<h {   // the buffer's first row is the picture's top
                for x in 0..<w where px[(y * w + x) * 4 + 3] > 128 {
                    let score = x - y   // further right and further up wins
                    if score > best.score { best = (score, x, y) }
                }
            }
            out[s.id] = CGPoint(x: CGFloat(best.x) / CGFloat(w), y: CGFloat(best.y) / CGFloat(h))
        }
        return out
    }()
}

/// Same three sizes as Rugonmac's rugs, with the same steps (its rugs have 22, 30 and 40 rows),
/// so a chair keeps its proportion to the rug when both are set to the same size.
enum SofaSize: Int, CaseIterable, Identifiable {
    case small, medium, large
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }
    var longTitle: String {
        switch self {
        case .small: "Klein"
        case .medium: "Mittel"
        case .large: "Groß"
        }
    }
    var scale: CGFloat {
        switch self {
        case .small: 21.0 / 29
        case .medium: 1
        case .large: 39.0 / 29
        }
    }
}
