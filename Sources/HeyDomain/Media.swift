import Foundation

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case screenshot, screenRecording, photo, video

    public var isVideo: Bool { self == .screenRecording || self == .video }

    public var label: String {
        switch self {
        case .screenshot: tr("ภาพหน้าจอ")
        case .screenRecording: tr("อัดหน้าจอ")
        case .photo: tr("ภาพจากกล้อง")
        case .video: tr("วิดีโอจากกล้อง")
        }
    }
}

public struct MediaItem: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var kind: MediaKind
    public var path: String
    public var createdAt: Date
    public var duration: Double?

    public init(kind: MediaKind, path: String, createdAt: Date, duration: Double? = nil) {
        self.kind = kind; self.path = path; self.createdAt = createdAt; self.duration = duration
    }
}

public struct CaptureSettings: Codable, Equatable, Sendable {
    /// Seconds to count down before a full-screen shot or a recording starts.
    public var countdown = 3
    public var recordSystemAudio = true
    public var recordMicrophone = false
    public init() {}
}

public enum CaptureNaming {
    /// e.g. `Screenshot 2027-01-15 08.00.00.png`; the time is local so it matches what the user sees.
    public static func fileName(for kind: MediaKind, at date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let stamp = String(format: "%04d-%02d-%02d %02d.%02d.%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!)
        switch kind {
        case .screenshot: return "Screenshot \(stamp).png"
        case .screenRecording: return "Screen Recording \(stamp).mp4"
        case .photo: return "Photo \(stamp).jpg"
        case .video: return "Video \(stamp).mov"
        }
    }
}
