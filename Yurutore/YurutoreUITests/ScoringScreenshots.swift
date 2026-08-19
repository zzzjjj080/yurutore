import XCTest

/// 設定の「点数」タブを実際に開いて絵を撮る。
/// 画面を組み替えたときに、ビルドが通っただけで満足しないための確認用。
final class ScoringScreenshots: XCTestCase {

    private let outDir = "/tmp/yt-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let png = app.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testScoringTab() {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // ヘルスケアの許可ダイアログが出たら閉じる（シミュレータでは歩数が無い）
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["許可しない"]
        if deny.waitForExistence(timeout: 6) { deny.tap() }
        sleep(1)
        save(app, "01-calendar")

        // 歯車 → 点数タブ
        let gear = app.images["gearshape.fill"].firstMatch
        if gear.exists { gear.tap() } else { app.buttons.element(boundBy: 2).tap() }
        sleep(1)
        app.buttons["点数"].firstMatch.tap()
        sleep(1)
        save(app, "02-scoring-top")

        // 表まで送る
        app.swipeUp(); sleep(1); save(app, "03-scoring-mid")
        app.swipeUp(); sleep(1); save(app, "04-matrix")
        app.swipeUp(); sleep(1); save(app, "05-recalc")
    }
}
