import SwiftUI
import YurutoreCore

/// 初回だけ出す説明。細かい仕様より「何のために作ったか」を先に伝える。
/// 設定からいつでも見返せる。
struct OnboardingView: View {
    @Bindable var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var step = 0

    private var dark: Bool { store.isDark(scheme) }
    private var lang: AppLanguage { store.language }
    private var pages: [L.Page] { L.onboarding(lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(L.obSkip(lang)) { store.finishOnboarding() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            art.frame(height: 150).frame(maxWidth: .infinity).padding(.vertical, 26)

            Text(pages[step].title)
                .font(.system(size: 23, weight: .heavy))
                .padding(.bottom, 16)

            Text(pages[step].body)
                .font(.system(size: 13.5, weight: .semibold))
                .lineSpacing(6)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 20)

            HStack(spacing: 6) {
                Spacer()
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? store.accent(dark: dark) : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 18 : 6, height: 6)
                }
                Spacer()
            }
            .padding(.bottom, 16)

            Button {
                Haptics.light()
                if step < pages.count - 1 {
                    withAnimation(.easeOut(duration: 0.2)) { step += 1 }
                } else {
                    store.finishOnboarding()
                }
            } label: {
                Text(step < pages.count - 1 ? L.obNext(lang) : L.obStart(lang))
                    .font(.system(size: 15, weight: .heavy))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.rgb(18, 160, 107), in: .rect(cornerRadius: 13))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 34)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(store.theme == .system ? nil : (store.theme == .dark ? .dark : .light))
    }

    @ViewBuilder
    private var art: some View {
        switch step {
        case 0:
            // 実際のカレンダーと同じ色で見せる
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 3), count: 7), spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    let on = [2,3,5,9,10,12,16,17,19,23,24].contains(i)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(on ? store.cellColor(score: i % 3 == 0 ? 45 : 88, dark: dark)
                                 : Color(.tertiarySystemGroupedBackground))
                        .frame(height: 20)
                }
            }
            .frame(width: 7 * 20 + 6 * 3)
        case 1:
            HStack(spacing: 7) {
                chip("胸", "×2", Color.partFill(2, dark: dark), Color.partText(2, dark: dark))
                chip("背", "×1", Color.partFill(1, dark: dark), Color.partText(1, dark: dark))
                chip("肩", "—", Color(.tertiarySystemGroupedBackground), .secondary)
                chip("水泳", "×3", Color.actFill(3, dark: dark), Color.actText(3, dark: dark))
            }
        case 2:
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Scorer.passLine)")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(store.accent(dark: dark))
                Text(L.pts(lang)).font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(store.accent(dark: dark))
            }
        default:
            Image(systemName: "gearshape.fill")
                .font(.system(size: 56)).foregroundStyle(.secondary)
        }
    }

    private func chip(_ name: String, _ v: String, _ bg: Color, _ fg: Color) -> some View {
        VStack(spacing: 2) {
            Text(name).font(.system(size: 13, weight: .heavy))
            Text(v).font(.system(size: 10, weight: .heavy))
        }
        .frame(width: 52, height: 52)
        .background(bg, in: .rect(cornerRadius: 11))
        .foregroundStyle(fg)
    }
}
