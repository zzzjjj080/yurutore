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

    private func dismissHealthPrompt(_ app: XCUIApplication) {
        let hosts = [app,
                     XCUIApplication(bundleIdentifier: "com.apple.springboard"),
                     XCUIApplication(bundleIdentifier: "com.apple.Health")]
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            for host in hosts {
                let deny = host.buttons["許可しない"]
                if deny.exists && deny.isHittable { deny.tap(); return }
            }
            usleep(500_000)
        }
    }

    func testPalettes() {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        dismissHealthPrompt(app)
        sleep(1)
        save("p01-calendar")

        let gear = app.buttons["gearshape.fill"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        sleep(2)

        // 配色の欄まで送る
        let sky = app.buttons["palette-sky"]
        for _ in 0..<8 where !sky.exists || !sky.isHittable {
            app.swipeUp()
            usleep(600_000)
        }
        XCTAssertTrue(sky.waitForExistence(timeout: 5), "配色の一覧が出ていない")
        save("p02-palette-list")

        // いくつか選んで、サンプルとカレンダーが変わることを見る
        for id in ["grass", "grape", "stone"] {
            let chip = app.buttons["palette-\(id)"]
            if chip.exists && chip.isHittable {
                chip.tap()
                sleep(1)
                save("p03-\(id)")
            }
        }
    }
}
