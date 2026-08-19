import Foundation

/// 採点の決まり
///
/// 本人が決めるのは4つだけ。歩数と運動それぞれの「合格ライン」と「目標ライン」。
/// 合格ライン＝40点、目標ライン＝60点。この対応は動かさない。
///
/// つまり、歩数も運動も合格ラインに届いた日が 40+40＝80点。
/// 「まず80点の線を決める」という作業が、そのまま設定になる。
public struct ScoringSettings: Codable, Equatable, Sendable {
    /// 毎日これだけは歩きたい、という線。40点。
    public var passSteps: Int
    /// 調子がよければこれくらい、という線。60点。
    public var goalSteps: Int
    /// 毎日これだけはやりたい運動の数。40点。
    public var passExercises: Int
    /// 調子がよければこれくらい、という運動の数。60点。
    public var goalExercises: Int
    /// 「この日から記録を始めた」と本人が決めた日。
    /// nil なら、最初に運動を記録した日から自動で数える。
    public var startOverride: YMD?

    public init(passSteps: Int = 10000, goalSteps: Int = 16000,
                passExercises: Int = 2, goalExercises: Int = 3,
                startOverride: YMD? = nil) {
        self.passSteps = passSteps
        self.goalSteps = goalSteps
        self.passExercises = passExercises
        self.goalExercises = goalExercises
        self.startOverride = startOverride
    }

    public static let `default` = ScoringSettings()

    /// 選べる歩数（3000〜30000の1000刻み）
    public static let stepChoices: [Int] = stride(from: 3000, through: 30000, by: 1000).map { $0 }
    /// 選べる運動の数
    public static let exerciseChoices: [Int] = Array(1...6)

    /// 目標が合格を下回る組み合わせは選択肢に出さないので通常起きないが、
    /// 万一そうなっても計算が壊れないようにしておく。
    public var safeGoalSteps: Int { max(passSteps + 1000, goalSteps) }
    public var safeGoalExercises: Int { max(passExercises + 1, goalExercises) }

    /// 合格ラインだけを動かすときは、目標ラインも押し出す。
    ///
    /// 設定画面は「目標より下」しか選ばせないので問題にならないが、
    /// 初回設定では合格ラインだけを聞く。そこで目標を追い越せてしまうと、
    /// 本人の知らないところで目標ラインが無効になる。
    public mutating func setPassSteps(_ v: Int) {
        let gap = max(1000, goalSteps - passSteps)
        passSteps = v
        if goalSteps <= v { goalSteps = min(Self.stepChoices.last ?? v + gap, v + gap) }
    }

    public mutating func setPassExercises(_ v: Int) {
        let gap = max(1, goalExercises - passExercises)
        passExercises = v
        if goalExercises <= v { goalExercises = min(Self.exerciseChoices.last ?? v + gap, v + gap) }
    }

    // MARK: - 保存データの読み込み

    private enum CodingKeys: String, CodingKey {
        case passSteps, goalSteps, passExercises, goalExercises, startOverride
    }

    /// 旧版は lowerSteps / upperSteps / mode を保存していた。
    /// ここで例外を投げると保存データ全体の復元が失敗し、**記録が丸ごと消える**。
    /// 見つからない項目は既定値で埋めて、必ず読めるようにする。
    ///
    /// 採点式そのものが変わったので、旧版の歩数設定は引き継がない。
    /// 引き継いでも意味が変わってしまい、かえって分かりにくい。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.default
        self.init(
            passSteps: try c.decodeIfPresent(Int.self, forKey: .passSteps) ?? d.passSteps,
            goalSteps: try c.decodeIfPresent(Int.self, forKey: .goalSteps) ?? d.goalSteps,
            passExercises: try c.decodeIfPresent(Int.self, forKey: .passExercises) ?? d.passExercises,
            goalExercises: try c.decodeIfPresent(Int.self, forKey: .goalExercises) ?? d.goalExercises,
            startOverride: try c.decodeIfPresent(YMD.self, forKey: .startOverride))
    }
}

public enum Scorer {
    /// 合格ラインでもらえる点
    public static let passPoints = 40
    /// 目標ラインでもらえる点。ここで打ち止め。
    public static let goalPoints = 60

    /// 合格ライン。歩数40＋運動40。
    /// ここが人によって違うと「80点が合格」という説明そのものが成り立たなくなるので定数にする。
    public static let passLine = passPoints * 2   // 80

    /// 0 →(合格ライン)40点 →(目標ライン)60点 と折れ曲がる直線。目標より上は伸びない。
    ///
    /// 合格ラインの手前と後ろで傾きが変わるのは意図したもの。
    /// 「合格までは1歩の重みが大きく、その先は緩やかになる」ほうが、
    /// 毎日続けるという目的に合う。
    private static func points(_ value: Double, pass: Double, goal: Double) -> Int {
        let p = max(1, pass)
        let g = max(p + 1, goal)
        if value <= 0 { return 0 }
        if value >= g { return goalPoints }
        if value <= p {
            return Int((Double(passPoints) * value / p).rounded())
        }
        let t = (value - p) / (g - p)
        return Int((Double(passPoints) + Double(goalPoints - passPoints) * t).rounded())
    }

    public static func stepScore(steps: Int, settings: ScoringSettings) -> Int {
        points(Double(steps), pass: Double(settings.passSteps), goal: Double(settings.safeGoalSteps))
    }

    public static func exerciseScore(count: Int, settings: ScoringSettings) -> Int {
        points(Double(count), pass: Double(settings.passExercises), goal: Double(settings.safeGoalExercises))
    }

    /// 採点上、運動はここで頭打ち。表の列数もこれに合わせる。
    public static func exerciseCap(_ settings: ScoringSettings) -> Int {
        settings.safeGoalExercises
    }

    /// 記録から計算した点。手入力があってもこちらは常に計算できる。
    public static func autoScore(_ log: DayLog,
                                 activities: [Activity],
                                 settings: ScoringSettings) -> Int {
        let s = stepScore(steps: log.steps, settings: settings)
        let e = exerciseScore(count: log.exerciseCount(activities: activities), settings: settings)
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
