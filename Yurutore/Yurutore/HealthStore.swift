import Foundation
import HealthKit
import YurutoreCore

/// 歩数の読み取りだけを行う。書き込みは一切しない。
///
/// 読んだ値は端末の外に出さない。ネットワーク通信はアプリ全体で行っていない。
@MainActor
@Observable
final class HealthStore {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    /// 失敗したときは黙って諦めず、理由を残す。
    /// 無反応が一番たちが悪い（実際にエンタイトルメント漏れを見逃した）。
    private(set) var lastError: String?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var lastReadSucceeded = false

    /// 許可されているか。HealthKitは読み取り許可の有無を直接は教えないので、
    /// 実際に読めたかどうかで判断する。
    var isAuthorized: Bool { lastReadSucceeded }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastError = "この端末ではヘルスケアを利用できません"
            return false
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - 歩数が増えたら知らせてもらう

    /// 歩数の更新を見張る。
    ///
    /// **これが無いと、アプリを開くまでウィジェットの歩数が古いままになる。**
    /// ヘルスケアに歩数が入るとアプリが裏で起こされ、読み直して書き込める。
    ///
    /// 呼び出しは1回だけ。`HKObserverQuery` はアプリを入れ直すまで残る。
    func startWatchingSteps(_ onUpdate: @escaping @Sendable () async -> Void) {
        guard isAvailable else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, error in
            Task {
                await onUpdate()
                // **必ず呼ぶ。** 呼ばないとOSが「処理できなかった」と判断して、
                // そのうち起こしてくれなくなる
                completion()
            }
        }
        store.execute(query)

        // 歩数の最短は1時間ごと。これより短くは指定できない
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { [weak self] ok, error in
            guard !ok, let error else { return }
            Task { @MainActor in self?.lastError = error.localizedDescription }
        }
    }

    /// 指定した期間の日別歩数
    func dailySteps(from: YMD, to: YMD) async -> [YMD: Int] {
        guard isAvailable else { return [:] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current

        guard let start = cal.date(from: DateComponents(year: from.year, month: from.month, day: from.day)),
              let endBase = cal.date(from: DateComponents(year: to.year, month: to.month, day: to.day)),
              let end = cal.date(byAdding: .day, value: 1, to: endBase)
        else { return [:] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1))

        do {
            let results = try await descriptor.result(for: store)
            var out: [YMD: Int] = [:]
            results.enumerateStatistics(from: start, to: end) { stats, _ in
                guard let sum = stats.sumQuantity() else { return }
                let c = cal.dateComponents([.year, .month, .day], from: stats.startDate)
                out[YMD(c.year!, c.month!, c.day!)] = Int(sum.doubleValue(for: .count()))
            }
            // 歩数が1件も無くても、問い合わせ自体が通れば許可はされている。
            // 「許可したのにバナーが消えない」を防ぐため、ここで許可済みとみなす。
            lastReadSucceeded = true
            lastError = nil
            return out
        } catch {
            lastError = error.localizedDescription
            return [:]
        }
    }
}
