import Foundation

/// Reads the last quota recorded by Codex without changing its sessions or login.
public enum CodexUsageReader {
    static let tailLimit = 400_000
    /// macOS does not ship a Zstandard decoder. Use an installed decoder without invoking a shell.
    static var zstdExecutable: URL? {
        ["/usr/bin/zstd", "/opt/homebrew/bin/zstd", "/usr/local/bin/zstd"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
            .map { URL(fileURLWithPath: $0) }
    }

    public static func read(home: URL) -> ProviderUsage? {
        let root = home.appendingPathComponent("sessions")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]) else { return nil }
        var files: [(URL, Date)] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" || url.lastPathComponent.hasSuffix(".jsonl.zst") {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            files.append((url, values?.contentModificationDate ?? .distantPast))
        }
        // Recent sessions may contain only null quota windows. Keep looking for a real reading.
        for (url, _) in files.sorted(by: { $0.1 == $1.1 ? $0.0.path < $1.0.path : $0.1 > $1.1 }) {
            guard let data = tail(of: url) else { continue }
            // A byte-limited tail can start inside a UTF-8 character. Do not discard the whole log.
            let text = String(decoding: data, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() where line.contains("rate_limits") {
                if let usage = UsageParsers.codex(line: String(line)) { return usage }
            }
        }
        return nil
    }

    private static func tail(of url: URL) -> Data? {
        if url.pathExtension != "zst" {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            do {
                let size = try handle.seekToEnd()
                try handle.seek(toOffset: size > UInt64(tailLimit) ? size - UInt64(tailLimit) : 0)
                return try handle.readToEnd()
            } catch { return nil }
        }
        guard let decoder = zstdExecutable else { return nil }
        let task = Process()
        task.executableURL = decoder
        task.arguments = ["-q", "-d", "-c", "--", url.path]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return nil }
        defer { try? output.fileHandleForReading.close() }
        var tail = Data()
        do {
            // Drain before waitUntilExit so a full pipe cannot deadlock the decoder.
            while let chunk = try output.fileHandleForReading.read(upToCount: 65_536), !chunk.isEmpty {
                tail.append(chunk)
                if tail.count > tailLimit { tail = Data(tail.suffix(tailLimit)) }
            }
        } catch {
            task.terminate()
            task.waitUntilExit()
            return nil
        }
        task.waitUntilExit()
        return task.terminationStatus == 0 ? tail : nil
    }
}
