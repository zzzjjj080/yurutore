import XCTest

/// カレンダーの枠の中は、マス以外を押しても今日が開く。
///
/// 今日のマスを狙って押すのは、**毎日やる操作としては細かすぎる。**
/// ただし、他の日を開く経路を壊していないことも一緒に確かめる。
final class TapAnywhereTests: XCTestCase {

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

    /// 今日の日付。デモデータは端末の今日を基準に作られる
    private var todayID: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    @MainActor
    func testEmptySpaceOpensToday() {
        let app = launch()
        // 曜日の見出しはマスではない。ここを押しても今日が開くこと
        let weekday = app.staticTexts["月"].firstMatch
        XCTAssertTrue(weekday.waitForExistence(timeout: 10), "曜日の見出しが無い")
        weekday.tap()

        let editor = app.staticTexts["dayEditor-\(todayID)"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5),
                      "空いているところを押しても今日が開かなかった")
    }

    /// 「どこでも今日」を入れたせいで、他の日を開けなくなっていないこと
    @MainActor
    func testTappingADayStillOpensThatDay() {
        let app = launch()
        // 1日のマス。デモデータで記録が入っている
        let first = app.staticTexts["1"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "1日のマスが無い")
        first.tap()

        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        let firstID = String(format: "%04d-%02d-01", c.year!, c.month!)
        XCTAssertTrue(app.staticTexts["dayEditor-\(firstID)"].waitForExistence(timeout: 5),
                      "1日を押したのに、その日が開かなかった")
    }
}
