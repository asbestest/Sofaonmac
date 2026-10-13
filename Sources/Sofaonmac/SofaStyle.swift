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

    /// The chair stands at the bottom of the canvas, with room above it for the pile and around it for the shadow.
    var chair: CGRect {
        let px = image.size
        let aspect = px.height > 0 ? px.width / px.height : 1.2
        let w = width * Self.pointsPerCm
        return CGRect(x: 20, y: 60, width: w, height: w / aspect)
    }

    /// The sofa window's size at medium size.
    var canvas: CGSize {
        CGSize(width: chair.maxX + 20, height: chair.maxY + 18)
    }

    var seatPoint: CGPoint {
        CGPoint(x: chair.minX + chair.width * seat.x, y: chair.minY + chair.height * seat.y)
    }

    var pileSpread: CGFloat { chair.width * spread }
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
