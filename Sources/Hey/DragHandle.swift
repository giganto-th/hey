import AppKit
import SwiftUI

/// An invisible layer over a chip: dragging it starts a real drag session; a double click opens the item.
struct DragHandle: NSViewRepresentable {
    let writer: () -> NSPasteboardWriting?
    let image: () -> NSImage
    let onFinished: (NSDragOperation) -> Void
    let onOpen: () -> Void

    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ view: HandleView, context: Context) {
        view.writer = writer; view.image = image; view.onFinished = onFinished; view.onOpen = onOpen
    }

    final class HandleView: NSView, NSDraggingSource {
        var writer: () -> NSPasteboardWriting? = { nil }
        var image: () -> NSImage = { NSImage() }
        var onFinished: (NSDragOperation) -> Void = { _ in }
        var onOpen: () -> Void = {}
        private var downAt: NSPoint?
        private var dragging = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            downAt = event.locationInWindow
            dragging = false
            if event.clickCount == 2 { onOpen() }
        }
        override func mouseDragged(with event: NSEvent) {
            guard !dragging, let start = downAt, hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) > 4,
                  let w = writer() else { return }
            dragging = true
            let item = NSDraggingItem(pasteboardWriter: w)
            let icon = image()
            item.setDraggingFrame(NSRect(x: 0, y: 0, width: 40, height: 40), contents: icon)
            beginDraggingSession(with: [item], event: event, source: self)
        }
        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .outsideApplication ? [.copy, .generic, .link] : [.copy, .generic]
        }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            onFinished(operation)
        }
    }
}
