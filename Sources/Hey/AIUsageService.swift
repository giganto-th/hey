import AppKit
import Observation
import Security
import UserNotifications
import HeyDomain

/// Reads how much of your AI subscriptions is used up, per account.
/// - Codex (ChatGPT plan): the last rate-limit reading in Codex's own session logs. Each Codex home folder (`~/.codex`, `~/.codex-2`, a folder
///   you add) is one account; local files only.
/// - Claude: Claude's plan-usage endpoint. Accounts come from the Claude Code logins in your Keychain and from tokens you connected by hand.
/// - Antigravity: the quota answered by the running Antigravity's own local server (one account per running copy); the last reading of
///   every account is remembered, so a closed copy still shows its last known quota.
@MainActor @Observable
final class AIUsageService {
    static let alertsKey = "aiUsageAlerts"
    static let warnKey = "aiUsageWarn"
    static let criticalKey = "aiUsageCritical"
    static let systemNotifyKey = "aiUsageSystemNotify"
    static let connectedKey = "aiUsageConnected"
    static let codexHomesKey = "aiUsageCodexHomes"
    static let antigravityCacheKey = "aiUsageAntigravityCache"
    static let hiddenAccountsKey = "aiUsageHiddenAccounts"
    static let keychainService = "Hey! AI accounts"

    struct AccountRow: Identifiable {
        let id: String
        let provider: AIProvider
        var name: String
        var usage: ProviderUsage?
        var error: String?
        /// Can be removed here (connected by hand / a folder you added).
        var removable: Bool
        /// A remembered reading of an account that is not running right now.
        var stale = false
    }

    private(set) var rows: [AIProvider: [AccountRow]] = [:]
    private(set) var refreshing = false
    private(set) var lastRefresh: Date?

    @ObservationIgnored var onAlert: ((UsageAlert) -> Void)?
    @ObservationIgnored private lazy var alerts = UsageAlerts(thresholds: thresholds)
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var labels: [String: String] = [:]          // Claude login id -> email, remembered for the session

    private(set) var hiddenAccountIDs = Set(UserDefaults.standard.stringArray(forKey: hiddenAccountsKey) ?? [])

    func rows(for provider: AIProvider) -> [AccountRow] {
        (rows[provider] ?? []).filter { !hiddenAccountIDs.contains($0.id) }
    }

    /// Local visibility only: never delete another app's login or session files.
    func hideAccount(_ id: String) {
        hiddenAccountIDs.insert(id)
        UserDefaults.standard.set(hiddenAccountIDs.sorted(), forKey: Self.hiddenAccountsKey)
    }

