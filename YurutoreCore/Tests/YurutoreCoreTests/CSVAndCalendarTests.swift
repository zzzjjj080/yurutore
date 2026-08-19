import Foundation
import Testing
@testable import YurutoreCore

/// バックアップが壊れると取り返しがつかないので、往復を厚く確かめる。
struct CSVTests {

    let acts = Activity.defaults
    let settings = ScoringSettings.default
    let today = YMD(2026, 8, 14)

    func sample() -> Journal {
        var j = Journal()
        j[YMD(2026, 8, 1)]  = DayLog(steps: 9120, parts: [.chest: .two, .arm: .one])
        j[YMD(2026, 8, 2)]  = DayLog(steps: 4300, activities: ["radio": .one])
        var rest = DayLog(steps: 3100); rest.setRest(true)
        j[YMD(2026, 8, 6)]  = rest
        j[YMD(2026, 8, 12)] = DayLog(steps: 8100, parts: [.core: .three], activities: ["swim": .two])
        j[YMD(2026, 8, 13)] = DayLog(steps: 7400, parts: [.back: .one], manualScore: 60)
        j.settleAll(today: today, activities: acts, settings: settings)
        return j
    }

    @Test("書き出して読み戻すと元に戻る")
    func roundTrip() throws {
        let original = sample()
        let csv = CSVFormat.export(original, activities: acts, settings: settings)
        let result = try CSVFormat.import(csv, activities: acts)

        #expect(result.droppedNames.isEmpty)
        #expect(result.journal.days.count == original.days.count)
        for (date, log) in original.days {
            let back = try #require(result.journal[date])
            #expect(back.steps == log.steps, "\(date) の歩数")
            #expect(back.parts == log.parts, "\(date) の部位")
            #expect(back.activities == log.activities, "\(date) の運動")
            #expect(back.isRest == log.isRest, "\(date) の休養日")
            #expect(Scorer.score(back, activities: acts, settings: settings)
                    == Scorer.score(log, activities: acts, settings: settings), "\(date) の点数")
        }
    }

    @Test("確定した点数は読み込みで計算し直されない")
    func lockedScorePreserved() throws {
        let j = sample()
        let date = YMD(2026, 8, 1)
        let before = Scorer.score(j[date]!, activities: acts, settings: settings)
        let csv = CSVFormat.export(j, activities: acts, settings: settings)

        // 設定を変えてから読み込む
        var changed = settings; changed.passSteps = 4000; changed.goalSteps = 7000
        let result = try CSVFormat.import(csv, activities: acts)
        let after = Scorer.score(result.journal[date]!, activities: acts, settings: changed)
        #expect(after == before, "読み込みで過去の点数が書き換わった")
    }

    @Test("手入力も往復する")
    func manualRoundTrip() throws {
        let j = sample()
        let csv = CSVFormat.export(j, activities: acts, settings: settings)
        let result = try CSVFormat.import(csv, activities: acts)
        #expect(result.journal[YMD(2026, 8, 13)]?.manualScore == 60)
    }

    @Test("英語で書き出したものを日本語のまま読める")
    func crossLanguage() throws {
        let j = sample()
        let en = CSVFormat.export(j, activities: acts, settings: settings, language: .english)
        #expect(en.contains("Chestx2"))
        let result = try CSVFormat.import(en, activities: acts)
        #expect(result.journal[YMD(2026, 8, 1)]?.parts[.chest] == .two)
        #expect(result.journal[YMD(2026, 8, 6)]?.isRest == true)
    }

    @Test("設定に無い運動は黙って捨てず、名前を返す")
    func reportsDroppedActivities() throws {
        let j = sample()
        let csv = CSVFormat.export(j, activities: acts, settings: settings)
            .replacingOccurrences(of: "ラジオ体操", with: "縄跳び")
            .replacingOccurrences(of: "水泳", with: "ボルダリング")
        let result = try CSVFormat.import(csv, activities: acts)
        #expect(Set(result.droppedNames) == ["縄跳び", "ボルダリング"])
    }

    @Test("引用符つきのセルを読める")
    func quotedCells() throws {
        let csv = """
        日付,歩数,部位,その他の運動,休養日,点数,点数の出どころ
        2026-08-20,5000,"胸x2 背x1",,,45,自動
        """
        let result = try CSVFormat.import(csv, activities: acts)
        #expect(result.journal[YMD(2026, 8, 20)]?.parts == [.chest: .two, .back: .one])
    }

    @Test("ヘッダが無くても読める")
    func headerless() throws {
        let csv = "2026-08-20,5000,胸x2,,,45,自動"
        let result = try CSVFormat.import(csv, activities: acts)
        #expect(result.journal.days.count == 1)
    }

    @Test("壊れた入力は読み込まずにエラーにする")
    func rejectsGarbage() {
        #expect(throws: CSVFormat.ImportError.self) {
            _ = try CSVFormat.import("", activities: acts)
        }
        #expect(throws: CSVFormat.ImportError.self) {
            _ = try CSVFormat.import("あいうえお\nかきくけこ", activities: acts)
        }
        #expect(throws: CSVFormat.ImportError.self) {
            _ = try CSVFormat.import("2026-13-45,100,,,,50,自動", activities: acts)
        }
    }

    @Test("ExcelのためにBOMを付ける")
    func bom() {
        let data = CSVFormat.exportWithBOM(sample(), activities: acts, settings: settings)
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
    }
}

