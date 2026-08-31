import SwiftUI
import YurutoreCore

/// 設定のいちばん下に置く「コーヒーを奢る」。
///
/// 送っても機能は変わらない。日英どちらでも出るよう、文言は `L` に置いてある。
/// 「寄付」「Donation」とは書かない。慈善団体への寄付はAppleの扱いが別になる。
struct CoffeeTipSectionYurutore: View {
    @Bindable var tipJar: TipJar
    let lang: AppLanguage
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L.tipHeader(lang))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(accent)

            switch tipJar.state {
            case .thanks:
                thanksCard
            case .failed:
                Text(L.tipFailed(lang))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                closeButton
            case .unavailable:
                Text(L.tipNone(lang))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            default:
                button
            }

            gratitude
        }
        .task { await tipJar.load() }
        // 購入が通った瞬間だけ鳴らす。承認待ちが後から届く場合もここを通る。
        .onChange(of: tipJar.cups) { Haptics.success() }
    }

    private var button: some View {
        Button {
            Haptics.medium()
            Task { await tipJar.tip() }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(accent)
                Text(L.tipBuy(lang))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if let price = tipJar.displayPrice {
                    Text(price)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(accent)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(11)
            .background(accent.opacity(0.10), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.45), lineWidth: 1))
            // Spacer は描画を持たないので、これが無いと余白を押しても反応しない
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(tipJar.product == nil || tipJar.state == .purchasing)
        .accessibilityIdentifier("buyCoffee")
    }

    private var thanksCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L.tipThanks(lang), systemImage: "cup.and.saucer.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(accent)
            closeButton
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10), in: .rect(cornerRadius: 12))
    }

    private var closeButton: some View {
        Button(L.tipClose(lang)) {
            Haptics.light()
            tipJar.dismissThanks()
        }
        .font(.system(size: 11, weight: .heavy))
    }

    /// 奢ってくれた人にだけ出すお礼。
    /// 消耗型はStoreKitが復元しないので、機種変更すると 0 に戻ってこの行は消える。
    @ViewBuilder
    private var gratitude: some View {
        if tipJar.cups > 0 {
            Text(L.tipGratitude(tipJar.cups, lang))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
        }
    }
}
