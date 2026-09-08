import SwiftUI
import WidgetKit
import YurutoreCore

/// ホーム画面に出す、今日ぶんの2×2。
///
/// **ウィジェット自身は何も計算しない。** アプリが保存のたびに共有領域へ
/// 置いた結果を読むだけ。こうしないと、カレンダーと数字が食い違う。
@main
struct YurutoreWidgetBundle: WidgetBundle {
    var body: some Widget { TodayWidget() }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YurutoreTodayWidget", provider: Provider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("今日の点数")
        .description("歩数と種目数が、合格ラインまであとどれくらいかを出します。")
        .supportedFamilies([.systemSmall])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: WidgetStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // 中身が変わるのはアプリが保存したときだけ。そのとき押し込まれるので、
        // ここでは日付が変わるまで持たせておけばよい。
        let entry = Entry(date: Date(), snapshot: WidgetStore.load())
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

/// 共有領域から読むだけの入れ物。アプリ側と同じキーを使う。
enum WidgetStore {
    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup),
              let data = defaults.data(forKey: WidgetSnapshot.storageKey)
        else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
