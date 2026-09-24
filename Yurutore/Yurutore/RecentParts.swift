import SwiftUI
import YurutoreCore

/// カレンダーの下に出す、最近30日で動かした部位の量。
///
/// **良し悪しは付けない。** 少ない部位を警告の色にしていたのをやめた
/// （2026-09-24 本人指摘）。どこをどれだけ動かしたかが分かればよく、
/// 足りているかどうかを決めるのは本人。
/// 見せ方は5通りあり、設定で選ぶ。数字の意味はどれも同じ。
struct RecentParts: View {
    let store: AppStore
    let counts: [BodyPart: Int]
    let dark: Bool
    var style: PartsStyle

    private var lang: AppLanguage { store.language }
    private var accent: Color { store.accent(dark: dark) }
    private var track: Color { Color(.tertiarySystemGroupedBackground) }
    private var maxCount: Int { max(1, counts.values.max() ?? 1) }
    private func n(_ part: BodyPart) -> Int { counts[part] ?? 0 }
    private func ratio(_ part: BodyPart) -> Double { Double(n(part)) / Double(maxCount) }

    /// 絵の高さ。**画面の下にはもう余裕がない。**
    /// ここを増やすと、小さい端末でカレンダーが押し出される。
    private let art: CGFloat = 26

    var body: some View {
        Group {
            switch style {
            case .bars:    bars
            case .rows:    rows
            case .rings:   rings
            case .tiles:   tiles
            case .numbers: numbers
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 11))
        .accessibilityIdentifier("recentParts")
    }

    // MARK: - 見せ方

    /// 縦の棒。高さで量を見る
    private var bars: some View {
        columns { part in
            VStack(spacing: 3) {
                count(part, size: 11)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3).fill(track)
                    RoundedRectangle(cornerRadius: 3).fill(accent)
                        .frame(height: n(part) == 0 ? 0 : max(3, art * ratio(part)))
                }
                .frame(height: art)
                name(part)
            }
        }
    }

    /// 横の棒を2列。名前と数がいちばん読みやすい
    private var rows: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                  spacing: 7) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                HStack(spacing: 6) {
                    Text(L.partName(part, lang))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(track)
                            Capsule().fill(accent)
                                .frame(width: n(part) == 0 ? 0 : max(4, geo.size.width * ratio(part)))
                        }
                    }
                    .frame(height: 7)
                    Text("\(n(part))")
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .frame(width: 18, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(L.partName(part, lang)) \(n(part))")
            }
        }
    }

    /// 輪の長さで量を見る。真ん中に数
    private var rings: some View {
        columns { part in
            VStack(spacing: 3) {
                ZStack {
                    Circle().stroke(track, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: ratio(part))
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(n(part))")
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 30, height: 30)
                name(part)
            }
        }
    }

    /// 色の濃さで量を見る札
    private var tiles: some View {
        columns { part in
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        // 濃さは相対。0 でも枠は残すので、空白には見えない
                        .fill(accent.opacity(n(part) == 0 ? 0.10 : 0.2 + 0.35 * ratio(part)))
                    Text("\(n(part))")
                        .font(.system(size: 15, weight: .heavy))
                        .monospacedDigit()
                }
                .frame(height: 30)
                name(part)
            }
        }
    }

    /// 絵を使わず数字だけ。いちばん静か
    private var numbers: some View {
        columns { part in
            VStack(spacing: 0) {
                Text("\(n(part))")
                    .font(.system(size: 20, weight: .heavy))
                    .monospacedDigit()
                name(part)
            }
        }
    }

    // MARK: - 部品

    private func columns<C: View>(@ViewBuilder _ item: @escaping (BodyPart) -> C) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                item(part)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(L.partName(part, lang)) \(n(part))")
            }
        }
    }

    private func count(_ part: BodyPart, size: CGFloat) -> some View {
        Text("\(n(part))")
            .font(.system(size: size, weight: .heavy))
            .monospacedDigit()
    }

    private func name(_ part: BodyPart) -> some View {
        Text(L.partName(part, lang))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
