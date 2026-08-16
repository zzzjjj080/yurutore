import Foundation

/// 時刻を持たない「暦の上の1日」。
///
/// `Date` を使うと、タイムゾーンや夏時間で日付が前後する事故が起きる。
/// このアプリが扱うのは常に「何月何日」なので、最初から時刻を持たない型にしておく。
public struct YMD: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// "2026-08-14" 形式。CSVのキーにそのまま使う。
    public init?(_ text: String) {
        let parts = text.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        self.init(y, m, d)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (a: YMD, b: YMD) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    // MARK: - 暦の計算

    /// 夏時間の影響を受けないよう、UTC固定のグレゴリオ暦で計算する。
    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private var date: Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Self.calendar.date(from: c)!
    }

    public func adding(days: Int) -> YMD {
        let d = Self.calendar.date(byAdding: .day, value: days, to: date)!
        let c = Self.calendar.dateComponents([.year, .month, .day], from: d)
        return YMD(c.year!, c.month!, c.day!)
    }

    /// self が other の何日後か。過去なら負。
    public func days(since other: YMD) -> Int {
        Self.calendar.dateComponents([.day], from: other.date, to: date).day!
    }

    /// 0=日曜 … 6=土曜
    public var weekday: Int {
        Self.calendar.component(.weekday, from: date) - 1
    }

    /// その年月の日数（うるう年も正しく出る）
    public static func daysInMonth(year: Int, month: Int) -> Int {
        calendar.range(of: .day, in: .month, for: YMD(year, month, 1).date)!.count
    }

    public var isValid: Bool {
        day <= Self.daysInMonth(year: year, month: month)
    }
}
