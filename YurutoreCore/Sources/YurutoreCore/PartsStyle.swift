import Foundation

/// カレンダーの下に出す「最近30日の部位」の見せ方。
///
/// **どれも良し悪しは付けない。** 少ない部位を警告の色にしていたのをやめた
/// （2026-09-24 本人指摘：「少ないのは良くない、という雰囲気はいらない」）。
/// 量が分かればよく、足りているかどうかを決めるのは本人。
///
/// 5通り作って本人が2つに絞った（2026-09-25）。横棒・輪・数字だけは外した。
public enum PartsStyle: String, Codable, CaseIterable, Sendable {
    /// 縦の棒。高さで量を見る
    case bars
    /// 色の濃さで量を見る札
    case tiles

    public var japanese: String {
        switch self { case .bars: "棒"; case .tiles: "札" }
    }

    public var english: String {
        switch self { case .bars: "Bars"; case .tiles: "Tiles" }
    }

    public static let `default` = PartsStyle.bars

    /// 保存に知らない名前が入っていても落とさない
    /// （5通りあった版から減らしたので、`rings` などが残っている端末がある）
    public static func from(_ raw: String?) -> PartsStyle {
        guard let raw, let s = PartsStyle(rawValue: raw) else { return .default }
        return s
    }
}

// MARK: - 色

/// 部位の色。**カレンダーの配色とは別に選ぶ。**
/// カレンダーは点数の段階を表すのに対して、こちらはただの量なので、
/// 同じ色でなくてよい（2026-09-25 本人希望）。
public struct PartsColor: Identifiable, Equatable, Sendable {
    public let id: String
    public let ja: String
    public let en: String
    /// nil は「カレンダーに合わせる」。画面側がその時の色を入れる
    public let light: UInt32?
    public let dark: UInt32?

    public func name(japanese: Bool) -> String { japanese ? ja : en }
    public func hex(dark: Bool) -> UInt32? { dark ? self.dark : light }
}

public enum PartsColors {
    public static let followID = "follow"
    public static let defaultID = followID

    public static let all: [PartsColor] = [
        .init(id: followID, ja: "カレンダー", en: "Calendar", light: nil, dark: nil),
        .init(id: "indigo", ja: "藍",   en: "Indigo", light: 0x2F6FD0, dark: 0x5B9BF0),
        .init(id: "teal",   ja: "青緑", en: "Teal",   light: 0x0F7F84, dark: 0x33C2BE),
        .init(id: "green",  ja: "緑",   en: "Green",  light: 0x2A8C51, dark: 0x49C97C),
        .init(id: "amber",  ja: "琥珀", en: "Amber",  light: 0xB5650B, dark: 0xE8A33C),
        .init(id: "rose",   ja: "紅",   en: "Rose",   light: 0xC63A55, dark: 0xF0768C),
        .init(id: "purple", ja: "紫",   en: "Purple", light: 0x6F45C4, dark: 0xA98BF0),
        .init(id: "slate",  ja: "墨",   en: "Slate",  light: 0x4E5766, dark: 0x9AA4B2),
    ]

    public static func named(_ id: String?) -> PartsColor {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - 濃淡

/// 量の差を、色の濃さでどれだけ出すか。
///
/// `none` なら全部同じ濃さになり、**量は長さ（棒）と数字だけで分かる。**
/// 濃淡そのものを好まない人のために、切れるようにしてある。
public enum PartsShade: Int, Codable, CaseIterable, Sendable {
    case none = 0, weak = 1, medium = 2, strong = 3

    public var japanese: String {
        switch self { case .none: "なし"; case .weak: "弱"; case .medium: "中"; case .strong: "強" }
    }
    public var english: String {
        switch self { case .none: "Off"; case .weak: "Low"; case .medium: "Mid"; case .strong: "High" }
    }

    public static let `default` = PartsShade.medium

    public static func from(_ raw: Int?) -> PartsShade {
        guard let raw, let s = PartsShade(rawValue: raw) else { return .default }
        return s
    }

    /// いちばん少ない部位がどこまで薄くなるか
    private var span: Double {
        switch self { case .none: 0; case .weak: 0.25; case .medium: 0.5; case .strong: 0.75 }
    }

    /// 量の比（0〜1）に対する色の濃さ（0〜1）。
    /// いちばん多い部位は必ず 1.0 で、そこからどれだけ薄くするかだけが変わる。
    public func opacity(_ ratio: Double) -> Double {
        let r = min(1, max(0, ratio))
        return 1 - span + span * r
    }

    /// 札の塗りの濃さ。
    ///
    /// **札には数字が乗るので、上限を付ける。** べた塗りにすると、
    /// 色によっては黒文字も白文字も読めない明るさに入ってしまう
    /// （実測で 4.2:1 まで落ちた）。上限 0.55 なら、どの色・どの濃淡でも
    /// 4.5:1 を超える（`PartsColorTests`）。
    public func tileAlpha(_ ratio: Double) -> Double {
        0.18 + 0.37 * opacity(ratio)
    }
}
