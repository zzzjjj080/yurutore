import SwiftUI
import UniformTypeIdentifiers
import YurutoreCore

/// 設定は「表示」「点数」「データ」に分ける。
/// 混ざっていると、色を触るつもりで点数の決まり方を変えてしまう事故が起きる。
struct SettingsSheet: View {
    @Bindable var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable { case display, scoring, data }
    @State private var tab: Tab = .display
    @State private var confirm: Confirm?
    @State private var exporting = false
    @State private var importing = false
    @State private var importNote = ""

    private var dark: Bool { store.isDark(scheme) }
    private var lang: AppLanguage { store.language }

    struct Confirm: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .display: displayTab
                    case .scoring: scoringTab
                    case .data:    dataTab
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
        .preferredColorScheme(store.theme == .system ? nil : (store.theme == .dark ? .dark : .light))
        .alert(item: $confirm) { c in
            Alert(title: Text(c.title), message: Text(c.message),
                  primaryButton: .destructive(Text(L.yes(lang))) { c.action(); Haptics.medium() },
                  secondaryButton: .cancel(Text(L.cancel(lang))))
        }
        .fileExporter(isPresented: $exporting,
                      document: CSVDocument(text: CSVFormat.export(
                        store.journal, activities: store.activities,
                        settings: store.settings,
                        language: lang == .en ? .english : .japanese)),
                      contentType: .commaSeparatedText,
                      defaultFilename: "yurutore-\(store.today.description)") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText]) { result in
            handleImport(result)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.settings(lang)).font(.system(size: 19, weight: .heavy))
                Spacer()
            }
            Button {
                Haptics.light(); dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    store.showOnboarding = true
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(store.accent(dark: dark))
                    Text(L.aboutBtn(lang)).font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(11)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            }
            Picker("", selection: $tab) {
                Text(L.tabDisplay(lang)).tag(Tab.display)
                Text(L.tabScore(lang)).tag(Tab.scoring)
                Text(L.tabData(lang)).tag(Tab.data)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: - 表示

    private var displayTab: some View {
        Group {
            section(L.language(lang)) {
                Picker("", selection: $store.language) {
                    Text("日本語").tag(AppLanguage.ja)
                    Text("English").tag(AppLanguage.en)
                }.pickerStyle(.segmented).onChange(of: store.language) { store.save() }
            }
            section(L.theme(lang)) {
                Picker("", selection: $store.theme) {
                    Text(L.light(lang)).tag(ThemeChoice.light)
                    Text(L.dark(lang)).tag(ThemeChoice.dark)
                    Text(L.system(lang)).tag(ThemeChoice.system)
                }.pickerStyle(.segmented).onChange(of: store.theme) { store.save() }
            }
            section(L.weekStart(lang)) {
                Picker("", selection: $store.weekStart) {
                    Text(L.monday(lang)).tag(CalendarLayout.WeekStart.monday)
                    Text(L.sunday(lang)).tag(CalendarLayout.WeekStart.sunday)
                }.pickerStyle(.segmented).onChange(of: store.weekStart) { store.save() }
            }
            section(L.reminder(lang)) {
                hint(L.reminderHint(lang))
                Toggle(isOn: $store.reminderOn) {
                    Text(L.reminder(lang)).font(.system(size: 13, weight: .bold))
                }
                .onChange(of: store.reminderOn) { _, on in
                    store.save()
                    if on { Notifications.request() }
                    Notifications.reschedule(store)
                }
                if store.reminderOn {
                    Picker(L.reminderTime(lang), selection: $store.reminderHour) {
                        ForEach(17...23, id: \.self) { Text("\($0):00").tag($0) }
                    }
                    .onChange(of: store.reminderHour) { store.save(); Notifications.reschedule(store) }
                }
            }
            section(L.calColors(lang)) {
                Text(L.under80(lang)).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                swatches(selected: store.failColor, band: .fail) { store.failColor = $0; store.save() }
                Text(L.over80(lang)).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary).padding(.top, 4)
                swatches(selected: store.passColor, band: .pass) { store.passColor = $0; store.save() }
            }
            resetButton(L.resetDefaults(lang),
                        message: L.t("配色・言語・週の始まり・リマインダー・カレンダーの色を、最初の設定に戻します。点数の設定と記録はそのままです。",
                                     "Reset appearance, language, week start, reminder and calendar colors. Scoring settings and your records are kept.", lang)) {
                store.resetDisplaySettings()
            }
        }
    }

    private enum Band { case fail, pass }

    private func swatches(selected: PaletteKind, band: Band,
                          pick: @escaping (PaletteKind) -> Void) -> some View {
        HStack(spacing: 7) {
            ForEach(PaletteKind.allCases) { kind in
                let r = kind.ramp(dark: dark)
                let c = band == .pass ? mix(r.lo, r.hi, 0.86) : mix(r.lo, r.hi, 0.34)
                Button { Haptics.light(); pick(kind) } label: {
                    RoundedRectangle(cornerRadius: 3).fill(c)
                        .frame(height: 12).frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(selected == kind ? Color.primary : .clear, lineWidth: 2))
                }
                .accessibilityLabel(Text(kind.label))
            }
        }
    }

    // MARK: - 点数

    private var scoringTab: some View {
        Group {
            section(L.scoreMode(lang)) {
                ForEach(ScoringMode.allCases, id: \.self) { m in
                    Button {
                        Haptics.medium(); store.settings.mode = m; store.save()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L.modeName(m, lang)).font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(store.settings.mode == m
                                                     ? store.accent(dark: dark) : .primary)
                                Text(L.modeDesc(m, lang)).font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(m.stepSpan) / \(m.exerciseSpan)")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(store.settings.mode == m ? store.accent(dark: dark) : .clear,
                                          lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            section(L.stepGoal(lang)) {
                hint(L.stepHint(Scorer.baseScore, lang))
                // 上限が下限を下回る組み合わせは、そもそも選択肢に出さない
                Picker(L.lower(lang), selection: $store.settings.lowerSteps) {
                    ForEach(ScoringSettings.stepChoices.filter { $0 < store.settings.upperSteps },
                            id: \.self) { Text($0.formatted()).tag($0) }
                }.onChange(of: store.settings.lowerSteps) { store.save() }
                Picker(L.upper(lang), selection: $store.settings.upperSteps) {
                    ForEach(ScoringSettings.stepChoices.filter { $0 > store.settings.lowerSteps },
                            id: \.self) { Text($0.formatted()).tag($0) }
                }.onChange(of: store.settings.upperSteps) { store.save() }
            }

            section(L.otherEx(lang)) {
                hint(L.actHint(lang))
                ForEach(Array(store.activities.enumerated()), id: \.element.id) { i, act in
                    activityRow(i, act)
                }
                Button {
                    Haptics.light(); store.addActivity()
                } label: {
                    Label(L.addAct(lang), systemImage: "plus")
                        .font(.system(size: 13, weight: .heavy))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }
            }

            section(L.matrixTitle(lang)) {
                hint(L.matrixHint(lang))
                ScoreMatrix(store: store, dark: dark)
            }

            resetButton(L.resetDefaults(lang),
                        message: L.t("採点モード・歩数の目安・その他の運動を、最初の設定に戻します。見た目の設定と記録はそのままです。",
                                     "Reset scoring mode, step targets and exercises. Display settings and your records are kept.", lang)) {
                store.resetScoringSettings()
            }
        }
    }

    private func activityRow(_ index: Int, _ act: Activity) -> some View {
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                arrow("chevron.up", enabled: index > 0) { store.moveActivity(from: index, by: -1) }
                arrow("chevron.down", enabled: index < store.activities.count - 1) {
                    store.moveActivity(from: index, by: 1)
                }
            }
            TextField(L.t("運動の名前", "Name", lang),
                      text: Binding(get: { store.activities[index].name },
                                    set: { store.activities[index].name = $0; store.save() }))
                .font(.system(size: 13, weight: .bold))
                .textFieldStyle(.roundedBorder)
            TextField("", value: Binding(
                get: { store.activities[index].quantity },
                set: { store.activities[index].quantity = max(1, $0)
                       store.activities[index].met = nil
                       store.activities[index].minutes = nil
                       store.save() }), format: .number)
                .frame(width: 52).multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder).keyboardType(.numberPad)
            Picker("", selection: Binding(
                get: { store.activities[index].unit },
                set: { store.activities[index].unit = $0; store.save() })) {
                ForEach(ActivityUnit.allCases, id: \.self) {
                    Text(L.unitName($0, lang)).tag($0)
                }
            }
            .labelsHidden().frame(width: 68)
            Button {
                // 消すと過去の点数まで下がるので、必ず件数を見せてから確認する
                let used = store.usageCount(activityID: act.id)
                confirm = .init(
                    title: L.t("「\(act.name)」を消しますか？", "Delete \"\(act.name)\"?", lang),
                    message: used > 0
                        ? L.t("この運動は\(used)日ぶん記録されています。消すと、その日の点数が下がります。記録そのものは残ります。",
                              "It is logged on \(used) days. Those days will score lower. The records themselves are kept.", lang)
                        : L.t("まだ一度も記録されていません。", "It has never been logged.", lang),
                    action: { store.deleteActivity(id: act.id) })
            } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary).frame(width: 26)
            }
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: symbol).font(.system(size: 8, weight: .bold))
                .frame(width: 24, height: 17)
                .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 5))
                .foregroundStyle(.secondary)
        }
        .disabled(!enabled).opacity(enabled ? 1 : 0.25)
    }

    // MARK: - データ

    private var dataTab: some View {
        Group {
            section(L.dataTitle(lang)) {
                hint(L.dataHint(lang))
                Text(L.dataCount(store.journal.days.count, lang))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Button { Haptics.medium(); exporting = true } label: {
                    Text(L.exportBtn(lang)).font(.system(size: 15, weight: .heavy))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.rgb(18, 160, 107), in: .rect(cornerRadius: 13))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button { Haptics.light(); importing = true } label: {
                    Text(L.importBtn(lang)).font(.system(size: 13, weight: .heavy))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }
                if !importNote.isEmpty {
                    Text(importNote).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importNote = L.t("読み込めませんでした。形式を確認してください。",
                             "Could not read that file.", lang)
            return
        }
        do {
            let r = try CSVFormat.import(text, activities: store.activities)
            let missing = Array(Set(r.droppedNames))
            confirm = .init(
                title: L.t("読み込みますか？", "Import?", lang),
                message: L.t("\(r.journal.days.count)日ぶんの記録を読み込みます。同じ日の記録は上書きされます。",
                             "Import \(r.journal.days.count) days. Records for the same dates will be overwritten.", lang)
                    + (missing.isEmpty ? "" :
                       L.t("\n\n⚠ 次の運動はいまの設定に無いので読み込めません：\(missing.joined(separator: "、"))",
                           "\n\n⚠ These are not in your settings and will be skipped: \(missing.joined(separator: ", "))", lang)),
                action: {
                    for (d, l) in r.journal.days { store.journal[d] = l }
                    store.journal.settleAll(today: store.today,
                                            activities: store.activities, settings: store.settings)
                    store.save()
                    importNote = missing.isEmpty
                        ? L.t("\(r.journal.days.count)日ぶんを読み込みました", "Imported \(r.journal.days.count) days", lang)
                        : L.t("\(r.journal.days.count)日ぶんを読み込みました（\(missing.count)件の運動は読み込めませんでした）",
                              "Imported \(r.journal.days.count) days (\(missing.count) skipped)", lang)
                })
        } catch {
            importNote = L.t("読み込めませんでした。形式を確認してください。",
                             "Could not read that file. Check the format.", lang)
        }
    }

    // MARK: - 部品

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 11, weight: .heavy)).foregroundStyle(.secondary)
            content()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 10))
    }

    private func resetButton(_ title: String, message: String,
                             action: @escaping () -> Void) -> some View {
        Button {
            Haptics.medium()
            confirm = .init(title: L.t("デフォルトに戻しますか？", "Reset to defaults?", lang),
                            message: message, action: action)
        } label: {
            Text(title).font(.system(size: 14, weight: .heavy))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                .foregroundStyle(.orange)
        }
        .padding(.top, 4)
    }
}

