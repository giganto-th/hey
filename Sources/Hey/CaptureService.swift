import AppKit
import Observation
import ScreenCaptureKit
import Vision
import HeyDomain

/// Screenshots and screen recordings through ScreenCaptureKit. Our own windows (the pet, the
/// countdown, notes…) are always left out of what is captured.
@MainActor
@Observable
final class CaptureService {
    private(set) var isRecording = false
    private(set) var elapsed = 0.0
    private(set) var busy = false

    @ObservationIgnored var onMessage: ((String, String?) -> Void)?
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let model: GameModel
    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private var recordingOutput: SCRecordingOutput?
    @ObservationIgnored private var recordingURL: URL?
    @ObservationIgnored private var recordingStarted: Date?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private let delegate = RecordingDelegate()

    init(model: GameModel) {
        self.model = model
        delegate.onFinished = { [weak self] error in self?.recordingFinished(error: error) }
        delegate.onStopped = { [weak self] error in self?.streamStopped(error: error) }
    }

    // MARK: folders

    static func directory(for kind: MediaKind) -> URL {
        let fm = FileManager.default
        let base = kind.isVideo ? fm.urls(for: .moviesDirectory, in: .userDomainMask)[0]
                                : fm.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Hey", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newURL(for kind: MediaKind, at date: Date = Date()) -> URL {
        directory(for: kind).appendingPathComponent(CaptureNaming.fileName(for: kind, at: date))
    }

    // MARK: screenshots

    /// `region == false`: whole screen after the countdown. `true`: drag out an area.
    func screenshot(region: Bool) async {
        guard !busy, Permissions.ensureScreenRecording() else { return }
        busy = true
        defer { busy = false }

        let screen: NSScreen
        var area: CGRect?
        if region {
            guard let picked = await RegionSelector.select() else { return }
            screen = picked.screen
            area = picked.rect
            try? await Task.sleep(for: .milliseconds(150))     // the dimmed overlay must be gone
        } else {
            onMessage?("ยิ้มหน่อย!", "camera.fill")
            await CountdownOverlay.run(seconds: model.game.capture.countdown)
            let mouse = NSEvent.mouseLocation
            screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main ?? NSScreen.screens[0]
        }

        do {
            let image = try await grab(screen: screen, area: area)
            let rep = NSBitmapImageRep(cgImage: image)
            guard let png = rep.representation(using: .png, properties: [:]) else { throw CaptureError.encoding }
            let now = Date()
            let url = Self.newURL(for: .screenshot, at: now)
            try png.write(to: url)
            model.perform { $0.addMedia(MediaItem(kind: .screenshot, path: url.path, createdAt: now)) }
        } catch {
            onMessage?("ถ่ายภาพหน้าจอไม่สำเร็จ", "exclamationmark.triangle.fill")
            FileHandle.standardError.write(Data("[Hey] screenshot failed: \(error)\n".utf8))
        }
    }

