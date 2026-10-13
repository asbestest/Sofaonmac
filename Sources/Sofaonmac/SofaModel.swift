import AppKit
import QuickLookThumbnailing
import ServiceManagement
import SwiftUI

/// One file (or folder) lying on the sofa.
struct SofaItem: Identifiable, Codable, Equatable {
    let id: UUID
    /// Name inside the sofa folder.
    var fileName: String
    /// Where it came from, so it can go back there.
    let originalPath: String
    let addedAt: Date
    /// How it landed on the pile: a little tilt and sideways offset, fixed for its lifetime.
    let tilt: Double
    let offset: CGFloat

    /// Sideways position on the seat, -1…1 (older versions stored points, up to ±42).
    var spread: CGFloat { abs(offset) > 1 ? offset / 42 : offset }

    static func new(fileName: String, originalPath: String) -> SofaItem {
        SofaItem(id: UUID(), fileName: fileName, originalPath: originalPath, addedAt: Date(),
                 tilt: Double.random(in: -16...16), offset: CGFloat.random(in: -1...1))
    }
}

/// What a file looks like on the sofa: a real thumbnail (framed like a photo) or just its icon.
struct Preview {
    let image: NSImage
    let isThumbnail: Bool
    var aspect: CGFloat { image.size.height > 0 ? image.size.width / image.size.height : 1 }
}

/// Everything on the sofa. Files really move: into the sofa folder when thrown,
/// back to where they came from when picked up again.
final class SofaModel: ObservableObject {
    @Published var items: [SofaItem] = []
    @Published private(set) var previews: [UUID: Preview] = [:]
    /// Something is being dragged somewhere on screen.
    @Published var dragActive = false
    /// …and it's over the sofa right now.
    @Published var dropHover = false
    /// Bumped every time something lands, so the sofa can bounce.
    @Published var landings = 0

    // MARK: Settings (same set as Rugonmac's)

