import Foundation

/// 月カレンダーのマス配置。
///
/// 月によって5行・6行と変わると、カレンダーの高さが動いて
/// 下の表示までずれる。常に6行（42マス）で固定する。
public enum CalendarLayout {
    public static let cellCount = 42   // 7列 × 6行

    /// 週の始まり。0=日曜、1=月曜（既定）
    public enum WeekStart: Int, Codable, CaseIterable, Sendable {
        case sunday = 0, monday = 1
    }

    /// 曜日見出しの並び（0=日 … 6=土）
    public static func weekdayOrder(weekStart: WeekStart) -> [Int] {
        (0..<7).map { (weekStart.rawValue + $0) % 7 }
    }

    /// 月初までの空きマス数
    public static func leadingBlanks(year: Int, month: Int, weekStart: WeekStart) -> Int {
        (YMD(year, month, 1).weekday - weekStart.rawValue + 7) % 7
    }

    /// 42マスぶんの並び。日付が無いマスは nil。
    public static func cells(year: Int, month: Int, weekStart: WeekStart) -> [YMD?] {
        let lead = leadingBlanks(year: year, month: month, weekStart: weekStart)
        let count = YMD.daysInMonth(year: year, month: month)
        var out: [YMD?] = Array(repeating: nil, count: lead)
        out += (1...count).map { YMD(year, month, $0) }
        out += Array(repeating: nil, count: cellCount - out.count)
        return out
    }
}
