import SwiftUI

/// Same look as Rugonmac's settings (and the menu bar menu): translucent menu material,
/// small grey section labels, plain rows and hairline separators.
struct SettingsView: View {
    @ObservedObject var model: SofaModel
    let onResetPosition: () -> Void
    let onPutBackAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 12)
            separator

            SectionLabel(L("Chair"))
            SofaPicker(model: model)
                .padding(.bottom, 2)
            Row(L("Size")) {
                Picker("", selection: $model.size) {
                    ForEach(SofaSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 104)
            }
            Row(L("Position"), caption: L("Drag the chair with the mouse")) {
                Button(L("To the corner"), action: onResetPosition).controlSize(.small)
            }
            separator

            SectionLabel(L("Options"))
            Row(L("Always in front"), caption: model.alwaysOnTop ? L("Stands in front of all windows") : L("Comes forward when you drag something")) {
                Toggle("", isOn: $model.alwaysOnTop).toggleStyle(.switch).labelsHidden().controlSize(.mini)
            }
            Row(L("Sofa folder"), caption: L("Everything on the sofa is here")) {
                Button { model.showFolder() } label: {
                    Label(L("In Finder"), systemImage: "arrow.up.right").labelStyle(.titleAndIcon)
                }
                .controlSize(.small)
            }
            Row(L("Start at login"), caption: model.loginError ?? L("Back after a restart")) {
                Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch).labelsHidden().controlSize(.mini)
            }
            separator

            HStack {
                Button(action: onPutBackAll) { Label(L("Put everything back"), systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.plain)
                    .disabled(model.items.isEmpty)
                Spacer()
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")")
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
        .background(MenuMaterial().ignoresSafeArea())
        .tint(accent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sofaonmac").font(.system(size: 15, weight: .semibold))
                Text((model.visible ? L("Standing") : L("Put away")) + " · " + model.countText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $model.visible).toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
    }

    private var separator: some View {
        Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1).padding(.horizontal, 10).padding(.vertical, 5)
    }
}

/// Small grey heading, like the "Chair" label in the menu.
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
}

private struct Row<Trailing: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let trailing: Trailing

    init(_ title: String, caption: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.caption = caption
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13)).lineLimit(1)
                if let caption {
                    Text(caption).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}

/// The translucent material macOS uses for menus.
private struct MenuMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .menu
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
