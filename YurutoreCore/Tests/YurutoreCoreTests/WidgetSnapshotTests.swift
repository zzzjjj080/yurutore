import Foundation
import Testing
@testable import YurutoreCore

/// ウィジェットは別プロセスで、設定も配色も読めない。
/// **渡した中身だけで表示が決まる**ので、ここが狂うと画面と数字が食い違う。
struct WidgetSnapshotTests {

    let acts = Activity.defaults
    let settings = ScoringSettings.default        // 8000歩 / 2種目
    let palette = Palettes.named(nil)

    func snapshot(steps: Int, exercises n: Int, rest: Bool = false) -> WidgetSnapshot {
        var log = DayLog(steps: steps)
        var remaining = n
        for part in BodyPart.allCases where remaining > 0 {
            let v = min(3, remaining)
            log.parts[part] = Volume(rawValue: v)!
            remaining -= v
        }
        if rest { log.setRest(true) }
        return WidgetSnapshot(date: YMD(2026, 9, 9), log: log, activities: acts,
                              settings: settings, palette: palette)
    }

    @Test("カレンダーと同じ点数になる")
    func matchesTheCalendar() {
        let s = snapshot(steps: 6600, exercises: 1)
        var log = DayLog(steps: 6600); log.parts[.chest] = .one
        #expect(s.total == Scorer.liveScore(log, activities: acts, settings: settings))
        #expect(s.stepScore + s.exerciseScore == s.total)
    }

    @Test("合格ラインまでの残りが出る")
    func remaining() {
        let s = snapshot(steps: settings.passSteps - 1760, exercises: 1)
        #expect(s.stepsLeft == 1760)
        #expect(s.exercisesLeft == 1)
        #expect(!s.isPass)
    }

    @Test("届いていれば残りは0")
    func nothingLeftWhenReached() {
        let s = snapshot(steps: 12000, exercises: 3)
        #expect(s.stepsLeft == 0)
        #expect(s.exercisesLeft == 0)
        #expect(s.isPass)
    }

    /// 輪が一周を超えて回ると、達成したことがかえって分かりにくい
    @Test("輪は1で止まる")
    func gaugeIsClamped() {
        let s = snapshot(steps: 30000, exercises: 6)
        #expect(s.stepGauge == 1)
        #expect(s.exerciseGauge == 1)
    }

    /// 歩数も種目数も、同じ40点で一周。基準が違うと見比べられない。
    @Test("輪は40点で一周する")
    func gaugeIsFullAtFortyPoints() {
        let s = snapshot(steps: settings.passSteps, exercises: settings.passExercises)
        #expect(s.stepScore == Scorer.passPoints)
        #expect(s.exerciseScore == Scorer.passPoints)
        #expect(s.stepGauge == 1)
        #expect(s.exerciseGauge == 1)
    }

    /// 輪と、そのすぐ下に出す点数が食い違わないこと
    @Test("輪は、表示している点数と必ず一致する")
    func gaugeMatchesTheShownPoints() {
        for steps in stride(from: 0, through: 20000, by: 500) {
            for n in 0...5 {
                let s = snapshot(steps: steps, exercises: n)
                let expectedStep = min(1.0, Double(s.stepScore) / Double(Scorer.passPoints))
                let expectedEx = min(1.0, Double(s.exerciseScore) / Double(Scorer.passPoints))
                #expect(abs(s.stepGauge - expectedStep) < 0.0001, "\(steps)歩")
                #expect(abs(s.exerciseGauge - expectedEx) < 0.0001, "\(n)種目")
            }
        }
    }

    @Test("半分まで来たら輪も半分")
    func halfway() {
        let s = snapshot(steps: settings.passSteps / 2, exercises: 1)
        #expect(abs(s.stepGauge - 0.5) < 0.0001)
        #expect(abs(s.exerciseGauge - 0.5) < 0.0001)
    }

