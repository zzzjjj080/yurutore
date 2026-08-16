import Foundation

/// 記録の書き出し・読み込み。
///
/// 表計算ソフトでそのまま開けて、人が見て分かる形にしてある。
/// 部位と運動は「名前x回数」を空白で並べた1列にまとめる。
public enum CSVFormat {

    public enum Language: Sendable { case japanese, english }

    public struct ImportResult: Equatable, Sendable {
        public var journal: Journal
        /// いまの設定に無くて読み込めなかった運動の名前
        public var droppedNames: [String]
    }

    public enum ImportError: Error, Equatable {
        case empty
        case badFormat(line: Int)
    }

    private static let headerJA = ["日付", "歩数", "部位", "その他の運動", "休養日", "点数", "点数の出どころ"]
    private static let headerEN = ["date", "steps", "body parts", "other exercise", "rest day", "score", "score source"]

    // 出どころは日英どちらの語でも読めるようにする
    private static let manualWords = ["手入力", "manual"]
    private static let lockedWords = ["確定", "locked"]
    private static let yesWords    = ["はい", "yes"]

    // MARK: - 書き出し

    public static func export(_ journal: Journal,
                              activities: [Activity],
                              settings: ScoringSettings,
                              language: Language = .japanese) -> String {
        var rows: [[String]] = [language == .english ? headerEN : headerJA]

        for date in journal.days.keys.sorted() {
            guard let log = journal.days[date] else { continue }
            let partText = BodyPart.allCases.compactMap { p -> String? in
                guard let v = log.parts[p] else { return nil }
                return "\(language == .english ? p.english : p.japanese)x\(v.rawValue)"
            }.joined(separator: " ")

            let actText = activities.compactMap { a -> String? in
                guard let v = log.activities[a.id] else { return nil }
                return "\(a.name)x\(v.rawValue)"
            }.joined(separator: " ")

            let source: String
            if log.manualScore != nil {
                source = manualWords[language == .english ? 1 : 0]
            } else if log.lockedScore != nil {
                source = lockedWords[language == .english ? 1 : 0]
            } else {
                source = language == .english ? "auto" : "自動"
            }

            rows.append([
                date.description,
                String(log.steps),
                partText,
                actText,
                log.isRest ? yesWords[language == .english ? 1 : 0] : "",
                String(Scorer.score(log, activities: activities, settings: settings)),
                source
            ])
        }

        return rows.map { row in
            row.map(escape).joined(separator: ",")
        }.joined(separator: "\n")
    }

    /// Excelで文字化けしないようBOMを付けたもの
    public static func exportWithBOM(_ journal: Journal,
                                     activities: [Activity],
                                     settings: ScoringSettings,
                                     language: Language = .japanese) -> Data {
        let bom = Data([0xEF, 0xBB, 0xBF])
        return bom + Data(export(journal, activities: activities,
                                 settings: settings, language: language).utf8)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - 読み込み

    public static func `import`(_ text: String, activities: [Activity]) throws -> ImportResult {
        let cleaned = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let lines = cleaned.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { throw ImportError.empty }

        let head = lines[0].lowercased()
        let start = (head.hasPrefix("日付") || head.hasPrefix("date")) ? 1 : 0
        guard lines.count > start else { throw ImportError.empty }

        var journal = Journal()
        var dropped: [String] = []

        for i in start..<lines.count {
            let cols = splitLine(lines[i])
            guard let date = YMD(cols.value(0).trimmingCharacters(in: .whitespaces)), date.isValid
            else { throw ImportError.badFormat(line: i + 1) }

            let score = min(100, max(0, Int(cols.value(5)) ?? 0))
            let source = cols.value(6).trimmingCharacters(in: .whitespaces)

            var log = DayLog()
            log.steps = max(0, Int(cols.value(1)) ?? 0)
            log.parts = parseParts(cols.value(2))
            let (acts, missed) = parseActivities(cols.value(3), activities: activities)
            log.activities = acts
            dropped.append(contentsOf: missed)
            log.isRest = !cols.value(4).trimmingCharacters(in: .whitespaces).isEmpty
            log.manualScore = matches(source, manualWords) ? score : nil
            // 確定済みの日はその点数をそのまま戻す。
            // 計算し直すと、いまの設定で過去が書き換わってしまう。
            log.lockedScore = matches(source, lockedWords) ? score : nil

            journal.days[date] = log
        }

        guard !journal.days.isEmpty else { throw ImportError.empty }
        return ImportResult(journal: journal, droppedNames: dropped)
    }

    private static func matches(_ value: String, _ words: [String]) -> Bool {
        words.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    private static func parseParts(_ text: String) -> [BodyPart: Volume] {
        var out: [BodyPart: Volume] = [:]
        for (label, n) in tokens(text) {
            if let p = BodyPart.from(label: label), let v = Volume(rawValue: n) {
                out[p] = v
            }
        }
        return out
    }

    private static func parseActivities(_ text: String,
                                        activities: [Activity]) -> ([String: Volume], [String]) {
        var out: [String: Volume] = [:]
        var missed: [String] = []
        for (label, n) in tokens(text) {
            guard let v = Volume(rawValue: n) else { continue }
            if let a = activities.first(where: { $0.name == label }) {
                out[a.id] = v
            } else {
                missed.append(label)
            }
        }
        return (out, missed)
    }

    /// "胸x2 背x1" → [("胸",2), ("背",1)]
    private static func tokens(_ text: String) -> [(String, Int)] {
        text.split(whereSeparator: { $0 == " " || $0 == "\u{3000}" }).compactMap { token in
            guard let sep = token.lastIndex(of: "x"),
                  let n = Int(token[token.index(after: sep)...]),
                  sep != token.startIndex
            else { return nil }
            return (String(token[token.startIndex..<sep]), n)
        }
    }

    /// 引用符つきのセルに対応した1行の分解
    private static func splitLine(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\""); i = next
                    } else {
                        inQuotes = false
                    }
                } else { current.append(c) }
            } else {
                if c == "\"" { inQuotes = true }
                else if c == "," { out.append(current); current = "" }
                else { current.append(c) }
            }
            i = line.index(after: i)
        }
        out.append(current)
        return out
    }
}

private extension Array where Element == String {
    /// 列が足りないCSVでも落ちないように
    func value(_ index: Int) -> String { indices.contains(index) ? self[index] : "" }
}
