import Foundation
import UIKit
import YurutoreCore

/// ヘルスケアに歩数が入ったとき、アプリが裏で起こされる入口。
///
/// **開かなければ更新されない、を無くすためにある。**
/// 起こされたら歩数を読み直して保存し、その保存がウィジェットへ押し込まれる。
@MainActor
enum BackgroundSteps {
    private static var health: HealthStore?
    private static var working = false

    /// 起動のたびに呼ぶ。2度目以降は何もしない。
    static func start() {
        guard health == nil else { return }
        let h = HealthStore()
        health = h
        h.startWatchingSteps { await handleUpdate() }
    }

    private static func handleUpdate() async {
        // 画面が出ているときは、そちらが読み直している。
        // **同じ保存を2つの入れ物から書くと、後から書いたほうで上書きされる。**
        guard UIApplication.shared.applicationState != .active else { return }
        guard !working, let health else { return }
        working = true
        defer { working = false }

        // 保存から読み直した、この処理だけの入れ物。画面の状態とは混ぜない
        let store = AppStore()
        store.refreshToday()
        await store.syncSteps(using: health)
    }
}
