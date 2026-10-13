import SwiftUI

final class FanState: ObservableObject {
    @Published var open = false
}

/// Full-screen overlay: the pile spread out above the sofa like a hand of cards.
/// Click a card to open the file, drag it out to put it anywhere, or send it back where it came from.
struct FanView: View {
    @ObservedObject var model: SofaModel
    @ObservedObject var state: FanState
    /// Top of the chair, in this view's coordinates (top-left origin).
    let sofaPoint: CGPoint
    let onOpen: (SofaItem) -> Void
    let onPutBack: (SofaItem) -> Void
    let onPutBackAll: () -> Void
    let onDragOut: () -> Void
    let onDragEnded: () -> Void
    let onClose: () -> Void

    @State private var hovered: UUID?

    var body: some View {
        GeometryReader { geo in
            let layout = FanLayout(count: model.items.count, sofa: sofaPoint, bounds: geo.size)
            ZStack(alignment: .topLeading) {
                Color.black.opacity(state.open ? 0.28 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                ForEach(Array(model.items.enumerated()), id: \.element.id) { i, item in
                    card(item, slot: layout.slot(i), index: i, layout: layout)
                }

                if model.items.count > 1 {
                    Button(action: onPutBackAll) {
                        Label("Alles zurücklegen", systemImage: "arrow.uturn.backward")
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

    private func card(_ item: SofaItem, slot: FanLayout.Slot, index: Int, layout: FanLayout) -> some View {
        let p = model.preview(of: item)
        let size = Thumb.fit(p, maxWidth: layout.cardWidth, maxHeight: layout.cardWidth * 0.8)
        let isHover = hovered == item.id
        // hovered cards slide a bit further out along their ray
        let push: CGFloat = isHover ? 26 : 0
        let target = CGPoint(x: slot.center.x + sin(slot.angle) * push, y: slot.center.y - cos(slot.angle) * push)
        let pos = state.open ? target : CGPoint(x: sofaPoint.x + item.spread * 20, y: sofaPoint.y + 50)
        let showLabel = state.open && (isHover || model.items.count <= 5)

        return VStack(spacing: 6) {
            Thumb(preview: p, width: size.width, height: size.height, corner: 10)
                .overlay(FileDragSource(url: model.url(of: item), image: p.image,
                                        onClick: { onOpen(item) },
                                        onDragBegan: onDragOut,
                                        onDragEnded: { _ in onDragEnded() }))
            Text(item.fileName).lineLimit(1).truncationMode(.middle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .frame(maxWidth: layout.cardWidth)
                .opacity(showLabel ? 1 : 0)
            Button { onPutBack(item) } label: {
                Label("Zurücklegen", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .opacity(isHover && state.open ? 1 : 0)
        }
        .contentShape(Rectangle())
        .scaleEffect(state.open ? (isHover ? 1.1 : 1) : 0.3)
        .rotationEffect(state.open ? .radians(Double(slot.angle)) : .degrees(item.tilt))
        .position(pos)
        .zIndex(isHover ? 1000 : Double(index))
        .onHover { hovered = $0 ? item.id : (hovered == item.id ? nil : hovered) }
        .help("Klicken zum Öffnen, rausziehen zum Ablegen")
        .animation(.spring(response: 0.42, dampingFraction: 0.72).delay(state.open ? Double(index) * 0.025 : 0),
                   value: state.open)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHover)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}

/// Cards sit on an arc around a pivot below the sofa, the arc wide enough to keep neighbours apart.
struct FanLayout {
    struct Slot { let center: CGPoint; let angle: CGFloat }

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

    var topY: CGFloat { pivot.y - radius - cardWidth * 0.5 }
}
