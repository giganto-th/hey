import AppKit
import SwiftUI
import HeyDomain

/// "My Mac": live CPU, memory, disk, network, power and the busiest processes, plus what Hey! itself costs.
struct SystemTab: View {
    let power: PowerMonitor
    let log: MachineLog
    @State private var stats = SystemStats()
    @State private var cleaner = DiskCleaner()
    @State private var span = HistorySpan.day
    @State private var battery = BatteryHealth.read()
    @State private var agents: [LoginAgent] = []

    var body: some View {
        Form {
            Section { MachineRings(stats: stats) }

            Section(tr("คำแนะนำ")) {
                ForEach(MachineAdvisor.advise(stats.snapshot(reclaimable: cleaner.reclaimable, thermal: power.signals.thermal))) { advice in
                    adviceRow(advice)
                }
            }

            Section(tr("เครื่องนี้")) {
                row(tr("ชิป"), stats.chip)
                row(tr("รุ่น"), stats.model)
                row(tr("แกน CPU"), tr("{0} แกนจริง · {1} แกนตรรกะ", stats.physicalCores, stats.logicalCores))
                row(tr("หน่วยความจำ"), ByteText.size(stats.totalMemory))
                row("macOS", stats.osVersion)
                row(tr("เปิดเครื่องมาแล้ว"), uptimeText(stats.uptime))
            }

            Section("CPU") {
                meterHeader(tr("ใช้งานรวม"), percent(stats.cpu))
                Sparkline(values: stats.cpuHistory.values, maximum: 1, color: .cyan).frame(height: 44)
                if !stats.cores.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 6) {
                        ForEach(Array(stats.cores.enumerated()), id: \.offset) { i, value in
                            HStack(spacing: 6) {
                                Text("\(i + 1)").font(.caption2).foregroundStyle(.secondary).frame(width: 18, alignment: .trailing)
                                ProgressView(value: value).tint(color(for: value))
                                Text(percent(value)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            Section(tr("หน่วยความจำ")) {
                let fraction = stats.totalMemory > 0 ? min(stats.memoryUsed / stats.totalMemory, 1) : 0
                meterHeader(tr("ใช้อยู่"), "\(ByteText.size(stats.memoryUsed)) / \(ByteText.size(stats.totalMemory))")
                ProgressView(value: fraction).tint(color(for: fraction))
                Sparkline(values: stats.memoryHistory.values, maximum: 1, color: .purple).frame(height: 36)
                row(tr("ล็อกไว้ (wired)"), ByteText.size(stats.memoryWired))
                row(tr("บีบอัด"), ByteText.size(stats.memoryCompressed))
                row(tr("แคช (เรียกคืนได้)"), ByteText.size(stats.memoryCached))
                row(tr("แรงกดดันหน่วยความจำ"), pressureText(stats.memoryPressure))
                row("Swap", stats.swapTotal > 0 ? "\(ByteText.size(stats.swapUsed)) / \(ByteText.size(stats.swapTotal))" : tr("ไม่ได้ใช้"))
            }

            Section(tr("ดิสก์")) {
                let used = max(stats.diskTotal - stats.diskFree, 0)
                meterHeader(tr("ใช้ไป"), "\(ByteText.size(used)) / \(ByteText.size(stats.diskTotal))")
                ProgressView(value: stats.diskTotal > 0 ? used / stats.diskTotal : 0)
                    .tint(color(for: stats.diskTotal > 0 ? used / stats.diskTotal : 0))
                row(tr("ว่าง"), ByteText.size(stats.diskFree))
            }

            Section(tr("พื้นที่ที่เคลียร์ได้")) {
                if cleaner.places.isEmpty {
                    Button(tr("สแกนหาพื้นที่ที่เคลียร์ได้"), systemImage: "magnifyingglass") { cleaner.scan() }
                } else {
                    ForEach(cleaner.places) { place in
                        HStack(spacing: 10) {
                            Image(systemName: place.symbol).frame(width: 22).foregroundStyle(.secondary)
                            Text(place.title)
                            Spacer()
                            if let bytes = place.bytes { Text(ByteText.size(bytes)).foregroundStyle(.secondary).monospacedDigit() }
                            else { ProgressView().controlSize(.small) }
                            Button { cleaner.reveal(place) } label: { Image(systemName: "folder") }
                                .buttonStyle(.borderless).help(tr("เปิดใน Finder"))
                            if place.clearable {
                                Button(tr("ล้าง")) { cleaner.clear(place) }.heySecondaryButton().disabled(cleaner.scanning || (place.bytes ?? 0) == 0)
                            }
                        }
                    }
                    HStack {
                        Text(tr("รวมที่เคลียร์ได้ราว {0}", ByteText.size(cleaner.reclaimable))).foregroundStyle(.secondary)
                        Spacer()
                        Button(tr("สแกนใหม่"), systemImage: "arrow.clockwise") { cleaner.scan() }.disabled(cleaner.scanning)
                    }
                    if let message = cleaner.message { Text(message).font(.caption).foregroundStyle(.orange) }
                }
            }

            if !cleaner.largeFiles.isEmpty {
                Section(tr("ไฟล์ใหญ่ในดาวน์โหลด")) {
                    ForEach(cleaner.largeFiles) { file in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                if let date = file.modified { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text(ByteText.size(file.bytes)).foregroundStyle(.secondary).monospacedDigit()
                            Button { cleaner.reveal(file) } label: { Image(systemName: "folder") }.buttonStyle(.borderless).help(tr("เปิดใน Finder"))
                            Button { cleaner.trash(file) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help(tr("ย้ายไปถังขยะ"))
                        }
                    }
                }
            }

            Section(tr("ประวัติ")) {
                Picker(tr("ช่วง"), selection: $span) {
                    ForEach(HistorySpan.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                historyChart(tr("CPU"), \.cpu, maximum: 1, color: .cyan, format: { "\(Int(($0 * 100).rounded()))%" })
                historyChart(tr("หน่วยความจำ"), \.memory, maximum: 1, color: .purple, format: { "\(Int(($0 * 100).rounded()))%" })
                if log.history.samples.contains(where: { $0.temperature != nil }) {
                    historyChart(tr("อุณหภูมิ"), \.temperature, maximum: 110, color: .orange, format: { "\(Int($0.rounded()))°C" })
                }
            }

            Section(tr("เครือข่าย")) {
                HStack {
                    Label(ByteText.speed(stats.netIn), systemImage: "arrow.down.circle.fill").foregroundStyle(.green)
                    Spacer()
                    Label(ByteText.speed(stats.netOut), systemImage: "arrow.up.circle.fill").foregroundStyle(.orange)
                }
                .font(.callout.monospacedDigit())
                ZStack {
                    Sparkline(values: stats.netInHistory.values, maximum: max(stats.netInHistory.peak, stats.netOutHistory.peak, 1024), color: .green)
                    Sparkline(values: stats.netOutHistory.values, maximum: max(stats.netInHistory.peak, stats.netOutHistory.peak, 1024), color: .orange)
                }
                .frame(height: 36)
            }

            Section(tr("พลังงานและความร้อน")) {
                if let t = stats.temperature {
                    if let cpu = t.cpu {
                        meterHeader(tr("อุณหภูมิ CPU"), "\(Int(cpu.rounded()))°C")
                        Sparkline(values: stats.cpuTempHistory.values, maximum: 110, color: cpu >= 85 ? .red : cpu >= 70 ? .orange : .green).frame(height: 36)
                    }
                    if let ssd = t.ssd { row(tr("อุณหภูมิ SSD"), "\(Int(ssd.rounded()))°C") }
                    if let battery = t.battery { row(tr("อุณหภูมิแบตเตอรี่"), "\(Int(battery.rounded()))°C") }
                }
                let s = power.signals
                if let battery = s.batteryPercent {
                    row(tr("แบตเตอรี่"), "\(battery)%" + (s.isCharging ? tr(" · กำลังชาร์จ") : s.onAC ? tr(" · เสียบไฟ") : ""))
                } else {
                    row(tr("แหล่งพลังงาน"), tr("ไฟบ้าน (ไม่มีแบตเตอรี่)"))
                }
                row(tr("ความร้อน"), thermalText(s.thermal))
                row(tr("โหมดประหยัดพลังงาน"), s.lowPowerMode ? tr("เปิด") : tr("ปิด"))
            }

            if let battery {
                Section(tr("แบตเตอรี่")) {
                    if let h = battery.healthPercent { row(tr("สุขภาพแบต"), "\(h)%") }
                    if let c = battery.cycles { row(tr("จำนวนรอบชาร์จ"), "\(c)") }
                    if let t = battery.temperature { row(tr("อุณหภูมิ"), "\(Int(t.rounded()))°C") }
                    if let m = battery.minutesRemaining { row(tr("เวลาที่เหลือ"), tr("{0} ชม. {1} นาที", m / 60, m % 60)) }
                }
            }

            Section(tr("เริ่มเองเมื่อเข้าสู่ระบบ")) {
                ForEach(agents) { agent in
                    HStack {
                        Text(agent.label).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        if agent.isSystemWide { Text(tr("ทั้งเครื่อง")).chipLabel(.gray) }
                        Button { NSWorkspace.shared.activateFileViewerSelecting([agent.url]) } label: { Image(systemName: "folder") }
                            .buttonStyle(.borderless).help(tr("เปิดใน Finder"))
                    }
                }
                HStack {
                    Text(tr("{0} รายการ", agents.count)).foregroundStyle(.secondary)
                    Spacer()
                    Button(tr("เปิดการตั้งค่ารายการเข้าสู่ระบบ")) { LoginAgent.openSettings() }
                }
            }

            Section("Hey!") {
                row(tr("CPU ที่ Hey! ใช้"), String(format: "%.1f%%", stats.heyCPU))
                row(tr("หน่วยความจำที่ Hey! ใช้"), ByteText.size(stats.heyMemory))
            }

            if !stats.topByCPU.isEmpty {
                Section(tr("โปรแกรมที่ใช้ CPU มากสุด")) {
                    ForEach(stats.topByCPU) { p in processRow(p, String(format: "%.1f%%", p.cpu)) }
                }
                Section(tr("โปรแกรมที่ใช้หน่วยความจำมากสุด")) {
                    ForEach(stats.topByMemory) { p in processRow(p, ByteText.size(p.memory)) }
                }
            }
        }
        .onAppear { stats.start(); battery = BatteryHealth.read(); agents = LoginAgent.scan() }
        .onDisappear { stats.stop() }
    }

    /// An ordinary app (not a helper, not Finder, not Hey! itself) that can be asked to quit.
    private func quittable(_ pid: Int32) -> NSRunningApplication? {
        guard pid != ProcessInfo.processInfo.processIdentifier, let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular, app.bundleIdentifier != "com.apple.finder" else { return nil }
        return app
    }

    private func processRow(_ p: SystemStats.ProcessRow, _ value: String) -> some View {
        let app = quittable(p.pid)
        return HStack(spacing: 8) {
            Text(app?.localizedName ?? p.name).lineLimit(1)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            if let app {
                Menu {
                    Button(tr("ปิดแอป")) { app.terminate() }
                    Button(tr("บังคับปิด…")) { confirmForceQuit(app) }
                } label: { Image(systemName: "xmark.circle") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help(tr("ปิด {0}", app.localizedName ?? p.name))
            }
        }
        .font(.callout)
    }

    private func confirmForceQuit(_ app: NSRunningApplication) {
        let alert = NSAlert()
        alert.messageText = tr("บังคับปิด {0}?", app.localizedName ?? "")
        alert.informativeText = tr("งานที่ยังไม่ได้บันทึกในแอปนี้จะหายไป")
        alert.addButton(withTitle: tr("บังคับปิด"))
        alert.addButton(withTitle: tr("ยกเลิก"))
        if alert.runModal() == .alertFirstButtonReturn { app.forceTerminate() }
    }

    private func adviceRow(_ advice: Advice) -> some View {
        let (symbol, tint): (String, Color) = switch advice.severity {
        case .critical: ("exclamationmark.octagon.fill", .red)
        case .warning: ("exclamationmark.triangle.fill", .orange)
        case .info: (advice.kind == .allGood ? "checkmark.seal.fill" : "info.circle.fill", advice.kind == .allGood ? .green : HeyLook.glow)
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 22)
            Text(advice.message).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            adviceAction(advice)
        }
    }

    @ViewBuilder private func adviceAction(_ advice: Advice) -> some View {
        switch advice.kind {
        case .cpuBusy(let name?, _):
            if let app = stats.topByCPU.first(where: { $0.name == name }).flatMap({ quittable($0.pid) }) {
                Button(tr("ปิด {0}", app.localizedName ?? name)) { app.terminate() }.heySecondaryButton()
            }
        case .memoryPressure(let name?, _):
            if let app = stats.topByMemory.first(where: { $0.name == name }).flatMap({ quittable($0.pid) }) {
                Button(tr("ปิด {0}", app.localizedName ?? name)) { app.terminate() }.heySecondaryButton()
            }
        case .diskLow:
            if cleaner.places.isEmpty { Button(tr("สแกน")) { cleaner.scan() }.heySecondaryButton() }
        default: EmptyView()
        }
    }

    private func historyChart(_ title: String, _ value: @escaping (MachineSample) -> Double?, maximum: Double, color: Color,
                              format: (Double) -> String) -> some View {
        let series = log.history.series(span: span.seconds, buckets: 72, now: Date(), value)
        let known = series.compactMap { $0 }
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                if let low = known.min(), let high = known.max() {
                    Text(tr("ต่ำสุด {0} · สูงสุด {1}", format(low), format(high))).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Text(tr("ยังไม่มีข้อมูล")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Sparkline(values: known, maximum: maximum, color: color).frame(height: 40)
        }
    }

    private func pressureText(_ p: MemoryPressure) -> String {
        switch p {
        case .normal: tr("ปกติ")
        case .warning: tr("เริ่มตึง")
        case .critical: tr("ตึงมาก")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).lineLimit(1)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
        }
        .font(.callout)
    }

    private func meterHeader(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).font(.title3.weight(.semibold).monospacedDigit()) }
            .font(.callout)
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    private func color(for v: Double) -> Color { v > 0.9 ? .red : v > 0.7 ? .orange : .accentColor }

    private func uptimeText(_ t: TimeInterval) -> String {
        let days = Int(t / 86_400), hours = Int(t.truncatingRemainder(dividingBy: 86_400) / 3600), minutes = Int(t.truncatingRemainder(dividingBy: 3600) / 60)
        return days > 0 ? tr("{0} วัน {1} ชม.", days, hours) : tr("{0} ชม. {1} นาที", hours, minutes)
    }

    private func thermalText(_ level: ThermalLevel) -> String {
        switch level {
        case .nominal: tr("ปกติ")
        case .fair: tr("อุ่น")
        case .serious: tr("ร้อน")
        case .critical: tr("ร้อนจัด")
        }
    }
}

/// A small line chart of the latest readings, scaled to `maximum`.
private struct Sparkline: View {
    let values: [Double]
    let maximum: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count > 1, maximum > 0 {
                let step = geo.size.width / CGFloat(max(values.count - 1, 1))
                Path { path in
                    for (i, v) in values.enumerated() {
                        let point = CGPoint(x: CGFloat(i) * step, y: geo.size.height * (1 - CGFloat(min(max(v / maximum, 0), 1))))
                        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

private enum HistorySpan: String, CaseIterable, Identifiable {
    case day, week
    var id: Self { self }
    var title: String { self == .day ? tr("24 ชั่วโมง") : tr("7 วัน") }
    var seconds: TimeInterval { self == .day ? 86_400 : 7 * 86_400 }
}

/// The four gauges, in a view of their own so that only they redraw when a reading changes.
private struct MachineRings: View {
    let stats: SystemStats

    var body: some View {
        HStack(spacing: 8) {
            StatRing(value: (stats.cpu * 100).rounded(), symbol: "cpu", title: "CPU", inverted: true, animated: false)
            StatRing(value: stats.totalMemory > 0 ? (stats.memoryUsed / stats.totalMemory * 100).rounded() : 0,
                     symbol: "memorychip", title: tr("หน่วยความจำ"), inverted: true, animated: false)
            StatRing(value: stats.diskTotal > 0 ? ((stats.diskTotal - stats.diskFree) / stats.diskTotal * 100).rounded() : 0,
                     symbol: "internaldrive", title: tr("ดิสก์"), inverted: true, animated: false)
            if let t = stats.temperature?.cpu {
                StatRing(value: t.rounded(), total: 110, symbol: "thermometer.medium", title: tr("อุณหภูมิ"), inverted: true, unit: "°", animated: false)
            }
        }
        .padding(.vertical, 6)
    }
}
