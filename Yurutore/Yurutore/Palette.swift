import SwiftUI

/// カレンダーの配色。
///
/// マスの文字は合否にかかわらず黒で統一するので、塗りは「黒文字が読める明度」
/// だけで組んである。明度で合否を分けられないぶん、色相の差で分ける。
/// ライト/ダークどちらでも黒文字とのコントラスト比 4.5:1 以上を確保している。
enum PaletteKind: String, CaseIterable, Codable, Identifiable {
    case yellow, blue, green, orange, purple
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .yellow: "色・黄"; case .blue: "色・青"; case .green: "色・緑"
        case .orange: "色・橙"; case .purple: "色・紫"
        }
    }

    struct Ramp {
        let lo: Color, hi: Color
        /// 文字やタブに使う色（カードの上に乗るので明度が別に要る）
        let ink: Color
        /// ink の上に乗る文字
        let onInk: Color
    }

    func ramp(dark: Bool) -> Ramp {
        switch (self, dark) {
        case (.yellow, false): .init(lo: .rgb(249,243,224), hi: .rgb(240,201,74),
                                     ink: .rgb(176,120,10), onInk: .white)
        case (.yellow, true):  .init(lo: .rgb(138,129,99),  hi: .rgb(224,192,74),
                                     ink: .rgb(234,190,70), onInk: .rgb(36,26,0))
        case (.blue, false):   .init(lo: .rgb(223,233,251), hi: .rgb(109,164,240),
                                     ink: .rgb(37,99,235),  onInk: .white)
        case (.blue, true):    .init(lo: .rgb(129,149,180), hi: .rgb(109,164,240),
                                     ink: .rgb(91,155,245), onInk: .rgb(7,20,38))
        case (.green, false):  .init(lo: .rgb(223,240,231), hi: .rgb(87,195,151),
                                     ink: .rgb(13,138,90),  onInk: .white)
        case (.green, true):   .init(lo: .rgb(125,153,140), hi: .rgb(87,195,151),
                                     ink: .rgb(52,196,146), onInk: .rgb(4,21,14))
        case (.orange, false): .init(lo: .rgb(251,233,220), hi: .rgb(240,160,92),
                                     ink: .rgb(193,92,14),  onInk: .white)
        case (.orange, true):  .init(lo: .rgb(160,135,112), hi: .rgb(240,160,92),
                                     ink: .rgb(240,150,80), onInk: .rgb(35,16,0))
        case (.purple, false): .init(lo: .rgb(236,230,250), hi: .rgb(171,140,232),
                                     ink: .rgb(105,55,208), onInk: .white)
        case (.purple, true):  .init(lo: .rgb(138,131,168), hi: .rgb(171,140,232),
                                     ink: .rgb(160,124,240), onInk: .rgb(21,4,41))
        }
    }
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

/// 混色。点数から塗りの色を作るのに使う。
func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let ac = UIColor(a).cgColor.components ?? [0,0,0,1]
    let bc = UIColor(b).cgColor.components ?? [0,0,0,1]
    let k = min(1, max(0, t))
    return Color(.sRGB,
                 red:   ac[0] + (bc[0] - ac[0]) * k,
                 green: ac[1] + (bc[1] - ac[1]) * k,
                 blue:  ac[2] + (bc[2] - ac[2]) * k)
}
