import AppKit
import SwiftUI
import HeyDomain

/// Hub › Features › Calendar: the month as a grid, a dot or a short title per event in each calendar's own colour,
/// and the chosen day's events below. Read-only; changes are made in Apple's Calendar app.
struct CalendarMonthTab: View {
    let calendar: CalendarService
    let router: HubRouter
    @State private var shownMonth = Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @AppStorage("calendarMode") private var mode = CalendarMode.week

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                switch calendar.access {
                case .off:
                    prompt(tr("เปิดเพื่อดูนัดทั้งเดือนในตารางปฏิทิน"), button: tr("เปิดใช้ปฏิทิน")) { Task { await calendar.setEnabled(true) } }
                case .notAllowed:
                    prompt(tr("Hey! ยังไม่ได้รับสิทธิ์อ่านปฏิทิน เปิดได้ที่ การตั้งค่าระบบ › ความเป็นส่วนตัว › ปฏิทิน"),
                           button: tr("เปิดการตั้งค่า")) { calendar.openPrivacySettings() }
                case .ready:
                    if mode == .month {
                        let grid = MonthGrid(containing: shownMonth)
                        let range = grid.range()
                        let events = calendar.events(from: range.start, to: range.end)
                        HubCard(padding: 14) { monthCard(grid, events) }
                        dayCard(MonthGrid.events(events, on: selected))
                    } else {
                        let days = MonthGrid.week(containing: selected)
                        let end = Calendar.current.date(byAdding: .day, value: 7, to: days[0]) ?? days[0]
                        HubCard(padding: 14) {
                            VStack(spacing: 10) {
                                toolbar(title: weekTitle(days), back: { stepWeek(-1) }, forward: { stepWeek(1) })
                                WeekGrid(days: days, events: calendar.events(from: days[0], to: end), selected: $selected,
                                         color: { Color(nsColor: calendar.color(of: $0)) }, join: calendar.join)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear { calendar.refresh() }
    }

    // MARK: month

    private func monthCard(_ grid: MonthGrid, _ events: [CalendarEventInfo]) -> some View {
        VStack(spacing: 10) {
            toolbar(title: grid.month.formatted(.dateTime.month(.wide).year()), back: { step(-1) }, forward: { step(1) })
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(MonthGrid.weekdaySymbols().enumerated()), id: \.offset) { _, name in
                    Text(name).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                ForEach(grid.days, id: \.self) { day in
                    DayCell(day: day, inMonth: grid.isInMonth(day), selected: Calendar.current.isDate(day, inSameDayAs: selected),
                            events: MonthGrid.events(events, on: day), color: { Color(nsColor: calendar.color(of: $0)) }) {
                        withAnimation(.snappy(duration: 0.2)) { selected = day }
                    }
                }
            }
        }
    }

    /// Today, back, forward, the period's name, and the week/month switch, as in Google Calendar.
    private func toolbar(title: String, back: @escaping () -> Void, forward: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(tr("วันนี้")) { go(to: Date()) }.buttonStyle(.bordered).controlSize(.small)
            Button(action: back) { Image(systemName: "chevron.left") }.buttonStyle(.borderless).help(tr("ก่อนหน้า"))
            Button(action: forward) { Image(systemName: "chevron.right") }.buttonStyle(.borderless).help(tr("ถัดไป"))
            Text(title).font(.title3.weight(.semibold)).lineLimit(1)
            Spacer()
            Picker("", selection: $mode) {
                ForEach(CalendarMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
        }
    }

    private func weekTitle(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let sameMonth = Calendar.current.isDate(first, equalTo: last, toGranularity: .month)
        return sameMonth ? first.formatted(.dateTime.month(.wide).year())
                         : "\(first.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
    }

    private func stepWeek(_ weeks: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: 7 * weeks, to: selected) else { return }
        withAnimation(.snappy(duration: 0.2)) { selected = next; shownMonth = next }
    }

    private func step(_ months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: MonthGrid(containing: shownMonth).month) else { return }
        withAnimation(.snappy(duration: 0.2)) { shownMonth = next; selected = next }
    }

    private func go(to date: Date) {
        withAnimation(.snappy(duration: 0.2)) { shownMonth = date; selected = Calendar.current.startOfDay(for: date) }
    }

    // MARK: the chosen day

    private func dayCard(_ events: [CalendarEventInfo]) -> some View {
        HubCard(title: selected.formatted(.dateTime.weekday(.wide).day().month(.wide)), symbol: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                if events.isEmpty {
                    Label(tr("ไม่มีนัด"), systemImage: "checkmark.circle").font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(events) { e in eventRow(e) }
                }
                Button(tr("เปิดแอปปฏิทิน"), systemImage: "arrow.up.forward.app") { calendar.openCalendarApp() }
                    .buttonStyle(.borderless).font(.footnote)
            }
        }
    }