/// 月をまたぐ配置は事故が多いので、境界を並べて確かめる。
struct CalendarLayoutTests {

    @Test("どの月でも必ず42マス", arguments: [
        (2026, 1), (2026, 2), (2026, 8), (2026, 11), (2027, 2), (2028, 2)
    ])
    func alwaysFortyTwo(_ ym: (Int, Int)) {
        for ws in CalendarLayout.WeekStart.allCases {
            let cells = CalendarLayout.cells(year: ym.0, month: ym.1, weekStart: ws)
            #expect(cells.count == CalendarLayout.cellCount)
            #expect(cells.compactMap { $0 }.count == YMD.daysInMonth(year: ym.0, month: ym.1))
        }
    }

    @Test("週の始まりで先頭の空きマス数が変わる")
    func leadingBlanks() {
        // 2026年8月1日は土曜
        #expect(CalendarLayout.leadingBlanks(year: 2026, month: 8, weekStart: .sunday) == 6)
        #expect(CalendarLayout.leadingBlanks(year: 2026, month: 8, weekStart: .monday) == 5)
        // 2026年1月1日は木曜
        #expect(CalendarLayout.leadingBlanks(year: 2026, month: 1, weekStart: .sunday) == 4)
        #expect(CalendarLayout.leadingBlanks(year: 2026, month: 1, weekStart: .monday) == 3)
    }

    @Test("曜日の並びが週の始まりに追従する")
    func weekdayOrder() {
        #expect(CalendarLayout.weekdayOrder(weekStart: .sunday) == [0, 1, 2, 3, 4, 5, 6])
        #expect(CalendarLayout.weekdayOrder(weekStart: .monday) == [1, 2, 3, 4, 5, 6, 0])
    }

    @Test("うるう年の2月は29日")
    func leapYear() {
        #expect(YMD.daysInMonth(year: 2028, month: 2) == 29)
        #expect(YMD.daysInMonth(year: 2026, month: 2) == 28)
        #expect(YMD.daysInMonth(year: 2100, month: 2) == 28)  // 100年例外
        #expect(YMD.daysInMonth(year: 2000, month: 2) == 29)  // 400年例外
    }
}

struct YMDTests {

    @Test("文字列と往復する")
    func stringRoundTrip() {
        let d = YMD(2026, 8, 5)
        #expect(d.description == "2026-08-05")
        #expect(YMD("2026-08-05") == d)
        #expect(YMD("2026-8-5") == nil)      // 桁数が違うものは弾く
        #expect(YMD("わからない") == nil)
    }

    @Test("月またぎ・年またぎで日を動かせる")
    func adding() {
        #expect(YMD(2026, 8, 31).adding(days: 1) == YMD(2026, 9, 1))
        #expect(YMD(2026, 1, 1).adding(days: -1) == YMD(2025, 12, 31))
        #expect(YMD(2028, 2, 28).adding(days: 1) == YMD(2028, 2, 29))
    }

    @Test("日数の差を数えられる")
    func daysSince() {
        #expect(YMD(2026, 8, 14).days(since: YMD(2026, 8, 11)) == 3)
        #expect(YMD(2026, 1, 1).days(since: YMD(2025, 12, 31)) == 1)
        #expect(YMD(2026, 8, 11).days(since: YMD(2026, 8, 14)) == -3)
    }

    @Test("並べ替えできる")
    func ordering() {
        let sorted = [YMD(2026, 9, 1), YMD(2025, 12, 31), YMD(2026, 8, 14)].sorted()
        #expect(sorted == [YMD(2025, 12, 31), YMD(2026, 8, 14), YMD(2026, 9, 1)])
    }
}
