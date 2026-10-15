import AppKit
import Combine
import SwiftUI

/// Owns the windows: the sofa on the desktop and the fan overlay.
final class SofaController {
    let model: SofaModel
    private let watcher = DragWatcher()
    private var sofa: SofaPanel!
    private var fan: FanPanel?
    private let fanState = FanState()
    private let defaults = UserDefaults.standard
    private var subscriptions: Set<AnyCancellable> = []

    private var restingLevel: NSWindow.Level {
        // one above Rugonmac's rug, so the chair always stands on the rug
        model.alwaysOnTop ? .floating : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
    }

    /// The window's size for the current chair size.
    private var windowSize: CGSize {
        CGSize(width: model.style.canvas.width * model.size.scale, height: model.style.canvas.height * model.size.scale)
    }

    init(model: SofaModel) {
        self.model = model
        sofa = SofaPanel(model: model)
        sofa.onClick = { [weak self] in self?.toggleFan() }
        sofa.onMoved = { [weak self] origin in
            self?.defaults.set(NSStringFromPoint(origin), forKey: "sofaOrigin")
        }
        sofa.level = restingLevel
        sofa.setContentSize(windowSize)
        placeSofa(reset: false)
        if model.visible { sofa.orderFrontRegardless() }

        // settings changed in the menu or the settings window
        model.$visible.dropFirst().removeDuplicates().sink { [weak self] on in
            guard let self else { return }
            if on { sofa.orderFrontRegardless() } else { closeFan(); sofa.orderOut(nil) }
        }.store(in: &subscriptions)
        model.$alwaysOnTop.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self.map { $0.sofa.level = $0.restingLevel } }
        }.store(in: &subscriptions)
        // a bigger chair or another piece of furniture: grow and shrink around its feet
        model.$size.dropFirst().removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.resize() }
        }.store(in: &subscriptions)
        model.$style.dropFirst().removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.resize() }
        }.store(in: &subscriptions)

        watcher.onBegan = { [weak self] in
            guard let self, fan == nil, model.visible else { return }
            sofa.level = .floating
            sofa.orderFrontRegardless()
            model.dragActive = true
        }
        watcher.onEnded = { [weak self] in
            guard let self else { return }
            model.dragActive = false
            model.dropHover = false
            sofa.level = restingLevel
        }
        watcher.start()
    }

    func placeSofa(reset: Bool) {
        if !reset, let s = defaults.string(forKey: "sofaOrigin") {
            let o = NSPointFromString(s)
            if NSScreen.screens.contains(where: { $0.frame.intersects(CGRect(origin: o, size: windowSize)) }) {
                sofa.setFrameOrigin(o)
                return
            }
        }
        guard let vf = NSScreen.main?.visibleFrame else { return }
        sofa.setFrameOrigin(NSPoint(x: vf.maxX - windowSize.width - 20, y: vf.minY + 4))
        defaults.removeObject(forKey: "sofaOrigin")
    }

    private func resize() {
        let old = sofa.frame
        let new = windowSize
        var frame = CGRect(x: old.midX - new.width / 2, y: old.minY, width: new.width, height: new.height)
        // a long sofa in the corner shouldn't stick out of the screen
        if let vf = (sofa.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, vf.minX), vf.maxX - frame.width)
        }
        sofa.setFrame(frame, display: true)
        defaults.set(NSStringFromPoint(sofa.frame.origin), forKey: "sofaOrigin")
    }

    // MARK: Fan

    func toggleFan() {
        fan == nil ? openFan() : closeFan()
    }

    func openFan() {
        guard fan == nil else { return }
        guard !model.items.isEmpty else {
            sofa.shake()
            return
        }
        guard let screen = sofa.screen ?? NSScreen.main else { return }
        let f = screen.frame
        let chair = model.style.chair, s = model.size.scale
        let chairTop = CGPoint(x: sofa.frame.minX + chair.midX * s - f.minX, y: f.maxY - sofa.frame.maxY + chair.minY * s)
        let view = FanView(model: model, state: fanState, sofaPoint: chairTop,
                           onOpen: { [weak self] item in self?.model.open(item); self?.closeFan() },
                           onPutBack: { [weak self] item in self?.putBack(item) },
                           onPutBackAll: { [weak self] in self?.putBackAll() },
                           onDragOut: { [weak self] in self?.dragOut() },
                           // moved out by Finder: off the pile right away, not on the next check
                           onDragEnded: { [weak self] in self?.dragOutEnded() },
                           onClose: { [weak self] in self?.closeFan() })
        let panel = FanPanel(frame: f, content: view)
        panel.onCancel = { [weak self] in self?.closeFan() }
        fan = panel
        fanState.open = false
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { self.fanState.open = true }
    }

    func closeFan() {
        guard let panel = fan else { return }
        fan = nil
        fanState.open = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { panel.orderOut(nil) }
    }

    private func putBack(_ item: SofaItem) {
        model.putBack(item)
        if model.items.isEmpty { closeFan() }
    }

    func putBackAll() {
        if let panel = fan {
            fan = nil
            panel.orderOut(nil)
        }
        model.putBackAll()
    }

    /// A card is being dragged out: get the overlay out of the way so the drop reaches whatever is below.
    private func dragOut() {
        guard let panel = fan else { return }
        panel.ignoresMouseEvents = true
        panel.animator().alphaValue = 0
    }

    /// …and once it's dropped, close the fan for good. If Finder moved the file, it leaves the pile right away.
    private func dragOutEnded() {
        model.sync()
        guard let panel = fan else { return }
        fan = nil
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        fanState.open = false
    }
}

