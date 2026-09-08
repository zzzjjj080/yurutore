import Foundation
import WidgetKit
import YurutoreCore

/// ウィジェットへ今日ぶんを渡す。
///
/// **ウィジェットは別プロセスなので、いつもの UserDefaults は読めない。**
/// App Group の領域に置いて初めて共有できる。
enum WidgetBridge {

    @MainActor
    static func publish(_ store: AppStore) {
        let snapshot = WidgetSnapshot(date: store.today,
                                      log: store.journal[store.today] ?? DayLog(),
                                      activities: store.activities,
                                      settings: store.settings,
                                      palette: store.palette)
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup),
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: WidgetSnapshot.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
