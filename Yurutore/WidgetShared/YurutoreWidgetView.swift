import SwiftUI
import WidgetKit
import YurutoreCore

/// 2×2の中身。出すものは4つだけ。
///
/// 1. 今日の合計点
/// 2. 歩数と種目それぞれの記号
/// 3. それぞれの達成ぐあい（◯／◯）
/// 4. それぞれの点数
///
/// **「あと何歩」は書かない。** 輪の欠けを見れば分かるので、
/// 同じことを2回言うと、そのぶん字が小さくなる。
///
/// 地の色は、その日の段階の色。**カレンダーのマスをそのまま大きくしたもの**にする。
/// アプリで選んだ配色がそのまま出るので、100点の日は100点の色になる。
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
                    .font(.system(size: 24, weight: .semibold))
                Text("アプリを開くと\nここに今日が出ます")
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func content(_ s: WidgetSnapshot) -> some View {
        VStack(spacing: 0) {
            score(s)
            Spacer(minLength: 2)
            HStack(spacing: 0) {
                gauge(progress: s.stepGauge, state: s.stepState, symbol: "figure.walk",
                      value: shortSteps(s.steps), points: s.stepScore)
                    .frame(maxWidth: .infinity)
                gauge(progress: s.exerciseGauge, state: s.exerciseState, symbol: "dumbbell.fill",
                      value: "\(s.exercises)/\(s.passExercises)", points: s.exerciseScore)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        // マスの文字は、どの段階の色の上でも読めるように作ってある（PaletteTests）
        .foregroundStyle(Color.cellInk)
    }

    /// 合計点。地が段階の色なので、文字は黒で置くだけでよい
    private func score(_ s: WidgetSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(s.total)")
                .font(.system(size: 36, weight: .heavy))
                .monospacedDigit()
            Text("点")
                .font(.system(size: 12, weight: .heavy))
        }
        .frame(maxWidth: .infinity)
    }

    /// 輪1つ。**40点で一周。** 濃さはその輪だけの達成ぐあいで決める。
    /// 届いた側だけがはっきり出るので、どちらが残っているか一目で分かる。
    private func gauge(progress: Double, state: WidgetSnapshot.GaugeState,
                       symbol: String, value: String, points: Int) -> some View {
        let strength: Double = switch state {
        case .reached:  1.0
        case .partway:  0.55
        case .none:     0.35
        }
        return VStack(spacing: 2) {
            ZStack {
                Circle().stroke(Color.cellInk.opacity(0.15), lineWidth: 7)
                // 0のときは描かない。丸い端だけが残ると、進んでいるように見える
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.cellInk.opacity(strength),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .opacity(strength)
            }
            .frame(width: 54, height: 54)
            Text(value)
                .font(.system(size: 14, weight: .heavy)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(points)点")
                .font(.system(size: 11, weight: .bold))
                .opacity(0.65)
        }
    }

    /// 「8.2k」に縮める。小さい枠で桁を並べると読めない
    private func shortSteps(_ n: Int) -> String {
        guard n >= 1000 else { return "\(n)" }
        let k = Double(n) / 1000
        return k >= 10 ? "\(Int(k.rounded()))k"
                       : String(format: "%.1fk", k)
    }
}

extension WidgetSnapshot {
    /// ウィジェットの地の色。カレンダーのマスと同じ色にする。
    func background(dark: Bool) -> Color { Color(hex: fill(dark: dark)) }
}
