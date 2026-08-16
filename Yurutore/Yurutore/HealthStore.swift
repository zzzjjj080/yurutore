import Foundation
import HealthKit
import YurutoreCore

/// 歩数の読み取りだけを行う。書き込みは一切しない。
///
/// 読んだ値は端末の外に出さない。ネットワーク通信はアプリ全体で行っていない。
@MainActor
final class HealthStore {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 許可されているか。HealthKitは読み取り許可の有無を直接は教えないので、
    /// 実際に読めたかどうかで判断する。
    var isAuthorized: Bool {
        store.authorizationStatus(for: stepType) == .sharingAuthorized
            || lastReadSucceeded
    }
    private var lastReadSucceeded = false

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            return true
        } catch {
            return false
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
            lastReadSucceeded = !out.isEmpty
            return out
        } catch {
            return [:]
        }
    }
}
