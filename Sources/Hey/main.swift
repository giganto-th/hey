import AppKit

setvbuf(stdout, nil, _IOLBF, 0)   // keep dev logs visible when redirected

// One pet per save: a second copy would overwrite the first one's progress.
let lockPath = GameModel.dataDirectory().appendingPathComponent(".lock").path
let lockFile = open(lockPath, O_CREAT | O_RDWR, 0o644)
guard lockFile >= 0, flock(lockFile, LOCK_EX | LOCK_NB) == 0 else {
    FileHandle.standardError.write(Data("[Hey] already running, exiting\n".utf8))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
