import Testing
@testable import YurutoreCore

/// 採点はこのアプリの芯なので、決めた条件をそのままテストにしておく。
/// ここが崩れたら、設定画面もカレンダーの色も全部意味が変わる。
struct ScoringTests {

    let acts = Activity.defaults
    let settings = ScoringSettings.default

    /// 部位だけで指定した数の運動を持つ1日を作る
    func day(steps: Int, exercises n: Int) -> DayLog {
        var log = DayLog(steps: steps)
        var remaining = n
        for part in BodyPart.allCases where remaining > 0 {
            let v = min(3, remaining)
            log.parts[part] = Volume(rawValue: v)!
            remaining -= v
        }
        return log
    }

    // MARK: - 決めた5点

    @Test("設計時に決めた5つの条件をすべて満たす")
    func anchors() {
        #expect(Scorer.autoScore(day(steps: 8000,  exercises: 0), activities: acts, settings: settings) == 20)
        #expect(Scorer.autoScore(day(steps: 10000, exercises: 2), activities: acts, settings: settings) == 80)
        #expect(Scorer.autoScore(day(steps: 16000, exercises: 0), activities: acts, settings: settings) == 80)
        #expect(Scorer.autoScore(day(steps: 8000,  exercises: 3), activities: acts, settings: settings) == 80)
        #expect(Scorer.autoScore(day(steps: 13000, exercises: 3), activities: acts, settings: settings) == 100)
    }

    @Test("合格ラインは80で固定")
    func passLineIsFixed() {
        #expect(Scorer.passLine == 80)
        #expect(Scorer.isPass(day(steps: 10000, exercises: 2), activities: acts, settings: settings))
        #expect(!Scorer.isPass(day(steps: 10000, exercises: 1), activities: acts, settings: settings))
    }

    // MARK: - 打ち止め

    @Test("歩数は上限を超えても伸びない")
    func stepsCap() {
        let at   = Scorer.stepScore(steps: 16000, settings: settings)
        let over = Scorer.stepScore(steps: 40000, settings: settings)
        #expect(at == 80)
        #expect(at == over)
    }

    @Test("歩数は下限を下回っても20点より下がらない")
    func stepsFloor() {
        #expect(Scorer.stepScore(steps: 8000, settings: settings) == 20)
        #expect(Scorer.stepScore(steps: 0,    settings: settings) == 20)
    }

    @Test("運動は3つで頭打ち", arguments: [3, 4, 8, 15])
    func exerciseCap(_ n: Int) {
        #expect(Scorer.autoScore(day(steps: 8000, exercises: n),
                                 activities: acts, settings: settings) == 80)
    }

    @Test("合計は100を超えない")
    func totalCap() {
        #expect(Scorer.autoScore(day(steps: 30000, exercises: 9),
                                 activities: acts, settings: settings) == 100)
    }

    // MARK: - モード

    @Test("モードは配分だけを変え、下駄と満点は共通")
    func modes() {
        for mode in ScoringMode.allCases {
            var s = settings; s.mode = mode
            #expect(Scorer.autoScore(day(steps: 8000, exercises: 0), activities: acts, settings: s) == 20,
                    "\(mode) の下駄が20でない")
            #expect(Scorer.stepScore(steps: 8000, settings: s) == 20)
            #expect(Scorer.maxStepScore(settings: s) == 20 + mode.stepSpan)
        }
    }

    @Test("歩数重視では歩かないと合格できない")
    func stepsFirstMode() {
        var s = settings; s.mode = .stepsFirst
        // 運動を上限までやっても、下限歩数のままでは届かない
        #expect(Scorer.autoScore(day(steps: 8000, exercises: 3), activities: acts, settings: s) < 80)
        #expect(Scorer.autoScore(day(steps: 16000, exercises: 0), activities: acts, settings: s) >= 80)
    }

    @Test("運動重視では歩くだけでは合格できない")
    func exerciseFirstMode() {
        var s = settings; s.mode = .exerciseFirst
        #expect(Scorer.autoScore(day(steps: 30000, exercises: 0), activities: acts, settings: s) < 80)
        #expect(Scorer.autoScore(day(steps: 8000, exercises: 3), activities: acts, settings: s) >= 80)
    }

    // MARK: - 部位とその他の運動の等価性

    @Test("その他の運動は部位と同じ重みで数える")
    func activitiesEqualParts() {
        let byParts = day(steps: 8000, exercises: 3)
        var byActs = DayLog(steps: 8000)
        byActs.activities = ["radio": .three]
        var mixed = DayLog(steps: 8000)
        mixed.parts = [.chest: .one]
        mixed.activities = ["swim": .two]

        let a = Scorer.autoScore(byParts, activities: acts, settings: settings)
        let b = Scorer.autoScore(byActs,  activities: acts, settings: settings)
        let c = Scorer.autoScore(mixed,   activities: acts, settings: settings)
        #expect(a == b)
        #expect(b == c)
    }

    @Test("設定から消された運動は数に入らない")
    func unknownActivityIgnored() {
        var log = DayLog(steps: 8000)
        log.activities = ["radio": .three, "deleted-one": .three]
        // radio しか設定に無いので3つぶんだけ数える
        #expect(log.exerciseCount(activities: acts) == 3)
        #expect(Scorer.autoScore(log, activities: acts, settings: settings) == 80)
    }

    // MARK: - 手入力

    @Test("手入力は自動計算より優先されるが、自動計算自体は汚さない")
    func manualScore() {
        var log = day(steps: 16000, exercises: 3)
        log.manualScore = 40
        #expect(Scorer.liveScore(log, activities: acts, settings: settings) == 40)
        #expect(Scorer.autoScore(log, activities: acts, settings: settings) == 100)
        log.manualScore = nil
        #expect(Scorer.liveScore(log, activities: acts, settings: settings) == 100)
    }

    @Test("手入力の選択肢は20〜100の10刻み")
    func manualChoices() {
        #expect(Scorer.manualChoices == [20, 30, 40, 50, 60, 70, 80, 90, 100])
    }

    // MARK: - 歩数の設定

    @Test("下限と上限を変えると、その両端がちょうど20点と上限点になる")
    func customStepRange() {
        var s = ScoringSettings(lowerSteps: 5000, upperSteps: 11000)
        #expect(Scorer.stepScore(steps: 5000,  settings: s) == 20)
        #expect(Scorer.stepScore(steps: 11000, settings: s) == 80)
        #expect(Scorer.stepScore(steps: 8000,  settings: s) == 50)  // ちょうど中間

        // 上限が下限を下回っても壊れない
        s = ScoringSettings(lowerSteps: 10000, upperSteps: 3000)
        #expect(Scorer.stepScore(steps: 9000, settings: s) == 20)
    }

    @Test("選べる歩数は3000〜30000の1000刻み")
    func stepChoices() {
        #expect(ScoringSettings.stepChoices.first == 3000)
        #expect(ScoringSettings.stepChoices.last == 30000)
        #expect(ScoringSettings.stepChoices.count == 28)
    }
}
