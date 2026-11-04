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
    let magnify: Bool
    let action: () -> Void
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .frame(width: size, height: size)
                .scaleEffect(hovering && magnify ? 1.28 : 1, anchor: .bottom)
                .offset(y: hovering && magnify ? -4 : 0)
                .overlay(alignment: .top) {
                    if hovering {
                        Text(label).font(.caption.weight(.medium)).lineLimit(1).fixedSize()
                            .glassPill()
                            .offset(y: -(magnify ? 38 : 30))
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
    @State private var dragging: String?
    @State private var resizeBase: Double?
    @State private var overRemove = false

    private var dock: DockLayout { model.game.dock }
    private var size: CGFloat { CGFloat(dock.iconSize) }

    private func edit(_ change: @escaping (inout DockLayout) -> Void) {
        model.perform { $0.setDock(change); return [] }
    }

    var body: some View {
        let slot = size + 14
        let room = max(0, Int((maxWidth - 170) / slot) - dock.entries.count - 1)
        let loose = Array(service.runningApps.filter { !dock.contains($0.bundleID) }.prefix(room))
        VStack(spacing: 10) {
            if let id = openGroup, let group = group(id) { popout(group) }
            if dragging != nil { removeZone }
            bar(loose)
        }
        .padding(.horizontal, 24).padding(.bottom, 14).padding(.top, 40)
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize($0) }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: openGroup)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: dock)
        .animation(.spring(duration: 0.25), value: dragging)
        .onChange(of: dock) { if let id = openGroup, group(id) == nil { openGroup = nil } }
        .task(id: dragging) {               // a drag has no "ended" callback, so watch for the button coming up
            guard dragging != nil else { return }
            while !Task.isCancelled, NSEvent.pressedMouseButtons & 1 != 0 { try? await Task.sleep(for: .milliseconds(120)) }
            try? await Task.sleep(for: .milliseconds(150))
            dragging = nil
        }
    }

    private func group(_ id: UUID) -> DockGroup? {
        for case .group(let g) in dock.entries where g.id == id { return g }
        return nil
    }

    // MARK: bar

    private func bar(_ loose: [DockApp]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(dock.entries.enumerated()), id: \.element.id) { index, entry in
                gap(before: index)
                switch entry {
                case .app(let app): appTile(app, pinned: true, inGroup: nil)
                case .group(let g): groupTile(g)
                }
            }
            gap(before: dock.entries.count)
            if !dock.entries.isEmpty && !loose.isEmpty { divider }
            ForEach(loose, id: \.bundleID) { app in
                appTile(app, pinned: false, inGroup: nil)
                Color.clear.frame(width: 14, height: 1)
            }
            if dock.entries.isEmpty && loose.isEmpty {
                Text("ลากแอปมาวางที่นี่ หรือกดปุ่มบวก").font(.callout).foregroundStyle(.white.opacity(0.7)).padding(.horizontal, 8)
            }
            resizeHandle
            DockTile(label: "เพิ่มแอป", running: false, size: size * 0.7, magnify: dock.magnify, action: onAdd) {
                Image(systemName: "plus").font(.system(size: size * 0.34, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    .frame(width: size * 0.7, height: size * 0.7)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .glassEffect(.regular.tint(HeyLook.deep.opacity(0.35)), in: .rect(cornerRadius: 22 + size * 0.18))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .dropDestination(for: URL.self) { urls, _ in onDropURLs(urls); return true }
    }

    private var divider: some View {
        Capsule().fill(.white.opacity(0.22)).frame(width: 1.5, height: size * 0.7).padding(.horizontal, 7)
    }

    /// The divider doubles as the size handle, like the system Dock: drag it up or down.
    private var resizeHandle: some View {
        Capsule().fill(.white.opacity(0.28)).frame(width: 3, height: size * 0.7)
            .padding(.horizontal, 7).padding(.vertical, 6).contentShape(Rectangle())
            .onHover { inside in if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    let base = resizeBase ?? dock.iconSize
                    resizeBase = base
                    edit { $0.setIconSize(base - Double(value.translation.height) * 0.6) }
                }
                .onEnded { _ in resizeBase = nil })
            .help("ลากขึ้นลงเพื่อปรับขนาด")
    }

    /// A thin drop slot between tiles: dropping an app here puts it at that position (out of its group if needed).
    private func gap(before index: Int) -> some View {
        DockGap(active: dragging != nil, height: size) { id in
            let incoming = dock.contains(id) ? nil : service.info(forBundleID: id)
            edit { layout in
                if let incoming { layout.add(incoming) }
                layout.insert(id, at: index)
            }
        }
    }

    private var removeZone: some View {
        Label("ลากมาวางที่นี่เพื่อเอาออกจาก Dock", systemImage: "trash")
            .font(.callout.weight(.medium)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .glassEffect(.regular.tint((overRemove ? Color.red : HeyLook.deep).opacity(0.55)), in: .capsule)
            .scaleEffect(overRemove ? 1.06 : 1)
            .dropDestination(for: String.self) { ids, _ in
                if let id = ids.first { edit { $0.remove(id) } }
                dragging = nil
                return true
            } isTargeted: { overRemove = $0 }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: tiles

    private func appTile(_ app: DockApp, pinned: Bool, inGroup groupID: UUID?, side: CGFloat? = nil) -> some View {
        let s = side ?? size
        let live = service.isRunning(app)
        return DockTile(label: app.name, running: live, size: s, magnify: dock.magnify, action: { service.open(app) }) {
            DockIcon(image: service.icon(app), size: s, spinning: live && dock.spinRunning)
        }
        .onDrag {
            dragging = app.bundleID
            return NSItemProvider(object: app.bundleID as NSString)
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            drop(id, onto: app.bundleID); return true
        }
        .contextMenu { appMenu(app, pinned: pinned, inGroup: groupID) }
    }

    private func groupTile(_ g: DockGroup) -> some View {
        let anyRunning = g.apps.contains { service.isRunning($0) }
        let mini = (size - 10) / 2 - 3
        return DockTile(label: "\(g.name) · \(g.apps.count)", running: anyRunning, size: size, magnify: dock.magnify,
                        action: { openGroup = openGroup == g.id ? nil : g.id }) {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(.white.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .overlay {
                    LazyVGrid(columns: [GridItem(.fixed(mini), spacing: 3), GridItem(.fixed(mini), spacing: 3)], spacing: 3) {
                        ForEach(Array(g.apps.prefix(4)), id: \.bundleID) { app in
                            DockIcon(image: service.icon(app), size: mini, spinning: service.isRunning(app) && dock.spinRunning)
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
                ForEach(g.apps, id: \.bundleID) { appTile($0, pinned: true, inGroup: g.id, side: size * 0.85) }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .glassEffect(.regular.tint(HeyLook.deep.opacity(0.35)), in: .rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
    }

    // MARK: actions

    private func drop(_ bundleID: String, onto targetID: String) {
        let incoming = dock.contains(bundleID) ? nil : service.info(forBundleID: bundleID)
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

/// An insertion slot between tiles that widens and lights up while an icon is being dragged over it.
private struct DockGap: View {
    let active: Bool
    let height: CGFloat
    let onDrop: (String) -> Void
    @State private var targeted = false

    var body: some View {
        Capsule().fill(.white.opacity(targeted ? 0.85 : 0))
            .frame(width: targeted ? 4 : 2, height: height * 0.8)
            .frame(width: active ? 16 : 7, height: height)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first else { return false }
                onDrop(id); return true
            } isTargeted: { targeted = $0 }
            .animation(.spring(duration: 0.2), value: targeted)
            .animation(.spring(duration: 0.2), value: active)
    }
}
