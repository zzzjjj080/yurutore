import UIKit

/// 押した感触があるだけで入力が気持ちよくなる。
/// シミュレータでは鳴らないので、確認は実機で行う。
enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    /// 合格ラインを跨いだ瞬間だけこれを使う
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
