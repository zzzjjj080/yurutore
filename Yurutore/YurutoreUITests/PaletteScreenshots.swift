import XCTest

/// 新しい4段階の色を、実際の画面で見るための撮影用。
/// 「ビルドが通った」で終わらせないための確認でもある。
final class PaletteScreenshots: XCTestCase {

    private let outDir = "/tmp/yt-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    }


    func testPalettes() {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        dismissHealthPrompts(app)
        sleep(1)
        save("p01-calendar")

        let gear = app.buttons["gearshape.fill"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        sleep(2)

        // まず4段階のサンプルが見えるところで1枚。
        // 既定の swipeUp は一気に飛ぶので、ゆっくり送って行き過ぎないようにする
        let band = app.staticTexts["〜39"]
        for _ in 0..<10 where !band.exists || !band.isHittable {
            app.swipeUp(velocity: .slow)
            usleep(500_000)
        }
        save("p02-tier-sample")

        // 配色の欄まで送る
        let first = app.buttons["palette-wheat-sky"]
        for _ in 0..<8 where !first.exists || !first.isHittable {
            app.swipeUp()
            usleep(600_000)
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "配色の一覧が出ていない")
        save("p03-palette-list")

        // いくつか選んで、サンプルとカレンダーが変わることを見る
        for id in ["rose-mint", "sky-brick", "indigo-lime"] {
            let chip = app.buttons["palette-\(id)"]
            if chip.exists && chip.isHittable {
                chip.tap()
                sleep(1)
                save("p04-\(id)")
            }
        }
    }
}
