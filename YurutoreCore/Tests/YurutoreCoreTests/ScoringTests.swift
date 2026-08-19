import Foundation
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

    // MARK: - 合格ラインの決まり

    @Test("合格ライン同士を足すとちょうど80点になる")
    func passLineIsTheSumOfBothPassLines() {
        #expect(Scorer.passLine == 80)
        #expect(Scorer.stepScore(steps: settings.passSteps, settings: settings) == 40)
        #expect(Scorer.exerciseScore(count: settings.passExercises, settings: settings) == 40)
        #expect(Scorer.autoScore(day(steps: 10000, exercises: 2),
                                 activities: acts, settings: settings) == 80)
        #expect(Scorer.isPass(day(steps: 10000, exercises: 2), activities: acts, settings: settings))
    }

    @Test("目標ラインはどちらも60点")
    func goalLineIsSixty() {
        #expect(Scorer.stepScore(steps: settings.goalSteps, settings: settings) == 60)
        #expect(Scorer.exerciseScore(count: settings.goalExercises, settings: settings) == 60)
    }

    @Test("片方だけでは合格できない")
    func oneAxisAloneCannotPass() {
        // 歩数をいくら伸ばしても60点止まり
        #expect(Scorer.autoScore(day(steps: 40000, exercises: 0),
                                 activities: acts, settings: settings) == 60)
        // 運動だけでも同じ
        #expect(Scorer.autoScore(day(steps: 0, exercises: 6),
                                 activities: acts, settings: settings) == 60)
    }

    @Test("既定の設定での代表的な組み合わせ")
    func defaultTable() {
        #expect(Scorer.autoScore(day(steps: 0,     exercises: 0), activities: acts, settings: settings) == 0)
        #expect(Scorer.autoScore(day(steps: 5000,  exercises: 0), activities: acts, settings: settings) == 20)
        #expect(Scorer.autoScore(day(steps: 10000, exercises: 1), activities: acts, settings: settings) == 60)
        #expect(Scorer.autoScore(day(steps: 8000,  exercises: 3), activities: acts, settings: settings) == 92)
        #expect(Scorer.autoScore(day(steps: 13000, exercises: 3), activities: acts, settings: settings) == 100)
    }

    // MARK: - 打ち止め

    @Test("歩数は目標ラインを超えても伸びない")
    func stepsCap() {
        let at   = Scorer.stepScore(steps: 16000, settings: settings)
        let over = Scorer.stepScore(steps: 40000, settings: settings)
        #expect(at == 60)
        #expect(at == over)
    }

    @Test("歩数0は0点")
    func stepsFloor() {
        #expect(Scorer.stepScore(steps: 0, settings: settings) == 0)
    }

    @Test("運動は目標ラインで頭打ち", arguments: [3, 4, 8, 15])
    func exerciseCap(_ n: Int) {
        #expect(Scorer.exerciseScore(count: n, settings: settings) == 60)
        #expect(Scorer.exerciseCap(settings) == 3)
    }

    @Test("合計は100を超えない")
    func totalCap() {
        #expect(Scorer.autoScore(day(steps: 30000, exercises: 9),
                                 activities: acts, settings: settings) == 100)
    }

    // MARK: - 設定を変えたとき

    @Test("歩数のラインを変えると、その2点がちょうど40点と60点になる")
    func customStepLines() {
        var s = ScoringSettings(passSteps: 6000, goalSteps: 12000)
        #expect(Scorer.stepScore(steps: 6000,  settings: s) == 40)
        #expect(Scorer.stepScore(steps: 12000, settings: s) == 60)
        #expect(Scorer.stepScore(steps: 3000,  settings: s) == 20)  // 合格ラインの半分
        #expect(Scorer.stepScore(steps: 9000,  settings: s) == 50)  // 合格と目標の中間

        // 目標が合格を下回っても壊れない
        s = ScoringSettings(passSteps: 10000, goalSteps: 3000)
        #expect(Scorer.stepScore(steps: 10000, settings: s) == 40)
        #expect(Scorer.stepScore(steps: 99999, settings: s) == 60)
    }

    @Test("運動のラインを変えると、1種目あたりの点が変わる")
    func customExerciseLines() {
        // 合格1種目・目標2種目にすると、1種目で40点
        let easy = ScoringSettings(passExercises: 1, goalExercises: 2)
        #expect(Scorer.exerciseScore(count: 1, settings: easy) == 40)
        #expect(Scorer.exerciseScore(count: 2, settings: easy) == 60)
        #expect(Scorer.exerciseScore(count: 3, settings: easy) == 60)

        // 合格4種目・目標6種目にすると、1種目は10点
        let hard = ScoringSettings(passExercises: 4, goalExercises: 6)
        #expect(Scorer.exerciseScore(count: 1, settings: hard) == 10)
        #expect(Scorer.exerciseScore(count: 4, settings: hard) == 40)
        #expect(Scorer.exerciseScore(count: 6, settings: hard) == 60)
    }

    @Test("合格ラインを両方満たせば、設定をどう変えても80点")
    func passLineHoldsForAnySettings() {
        let cases = [
            ScoringSettings(passSteps: 4000,  goalSteps: 9000,  passExercises: 1, goalExercises: 2),
            ScoringSettings(passSteps: 12000, goalSteps: 20000, passExercises: 3, goalExercises: 5),
            ScoringSettings(passSteps: 7000,  goalSteps: 8000,  passExercises: 5, goalExercises: 6),
        ]
        for s in cases {
            let log = day(steps: s.passSteps, exercises: s.passExercises)
            #expect(Scorer.autoScore(log, activities: acts, settings: s) == 80,
                    "\(s.passSteps)歩 + \(s.passExercises)種目 が80点にならない")
            #expect(Scorer.isPass(log, activities: acts, settings: s))
        }
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
        var log = DayLog(steps: 10000)
        log.activities = ["radio": .two, "deleted-one": .three]
        // radio しか設定に無いので2つぶんだけ数える
        #expect(log.exerciseCount(activities: acts) == 2)
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

    // MARK: - 選択肢

    @Test("選べる歩数は3000〜30000の1000刻み")
    func stepChoices() {
        #expect(ScoringSettings.stepChoices.first == 3000)
        #expect(ScoringSettings.stepChoices.last == 30000)
        #expect(ScoringSettings.stepChoices.count == 28)
    }

    @Test("選べる運動の数は1〜6")
    func exerciseChoices() {
        #expect(ScoringSettings.exerciseChoices == [1, 2, 3, 4, 5, 6])
    }

    // MARK: - 保存データの互換

    @Test("旧版の保存データを読んでも失敗しない")
    func decodesOldFormat() throws {
        // 旧版は lowerSteps / upperSteps / mode を書いていた。
        // ここで失敗すると記録が丸ごと消えるので、必ず読めること。
        let old = """
        {"lowerSteps":8000,"upperSteps":16000,"mode":"balanced",
         "startOverride":{"year":2026,"month":8,"day":1}}
        """
        let s = try JSONDecoder().decode(ScoringSettings.self, from: Data(old.utf8))
        #expect(s == ScoringSettings(startOverride: YMD(2026, 8, 1)))
        #expect(s.startOverride == YMD(2026, 8, 1))
    }

    @Test("書き出したものはそのまま読み戻せる")
    func roundTrip() throws {
        let s = ScoringSettings(passSteps: 7000, goalSteps: 14000,
                                passExercises: 3, goalExercises: 5,
                                startOverride: YMD(2026, 1, 15))
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(ScoringSettings.self, from: data) == s)
    }
}