// MARK: - Windows

/// The borderless window the sofa stands in. Click opens the fan, drag moves the sofa,
/// and anything dropped onto it lands on the pile.
final class SofaPanel: NSPanel {
    var onClick: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?

    init(model: SofaModel) {
        super.init(contentRect: CGRect(origin: .zero, size: model.style.canvas),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let host = SofaHostView(rootView: SofaView(model: model))
        host.panel = self
        host.model = model
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func shake() {
        let o = frame.origin
        let keys: [CGFloat] = [-8, 7, -5, 4, -2, 0]
        for (i, dx) in keys.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                self.setFrameOrigin(NSPoint(x: o.x + dx, y: o.y))
            }
        }
    }
}

/// Handles the mouse and drops itself instead of SwiftUI:
/// a short press is a click, anything further moves the sofa.
final class SofaHostView: NSHostingView<SofaView> {
    weak var panel: SofaPanel?
    weak var model: SofaModel?
    private var downAt: NSPoint?
    private var originAtDown: NSPoint = .zero
    private var moved = false

    required init(rootView: SofaView) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL, .URL, .tiff, .png, .string])
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        downAt = NSEvent.mouseLocation
        originAtDown = window?.frame.origin ?? .zero
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downAt, let window else { return }
        let p = NSEvent.mouseLocation
        if !moved, hypot(p.x - downAt.x, p.y - downAt.y) < 4 { return }
        moved = true
        window.setFrameOrigin(NSPoint(x: originAtDown.x + p.x - downAt.x, y: originAtDown.y + p.y - downAt.y))
    }

    override func mouseUp(with event: NSEvent) {
        defer { downAt = nil }
        guard let panel else { return }
        if moved { panel.onMoved?(panel.frame.origin) } else { panel.onClick?() }
    }

    // MARK: Drops

    /// Files from Finder are moved (they leave the desktop); from anywhere that doesn't allow moving, copied.
    private func operation(_ info: NSDraggingInfo) -> NSDragOperation {
        let mask = info.draggingSourceOperationMask
        if mask.contains(.move) { return .move }
        if mask.contains(.copy) { return .copy }
        return mask.contains(.generic) ? .generic : []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        model?.dropHover = true
        return operation(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { operation(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) { model?.dropHover = false }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let model else { return false }
        model.dropHover = false
        let pb = sender.draggingPasteboard
        let move = operation(sender) != .copy

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return model.add(urls: urls, move: move) > 0
        }
        // not a file: make one
        let stamp = Self.stamp()
        if let img = NSImage(pasteboard: pb), let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            return model.add(data: png, named: "Bild \(stamp).png")
        }
        if let link = pb.string(forType: .URL) ?? pb.string(forType: .string).flatMap({ s in
            URL(string: s).flatMap { $0.scheme?.hasPrefix("http") == true ? s : nil } }),
           let url = URL(string: link) {
            let plist: [String: String] = ["URL": url.absoluteString]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                let name = (url.host ?? "Link").replacingOccurrences(of: "www.", with: "")
                return model.add(data: data, named: "\(name).webloc")
            }
        }
        if let text = pb.string(forType: .string), let data = text.data(using: .utf8) {
            return model.add(data: data, named: "Notiz \(stamp).txt")
        }
        return false
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'um' HH.mm.ss"
        return f.string(from: Date())
    }
}

/// Full-screen, transparent, in front of everything; Esc closes it.
final class FanPanel: NSPanel {
    var onCancel: (() -> Void)?

    init(frame: CGRect, content: FanView) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: content)
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
