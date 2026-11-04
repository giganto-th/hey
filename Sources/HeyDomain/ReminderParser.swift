import Foundation

public struct ParsedReminder: Equatable, Sendable {
    public var text: String
    public var fireAt: Date
}

/// Understands the common short forms in Thai and English, e.g.
/// "ประชุม อีก 20 นาที", "พรุ่งนี้ 9 โมง ส่งงาน", "บ่าย 2 โมง กินยา", "call mom 18:30", "in 2 hours".
public enum ReminderParser {
    public static func parse(_ input: String, now: Date, calendar: Calendar = .current) -> ParsedReminder? {
        var text = input

        // 1) relative: "อีก 20 นาที" / "in 20 minutes"
        if let m = firstMatch(#"(?:อีก|in)\s*(\d+)\s*(นาที|ชั่วโมง|ชม\.?|วินาที|minutes?|mins?|hours?|hrs?|seconds?|secs?)"#, in: text) {
            let n = Double(m.groups[0]) ?? 0
            let unit = m.groups[1].lowercased()
            let seconds: Double
            if unit.hasPrefix("ชั่ว") || unit.hasPrefix("ชม") || unit.hasPrefix("h") { seconds = 3600 }
            else if unit.hasPrefix("วิ") || unit.hasPrefix("s") { seconds = 1 }
            else { seconds = 60 }
            guard n > 0 else { return nil }
            text.removeSubrange(m.range)
            return ParsedReminder(text: clean(text), fireAt: now.addingTimeInterval(n * seconds))
        }

        // 2) wall-clock time, optionally with "tomorrow"
        var tomorrow = false
        if let m = firstMatch(#"พรุ่งนี้|tomorrow"#, in: text) {
            tomorrow = true
            text.removeSubrange(m.range)
        }

        var hour: Int?
        var minute = 0

        if let m = firstMatch(#"(\d{1,2})\s*[:.]\s*(\d{2})\s*(?:น\.?)?"#, in: text) {
            hour = Int(m.groups[0]); minute = Int(m.groups[1]) ?? 0
            text.removeSubrange(m.range)
        } else if let m = firstMatch(#"(\d{1,2})\s*(am|pm)"#, in: text) {
            var h = Int(m.groups[0]) ?? 0
            let pm = m.groups[1].lowercased() == "pm"
            if pm, h < 12 { h += 12 }
            if !pm, h == 12 { h = 0 }
            hour = h
            text.removeSubrange(m.range)
        } else if let m = firstMatch(#"(\d{1,2})\s*ทุ่ม"#, in: text) {
            if let n = Int(m.groups[0]), (1...5).contains(n) { hour = 18 + n }
            text.removeSubrange(m.range)
        } else if let m = firstMatch(#"(บ่าย|เย็น|เช้า|ตอนเช้า)?\s*(\d{1,2})\s*โมง(?:\s*(ครึ่ง))?"#, in: text) {
            var h = Int(m.groups[1]) ?? 0
            switch m.groups[0] {
            case "บ่าย": if h < 12 { h += 12 }
            case "เย็น": if h < 12 { h += 12 }
            default: break
            }
            hour = h
            minute = m.groups[2].isEmpty ? 0 : 30
            text.removeSubrange(m.range)
        }

        guard let h = hour, (0...23).contains(h), (0...59).contains(minute) else { return nil }
        guard var fire = calendar.date(bySettingHour: h, minute: minute, second: 0, of: now) else { return nil }
        if tomorrow {
            fire = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire
        } else if fire <= now {
            fire = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire
        }
        return ParsedReminder(text: clean(text), fireAt: fire)
    }

    private struct Match {
        var range: Range<String.Index>
        var groups: [String]
    }

    private static func firstMatch(_ pattern: String, in s: String) -> Match? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
              let whole = Range(m.range, in: s) else { return nil }
        var groups: [String] = []
        for i in 1..<max(m.numberOfRanges, 1) {
            let r = m.range(at: i)
            groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        return Match(range: whole, groups: groups)
    }

    private static func clean(_ s: String) -> String {
        let t = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return t.isEmpty ? "เตือน" : t
    }
}
