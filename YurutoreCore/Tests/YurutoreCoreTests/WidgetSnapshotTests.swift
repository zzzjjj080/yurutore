import Foundation
import Testing
@testable import YurutoreCore

/// ウィジェットは別プロセスで、設定も配色も読めない。
/// **渡した中身だけで表示が決まる**ので、ここが狂うと画面と数字が食い違う。
struct WidgetSnapshotTests {

    let acts = Activity.defaults
    let settings = ScoringSettings.default        // 10000歩 / 2種目
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
        let s = snapshot(steps: 8240, exercises: 1)
        var log = DayLog(steps: 8240); log.parts[.chest] = .one
        #expect(s.total == Scorer.liveScore(log, activities: acts, settings: settings))
        #expect(s.stepScore + s.exerciseScore == s.total)
    }

    @Test("合格ラインまでの残りが出る")
    func remaining() {
        let s = snapshot(steps: 8240, exercises: 1)
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
        let s = snapshot(steps: 10000, exercises: 2)
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
        let s = snapshot(steps: 5000, exercises: 1)
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

        let both = snapshot(steps: 10000, exercises: 2)
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
