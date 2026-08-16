import SwiftUI
import YurutoreCore

/// 月カレンダー。常に6行（42マス）で描くので、月をまたいでも高さが動かない。
struct MonthGrid: View {
    @Bindable var store: AppStore
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { store.isDark(scheme) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(CalendarLayout.weekdayOrder(weekStart: store.weekStart), id: \.self) { w in
                    Text(L.weekdayShort(w, store.language))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(w == 0 ? Color.rgb(217,74,74)
                                       : w == 6 ? Color.rgb(47,111,208)
                                       : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(Array(CalendarLayout.cells(year: store.viewYear, month: store.viewMonth,
                                                   weekStart: store.weekStart).enumerated()),
                        id: \.offset) { _, date in
                    if let date {
                        DayCell(store: store, date: date, dark: dark)
                            .onTapGesture {
                                guard !store.isFuture(date) else { return }
                                Haptics.light()
                                store.editingDate = date
                            }
                    } else {
                        Color.clear.aspectRatio(1 / 1.55, contentMode: .fit)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}

/// 1マス。日付は左上、中央に点数、その下に「歩数(運動数)」。
struct DayCell: View {
    let store: AppStore
    let date: YMD
    let dark: Bool

    private var isToday: Bool { date == store.today }
    private var future: Bool { store.isFuture(date) }
    private var score: Int? { future ? nil : store.score(date) }
    private var state: DayState { store.state(date) }

    private var fill: Color {
        guard let score else { return Color(.tertiarySystemGroupedBackground) }
        return store.cellColor(score: score, dark: dark)
    }
    private var ink: Color { score == nil ? .primary : .cellInk }

    /// 例: 9230歩・運動2つ → "9k(2)" / 休養日 → "3k(休)"
    private var subLabel: String? {
        guard !future, let log = store.journal[date] else { return nil }
        let s = log.steps >= 1000 ? "\(Int((Double(log.steps) / 1000).rounded()))k" : "\(log.steps)"
        switch state {
        case .rest:   return "\(s)(\(store.language == .en ? "R" : "休"))"
        case .logged: return "\(s)(\(log.exerciseCount(activities: store.activities)))"
        case .unlogged: return s
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(fill)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, style: .init(lineWidth: borderWidth, dash: dashed ? [3, 2] : []))

            VStack(spacing: 2) {
                Text(score.map(String.init) ?? "·")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(ink)
                if let subLabel {
                    Text(subLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ink.opacity(0.72))
                        .padding(.top, 3)
                }
            }
            .padding(.top, 8)

            VStack {
                HStack {
                    Text("\(date.day)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(ink.opacity(isToday ? 1 : 0.6))
                    Spacer()
                    if store.journal[date]?.manualScore != nil {
                        Text(store.language == .en ? "M" : "手")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(ink.opacity(0.75))
                    }
                }
                Spacer()
            }
            .padding(5)
        }
        .aspectRatio(1 / 1.55, contentMode: .fit)
        .opacity(future ? 0.32 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .accessibilityAddTraits(.isButton)
    }

    /// 今日は塗りつぶされていても分かるよう、地色と対比する色で太く囲う。
    /// 合格色と同じ枠だと塗りに同化して見えなくなる。
    private var borderColor: Color {
        if isToday { return .primary }
        return state == .unlogged && !future ? Color.secondary.opacity(0.6) : .clear
    }
    private var borderWidth: CGFloat { isToday ? 3 : 1.5 }
    private var dashed: Bool { !isToday && state == .unlogged && !future }

    /// 色だけに頼らず、読み上げでも合否が分かるようにする
    private var a11y: String {
        let en = store.language == .en
        var parts: [String] = []
        if isToday { parts.append(en ? "Today" : "今日") }
        parts.append(en ? "\(date.month)/\(date.day)" : "\(date.month)月\(date.day)日")
        if let score {
            parts.append(en ? "\(score) points" : "\(score)点")
            if store.isPass(date) { parts.append(en ? "passed" : "合格") }
        }
        switch state {
        case .rest: parts.append(en ? "rest day" : "休養日")
        case .unlogged where !future: parts.append(en ? "not logged" : "未入力")
        default: break
        }
        return parts.joined(separator: " ")
    }
}
