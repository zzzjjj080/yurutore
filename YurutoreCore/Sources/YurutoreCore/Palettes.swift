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
        .init(id: "wheat-sky", ja: "麦と空", en: "Wheat & Sky",
              light: .init(tiers: [0xD8DDE3, 0xF6C278, 0x00AFDC, 0x0096BD],
                           ink: 0x007898, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xBB9258, 0x76D9FF, 0xB0E8FF],
                           ink: 0x3ECFFF, onInk: 0x02141B)),
        .init(id: "rose-grass", ja: "薔薇と草", en: "Rose & Grass",
              light: .init(tiers: [0xD8DDE3, 0xFFB3CA, 0x37BB62, 0x00A34A],
                           ink: 0x007F38, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0xC88297, 0x78E693, 0x77FF9B],
                           ink: 0x66DA85, onInk: 0x07150A)),
        .init(id: "sky-brick", ja: "空と煉瓦", en: "Sky & Brick",
              light: .init(tiers: [0xD8DDE3, 0x7BDBFF, 0xF56B7C, 0xE84461],
                           ink: 0xBC3F53, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x55A6C4, 0xFFB3B8, 0xFFD1D3],
                           ink: 0xFF9EA6, onInk: 0x1D0C0D)),
        .init(id: "mint-peach", ja: "薄荷と桃", en: "Mint & Peach",
              light: .init(tiers: [0xD8DDE3, 0x67E3E2, 0xE66DB6, 0xD84AA5],
                           ink: 0xAF4387, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x4BABAB, 0xFFADDB, 0xFFCDE8],
                           ink: 0xFF96D3, onInk: 0x1B0C15)),
        .init(id: "indigo-lime", ja: "藍と若葉", en: "Indigo & Lime",
              light: .init(tiers: [0xD8DDE3, 0xB8CAFF, 0x92AC00, 0x7D9400],
                           ink: 0x637600, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x8497D2, 0xBED95A, 0xCFEF4D],
                           ink: 0xB1CC46, onInk: 0x101305)),
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
        .init(id: "grass-magenta", ja: "草と紅", en: "Grass & Magenta",
              light: .init(tiers: [0xD8DDE3, 0x82E3BA, 0xC57AE6, 0xB55ADA],
                           ink: 0x944FB0, onInk: 0xFFFFFF),
              dark:  .init(tiers: [0x83888E, 0x60AC8C, 0xE7B3FF, 0xF0D0FF],
                           ink: 0xE29FFF, onInk: 0x170D1B)),
    ]

    /// 自分で4色を選んだときの id
    public static let customID = "custom"

    public static func named(_ id: String?) -> CalendarPalette {
        if let id, let hit = all.first(where: { $0.id == id }) { return hit }
        return all.first { $0.id == defaultID } ?? all[0]
    }

    /// 選んだ4色から配色を作る。
    ///
    /// **明暗のテーマで同じ色を使う。** 8色を選ばせるのは多すぎるし、
    /// 「自分で決めた色が、テーマを変えたら別の色になる」ほうが分かりにくい。
    /// 文字やボタンの色は、地の上で読める明るさまで動かして作る。
    public static func custom(_ colors: [UInt32], ja: String, en: String) -> CalendarPalette {
        let tiers = normalizedCustom(colors)
        func side(dark: Bool) -> PaletteColors {
            let ink = ColorMath.readableInk(tiers[3], dark: dark)
            return .init(tiers: tiers, ink: ink, onInk: ColorMath.readableText(on: ink))
        }
        return .init(id: customID, ja: ja, en: en, light: side(dark: false), dark: side(dark: true))
    }

    /// 4色に満たない保存を読んでも落ちないようにする
    public static func normalizedCustom(_ colors: [UInt32]) -> [UInt32] {
        let base = named(defaultID).colors(dark: false).tiers
        return (0..<4).map { colors.indices.contains($0) ? colors[$0] : base[$0] }
    }

    /// 自分で選んだ色が、このアプリの条件を満たしているか。
    /// **止めはしない。** 選ぶのは本人なので、気づけるようにだけしておく。
    public static func issues(with colors: [UInt32]) -> [CustomColorIssue] {
        let c = normalizedCustom(colors)
        var found: [CustomColorIssue] = []
        for tier in DayTier.allCases where
            ColorMath.contrast(c[tier.rawValue - 1], ColorMath.cellInk) < 4.5 {
            found.append(.textUnreadable(tier))
        }
        for i in 0..<3 where ColorMath.difference(c[i], c[i + 1]) < 0.055 {
            found.append(.tooClose(DayTier(rawValue: i + 1)!, DayTier(rawValue: i + 2)!))
        }
        if ColorMath.difference(c[1], c[2]) < 0.15 { found.append(.weakPassBoundary) }
        return found
    }

    /// 1.1 までは「80点未満の色」と「80点以上の色」を別々に選ばせていた。
    /// **80点以上に選んでいた色を引き継ぐ。** そこが合否の境目なので、
    /// 印象がいちばん変わらない。
    public static func migrating(fail: String?, pass: String?) -> String {
        switch pass {
        case "green":            return "rose-grass"
        case "purple":           return "wheat-grape"
        case "orange", "yellow": return "water-apricot"   // 暖色で合格を示していた人
        default:                 return defaultID         // 青、および記録が無いとき
        }
    }
}

