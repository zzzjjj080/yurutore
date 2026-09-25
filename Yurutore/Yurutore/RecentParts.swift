import SwiftUI
import YurutoreCore

/// カレンダーの下に出す、最近30日で動かした部位の量。
///
/// **良し悪しは付けない。** 少ない部位を警告の色にしていたのをやめた
/// （2026-09-24 本人指摘）。どこをどれだけ動かしたかが分かればよく、
/// 足りているかどうかを決めるのは本人。
///
/// 見せ方は棒と札の2つ。色・濃さ・濃淡は設定で選ぶ（2026-09-25）。
struct RecentParts: View {
    let store: AppStore
    let counts: [BodyPart: Int]
    let dark: Bool
    var style: PartsStyle
    var colorID: String
    var depth: PartsDepth
    var shade: PartsShade

    private var lang: AppLanguage { store.language }
    private var track: Color { Color(.tertiarySystemGroupedBackground) }

    /// 札の下地。数字が読めるかの計算に使うので、実際のカードと同じ値にする
    private var cardHex: UInt32 { dark ? 0x1C1C1E : 0xFFFFFF }
    /// 「カレンダーに合わせる」なら、その時の配色の色を借りる
    private var baseHex: UInt32 {
        PartsColors.named(colorID).hex(dark: dark) ?? store.accentHex(dark: dark)
    }
    private var base: Color { Color(hex: baseHex) }

    private var maxCount: Int { max(1, counts.values.max() ?? 1) }
    private func n(_ part: BodyPart) -> Int { counts[part] ?? 0 }
    private func ratio(_ part: BodyPart) -> Double { Double(n(part)) / Double(maxCount) }

    /// 絵の高さ。**画面の下にはもう余裕がない。**
    /// ここを増やすと、小さい端末でカレンダーが押し出される。
    private let art: CGFloat = 26

    var body: some View {
        Group {
            switch style {
            case .bars:  bars
            case .tiles: tiles
            }
        }
        .padding(.horizontal, 10)
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
                Text("\(n(part))")
                    .font(.system(size: 13, weight: .heavy))
                    .monospacedDigit()
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3).fill(track)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(base.opacity(shade.barAlpha(ratio(part), depth: depth)))
                        .frame(height: n(part) == 0 ? 0 : max(3, art * ratio(part)))
                }
                .frame(height: art)
                name(part)
            }
        }
    }

    /// 色の濃さで量を見る札
    private var tiles: some View {
        columns { part in
            // 塗りと数字の色はひと組で決める。**濃い色のときは白抜きに変わる**
            let a = n(part) == 0 ? 0.10 : shade.tileAlpha(ratio(part), depth: depth)
            let paint = ColorMath.readableFill(baseHex, over: cardHex, alpha: a)
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color(hex: paint.fill))
                    Text("\(n(part))")
                        .font(.system(size: 17, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(n(part) == 0 ? Color.secondary : Color(hex: paint.ink))
                }
                .frame(height: 32)
                name(part)
            }
        }
    }

    // MARK: - 部品

    private func columns<C: View>(@ViewBuilder _ item: @escaping (BodyPart) -> C) -> some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                item(part)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(L.partName(part, lang)) \(n(part))")
            }
        }
    }

    /// 部位の名前。**小さすぎて読めないと言われたので大きくした**（2026-09-25）
    private func name(_ part: BodyPart) -> some View {
        Text(L.partName(part, lang))
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
