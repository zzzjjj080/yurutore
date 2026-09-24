import SwiftUI
import YurutoreCore

/// カレンダーの下の空きに置く、最近30日で動かした部位の量。
///
/// **狙いは合計ではなく偏り。** どこを多くやったかより、
/// 「どこをやっていないか」が一目で分かることを優先している。
/// 少ない側はオレンジにして、数字を読まなくても目に入るようにする。
struct RecentParts: View {
    let store: AppStore
    let counts: [BodyPart: Int]
    let dark: Bool

    /// 棒の高さ。**画面の下にはもう余裕がない。**
    /// ここを増やすと、小さい端末でカレンダーが押し出される。
    private let barHeight: CGFloat = 24

    private var lang: AppLanguage { store.language }

    var body: some View {
        let maxCount = max(1, counts.values.max() ?? 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                let n = counts[part] ?? 0
                // 0 は「やっていない」。少ない扱いに含めつつ、棒は描かない
                let low = n == 0 || Double(n) <= Double(maxCount) * 0.34
                VStack(spacing: 3) {
                    Text("\(n)")
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(n == 0 ? Color.secondary
                                         : low ? Color.orange : Color.primary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.tertiarySystemGroupedBackground))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(n == 0 ? Color.clear
                                  : low ? Color.orange : store.accent(dark: dark))
                            .frame(height: max(3, barHeight * Double(n) / Double(maxCount)))
                    }
                    .frame(height: barHeight)
                    Text(L.partName(part, lang))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(low ? Color.orange : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(L.partName(part, lang)) \(n)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 11))
        .accessibilityIdentifier("recentParts")
    }
}
