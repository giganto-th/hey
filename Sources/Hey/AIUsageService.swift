import AppKit
import CryptoKit
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
    static let claudeCacheKey = "aiUsageClaudeCache"
    static let claudeLabelsKey = "aiUsageClaudeLabels"
    static let hiddenAccountsKey = "aiUsageHiddenAccounts"
    static let menuBarKey = "aiUsageMenuBar"
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

    private(set) var rows: [AIProvider: [AccountRow]] = [:] {
        didSet { onChange?() }
    }
    var menuBarSettings: UsageMenuBarSettings = {
        guard let data = UserDefaults.standard.data(forKey: menuBarKey),
              let settings = try? JSONDecoder().decode(UsageMenuBarSettings.self, from: data) else { return UsageMenuBarSettings() }
        return settings
    }() {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(menuBarSettings), forKey: Self.menuBarKey)
            onChange?()
        }
    }
    private(set) var refreshing = false {
        didSet { onChange?() }
    }
    private(set) var lastRefresh: Date?

    @ObservationIgnored var onAlert: ((UsageAlert) -> Void)?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private lazy var alerts = UsageAlerts(thresholds: thresholds)
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var labels: [String: String] =             // Claude login id -> email, remembered across launches
        (UserDefaults.standard.dictionary(forKey: claudeLabelsKey) as? [String: String]) ?? [:]
    @ObservationIgnored private var renewAttempts: [String: Date] = [:]  // Claude login id -> when Hey! last asked `claude` to renew it
    /// A 5-hour or weekly quota just started over (the pet sets off fireworks).
    @ObservationIgnored var onReset: (([UsageReset]) -> Void)?
    @ObservationIgnored private var resets = UsageResets()
    @ObservationIgnored private var resetTimer: Timer?

    private(set) var hiddenAccountIDs = Set(UserDefaults.standard.stringArray(forKey: hiddenAccountsKey) ?? []) {
        didSet { onChange?() }
    }

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
        defer { lastRefresh = Date(); refreshing = false }
        if isEnabled(.codex) { rows[.codex] = await refreshCodex() }
        if isEnabled(.claude) { rows[.claude] = await refreshClaude() }
        if isEnabled(.antigravity) { rows[.antigravity] = await refreshAntigravity() }
        checkResets()
    }

    /// Celebrates resets that came due, then sets one timer for the next, so the show starts on the minute rather than at the next refresh.
    private func checkResets() {
        let usages = rows.values.flatMap { $0 }.filter { !hiddenAccountIDs.contains($0.id) }.compactMap(\.usage)
        let now = Date()
        let due = resets.due(in: usages, now: now)
        if !due.isEmpty { onReset?(due) }
        resetTimer?.invalidate()
        resetTimer = nil
        guard let next = resets.next(in: usages, now: now) else { return }
        let timer = Timer(fire: next.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkResets() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        resetTimer = timer
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

    /// Claude Code's access token lasts about 8 hours and only Claude Code itself renews it. When one has run out, Hey! asks the `claude`
    /// command to renew it (`claude auth status` for that login's config folder: about a second, no chat, no session files), then reads
    /// the Keychain again. Hey! never touches the renewal token itself. If that fails, it shows the last reading, marked as such; a login
    /// whose renewal token has also run out (it will never come back without signing in again) is left out.
    private func refreshClaude() async -> [AccountRow] {
        var logins = await Task.detached(operation: { Self.keychainLogins() }).value
        let now0 = Date()
        let toRenew = logins.filter { login in
            guard !login.removable, !hiddenAccountIDs.contains(login.id),
                  let expires = login.expiresAt, expires < now0.addingTimeInterval(60),
                  login.refreshExpiresAt.map({ $0 > now0 }) ?? true else { return false }
            return renewAttempts[login.id].map { now0.timeIntervalSince($0) > 600 } ?? true      // one try per login every 10 minutes
        }
        if !toRenew.isEmpty {
            for login in toRenew { renewAttempts[login.id] = now0 }
            let services = toRenew.map { String($0.id.dropFirst("keychain:".count)) }
            let renewed = await Task.detached(operation: { services.map(Self.renewClaude).contains(true) }).value
            if renewed { logins = await Task.detached(operation: { Self.keychainLogins() }).value }
        }
        for account in connected {
            if let token = Self.token(forConnected: account.id) {
                logins.append(Login(id: account.id, token: token, plan: nil, expiresAt: nil, refreshExpiresAt: nil, name: account.name, removable: true))
            }
        }
        var cache = loadClaudeCache()
        let now = Date()
        var result: [AccountRow] = []
        var seenEmails = Set<String>()
        for login in logins {
            guard !hiddenAccountIDs.contains(login.id) else { continue }
            if let dead = login.refreshExpiresAt, dead < now, login.expiresAt.map({ $0 < now }) ?? true { continue }
            var row = AccountRow(id: login.id, provider: .claude, name: login.name ?? labels[login.id] ?? tr("บัญชี Claude"),
                                 usage: nil, error: nil, removable: login.removable)
            if let email = labels[login.id] {
                if !login.removable, !seenEmails.insert(email).inserted { continue }          // the same account found twice
                if login.name == nil { row.name = email }
            }
            let expired = login.expiresAt.map { $0 < now } ?? false
            if !expired {
                if labels[login.id] == nil, let email = try? await Self.fetchEmail(token: login.token) {
                    labels[login.id] = email
                    UserDefaults.standard.set(labels, forKey: Self.claudeLabelsKey)
                    if login.name == nil { row.name = email }
                }
                do {
                    let usage = try await Self.fetchClaude(login: login, label: row.name)
                    row.usage = usage
                    cache[login.id] = usage
                    notify(usage)
                    result.append(row); continue
                } catch let error as UsageError where !error.expired {
                    row.error = error.message
                    result.append(row); continue
                } catch {}
            }
            // expired (by date or by the server): the last reading, or a quiet note when there is none yet
            if let last = cache[login.id] {
                row.usage = last; row.stale = true
            } else {
                row.error = login.removable ? tr("โทเคนใช้ไม่ได้ (หมดอายุ หรือไม่มีสิทธิ์อ่านโควตา)")
                                            : tr("รอต่ออายุ — จะอัปเดตเองเมื่อใช้คำสั่ง claude ด้วยบัญชีนี้ครั้งถัดไป")
            }
            result.append(row)
        }
        saveClaudeCache(cache)
        return result
    }

    private func loadClaudeCache() -> [String: ProviderUsage] {
        guard let data = UserDefaults.standard.data(forKey: Self.claudeCacheKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ProviderUsage].self, from: data)) ?? [:]
    }

    private func saveClaudeCache(_ cache: [String: ProviderUsage]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(cache), forKey: Self.claudeCacheKey)
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
            _ = try await Self.fetchClaude(login: Login(id: account.id, token: cleaned, plan: nil, expiresAt: nil, refreshExpiresAt: nil, name: account.name, removable: true), label: account.name)
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

    struct UsageError: Error {
        let message: String
        var expired = false
    }

    struct Login: Sendable {
        let id: String
        let token: String
        let plan: String?
        let expiresAt: Date?
        var refreshExpiresAt: Date? = nil
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
            let renewal = (oauth["refreshTokenExpiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
            logins.append(Login(id: "keychain:\(service)", token: token, plan: oauth["subscriptionType"] as? String,
                                expiresAt: expires, refreshExpiresAt: renewal, name: nil, removable: false))
        }
        return logins
    }

    /// Asks Claude Code to renew the login kept under this Keychain service. `Claude Code-credentials` is the default config folder
    /// (~/.claude); `Claude Code-credentials-<hash>` belongs to the folder whose path hashes (SHA-256, first 8 hex digits) to that suffix.
    nonisolated private static func renewClaude(service: String) -> Bool {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        guard let binary = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            .first(where: fm.isExecutableFile(atPath:)) else { return false }
        // A clean environment, so an inherited token or config variable can't make `claude` skip the Keychain login.
        let inherited = ProcessInfo.processInfo.environment
        var env = ["HOME": home, "USER": inherited["USER"] ?? NSUserName(), "TERM": "xterm-256color",
                   "LANG": inherited["LANG"] ?? "en_US.UTF-8", "PATH": "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
        let prefix = "Claude Code-credentials-"
        if service.hasPrefix(prefix) {
            let suffix = String(service.dropFirst(prefix.count))
            var candidates = ((try? fm.contentsOfDirectory(atPath: home)) ?? []).filter { $0.hasPrefix(".claude") }.map { "\(home)/\($0)" }
            candidates.append("\(home)/.config/claude")
            guard let dir = candidates.first(where: { path in
                SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined().prefix(8) == suffix
            }) else { return false }
            env["CLAUDE_CONFIG_DIR"] = dir
        }
        // 1. The cheap way: `claude auth status` renews the token when it re-reads the profile (about a second).
        _ = run(binary, ["auth", "status", "--json"], environment: env, timeout: 20)
        if renewed(service) { return true }
        // 2. As CodexBar does: open `claude` in a pseudo-terminal (`script`), ask for `/status`, wait for the Keychain item to
        //    change, then close it. No tools, no prompt sent, so no chat or session file is made. About six seconds.
        let probe = URL(fileURLWithPath: home + "/Library/Application Support/Hey/ClaudeProbe")
        try? fm.createDirectory(at: probe, withIntermediateDirectories: true)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        task.arguments = ["-q", "/dev/null", binary, "--allowed-tools", ""]
        task.environment = env
        task.currentDirectoryURL = probe
        let input = Pipe()
        task.standardInput = input
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return false }
        defer {
            try? input.fileHandleForWriting.close()
            if task.isRunning { task.terminate() }
        }
        Thread.sleep(forTimeInterval: 5)
        input.fileHandleForWriting.write(Data("\r".utf8))                 // past a first-run "trust this folder" question
        Thread.sleep(forTimeInterval: 1)
        input.fileHandleForWriting.write(Data("/status\r".utf8))
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 1)
            if renewed(service) { return true }
        }
        return false
    }

    /// The Keychain item's access token is good for at least another minute.
    nonisolated private static func renewed(_ service: String) -> Bool {
        guard let json = run("/usr/bin/security", ["find-generic-password", "-s", service, "-w"]),
              let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let ms = (oauth["expiresAt"] as? NSNumber)?.doubleValue else { return false }
        return Date(timeIntervalSince1970: ms / 1000) > Date().addingTimeInterval(60)
    }

    nonisolated private static func run(_ path: String, _ args: [String], environment: [String: String]? = nil, timeout: TimeInterval = 30) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        if let environment { task.environment = environment }
        task.currentDirectoryURL = FileManager.default.temporaryDirectory
        let out = Pipe()
        task.standardOutput = out
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return nil }
        let stop = DispatchWorkItem { if task.isRunning { task.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: stop)
        let data = out.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        stop.cancel()
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
            throw UsageError(message: tr("โทเคนใช้ไม่ได้ (หมดอายุ หรือไม่มีสิทธิ์อ่านโควตา)"), expired: true)
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
