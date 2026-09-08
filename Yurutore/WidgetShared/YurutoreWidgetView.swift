import SwiftUI
import WidgetKit
import YurutoreCore

/// 2×2の中身。**ぱっと見て「あとどれくらいか」が分かることだけを狙う。**
///
/// 数字を並べても読まれないので、輪の欠けで残りを見せる。
/// 輪は合格ラインを一周とし、超えても回し続けない（達成が分かりにくくなる）。
struct TodayWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let snapshot: WidgetSnapshot?

    private var dark: Bool { scheme == .dark }

    var body: some View {
        if let s = snapshot {
            content(s)
        } else {
            // 一度もアプリを開いていないとき
            VStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("アプリを開くと\nここに今日が出ます")
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func content(_ s: WidgetSnapshot) -> some View {
        let ink = Color(hex: s.ink(dark: dark))
        return VStack(spacing: 0) {
            header(s, ink: ink)
            Spacer(minLength: 4)
            HStack(spacing: 10) {
                gauge(progress: s.stepProgress, symbol: "figure.walk",
                      value: shortSteps(s.steps), points: s.stepScore, ink: ink)
                gauge(progress: s.exerciseProgress, symbol: "dumbbell.fill",
                      value: "\(s.exercises)/\(s.passExercises)", points: s.exerciseScore, ink: ink)
            }
            Spacer(minLength: 4)
            footer(s, ink: ink)
        }
    }

    /// 上段：日付と合計点。点は段階の色で塗る
    private func header(_ s: WidgetSnapshot, ink: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(s.date.month)/\(s.date.day)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Text("\(s.total)")
                .font(.system(size: 26, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Color.cellInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Color(hex: s.fill(dark: dark)), in: .rect(cornerRadius: 7))
            Text("点").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
        }
    }

    /// 輪1つ。中に記号、下に「いまの値」と「点」
    private func gauge(progress: Double, symbol: String,
                       value: String, points: Int, ink: Color) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(ink.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.001, progress))
                    .stroke(ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ink)
            }
            .frame(width: 46, height: 46)
            Text(value)
                .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(points)点")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    /// 下段：あとどれくらいか。ここがこのウィジェットの用件
    private func footer(_ s: WidgetSnapshot, ink: Color) -> some View {
        Text(remaining(s))
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(s.isPass ? ink : .primary)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
    }

    private func remaining(_ s: WidgetSnapshot) -> String {
        if s.total >= 100 { return "満点" }
        if s.isPass { return "合格" }
        var parts: [String] = []
        // **残りは丸めない。** 「あと1.8k歩」では、何歩歩けばいいのか分からない
        if s.stepsLeft > 0 { parts.append("あと\(s.stepsLeft.formatted())歩") }
        if s.exercisesLeft > 0 { parts.append("\(s.exercisesLeft)種目") }
        if parts.isEmpty { return s.isRest ? "休養日" : "もう少し" }
        return parts.joined(separator: "・")
    }

    /// いまの値は「8.2k」に縮める。小さい枠で桁を並べると読めない。
    /// **残りには使わない。** あちらは正確な数字が要る。
    private func shortSteps(_ n: Int) -> String {
        guard n >= 1000 else { return "\(n)" }
        let k = Double(n) / 1000
        return k >= 10 ? "\(Int(k.rounded()))k"
                       : String(format: "%.1fk", k)
    }
}
