import Foundation

/// ホーム画面のウィジェットへ渡す、その日ぶんのまとめ。
///
/// **ウィジェットはアプリとは別のプロセスで、設定も記録も読めない。**
/// 共有領域にこれを1つ置いて、ウィジェットはそれを読むだけにする。
/// 配色も読めないので、**色まで含めてここに入れて渡す。**
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public static let appGroup = "group.com.zzzjjj080.Yurutore"
    public static let storageKey = "widgetSnapshot"

    public let date: YMD
    /// 歩数と、その合格ライン
    public let steps: Int
    public let passSteps: Int
    public let stepScore: Int
    /// 種目数と、その合格ライン
    public let exercises: Int
    public let passExercises: Int
    public let exerciseScore: Int
    public let total: Int
    /// 休養日はせかさない
    public let isRest: Bool
    /// 段階の塗り。明るいテーマ用と暗いテーマ用。
    public let fillLight: UInt32
    public let fillDark: UInt32
    /// 4段階ぶんの塗り。**日をまたいだときに、ウィジェット側で段階を作り直すために持つ。**
    /// 1.3 の保存には入っていないので Optional（無ければ上の1色で代用する）。
    public let tierFillsLight: [UInt32]?
    public let tierFillsDark: [UInt32]?
    /// 目標ライン。**ウィジェットが自分で歩数から点を出し直すのに要る。**
    /// 1.4 より前の保存には入っていないので Optional。
    public let goalSteps: Int?
    public let goalExercises: Int?
    /// 文字やリングに使う色
    public let inkLight: UInt32
    public let inkDark: UInt32

    public init(date: YMD, steps: Int, passSteps: Int, stepScore: Int,
                exercises: Int, passExercises: Int, exerciseScore: Int,
                total: Int, isRest: Bool,
                fillLight: UInt32, fillDark: UInt32,
                inkLight: UInt32, inkDark: UInt32,
                tierFillsLight: [UInt32]? = nil, tierFillsDark: [UInt32]? = nil,
                goalSteps: Int? = nil, goalExercises: Int? = nil) {
        self.date = date
        self.steps = steps
        self.passSteps = passSteps
        self.stepScore = stepScore
        self.exercises = exercises
        self.passExercises = passExercises
        self.exerciseScore = exerciseScore
        self.total = total
        self.isRest = isRest
        self.fillLight = fillLight
        self.fillDark = fillDark
        self.inkLight = inkLight
        self.inkDark = inkDark
        self.tierFillsLight = tierFillsLight
        self.tierFillsDark = tierFillsDark
        self.goalSteps = goalSteps
        self.goalExercises = goalExercises
    }

    /// 記録と設定と配色から作る。**画面側で組み立てない。**
    /// ウィジェットとカレンダーで数字が食い違うと、どちらが正しいのか分からなくなる。
    public init(date: YMD, log: DayLog, activities: [Activity],
                settings: ScoringSettings, palette: CalendarPalette) {
        let count = log.exerciseCount(activities: activities)
        let total = Scorer.liveScore(log, activities: activities, settings: settings)
        let tier = Scorer.tier(total)
        self.init(date: date,
                  steps: log.steps,
                  passSteps: settings.passSteps,
                  stepScore: Scorer.stepScore(steps: log.steps, settings: settings),
                  exercises: count,
                  passExercises: settings.passExercises,
                  exerciseScore: Scorer.exerciseScore(count: count, settings: settings),
                  total: total,
                  isRest: log.isRest,
                  fillLight: palette.fill(tier, dark: false),
                  fillDark: palette.fill(tier, dark: true),
                  inkLight: palette.colors(dark: false).ink,
                  inkDark: palette.colors(dark: true).ink,
                  tierFillsLight: palette.colors(dark: false).tiers,
                  tierFillsDark: palette.colors(dark: true).tiers,
                  goalSteps: settings.goalSteps,
                  goalExercises: settings.goalExercises)
    }

    /// 日付だけ進めて、記録を空に戻したもの。
    ///
    /// **アプリを開かないまま日をまたぐと、ウィジェットは前の日を出し続ける。**
    /// 中身を書き直せるのはアプリだけなので、ウィジェット側でこれを作って
    /// 「今日はまだ0」に切り替える。歩数はアプリが次に開かれたときに追いつく。
    public func carriedOver(to newDate: YMD) -> WidgetSnapshot {
        WidgetSnapshot(date: newDate,
                       steps: 0, passSteps: passSteps, stepScore: 0,
                       exercises: 0, passExercises: passExercises, exerciseScore: 0,
                       total: 0, isRest: false,
                       fillLight: fill(.low, dark: false),
                       fillDark: fill(.low, dark: true),
                       inkLight: inkLight, inkDark: inkDark,
                       tierFillsLight: tierFillsLight, tierFillsDark: tierFillsDark,
                       goalSteps: goalSteps, goalExercises: goalExercises)
    }

    /// 書かれたときの設定。目標ラインが入っていなければ既定で補う。
    public var settings: ScoringSettings {
        ScoringSettings(passSteps: passSteps,
                        goalSteps: goalSteps ?? ScoringSettings.default.goalSteps,
                        passExercises: passExercises,
                        goalExercises: goalExercises ?? ScoringSettings.default.goalExercises)
    }

    /// 歩数だけを今の値に差し替える。
    ///
    /// **アプリを開かない日でも、ウィジェットが自分で歩数を読めるようにするため。**
    /// 種目は本人が入れるものなので、アプリが書いた値をそのまま使う。
    /// 点数の出し方はカレンダーと同じ `Scorer` を通すので、数字が食い違わない。
    public func withLiveSteps(_ liveSteps: Int) -> WidgetSnapshot {
        guard liveSteps != steps else { return self }
        let s = settings
        let newStepScore = Scorer.stepScore(steps: liveSteps, settings: s)
        let newTotal = min(100, newStepScore + exerciseScore)
        let newTier = Scorer.tier(newTotal)
        return WidgetSnapshot(date: date,
                              steps: liveSteps, passSteps: passSteps, stepScore: newStepScore,
                              exercises: exercises, passExercises: passExercises,
                              exerciseScore: exerciseScore,
                              total: newTotal, isRest: isRest,
                              fillLight: fill(newTier, dark: false),
                              fillDark: fill(newTier, dark: true),
                              inkLight: inkLight, inkDark: inkDark,
                              tierFillsLight: tierFillsLight, tierFillsDark: tierFillsDark,
                              goalSteps: goalSteps, goalExercises: goalExercises)
    }

    public var tier: DayTier { Scorer.tier(total) }
    public var isPass: Bool { total >= Scorer.passLine }

    /// 合格ラインまであと何歩か。届いていれば0。
    public var stepsLeft: Int { max(0, passSteps - steps) }
    /// 合格ラインまであと何種目か。届いていれば0。
    public var exercisesLeft: Int { max(0, passExercises - exercises) }

    /// 輪の進み具合（0...1）。**40点＝合格ラインで一周。超えても1で止める。**
    ///
    /// 歩数も種目数も、同じ「40点」を一周とする。片方だけ基準が違うと、
    /// 2つの輪を見比べたときに、どちらが進んでいるのか分からない。
    ///
    /// **輪の下に出している点数から作る。** 歩数そのものから作ると、
    /// 点数は四捨五入されるぶん、輪と数字がわずかにずれる。
    public var stepGauge: Double { gauge(stepScore) }
    public var exerciseGauge: Double { gauge(exerciseScore) }

    private func gauge(_ score: Int) -> Double {
        min(1, max(0, Double(score) / Double(Scorer.passPoints)))
    }

    /// 輪1つぶんの達成ぐあい。**合計の段階とは別。**
    /// 歩数は届いたが種目は途中、のような日を、輪の濃さで見分けるために持つ。
    public enum GaugeState: Int, Codable, Sendable {
        /// まだ何もしていない
        case none
        /// 途中
        case partway
        /// その線には届いた（40点）
        case reached
    }

    public var stepState: GaugeState { state(stepScore) }
    public var exerciseState: GaugeState { state(exerciseScore) }

    private func state(_ score: Int) -> GaugeState {
        if score >= Scorer.passPoints { return .reached }
        return score > 0 ? .partway : .none
    }

    /// その段階の塗り。4段階ぶんを持っていればそこから引く。
    /// 1.3 で保存されたものは今の段階の色しか持っていないので、そのときはそれを返す。
    public func fill(_ tier: DayTier, dark: Bool) -> UInt32 {
        let all = dark ? tierFillsDark : tierFillsLight
        if let all, all.indices.contains(tier.rawValue - 1) { return all[tier.rawValue - 1] }
        return dark ? fillDark : fillLight
    }

    /// いまの段階の塗り
    public func fill(dark: Bool) -> UInt32 { dark ? fillDark : fillLight }
    public func ink(dark: Bool) -> UInt32 { dark ? inkDark : inkLight }

    /// まだ何も入っていない日の見本。ウィジェットの下書き表示に使う。
    public static let placeholder = WidgetSnapshot(
        date: YMD(2026, 9, 9), steps: 6600, passSteps: ScoringSettings.default.passSteps, stepScore: 33,
        exercises: 1, passExercises: 2, exerciseScore: 20,
        total: 53, isRest: false,
        fillLight: Palettes.named(nil).fill(.mid, dark: false),
        fillDark: Palettes.named(nil).fill(.mid, dark: true),
        inkLight: Palettes.named(nil).colors(dark: false).ink,
        inkDark: Palettes.named(nil).colors(dark: true).ink)
}
