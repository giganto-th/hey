import AppKit
import Observation
import Security
import HeyDomain

/// Reads how much of your AI subscriptions is used up.
/// - Codex (ChatGPT plan): the last rate-limit reading in Codex's own session logs under `~/.codex/sessions` (local only, no network).
/// - Claude: Claude's plan-usage endpoint. Accounts come from the Claude Code logins found in your Keychain (log a second account in
///   with `CLAUDE_CONFIG_DIR=~/.claude-2 claude`) and from tokens you connected by hand; a token is only ever sent to api.anthropic.com.
@MainActor @Observable
final class AIUsageService {
    static let claudeKey = "aiUsageClaude"
    static let codexKey = "aiUsageCodex"
    static let alertsKey = "aiUsageAlerts"
    static let connectedKey = "aiUsageConnected"
    static let keychainService = "Hey! AI accounts"

    struct ClaudeRow: Identifiable {
        let id: String
        var name: String
        var usage: ProviderUsage?
        var error: String?
        /// Connected by hand (can be removed here), as opposed to found in the Keychain.
        var removable: Bool
    }

    private(set) var codexUsage: ProviderUsage?
    private(set) var codexError: String?
    private(set) var claudeRows: [ClaudeRow] = []
    private(set) var refreshing = false
    private(set) var lastRefresh: Date?

    @ObservationIgnored var onAlert: ((UsageAlert) -> Void)?
    @ObservationIgnored private var alerts = UsageAlerts()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var labels: [String: String] = [:]          // login id -> email, remembered for the session

    static var codexAvailable: Bool { FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/sessions") }

    func isEnabled(_ provider: AIProvider) -> Bool {
        switch provider {
        case .codex: UserDefaults.standard.object(forKey: Self.codexKey) as? Bool ?? Self.codexAvailable
        case .claude: UserDefaults.standard.bool(forKey: Self.claudeKey)
        }
    }

    func setEnabled(_ provider: AIProvider, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: provider == .codex ? Self.codexKey : Self.claudeKey)
        if !on {
            if provider == .codex { codexUsage = nil; codexError = nil } else { claudeRows = [] }
        } else { Task { await refresh() } }
    }

