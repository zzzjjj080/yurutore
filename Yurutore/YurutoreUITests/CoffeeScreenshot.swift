import XCTest

/// App内課金の「審査用スクリーンショット」を撮る。
///
/// 設定はシートなので、合成タップでは開けない（引き継ぎ書 4-24）。
/// 価格を出すには `.storekit` が要るが、それはスキーム経由でしか効かない（11-9）。
/// つまりこの絵は **`xcodebuild test` からしか撮れない。**
final class CoffeeScreenshot: XCTestCase {

    private let outDir = "/tmp/yt-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }



    func testCoffeeSection() {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        dismissHealthPrompts(app)
        sleep(1)

        // 歯車 → 設定
        let gear = app.buttons["gearshape.fill"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "歯車が見つからない")
        gear.tap()
        sleep(2)

        // 「データ」タブがいちばん短いので、投げ銭が画面に大きく収まる。
        // 配色の一覧が主役に見える絵にしない。
        let dataTab = app.buttons["データ"].firstMatch
        if dataTab.waitForExistence(timeout: 5) { dataTab.tap(); sleep(1) }

        // いちばん下まで送る。買うボタンが画面に入るまで。
        let buy = app.buttons["buyCoffee"]
        for _ in 0..<8 where !buy.exists || !buy.isHittable {
            app.swipeUp()
            usleep(600_000)
        }
        XCTAssertTrue(buy.waitForExistence(timeout: 5), "コーヒーのボタンが出ていない")

        // 価格が入るのを待つ。読み込み中は ProgressView のまま。
        sleep(3)

        // 画面そのものを撮る（app.screenshot() はアプリの窓だけ／4-32）
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/iap-review.png"))

        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "iap-review"
        a.lifetime = .keepAlways
        add(a)
    }
}
