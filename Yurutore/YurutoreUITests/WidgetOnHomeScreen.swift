import XCTest

/// **ホーム画面にウィジェットを置いて、実際に描き変わるかを見る。**
///
/// ここまでやらないと「共有領域には正しく書けているのに、
/// ウィジェットが古いまま」を見つけられない（引き継ぎ書 4-69）。
final class WidgetOnHomeScreen: XCTestCase {

    private let outDir = "/tmp/yt-shots"
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    }

    /// 押せるようになるまで待ってから押す。springboard は出るのが遅い
    @discardableResult
    private func tapIfPresent(_ labels: [String], timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in labels {
                let b = springboard.buttons[label].firstMatch
                if b.exists && b.isHittable { b.tap(); return true }
                let c = springboard.staticTexts[label].firstMatch
                if c.exists && c.isHittable { c.tap(); return true }
            }
            usleep(400_000)
        }
        return false
    }

    /// ホーム画面のウィジェットが出している「種目数 / 合格ライン」を読む
    private func widgetExerciseText() -> String? {
        let texts = springboard.staticTexts
            .matching(NSPredicate(format: "label ENDSWITH %@", "/2"))
        guard texts.count > 0 else { return nil }
        return texts.element(boundBy: 0).label
    }

    /// ホーム画面の1ページ目（ウィジェットを置いた場所）へ戻す
    private func goToWidgetPage() {
        XCUIDevice.shared.press(.home)
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(2)
        for _ in 0..<3 {
            if widgetExerciseText() != nil { return }
            springboard.swipeRight()
            usleep(800_000)
        }
    }

    /// ウィジェットがまだ無ければホーム画面に置く。
    /// **一度置けば残るので、2回目からは何もしない。**
    @MainActor
    func test1_placeWidgetIfNeeded() {
        goToWidgetPage()
        if widgetExerciseText() != nil { return }   // もう置いてある

        let sb = springboard
        sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            .press(forDuration: 2.0)
        sleep(2)
        tapIfPresent(["編集", "Edit"])
        sleep(1)
        XCTAssertTrue(tapIfPresent(["ウィジェットを追加", "Add Widget"]),
                      "ウィジェットの一覧を開けなかった")
        sleep(3)

        let field = sb.searchFields.firstMatch
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("ゆるトレ")
            sleep(3)
        }
        // 検索結果の行も、下端の追加ボタンも要素として取れないので座標で押す
        if !tapIfPresent(["ゆるトレ日記"], timeout: 3) {
            sb.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.29)).tap()
        }
        sleep(3)
        if !tapIfPresent(["ウィジェットを追加", "Add Widget"], timeout: 3) {
            sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.905)).tap()
        }
        sleep(3)
        tapIfPresent(["完了", "Done"])
        goToWidgetPage()
        save("home-placed")
        XCTAssertNotNil(widgetExerciseText(), "置いたのにウィジェットが読めない")
    }

    /// **アプリで記録を変えたら、ホーム画面のウィジェットも変わること。**
    ///
    /// ここが動いていれば、共有領域の受け渡しと `reloadAllTimelines()` は効いている。
    /// 「なかなか更新されない」の原因を、アプリを開かない間だけに絞り込める。
    @MainActor
    func test2_widgetFollowsTheApp() {
        goToWidgetPage()
        guard let before = widgetExerciseText() else {
            XCTFail("ウィジェットが置かれていない。先に test1 を通すこと")
            return
        }
        save("follow-00-before")

        let app = XCUIApplication()
        app.launchEnvironment["YURUTORE_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        dismissHealthPrompts(app)
        sleep(2)

        let weekday = app.staticTexts["月"].firstMatch
        XCTAssertTrue(weekday.waitForExistence(timeout: 10))
        weekday.tap()
        sleep(2)

        // 休養日にすると種目が0になる。表示が必ず動くので、追いついたか判定できる
        // ボタンで出ることも、文字で出ることもある
        var tapped = false
        for candidate in [app.buttons["休養日"].firstMatch, app.staticTexts["休養日"].firstMatch] {
            if candidate.waitForExistence(timeout: 5), candidate.isHittable {
                candidate.tap(); tapped = true; break
            }
        }
        XCTAssertTrue(tapped, "休養日のボタンを押せなかった")
        sleep(2)

        goToWidgetPage()
        sleep(3)
        save("follow-01-after")

        let after = widgetExerciseText()
        XCTAssertEqual(after, "0/2",
                       "アプリで休養日にしたのに、ウィジェットが追いつかなかった（前: \(before)）")
    }
}
