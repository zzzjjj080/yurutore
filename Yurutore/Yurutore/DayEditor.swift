import SwiftUI
import YurutoreCore

/// 1日の入力。開いたまま前後の日へ動けるようにしてある。
struct DayEditor: View {
    @Bindable var store: AppStore
    let date: YMD
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var pickerOpen = false

    private var dark: Bool { store.isDark(scheme) }
    private var lang: AppLanguage { store.language }
    private var current: YMD { store.editingDate ?? date }
    private var log: DayLog { store.log(current) }
    private var score: Int { Scorer.score(log, activities: store.activities, settings: store.settings) }
    private var pass: Bool { score >= Scorer.passLine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                head
                if pickerOpen { scorePicker }
                stepsCard
                partsSection
                actsSection
                actions
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
        .preferredColorScheme(store.theme == .system ? nil : (store.theme == .dark ? .dark : .light))
    }

    // MARK: - 見出しと点数

    private var head: some View {
        HStack {
            HStack(spacing: 4) {
                stepButton("chevron.left", -1, enabled: true)
                Text(L.dayTitle(current, lang)).font(.system(size: 19, weight: .heavy))
                stepButton("chevron.right", 1,
                           enabled: !store.isFuture(current.adding(days: 1)))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Button {
                    Haptics.light(); pickerOpen.toggle()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(score)")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(pass ? store.accent(dark: dark) : .primary)
                        Text(L.pts(lang)).font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(score) \(L.pts(lang)), \(L.tapToPick(lang))")
                Text(log.manualScore != nil ? L.manual(lang) : L.tapToPick(lang))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(log.manualScore != nil ? .orange : .secondary)
            }
        }
    }

    private func stepButton(_ symbol: String, _ delta: Int, enabled: Bool) -> some View {
        Button { store.stepEditingDay(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemGroupedBackground), in: .circle)
                .foregroundStyle(.secondary)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
    }

    /// 点数は20〜100の10刻みから選ぶ。自由入力だと刻みが揃わない。
    private var scorePicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            pick(nil, label: L.auto(lang))
            ForEach(Scorer.manualChoices, id: \.self) { v in pick(v, label: "\(v)") }
        }
        .padding(9)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 13))
    }

    private func pick(_ value: Int?, label: String) -> some View {
        let on = log.manualScore == value
        return Button {
            store.setManualScore(current, value)
            pickerOpen = false
        } label: {
            Text(label)
                .font(.system(size: value == nil ? 12 : 15, weight: .heavy))
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(on ? store.accent(dark: dark) : Color(.tertiarySystemGroupedBackground),
                            in: .rect(cornerRadius: 9))
                .foregroundStyle(on ? store.onAccent(dark: dark) : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 歩数

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(L.steps(lang)).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(badgeText)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(log.lockedScore != nil ? .secondary : store.accent(dark: dark))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(log.lockedScore != nil ? Color.secondary : store.accent(dark: dark),
                                      lineWidth: 1))
            }
            Text(log.steps.formatted())
                .font(.system(size: 27, weight: .heavy))
                .monospacedDigit()
            Text(subText).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private var badgeText: String {
        if log.lockedScore != nil { return L.settled(lang) }
        let left = max(0, Journal.graceDays - store.today.days(since: current))
        return L.syncing(left, lang)
    }

    private var subText: String {
        let s = Scorer.stepScore(steps: log.steps, settings: store.settings)
        let e = Scorer.exerciseScore(count: log.exerciseCount(activities: store.activities),
                                     settings: store.settings)
        if log.manualScore != nil {
            return L.ifAuto(Scorer.autoScore(log, activities: store.activities,
                                             settings: store.settings), lang)
        }
        return L.breakdown(s, e, lang)
    }

    // MARK: - 部位

    private var partsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L.bodyParts(lang)).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                if store.state(current) != .logged {
                    Text(store.state(current) == .rest ? L.restDay(lang) : L.notLogged(lang))
                        .font(.system(size: 11, weight: .heavy)).foregroundStyle(.orange)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                      spacing: 7) {
                ForEach(BodyPart.allCases, id: \.self) { part in
                    let v = log.parts[part]?.rawValue ?? 0
                    Button { store.cyclePart(current, part) } label: {
                        VStack(spacing: 3) {
                            Text(L.partName(part, lang)).font(.system(size: 17, weight: .heavy))
                            Text(v > 0 ? "×\(v)" : "—").font(.system(size: 11, weight: .heavy))
                                .opacity(0.85)
                        }
                        .frame(maxWidth: .infinity).frame(height: 64)
                        .background(v > 0 ? Color.partFill(v, dark: dark)
                                          : Color(.secondarySystemGroupedBackground),
                                    in: .rect(cornerRadius: 12))
                        .foregroundStyle(v > 0 ? Color.partText(v, dark: dark) : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(L.partName(part, lang)) \(v > 0 ? "×\(v)" : L.t("なし","none",lang))")
                }
            }
        }
    }

    // MARK: - その他の運動

    private var actsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(store.activities) { act in
                let v = log.activities[act.id]?.rawValue ?? 0
                Button { store.cycleActivity(current, act.id) } label: {
                    VStack(spacing: 2) {
                        Text(act.name.isEmpty ? "—" : act.name)
                            .font(.system(size: 12, weight: .heavy))
                            .multilineTextAlignment(.center)
                        Text("\(act.quantity)\(L.unitName(act.unit, lang))\(v > 1 ? " ×\(v)" : "")")
                            .font(.system(size: 9, weight: .bold)).opacity(0.85)
                        Text(v > 0 ? "×\(v)" : "—").font(.system(size: 11, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity).frame(minHeight: 58)
                    .padding(.vertical, 7)
                    .background(v > 0 ? Color.actFill(v, dark: dark)
                                      : Color(.secondarySystemGroupedBackground),
                                in: .rect(cornerRadius: 11))
                    .foregroundStyle(v > 0 ? Color.actText(v, dark: dark) : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(act.name) \(act.quantity)\(L.unitName(act.unit, lang)) \(v > 0 ? "×\(v)" : L.t("なし","none",lang))")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 9) {
            Button { store.toggleRest(current) } label: {
                Text(L.restDay(lang))
                    .font(.system(size: 15, weight: .heavy))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(store.state(current) == .rest ? Color.secondary
                                                              : Color(.secondarySystemGroupedBackground),
                                in: .rect(cornerRadius: 13))
                    .foregroundStyle(store.state(current) == .rest
                                     ? Color(.systemBackground) : Color.secondary)
            }
            .buttonStyle(.plain)
            Button { dismiss() } label: {
                Text(L.done(lang))
                    .font(.system(size: 15, weight: .heavy))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.rgb(18, 160, 107), in: .rect(cornerRadius: 13))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}