/// 自分で選んだ色の、気をつけたほうがいい点。
/// **文言は画面側で作る。** Coreは日本語も英語も持たない。
public enum CustomColorIssue: Sendable, Hashable {
    /// その段の色の上で、マスの数字が読みにくい
    case textUnreadable(DayTier)
    /// 隣り合う2段が見分けにくい
    case tooClose(DayTier, DayTier)
    /// 合否の境目（80点）が目立たない
    case weakPassBoundary
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

    /// OKLab から sRGB へ。`oklab(_:)` の逆。
    /// ガモットからはみ出したぶんは、そのまま切り詰める。
    public static func fromOklab(_ L: Double, _ a: Double, _ b: Double) -> UInt32 {
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        func enc(_ c: Double) -> UInt32 {
            let x = min(1, max(0, c))
            let v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
            return UInt32((v * 255).rounded())
        }
        return (enc(r) << 16) | (enc(g) << 8) | enc(bb)
    }

    /// 明るさだけを動かして、地の上で読める色にする。
    /// **色味は変えない。** 選んだ色から離れて見えると、選び直したくなる。
    public static func adjusted(_ hex: UInt32, toContrast ratio: Double,
                                against grounds: [UInt32], darker: Bool) -> UInt32 {
        var (L, a, b) = oklab(hex)
        var out = hex
        for _ in 0..<160 {
            if grounds.allSatisfy({ contrast(out, $0) >= ratio }) { return out }
            L += darker ? -0.006 : 0.006
            if L <= 0 || L >= 1 { break }
            out = fromOklab(L, a, b)
        }
        // どうしても届かないときは、色味を捨てて白黒に寄せる
        (L, a, b) = (darker ? 0.20 : 0.95, 0, 0)
        return fromOklab(L, a, b)
    }

    /// カードの上に置く文字・ボタンの色
    public static func readableInk(_ hex: UInt32, dark: Bool) -> UInt32 {
        let grounds: [UInt32] = dark ? [0x1C1C1E, 0x2C2C2E] : [0xF2F2F7, 0xFFFFFF]
        return adjusted(hex, toContrast: 4.5, against: grounds, darker: !dark)
    }

    /// その色の上に乗せる文字。白か、ほぼ黒か。
    public static func readableText(on hex: UInt32) -> UInt32 {
        contrast(0xFFFFFF, hex) >= contrast(cellInk, hex) ? 0xFFFFFF : cellInk
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
