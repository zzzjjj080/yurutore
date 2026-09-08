import SwiftUI
import YurutoreCore

/// アプリとウィジェットの両方が使う、色の小道具。
/// **どちらのターゲットからも同じ定義を見る**ようにまとめてある。
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255)
    }

    /// カレンダーのマスの文字。明暗どちらのテーマでも同じ黒。
    static let cellInk = Color(hex: ColorMath.cellInk)
}
