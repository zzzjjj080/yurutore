import Foundation
import YurutoreCore

/// 端末の暦での「今日」。
///
/// **アプリとウィジェットの両方が要る。** ウィジェットは別プロセスなので、
/// アプリが持っている「今日」を読めない。同じ出し方をここに1つ置く。
///
/// `YMD` は UTC 固定で計算するが、「今日が何日か」は端末の暦で決める。
/// ここを UTC にすると、日本では朝9時まで前の日のままになる。
public enum LocalDay {
    public static func today(_ now: Date = Date()) -> YMD {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        return YMD(c.year!, c.month!, c.day!)
    }

    /// 次に日付が変わる瞬間。ウィジェットの作り直しを予約するのに使う。
    public static func nextMidnight(_ now: Date = Date()) -> Date {
        let cal = Calendar.current
        return cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                            matchingPolicy: .nextTime)
            ?? cal.startOfDay(for: now.addingTimeInterval(86400))
    }
}
