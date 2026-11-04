import Testing
import Foundation
@testable import HeyDomain

private let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private func englishTable() throws -> [String: String] {
    let data = try Data(contentsOf: repo.appendingPathComponent("Resources/Localization/en.json"))
    return try JSONDecoder().decode([String: String].self, from: data)
}

/// Every key the code passes to `tr(...)`.
private func keysInSource() throws -> Set<String> {
    let re = try NSRegularExpression(pattern: #"\btr\("((?:[^"\\]|\\.)*)""#)
    var keys = Set<String>()
    let fm = FileManager.default
    for dir in ["Sources/Hey", "Sources/HeyDomain"] {
        for file in try fm.contentsOfDirectory(atPath: repo.appendingPathComponent(dir).path) where file.hasSuffix(".swift") {
            let text = try String(contentsOf: repo.appendingPathComponent("\(dir)/\(file)"), encoding: .utf8)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let r = Range(m.range(at: 1), in: text) else { continue }
                var key = String(text[r])
                key = key.replacingOccurrences(of: #"\n"#, with: "\n")
                key = key.replacingOccurrences(of: #"\""#, with: "\"")
                key = key.replacingOccurrences(of: #"\\"#, with: #"\"#)
                keys.insert(key)
            }
        }
    }
    return keys
}

private func placeholders(_ s: String) -> [String] {
    let re = try! NSRegularExpression(pattern: #"\{\d+\}|%[\d.]*[a-z@]"#)
    return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s).map { String(s[$0]) } }.sorted()
}

@Suite struct LocalizationTests {
    @Test func everyKeyInTheCodeHasAnEnglishTranslation() throws {
        let table = try englishTable()
        let missing = try keysInSource().filter { table[$0] == nil }.sorted()
        #expect(missing.isEmpty, "missing English for: \(missing.prefix(5))")
    }

    @Test func translationsKeepTheirPlaceholders() throws {
        for (thai, english) in try englishTable() {
            #expect(!english.isEmpty, "empty translation for \(thai)")
            #expect(placeholders(thai) == placeholders(english), "placeholders differ: \(thai) / \(english)")
        }
    }

    @Test func englishModeTranslatesAndThaiModeKeepsTheKey() {
        Localization.configure(english: true, table: ["สวัสดี {0}": "Hello {0}"])
        #expect(tr("สวัสดี {0}", "Sam") == "Hello Sam")
        #expect(tr("ไม่มีในตาราง") == "ไม่มีในตาราง")                  // a missing entry falls back to the Thai text
        Localization.configure(english: false, table: [:])
        #expect(tr("สวัสดี {0}", "Sam") == "สวัสดี Sam")
    }

    @Test func theSystemChoiceFollowsTheMacsLanguage() {
        #expect(!LanguageChoice.system.isEnglish(systemLanguages: ["th-TH", "en-US"]))
        #expect(LanguageChoice.system.isEnglish(systemLanguages: ["en-US", "th-TH"]))
        #expect(LanguageChoice.system.isEnglish(systemLanguages: []))
        #expect(LanguageChoice.english.isEnglish(systemLanguages: ["th-TH"]))
        #expect(!LanguageChoice.thai.isEnglish(systemLanguages: ["en-US"]))
    }
}
