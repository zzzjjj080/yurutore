import SwiftUI
import Charts
import YurutoreCore

/// 1年を一望する。「続いている感」を出すのがこの画面の役目。
struct YearGrid: View {
    @Bindable var store: AppStore
    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { store.isDark(scheme) }
    private var lang: AppLanguage { store.language }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                          spacing: 9) {
                    ForEach(1...12, id: \.self) { m in
                        Button {
                            Haptics.light()
                            store.viewMonth = m
                            withAnimation(.easeOut(duration: 0.2)) { store.viewMode = .month }
                        } label: {
                            miniMonth(m)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                chart
                Divider()
                summary
            }
            .padding(10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func miniMonth(_ m: Int) -> some View {
        let isCurrent = store.viewYear == store.today.year && m == store.today.month
        return VStack(alignment: .leading, spacing: 4) {
            Text(L.monthShort(m, lang))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(isCurrent ? store.accent(dark: dark) : .secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 7),
                      spacing: 1.5) {
                ForEach(Array(CalendarLayout.cells(year: store.viewYear, month: m,
                                                   weekStart: store.weekStart).enumerated()),
                        id: \.offset) { _, date in
                    if let date {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(fill(date))
                            .aspectRatio(1, contentMode: .fit)
                            .opacity(store.isFuture(date) ? 0.3 : 1)
                            .overlay {
                                if date == store.today {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .strokeBorder(.primary, lineWidth: 1.5)
                                }
                            }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.monthShort(m, lang))
    }

    private func fill(_ date: YMD) -> Color {
        guard !store.isFuture(date), let s = store.score(date) else {
            return Color(.tertiarySystemGroupedBackground)
        }
        return store.cellColor(score: s, dark: dark)
    }

    /// 月ごとの達成率。Swift Charts で描く。
    private var chart: some View {
        let rates = store.yearSummary.monthlyPassRate
        return VStack(alignment: .leading, spacing: 8) {
            Text(L.chartTitle(lang)).font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.secondary)
            Chart {
                ForEach(1...12, id: \.self) { m in
                    if let v = rates[m - 1] {
                        BarMark(x: .value("month", m), y: .value("rate", v))
                            .foregroundStyle(store.accent(dark: dark)
                                .opacity(0.35 + 0.65 * min(1, Double(v) / 100)))
                            .cornerRadius(3)
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXScale(domain: 0.5...12.5)
            .chartXAxis {
                AxisMarks(values: Array(1...12)) { v in
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)").font(.system(size: 8)) }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { v in
                    AxisGridLine()
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)").font(.system(size: 8)) }
                }
            }
            .frame(height: 90)
        }
    }

    private var summary: some View {
        let y = store.yearSummary
        return HStack {
            item(L.ySumPass(lang), "\(y.passedDays)", tint: store.accent(dark: dark))
            item(L.statScore(lang), y.averageScore.map { "\($0)" } ?? "—", tint: .primary)
            item(L.ySumLogged(lang), "\(y.loggedDays)", tint: .primary)
        }
    }

    private func item(_ key: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(key).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .heavy)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }
}