/// いまの設定でどんな点数になるかの一覧。設定を変えるとその場で書き換わる。
struct ScoreMatrix: View {
    let store: AppStore
    let dark: Bool

    private var rows: [Int] {
        let lo = store.settings.lowerSteps, hi = store.settings.safeUpperSteps
        let step = Double(hi - lo) / 4
        var v = [Double(lo) - step]
        v += (0...4).map { Double(lo) + step * Double($0) }
        v.append(Double(hi) + step)
        return Array(Set(v.map { max(0, Int(($0 / 100).rounded()) * 100) })).sorted()
    }

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Text("").frame(width: 46)
                ForEach(0...3, id: \.self) { c in
                    Text(c == 3 ? "3+" : "\(c)")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(rows, id: \.self) { steps in
                GridRow {
                    Text(steps.formatted())
                        .font(.system(size: 10, weight: .bold)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                    ForEach(0...3, id: \.self) { n in
                        let s = sample(steps: steps, exercises: n)
                        Text("\(s)")
                            .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                            .frame(maxWidth: .infinity).frame(height: 33)
                            .background(store.cellColor(score: s, dark: dark),
                                        in: .rect(cornerRadius: 7))
                            .foregroundStyle(Color.cellInk)
                    }
                }
            }
        }
    }

    private func sample(steps: Int, exercises n: Int) -> Int {
        var log = DayLog(steps: steps)
        var remaining = n
        for p in BodyPart.allCases where remaining > 0 {
            let v = min(3, remaining)
            log.parts[p] = Volume(rawValue: v)
            remaining -= v
        }
        return Scorer.autoScore(log, activities: store.activities, settings: store.settings)
    }
}

/// CSVの書き出し用
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Excelで文字化けしないようBOMを付ける
        FileWrapper(regularFileWithContents: Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8))
    }
}
