import Testing
@testable import Yurutore

import YurutoreCore

// ロジックの検証は YurutoreCore 側のテストで行っている。
// ここはアプリ層に固有の確認だけを置く。
struct YurutoreAppTests {
    @Test("アプリの状態を初期化できる")
    func makeStore() {
        let store = AppStore(today: .init(2026, 8, 14))
        #expect(store.viewMode == .month)
        #expect(store.viewMonth == 8)
    }

    @Test("日付を読み直すと、今日が実際の今日になる")
    func refreshToday() {
        let store = AppStore(today: .init(2026, 8, 14))
        store.refreshToday()
        #expect(store.today == AppStore.currentDate())
    }
}
