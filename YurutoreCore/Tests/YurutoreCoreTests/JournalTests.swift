import Foundation
import Testing
@testable import YurutoreCore

/// 確定・起点・集計。ここは「過去が勝手に書き換わらないこと」を守る仕組みなので、
/// 設定を変えてから確かめるテストを厚くしてある。
struct JournalTests {

    let acts = Activity.defaults
    let settings = ScoringSettings.default
    let today = YMD(2026, 8, 14)

    func sample() -> Journal {
        var j = Journal()
        j[YMD(2026, 8, 1)]  = DayLog(steps: 9120,  parts: [.chest: .two, .arm: .one])
        j[YMD(2026, 8, 2)]  = DayLog(steps: 4300,  activities: ["radio": .one])
        j[YMD(2026, 8, 10)] = DayLog(steps: 5200)                       // 歩数だけ＝未入力
        j[YMD(2026, 8, 12)] = DayLog(steps: 8100,  parts: [.chest: .two])
        j[YMD(2026, 8, 13)] = DayLog(steps: 7400,  parts: [.back: .one])
        j[YMD(2026, 8, 14)] = DayLog(steps: 12600, parts: [.arm: .two])
        return j
    }

    // MARK: - 確定

    @Test("3日経った日だけが確定する")
    func settleAfterGraceDays() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        #expect(j[YMD(2026, 8, 1)]?.lockedScore != nil)   // 13日前
        #expect(j[YMD(2026, 8, 10)]?.lockedScore != nil)  // 4日前
        #expect(j[YMD(2026, 8, 12)]?.lockedScore == nil)  // 2日前
        #expect(j[YMD(2026, 8, 13)]?.lockedScore == nil)  // 1日前
        #expect(j[YMD(2026, 8, 14)]?.lockedScore == nil)  // 今日
    }

    @Test("確定した日は合格ラインを変えても動かない")
    func lockedScoreSurvivesSettingsChange() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let settled = Scorer.score(j[YMD(2026, 8, 1)]!, activities: acts, settings: settings)
        let unsettled = Scorer.score(j[YMD(2026, 8, 13)]!, activities: acts, settings: settings)

        var changed = settings; changed.passSteps = 4000; changed.goalSteps = 7000
        #expect(Scorer.score(j[YMD(2026, 8, 1)]!, activities: acts, settings: changed) == settled,
                "確定済みの日が動いた")
        #expect(Scorer.score(j[YMD(2026, 8, 13)]!, activities: acts, settings: changed) != unsettled,
                "未確定の日が追従していない")
    }

    @Test("確定した日を編集したら、その日だけ計算し直して確定し直す")
    func touchReSettles() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let date = YMD(2026, 8, 2)          // 4300歩＋運動1つ
        let before = Scorer.score(j[date]!, activities: acts, settings: settings)

        j[date]?.setPart(.chest, to: .one)  // 忘れていた運動を足す
        j.touch(date, activities: acts, settings: settings)

        let after = Scorer.score(j[date]!, activities: acts, settings: settings)
        #expect(after > before, "編集しても点数が変わらない")
        #expect(j[date]?.lockedScore == after, "確定し直されていない")
    }

    @Test("未確定の日を編集しても確定はされない")
    func touchDoesNotLockUnsettled() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let date = YMD(2026, 8, 13)
        j[date]?.setPart(.leg, to: .two)
        j.touch(date, activities: acts, settings: settings)
        #expect(j[date]?.lockedScore == nil)
    }

    // MARK: - 集計の起点

    @Test("起点は本人が最初に入力した日。歩数だけの日は起点にならない")
    func startDateIgnoresStepsOnly() {
        var j = Journal()
        j[YMD(2026, 7, 20)] = DayLog(steps: 12000)                       // 歩数だけ
        j[YMD(2026, 8, 1)]  = DayLog(steps: 9000, parts: [.chest: .one]) // 初めての運動
        #expect(j.startDate(activities: acts) == YMD(2026, 8, 1))

        j[YMD(2026, 7, 20)]?.setPart(.leg, to: .one)
        #expect(j.startDate(activities: acts) == YMD(2026, 7, 20))
    }

    @Test("休養日にした日も起点になる")
    func restCountsAsStart() {
        var j = Journal()
        var rest = DayLog(steps: 3000); rest.setRest(true)
        j[YMD(2026, 8, 3)] = rest
        #expect(j.startDate(activities: acts) == YMD(2026, 8, 3))
    }

    @Test("記録が1件も無ければ起点は無い")
    func noStartDate() {
        #expect(Journal().startDate(activities: acts) == nil)
    }

    // MARK: - 集計範囲

    @Test("今月は昨日まで。今日は含めない")
    func rangeExcludesToday() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let r = j.countedRange(year: 2026, month: 8, today: today, activities: acts)
        #expect(r == 1...13)
    }

    @Test("起点より前の月は集計しない")
    func rangeBeforeStart() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        #expect(j.countedRange(year: 2026, month: 7, today: today, activities: acts) == nil)
    }

    @Test("起点の月は、その日から集計する")
    func rangeStartsAtStartDate() {
        var j = Journal()
        j[YMD(2026, 8, 20)] = DayLog(steps: 9000, parts: [.chest: .one])
        let r = j.countedRange(year: 2026, month: 8, today: YMD(2026, 9, 5), activities: acts)
        #expect(r == 20...31)
    }

    @Test("未来の月は集計しない")
    func rangeFuture() {
        let j = sample()
        #expect(j.countedRange(year: 2026, month: 12, today: today, activities: acts) == nil)
    }

    @Test("月初が今日なら、その月に集計対象は無い")
    func rangeFirstOfMonth() {
        var j = Journal()
        j[YMD(2026, 8, 1)] = DayLog(steps: 9000, parts: [.chest: .one])
        #expect(j.countedRange(year: 2026, month: 9, today: YMD(2026, 9, 1), activities: acts) == nil)
    }

    // MARK: - 月次集計

    @Test("達成率の分母は集計対象の日数")
    func monthSummary() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let s = j.monthSummary(year: 2026, month: 8, today: today,
                               activities: acts, settings: settings)
        #expect(s.countedDays == 13)
        #expect(s.passRate == Int((Double(s.passedDays) / 13.0 * 100).rounded()))
        // 今日(8/14)の歩数は合計に入らない
        #expect(s.totalSteps == 9120 + 4300 + 5200 + 8100 + 7400)
    }

    @Test("記録が無ければ達成率は出さない（0除算しない）")
    func emptyMonthSummary() {
        let j = Journal()
        let s = j.monthSummary(year: 2026, month: 8, today: today,
                               activities: acts, settings: settings)
        #expect(s.countedDays == 0)
        #expect(s.passRate == nil)
        #expect(s.averageSteps == nil)
        #expect(s.averageScore == nil)
    }

    @Test("年集計は12ヶ月ぶんの達成率を返す")
    func yearSummary() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let y = j.yearSummary(year: 2026, today: today, activities: acts, settings: settings)
        #expect(y.monthlyPassRate.count == 12)
        #expect(y.monthlyPassRate[7] != nil)   // 8月
        #expect(y.monthlyPassRate[8] == nil)   // 9月は未来
        #expect(y.monthlyPassRate[6] == nil)   // 7月は起点より前
    }

    // MARK: - 最近30日

    @Test("最近30日は今日も数えるが、平均と達成した日には今日を入れない")
    func recentSummaryIncludesTodayOnlyForParts() {
        var j = sample()
        j.settleAll(today: today, activities: acts, settings: settings)
        let s = j.recentSummary(today: today, activities: acts, settings: settings)
        // 起点(8/1)から昨日(8/13)までの13日
        #expect(s.countedDays == 13)
        // 今日の腕×2 も部位には入る
        #expect(s.partCounts[.arm] == 3)
        #expect(s.partCounts[.chest] == 4)
        // 歩数の合計に今日(12600)は入らない
        #expect(s.totalSteps == 9120 + 4300 + 5200 + 8100 + 7400)
    }

    @Test("月をまたいでも窓の長さは変わらない（月初でも29日ぶん数える）")
    func recentSummaryCrossesMonths() {
        var j = sample()
        let later = YMD(2026, 9, 2)
        j[YMD(2026, 9, 1)] = DayLog(steps: 9000, parts: [.leg: .one])
        let s = j.recentSummary(today: later, activities: acts, settings: settings)
        // 8/4〜9/1 の29日（今日=9/2 は分母に入れない）
        #expect(s.countedDays == 29)
        #expect(s.partCounts[.leg] == 1)
        // 起点より前(7月)は窓に入らないので、8/1・8/2 の記録は落ちる
        #expect(s.partCounts[.chest] == 2)
    }

    @Test("起点より前は数えない")
    func recentSummaryStopsAtStart() {
        var j = Journal()
        j[YMD(2026, 8, 12)] = DayLog(steps: 8100, parts: [.core: .one])
        let s = j.recentSummary(today: today, activities: acts, settings: settings)
        #expect(s.countedDays == 2)          // 8/12・8/13（今日=8/14 は入れない）
        #expect(s.partCounts[.core] == 1)
    }

    @Test("記録が無ければ最近30日でも達成率は出さない（0除算しない）")
    func emptyRecentSummary() {
        let s = Journal().recentSummary(today: today, activities: acts, settings: settings)
        #expect(s.countedDays == 0)
        #expect(s.passRate == nil)
        #expect(s.averageSteps == nil)
        #expect(s.averageScore == nil)
        #expect(s.partCounts[.chest] == 0)
    }

    // MARK: - 状態

    @Test("1日は3つの状態のどれか")
    func dayStates() {
        var log = DayLog(steps: 5000)
        #expect(log.state(activities: acts) == .unlogged)

        log.setRest(true)
        #expect(log.state(activities: acts) == .rest)

        log.setPart(.chest, to: .one)
        #expect(log.state(activities: acts) == .logged)
        #expect(log.isRest == false, "運動を足したら休養日は外れるはず")

        log.setRest(true)
        #expect(log.parts.isEmpty, "休養日にしたら運動は消えるはず")
    }

    @Test("倍率は なし→1→2→3→なし と巡回する")
    func volumeCycle() {
        var v: Volume? = nil
        var seen: [Int] = []
        for _ in 0..<5 {
            v = Volume.cycled(from: v)
            seen.append(v?.rawValue ?? 0)
        }
        #expect(seen == [1, 2, 3, 0, 1])
    }
}

