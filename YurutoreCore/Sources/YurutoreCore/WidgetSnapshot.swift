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
    /// 文字やリングに使う色
    public let inkLight: UInt32
    public let inkDark: UInt32

    public init(date: YMD, steps: Int, passSteps: Int, stepScore: Int,
                exercises: Int, passExercises: Int, exerciseScore: Int,
                total: Int, isRest: Bool,
                fillLight: UInt32, fillDark: UInt32,
                inkLight: UInt32, inkDark: UInt32) {
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
                  inkDark: palette.colors(dark: true).ink)
    }

    public var tier: DayTier { Scorer.tier(total) }
    public var isPass: Bool { total >= Scorer.passLine }

    /// 合格ラインまであと何歩か。届いていれば0。
    public var stepsLeft: Int { max(0, passSteps - steps) }
    /// 合格ラインまであと何種目か。届いていれば0。
    public var exercisesLeft: Int { max(0, passExercises - exercises) }

    /// 合格ラインに対する進み具合（0...1）。**超えても1で止める。**
    /// 輪が一周を超えて回ると、達成したことがかえって分かりにくい。
    public var stepProgress: Double { ratio(steps, passSteps) }
    public var exerciseProgress: Double { ratio(exercises, passExercises) }

    private func ratio(_ value: Int, _ line: Int) -> Double {
        guard line > 0 else { return value > 0 ? 1 : 0 }
        return min(1, max(0, Double(value) / Double(line)))
    }

    public func fill(dark: Bool) -> UInt32 { dark ? fillDark : fillLight }
    public func ink(dark: Bool) -> UInt32 { dark ? inkDark : inkLight }

    /// まだ何も入っていない日の見本。ウィジェットの下書き表示に使う。
    public static let placeholder = WidgetSnapshot(
        date: YMD(2026, 9, 9), steps: 8240, passSteps: 10000, stepScore: 33,
        exercises: 1, passExercises: 2, exerciseScore: 20,
        total: 53, isRest: false,
        fillLight: Palettes.named(nil).fill(.mid, dark: false),
        fillDark: Palettes.named(nil).fill(.mid, dark: true),
        inkLight: Palettes.named(nil).colors(dark: false).ink,
        inkDark: Palettes.named(nil).colors(dark: true).ink)
}