    @Published var style = SofaStyle.named(UserDefaults.standard.string(forKey: "sofaStyle")) {
        didSet {
            UserDefaults.standard.set(style.id, forKey: "sofaStyle")
            // picking a chair also puts it up if it was put away
            if !visible { visible = true }
        }
    }
    @Published var size = SofaSize(rawValue: UserDefaults.standard.object(forKey: "sofaSize") as? Int ?? 1) ?? .medium {
        didSet { UserDefaults.standard.set(size.rawValue, forKey: "sofaSize") }
    }
    /// The chair stands on the desktop; put away it's hidden (the things on it stay in the sofa folder).
    @Published var visible = UserDefaults.standard.object(forKey: "sofaVisible") as? Bool ?? true {
        didSet { UserDefaults.standard.set(visible, forKey: "sofaVisible") }
    }
    /// Normally the chair stands behind all windows and only comes forward while something is dragged.
    @Published var alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop") {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop") }
    }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Geht nur, wenn die App im Programme-Ordner liegt."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// "3 Sachen drauf"
    var countText: String {
        switch items.count {
        case 0: "leer"
        case 1: "1 Sache drauf"
        case let n: "\(n) Sachen drauf"
        }
    }

    let folder: URL
    private let manifest: URL
    private let fm = FileManager.default
    private var syncTimer: Timer?

    static var defaultFolder: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sofaonmac/Auf dem Sofa", isDirectory: true)
    }
    private static let fm = FileManager.default

    init(folder: URL = SofaModel.defaultFolder) {
        self.folder = folder
        manifest = folder.deletingLastPathComponent().appendingPathComponent("sofa.json")
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: manifest),
           let saved = try? JSONDecoder().decode([SofaItem].self, from: data) {
            items = saved
        }
        sync()
        items.forEach(loadPreview)
        // Files can also leave (dragged out, deleted in Finder) or arrive (put into the folder by hand).
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sync() }
    }

    func url(of item: SofaItem) -> URL { folder.appendingPathComponent(item.fileName) }

    func preview(of item: SofaItem) -> Preview {
        if let p = previews[item.id] { return p }
        // icons default to 32pt; ask for a big one so it stays sharp in the fan
        let icon = NSWorkspace.shared.icon(forFile: url(of: item).path)
        icon.size = NSSize(width: 512, height: 512)
        return Preview(image: icon, isThumbnail: false)
    }

    // MARK: Throwing things on

    /// Moves (or copies) the files onto the sofa. Returns how many landed.
    @discardableResult
    func add(urls: [URL], move: Bool) -> Int {
        var landed: [SofaItem] = []
        var failed = false
        for src in urls {
            // dragged from the fan back onto the sofa: it's already here
            if src.standardizedFileURL.deletingLastPathComponent().path == folder.standardizedFileURL.path { continue }
            let dest = unique(folder.appendingPathComponent(src.lastPathComponent))
            do {
                if move { try fm.moveItem(at: src, to: dest) } else { try fm.copyItem(at: src, to: dest) }
                landed.append(.new(fileName: dest.lastPathComponent, originalPath: src.path))
            } catch {
                NSLog("Sofaonmac: couldn't take \(src.path): \(error.localizedDescription)")
                failed = true
            }
        }
        if failed { NSSound.beep() }
        land(landed)
        return landed.count
    }

    /// Things that aren't files yet (a picture or some text dragged out of an app) become one, "from the desktop".
    @discardableResult
    func add(data: Data, named name: String) -> Bool {
        let dest = unique(folder.appendingPathComponent(name))
        guard (try? data.write(to: dest)) != nil else { NSSound.beep(); return false }
        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        land([.new(fileName: dest.lastPathComponent, originalPath: desktop.appendingPathComponent(name).path)])
        return true
    }

    private func land(_ new: [SofaItem]) {
        guard !new.isEmpty else { return }
        new.forEach(loadPreview)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            items.append(contentsOf: new)
            landings += 1
        }
        save()
    }

    // MARK: Taking things off

    /// Back to where it came from; if that folder is gone, onto the desktop.
    func putBack(_ item: SofaItem) {
        let original = URL(fileURLWithPath: item.originalPath)
        var dir = original.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) { dir = fm.urls(for: .desktopDirectory, in: .userDomainMask)[0] }
        let dest = unique(dir.appendingPathComponent(original.lastPathComponent))
        do {
            try fm.moveItem(at: url(of: item), to: dest)
        } catch {
            NSLog("Sofaonmac: couldn't put back \(item.fileName): \(error.localizedDescription)")
            NSSound.beep()
            return
        }
        remove([item.id])
    }

    func putBackAll() {
        for item in items { putBack(item) }
    }

    func open(_ item: SofaItem) {
        NSWorkspace.shared.open(url(of: item))
    }

    func showFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private func remove(_ ids: Set<UUID>) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            items.removeAll { ids.contains($0.id) }
        }
        ids.forEach { previews[$0] = nil }
        save()
    }

    // MARK: Bookkeeping

    /// Makes the list match the folder: gone files leave the sofa, new files in the folder join it.
    func sync() {
        let gone = Set(items.filter { !fm.fileExists(atPath: url(of: $0).path) }.map(\.id))
        if !gone.isEmpty { remove(gone) }

        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        let known = Set(items.map(\.fileName))
        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let strays = names.filter { !$0.hasPrefix(".") && !known.contains($0) }
            .map { SofaItem.new(fileName: $0, originalPath: desktop.appendingPathComponent($0).path) }
        if !strays.isEmpty { land(strays) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: manifest) }
    }

    private func unique(_ url: URL) -> URL {
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        for n in 2... {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            let candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    private func loadPreview(_ item: SofaItem) {
        Self.makePreview(url(of: item)) { [weak self] p in
            DispatchQueue.main.async { if let p { self?.previews[item.id] = p } }
        }
    }

    /// Quick Look thumbnail for documents and pictures; nil means "use the icon".
    static func makePreview(_ url: URL, done: @escaping (Preview?) -> Void) {
        let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 320, height: 320), scale: 2,
                                               representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            done(rep.map { Preview(image: $0.nsImage, isThumbnail: true) })
        }
    }
}