/// 「この日から記録を始めた」を本人が指定できる。
/// 機種変前の歩数がヘルスケアに残っていると、勝手に古い日から数え始めてしまうため。
struct StartOverrideTests {

    let acts = Activity.defaults
    let today = YMD(2026, 8, 17)

    func sample() -> Journal {
        var j = Journal()
        j[YMD(2026, 6, 10)] = DayLog(steps: 9000, parts: [.chest: .one])
        j[YMD(2026, 8, 3)]  = DayLog(steps: 11000, parts: [.back: .two])
        j[YMD(2026, 8, 12)] = DayLog(steps: 8000, parts: [.leg: .one])
        return j
    }

    @Test("指定した日が起点になる")
    func overrideWins() {
        let j = sample()
        #expect(j.startDate(activities: acts) == YMD(2026, 6, 10))
        #expect(j.startDate(activities: acts, override: YMD(2026, 8, 1)) == YMD(2026, 8, 1))
    }

    @Test("指定より前の月は集計しない")
    func rangeRespectsOverride() {
        let j = sample()
        #expect(j.countedRange(year: 2026, month: 6, today: today, activities: acts) != nil)
        #expect(j.countedRange(year: 2026, month: 6, today: today,
                               activities: acts, override: YMD(2026, 8, 1)) == nil)
    }

    @Test("指定した月は、その日から集計する")
    func rangeStartsAtOverride() {
        let j = sample()
        let r = j.countedRange(year: 2026, month: 8, today: today,
                               activities: acts, override: YMD(2026, 8, 5))
        #expect(r == 5...16)
    }

    @Test("設定に入れた起点が月次集計に効く")
    func settingsCarryOverride() {
        let j = sample()
        var s = ScoringSettings.default
        #expect(j.monthSummary(year: 2026, month: 6, today: today,
                               activities: acts, settings: s).countedDays > 0)
        s.startOverride = YMD(2026, 8, 1)
        #expect(j.monthSummary(year: 2026, month: 6, today: today,
                               activities: acts, settings: s).countedDays == 0)
    }

    @Test("記録より後ろの日を指定しても壊れない")
    func overrideAfterAllRecords() {
        let j = sample()
        let s = ScoringSettings(startOverride: YMD(2026, 12, 1))
        let m = j.monthSummary(year: 2026, month: 8, today: today,
                               activities: acts, settings: s)
        #expect(m.countedDays == 0)
        #expect(m.passRate == nil)
    }
}

