import SwiftUI
import HeyDomain

/// An app icon that turns slowly while the app is running (still when Reduce Motion is on).
struct DockIcon: View {
    let image: NSImage
    let size: CGFloat
    let spinning: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if spinning && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 18) / 18
                icon.rotationEffect(.degrees(turn * 360))
            }
        } else {
            icon
        }
    }

    private var icon: some View {
        Image(nsImage: image).resizable().interpolation(.high).frame(width: size, height: size)
    }
}

/// Hover magnify + label + running dot around whatever the tile shows.
private struct DockTile<Content: View>: View {
    let label: String
    let running: Bool
    let size: CGFloat
    let action: () -> Void
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .frame(width: size, height: size)
                .scaleEffect(hovering ? 1.28 : 1, anchor: .bottom)
                .offset(y: hovering ? -4 : 0)
                .overlay(alignment: .top) {
                    if hovering {
                        Text(label).font(.caption.weight(.medium)).lineLimit(1).fixedSize()
                            .glassPill()
                            .offset(y: -size * 0.62 - 14)
                            .allowsHitTesting(false)
                    }
                }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Circle().fill(.white.opacity(running ? 0.9 : 0)).frame(width: 5, height: 5).offset(y: 9)
        }
        .onHover { hovering = $0 }
        .animation(.spring(duration: 0.25, bounce: 0.35), value: hovering)
        .accessibilityLabel(label)
    }
}

struct DockView: View {
    let model: GameModel
    let service: DockService
    var onSize: (CGSize) -> Void
    var onAdd: () -> Void
    var onDropURLs: ([URL]) -> Void
    var onRename: (UUID, String) -> Void
    /// Widest the dock may grow; running apps that don't fit are left out (they stay in the system Dock).
    var maxWidth: CGFloat = 1200

    @State private var openGroup: UUID?

    private let iconSize: CGFloat = 52
    private var dock: DockLayout { model.game.dock }

    private func edit(_ change: @escaping (inout DockLayout) -> Void) {
        model.perform { $0.setDock(change); return [] }
    }

