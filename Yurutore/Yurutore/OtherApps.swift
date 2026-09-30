import SwiftUI
import YurutoreCore

/// 設定のいちばん下に置く「作者のほかのアプリ」。
///
/// **投げ銭（コーヒー1杯）を外した跡地**（2026-09-30 本人判断。収入の入り口を無くす）。
/// お金を受け取る代わりに、同じ作者のアプリ一覧へ送るだけにしている。
/// App Store を開くのは標準のブラウザ／App Store アプリなので、
/// **アプリ自身は通信しない。** プライバシーポリシーに書き足すこともない。
struct OtherAppsLinkYurutore: View {
    let lang: AppLanguage
    let accent: Color
    @Environment(\.openURL) private var openURL

    /// 作者のページ。アプリを増やしてもここは変わらない
    static let url = URL(string: "https://apps.apple.com/jp/developer/jin-nakamura/id6802013586")!

    var body: some View {
        Button {
            Haptics.light()
            openURL(Self.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(L.otherApps(lang))
                    .font(.system(size: 12, weight: .heavy))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(accent)
            // Spacer は描画を持たないので、これが無いと余白を押しても反応しない
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("otherApps")
    }
}
