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

    /// 最後は説明ではなく、実際に合格ラインを決めてもらう。
    /// 「あとで設定できます」と言うだけでは、ほとんどの人は設定を開かない。
    private var isSetup: Bool { step == pages.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(L.obSkip(lang)) { store.finishOnboarding() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            if !isSetup {
                art.frame(height: 150).frame(maxWidth: .infinity).padding(.vertical, 26)
            } else {
                Spacer(minLength: 12).frame(height: 20)
            }

            Text(pages[step].title)
                .font(.system(size: 23, weight: .heavy))
                .padding(.bottom, 16)

            Text(pages[step].body)
                .font(.system(size: 13.5, weight: .semibold))
                .lineSpacing(6)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isSetup { setup.padding(.top, 20) }

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

    /// 初回に決めてもらうのは合格ラインの2つだけ。
    /// 目標ラインまで聞くと、始める前に4つ選ばせることになる。
    private var setup: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(L.obWalk(lang), systemImage: "figure.walk") {
                Picker("", selection: Binding(
                    get: { store.settings.passSteps },
                    set: { store.settings.setPassSteps($0); store.save(); Haptics.light() })) {
                    // 目標ラインを置く余地を残すため、上限そのものは選ばせない
                    ForEach(ScoringSettings.stepChoices.dropLast(), id: \.self) {
                        Text("\($0.formatted())").tag($0)
                    }
                }
            }
            row(L.obMove(lang), systemImage: "dumbbell.fill") {
                Picker("", selection: Binding(
                    get: { store.settings.passExercises },
                    set: { store.settings.setPassExercises($0); store.save(); Haptics.light() })) {
                    ForEach(ScoringSettings.exerciseChoices.dropLast(), id: \.self) {
                        Text(L.exCount($0, lang)).tag($0)
                    }
                }
            }
            Text(L.lineSummary(steps: store.settings.passSteps,
                               ex: store.settings.passExercises, lang))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(store.accent(dark: dark))
                .padding(.top, 2)

            // 決めた線でどんな日がどう色づくかを見せる。
            // 数字だけだと、選んだ結果が想像しにくい。
            HStack(spacing: 7) {
                let s = store.settings
                preview(steps: s.passSteps / 2, ex: 0)
                preview(steps: s.passSteps, ex: 0)
                preview(steps: s.passSteps, ex: s.passExercises)
                preview(steps: s.safeGoalSteps, ex: s.safeGoalExercises)
            }
            .padding(.top, 4)

            Text(L.obLater(lang))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// カレンダーの1マスと同じ見た目で、その組み合わせの点を出す
    private func preview(steps: Int, ex: Int) -> some View {
        var log = DayLog(steps: steps)
        var remaining = ex
        for p in BodyPart.allCases where remaining > 0 {
            log.parts[p] = Volume(rawValue: min(3, remaining))
            remaining -= min(3, remaining)
        }
        let score = Scorer.autoScore(log, activities: store.activities, settings: store.settings)
        return VStack(spacing: 2) {
            Text("\(score)").font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.cellInk)
            Text("\(steps / 1000)k(\(ex))").font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.cellInk.opacity(0.65))
        }
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(store.cellColor(score: score, dark: dark), in: .rect(cornerRadius: 9))
    }

    private func row<C: View>(_ label: String, systemImage: String,
                              @ViewBuilder picker: () -> C) -> some View {
        HStack(spacing: 8) {
            Label(label, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold))
            Spacer(minLength: 4)
            picker()
        }
        .padding(.horizontal, 13).frame(height: 52)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
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