    /// 歩数は届いたが種目は途中、のような日を輪の濃さで見分ける
    @Test("輪ごとの達成ぐあいが出る")
    func gaugeStates() {
        let mixed = snapshot(steps: 12000, exercises: 1)
        #expect(mixed.stepState == .reached)
        #expect(mixed.exerciseState == .partway)

        let nothing = snapshot(steps: 0, exercises: 0)
        #expect(nothing.stepState == .none)
        #expect(nothing.exerciseState == .none)

        let both = snapshot(steps: settings.passSteps, exercises: settings.passExercises)
        #expect(both.stepState == .reached)
        #expect(both.exerciseState == .reached)
    }

    /// 40点に届いた輪は必ず一周している。濃さと欠けが食い違わないこと
    @Test("届いた輪は一周している")
    func reachedMeansFullRing() {
        for steps in stride(from: 0, through: 20000, by: 500) {
            let s = snapshot(steps: steps, exercises: 0)
            #expect((s.stepState == .reached) == (s.stepGauge >= 1), "\(steps)歩")
        }
    }

    @Test("休養日はそれと分かる")
    func restIsCarried() {
        #expect(snapshot(steps: 3000, exercises: 0, rest: true).isRest)
        #expect(!snapshot(steps: 3000, exercises: 0).isRest)
    }

    /// 配色を読めないので、色ごと渡す。明暗どちらぶんも入っていること。
    @Test("段階の色が入っている")
    func carriesTheColors() {
        let s = snapshot(steps: 12000, exercises: 3)
        #expect(s.fill(dark: false) == palette.fill(s.tier, dark: false))
        #expect(s.fill(dark: true) == palette.fill(s.tier, dark: true))
        #expect(s.ink(dark: false) == palette.colors(dark: false).ink)
    }

    // MARK: - 日をまたいだとき

    /// アプリを開かないまま日をまたぐと、ウィジェットは前の日を出し続ける。
    /// 中身を書き直せるのはアプリだけなので、ウィジェット側で作り直す。
    @Test("繰り越すと、日付だけ進んで中身は空になる")
    func carryOverResetsTheDay() {
        let yesterday = snapshot(steps: 12000, exercises: 3)
        let today = yesterday.carriedOver(to: YMD(2026, 9, 10))

        #expect(today.date == YMD(2026, 9, 10))
        #expect(today.steps == 0)
        #expect(today.exercises == 0)
        #expect(today.total == 0)
        #expect(today.tier == .low)
        #expect(!today.isRest)
    }

    /// 合格ラインは設定なので、日が変わっても引き継ぐ。
    /// ここを0にすると輪が一周した状態で出てしまう。
    @Test("繰り越しても合格ラインは持ち越す")
    func carryOverKeepsTheLines() {
        let today = snapshot(steps: 12000, exercises: 3).carriedOver(to: YMD(2026, 9, 10))
        #expect(today.passSteps == settings.passSteps)
        #expect(today.passExercises == settings.passExercises)
        #expect(today.stepGauge == 0)
        #expect(today.exerciseGauge == 0)
        #expect(today.stepsLeft == settings.passSteps)
    }

    /// 繰り越した日は1段階目。**その色を持っていないと繰り越せない。**
    @Test("繰り越した日は1段階目の色になる")
    func carryOverUsesTheLowestColor() {
        let today = snapshot(steps: 12000, exercises: 3).carriedOver(to: YMD(2026, 9, 10))
        #expect(today.fill(dark: false) == palette.fill(.low, dark: false))
        #expect(today.fill(dark: true) == palette.fill(.low, dark: true))
    }

    @Test("4段階ぶんの色を持っている")
    func carriesEveryTierColor() {
        let s = snapshot(steps: 8000, exercises: 1)
        for tier in DayTier.allCases {
            #expect(s.fill(tier, dark: false) == palette.fill(tier, dark: false))
            #expect(s.fill(tier, dark: true) == palette.fill(tier, dark: true))
        }
    }

