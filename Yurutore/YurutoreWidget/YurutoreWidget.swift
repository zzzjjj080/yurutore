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
                // その日の段階の色を地にする。カレンダーのマスと同じ意味で読める
                .containerBackground(for: .widget) {
                    if let s = entry.snapshot {
                        WidgetBackground(snapshot: s)
                    } else {
                        Color(.systemBackground)
                    }
                }
        }
        .configurationDisplayName("今日の点数")
        .description("歩数と種目数が、合格ラインまであとどれくらいかを出します。")
        .supportedFamilies([.systemSmall])
        // 既定の余白を切って、枠いっぱいまで使う。余白は View 側で決める
        .contentMarginsDisabled()
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

/// 地の色。`containerBackground` の中では環境が拾えないので、Viewに包んで渡す。
private struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme
    let snapshot: WidgetSnapshot
    var body: some View { snapshot.background(dark: scheme == .dark) }
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
