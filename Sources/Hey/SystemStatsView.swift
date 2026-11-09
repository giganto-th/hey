import SwiftUI
import HeyDomain

/// "My Mac": live CPU, memory, disk, network, power and the busiest processes, plus what Hey! itself costs.
struct SystemTab: View {
    let power: PowerMonitor
    @State private var stats = SystemStats()

    var body: some View {
        List {
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
                row("Swap", stats.swapTotal > 0 ? "\(ByteText.size(stats.swapUsed)) / \(ByteText.size(stats.swapTotal))" : tr("ไม่ได้ใช้"))
            }

            Section(tr("ดิสก์")) {
                let used = max(stats.diskTotal - stats.diskFree, 0)
                meterHeader(tr("ใช้ไป"), "\(ByteText.size(used)) / \(ByteText.size(stats.diskTotal))")
                ProgressView(value: stats.diskTotal > 0 ? used / stats.diskTotal : 0)
                    .tint(color(for: stats.diskTotal > 0 ? used / stats.diskTotal : 0))
                row(tr("ว่าง"), ByteText.size(stats.diskFree))
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
                let s = power.signals
                if let battery = s.batteryPercent {
                    row(tr("แบตเตอรี่"), "\(battery)%" + (s.isCharging ? tr(" · กำลังชาร์จ") : s.onAC ? tr(" · เสียบไฟ") : ""))
                } else {
                    row(tr("แหล่งพลังงาน"), tr("ไฟบ้าน (ไม่มีแบตเตอรี่)"))
                }
                row(tr("ความร้อน"), thermalText(s.thermal))
                row(tr("โหมดประหยัดพลังงาน"), s.lowPowerMode ? tr("เปิด") : tr("ปิด"))
            }

            Section("Hey!") {
                row(tr("CPU ที่ Hey! ใช้"), String(format: "%.1f%%", stats.heyCPU))
                row(tr("หน่วยความจำที่ Hey! ใช้"), ByteText.size(stats.heyMemory))
                Text(tr("ตัววัดทำงานเฉพาะตอนเปิดหน้านี้ ปิดหน้านี้แล้วไม่กินเครื่อง")).font(.caption).foregroundStyle(.secondary)
            }

            if !stats.topByCPU.isEmpty {
                Section(tr("โปรแกรมที่ใช้ CPU มากสุด")) {
                    ForEach(stats.topByCPU) { p in row(p.name, String(format: "%.1f%%", p.cpu)) }
                }
                Section(tr("โปรแกรมที่ใช้หน่วยความจำมากสุด")) {
                    ForEach(stats.topByMemory) { p in row(p.name, ByteText.size(p.memory)) }
                }
            }
        }
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
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