/// 歩数が静かに止まったことに気づけるか。
/// **止まっても点数は毎日20点で埋まる**ので、見ているだけでは分からない。
struct StepsMissingTests {

    let acts = Activity.defaults

    func journal(startingDaysAgo: Int, steps: [Int]) -> Journal {
        var j = Journal()
        let today = YMD(2026, 9, 9)
        // 起点になる日（運動を1つ入れた日）
        var first = DayLog(steps: 5000)
        first.parts[.chest] = .one
        j[today.adding(days: -startingDaysAgo)] = first
        for (i, count) in steps.enumerated() {
            j[today.adding(days: -(i + 1))] = DayLog(steps: count)
        }
        return j
    }

    @Test("直近3日の歩数が0なら、届いていないとみなす")
    func allZeroIsMissing() {
        let j = journal(startingDaysAgo: 30, steps: [0, 0, 0])
        #expect(j.stepsLookMissing(today: YMD(2026, 9, 9),
                                   start: j.startDate(activities: acts)))
    }

    @Test("1日でも歩いていれば、届いている")
    func oneDayWithStepsIsFine() {
        let j = journal(startingDaysAgo: 30, steps: [0, 4200, 0])
        #expect(!j.stepsLookMissing(today: YMD(2026, 9, 9),
                                    start: j.startDate(activities: acts)))
    }

    /// 使い始めた直後は、記録が無いだけかもしれない。**決めつけない。**
    @Test("使い始めて間もないうちは判断しない")
    func tooEarlyToTell() {
        let j = journal(startingDaysAgo: 2, steps: [0, 0, 0])
        #expect(!j.stepsLookMissing(today: YMD(2026, 9, 9),
                                    start: j.startDate(activities: acts)))
    }

    @Test("起点が無ければ判断しない")
    func noStartMeansNoJudgement() {
        let j = journal(startingDaysAgo: 30, steps: [0, 0, 0])
        #expect(!j.stepsLookMissing(today: YMD(2026, 9, 9), start: nil))
    }

    /// 当日は途中なので、0でも判断に入れない
    @Test("今日の歩数は見ない")
    func todayIsNotCounted() {
        var j = journal(startingDaysAgo: 30, steps: [8000, 9000, 7000])
        j[YMD(2026, 9, 9)] = DayLog(steps: 0)
        #expect(!j.stepsLookMissing(today: YMD(2026, 9, 9),
                                    start: j.startDate(activities: acts)))
    }
}

