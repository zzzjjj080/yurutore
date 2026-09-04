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
    /// カレンダーの配色パターン。1.1までは「80点未満の色」と「80点以上の色」を
    /// 別々に選ばせていたが、4段階になったのでパターンから選ぶ形にした。
    var paletteID: String = Palettes.defaultID
    /// 「自分で選ぶ」で決めた4色。プリセットに戻しても消さないので、行き来しても失われない。
    var customColors: [UInt32] = Palettes.named(Palettes.defaultID).colors(dark: false).tiers

    var palette: CalendarPalette {
        paletteID == Palettes.customID
            ? Palettes.custom(customColors,
                              ja: L.customPalette(.ja), en: L.customPalette(.en))
            : Palettes.named(paletteID)
    }
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

    /// 日付が変わったら「今日」を進める。
    /// 起動時に一度決めるだけだと、開きっぱなしで日をまたいだとき昨日のまま止まる。
    @discardableResult
    func refreshToday() -> Bool {
        let now = Self.currentDate()
        guard now != today else { return false }
        // 今日の月を見ていたなら一緒に送る。別の月を見ているなら邪魔しない。
        let follow = isViewingToday
        today = now
        if follow {
            viewYear = now.year
            if viewMode == .month { viewMonth = now.month }
        }
        journal.settleAll(today: now, activities: activities, settings: settings)
        save()
        return true
    }

    // MARK: - 派生値

    func log(_ date: YMD) -> DayLog { journal[date] ?? DayLog() }

    func score(_ date: YMD) -> Int? {
        guard !isBeforeStart(date), let l = journal[date] else { return nil }
        return Scorer.score(l, activities: activities, settings: settings)
    }

    /// その日の色の段階。点数から決まるので、記録が無い日・起点より前の日は nil。
    func tier(_ date: YMD) -> DayTier? {
        guard let s = score(date) else { return nil }
        return Scorer.tier(s)
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
        paletteID = Palettes.defaultID
        customColors = Palettes.named(Palettes.defaultID).colors(dark: false).tiers
        reminderOn = false; reminderHour = 21
        save()
    }

    func resetScoringSettings() {
        settings = .default   // startOverride も nil に戻る
        activities = Activity.defaults
        save()
    }

    // MARK: - 過去の点数の付け直し

    /// 設定を変えても確定済みの日は動かない。それが既定の動きなので、
    /// 過去も新しい設定で揃えたいときだけ、ここから明示的にやる。
    func recomputeAllScores() {
        for date in journal.days.keys {
            journal.days[date]?.lockedScore = nil
        }
        journal.settleAll(today: today, activities: activities, settings: settings)
        save()
    }

    /// 付け直すと点数が変わる日の数。実行前に見せる。
    var recomputeAffectedDays: Int {
        journal.days.values.reduce(into: 0) { n, log in
            guard let locked = log.lockedScore else { return }
            if Scorer.liveScore(log, activities: activities, settings: settings) != locked { n += 1 }
        }
    }

    // MARK: - 保存

    private struct Persisted: Codable {
        var journal: Journal
        var settings: ScoringSettings
        var activities: [Activity]
        var weekStart: Int
        var theme: String
        var language: String
        /// 1.1まではこの2つで色を決めていた。**消すと旧版の記録が読めなくなる**ので、
        /// 引き継ぎのために Optional で残してある。
        var failColor: String?
        var passColor: String?
        var paletteID: String?
        var customColors: [UInt32]?
        var reminderOn: Bool
        var reminderHour: Int
        var didOnboard: Bool
    }

    private static let storeKey = "yurutore.state.v1"

    func save() {
        let p = Persisted(journal: journal, settings: settings, activities: activities,
                          weekStart: weekStart.rawValue, theme: theme.rawValue,
                          language: language.rawValue, failColor: nil,
                          passColor: nil, paletteID: paletteID,
                          customColors: customColors, reminderOn: reminderOn,
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
        // 1.2より前の記録には paletteID が無い。2色の設定から一番近いものへ移す
        paletteID = p.paletteID ?? Palettes.migrating(fail: p.failColor, pass: p.passColor)
        customColors = Palettes.normalizedCustom(p.customColors ?? [])
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

    /// マスの色。**濃淡は付けない。4色だけ。**
    /// 点数そのものではなく「どちらの合格ラインを越えたか」で決まる。
    func cellColor(_ tier: DayTier, dark: Bool) -> Color { palette.color(tier, dark: dark) }

    /// その日のマスの色
    func cellColor(_ log: DayLog, dark: Bool) -> Color {
        cellColor(Scorer.tier(log, activities: activities, settings: settings), dark: dark)
    }

    func accent(dark: Bool) -> Color { palette.ink(dark: dark) }
    func onAccent(dark: Bool) -> Color { palette.onInk(dark: dark) }
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
