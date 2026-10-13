import SwiftUI

let accent = Color(red: 0.95, green: 0.42, blue: 0.30)

/// One chair in the picker: its picture on a soft backdrop, the name below, a check when chosen.
/// Same look as Rugonmac's pattern cards.
struct SofaCard: View {
    let style: SofaStyle
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.47, blue: 0.95), Color(red: 0.22, green: 0.16, blue: 0.58)],
                                         startPoint: .top, endPoint: .bottom))
                Image(nsImage: style.image).resizable().aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 16)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                    .scaleEffect(hover ? 1.07 : 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                Text(style.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, accent)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 100, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? accent : .white.opacity(0.10), lineWidth: selected ? 2 : 1))
            .shadow(color: (selected ? accent : .black).opacity(selected ? 0.3 : 0.15), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .help(style.subtitle)
        .onHover { h in withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { hover = h } }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
    }
}

/// A horizontally scrolling row of chair cards. The edges fade out so it's clear there's more.
struct SofaPicker: View {
    @ObservedObject var model: SofaModel
    var inset: CGFloat = 12

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SofaStyle.all) { style in
                        SofaCard(style: style, selected: model.style == style) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { model.style = style }
                            withAnimation(.snappy) { proxy.scrollTo(style.id, anchor: .center) }
                        }
                        .id(style.id)
                    }
                }
                .padding(.horizontal, inset)
                .padding(.vertical, 6)   // room for the selection shadow
            }
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: inset)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: inset)
                }
            )
            .onAppear { proxy.scrollTo(model.style.id, anchor: .center) }
        }
    }
}

/// The chairs at the top of the menu bar menu.
struct MenuSofaPicker: View {
    @ObservedObject var model: SofaModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sessel")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
            SofaPicker(model: model)
        }
        .padding(.vertical, 4)
        .frame(width: 300)
    }
}
