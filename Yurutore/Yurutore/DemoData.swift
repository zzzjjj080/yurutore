import Foundation
import YurutoreCore

// ストア用スクリーンショットを撮るためだけの仕込み。
// #if DEBUG で囲ってあるので、リリースビルドには一切入らない。
// 本当に入っていないかは strings で確認すること（引き継ぎ書4-5）。
#if DEBUG
enum DemoData {
    /// 環境変数 YURUTORE_DEMO=1 のときだけ、それらしい記録を入れる
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YURUTORE_DEMO"] == "1"
    }

    static func fill(_ store: AppStore) {
        guard isEnabled else { return }
        var j = Journal()
        let today = store.today
        // 直近70日ぶん。歩数と運動を、それらしくばらつかせる。
        let steps = [11200, 6400, 9800, 13100, 7300, 15600, 8200, 5100, 10400, 12800]
        let parts: [[BodyPart: Volume]] = [
            [.chest: .two, .arm: .one], [:], [.back: .three], [:], [.leg: .two],
            [.chest: .one, .shoulder: .two], [.core: .two], [:], [.back: .one, .arm: .two], [:]
        ]
        let acts: [[String: Volume]] = [
            [:], ["radio": .one], [:], ["stretch": .two], [:],
            [:], ["swim": .two], ["radio": .one, "stretch": .one], [:], ["bike": .one]
        ]
        for i in 0..<70 {
            let d = today.adding(days: -i)
            var log = DayLog(steps: steps[i % steps.count] + (i * 137) % 2600 - 1300)
            if i % 11 == 4 { log.setRest(true) }        // ときどき休養日
            else if i % 9 != 7 {                         // ときどき未入力を残す
                log.parts = parts[i % parts.count]
                log.activities = acts[i % acts.count]
            }
            j[d] = log
        }
        store.journal = j
        store.healthAuthorized = true
        store.journal.settleAll(today: today,
                                activities: store.activities, settings: store.settings)
    }
}
#endif
