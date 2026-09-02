import Foundation
import Testing
@testable import YurutoreCore

/// カレンダーの色は4段階しかない。その段階の決まり方をここで固定する。
///
/// **点数からは段階を復元できない**（78点の日が2通りある）ので、
/// 記録そのものを見て決める。確定した日は、そのときの段階を焼き付ける。
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

    @Test("どちらの線にも届かない日は1段階目")
    func neither() {
        #expect(tier(day(steps: 0, exercises: 0)) == .none)
        #expect(tier(day(steps: 5000, exercises: 1)) == .none)
        // 9900歩(39点)＋1種目(20点)＝59点。点数はそこそこでも、線は1本も越えていない
        #expect(tier(day(steps: 9900, exercises: 1)) == .none)
    }

    @Test("片方だけ届いた日は2段階目")
    func onlyOne() {
        #expect(tier(day(steps: 10000, exercises: 0)) == .half)   // 歩数だけ
        #expect(tier(day(steps: 0, exercises: 2)) == .half)       // 運動だけ
        #expect(tier(day(steps: 12000, exercises: 1)) == .half)
    }

    @Test("両方届いた日は3段階目")
    func both() {
        #expect(tier(day(steps: 10000, exercises: 2)) == .both)
        #expect(tier(day(steps: 14000, exercises: 2)) == .both)
    }

    @Test("100点は4段階目")
    func perfect() {
        #expect(tier(day(steps: 16000, exercises: 3)) == .perfect)
        #expect(tier(day(steps: 30000, exercises: 6)) == .perfect)
    }

    /// よく歩いた日は歩数だけで60点まで伸びるので、1種目でも80点に届く。
    /// 「80点＝合格」と出しながら不合格の色で塗るのはおかしいので、合格の色にする。
    @Test("80点に届いた日は、線が1本でも合格の色にする")
    func passLineWins() {
        let log = day(steps: 16000, exercises: 1)          // 60 + 20 = 80
        #expect(Scorer.autoScore(log, activities: acts, settings: settings) == 80)
        #expect(Scorer.isPass(log, activities: acts, settings: settings))
        #expect(tier(log) == .both)
    }

    @Test("手入力の日は点数から決める")
    func manual() {
        var log = day(steps: 0, exercises: 0)
        log.manualScore = 100
        #expect(tier(log) == .perfect)
        log.manualScore = 80
        #expect(tier(log) == .both)
        log.manualScore = 50
        #expect(tier(log) == .half)
        log.manualScore = 20
        #expect(tier(log) == .none)
    }

    @Test("確定したら、設定を変えても段階は動かない")
    func settledStaysPut() {
        var journal = Journal()
        let date = YMD(2026, 8, 1)
        journal[date] = day(steps: 10000, exercises: 2)          // 両方届いた
        journal.settleAll(today: YMD(2026, 8, 10), activities: acts, settings: settings)

        #expect(journal[date]?.lockedTier == .both)
        #expect(journal[date]?.lockedScore == 80)

        // 合格ラインを引き上げても、確定済みの日は動かない
        var harder = settings
        harder.setPassSteps(20000)
        harder.setPassExercises(5)
        #expect(Scorer.tier(journal[date]!, activities: acts, settings: harder) == .both)
    }

    @Test("確定した日を編集したら、段階も付け直す")
    func editingSettledDayRecomputes() {
        var journal = Journal()
        let date = YMD(2026, 8, 1)
        journal[date] = day(steps: 3000, exercises: 0)
        journal.settleAll(today: YMD(2026, 8, 10), activities: acts, settings: settings)
        #expect(journal[date]?.lockedTier == DayTier.none)

        // 忘れていた運動をあとから足す
        journal[date]?.steps = 12000
        journal[date]?.parts[.chest] = .two
        journal.touch(date, activities: acts, settings: settings)
        #expect(journal[date]?.lockedTier == .both)
    }

    /// 1.1以前に確定した日には段階が入っていない。
    /// **ここで例外を投げると、記録が丸ごと読めなくなる。**（引き継ぎ書 4-21）
    @Test("段階を持たない旧版の記録も、そのまま読める")
    func readsOldRecordsWithoutTier() throws {
        let old = """
        {"steps":12000,"parts":{"chest":2},"activities":{},"isRest":false,"lockedScore":80}
        """
        let log = try JSONDecoder().decode(DayLog.self, from: Data(old.utf8))
        #expect(log.steps == 12000)
        #expect(log.lockedScore == 80)
        #expect(log.lockedTier == nil)
        // 段階が無いので、確定した点数から読み替える
        #expect(tier(log) == .both)
    }

    @Test("休養日は運動0として扱う")
    func restDay() {
        var log = day(steps: 12000, exercises: 0)
        log.setRest(true)
        #expect(tier(log) == .half)     // 歩数だけ届いた
    }
}