/// 部位の見せ方。良し悪しを付けず、見た目だけを選べるようにしたもの。
struct PartsStyleTests {

    @Test("見せ方は棒と札の2つ")
    func twoStyles() {
        #expect(PartsStyle.allCases.count == 2)
        #expect(PartsStyle.allCases.contains(.bars))
        #expect(PartsStyle.allCases.contains(.tiles))
    }

    @Test("保存して読み直しても同じ")
    func roundTrip() throws {
        for s in PartsStyle.allCases {
            let data = try JSONEncoder().encode(s)
            #expect(try JSONDecoder().decode(PartsStyle.self, from: data) == s)
        }
    }

    /// 5通りあった版で「輪」を選んでいた端末が更新されても、落ちずに既定へ戻る
    @Test("知らない名前・未設定は既定に落ちる")
    func unknownFallsBack() {
        #expect(PartsStyle.from(nil) == .default)
        #expect(PartsStyle.from("rings") == .default)
        #expect(PartsStyle.from("numbers") == .default)
        #expect(PartsStyle.from("tiles") == .tiles)
    }

    @Test("名前は日英とも空でない")
    func names() {
        for s in PartsStyle.allCases {
            #expect(!s.japanese.isEmpty)
            #expect(!s.english.isEmpty)
        }
        for c in PartsColors.all {
            #expect(!c.name(japanese: true).isEmpty)
            #expect(!c.name(japanese: false).isEmpty)
        }
    }
}