    var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.alertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.alertsKey) }
    }

    var connected: [ConnectedAccount] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.connectedKey) else { return [] }
            return (try? JSONDecoder().decode([ConnectedAccount].self, from: data)) ?? []
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Self.connectedKey) }
    }

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { Task { await self?.refresh() } }
        }
    }

    // MARK: refreshing

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date() }
        if isEnabled(.codex) {
            if let usage = await Task.detached(operation: { Self.readCodex() }).value {
                codexUsage = usage; codexError = nil; notify(usage)
            } else {
                codexUsage = nil; codexError = tr("ยังไม่พบข้อมูลโควตาจาก Codex — ลองใช้ Codex สักครั้ง")
            }
        }
        if isEnabled(.claude) { await refreshClaude() }
    }

    private func notify(_ usage: ProviderUsage) {
        guard alertsEnabled else { return }
        for alert in alerts.evaluate(usage, now: Date()) { onAlert?(alert) }
    }

    private func refreshClaude() async {
        var logins = await Task.detached(operation: { Self.keychainLogins() }).value
        for account in connected {
            if let token = Self.token(forConnected: account.id) {
                logins.append(Login(id: account.id, token: token, plan: nil, expiresAt: nil, name: account.name, removable: true))
            }
        }
        var rows: [ClaudeRow] = []
        var seenEmails = Set<String>()
        for login in logins {
            var row = ClaudeRow(id: login.id, name: login.name ?? labels[login.id] ?? tr("บัญชี Claude"), usage: nil, error: nil, removable: login.removable)
            if let expires = login.expiresAt, expires < Date() {
                row.error = tr("การเข้าสู่ระบบหมดอายุ — เปิด Claude Code ด้วยบัญชีนี้สักครั้งเพื่อต่ออายุ")
                rows.append(row); continue
            }
            if labels[login.id] == nil, let email = try? await Self.fetchEmail(token: login.token) { labels[login.id] = email }
            if let email = labels[login.id] {
                if !login.removable, !seenEmails.insert(email).inserted { continue }          // the same account found twice
                if login.name == nil { row.name = email }
            }
            do {
                let usage = try await Self.fetchClaude(login: login, label: row.name)
                row.usage = usage
                notify(usage)
            } catch {
                row.error = (error as? UsageError)?.message ?? error.localizedDescription
            }
            rows.append(row)
        }
        claudeRows = rows
    }

    /// A one-line-per-account summary for the pet's bubble and the menu.
    func summaryLines(now: Date = Date()) -> [String] {
        ([codexUsage] + claudeRows.map(\.usage)).compactMap { $0 }.map { UsageText.summary($0, now: now) }
    }

    // MARK: connecting an account by hand

    /// Check a pasted token against the usage endpoint and, if it works, keep it in the Keychain. Returns an error message or nil.
    func connect(name: String, token: String) async -> String? {
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return tr("ยังไม่ได้ใส่โทเคน") }
        let account = ConnectedAccount(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("บัญชี Claude") : name)
        do {
            _ = try await Self.fetchClaude(login: Login(id: account.id, token: cleaned, plan: nil, expiresAt: nil, name: account.name, removable: true), label: account.name)
        } catch {
            return (error as? UsageError)?.message ?? error.localizedDescription
        }
        Self.store(token: cleaned, forConnected: account.id)
        connected += [account]
        UserDefaults.standard.set(true, forKey: Self.claudeKey)
        await refresh()
        return nil
    }

    func disconnect(_ id: String) {
        Self.removeToken(forConnected: id)
        connected = connected.filter { $0.id != id }
        claudeRows.removeAll { $0.id == id }
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

    // MARK: Claude

    struct UsageError: Error { let message: String }

    struct Login: Sendable {
        let id: String
        let token: String
        let plan: String?
        let expiresAt: Date?
        let name: String?
        let removable: Bool
    }

    /// Every Claude Code login in the login keychain (one per config folder). Items without a Claude account login are skipped.
    nonisolated private static func keychainLogins() -> [Login] {
        guard let dump = run("/usr/bin/security", ["dump-keychain", NSHomeDirectory() + "/Library/Keychains/login.keychain-db"]) else { return [] }
        let services = Set(dump.components(separatedBy: "\n").compactMap { line -> String? in
            guard let r = line.range(of: #""svce"<blob>=""#) else { return nil }
            let rest = line[r.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            let name = String(rest[..<end])
            return name.hasPrefix("Claude Code-credentials") ? name : nil
        }).sorted()
        var logins: [Login] = []
        for service in services {
            guard let json = run("/usr/bin/security", ["find-generic-password", "-s", service, "-w"]),
                  let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = root["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String else { continue }
            let expires = (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
            logins.append(Login(id: "keychain:\(service)", token: token, plan: oauth["subscriptionType"] as? String,
                                expiresAt: expires, name: nil, removable: false))
        }
        return logins
    }

    nonisolated private static func run(_ path: String, _ args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let out = Pipe()
        task.standardOutput = out
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return task.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil
    }

    private static func request(_ path: String, token: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/" + path)!, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return request
    }

    private static func fetchEmail(token: String) async throws -> String? {
        let (data, response) = try await URLSession.shared.data(for: request("profile", token: token))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return ClaudeProfile.label(from: data)
    }

    private static func fetchClaude(login: Login, label: String) async throws -> ProviderUsage {
        let (data, response) = try await URLSession.shared.data(for: request("usage", token: login.token))
        guard let http = response as? HTTPURLResponse else { throw UsageError(message: tr("อ่านข้อมูลไม่สำเร็จ")) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError(message: login.removable
                ? tr("โทเคนใช้ไม่ได้ (หมดอายุ หรือไม่มีสิทธิ์อ่านโควตา)")
                : tr("การเข้าสู่ระบบหมดอายุ — เปิด Claude Code ด้วยบัญชีนี้สักครั้งเพื่อต่ออายุ"))
        }
        guard http.statusCode == 200 else { throw UsageError(message: tr("Claude ตอบกลับผิดปกติ (รหัส {0})", http.statusCode)) }
        guard let usage = UsageParsers.claude(json: data, plan: login.plan, accountID: login.id, accountLabel: label, now: Date()) else {
            throw UsageError(message: tr("อ่านข้อมูลไม่สำเร็จ"))
        }
        return usage
    }

    // MARK: tokens you connected (Hey!'s own Keychain items)

    private static func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: id]
    }

    private static func store(token: String, forConnected id: String) {
        var attributes = query(id)
        SecItemDelete(attributes as CFDictionary)
        attributes[kSecValueData as String] = Data(token.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func token(forConnected id: String) -> String? {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func removeToken(forConnected id: String) { SecItemDelete(query(id) as CFDictionary) }
}