    var body: some View {
        let room = max(0, Int((maxWidth - 170) / 66) - dock.entries.count - 1)
        let loose = Array(service.runningApps.filter { !dock.contains($0.bundleID) }.prefix(room))
        VStack(spacing: 10) {
            if let id = openGroup, let group = group(id) { popout(group) }
            bar(loose)
        }
        .padding(.horizontal, 24).padding(.bottom, 14).padding(.top, 40)
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize($0) }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: openGroup)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: dock)
        .onChange(of: dock) { if let id = openGroup, group(id) == nil { openGroup = nil } }
    }

    private func group(_ id: UUID) -> DockGroup? {
        for case .group(let g) in dock.entries where g.id == id { return g }
        return nil
    }

    // MARK: bar

    private func bar(_ loose: [DockApp]) -> some View {
        HStack(spacing: 14) {
            ForEach(dock.entries) { entry in
                switch entry {
                case .app(let app): appTile(app, pinned: true, inGroup: nil)
                case .group(let g): groupTile(g)
                }
            }
            if !dock.entries.isEmpty && !loose.isEmpty { divider }
            ForEach(loose, id: \.bundleID) { appTile($0, pinned: false, inGroup: nil) }
            if dock.entries.isEmpty && loose.isEmpty {
                Text("ลากแอปมาวางที่นี่ หรือกดปุ่มบวก").font(.callout).foregroundStyle(.white.opacity(0.7)).padding(.horizontal, 8)
            }
            divider
            DockTile(label: "เพิ่มแอป", running: false, size: iconSize * 0.7, action: onAdd) {
                Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    .frame(width: iconSize * 0.7, height: iconSize * 0.7)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .glassEffect(.regular.tint(HeyLook.deep.opacity(0.35)), in: .rect(cornerRadius: 32))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .dropDestination(for: URL.self) { urls, _ in onDropURLs(urls); return true }
    }

    private var divider: some View {
        Capsule().fill(.white.opacity(0.22)).frame(width: 1.5, height: iconSize * 0.7)
    }

    // MARK: tiles

    private func appTile(_ app: DockApp, pinned: Bool, inGroup groupID: UUID?, size: CGFloat? = nil) -> some View {
        let s = size ?? iconSize
        let live = service.isRunning(app)
        return DockTile(label: app.name, running: live, size: s, action: { service.open(app) }) {
            DockIcon(image: service.icon(app), size: s, spinning: live)
        }
        .draggable(app.bundleID)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            drop(id, onto: app.bundleID); return true
        }
        .contextMenu { appMenu(app, pinned: pinned, inGroup: groupID) }
    }

    private func groupTile(_ g: DockGroup) -> some View {
        let anyRunning = g.apps.contains { service.isRunning($0) }
        return DockTile(label: "\(g.name) · \(g.apps.count)", running: anyRunning, size: iconSize,
                        action: { openGroup = openGroup == g.id ? nil : g.id }) {
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .overlay {
                    LazyVGrid(columns: [GridItem(.fixed(21), spacing: 3), GridItem(.fixed(21), spacing: 3)], spacing: 3) {
                        ForEach(Array(g.apps.prefix(4)), id: \.bundleID) { app in
                            DockIcon(image: service.icon(app), size: 21, spinning: service.isRunning(app))
                        }
                    }
                }
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            drop(id, onto: g.id.uuidString); return true
        }
        .contextMenu {
            Button("เปลี่ยนชื่อกลุ่ม…") { onRename(g.id, g.name) }
            Button("เลื่อนไปทางซ้าย") { edit { $0.move(g.id.uuidString, by: -1) } }
            Button("เลื่อนไปทางขวา") { edit { $0.move(g.id.uuidString, by: 1) } }
            Divider()
            Button("แยกกลุ่ม") { edit { $0.dissolve(g.id) } }
        }
    }

    private func popout(_ g: DockGroup) -> some View {
        VStack(spacing: 6) {
            Text(g.name).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 12) {
                ForEach(g.apps, id: \.bundleID) { appTile($0, pinned: true, inGroup: g.id, size: 44) }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .glassEffect(.regular.tint(HeyLook.deep.opacity(0.35)), in: .rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
    }

    // MARK: actions

    private func drop(_ bundleID: String, onto targetID: String) {
        let known = dock.contains(bundleID)
        let incoming = known ? nil : service.info(forBundleID: bundleID)
        edit { layout in
            if let incoming { layout.add(incoming) }
            layout.drop(bundleID, onto: targetID)
        }
    }

    @ViewBuilder
    private func appMenu(_ app: DockApp, pinned: Bool, inGroup groupID: UUID?) -> some View {
        Button("เปิด") { service.open(app) }
        Divider()
        if pinned {
            if groupID != nil { Button("นำออกจากกลุ่ม") { edit { $0.ungroup(app.bundleID) } } }
            let groups = dock.entries.compactMap { entry -> DockGroup? in
                if case .group(let g) = entry, g.id != groupID { return g } else { return nil }
            }
            if !groups.isEmpty {
                Menu("ย้ายไปกลุ่ม") {
                    ForEach(groups, id: \.id) { g in Button(g.name) { edit { $0.move(app.bundleID, toGroup: g.id) } } }
                }
            }
            if groupID == nil {
                Button("เลื่อนไปทางซ้าย") { edit { $0.move(app.bundleID, by: -1) } }
                Button("เลื่อนไปทางขวา") { edit { $0.move(app.bundleID, by: 1) } }
            }
            Button("เอาออกจาก Dock") { edit { $0.remove(app.bundleID) } }
        } else {
            Button("ปักหมุดไว้ใน Dock") { edit { $0.add(app) } }
        }
    }
}
