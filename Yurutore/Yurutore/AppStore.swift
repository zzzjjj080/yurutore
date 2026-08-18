import SwiftUI
import Observation
import YurutoreCore

enum ViewMode { case month, year }
enum ThemeChoice: String, CaseIterable, Codable { case light, dark, system }
enum AppLanguage: String, CaseIterable, Codable { case ja, en }

/// アプリの状態はここ1つ。Viewはこれを見るだけにする。
@Observable
final class AppStore {

    // MARK: - 記録
    var journal = Journal()

    // MARK: - 設定
    var settings = ScoringSettings.default
    var activities = Activity.defaults
    var weekStart: CalendarLayout.WeekStart = .monday
    var theme: ThemeChoice = .light
    var language: AppLanguage = .ja
    var failColor: PaletteKind = .yellow
    var passColor: PaletteKind = .blue
    var reminderOn = false
    var reminderHour = 21

    // MARK: - 画面の状態
    var today: YMD
    var viewYear: Int
    var viewMonth: Int
    var viewMode: ViewMode = .month
    var editingDate: YMD?
    var showDetail = false
    var showSettings = false
    var showOnboarding = false
    var healthAuthorized = false

    init(today: YMD = AppStore.currentDate()) {
        self.today = today
        self.viewYear = today.year
        self.viewMonth = today.month
        load()
        #if DEBUG
        DemoData.fill(self)
        if DemoData.isEnabled { showOnboarding = false }
        #endif
        journal.settleAll(today: today, activities: activities, settings: settings)
    }

    static func currentDate() -> YMD {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return YMD(c.year!, c.month!, c.day!)
    }

    // MARK: - 派生値

    func log(_ date: YMD) -> DayLog { journal[date] ?? DayLog() }

    func score(_ date: YMD) -> Int? {
        guard !isBeforeStart(date), let l = journal[date] else { return nil }
        return Scorer.score(l, activities: activities, settings: settings)
    }

    func isPass(_ date: YMD) -> Bool {
        guard !isBeforeStart(date), let l = journal[date] else { return false }
        return Scorer.isPass(l, activities: activities, settings: settings)
    }

    func state(_ date: YMD) -> DayState {
        if isBeforeStart(date) { return .unlogged }
        return journal[date]?.state(activities: activities) ?? .unlogged
    }

    func isFuture(_ date: YMD) -> Bool { date > today }
    var isViewingToday: Bool {
        viewMode == .year ? viewYear == today.year
                          : (viewYear == today.year && viewMonth == today.month)
    }

    var monthSummary: MonthSummary {
        journal.monthSummary(year: viewYear, month: viewMonth, today: today,
                             activities: activities, settings: settings)
    }
    var yearSummary: YearSummary {
        journal.yearSummary(year: viewYear, today: today,
                            activities: activities, settings: settings)
    }
    var startDate: YMD? {
        journal.startDate(activities: activities, override: settings.startOverride)
    }

    /// 記録を始める前の日。点数を出さず、カレンダーでは濃いグレーにする。
    func isBeforeStart(_ date: YMD) -> Bool {
        guard let s = startDate else { return false }
        return date < s
    }

    // MARK: - 編集

    private func mutate(_ date: YMD, _ body: (inout DayLog) -> Void) {
        var l = journal[date] ?? DayLog()
        body(&l)
        journal[date] = l
        journal.touch(date, activities: activities, settings: settings)
        save()
    }

    /// 押すたびに なし→×1→×2→×3→なし
    func cyclePart(_ date: YMD, _ part: BodyPart) {
        let before = isPass(date)
        mutate(date) { $0.setPart(part, to: Volume.cycled(from: $0.parts[part])) }
        feedback(crossed: before != isPass(date))
    }

    func cycleActivity(_ date: YMD, _ id: String) {
        let before = isPass(date)
        mutate(date) { $0.setActivity(id, to: Volume.cycled(from: $0.activities[id])) }
        feedback(crossed: before != isPass(date))
    }

    func toggleRest(_ date: YMD) {
        mutate(date) { $0.setRest(!$0.isRest) }
        Haptics.medium()
    }

    func setManualScore(_ date: YMD, _ value: Int?) {
        let before = isPass(date)
        mutate(date) { $0.manualScore = value }
        feedback(crossed: before != isPass(date))
    }

    func setSteps(_ date: YMD, _ steps: Int) {
        mutate(date) { $0.steps = max(0, steps) }
    }

    /// 合格ラインを跨いだ瞬間だけ強く返す
    private func feedback(crossed: Bool) {
        crossed ? Haptics.success() : Haptics.light()
    }