    func restoreHiddenAccounts() {
        hiddenAccountIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.hiddenAccountsKey)
        Task { await refresh() }
    }

    private func loadDemo() {
        let now = Date()
        func usage(_ provider: AIProvider, _ id: String, _ who: String, _ plan: String, _ windows: [(String, Double, TimeInterval)]) -> AccountRow {
            let u = ProviderUsage(provider: provider, accountID: id, accountLabel: who, plan: plan,
                                  windows: windows.map { UsageWindow(id: $0.0, usedPercent: $0.1, resetsAt: now.addingTimeInterval($0.2)) }, asOf: now)
            return AccountRow(id: id, provider: provider, name: who, usage: u, error: nil, removable: false)
        }
        rows = [
            .claude: [usage(.claude, "d1", "work@example.com", "Pro", [("5h", 43, 7200), ("7d", 58, 380_000)]),
                      usage(.claude, "d2", "home@example.com", "Max", [("5h", 12, 12_000), ("7d", 91, 250_000)])],
            .codex: [usage(.codex, "d3", "me@example.com", "Plus", [("5h", 66, 9000), ("7d", 42, 520_000)])],
            .antigravity: [usage(.antigravity, "d4", "me@example.org", "Pro", [("Gemini 3.8 Flash +5", 18, 600_000)])],
        ]
        lastRefresh = now
    }

    static var codexAvailable: Bool { FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/sessions") }
    static var antigravityAvailable: Bool {
        FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.gemini/bin/agy")
            || FileManager.default.fileExists(atPath: "/Applications/Antigravity.app")
    }

    private func key(_ provider: AIProvider) -> String {
        switch provider {
        case .codex: "aiUsageCodex"
        case .claude: "aiUsageClaude"
        case .antigravity: "aiUsageAntigravity"
        }
    }

    func isEnabled(_ provider: AIProvider) -> Bool {
        let stored = UserDefaults.standard.object(forKey: key(provider)) as? Bool
        switch provider {
        case .codex: return stored ?? Self.codexAvailable
        case .claude: return stored ?? false
        case .antigravity: return stored ?? Self.antigravityAvailable
        }
    }

    func setEnabled(_ provider: AIProvider, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: key(provider))
        if !on { rows[provider] = nil } else { Task { await refresh() } }
    }

    var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.alertsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.alertsKey) }
    }

    /// Where the pet starts warning, and where it warns again (percent of a quota window used).
    var warnAt: Int {
        get { UserDefaults.standard.object(forKey: Self.warnKey) as? Int ?? 80 }
        set { UserDefaults.standard.set(newValue, forKey: Self.warnKey); alerts.thresholds = thresholds }
    }
    var criticalAt: Int {
        get { UserDefaults.standard.object(forKey: Self.criticalKey) as? Int ?? 95 }
        set { UserDefaults.standard.set(newValue, forKey: Self.criticalKey); alerts.thresholds = thresholds }
    }
    private var thresholds: [Int] { [warnAt, max(criticalAt, warnAt + 1)] }

    /// Also post a macOS notification (not only the pet's bubble).
    var systemNotify: Bool {
        get { UserDefaults.standard.bool(forKey: Self.systemNotifyKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.systemNotifyKey)
            if newValue { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        }
    }

    func postSystemNotification(_ text: String) {
        guard systemNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = "Hey!"
        content.body = text
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    var connected: [ConnectedAccount] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.connectedKey) else { return [] }
            return (try? JSONDecoder().decode([ConnectedAccount].self, from: data)) ?? []
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Self.connectedKey) }
    }

    var customCodexHomes: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.codexHomesKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.codexHomesKey) }
    }

    func addCodexHome(_ url: URL) {
        let path = url.path
        if !customCodexHomes.contains(path) { customCodexHomes += [path] }
        UserDefaults.standard.set(true, forKey: key(.codex))
        Task { await refresh() }
    }

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: refreshing

    func refresh() async {
        if ProcessInfo.processInfo.environment["HEY_DEV_USAGE_DEMO"] != nil { loadDemo(); return }          // screenshots with made-up accounts
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date() }
        if isEnabled(.codex) { rows[.codex] = await refreshCodex() }
        if isEnabled(.claude) { rows[.claude] = await refreshClaude() }
        if isEnabled(.antigravity) { rows[.antigravity] = await refreshAntigravity() }
    }

    private func notify(_ usage: ProviderUsage) {
        guard alertsEnabled, !hiddenAccountIDs.contains(usage.accountID) else { return }
        for alert in alerts.evaluate(usage, now: Date()) { onAlert?(alert) }
    }

    private func refreshCodex() async -> [AccountRow] {
        let custom = customCodexHomes
        let homes = await Task.detached(operation: { Self.codexHomes(custom: custom) }).value
        var result: [AccountRow] = []
        var seen = Set<String>()
        for home in homes {
            guard !hiddenAccountIDs.contains("codex:\(home.url.path)") else { continue }
            if let email = home.email, !seen.insert(email).inserted { continue }
            let name = home.email ?? home.url.lastPathComponent
            var row = AccountRow(id: "codex:\(home.url.path)", provider: .codex, name: name, usage: nil, error: nil, removable: home.custom)
            if var usage = await Task.detached(operation: { Self.readCodex(home: home.url) }).value {
                usage.accountID = row.id
                usage.accountLabel = home.email ?? (homes.count > 1 ? name : nil)
                row.usage = usage
                notify(usage)
            } else {
                row.error = tr("ยังไม่พบข้อมูลโควตาจาก Codex — ลองใช้ Codex สักครั้ง")
            }
            result.append(row)
        }
        return result
    }

    private func refreshClaude() async -> [AccountRow] {
        var logins = await Task.detached(operation: { Self.keychainLogins() }).value
        for account in connected {
            if let token = Self.token(forConnected: account.id) {
                logins.append(Login(id: account.id, token: token, plan: nil, expiresAt: nil, name: account.name, removable: true))
            }
        }
        var result: [AccountRow] = []
        var seenEmails = Set<String>()
        for login in logins {
            guard !hiddenAccountIDs.contains(login.id) else { continue }
            var row = AccountRow(id: login.id, provider: .claude, name: login.name ?? labels[login.id] ?? tr("บัญชี Claude"),
                                 usage: nil, error: nil, removable: login.removable)
            if let expires = login.expiresAt, expires < Date() {
                row.error = tr("การเข้าสู่ระบบหมดอายุ — เปิด Claude Code ด้วยบัญชีนี้สักครั้งเพื่อต่ออายุ")
                result.append(row); continue
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
            result.append(row)
        }
        return result
    }

    private func refreshAntigravity() async -> [AccountRow] {
        var cache = loadAntigravityCache()
        let live = await Task.detached(operation: { await Self.readAntigravity() }).value
        var liveIDs = Set<String>()
        for usage in live {
            cache[usage.accountID] = usage
            liveIDs.insert(usage.accountID)
            notify(usage)
        }
        saveAntigravityCache(cache)
        return cache.values.sorted { $0.title < $1.title }.map { usage in
            AccountRow(id: usage.accountID, provider: .antigravity, name: usage.accountLabel ?? "Antigravity", usage: usage, error: nil,
                       removable: !liveIDs.contains(usage.accountID), stale: !liveIDs.contains(usage.accountID))
        }
    }

    func forgetAntigravity(_ id: String) {
        var cache = loadAntigravityCache()
        cache[id] = nil
        saveAntigravityCache(cache)
        rows[.antigravity]?.removeAll { $0.id == id }
    }

    func removeCodexHome(_ id: String) {
        customCodexHomes = customCodexHomes.filter { "codex:\($0)" != id }
        rows[.codex]?.removeAll { $0.id == id }
    }

    private func loadAntigravityCache() -> [String: ProviderUsage] {
        guard let data = UserDefaults.standard.data(forKey: Self.antigravityCacheKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ProviderUsage].self, from: data)) ?? [:]
    }

    private func saveAntigravityCache(_ cache: [String: ProviderUsage]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(cache), forKey: Self.antigravityCacheKey)
    }

    /// A one-line-per-account summary for the pet's bubble and the menu.
    func summaryLines(now: Date = Date()) -> [String] {
        AIProvider.allCases.flatMap { rows(for: $0) }.compactMap(\.usage).map { UsageText.summary($0, now: now) }
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
        UserDefaults.standard.set(true, forKey: key(.claude))
        await refresh()
        return nil
    }

    func disconnect(_ id: String) {
        Self.removeToken(forConnected: id)
        connected = connected.filter { $0.id != id }
        rows[.claude]?.removeAll { $0.id == id }
    }

    // MARK: Codex (local files)

    struct CodexHome: Sendable { let url: URL; let email: String?; let custom: Bool }

    /// `~/.codex` and any `~/.codex-*` folder that has sessions or a login, plus the folders you added.
    nonisolated private static func codexHomes(custom: [String]) -> [CodexHome] {
        let fm = FileManager.default
        var urls: [(URL, Bool)] = []
        let names = (try? fm.contentsOfDirectory(atPath: NSHomeDirectory())) ?? []
        for name in names.sorted() where name == ".codex" || (name.hasPrefix(".codex-") || name.hasPrefix(".codex_")) {
            urls.append((URL(fileURLWithPath: NSHomeDirectory() + "/" + name), false))
        }
        for path in custom where !urls.contains(where: { $0.0.path == path }) { urls.append((URL(fileURLWithPath: path), true)) }
        return urls.compactMap { url, isCustom in
            guard fm.fileExists(atPath: url.appendingPathComponent("sessions").path) || fm.fileExists(atPath: url.appendingPathComponent("auth.json").path) else { return nil }
            var email: String?
            if let data = try? Data(contentsOf: url.appendingPathComponent("auth.json")),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tokens = root["tokens"] as? [String: Any], let idToken = tokens["id_token"] as? String {
                email = UsageParsers.jwtEmail(idToken)
            }
            return CodexHome(url: url, email: email, custom: isCustom)
        }
    }

    nonisolated private static func readCodex(home: URL) -> ProviderUsage? {
        CodexUsageReader.read(home: home)
    }

    // MARK: Antigravity (the running app's local server)

    /// Asks every running Antigravity copy (`agy --csrf_token=… --hub-port=…`) for its user status.
    nonisolated private static func readAntigravity() async -> [ProviderUsage] {
        guard let ps = run("/bin/ps", ["-axo", "pid,command"]) else { return [] }
        var found: [ProviderUsage] = []
        for line in ps.components(separatedBy: "\n") where line.contains("/agy ") && line.contains("--csrf_token=") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let token = capture(#"--csrf_token=([\w-]+)"#, in: line) else { continue }
            let pid = String(parts[0])
            let listening = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-p", pid]) ?? ""
            let ports = Set(listening.components(separatedBy: "\n").compactMap { capture(#":(\d+) \(LISTEN\)"#, in: $0) }).sorted()
            var usage: ProviderUsage?
            for scheme in ["http", "https"] where usage == nil {
                for port in ports where usage == nil {
                    usage = await antigravityStatus(scheme: scheme, port: port, token: token)
                }
            }
            if let usage, !found.contains(where: { $0.accountID == usage.accountID }) { found.append(usage) }
        }
        return found
    }

    nonisolated private static func antigravityStatus(scheme: String, port: String, token: String) async -> ProviderUsage? {
        guard let url = URL(string: "\(scheme)://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 4)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(token, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.httpBody = Data(#"{"metadata":{"ideName":"antigravity","extensionName":"antigravity","ideVersion":"unknown","locale":"en"}}"#.utf8)
        let session = URLSession(configuration: .ephemeral, delegate: LocalTrust(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return UsageParsers.antigravity(json: data, now: Date())
    }

    /// The local server uses a self-signed certificate; this accepts it for 127.0.0.1 only.
    private final class LocalTrust: NSObject, URLSessionDelegate {
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.host == "127.0.0.1", let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

    nonisolated private static func capture(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern), let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
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
