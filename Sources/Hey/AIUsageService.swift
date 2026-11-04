import AppKit
import Observation
import HeyDomain

/// Reads how much of your AI subscriptions is used up.
/// - Codex (ChatGPT plan): the last rate-limit reading in Codex's own session logs under `~/.codex/sessions` (local only, no network).
/// - Claude: Claude's plan-usage endpoint, using the Claude Code login that is already in your Keychain; the token is only sent to api.anthropic.com.
@MainActor @Observable
final class AIUsageService {
    static let claudeKey = "aiUsageClaude"
    static let codexKey = "aiUsageCodex"
    static let alertsKey = "aiUsageAlerts"

    private(set) var usages: [AIProvider: ProviderUsage] = [:]
    private(set) var errors: [AIProvider: String] = [:]
    private(set) var refreshing = false
    private(set) var lastRefresh: Date?

    @ObservationIgnored var onAlert: ((UsageAlert) -> Void)?
    @ObservationIgnored private var alerts = UsageAlerts()
    @ObservationIgnored private var timer: Timer?

    static var codexAvailable: Bool {
        FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/sessions")
    }

    func isEnabled(_ provider: AIProvider) -> Bool {
        switch provider {
        case .codex: UserDefaults.standard.object(forKey: Self.codexKey) as? Bool ?? Self.codexAvailable
        case .claude: UserDefaults.standard.bool(forKey: Self.claudeKey)
        }
    }

    func setEnabled(_ provider: AIProvider, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: provider == .codex ? Self.codexKey : Self.claudeKey)
        if !on { usages[provider] = nil; errors[provider] = nil } else { Task { await refresh() } }
    }

    var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.alertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.alertsKey) }
    }

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { Task { await self?.refresh() } }
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date() }
        for provider in AIProvider.allCases where isEnabled(provider) {
            do {
                let usage: ProviderUsage? = switch provider {
                case .codex: await Task.detached { Self.readCodex() }.value
                case .claude: try await Self.readClaude()
                }
                if let usage {
                    usages[provider] = usage
                    errors[provider] = nil
                    if alertsEnabled { for alert in alerts.evaluate(usage, now: Date()) { onAlert?(alert) } }
                } else {
                    usages[provider] = nil
                    errors[provider] = provider == .codex ? tr("ยังไม่พบข้อมูลโควตาจาก Codex — ลองใช้ Codex สักครั้ง") : tr("อ่านข้อมูลไม่สำเร็จ")
                }
            } catch {
                usages[provider] = nil
                errors[provider] = (error as? UsageError)?.message ?? error.localizedDescription
            }
        }
    }

    /// A one-line-per-provider summary for the pet's bubble and the menu.
    func summaryLines(now: Date = Date()) -> [String] {
        AIProvider.allCases.compactMap { usages[$0].map { UsageText.summary($0, now: now) } }
    }

    // MARK: Codex (local files)

    nonisolated private static func readCodex() -> ProviderUsage? {
        let root = URL(fileURLWithPath: NSHomeDirectory() + "/.codex/sessions")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]) else { return nil }
        var files: [(URL, Date)] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            files.append((url, date))
        }
        for (url, _) in files.sorted(by: { $0.1 > $1.1 }).prefix(8) {
            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            try? handle.seek(toOffset: size > 400_000 ? size - 400_000 : 0)
            guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() where line.contains("rate_limits") {
                if let usage = UsageParsers.codex(line: String(line)) { return usage }
            }
        }
        return nil
    }

    // MARK: Claude (plan usage endpoint)

    struct UsageError: Error { let message: String }

    private static func readClaude() async throws -> ProviderUsage? {
        let credentials = try await Task.detached { try claudeCredentials() }.value
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, timeoutInterval: 15)
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError(message: tr("การเข้าสู่ระบบ Claude Code หมดอายุ — เปิด Claude Code สักครั้งเพื่อต่ออายุ"))
        }
        guard http.statusCode == 200 else { throw UsageError(message: tr("Claude ตอบกลับผิดปกติ (รหัส {0})", http.statusCode)) }
        return UsageParsers.claude(json: data, plan: credentials.plan, now: Date())
    }

    nonisolated private static func claudeCredentials() throws -> (token: String, plan: String?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw UsageError(message: tr("ไม่พบการเข้าสู่ระบบ Claude Code ใน Keychain (หรือยังไม่ได้อนุญาต)"))
        }
        if let expires = (oauth["expiresAt"] as? NSNumber)?.doubleValue, expires / 1000 < Date().timeIntervalSince1970 {
            throw UsageError(message: tr("การเข้าสู่ระบบ Claude Code หมดอายุ — เปิด Claude Code สักครั้งเพื่อต่ออายุ"))
        }
        return (token, oauth["subscriptionType"] as? String)
    }
}
