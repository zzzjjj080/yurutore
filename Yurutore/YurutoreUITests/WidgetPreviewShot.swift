import XCTest

/// ウィジェットの見た目を撮る。
///
/// **拡張は単体で起動できない**ので、同じ View をアプリ側の
/// DEBUG限定の入口から組み立てて撮る（配布版には入らない）。
final class WidgetPreviewShot: XCTestCase {

    private let outDir = "/tmp/yt-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    func testWidgetLooks() {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_WIDGET_PREVIEW"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.otherElements["widgetPreview"].waitForExistence(timeout: 10)
                      || app.staticTexts["あと少し"].waitForExistence(timeout: 10),
                      "ウィジェットの下書き画面が出ていない")
        sleep(1)

        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/widget-01.png"))

        // 下のほうの見本も撮る
        app.swipeUp(velocity: .slow)
        sleep(1)
        let png2 = XCUIScreen.main.screenshot().pngRepresentation
        try? png2.write(to: URL(fileURLWithPath: "\(outDir)/widget-02.png"))
    }
}
