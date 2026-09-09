import XCTest

/// App Store の掲載画像のもとを撮る。
///
/// **6.9インチ（1320×2868）のシミュレータで走らせること。**
/// 手近な端末で撮って引き伸ばすと縦横比がわずかにずれる（引き継ぎ書 4-32）。
final class StoreShots: XCTestCase {

    private let outDir = "/tmp/yt-store-raw"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        for (k, v) in env { app.launchEnvironment[k] = v }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        dismissHealthPrompts(app)
        sleep(1)
        return app
    }

    @MainActor
    func testCaptureAll() {
        // ① 月カレンダー
        var app = launch()
        save("01-month")

        // ② 入力シート。枠の空いているところを押すと今日が開く
        let weekday = app.staticTexts["月"].firstMatch
        XCTAssertTrue(weekday.waitForExistence(timeout: 10))
        weekday.tap()
        sleep(2)
        save("02-input")
        app.terminate()

        // ③ ウィジェット
        app = launch(["YURUTORE_WIDGET_PREVIEW": "store"])
        sleep(1)
        save("03-widget")
        app.terminate()

        // ④ 年表示
        app = launch()
        let title = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "年")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "月の見出しが無い")
        title.tap()
        sleep(2)
        save("04-year")

        // ⑤ 設定の配色
        app.terminate()
        app = launch()
        let gear = app.buttons["gearshape.fill"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        sleep(2)
        let band = app.staticTexts["〜39"]
        for _ in 0..<10 where !band.exists || !band.isHittable {
            app.swipeUp(velocity: .slow)
            usleep(500_000)
        }
        // 4段階の見本だけでなく、選べるパターンも入る位置まで送る
        app.swipeUp(velocity: .slow)
        sleep(1)
        save("05-settings")
    }
}
