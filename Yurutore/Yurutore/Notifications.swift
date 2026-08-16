import Foundation
import UserNotifications
import YurutoreCore

/// その日まだ運動を記録していないときだけ知らせる。
/// 毎日せかされるのは「ゆる」ではないので、既定はオフ。
enum Notifications {
    private static let id = "yurutore.reminder"

    static func request() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @MainActor
    static func reschedule(_ store: AppStore) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard store.reminderOn else { return }

        let content = UNMutableNotificationContent()
        let ja = store.language == .ja
        content.title = ja ? "ゆるトレ日記" : "Yuru Training Diary"
        content.body = ja ? "今日はまだ記録がありません。歩数は入っています。"
                          : "Nothing logged today yet. Your steps are in."
        content.sound = .default

        var when = DateComponents()
        when.hour = store.reminderHour
        when.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// 記録した日はその日ぶんを鳴らさない。
    /// 繰り返し通知は個別に止められないので、記録が入った時点で当日ぶんを取り消す。
    @MainActor
    static func cancelToday(_ store: AppStore) {
        guard store.state(store.today) != .unlogged else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}
