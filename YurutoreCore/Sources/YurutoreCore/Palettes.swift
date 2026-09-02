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
/// **どれを選んでも、4段階の並びが一目で分かること**を条件に作ってある。
/// 段階が進むほど彩度が上がり、明度は地から離れる（明るい地では暗く、暗い地では明るく）。
/// 3段階目と4段階目だけは、同じ色相の濃さ違いにして近づけてある。
///
/// 数値は機械で生成し、`PaletteTests` で毎回測り直している。
/// 手で1色だけ差し替えると条件が崩れるので、直すときは生成条件から直すこと。
public enum Palettes {
    /// 1.1 までの既定（うすい黄＋青）に一番近いもの
    public static let defaultID = "sand"

    public static let all: [CalendarPalette] = [
        .init(id: "sky", ja: "空", en: "Sky",
              light: .init(tiers: [0xDEEFFF, 0xB4DCFF, 0x61B9FF, 0x009DF6],
                           ink: 0x0073B7, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x8193A3, 0x7EAFD9, 0x8DCAFF, 0xB4DCFF],
                           ink: 0x80C5FF, onInk: 0x06131E)),
        .init(id: "grass", ja: "草", en: "Grass",
              light: .init(tiers: [0xDDF4E0, 0xAAE9B6, 0x61CB7C, 0x00B453],
                           ink: 0x007F38, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x839787, 0x85B88F, 0x7FDC94, 0x79F699],
                           ink: 0x66DA85, onInk: 0x07150A)),
        .init(id: "grape", ja: "葡萄", en: "Grape",
              light: .init(tiers: [0xF0E9FF, 0xDECDFF, 0xC09AFF, 0xA976F5],
                           ink: 0x8156C0, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x938DA2, 0xB19ED5, 0xCEB4FF, 0xDECDFF],
                           ink: 0xC9ACFF, onInk: 0x140E1D)),
        .init(id: "apricot", ja: "杏", en: "Apricot",
              light: .init(tiers: [0xFFE8D7, 0xFFCBA4, 0xF79643, 0xDD7800],
                           ink: 0xA95A00, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0xA08C7E, 0xD09D77, 0xFFAF70, 0xFFCBA4],
                           ink: 0xFFA65E, onInk: 0x1B0E05)),
        .init(id: "peach", ja: "桃", en: "Peach",
              light: .init(tiers: [0xFFE5EE, 0xFFC3D9, 0xFA86B6, 0xE85B9C],
                           ink: 0xB54076, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0xA28992, 0xD294AC, 0xFFA3C7, 0xFFC3D9],
                           ink: 0xFF99C2, onInk: 0x1C0C12)),
        .init(id: "lagoon", ja: "碧", en: "Lagoon",
              light: .init(tiers: [0xD2F5F3, 0x86EBE7, 0x00CBC6, 0x00ACA8],
                           ink: 0x007B78, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x7B9796, 0x68BAB6, 0x27DFDA, 0x00F6F0],
                           ink: 0x00D9D4, onInk: 0x011615)),
        .init(id: "wheat", ja: "麦", en: "Wheat",
              light: .init(tiers: [0xF4EDD2, 0xEAD78E, 0xCFAF1D, 0xB19400],
                           ink: 0x826C00, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x97917B, 0xB9A96E, 0xDFC251, 0xFAD42F],
                           ink: 0xDEBB19, onInk: 0x161103)),
        .init(id: "brick", ja: "煉瓦", en: "Brick",
              light: .init(tiers: [0xFFE6E4, 0xFFC7C1, 0xFF8A82, 0xF25D59],
                           ink: 0xBD413F, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0xA48A87, 0xD79690, 0xFFA9A2, 0xFFC7C1],
                           ink: 0xFFA098, onInk: 0x1D0C0B)),
        .init(id: "stone", ja: "石", en: "Stone",
              light: .init(tiers: [0xEEF2F7, 0xC3CDD8, 0x9AAABA, 0x7C8EA2],
                           ink: 0x666F7A, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x898C90, 0xA0A9B2, 0xB7C6D5, 0xCFE2F6],
                           ink: 0xB4BFCA, onInk: 0x07121E)),
        .init(id: "leaf", ja: "若葉", en: "Leaf",
              light: .init(tiers: [0xF2EED3, 0xE5D98F, 0x61CB7C, 0x00B453],
                           ink: 0x007F38, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x95917B, 0xB5AB6F, 0x7FDC94, 0x79F699],
                           ink: 0x66DA85, onInk: 0x07150A)),
        .init(id: "water", ja: "水と青", en: "Water & Blue",
              light: .init(tiers: [0xD2F4F8, 0x85E9F5, 0x86B1FF, 0x5891FF],
                           ink: 0x396BCB, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x7B979A, 0x68B8C1, 0xA3C4FF, 0xC2D8FF],
                           ink: 0x9ABEFF, onInk: 0x0A111F)),
        .init(id: "rose", ja: "薔薇と菫", en: "Rose & Violet",
              light: .init(tiers: [0xFFE5EF, 0xFFC3DC, 0xC399FF, 0xAC74F3],
                           ink: 0x8455BE, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0xA18993, 0xD195AE, 0xD1B3FF, 0xDFCCFF],
                           ink: 0xCCABFF, onInk: 0x140E1D)),
        .init(id: "sunfire", ja: "陽と炎", en: "Sun & Fire",
              light: .init(tiers: [0xFDE9D4, 0xFFCC92, 0xFF8A82, 0xF25D59],
                           ink: 0xBD413F, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x9E8E7C, 0xCAA171, 0xFFA9A2, 0xFFC7C1],
                           ink: 0xFFA098, onInk: 0x1D0C0B)),
        .init(id: "mint", ja: "薄荷と碧", en: "Mint & Teal",
              light: .init(tiers: [0xE0F3DD, 0xB3E7AD, 0x00CACF, 0x00ABAF],
                           ink: 0x007A7D, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x869684, 0x8DB688, 0x21DEE3, 0x00F4FA],
                           ink: 0x00D8DD, onInk: 0x001616)),
        .init(id: "corn", ja: "粟と琥珀", en: "Corn & Amber",
              light: .init(tiers: [0xF1EED3, 0xE3DA8F, 0xFC9252, 0xE96D00],
                           ink: 0xB25200, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x94927C, 0xB3AC70, 0xFFAD7F, 0xFFCAAD],
                           ink: 0xFFA571, onInk: 0x1C0D06)),
        .init(id: "lilac", ja: "藤と藍", en: "Lilac & Indigo",
              light: .init(tiers: [0xF4E7FF, 0xE7C9FF, 0x90AEFF, 0x688DFF],
                           ink: 0x4867CC, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x978CA0, 0xB99CCF, 0xAAC2FF, 0xC6D6FF],
                           ink: 0xA2BCFF, onInk: 0x0C111F)),
        .init(id: "sand", ja: "砂と空", en: "Sand & Sky",
              light: .init(tiers: [0xFCEAD3, 0xFECD90, 0x64B8FF, 0x009CF8],
                           ink: 0x0073B9, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x9D8E7C, 0xC9A170, 0x8ECAFF, 0xB5DCFF],
                           ink: 0x82C5FF, onInk: 0x06131E)),
        .init(id: "blossom", ja: "花と葉", en: "Blossom & Leaf",
              light: .init(tiers: [0xFFE4F0, 0xFFC3DE, 0x5BCC80, 0x00B35B],
                           ink: 0x00803F, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0xA18993, 0xD195B0, 0x7ADC98, 0x73F69E],
                           ink: 0x60DB89, onInk: 0x07150B)),
        .init(id: "straw", ja: "藁と葡萄", en: "Straw & Grape",
              light: .init(tiers: [0xF3EED3, 0xE7D88E, 0xBC9CFF, 0xA577F7],
                           ink: 0x7E57C1, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x96917B, 0xB6AA6F, 0xCBB5FF, 0xDCCEFF],
                           ink: 0xC7ADFF, onInk: 0x130F1D)),
    ]

    public static func named(_ id: String?) -> CalendarPalette {
        if let id, let hit = all.first(where: { $0.id == id }) { return hit }
        return all.first { $0.id == defaultID } ?? all[0]
    }

    /// 1.1 までは「80点未満の色」と「80点以上の色」を別々に選ばせていた。
    /// その2つから、いちばん近いパターンへ移す。
    public static func migrating(fail: String?, pass: String?) -> String {
        let p = pass ?? "blue"
        if fail == p {
            switch p {
            case "yellow": return "wheat"
            case "blue":   return "sky"
            case "green":  return "grass"
            case "orange": return "apricot"
            case "purple": return "grape"
            default:       return defaultID
            }
        }
        switch p {
        case "blue":   return "sand"
        case "green":  return "leaf"
        case "purple": return "straw"
        case "orange": return "corn"
        case "yellow": return "wheat"
        default:       return defaultID
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
