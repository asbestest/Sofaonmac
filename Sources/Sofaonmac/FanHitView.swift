import AppKit

/// Lies over the fan and does all the mouse work for its cards: hover, click (open) and drag (the real file).
///
/// It tests the mouse against the cards' actual, rotated outlines, topmost card first, and lets every other
/// click through to SwiftUI below (the "Put back" buttons, "Put everything back", the background).
/// Dragging offers "move", so Finder moves the file out of the sofa instead of copying it, and puts it
/// where the mouse lets go.
final class FanHitView: NSView, NSDraggingSource {
    /// The cards as currently laid out, in this view's (top-left) coordinates.
    var cards: () -> [FanLayout.Card] = { [] }
    var state: FanState?
    var url: (SofaItem) -> URL? = { _ in nil }
    var image: (SofaItem) -> NSImage? = { _ in nil }
    var onOpen: ((SofaItem) -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private var down: (event: NSEvent, card: FanLayout.Card)?
    /// Room under a hovered card for its name and button, so moving onto the button keeps it visible.
    private let below: CGFloat = 64

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Topmost first: the hovered card is drawn above all others, then later cards above earlier ones.
    private func card(at p: CGPoint, below: CGFloat = 0) -> FanLayout.Card? {
        guard state?.open == true else { return nil }
        let hovered = state?.hovered
        let ordered = cards().sorted { a, b in
            if (a.id == hovered) != (b.id == hovered) { return a.id == hovered }
            return a.index > b.index
        }
        return ordered.first { $0.contains(p, hovered: $0.id == hovered, below: $0.id == hovered ? below : 0) }
    }

    // MARK: Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        return card(at: p) != nil ? self : nil   // not on a card picture: SwiftUI below gets it
    }

    // MARK: Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let id = card(at: convert(event.locationInWindow, from: nil), below: below)?.id
        if state?.hovered != id { state?.hovered = id }
    }

    override func mouseExited(with event: NSEvent) {
        state?.hovered = nil
    }

    // MARK: Click and drag

    override func mouseDown(with event: NSEvent) {
        guard let c = card(at: convert(event.locationInWindow, from: nil)) else { return }
        down = (event, c)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let (start, c) = down, let url = url(c.item) else { return }
        let a = start.locationInWindow, b = event.locationInWindow
        guard hypot(b.x - a.x, b.y - a.y) > 4 else { return }
        down = nil

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let p = convert(start.locationInWindow, from: nil)
        let frame = CGRect(x: p.x - c.size.width / 2, y: p.y - c.size.height / 2, width: c.size.width, height: c.size.height)
        item.setDraggingFrame(frame, contents: image(c.item))
        let session = beginDraggingSession(with: [item], event: start, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        onDragBegan?()
    }

    override func mouseUp(with event: NSEvent) {
        if let (_, c) = down { onOpen?(c.item) }
        down = nil
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Finder moves on the same disk and copies to another one (or with ⌥), just like its own drags
        context == .outsideApplication ? [.move, .copy] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragEnded?()
    }
}
