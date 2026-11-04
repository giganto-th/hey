import AppKit
import AVFoundation
import HeyDomain

/// A small window with a live preview and Photo / Record buttons. The camera only runs while it is open.
@MainActor
final class CameraController: NSObject, NSWindowDelegate {
    private let model: GameModel
    var onMessage: ((String, String?) -> Void)?

    private var window: NSPanel?
    private var session: AVCaptureSession?
    // An output can only belong to one session, so each opening of the window gets new ones.
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private let helper = OutputHelper()
    private var recordButton: NSButton?
    private var statusLabel: NSTextField?
    private var recordingStart: Date?
    private var timer: Timer?

    init(model: GameModel) {
        self.model = model
        super.init()
        helper.onPhoto = { [weak self] data in self?.savePhoto(data) }
        helper.onMovie = { [weak self] url, error in self?.movieFinished(url, error) }
    }

    var isOpen: Bool { window?.isVisible ?? false }
    var isRecording: Bool { movieOutput.isRecording }

    func show() async {
        if let window { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); return }
        guard await Permissions.ensureCamera() else { return }
        let wantsMic = model.game.capture.recordMicrophone
        let micOK = wantsMic ? await Permissions.microphoneAllowed() : false

        photoOutput = AVCapturePhotoOutput()
        movieOutput = AVCaptureMovieFileOutput()
        let session = AVCaptureSession()
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            onMessage?(tr("ไม่พบกล้อง"), "exclamationmark.triangle.fill")
            return
        }
        session.addInput(input)
        if micOK, let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
            session.addInput(micInput)
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        self.session = session

        buildWindow(session: session)
        let box = SessionBox(session)
        Task.detached { box.session.startRunning() }      // blocks, so keep it off the main thread
    }

    func close() { window?.close() }

    // MARK: window

    private func buildWindow(session: AVCaptureSession) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                            styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = tr("กล้อง")
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let preview = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 360))
        preview.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        layer.frame = preview.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        if let c = layer.connection, c.isVideoMirroringSupported {      // mirror like a mirror; saved files stay unmirrored
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = true
        }
        preview.layer?.addSublayer(layer)
        preview.layer?.backgroundColor = NSColor.black.cgColor

        let photo = NSButton(title: tr("ถ่ายรูป"), target: self, action: #selector(takePhoto))
        let record = NSButton(title: tr("เริ่มอัด"), target: self, action: #selector(toggleRecord))
        recordButton = record
        let label = NSTextField(labelWithString: "")
        statusLabel = label
        let bar = NSStackView(views: [photo, record, label])
        bar.orientation = .horizontal
        bar.spacing = 12
        bar.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        let root = NSStackView(views: [preview, bar])
        root.orientation = .vertical
        root.spacing = 0
        panel.contentView = root
        preview.heightAnchor.constraint(equalToConstant: 360).isActive = true
        preview.widthAnchor.constraint(equalToConstant: 480).isActive = true

        if let area = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: area.midX - 240, y: area.midY - 180))
        }
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if movieOutput.isRecording { movieOutput.stopRecording() }
        timer?.invalidate()
        timer = nil
        if let session { let box = SessionBox(session); Task.detached { box.session.stopRunning() } }
        session = nil
        window = nil
    }

    // MARK: actions

    @objc private func takePhoto() {
        guard photoOutput.connection(with: .video)?.isActive == true else { onMessage?(tr("กล้องยังไม่พร้อม ลองอีกครั้ง"), "camera.fill"); return }
        let settings = photoOutput.availablePhotoCodecTypes.contains(.jpeg)
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]) : AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: helper)
    }

    @objc private func toggleRecord() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        } else {
            guard movieOutput.connection(with: .video)?.isActive == true else { onMessage?(tr("กล้องยังไม่พร้อม ลองอีกครั้ง"), "camera.fill"); return }
            let url = CaptureService.newURL(for: .video)
            movieOutput.startRecording(to: url, recordingDelegate: helper)
            recordButton?.title = tr("หยุดอัด")
            recordingStart = Date()
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let start = self.recordingStart else { return }
                    let s = Int(Date().timeIntervalSince(start))
                    self.statusLabel?.stringValue = String(format: "● REC %d:%02d", s / 60, s % 60)
                    self.statusLabel?.textColor = .systemRed
                }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    private func savePhoto(_ data: Data?) {
        guard let data else { onMessage?(tr("ถ่ายรูปไม่สำเร็จ"), "exclamationmark.triangle.fill"); return }
        let now = Date()
        let url = CaptureService.newURL(for: .photo, at: now)
        do {
            try data.write(to: url)
            model.perform { $0.addMedia(MediaItem(kind: .photo, path: url.path, createdAt: now)) }
        } catch {
            onMessage?(tr("บันทึกรูปไม่สำเร็จ"), "exclamationmark.triangle.fill")
        }
    }

    private func movieFinished(_ url: URL, _ error: Error?) {
        timer?.invalidate()
        timer = nil
        recordButton?.title = tr("เริ่มอัด")
        statusLabel?.stringValue = ""
        let seconds = recordingStart.map { Date().timeIntervalSince($0) }
        recordingStart = nil
        // AVFoundation reports an "error" for some normal stops (e.g. disk full is real, max-duration is not), so trust the file.
        guard FileManager.default.fileExists(atPath: url.path) else {
            onMessage?(tr("บันทึกวิดีโอไม่สำเร็จ"), "exclamationmark.triangle.fill")
            return
        }
        model.perform { $0.addMedia(MediaItem(kind: .video, path: url.path, createdAt: Date(), duration: seconds)) }
    }
}

private struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
    init(_ s: AVCaptureSession) { session = s }
}

/// AVFoundation's delegate callbacks arrive on its own queues.
private final class OutputHelper: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    var onPhoto: (@MainActor (Data?) -> Void)?
    var onMovie: (@MainActor (URL, Error?) -> Void)?

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        Task { @MainActor in onPhoto?(data) }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in onMovie?(url, error) }
    }
}
