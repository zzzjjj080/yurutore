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
    @Test("進み具合は1で止まる")
    func progressIsClamped() {
        let s = snapshot(steps: 30000, exercises: 6)
        #expect(s.stepProgress == 1)
        #expect(s.exerciseProgress == 1)
    }

    @Test("進み具合は合格ラインに対する割合")
    func progressIsAgainstThePassLine() {
        let s = snapshot(steps: 5000, exercises: 1)
        #expect(abs(s.stepProgress - 0.5) < 0.0001)
        #expect(abs(s.exerciseProgress - 0.5) < 0.0001)
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
        #expect(s.stepProgress == 1)
        #expect(s.exerciseProgress == 0)
    }
}
