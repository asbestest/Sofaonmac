import SwiftUI

final class FanState: ObservableObject {
    @Published var open = false
    /// The card under the mouse; set by FanHitView, which does the fan's mouse handling.
    @Published var hovered: UUID?
}

/// Full-screen overlay: the pile spread out above the sofa like a hand of cards.
/// Click a card to open the file, drag it out to put it anywhere, or send it back where it came from.
///
/// The cards themselves only draw. Clicks, drags and hover on them are handled by FanHitView on top,
/// which tests against the same geometry (rotated, overlapping cards) — the same on every macOS version.
struct FanView: View {
    @ObservedObject var model: SofaModel
    @ObservedObject var state: FanState
    /// Top of the chair, in this view's coordinates (top-left origin).
    let sofaPoint: CGPoint
    let onPutBack: (SofaItem) -> Void
    let onPutBackAll: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = FanLayout(count: model.items.count, sofa: sofaPoint, bounds: geo.size)
            let cards = layout.cards(model.items, preview: model.preview(of:))
            ZStack(alignment: .topLeading) {
                Color.black.opacity(state.open ? 0.28 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                ForEach(cards) { card($0, layout: layout) }

                if model.items.count > 1 {
                    Button(action: onPutBackAll) {
                        Label(L("Put everything back"), systemImage: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .position(x: layout.pivot.x, y: max(30, layout.topY - 34))
                    .opacity(state.open ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func card(_ c: FanLayout.Card, layout: FanLayout) -> some View {
        let item = c.item
        let isHover = state.hovered == item.id
        let pos = state.open ? c.center(hovered: isHover) : CGPoint(x: sofaPoint.x + item.spread * 20, y: sofaPoint.y + 50)
        let showLabel = state.open && (isHover || model.items.count <= 5)

        return Thumb(preview: model.preview(of: item), width: c.size.width, height: c.size.height, corner: 10)
            .allowsHitTesting(false)
            // name and "put back" hang below the picture; the picture's middle stays the card's middle
            .overlay(alignment: .top) {
                VStack(spacing: 6) {
                    Text(item.fileName).lineLimit(1).truncationMode(.middle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .opacity(showLabel ? 1 : 0)
                        .allowsHitTesting(false)
                    Button { onPutBack(item) } label: {
                        Label(L("Put back"), systemImage: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHover && state.open ? 1 : 0)
                    .allowsHitTesting(isHover && state.open)
                }
                .frame(width: layout.cardWidth)
                .offset(y: c.size.height + 6)
            }
            .scaleEffect(state.open ? (isHover ? FanLayout.hoverScale : 1) : 0.3)
            .rotationEffect(state.open ? .radians(Double(c.angle)) : .degrees(item.tilt))
            .position(pos)
            .zIndex(isHover ? 1000 : Double(c.index))
            .animation(.spring(response: 0.42, dampingFraction: 0.72).delay(state.open ? Double(c.index) * 0.025 : 0),
                       value: state.open)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHover)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}

/// Cards sit on an arc around a pivot below the sofa, the arc wide enough to keep neighbours apart.
struct FanLayout {
    struct Slot { let center: CGPoint; let angle: CGFloat }

    /// One card's place in the open fan. `center` is the middle of the picture.
    struct Card: Identifiable {
        let item: SofaItem
        let index: Int
        let center: CGPoint
        let size: CGSize
        let angle: CGFloat
        var id: UUID { item.id }

        /// Hovered cards slide a bit further out along their ray.
        func center(hovered: Bool) -> CGPoint {
            guard hovered else { return center }
            return CGPoint(x: center.x + sin(angle) * FanLayout.hoverPush, y: center.y - cos(angle) * FanLayout.hoverPush)
        }

        /// Is `p` on this card? `below` extends the card downward (for the name and button under it).
        func contains(_ p: CGPoint, hovered: Bool, below: CGFloat = 0) -> Bool {
            let c = center(hovered: hovered)
            let s = hovered ? FanLayout.hoverScale : 1
            // into the card's own, unrotated coordinates
            let dx = p.x - c.x, dy = p.y - c.y
            let x = dx * cos(angle) + dy * sin(angle)
            let y = -dx * sin(angle) + dy * cos(angle)
            return abs(x) <= size.width * s / 2 && y >= -size.height * s / 2 && y <= size.height * s / 2 + below * s
        }
    }

    static let hoverPush: CGFloat = 26
    static let hoverScale: CGFloat = 1.1

    let count: Int
    let cardWidth: CGFloat
    let radius: CGFloat
    let step: CGFloat
    let pivot: CGPoint

    init(count: Int, sofa: CGPoint, bounds: CGSize) {
        self.count = count
        cardWidth = count <= 5 ? 200 : count <= 9 ? 170 : 140
        radius = max(500, bounds.height * 0.8)
        // neighbours overlap a little, like a real hand of cards; the whole hand spans at most ~75°
        let wanted = cardWidth * 0.75 / radius
        step = count > 1 ? min(wanted, 1.3 / CGFloat(count - 1)) : 0
        let half = radius * sin(step * CGFloat(max(count - 1, 0)) / 2) + cardWidth * 0.6
        let x = min(max(sofa.x, half + 20), bounds.width - half - 20)
        // the middle card floats ~300pt above the sofa, but the whole hand stays on screen
        pivot = CGPoint(x: x, y: max(sofa.y - 300, cardWidth * 0.5 + 90) + radius)
    }

    func slot(_ i: Int) -> Slot {
        let a = (CGFloat(i) - CGFloat(count - 1) / 2) * step
        return Slot(center: CGPoint(x: pivot.x + radius * sin(a), y: pivot.y - radius * cos(a)), angle: a)
    }

    func cards(_ items: [SofaItem], preview: (SofaItem) -> Preview) -> [Card] {
        items.enumerated().map { i, item in
            let s = slot(i)
            return Card(item: item, index: i, center: s.center,
                        size: Thumb.fit(preview(item), maxWidth: cardWidth, maxHeight: cardWidth * 0.8), angle: s.angle)
        }
    }

    var topY: CGFloat { pivot.y - radius - cardWidth * 0.5 }
}
