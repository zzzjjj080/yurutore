import SwiftUI
import YurutoreCore

/// 部位のバランスなど、カレンダーを大きく保つために奥に置いた情報。
struct DetailSheet: View {
    @Bindable var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    private var dark: Bool { store.isDark(scheme) }
    private var lang: AppLanguage { store.language }

    var body: some View {
        let s = store.monthSummary
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L.detailTitle(store.viewYear, store.viewMonth, lang))
                    .font(.system(size: 19, weight: .heavy))

                card(L.bodyParts(lang)) {
                    let maxCount = max(1, s.partCounts.values.max() ?? 1)
                    ForEach(BodyPart.allCases, id: \.self) { p in
                        let n = s.partCounts[p] ?? 0
                        let low = Double(n) <= Double(maxCount) * 0.34
                        HStack(spacing: 9) {
                            Text(L.partName(p, lang))
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(low ? .orange : .primary)
                                .frame(width: 30, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(.tertiarySystemGroupedBackground))
                                    Capsule()
                                        .fill(low ? Color.secondary : store.accent(dark: dark))
                                        .frame(width: geo.size.width * Double(n) / Double(maxCount))
                                }
                            }
                            .frame(height: 8)
                            Text("\(n)").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary).monospacedDigit()
                                .frame(width: 26, alignment: .trailing)
                        }
                    }
                }

                card(L.otherEx(lang)) {
                    let done = store.activities.filter { (s.activityCounts[$0.id] ?? 0) > 0 }
                    if done.isEmpty {
                        Text(L.noneYet(lang)).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        FlowRow(spacing: 6) {
                            ForEach(done) { a in
                                HStack(spacing: 5) {
                                    Text(a.name).font(.system(size: 11, weight: .bold))
                                    Text("\(s.activityCounts[a.id] ?? 0)")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundStyle(store.accent(dark: dark))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(.tertiarySystemGroupedBackground), in: .capsule)
                            }
                        }
                    }
                }

                card(L.steps(lang)) {
                    row(L.total(lang), s.totalSteps.formatted())
                    row(L.perDay(lang), (s.averageSteps ?? 0).formatted())
                }

                Text(store.startDate.map { L.since($0, lang) } ?? L.sinceNone(lang))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button { dismiss() } label: {
                    Text(L.close(lang))
                        .font(.system(size: 15, weight: .heavy))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.rgb(18, 160, 107), in: .rect(cornerRadius: 13))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
        .preferredColorScheme(store.theme == .system ? nil : (store.theme == .dark ? .dark : .light))
    }

    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 13, weight: .heavy)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 17, weight: .heavy)).monospacedDigit()
        }
    }
}

/// タグを折り返して並べる
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
