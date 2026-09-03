import Foundation

/// カレンダーのマスの色を決める4段階。
///
/// **濃淡の連続ではなく、この4色しか使わない。** 点数の帯で分ける。
/// 境目は採点の決まりから来ている（40点＝片方の合格ライン、80点＝合格）。
public enum DayTier: Int, Codable, Sendable, CaseIterable, Comparable {
    /// 40点未満
    case low = 1
    /// 40〜79点
    case mid = 2
    /// 80〜99点（＝合格）
    case pass = 3
    /// 100点
    case full = 4

    // `none` にすると Optional の `.none` と紛れるので、この名前にしてある

    public static func < (a: DayTier, b: DayTier) -> Bool { a.rawValue < b.rawValue }
}

/// 色は `0xRRGGBB`。**Coreは画面に依存しないので、SwiftUIのColorは持たない。**
/// こうしておくと、コントラスト比を `swift test` で実測できる。
public struct PaletteColors: Sendable, Hashable {
    /// 4段階の塗り（未達成 → 100点）
    public let tiers: [UInt32]
    /// 文字やボタンに使う色
    public let ink: UInt32
    /// `ink` の上に乗る文字
    public let onInk: UInt32

    public init(tiers: [UInt32], ink: UInt32, onInk: UInt32) {
        self.tiers = tiers
        self.ink = ink
        self.onInk = onInk
    }
}

public struct CalendarPalette: Identifiable, Sendable, Hashable {
    public let id: String
    public let ja: String
    public let en: String
    public let light: PaletteColors
    public let dark: PaletteColors

    public init(id: String, ja: String, en: String, light: PaletteColors, dark: PaletteColors) {
        self.id = id
        self.ja = ja
        self.en = en
        self.light = light
        self.dark = dark
    }

    public func colors(dark: Bool) -> PaletteColors { dark ? self.dark : light }
    public func fill(_ tier: DayTier, dark: Bool) -> UInt32 {
        colors(dark: dark).tiers[tier.rawValue - 1]
    }
    public func name(japanese: Bool) -> String { japanese ? ja : en }
}

/// 配色のパターン。
///
/// **どれを選んでも、次の3つが成り立つように作ってある。**
///
/// - 1段階目（39点まで）は無彩色。まだ何も越えていない日を、色で語らせない
/// - **80点の境目でだけ色相が変わる。** 合否がいちばん見分けたいところなので、
///   隣り合うどの段差よりも大きく離してある
/// - 3段階目と4段階目は同じ色相の濃さ違い。合格した日どうしは近くてよい
///
/// 単色の濃淡だけで4段階を作るパターンは置いていない。合否の境目が読めないため。
///
/// 数値は機械で生成し、`PaletteTests` で毎回測り直している。
/// 手で1色だけ差し替えると条件が崩れるので、直すときは生成条件から直すこと。
public enum Palettes {
    /// 1.1 までの既定（うすい黄＋青）に一番近いもの
    public static let defaultID = "wheat-sky"

