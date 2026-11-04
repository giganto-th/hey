import Foundation

/// The line the pet says on the first check-in of the day, chosen by the hour so it never feels canned.
public enum Greeting {
    public struct Line: Equatable, Sendable {
        public var text: String
        public var symbol: String
    }

    public static func line(hour: Int) -> Line {
        switch hour {
        case 5..<11: Line(text: "อรุณสวัสดิ์! วันนี้ลุยกัน", symbol: "sunrise.fill")
        case 11..<14: Line(text: "เที่ยงแล้ว อย่าลืมกินข้าวนะ", symbol: "sun.max.fill")
        case 14..<18: Line(text: "สวัสดีตอนบ่าย สู้ ๆ นะ", symbol: "cloud.sun.fill")
        case 18..<22: Line(text: "สวัสดีตอนเย็น วันนี้เป็นไงบ้าง", symbol: "sunset.fill")
        default: Line(text: "ดึกแล้วยังไม่นอนอีก", symbol: "moon.stars.fill")
        }
    }
}
