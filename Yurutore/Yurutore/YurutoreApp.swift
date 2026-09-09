import SwiftUI
import YurutoreCore

@main
struct YurutoreApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // ウィジェットの見た目を確かめるための入口。
            // 拡張は単体で撮れないので、同じ View をアプリ側でも組み立てる。
            // 配布版には入らない（strings で確かめること・引き継ぎ書 4-7）
            if ProcessInfo.processInfo.environment["YURUTORE_WIDGET_PREVIEW"] == "1" {
                WidgetPreviewScreen()
            } else {
                ContentView(store: store)
            }
            #else
            ContentView(store: store)
            #endif
        }
    }
}

#if DEBUG
/// 2×2のウィジェットを、実寸に近い枠で並べて見る。
struct WidgetPreviewScreen: View {
    /// 見え方を確かめたい組み合わせ。「あと少し」「合格」「満点」「何もしていない」
    private var samples: [(String, WidgetSnapshot)] {
        let p = Palettes.named(nil)
        func make(_ steps: Int, _ ex: Int, rest: Bool = false) -> WidgetSnapshot {
            var log = DayLog(steps: steps)
            var left = ex
            for part in BodyPart.allCases where left > 0 {
                let v = min(3, left); log.parts[part] = Volume(rawValue: v)!; left -= v
            }
            if rest { log.setRest(true) }
            return WidgetSnapshot(date: YMD(2026, 9, 9), log: log,
                                  activities: Activity.defaults,
                                  settings: .default, palette: p)
        }
        return [("あと少し", make(8240, 1)),
                ("合格", make(11200, 2)),
                ("満点", make(17000, 3)),
                ("これから", make(1200, 0))]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 6) {
                        TodayWidgetView(snapshot: item.1)
                            .frame(width: 158, height: 158)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: .rect(cornerRadius: 22))
                        Text(item.0).font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("widgetPreview")
    }
}
#endif