    public static let all: [CalendarPalette] = [
        .init(id: "apricot-indigo", ja: "杏と藍", en: "Apricot & Indigo",
              light: .init(tiers: [0xD8DDE3, 0xFFBC85, 0x7997FF, 0x5B79FE],
                           ink: 0x4D66CC, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xC38C5F, 0xB6C9FF, 0xD1DDFF],
                           ink: 0xA4BBFF, onInk: 0x0C111F)),
        .init(id: "apricot-mint", ja: "杏と薄荷", en: "Apricot & Mint",
              light: .init(tiers: [0xD8DDE3, 0xFFBA9B, 0x00B5B5, 0x009B9C],
                           ink: 0x007C7D, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xC9886B, 0x00E7E7, 0x00FDFD],
                           ink: 0x00D8D9, onInk: 0x001616)),
        .init(id: "brick-sky", ja: "煉瓦と空", en: "Brick & Sky",
              light: .init(tiers: [0xD8DDE3, 0xFFB8AB, 0x00A9F7, 0x0091D5],
                           ink: 0x0074AB, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xCB8579, 0x94D3FF, 0xBEE4FF],
                           ink: 0x76C7FF, onInk: 0x05131D)),
        .init(id: "grape-grass", ja: "葡萄と草", en: "Grape & Grass",
              light: .init(tiers: [0xD8DDE3, 0xD5BFFF, 0x37BB62, 0x00A34A],
                           ink: 0x007F38, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xA28DCA, 0x78E693, 0x77FF9B],
                           ink: 0x66DA85, onInk: 0x07150A)),
        .init(id: "grape-wheat", ja: "葡萄と麦", en: "Grape & Wheat",
              light: .init(tiers: [0xD8DDE3, 0xC6C5FF, 0xD38F00, 0xB57A00],
                           ink: 0x966400, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x9492D0, 0xFFBD58, 0xFFD7A0],
                           ink: 0xF9AD26, onInk: 0x190F03)),
        .init(id: "grass-magenta", ja: "草と紅", en: "Grass & Magenta",
              light: .init(tiers: [0xD8DDE3, 0x82E3BA, 0xC57AE6, 0xB55ADA],
                           ink: 0x944FB0, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x60AC8C, 0xE7B3FF, 0xF0D0FF],
                           ink: 0xE29FFF, onInk: 0x170D1B)),
        .init(id: "grass-rose", ja: "草と薔薇", en: "Grass & Rose",
              light: .init(tiers: [0xD8DDE3, 0x97E1A6, 0xEF6A9A, 0xE54786],
                           ink: 0xB73F6E, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x70AA7C, 0xFFB1C8, 0xFFCFDC],
                           ink: 0xFF9BBA, onInk: 0x1C0C11)),
        .init(id: "indigo-apricot", ja: "藍と杏", en: "Indigo & Apricot",
              light: .init(tiers: [0xD8DDE3, 0xAACFFF, 0xF27636, 0xDB5A00],
                           ink: 0xB94B00, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x749CD1, 0xFFB797, 0xFFD3C0],
                           ink: 0xFFA47A, onInk: 0x1C0D06)),
        .init(id: "indigo-lime", ja: "藍と若葉", en: "Indigo & Lime",
              light: .init(tiers: [0xD8DDE3, 0xB8CAFF, 0x92AC00, 0x7D9400],
                           ink: 0x637600, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x8497D2, 0xBED95A, 0xCFEF4D],
                           ink: 0xB1CC46, onInk: 0x101305)),
        .init(id: "lime-grape", ja: "若葉と葡萄", en: "Lime & Grape",
              light: .init(tiers: [0xD8DDE3, 0xADDD93, 0x968CFF, 0x806EF9],
                           ink: 0x6B5FCA, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x82A76E, 0xC4C4FF, 0xDADAFF],
                           ink: 0xB6B4FF, onInk: 0x10101E)),
        .init(id: "lime-indigo", ja: "若葉と藍", en: "Lime & Indigo",
              light: .init(tiers: [0xD8DDE3, 0xD7D079, 0x53A0FF, 0x1085FC],
                           ink: 0x1E6FCA, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xA29D59, 0xA7CEFF, 0xC9E0FF],
                           ink: 0x91C1FF, onInk: 0x08121F)),
        .init(id: "lime-magenta", ja: "若葉と紅", en: "Lime & Magenta",
              light: .init(tiers: [0xD8DDE3, 0xC3D784, 0xD773D0, 0xC951C2],
                           ink: 0xA3489D, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x92A261, 0xFFA7F7, 0xFFCAF9],
                           ink: 0xF695EE, onInk: 0x190D18)),
        .init(id: "magenta-lime", ja: "紅と若葉", en: "Magenta & Lime",
              light: .init(tiers: [0xD8DDE3, 0xE7B6FE, 0xADA200, 0x948B00],
                           ink: 0x787100, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xAF89C0, 0xDACF44, 0xF1E323],
                           ink: 0xCEC228, onInk: 0x141203)),
        .init(id: "mint-brick", ja: "薄荷と煉瓦", en: "Mint & Brick",
              light: .init(tiers: [0xD8DDE3, 0x70E4CF, 0xF66E5C, 0xE94937],
                           ink: 0xBD4334, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x52AC9C, 0xFFB5A8, 0xFFD2CA],
                           ink: 0xFFA191, onInk: 0x1D0C0A)),
        .init(id: "mint-peach", ja: "薄荷と桃", en: "Mint & Peach",
              light: .init(tiers: [0xD8DDE3, 0x67E3E2, 0xE66DB6, 0xD84AA5],
                           ink: 0xAF4387, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x4BABAB, 0xFFADDB, 0xFFCDE8],
                           ink: 0xFF96D3, onInk: 0x1B0C15)),
        .init(id: "rose-grass", ja: "薔薇と草", en: "Rose & Grass",
              light: .init(tiers: [0xD8DDE3, 0xFFB3CA, 0x37BB62, 0x00A34A],
                           ink: 0x007F38, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xC88297, 0x78E693, 0x77FF9B],
                           ink: 0x66DA85, onInk: 0x07150A)),
        .init(id: "rose-mint", ja: "薔薇と薄荷", en: "Rose & Mint",
              light: .init(tiers: [0xD8DDE3, 0xFFB3CA, 0x00B8A1, 0x009E8A],
                           ink: 0x007C6D, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xC88297, 0x00EACE, 0x33FFE2],
                           ink: 0x00DCC1, onInk: 0x011612)),
        .init(id: "rose-water", ja: "薔薇と水", en: "Rose & Water",
              light: .init(tiers: [0xD8DDE3, 0xFFB3CA, 0x00B2C8, 0x0099AC],
                           ink: 0x007A8A, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xC88297, 0x00E3FF, 0x93EFFF],
                           ink: 0x00D5EF, onInk: 0x011519)),
        .init(id: "sky-brick", ja: "空と煉瓦", en: "Sky & Brick",
              light: .init(tiers: [0xD8DDE3, 0x7BDBFF, 0xF56B7C, 0xE84461],
                           ink: 0xBC3F53, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x55A6C4, 0xFFB3B8, 0xFFD1D3],
                           ink: 0xFF9EA6, onInk: 0x1D0C0D)),
        .init(id: "sky-wheat", ja: "空と麦", en: "Sky & Wheat",
              light: .init(tiers: [0xD8DDE3, 0x98D4FF, 0xC19900, 0xA68300],
                           ink: 0x876A00, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x63A1CC, 0xF2C53A, 0xFFDA74],
                           ink: 0xE6B816, onInk: 0x171103)),
        .init(id: "water-apricot", ja: "水と杏", en: "Water & Apricot",
              light: .init(tiers: [0xD8DDE3, 0x69E0F4, 0xE68100, 0xC66E00],
                           ink: 0xA75C00, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x4CA9B9, 0xFFBA81, 0xFFD5B3],
                           ink: 0xFFA658, onInk: 0x1B0E04)),
        .init(id: "wheat-grape", ja: "麦と葡萄", en: "Wheat & Grape",
              light: .init(tiers: [0xD8DDE3, 0xE8C975, 0xB082F7, 0x9E64EE],
                           ink: 0x8156C0, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xAF9756, 0xD4BDFF, 0xE3D6FF],
                           ink: 0xC9ACFF, onInk: 0x140E1D)),
        .init(id: "wheat-sky", ja: "麦と空", en: "Wheat & Sky",
              light: .init(tiers: [0xD8DDE3, 0xF6C278, 0x00AFDC, 0x0096BD],
                           ink: 0x007898, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xBB9258, 0x76D9FF, 0xB0E8FF],
                           ink: 0x3ECFFF, onInk: 0x02141B)),
    ]

    public static func named(_ id: String?) -> CalendarPalette {
        if let id, let hit = all.first(where: { $0.id == id }) { return hit }
        return all.first { $0.id == defaultID } ?? all[0]
    }

    /// 1.1 までは「80点未満の色」と「80点以上の色」を別々に選ばせていた。
    /// **80点以上に選んでいた色を引き継ぐ。** そこが合否の境目なので、
    /// 印象がいちばん変わらない。
    public static func migrating(fail: String?, pass: String?) -> String {
        switch pass {
        case "green":  return "rose-grass"
        case "purple": return "wheat-grape"
        case "orange": return "indigo-apricot"
        case "yellow": return "sky-wheat"
        default:       return defaultID          // 青、および記録が無いとき
        }
    }
}

