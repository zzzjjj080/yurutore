import XCTest

/// 入力シートの見た目を撮る。**毎日いちばん多く開く画面**なので、
/// 送らずに済んでいるか、並び順が意図どおりかを目で確かめる。
final class EditorShot: XCTestCase {

    private let outDir = "/tmp/yt-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    @MainActor
    func testEditorLayout() {
        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        dismissHealthPrompts(app)
        sleep(1)

        // 枠の空いているところを押すと今日が開く
        let weekday = app.staticTexts["月"].firstMatch
        XCTAssertTrue(weekday.waitForExistence(timeout: 10))
        weekday.tap()
        sleep(2)

        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/editor-01.png"))

        // 送らないと「完了」に届かないなら、そのぶん毎日の手間になる
        let done = app.buttons["完了"].firstMatch
        if done.exists {
            try? "完了は最初から見えている: \(done.isHittable)"
                .write(to: URL(fileURLWithPath: "\(outDir)/editor-done.txt"),
                       atomically: true, encoding: .utf8)
        }

        app.swipeUp(velocity: .slow)
        sleep(1)
        let png2 = XCUIScreen.main.screenshot().pngRepresentation
        try? png2.write(to: URL(fileURLWithPath: "\(outDir)/editor-02.png"))
    }
}
