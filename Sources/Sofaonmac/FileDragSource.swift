import AppKit
import SwiftUI

/// Makes a card in the fan behave like a file icon in Finder: click opens it, dragging hands the real file
/// to wherever it's dropped. The drag offers "move" (not just "copy", like SwiftUI's onDrag does),
/// so Finder moves the file out of the sofa instead of duplicating it, and puts it where the mouse lets go.
struct FileDragSource: NSViewRepresentable {
    let url: URL
    let image: NSImage
    let onClick: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: (NSDragOperation) -> Void

    func makeNSView(context: Context) -> SourceView { SourceView() }

    func updateNSView(_ view: SourceView, context: Context) {
        view.url = url
        view.image = image
        view.onClick = onClick
        view.onDragBegan = onDragBegan
        view.onDragEnded = onDragEnded
    }

    final class SourceView: NSView, NSDraggingSource {
        var url: URL?
        var image: NSImage?
        var onClick: (() -> Void)?
        var onDragBegan: (() -> Void)?
        var onDragEnded: ((NSDragOperation) -> Void)?
        private var downEvent: NSEvent?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) { downEvent = event }

        override func mouseDragged(with event: NSEvent) {
            guard let down = downEvent, let url else { return }
            let a = down.locationInWindow, b = event.locationInWindow
            guard hypot(b.x - a.x, b.y - a.y) > 4 else { return }
            downEvent = nil

            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(bounds, contents: image)
            let session = beginDraggingSession(with: [item], event: down, source: self)
            session.animatesToStartingPositionsOnCancelOrFail = true
            onDragBegan?()
        }

        override func mouseUp(with event: NSEvent) {
            if downEvent != nil { onClick?() }
            downEvent = nil
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            // Finder moves on the same disk and copies to another one (or with ⌥), just like its own drags
            context == .outsideApplication ? [.move, .copy] : []
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            onDragEnded?(operation)
        }
    }
}