/// 色の測り方。**「明るく見えるか」ではなく輝度で決める。**
/// 黄と青は明度が同じでも輝度がまるで違うので、目分量だと必ず外す。
public enum ColorMath {
    /// マスの文字。明暗どちらのテーマでも同じ黒を使う。
    public static let cellInk: UInt32 = 0x14181E

    public static func rgb(_ hex: UInt32) -> (Double, Double, Double) {
        (Double((hex >> 16) & 0xFF) / 255,
         Double((hex >> 8) & 0xFF) / 255,
         Double(hex & 0xFF) / 255)
    }

    /// WCAG の相対輝度
    public static func relativeLuminance(_ hex: UInt32) -> Double {
        func f(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = rgb(hex)
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
    }

    /// コントラスト比。文字が読めるかの判定は 4.5:1（WCAG AA）で見る。
    public static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = relativeLuminance(a), y = relativeLuminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// 見た目の差。コントラスト比は明度の差しか見ないので、
    /// 「色が違うこと」を測るにはこちらが要る。
    public static func difference(_ a: UInt32, _ b: UInt32) -> Double {
        let x = oklab(a), y = oklab(b)
        return sqrt(pow(x.0 - y.0, 2) + pow(x.1 - y.1, 2) + pow(x.2 - y.2, 2))
    }

    /// 鮮やかさ。無彩色なら 0 に近い。
    public static func chroma(_ hex: UInt32) -> Double {
        let (_, a, b) = oklab(hex)
        return sqrt(a * a + b * b)
    }

    /// 色相（度）。彩度がほぼ無いときは意味を持たないので、呼ぶ前に確かめること。
    public static func hue(_ hex: UInt32) -> Double {
        let (_, a, b) = oklab(hex)
        return atan2(b, a) * 180 / .pi
    }

    /// 色相の隔たり（0〜180度）
    public static func hueGap(_ x: UInt32, _ y: UInt32) -> Double {
        let d = abs(hue(x) - hue(y)).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    public static func oklab(_ hex: UInt32) -> (Double, Double, Double) {
        func f(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let (r0, g0, b0) = rgb(hex)
        let r = f(r0), g = f(g0), b = f(b0)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }
}
