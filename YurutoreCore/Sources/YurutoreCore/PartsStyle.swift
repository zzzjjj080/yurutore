import Foundation

/// カレンダーの下に出す「最近30日の部位」の見せ方。
///
/// **どれも良し悪しは付けない。** 少ない部位を警告の色にしていたのをやめた
/// （2026-09-24 本人指摘：「少ないのは良くない、という雰囲気はいらない」）。
/// 量が分かればよく、足りているかどうかを決めるのは本人。
public enum PartsStyle: String, Codable, CaseIterable, Sendable {
    /// 縦の棒。高さで量を見る
    case bars
    /// 横の棒を2列に並べる。名前と数が読みやすい
    case rows
    /// 輪の長さで量を見る。真ん中に数
    case rings
    /// 色の濃さで量を見る札
    case tiles
    /// 絵を使わず数字だけ
    case numbers

    public var japanese: String {
        switch self {
        case .bars: "棒"; case .rows: "横棒"; case .rings: "輪"
        case .tiles: "札"; case .numbers: "数字だけ"
        }
    }

    public var english: String {
        switch self {
        case .bars: "Bars"; case .rows: "Rows"; case .rings: "Rings"
        case .tiles: "Tiles"; case .numbers: "Numbers"
        }
    }

    /// 本人が選ぶまでの既定。
    public static let `default` = PartsStyle.bars

    /// 保存に知らない名前が入っていても落とさない（先の版で増やす可能性がある）
    public static func from(_ raw: String?) -> PartsStyle {
        guard let raw, let s = PartsStyle(rawValue: raw) else { return .default }
        return s
    }
}