/// 色と濃淡。**数字が読めるかどうかまでここで測る。**
/// 画面側に置くと測れないので、色の計算は Core に持たせてある。
struct PartsColorTests {

    @Test("カレンダーに合わせるは色を持たない。ほかは明暗どちらも持つ")
    func colorTable() {
        let follow = PartsColors.named(PartsColors.followID)
        #expect(follow.hex(dark: false) == nil)
        #expect(follow.hex(dark: true) == nil)
        for c in PartsColors.all where c.id != PartsColors.followID {
            #expect(c.hex(dark: false) != nil)
            #expect(c.hex(dark: true) != nil)
        }
    }

    @Test("知らない色は「カレンダーに合わせる」に落ちる")
    func unknownColor() {
        #expect(PartsColors.named(nil).id == PartsColors.followID)
        #expect(PartsColors.named("gold").id == PartsColors.followID)
        #expect(PartsColors.named("rose").id == "rose")
    }

    @Test("濃淡なしは全部同じ濃さ。強いほど少ない側が薄くなる")
    func shadeCurve() {
        #expect(PartsShade.none.opacity(0) == 1)
        #expect(PartsShade.none.opacity(1) == 1)
        for s in PartsShade.allCases {
            // いちばん多い部位は、どの強さでも濃さいっぱい
            #expect(s.opacity(1) == 1)
            // 範囲の外を渡されても 0〜1 に収まる
            #expect(s.opacity(-5) >= 0 && s.opacity(-5) <= 1)
            #expect(s.opacity(9) == 1)
        }
        #expect(PartsShade.weak.opacity(0) > PartsShade.medium.opacity(0))
        #expect(PartsShade.medium.opacity(0) > PartsShade.strong.opacity(0))
    }

    /// 札は色の上に数字が乗る。**どの色・どの濃さ・どの濃淡でも読めること。**
    /// 「濃い」を選べるようにした以上、ここが崩れていないかは毎回測る。
    @Test("札の数字は、どの組み合わせでも読める")
    func tileTextIsReadable() {
        // 札の下地（カードの色）。明暗それぞれ
        let grounds: [(bg: UInt32, dark: Bool)] = [(0xFFFFFF, false), (0x1C1C1E, true)]
        for c in PartsColors.all {
            for (bg, dark) in grounds {
                guard let hex = c.hex(dark: dark) else { continue }
                for depth in PartsDepth.allCases {
                    for shade in PartsShade.allCases {
                        for ratio in [0.0, 0.25, 0.5, 0.75, 1.0] {
                            let a = shade.tileAlpha(ratio, depth: depth)
                            let (fill, ink) = ColorMath.readableFill(hex, over: bg, alpha: a)
                            #expect(ColorMath.contrast(ink, fill) >= 4.5,
                                    "\(c.id) depth=\(depth) shade=\(shade) ratio=\(ratio) dark=\(dark)")
                        }
                    }
                }
            }
        }
    }

    @Test("濃いほど塗りが濃くなる。薄いほうにも下限がある")
    func depthOrder() {
        for shade in PartsShade.allCases {
            #expect(shade.tileAlpha(1, depth: .light) < shade.tileAlpha(1, depth: .normal))
            #expect(shade.tileAlpha(1, depth: .normal) < shade.tileAlpha(1, depth: .deep))
            #expect(shade.barAlpha(1, depth: .deep) == 1)
            // いちばん少ない部位でも消えない
            #expect(shade.tileAlpha(0, depth: .light) >= 0.12)
            #expect(shade.barAlpha(0, depth: .light) >= 0.15)
        }
        #expect(PartsDepth.from(nil) == .default)
        #expect(PartsDepth.from(9) == .default)
        #expect(PartsDepth.from(2) == .deep)
    }

    @Test("重ねた色は、濃さ0で背景そのもの・1で元の色")
    func blendEnds() {
        #expect(ColorMath.blend(0x2F6FD0, over: 0xFFFFFF, alpha: 0) == 0xFFFFFF)
        #expect(ColorMath.blend(0x2F6FD0, over: 0xFFFFFF, alpha: 1) == 0x2F6FD0)
    }
}