    private func eventRow(_ e: CalendarEventInfo) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: calendar.color(of: e.calendarID))).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.displayTitle).font(.callout.weight(.medium)).lineLimit(1)
                Text(e.isAllDay ? tr("ทั้งวัน") : "\(e.start.formatted(date: .omitted, time: .shortened))–\(e.end.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if e.meetingURL != nil, e.end > Date() {
                Button(tr("เปิดลิงก์"), systemImage: "video") { calendar.join(e) }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private func prompt(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        HubCard(title: tr("ปฏิทิน"), symbol: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(button, action: action).buttonStyle(PillButtonStyle())
            }
        }
    }
}

/// One day of the grid: its number (circled blue when today, filled when chosen) and up to two event titles, then "+n".
private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let selected: Bool
    let events: [CalendarEventInfo]
    let color: (String) -> Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let today = Calendar.current.isDateInToday(day)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.footnote.weight(today || selected ? .bold : .regular)).monospacedDigit()
                    .foregroundStyle(selected ? AnyShapeStyle(.white) : today ? AnyShapeStyle(HeyLook.accent) : AnyShapeStyle(.primary))
                    .frame(width: 24, height: 24)
                    .background { if selected { Circle().fill(HeyLook.accent) } else if today { Circle().strokeBorder(HeyLook.accent, lineWidth: 1.5) } }
                ForEach(events.prefix(2)) { e in
                    Text(e.displayTitle)
                        .font(.system(size: 10, weight: .medium)).lineLimit(1)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(color(e.calendarID).opacity(0.22), in: RoundedRectangle(cornerRadius: 4))
                }
                if events.count > 2 {
                    Text("+\(events.count - 2)").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(hovering ? 0.06 : 0)))
            .opacity(inMonth ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(tr("{0} นัด", events.count))
    }
}

enum CalendarMode: String, CaseIterable, Identifiable {
    case week, month
    var id: Self { self }
    var title: String { self == .week ? tr("สัปดาห์") : tr("เดือน") }
}