    // MARK: - 画面移動

    func moveMonth(_ delta: Int) {
        if viewMode == .year { viewYear += delta; return }
        var m = viewMonth + delta, y = viewYear
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        viewMonth = m; viewYear = y
    }

    func goToday() {
        viewYear = today.year
        viewMonth = today.month
        Haptics.medium()
    }

    /// シートを開いたまま前後の日へ。未来へは進めない。
    func stepEditingDay(_ delta: Int) {
        guard let cur = editingDate else { return }
        let next = cur.adding(days: delta)
        guard !isFuture(next) else { return }
        editingDate = next
        viewYear = next.year
        viewMonth = next.month
        Haptics.light()
    }

    // MARK: - 設定の変更

    func deleteActivity(id: String) {
        activities.removeAll { $0.id == id }
        save()
    }

    /// その運動が何日ぶん記録されているか。消す前に見せる。
    func usageCount(activityID: String) -> Int {
        journal.days.values.filter { ($0.activities[activityID]?.rawValue ?? 0) > 0 }.count
    }

    func moveActivity(from index: Int, by delta: Int) {
        let to = index + delta
        guard activities.indices.contains(index), activities.indices.contains(to) else { return }
        activities.swapAt(index, to)
        save()
    }

    func addActivity() {
        activities.append(.init(id: "c-\(UUID().uuidString.prefix(8))",
                                name: "", quantity: 5, unit: .minute))
        save()
    }

    func resetDisplaySettings() {
        theme = .light; language = .ja; weekStart = .monday
        failColor = .yellow; passColor = .blue
        reminderOn = false; reminderHour = 21
        save()
    }

    func resetScoringSettings() {
        settings = .default   // startOverride も nil に戻る
        activities = Activity.defaults
        save()
    }

    // MARK: - 保存

    private struct Persisted: Codable {
        var journal: Journal
        var settings: ScoringSettings
        var activities: [Activity]
        var weekStart: Int
        var theme: String
        var language: String
        var failColor: String
        var passColor: String
        var reminderOn: Bool
        var reminderHour: Int
        var didOnboard: Bool
    }

    private static let storeKey = "yurutore.state.v1"

    func save() {
        let p = Persisted(journal: journal, settings: settings, activities: activities,
                          weekStart: weekStart.rawValue, theme: theme.rawValue,
                          language: language.rawValue, failColor: failColor.rawValue,
                          passColor: passColor.rawValue, reminderOn: reminderOn,
                          reminderHour: reminderHour, didOnboard: didOnboard)
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }

    private(set) var didOnboard = false

    func finishOnboarding() {
        didOnboard = true
        showOnboarding = false
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storeKey),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else {
            showOnboarding = true   // 初回
            return
        }
        journal = p.journal
        settings = p.settings
        activities = p.activities
        weekStart = .init(rawValue: p.weekStart) ?? .monday
        theme = .init(rawValue: p.theme) ?? .light
        language = .init(rawValue: p.language) ?? .ja
        failColor = .init(rawValue: p.failColor) ?? .yellow
        passColor = .init(rawValue: p.passColor) ?? .blue
        reminderOn = p.reminderOn
        reminderHour = p.reminderHour
        didOnboard = p.didOnboard
        showOnboarding = !p.didOnboard
    }

    // MARK: - 配色

    func isDark(_ scheme: ColorScheme) -> Bool {
        switch theme {
        case .light: false
        case .dark: true
        case .system: scheme == .dark
        }
    }

    /// 合格ライン未満はうっすら、以上はしっかり。境目で濃さが飛ぶので一目で分かる。
    func cellColor(score: Int, dark: Bool) -> Color {
        if score >= Scorer.passLine {
            let r = passColor.ramp(dark: dark)
            let t = Double(score - Scorer.passLine) / Double(max(1, 100 - Scorer.passLine))
            return mix(r.lo, r.hi, 0.72 + 0.28 * t)
        }
        let r = failColor.ramp(dark: dark)
        let t = Double(score) / Double(Scorer.passLine)
        return mix(r.lo, r.hi, 0.06 + 0.44 * t)
    }

    func accent(dark: Bool) -> Color { passColor.ramp(dark: dark).ink }
    func onAccent(dark: Bool) -> Color { passColor.ramp(dark: dark).onInk }
}


extension YMD {
    /// DatePicker とやり取りするための変換。表示だけに使う。
    var asDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
    init(from date: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        self.init(c.year!, c.month!, c.day!)
    }
}
