import XCTest

/// カレンダーの下の「最近30日」。
///
/// 数字が**窓の中の記録そのもの**であることを確かめる。
/// 集計の窓を月から30日に変えたので、記録を足したら帯が伸びる、という
/// 当たり前の線が切れていないかをここで押さえる。
final class RecentStatsTests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        dismissHealthPrompts(app)
        sleep(1)
        return app
    }

    /// 「胸 7」のように、部位と数がひとつのラベルになっている
    private func partLabel(_ app: XCUIApplication, _ part: String) -> String? {
        let p = NSPredicate(format: "label BEGINSWITH %@", "\(part) ")
        let e = app.descendants(matching: .any).matching(p).firstMatch
        guard e.waitForExistence(timeout: 10) else { return nil }
        return e.label
    }

    private func count(_ label: String?) -> Int? {
        guard let n = label?.split(separator: " ").last else { return nil }
        return Int(n)
    }

    @MainActor
    func testStripShowsSixParts() {
        let app = launch()
        XCTAssertTrue(app.otherElements["recentParts"].waitForExistence(timeout: 10),
                      "最近30日の部位の帯が出ていない")
        for part in ["胸", "背", "肩", "腕", "足", "腹"] {
            XCTAssertNotNil(count(partLabel(app, part)), "\(part)の数が読めない")
        }
    }

    /// 今日の記録を足したら、帯の数もその場で増える。
    /// **今日は平均には入れないが、部位には入れる**という決まりの確認でもある。
    @MainActor
    func testTodaysExerciseCountsInTheStrip() {
        let app = launch()
        guard let before = count(partLabel(app, "肩")) else {
            return XCTFail("肩の数が読めない")
        }

        // 曜日の見出しを押すと今日が開く
        app.staticTexts["月"].firstMatch.tap()
        let shoulder = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "肩 ")).firstMatch
        XCTAssertTrue(shoulder.waitForExistence(timeout: 5), "入力シートに肩のボタンが無い")
        shoulder.tap()
        app.buttons["完了"].firstMatch.tap()

        // 閉じたあとの帯
        let after = count(partLabel(app, "肩"))
        XCTAssertEqual(after, before + 1, "今日の運動が最近30日の帯に入っていない")
    }
}
