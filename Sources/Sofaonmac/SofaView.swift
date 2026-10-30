import SwiftUI

/// The sofa window's content: the chair plus the pile of files on its seat.
/// Laid out on a fixed canvas (top-left origin); there's room above the chair for the pile to grow.
struct SofaView: View {

    @ObservedObject var model: SofaModel
    var showsBadge = true
    @State private var squash = false

    var body: some View {
        let s = model.size.scale
        ZStack(alignment: .topLeading) {
            content
                .scaleEffect(s, anchor: .topLeading)
            // drawn outside the scaling, so it's always crisp and always the same size
            if showsBadge && !model.items.isEmpty {
                let p = model.style.badgePoint
                badge.position(x: p.x * s, y: p.y * s)
            }
        }
        .frame(width: model.style.canvas.width * s, height: model.style.canvas.height * s, alignment: .topLeading)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.size)
    }

    private var content: some View {
        let chair = model.style.chair
        return ZStack(alignment: .topLeading) {
            floorShadow(chair)
            Image(nsImage: model.style.image).resizable().interpolation(.high)
                .frame(width: chair.width, height: chair.height)
                .position(x: chair.midX, y: chair.midY)
                .shadow(color: model.dropHover ? Color(red: 1, green: 0.88, blue: 0.5).opacity(0.95) : .clear, radius: 16)
            pile
        }
        .frame(width: model.style.canvas.width, height: model.style.canvas.height, alignment: .topLeading)
        .scaleEffect(x: squash ? 1.04 : (model.dropHover ? 1.05 : 1),
                     y: squash ? 0.94 : (model.dropHover ? 1.05 : 1), anchor: .bottom)
        .offset(y: model.dragActive && !model.dropHover ? -4 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: model.dropHover)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: model.dragActive)
        .onChange(of: model.landings) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.9)) { squash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.35)) { squash = false }
            }
        }
    }

    /// A shadow that runs along the chair's actual bottom outline (feet, edges, slanted photos alike):
    /// a dark, tight contact shadow right at the outline and a wide, soft one around it.
    /// It's drawn behind the chair, so only the part below the outline shows.
    private func floorShadow(_ chair: CGRect) -> some View {
        let profile = model.style.bottomProfile.map {
            CGPoint(x: chair.minX + chair.width * $0.x, y: chair.minY + chair.height * $0.y)
        }
        func band(depth: CGFloat, inset: CGFloat) -> Path {
            Path { p in
                guard let first = profile.first, let last = profile.last else { return }
                p.move(to: CGPoint(x: first.x + inset, y: first.y - depth * 0.6))
                for pt in profile { p.addLine(to: CGPoint(x: pt.x, y: pt.y - depth * 0.6)) }
                p.addLine(to: CGPoint(x: last.x - inset, y: last.y + depth * 0.4))
                for pt in profile.reversed() { p.addLine(to: CGPoint(x: pt.x, y: pt.y + depth * 0.4)) }
                p.closeSubpath()
            }
        }
        return ZStack {
            band(depth: 22, inset: -10).fill(.black.opacity(0.16)).blur(radius: 12)
            band(depth: 8, inset: 4).fill(.black.opacity(0.32)).blur(radius: 4)
        }
        .allowsHitTesting(false)
    }

    private var pile: some View {
        let shown = Array(model.items.suffix(14))
        return ForEach(Array(shown.enumerated()), id: \.element.id) { i, item in
            let p = model.preview(of: item)
            // smaller chairs get smaller things, so the pile doesn't swallow them
            let k = min(1, model.style.chair.height / 190)
            let size = Thumb.fit(p, maxWidth: 58 * k, maxHeight: 48 * k)
            Thumb(preview: p, width: size.width, height: size.height, corner: 3, lying: true)
                // lying flat on the cushion, seen from slightly above like the chair
                .rotationEffect(.degrees(item.tilt))
                .rotation3DEffect(.degrees(58), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.35)
                .position(x: model.style.seatPoint.x + item.spread * model.style.pileSpread,
                          y: model.style.seatPoint.y - CGFloat(i) * 4)
                .transition(.asymmetric(insertion: .scale(scale: 1.5).combined(with: .opacity),
                                        removal: .scale(scale: 0.6).combined(with: .opacity)))
        }
    }

    /// Like a Dock badge: fixed size, white on red, a thin white ring so it reads on any upholstery.
    private var badge: some View {
        Text("\(model.items.count)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(Color(red: 0.92, green: 0.26, blue: 0.21)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
            .fixedSize()
    }
}

/// A file's picture: thumbnails get a thin white border like a photo, icons stand on their own.
struct Thumb: View {
    let preview: Preview
    let width: CGFloat
    let height: CGFloat
    var corner: CGFloat = 8
    /// Lying on a cushion: a tight shadow right under it instead of one that makes it float.
    var lying = false

    static func fit(_ p: Preview, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        if !p.isThumbnail { let s = min(maxWidth, maxHeight) * 1.05; return CGSize(width: s, height: s) }
        let w = min(maxWidth, maxHeight * p.aspect)
        return CGSize(width: w, height: w / p.aspect)
    }

    var body: some View {
        if preview.isThumbnail {
            Image(nsImage: preview.image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.95), lineWidth: max(1.5, width / 45)))
                .shadow(color: .black.opacity(lying ? 0.45 : 0.35), radius: lying ? 1.2 : max(2, width / 40), y: lying ? 0.8 : max(1, width / 80))
        } else {
            Image(nsImage: preview.image).resizable().aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(lying ? 0.4 : 0.3), radius: lying ? 1 : max(1.5, width / 50), y: lying ? 0.6 : max(1, width / 90))
        }
    }
}
