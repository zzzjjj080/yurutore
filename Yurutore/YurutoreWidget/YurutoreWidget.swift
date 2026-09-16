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
        completion(Entry(date: Date(), snapshot: WidgetStore.current() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let midnight = LocalDay.nextMidnight(now)

        var entries = [Entry(date: now, snapshot: WidgetStore.current(now))]
        // **日付が変わる瞬間のぶんも積んでおく。**
        // アプリを開かないまま日をまたぐと、ここが無いと前の日を出し続ける。
        if let carried = WidgetStore.current(now)?.carriedOver(to: LocalDay.today(midnight)) {
            entries.append(Entry(date: midnight, snapshot: carried))
        }
        // 積んだぶんを使い切ったら、そこでまた組み直してもらう
        completion(Timeline(entries: entries, policy: .atEnd))
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

    /// いま出すべき中身。**前の日のものなら、その場で今日ぶんに繰り越す。**
    /// 書き直せるのはアプリだけなので、開かれないまま日をまたいでも
    /// 前の日の点数が残らないようにする。
    static func current(_ now: Date = Date()) -> WidgetSnapshot? {
        guard let saved = load() else { return nil }
        let today = LocalDay.today(now)
        return saved.date == today ? saved : saved.carriedOver(to: today)
    }
}
