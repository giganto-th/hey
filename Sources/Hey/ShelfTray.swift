import AppKit
import SwiftUI
import HeyDomain

/// The shelf's tray: a glass card at the bottom-left of the screen. Drag a chip out to drop it anywhere.
@MainActor
final class ShelfTrayController {
    private let model: GameModel
    private let service: ShelfService
    private var panel: NSPanel?
    private var host: NSHostingView<ShelfTrayView>?
    private(set) var wantsOpen = false

    init(model: GameModel, service: ShelfService) {
        self.model = model
        self.service = service
    }

    var isOpen: Bool { panel?.isVisible ?? false }

    func show() { wantsOpen = true; sync() }
    func close() { wantsOpen = false; sync() }
    func toggle() { wantsOpen ? close() : show() }

    /// Follows the shelf's contents: opens when something arrives (via `show`), closes itself when emptied.
    func sync() {
        if model.game.shelf.isEmpty { wantsOpen = false }
        guard wantsOpen else { panel?.orderOut(nil); return }
        if panel == nil {
            let host = NSHostingView(rootView: ShelfTrayView(model: model, service: service, onClose: { [weak self] in self?.close() }))
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.hidesOnDeactivate = false
            let dropArea = TrayDropView(frame: .zero)
            dropArea.onDrop = { [weak service] in service?.add($0) }
            host.frame = dropArea.bounds
            host.autoresizingMask = [.width, .height]
            dropArea.addSubview(host)
            p.contentView = dropArea
            self.host = host
            panel = p
        }
        guard let panel, let host else { return }
        let size = host.fittingSize
        if let area = NSScreen.main?.visibleFrame {
            panel.setFrame(NSRect(x: area.minX + 16, y: area.minY + 16, width: size.width, height: size.height), display: true)
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

/// The tray accepts drops too: drag more things onto it to add them.
private final class TrayDropView: NSView {
    var onDrop: ((DropPayload) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = DropPayload(from: sender.draggingPasteboard) else { return false }
        onDrop?(payload)
        return true
    }
}

struct ShelfTrayView: View {
    let model: GameModel
    let service: ShelfService
    let onClose: () -> Void

    var body: some View {
        let items = model.game.shelf
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ถาดพักไฟล์ · \(items.count)", systemImage: "suitcase.fill").font(.headline)
                Spacer()
                Button("ล้าง") { service.clear() }.buttonStyle(.borderless).font(.caption)
                Button { onClose() } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless)
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(items.prefix(8)) { item in ShelfChip(item: item, service: service) }
                    if items.count > 8 {
                        Text("และอีก \(items.count - 8) รายการ — ดูทั้งหมดใน Hub › ฝากไฟล์").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 330)
            Text("ลากรายการออกไปวางที่ไหนก็ได้ · ดับเบิลคลิกเพื่อเปิด")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 300)
        .glassCard(cornerRadius: 22)
    }
}

private struct ShelfChip: View {
    let item: ShelfItem
    let service: ShelfService

    var body: some View {
        let present = service.exists(item)
        HStack(spacing: 8) {
            ZStack {
                HStack(spacing: 10) {
                    Image(nsImage: service.icon(for: item)).resizable().frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).lineLimit(1).font(.callout)
                        Text(present ? subtitle : "ไม่พบแล้ว (ถูกย้ายหรือลบ)").font(.caption2)
                            .foregroundStyle(present ? Color.secondary : Color.red).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                if present {
                    DragHandle(
                        writer: { service.pasteboardWriter(for: item) },
                        image: { service.icon(for: item) },
                        onFinished: { service.dragFinished(item, operation: $0) },
                        onOpen: { service.open(item) })
                }
            }
            Button { service.remove(item) } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var subtitle: String {
        switch item.kind {
        case .file, .folder: (item.path.map { ($0 as NSString).deletingLastPathComponent } ?? "").replacingOccurrences(of: NSHomeDirectory(), with: "~")
        case .link: item.text ?? ""
        case .text: String((item.text ?? "").prefix(40)).replacingOccurrences(of: "\n", with: " ")
        }
    }
}
