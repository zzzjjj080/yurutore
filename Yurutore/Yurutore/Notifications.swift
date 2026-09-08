import Foundation
import UserNotifications
import YurutoreCore

/// 知らせるのは2つだけ。
///
/// - **夜**：その日まだ記録していないとき（従来から）
/// - **朝**：前の日の運動が入っていないとき／歩数が届いていないとき
///
/// 毎日せかされるのは「ゆる」ではないので、どちらも既定はオフ。
enum Notifications {
    private static let eveningID = "yurutore.reminder"
    private static let morningPrefix = "yurutore.morning."
    /// 朝の通知を何日ぶん先まで置くか。
    /// アプリを開かない日は必ず未入力なので、先に置いておいてよい。
    /// 開いた時点で作り直すので、入力した日のぶんは消える。
    private static let morningDays = 3

    static func request() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 予約をすべて作り直す。**起動時と、設定や記録が変わったときに呼ぶ。**
    @MainActor
    static func reschedule(_ store: AppStore) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: [eveningID] + (0..<morningDays).map { "\(morningPrefix)\($0)" })
        scheduleEvening(store, center: center)
        scheduleMornings(store, center: center)
    }

    // MARK: - 夜：その日まだ記録していない

    @MainActor
    private static func scheduleEvening(_ store: AppStore, center: UNUserNotificationCenter) {
        guard store.reminderOn else { return }
        let ja = store.language == .ja
        let content = base(ja: ja)
        content.body = ja ? "今日はまだ記録がありません。歩数は入っています。"
                          : "Nothing logged today yet. Your steps are in."

        var when = DateComponents()
        when.hour = store.reminderHour
        when.minute = 0
        center.add(UNNotificationRequest(
            identifier: eveningID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }

    /// 記録した日はその日ぶんを鳴らさない。
    /// 繰り返し通知は個別に止められないので、記録が入った時点で当日ぶんを取り消す。
    @MainActor
    static func cancelToday(_ store: AppStore) {
        guard store.state(store.today) != .unlogged else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [eveningID])
    }

    // MARK: - 朝：前の日の入れ忘れと、歩数が届いていないこと

    @MainActor
    private static func scheduleMornings(_ store: AppStore, center: UNUserNotificationCenter) {
        guard store.morningOn else { return }
        let ja = store.language == .ja
        // 歩数が届いていないかは、いま分かっていることで決める。
        // 先の日ぶんも同じ判断で置く（開いた時点で作り直される）
        let stepsMissing = store.stepsLookMissing

        for offset in 0..<morningDays {
            // offset 日先の朝に、その前の日のことを知らせる
            let morning = store.today.adding(days: offset + 1)
            let subject = store.today.adding(days: offset)
            guard let body = morningBody(store, about: subject,
                                         stepsMissing: stepsMissing, ja: ja) else { continue }
            let content = base(ja: ja)
            content.body = body

            var when = DateComponents()
            when.year = morning.year; when.month = morning.month; when.day = morning.day
            when.hour = store.morningHour
            when.minute = 0
            center.add(UNNotificationRequest(
                identifier: "\(morningPrefix)\(offset)", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        }
    }

    /// 知らせることが無ければ nil。**用が無いのに鳴らさない。**
    @MainActor
    private static func morningBody(_ store: AppStore, about date: YMD,
                                    stepsMissing: Bool, ja: Bool) -> String? {
        // 歩数が届いていないほうが重い。点数が毎日20点に張り付く原因になる
        if stepsMissing {
            return ja ? "歩数が読み取れていません。ヘルスケアの許可を確かめてください。"
                      : "Step counts are not coming in. Please check Health access."
        }
        // 未来の日は、まだ開いていないので必ず未入力
        let unlogged = date > store.today || store.state(date) == .unlogged
        guard unlogged else { return nil }
        return ja ? "昨日の運動がまだ入っていません。いまからでも入れられます。"
                  : "Yesterday's exercise is still empty. You can add it now."
    }

    private static func base(ja: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = ja ? "ゆるトレ日記" : "Yuru Training Diary"
        content.sound = .default
        return content
    }
}
