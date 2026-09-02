import SwiftUI
import YurutoreCore

/// カレンダーの配色。
///
/// **色そのものは `YurutoreCore` の `Palettes` にある。** ここは SwiftUI に橋を架けるだけ。
/// 数値を Core に置いてあるのは、黒文字とのコントラスト比を `swift test` で
/// 実測するため。画面側に置くと測れない。
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255)
    }
}

extension CalendarPalette {
    func color(_ tier: DayTier, dark: Bool) -> Color { Color(hex: fill(tier, dark: dark)) }
    func ink(dark: Bool) -> Color { Color(hex: colors(dark: dark).ink) }
    func onInk(dark: Bool) -> Color { Color(hex: colors(dark: dark).onInk) }
}

extension Color {
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255)
    }

    /// カレンダーのマスの文字。両テーマ共通の黒。
    static let cellInk = Color.rgb(20, 24, 30)

    /// 部位＝琥珀、その他の運動＝青緑。完了ボタンの緑と3系統に分ける。
    static func partFill(_ v: Int, dark: Bool) -> Color {
        switch (v, dark) {
        case (1, false): .rgb(250,223,184); case (1, true): .rgb(90,58,14)
        case (2, false): .rgb(224,138,42);  case (2, true): .rgb(165,112,28)
        default:         dark ? .rgb(240,169,60) : .rgb(194,106,12)
        }
    }
    static func partText(_ v: Int, dark: Bool) -> Color {
        if dark { return v >= 3 ? .rgb(36,20,0) : .white }
        return v == 1 ? .rgb(74,44,5) : .white
    }
    static func actFill(_ v: Int, dark: Bool) -> Color {
        switch (v, dark) {
        case (1, false): .rgb(191,227,230); case (1, true): .rgb(14,74,82)
        case (2, false): .rgb(41,163,174);  case (2, true): .rgb(22,131,143)
        default:         dark ? .rgb(63,201,214) : .rgb(16,128,140)
        }
    }
    static func actText(_ v: Int, dark: Bool) -> Color {
        if dark { return v >= 3 ? .rgb(5,34,38) : .white }
        return v == 1 ? .rgb(6,54,59) : .white
    }
}

