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

    /// The chair's own outline, squashed flat onto the floor and blurred: a contact shadow that fits every
    /// shape (legs, arms, a lopsided bean bag), plus a wide, very soft one around it.
    private func floorShadow(_ chair: CGRect) -> some View {
        let silhouette = Image(nsImage: model.style.image).resizable().renderingMode(.template)
        return ZStack {
            silhouette
                .foregroundStyle(.black.opacity(0.22))
                .frame(width: chair.width * 1.04, height: chair.height)
                .scaleEffect(x: 1, y: 0.16, anchor: .bottom)
                .blur(radius: 14)
            silhouette
                .foregroundStyle(.black.opacity(0.4))
                .frame(width: chair.width * 0.96, height: chair.height)
                .scaleEffect(x: 1, y: 0.06, anchor: .bottom)
                .blur(radius: 4)
        }
        .frame(width: chair.width, height: chair.height)
        // photos are taken from slightly above: the floor contact sits a bit above the lowest pixel
        .position(x: chair.midX + 4, y: chair.midY - chair.height * 0.03)
        .allowsHitTesting(false)
    }

    private var pile: some View {
        let shown = Array(model.items.suffix(14))
        return ForEach(Array(shown.enumerated()), id: \.element.id) { i, item in
            let p = model.preview(of: item)
            // flat sofas get smaller things, so the pile doesn't swallow them
            let k = min(1, model.style.chair.height / 190)
            let size = Thumb.fit(p, maxWidth: 70 * k, maxHeight: 58 * k)
            Thumb(preview: p, width: size.width, height: size.height, corner: 3)
                // lying on the cushion, not standing on it
                .rotationEffect(.degrees(item.tilt))
                .rotation3DEffect(.degrees(38), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
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
                .shadow(color: .black.opacity(0.35), radius: max(2, width / 40), y: max(1, width / 80))
        } else {
            Image(nsImage: preview.image).resizable().aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.3), radius: max(1.5, width / 50), y: max(1, width / 90))
        }
    }
}