    /// One frame of `screen`, or of `area` (window coordinates) when given.
    private func grab(screen: NSScreen, area: CGRect?) async throws -> CGImage {
        let (display, filter) = try await filter(for: screen)
        let scale = Double(display.width) > 0 ? Double(screen.backingScaleFactor) : 1
        let config = SCStreamConfiguration()
        config.showsCursor = false
        if let area {
            // ScreenCaptureKit wants top-left-origin points relative to the display.
            config.sourceRect = CGRect(x: area.minX, y: screen.frame.height - area.maxY,
                                       width: area.width, height: area.height)
            config.width = Int(area.width * scale)
            config.height = Int(area.height * scale)
        } else {
            config.width = Int(Double(display.width) * scale)
            config.height = Int(Double(display.height) * scale)
        }
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Drag out an area, read the text in it, and put the text on the clipboard. Nothing is saved to disk.
    func readText() async {
        guard !busy, Permissions.ensureScreenRecording() else { return }
        busy = true
        defer { busy = false }
        guard let picked = await RegionSelector.select() else { return }
        try? await Task.sleep(for: .milliseconds(150))
        do {
            let image = try await grab(screen: picked.screen, area: picked.rect)
            let text = try await Task.detached { try TextReader.read(image) }.value
            guard !text.isEmpty else { onMessage?("ไม่พบข้อความในพื้นที่นี้", "text.magnifyingglass"); return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            let lines = text.split(whereSeparator: \.isNewline).count
            onMessage?("คัดลอกข้อความแล้ว \(lines) บรรทัด", "text.viewfinder")
        } catch {
            onMessage?("อ่านข้อความไม่สำเร็จ", "exclamationmark.triangle.fill")
            FileHandle.standardError.write(Data("[Hey] text read failed: \(error)\n".utf8))
        }
    }

    // MARK: recording

    func toggleRecording() {
        Task { if isRecording { await stopRecording() } else { await startRecording() } }
    }

    func startRecording() async {
        guard !busy, !isRecording, Permissions.ensureScreenRecording() else { return }
        busy = true
        defer { busy = false }

        onMessage?("เตรียมอัดนะ", "video.fill")
        await CountdownOverlay.run(seconds: model.game.capture.countdown)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let settings = model.game.capture

        do {
            let (display, filter) = try await filter(for: screen)
            let scale = Double(screen.backingScaleFactor)
            let config = SCStreamConfiguration()
            config.width = Int(Double(display.width) * scale)
            config.height = Int(Double(display.height) * scale)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.showsCursor = true
            config.capturesAudio = settings.recordSystemAudio
            config.excludesCurrentProcessAudio = true
            if settings.recordMicrophone, await Permissions.microphoneAllowed() { config.captureMicrophone = true }

            let url = Self.newURL(for: .screenRecording)
            let recording = SCRecordingOutputConfiguration()
            recording.outputURL = url
            recording.outputFileType = .mp4
            recording.videoCodecType = .h264
            let output = SCRecordingOutput(configuration: recording, delegate: delegate)

            let stream = SCStream(filter: filter, configuration: config, delegate: delegate)
            try stream.addRecordingOutput(output)
            try await stream.startCapture()

            self.stream = stream
            recordingOutput = output
            recordingURL = url
            recordingStarted = Date()
            isRecording = true
            elapsed = 0
            startTicker()
            onMessage?("กำลังอัด", "record.circle.fill")
            onChange?()
        } catch {
            onMessage?("เริ่มอัดไม่สำเร็จ", "exclamationmark.triangle.fill")
            FileHandle.standardError.write(Data("[Hey] recording failed to start: \(error)\n".utf8))
        }
    }

    func stopRecording() async {
        guard isRecording, let stream else { return }
        do { try await stream.stopCapture() } catch {
            FileHandle.standardError.write(Data("[Hey] stopCapture: \(error)\n".utf8))
            streamStopped(error: error)   // the finished callback won't come
        }
        // The saved-file callback (`recordingFinished`) completes the job.
    }

    private func recordingFinished(error: Error?) {
        guard let url = recordingURL else { return }      // already handled (the stream and the output both report)
        let seconds = recordingStarted.map { Date().timeIntervalSince($0) }
        cleanUpRecording()
        guard error == nil, FileManager.default.fileExists(atPath: url.path) else {
            onMessage?("บันทึกวิดีโอไม่สำเร็จ", "exclamationmark.triangle.fill")
            return
        }
        model.perform { $0.addMedia(MediaItem(kind: .screenRecording, path: url.path, createdAt: Date(), duration: seconds)) }
    }

    private func streamStopped(error: Error?) {
        guard isRecording else { return }
        if error != nil { onMessage?("การอัดหยุดกะทันหัน", "exclamationmark.triangle.fill") }
        // If the output already finished, `recordingFinished` ran; otherwise salvage what we have.
        if let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
            recordingFinished(error: nil)
        } else {
            cleanUpRecording()
        }
    }

    private func cleanUpRecording() {
        isRecording = false
        stream = nil
        recordingOutput = nil
        recordingURL = nil
        recordingStarted = nil
        ticker?.invalidate()
        ticker = nil
        onChange?()
    }

    private func startTicker() {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let start = self.recordingStarted else { return }
                self.elapsed = Date().timeIntervalSince(start)
                self.onChange?()
            }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    // MARK: helpers

    private enum CaptureError: Error { case noDisplay, encoding }

    private func filter(for screen: NSScreen) async throws -> (SCDisplay, SCContentFilter) {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == id }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let ours = content.applications.filter { $0.processID == pid }
        return (display, SCContentFilter(display: display, excludingApplications: ours, exceptingWindows: []))
    }
}

/// ScreenCaptureKit calls these on its own queues; the service hops back to the main actor.
private final class RecordingDelegate: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, @unchecked Sendable {
    var onFinished: (@MainActor (Error?) -> Void)?
    var onStopped: (@MainActor (Error?) -> Void)?

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in onFinished?(nil) }
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        Task { @MainActor in onFinished?(error) }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in onStopped?(error) }
    }
}

/// Text recognition for screenshots (Thai and English), on-device.
enum TextReader {
    static func read(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["th-TH", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
