import Foundation
import Testing
@testable import YurutoreCore

/// カレンダーの色は4段階しかない。境目をここで固定する。
///
/// **点数だけで決める。** 確定済みの日も手入力の日も同じ規則で塗れて、
/// マスに出ている数字とも食い違わない。
struct TierTests {

    let acts = Activity.defaults
    let settings = ScoringSettings.default   // 10000/16000歩・2/3種目

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

    func tier(_ log: DayLog) -> DayTier {
        Scorer.tier(log, activities: acts, settings: settings)
    }

    /// 境目は採点の決まりから来ている。40点＝片方の合格ライン、80点＝合格。
    @Test("点数の境目")
    func boundaries() {
        #expect(Scorer.tier(0) == .low)
        #expect(Scorer.tier(39) == .low)
        #expect(Scorer.tier(40) == .mid)
        #expect(Scorer.tier(79) == .mid)
        #expect(Scorer.tier(80) == .pass)
        #expect(Scorer.tier(99) == .pass)
        #expect(Scorer.tier(100) == .full)
    }

    /// 境目が採点側の定数からずれていないこと。
    /// どちらかを直したときに、もう一方を直し忘れると気づけない。
    @Test("境目は採点の定数と同じところにある")
    func boundariesFollowScoring() {
        #expect(Scorer.tier(Scorer.passPoints) == .mid)
        #expect(Scorer.tier(Scorer.passPoints - 1) == .low)
        #expect(Scorer.tier(Scorer.passLine) == .pass)
        #expect(Scorer.tier(Scorer.passLine - 1) == .mid)
    }

    @Test("3段階目は「合格」と一致する")
    func passMatchesIsPass() {
        for steps in stride(from: 0, through: 24000, by: 1000) {
            for n in 0...6 {
                let log = day(steps: steps, exercises: n)
                let passed = Scorer.isPass(log, activities: acts, settings: settings)
                #expect(passed == (tier(log) >= .pass), "\(steps)歩 \(n)種目")
            }
        }
    }

    @Test("記録から塗る色が出る")
    func fromRecords() {
        #expect(tier(day(steps: 0, exercises: 0)) == .low)
        #expect(tier(day(steps: 10000, exercises: 0)) == .mid)   // 40点
        #expect(tier(day(steps: 10000, exercises: 2)) == .pass)  // 80点
        #expect(tier(day(steps: 16000, exercises: 3)) == .full)  // 100点
    }

    @Test("手入力の日も同じ規則で塗る")
    func manual() {
        var log = day(steps: 0, exercises: 0)
        for (score, expected) in [(100, DayTier.full), (80, .pass), (50, .mid), (20, .low)] {
            log.manualScore = score
            #expect(tier(log) == expected, "手入力 \(score)点")
        }
    }

    /// 確定した点数がそのまま色になる。**段階を別に保存する必要がない。**
    @Test("確定したら、設定を変えても色は動かない")
    func settledStaysPut() {
        var journal = Journal()
        let date = YMD(2026, 8, 1)
        journal[date] = day(steps: 10000, exercises: 2)
        journal.settleAll(today: YMD(2026, 8, 10), activities: acts, settings: settings)
        #expect(journal[date]?.lockedScore == 80)

        var harder = settings
        harder.setPassSteps(20000)
        harder.setPassExercises(5)
        #expect(Scorer.tier(journal[date]!, activities: acts, settings: harder) == .pass)
    }

    @Test("確定した日を編集したら、色も付け直す")
    func editingSettledDayRecomputes() {
        var journal = Journal()
        let date = YMD(2026, 8, 1)
        journal[date] = day(steps: 3000, exercises: 0)
        journal.settleAll(today: YMD(2026, 8, 10), activities: acts, settings: settings)
        #expect(Scorer.tier(journal[date]!, activities: acts, settings: settings) == .low)

        journal[date]?.steps = 12000
        journal[date]?.parts[.chest] = .two
        journal.touch(date, activities: acts, settings: settings)
        #expect(Scorer.tier(journal[date]!, activities: acts, settings: settings) == .pass)
    }

    /// **ここで例外を投げると、記録が丸ごと読めなくなる。**（引き継ぎ書 4-21）
    @Test("1.1までに保存した記録も、そのまま読める")
    func readsOldRecords() throws {
        let old = """
        {"steps":12000,"parts":{"chest":2},"activities":{},"isRest":false,"lockedScore":80}
        """
        let log = try JSONDecoder().decode(DayLog.self, from: Data(old.utf8))
        #expect(log.steps == 12000)
        #expect(log.lockedScore == 80)
        #expect(tier(log) == .pass)
    }

    @Test("休養日でも歩数の点は入る")
    func restDay() {
        var log = day(steps: 12000, exercises: 0)
        log.setRest(true)
        #expect(tier(log) == .mid)
    }
}
