import XCTest

/// ヘルスケアの許可まわりのダイアログを閉じる。
///
/// 面倒なのが3つある。
/// - **出る場所が一定しない。** アプリ内のリモートビューのことも springboard のこともある
/// - **1枚とは限らない。** 入れ直した直後は「あとでヘルスケアアプリで…」のOKが先に重なる
/// - **2回目以降は出ない。** 出ないこと自体は失敗ではない
///
/// なので「押せるものを押し続けて、何も出なくなったら抜ける」形にしてある。
func dismissHealthPrompts(_ app: XCUIApplication, timeout: TimeInterval = 20) {
    let hosts = [app,
                 XCUIApplication(bundleIdentifier: "com.apple.springboard"),
                 XCUIApplication(bundleIdentifier: "com.apple.Health")]
    let labels = ["OK", "許可しない"]
    let deadline = Date().addingTimeInterval(timeout)
    var quiet = 0

    while Date() < deadline && quiet < 4 {
        var tapped = false
        for host in hosts {
            for label in labels {
                let button = host.buttons[label]
                if button.exists && button.isHittable {
                    button.tap()
                    tapped = true
                    usleep(700_000)
                    break
                }
            }
            if tapped { break }
        }
        quiet = tapped ? 0 : quiet + 1
        if !tapped { usleep(500_000) }
    }
}