/// The week as a time grid, like Google Calendar: all-day items on top, hours down the side, each event a coloured block
/// placed by its time (overlaps side by side), and a red line at the current time. Opens scrolled to the working day.
private struct WeekGrid: View {
    let days: [Date]
    let events: [CalendarEventInfo]
    @Binding var selected: Date
    let color: (String) -> Color
    let join: (CalendarEventInfo) -> Void
    private let hourHeight: CGFloat = 44
    private let gutter: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            header
            allDayRow
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hourLines
                        HStack(spacing: 0) {
                            Color.clear.frame(width: gutter)
                            ForEach(days, id: \.self) { day in column(day) }
                        }
                    }
                    .frame(height: hourHeight * 24)
                }
                .frame(height: 520)
                .onAppear { proxy.scrollTo(max(Calendar.current.component(.hour, from: Date()) - 2, 7), anchor: .top) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter, height: 1)
            ForEach(days, id: \.self) { day in
                let today = Calendar.current.isDateInToday(day)
                Button { selected = day } label: {
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2.weight(.semibold))
                            .foregroundStyle(today ? AnyShapeStyle(HeyLook.accent) : AnyShapeStyle(.secondary))
                        Text("\(Calendar.current.component(.day, from: day))").font(.title3.weight(today ? .bold : .regular)).monospacedDigit()
                            .foregroundStyle(today ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                            .frame(width: 34, height: 34)
                            .background { if today { Circle().fill(HeyLook.accent) } }
                    }
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var allDayRow: some View {
        let perDay = days.map { day in MonthGrid.events(events, on: day).filter(\.isAllDay) }
        if perDay.contains(where: { !$0.isEmpty }) {
            HStack(alignment: .top, spacing: 0) {
                Text(tr("ทั้งวัน")).font(.system(size: 9)).foregroundStyle(.secondary).frame(width: gutter, alignment: .trailing).padding(.trailing, 4)
                ForEach(Array(perDay.enumerated()), id: \.offset) { _, list in
                    VStack(spacing: 2) {
                        ForEach(list.prefix(3)) { e in chip(e) }
                        if list.count > 3 { Text("+\(list.count - 3)").font(.system(size: 9)).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .top).padding(.horizontal, 1)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func chip(_ e: CalendarEventInfo) -> some View {
        Text(e.displayTitle).font(.system(size: 10, weight: .medium)).lineLimit(1).foregroundStyle(.white)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color(e.calendarID), in: RoundedRectangle(cornerRadius: 4))
            .help(e.displayTitle)
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { h in
                HStack(alignment: .top, spacing: 4) {
                    Text(h == 0 ? "" : String(format: "%02d:00", h)).font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: gutter - 4, alignment: .trailing).offset(y: -6)
                    Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(h)
            }
        }
    }

    private func column(_ day: Date) -> some View {
        let timed = MonthGrid.events(events, on: day).compactMap { e in MonthGrid.hours(of: e, on: day).map { (e, $0) } }
        let lanes = MonthGrid.lanes(timed.map { (id: $0.0.id, start: $0.1.start, end: $0.1.end) })
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.primary.opacity(0.08)).frame(width: 1).frame(maxHeight: .infinity)
                ForEach(timed, id: \.0.id) { e, span in
                    let lane = lanes[e.id] ?? (0, 1)
                    let width = (geo.size.width - 4) / CGFloat(lane.of)
                    block(e, span)
                        .frame(width: max(width - 2, 8), height: max(CGFloat(span.end - span.start) * hourHeight - 2, 14))
                        .offset(x: 2 + CGFloat(lane.lane) * width, y: CGFloat(span.start) * hourHeight + 1)
                }
                if Calendar.current.isDateInToday(day) {
                    TimelineView(.periodic(from: .now, by: 60)) { ctx in
                        let h = ctx.date.timeIntervalSince(Calendar.current.startOfDay(for: ctx.date)) / 3600
                        HStack(spacing: 0) {
                            Circle().fill(.red).frame(width: 8, height: 8).offset(x: -4)
                            Rectangle().fill(.red).frame(height: 1.5)
                        }
                        .offset(y: CGFloat(h) * hourHeight - 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func block(_ e: CalendarEventInfo, _ span: (start: Double, end: Double)) -> some View {
        let tint = color(e.calendarID)
        let past = e.end < Date()
        return VStack(alignment: .leading, spacing: 1) {
            Text(e.displayTitle).font(.system(size: 10, weight: .semibold)).lineLimit(span.end - span.start >= 1 ? 2 : 1)
            if span.end - span.start >= 0.75 {
                Text(e.start.formatted(date: .omitted, time: .shortened)).font(.system(size: 9)).opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(past ? 0.55 : 0.95), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { if e.meetingURL != nil, !past { join(e) } }
        .help("\(e.displayTitle)\n\(e.start.formatted(date: .omitted, time: .shortened))–\(e.end.formatted(date: .omitted, time: .shortened))")
    }
}
