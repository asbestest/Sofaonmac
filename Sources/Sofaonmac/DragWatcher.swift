import AppKit

/// Notices when the user starts dragging files (or pictures, text …) anywhere on screen,
/// so the sofa can come forward as a drop target. Same trick as shelf apps: during a drag
/// the system drag pasteboard gets new contents, which we see from a global mouse monitor.
final class DragWatcher {
    var onBegan: (() -> Void)?
    var onEnded: (() -> Void)?

    private var monitors: [Any] = []
    private let pasteboard = NSPasteboard(name: .drag)
    private var countAtDown = 0
    private var active = false

    private static let interesting: Set<NSPasteboard.PasteboardType> = [.fileURL, .URL, .tiff, .png, .string]

    func start() {
        guard monitors.isEmpty else { return }
        let add: (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Void = { mask, handler in
            if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) { self.monitors.append(m) }
        }
        add(.leftMouseDown) { [weak self] _ in
            guard let self else { return }
            countAtDown = pasteboard.changeCount
        }
        add(.leftMouseDragged) { [weak self] _ in
            guard let self, !active, pasteboard.changeCount != countAtDown,
                  let types = pasteboard.types, !Self.interesting.isDisjoint(with: types) else { return }
            active = true
            onBegan?()
        }
        add(.leftMouseUp) { [weak self] _ in
            guard let self, active else { return }
            active = false
            // let a drop onto the sofa finish before it steps back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.onEnded?() }
        }
    }
}
