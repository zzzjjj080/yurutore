import Foundation

/// 採点モード。20点の下駄・合格80点・満点100点は共通で、
/// 歩数と運動の「伸びしろ」の配分だけを変える。
public enum ScoringMode: String, CaseIterable, Codable, Sendable {
    case balanced      // 歩数60 / 運動60
    case stepsFirst    // 歩数75 / 運動45
    case exerciseFirst // 歩数45 / 運動75

    /// 歩数スコアの伸びしろ
    public var stepSpan: Int {
        switch self { case .balanced: 60; case .stepsFirst: 75; case .exerciseFirst: 45 }
    }
    /// 運動スコアの伸びしろ
    public var exerciseSpan: Int {
        switch self { case .balanced: 60; case .stepsFirst: 45; case .exerciseFirst: 75 }
    }
}

public struct ScoringSettings: Codable, Equatable, Sendable {
    /// 最低これだけは毎日歩きたい、という線。ここが20点になる。
    public var lowerSteps: Int
    /// 調子がよければこれくらい、という線。ここで打ち止め。
    public var upperSteps: Int
    public var mode: ScoringMode
    /// 「この日から記録を始めた」と本人が決めた日。
    /// nil なら、最初に運動を記録した日から自動で数える。
    public var startOverride: YMD?

    public init(lowerSteps: Int = 8000, upperSteps: Int = 16000,
                mode: ScoringMode = .balanced, startOverride: YMD? = nil) {
        self.lowerSteps = lowerSteps
        self.upperSteps = upperSteps
        self.mode = mode
        self.startOverride = startOverride
    }

    public static let `default` = ScoringSettings()

    /// 選べる歩数（3000〜30000の1000刻み）
    public static let stepChoices: [Int] = stride(from: 3000, through: 30000, by: 1000).map { $0 }

    /// 上限が下限を下回る組み合わせは選択肢に出さないので通常起きないが、
    /// 万一そうなっても計算が壊れないようにしておく。
    public var safeUpperSteps: Int { max(lowerSteps + 500, upperSteps) }
}

public enum Scorer {
    /// 合格ライン。ここが人によって違うと「80点が合格」という
    /// アプリの説明そのものが成り立たなくなるので定数にする。
    public static let passLine = 20 + 60   // 80

    /// 下限歩数のときの点
    public static let baseScore = 20

    /// 採点上、運動はここで頭打ち
    public static let exerciseCap = 3

    /// バランス時の運動スコア。伸びは +25 / +20 / +15 と逓減する。
    private static let baseExerciseTable = [0, 25, 45, 60]

    /// いまのモードでの運動スコア表
    public static func exerciseTable(mode: ScoringMode) -> [Int] {
        baseExerciseTable.map { Int((Double($0) * Double(mode.exerciseSpan) / 60.0).rounded()) }
    }

    /// 歩数スコア。下限〜上限を直線で結び、外側は打ち止め。
    public static func stepScore(steps: Int, settings: ScoringSettings) -> Int {
        let lo = settings.lowerSteps
        let hi = settings.safeUpperSteps
        let top = baseScore + settings.mode.stepSpan
        let t = min(1, max(0, Double(steps - lo) / Double(hi - lo)))
        return Int((Double(baseScore) + Double(top - baseScore) * t).rounded())
    }

    /// 歩数スコアの上限（＝上限歩数に達したときの点）
    public static func maxStepScore(settings: ScoringSettings) -> Int {
        baseScore + settings.mode.stepSpan
    }

    public static func exerciseScore(count: Int, mode: ScoringMode) -> Int {
        let table = exerciseTable(mode: mode)
        return table[min(count, table.count - 1)]
    }

    /// 記録から計算した点。手入力があってもこちらは常に計算できる。
    public static func autoScore(_ log: DayLog,
                                 activities: [Activity],
                                 settings: ScoringSettings) -> Int {
        let s = stepScore(steps: log.steps, settings: settings)
        let e = exerciseScore(count: log.exerciseCount(activities: activities), mode: settings.mode)
        return min(100, s + e)
    }

    /// 確定前の点。手入力があればそれを使う。
    public static func liveScore(_ log: DayLog,
                                 activities: [Activity],
                                 settings: ScoringSettings) -> Int {
        if let m = log.manualScore { return min(100, max(0, m)) }
        return autoScore(log, activities: activities, settings: settings)
    }

    /// 実際に表示する点。確定済みならその値を動かさない。
    public static func score(_ log: DayLog,
                             activities: [Activity],
                             settings: ScoringSettings) -> Int {
        log.lockedScore ?? liveScore(log, activities: activities, settings: settings)
    }

    public static func isPass(_ log: DayLog,
                              activities: [Activity],
                              settings: ScoringSettings) -> Bool {
        score(log, activities: activities, settings: settings) >= passLine
    }

    /// 手入力で選べる点数（20〜100の10刻み）
    public static let manualChoices: [Int] = stride(from: 20, through: 100, by: 10).map { $0 }
}
