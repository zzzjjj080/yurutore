import SwiftUI
import YurutoreCore

struct ContentView: View {
    @Bindable var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var health = HealthStore()

    private var dark: Bool { store.isDark(scheme) }
    private var lang: AppLanguage { store.language }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 10) {
                header
                if !store.healthAuthorized { healthBanner }

                Group {
                    if store.viewMode == .month {
                        MonthGrid(store: store)
                    } else {
                        YearGrid(store: store)
                    }
                }
                .contentShape(.rect)
                .gesture(
                    // 縦スクロールと誤認しないよう、横に振れたときだけ月を送る
                    DragGesture(minimumDistance: 24)
                        .onEnded { v in
                            guard abs(v.translation.width) > abs(v.translation.height) else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.moveMonth(v.translation.width < 0 ? 1 : -1)
                            }
                            Haptics.light()
                        }
                )

                stats
                Button(L.detailBtn(lang)) { Haptics.light(); store.showDetail = true }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .preferredColorScheme(store.theme == .system ? nil : (store.theme == .dark ? .dark : .light))
        .sheet(item: $store.editingDate) { date in
            DayEditor(store: store, date: date)
        }
        .sheet(isPresented: $store.showDetail) { DetailSheet(store: store) }
        .sheet(isPresented: $store.showSettings) { SettingsSheet(store: store) }
        .fullScreenCover(isPresented: $store.showOnboarding) { OnboardingView(store: store) }
        .task { await syncHealth() }
    }

    // MARK: - 上部

    private var header: some View {
        HStack {
            Button {
                Haptics.medium()
                withAnimation(.easeOut(duration: 0.2)) {
                    store.viewMode = store.viewMode == .month ? .year : .month
                }
            } label: {
                HStack(spacing: 5) {
                    Text(store.viewMode == .month
                         ? L.monthTitle(store.viewYear, store.viewMonth, lang)
                         : L.yearTitle(store.viewYear, lang))
                        .font(.system(size: 26, weight: .heavy))
                    Image(systemName: store.viewMode == .month ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 8) {
                if !store.isViewingToday {
                    Button(L.today(lang)) {
                        withAnimation(.easeOut(duration: 0.2)) { store.goToday() }
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(store.accent(dark: dark))
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Color(.secondarySystemGroupedBackground), in: .capsule)
                }
                circleButton("questionmark") { Haptics.light(); store.showOnboarding = true }
                circleButton("gearshape.fill") { Haptics.light(); store.showSettings = true }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemGroupedBackground), in: .circle)
        }
        .buttonStyle(.plain)
    }

    private var healthBanner: some View {
        Button {
            Task {
                _ = await health.requestAuthorization()
                await syncHealth()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.hkBanner(lang)).font(.system(size: 12, weight: .heavy))
                    Text(L.hkBannerSub(lang)).font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(L.hkAllow(lang)).font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.orange)
            }
            .padding(11)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange, lineWidth: 1.5))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 指標

    @ViewBuilder
    private var stats: some View {
        // 年表示のときは年の集計に切り替える。月の数字のままだと、
        // 何を見ている数字なのか分からなくなる。
        if store.viewMode == .year {
            let y = store.yearSummary
            return HStack(spacing: 7) {
                statTile(L.ySumPass(lang), value: "\(y.passedDays)",
                         unit: L.t("日", "d", lang), sub: "", tint: store.accent(dark: dark))
                statTile(L.ySumLogged(lang), value: "\(y.loggedDays)",
                         unit: L.t("日", "d", lang), sub: "", tint: .primary)
                statTile(L.statScore(lang), value: y.averageScore.map { "\($0)" } ?? "—",
                         unit: y.averageScore != nil ? L.pts(lang) : nil, sub: "", tint: .primary)
            }
        }
        let s = store.monthSummary
        return HStack(spacing: 7) {
            statTile(L.statPass(lang),
                     value: s.passRate.map { "\($0)" } ?? "—",
                     unit: s.passRate != nil ? "%" : nil,
                     sub: s.countedDays > 0 ? "\(s.passedDays)/\(s.countedDays)" : "",
                     tint: store.accent(dark: dark))
            statTile(L.statSteps(lang),
                     value: s.averageSteps.map { $0.formatted() } ?? "—",
                     unit: nil, sub: "", tint: .primary)
            statTile(L.statScore(lang),
                     value: s.averageScore.map { "\($0)" } ?? "—",
                     unit: s.averageScore != nil ? L.pts(lang) : nil,
                     sub: "", tint: .primary)
        }
    }

    private func statTile(_ key: String, value: String, unit: String?,
                          sub: String, tint: Color) -> some View {
        Button { Haptics.light(); store.showDetail = true } label: {
            VStack(spacing: 3) {
                Text(key).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value).font(.system(size: 19, weight: .heavy)).foregroundStyle(tint)
                    if let unit {
                        Text(unit).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    }
                }
                Text(sub).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(key) \(value)\(unit ?? "") \(sub)")
    }

    // MARK: - ヘルスケア

    private func syncHealth() async {
        guard health.isAvailable else { return }
        // 起点より前は読んでも使わないので、直近1年ぶんだけ取る
        let from = store.today.adding(days: -400)
        let steps = await health.dailySteps(from: from, to: store.today)
        guard !steps.isEmpty else { return }
        store.healthAuthorized = true
        for (date, count) in steps {
            // 確定済みの日は歩数を上書きしない。過去の点数が動くため。
            if store.journal[date]?.lockedScore != nil { continue }
            var log = store.journal[date] ?? DayLog()
            log.steps = count
            store.journal[date] = log
        }
        store.journal.settleAll(today: store.today,
                                activities: store.activities, settings: store.settings)
        store.save()
    }
}

extension YMD: @retroactive Identifiable {
    public var id: String { description }
}