    /// 1.3 が書いた保存には4段階の色が入っていない。**読めなくなってはいけない。**
    @Test("1.3 が書いた保存も読める")
    func readsSnapshotsWrittenBefore() throws {
        let old = """
        {"date":{"year":2026,"month":9,"day":9},"steps":8000,"passSteps":8000,
         "stepScore":40,"exercises":2,"passExercises":2,"exerciseScore":40,
         "total":80,"isRest":false,"fillLight":11189196,"fillDark":2245648,
         "inkLight":30874,"inkDark":4115711}
        """
        let s = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(old.utf8))
        #expect(s.total == 80)
        #expect(s.tierFillsLight == nil)
        // 4段階を持っていないので、どの段階を聞かれても今の色で答える
        #expect(s.fill(.low, dark: false) == s.fillLight)
        #expect(s.fill(.pass, dark: false) == s.fillLight)
    }

    // MARK: - ウィジェットが自分で歩数を読む

    /// アプリを開かない日でも、ウィジェットが歩数だけは自分で読めるようにしてある。
    /// **点数の出し方はカレンダーと同じ `Scorer` を通す。**
    @Test("歩数を差し替えると、点数も段階も付け直す")
    func liveStepsRecomputes() {
        let saved = snapshot(steps: 2000, exercises: 2)     // 10 + 40 = 50点
        let now = saved.withLiveSteps(8000)                 // 40 + 40 = 80点

        #expect(now.steps == 8000)
        #expect(now.stepScore == 40)
        #expect(now.total == 80)
        #expect(now.tier == .pass)
        // 種目は本人が入れるものなので動かさない
        #expect(now.exercises == saved.exercises)
        #expect(now.exerciseScore == saved.exerciseScore)
    }

    /// 段階が変われば地の色も変わる。**4段階を持っているから作れる。**
    @Test("段階が上がると色も変わる")
    func liveStepsChangesTheColor() {
        let now = snapshot(steps: 2000, exercises: 2).withLiveSteps(8000)
        #expect(now.fill(dark: false) == palette.fill(.pass, dark: false))
        #expect(now.fill(dark: true) == palette.fill(.pass, dark: true))
    }

    @Test("同じ歩数なら何も変えない")
    func liveStepsNoChange() {
        let saved = snapshot(steps: 8000, exercises: 2)
        #expect(saved.withLiveSteps(8000) == saved)
    }

    /// 差し替えた結果が、カレンダーが出す点数と一致すること。
    /// ここがずれると、ウィジェットとアプリで違う点数が出る。
    @Test("差し替えてもカレンダーと同じ点数になる")
    func liveStepsMatchesTheCalendar() {
        for steps in stride(from: 0, through: 20000, by: 1000) {
            let now = snapshot(steps: 0, exercises: 2).withLiveSteps(steps)
            var log = DayLog(steps: steps)
            log.parts[.chest] = .two
            let expected = Scorer.liveScore(log, activities: acts, settings: settings)
            #expect(now.total == expected, "\(steps)歩")
        }
    }

    /// 1.3 が書いた保存には目標ラインが入っていない。**既定で補って落ちないこと。**
    @Test("目標ラインが無い保存でも差し替えられる")
    func liveStepsWithoutGoalLines() {
        let old = WidgetSnapshot(date: YMD(2026, 9, 19), steps: 0, passSteps: 8000, stepScore: 0,
                                 exercises: 2, passExercises: 2, exerciseScore: 40,
                                 total: 40, isRest: false,
                                 fillLight: 0xD8DDE3, fillDark: 0x85909A,
                                 inkLight: 0x007898, inkDark: 0x3ECFFF)
        #expect(old.goalSteps == nil)
        let now = old.withLiveSteps(8000)
        #expect(now.stepScore == 40)
        #expect(now.total == 80)
    }

    @Test("保存して読み直しても同じ")
    func survivesASaveAndLoad() throws {
        let s = snapshot(steps: 8240, exercises: 1)
        let back = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }

    /// 合格ラインを0にはできないが、壊れた保存を読んでも落ちないこと
    @Test("合格ラインが0でも割り算で落ちない")
    func zeroLineDoesNotCrash() {
        let s = WidgetSnapshot(date: YMD(2026, 9, 9), steps: 100, passSteps: 0, stepScore: 40,
                               exercises: 0, passExercises: 0, exerciseScore: 0,
                               total: 40, isRest: false,
                               fillLight: 0, fillDark: 0, inkLight: 0, inkDark: 0)
        #expect(s.stepGauge == 1)
        #expect(s.exerciseGauge == 0)
    }
}
