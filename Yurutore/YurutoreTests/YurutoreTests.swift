import Testing
@testable import Yurutore

// ロジックの検証は YurutoreCore 側のテストで行っている（49本）。
// ここはアプリ層に固有の確認だけを置く。
struct YurutoreAppTests {
    @Test("アプリの状態を初期化できる")
    func makeStore() {
        let store = AppStore(today: .init(2026, 8, 14))
        #expect(store.viewMode == .month)
        #expect(store.settings.mode == .balanced)
    }
}
