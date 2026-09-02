import Foundation

/// 記録全体。日付をキーに持つだけの入れ物だが、
/// 「確定」と「集計の起点」の規則をここに集約している。
public struct Journal: Codable, Equatable, Sendable {
    public var days: [YMD: DayLog]

    public init(days: [YMD: DayLog] = [:]) { self.days = days }

    public subscript(date: YMD) -> DayLog? {
        get { days[date] }
        set { days[date] = newValue }
    }

    // MARK: - 確定

    /// 当日を含めてこの日数は未確定。歩数がまだ増えるため。
    public static let graceDays = 3

    /// その日が確定すべきか
    public static func shouldSettle(_ date: YMD, today: YMD) -> Bool {
        today.days(since: date) >= graceDays
    }

    /// 期限を過ぎた未確定の日を焼き付ける。実機では起動時に一度呼ぶ。
    ///
    /// これをやらないと、採点モードや運動の一覧を変えたときに
    /// 過去のカレンダーと達成率が丸ごと書き換わってしまう。
    public mutating func settleAll(today: YMD,
                                   activities: [Activity],
                                   settings: ScoringSettings) {
        for (date, log) in days where log.lockedScore == nil && Self.shouldSettle(date, today: today) {
            days[date]?.lockedScore = Scorer.liveScore(log, activities: activities, settings: settings)
            days[date]?.lockedTier = Scorer.liveTier(log, activities: activities, settings: settings)
        }
    }

    /// 確定済みの日を編集したら、その日だけ計算し直して確定し直す。
    /// これが無いと「忘れてた運動を足したのに点が変わらない」ことになる。
    public mutating func touch(_ date: YMD,
                               activities: [Activity],
                               settings: ScoringSettings) {
        guard let log = days[date], log.lockedScore != nil else { return }
        days[date]?.lockedScore = Scorer.liveScore(log, activities: activities, settings: settings)
        days[date]?.lockedTier = Scorer.liveTier(log, activities: activities, settings: settings)
    }

    // MARK: - 集計の起点

    /// 集計の起点。
    ///
    /// override が指定されていればそれを使う。無ければ、本人が最初に入力した日
    /// （運動を記録した日、または休養日にした日）。
    /// 歩数はヘルスケアから何年ぶんでも入りうるので、
    /// これを起点にしないと過去が全部0%になる。
    public func startDate(activities: [Activity], override: YMD? = nil) -> YMD? {
        if let override { return override }
        return days.filter { $0.value.state(activities: activities) != .unlogged }
            .keys.min()
    }

    /// その月で集計する日の範囲。対象外なら nil。
    ///
    /// 今日は含めない。まだ歩き終わっていない日を混ぜると平均が下がるため。
    public func countedRange(year: Int, month: Int,
                             today: YMD,
                             activities: [Activity],
                             override: YMD? = nil) -> ClosedRange<Int>? {
        // 未来の月
        if (year, month) > (today.year, today.month) { return nil }
        let daysInMonth = YMD.daysInMonth(year: year, month: month)
        let last = (year == today.year && month == today.month)
            ? today.day - 1
            : daysInMonth
        guard last >= 1 else { return nil }

        guard let start = startDate(activities: activities, override: override) else { return nil }
        if (year, month) < (start.year, start.month) { return nil }
        let first = (year == start.year && month == start.month) ? start.day : 1
        guard first <= last else { return nil }
        return first...last
    }
}

// MARK: - 集計結果

public struct MonthSummary: Equatable, Sendable {
    /// 分母（集計対象の日数）
    public var countedDays: Int
    /// 80点以上だった日数
    public var passedDays: Int
    public var totalSteps: Int
    public var averageScore: Int?
    public var partCounts: [BodyPart: Int]
    public var activityCounts: [String: Int]

    public var passRate: Int? {
        countedDays > 0 ? Int((Double(passedDays) / Double(countedDays) * 100).rounded()) : nil
    }
    public var averageSteps: Int? {
        countedDays > 0 ? Int((Double(totalSteps) / Double(countedDays)).rounded()) : nil
    }
}

public struct YearSummary: Equatable, Sendable {
    public var passedDays: Int
    public var loggedDays: Int
    public var averageScore: Int?
    /// 1月〜12月の達成率（対象外の月は nil）
    public var monthlyPassRate: [Int?]
}

extension Journal {
    public func monthSummary(year: Int, month: Int,
                             today: YMD,
                             activities: [Activity],
                             settings: ScoringSettings) -> MonthSummary {
        var parts: [BodyPart: Int] = [:]
        var acts: [String: Int] = [:]
        BodyPart.allCases.forEach { parts[$0] = 0 }
        activities.forEach { acts[$0.id] = 0 }

        guard let range = countedRange(year: year, month: month, today: today,
                                       activities: activities,
                                       override: settings.startOverride) else {
            return MonthSummary(countedDays: 0, passedDays: 0, totalSteps: 0,
                                averageScore: nil, partCounts: parts, activityCounts: acts)
        }

        var passed = 0, steps = 0, sum = 0, n = 0
        for d in range {
            guard let log = days[YMD(year, month, d)] else { continue }
            steps += log.steps
            sum += Scorer.score(log, activities: activities, settings: settings)
            n += 1
            if Scorer.isPass(log, activities: activities, settings: settings) { passed += 1 }
            for (p, v) in log.parts { parts[p, default: 0] += v.rawValue }
            for (id, v) in log.activities where acts[id] != nil { acts[id]! += v.rawValue }
        }

        return MonthSummary(
            countedDays: range.count,
            passedDays: passed,
            totalSteps: steps,
            averageScore: n > 0 ? Int((Double(sum) / Double(n)).rounded()) : nil,
            partCounts: parts,
            activityCounts: acts)
    }

    public func yearSummary(year: Int,
                            today: YMD,
                            activities: [Activity],
                            settings: ScoringSettings) -> YearSummary {
        var passed = 0, logged = 0, sum = 0, n = 0
        var rates: [Int?] = []
        for m in 1...12 {
            let s = monthSummary(year: year, month: m, today: today,
                                 activities: activities, settings: settings)
            rates.append(s.passRate)
            passed += s.passedDays
            if let range = countedRange(year: year, month: m, today: today,
                                        activities: activities,
                                        override: settings.startOverride) {
                for d in range {
                    guard let log = days[YMD(year, m, d)] else { continue }
                    sum += Scorer.score(log, activities: activities, settings: settings)
                    n += 1
                    if log.state(activities: activities) != .unlogged { logged += 1 }
                }
            }
        }
        return YearSummary(passedDays: passed, loggedDays: logged,
                           averageScore: n > 0 ? Int((Double(sum) / Double(n)).rounded()) : nil,
                           monthlyPassRate: rates)
    }
}

// MARK: - 辞書のキーに YMD を使うための対応

extension YMD: CodingKeyRepresentable {
    public var codingKey: any CodingKey { RawKey(stringValue: description) }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(codingKey.stringValue)
    }

    private struct RawKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
