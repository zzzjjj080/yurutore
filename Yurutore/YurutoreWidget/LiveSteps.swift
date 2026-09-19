import Foundation
import HealthKit
import YurutoreCore

/// ウィジェットが自分で読む、今日の歩数。
///
/// **本来ウィジェットは何も計算しない方針だが、歩数だけは例外にしている。**
/// 歩数はアプリが書き込むまで更新されず、アプリを開かない日は古いまま止まる。
/// ここで読めば、ウィジェットが組み直されるたびに今の歩数になる。
///
/// 許可を求めるのはアプリ本体だけ。ここは読むだけで、断られたら黙って諦める
/// （アプリが書いた値をそのまま使う）。
enum LiveSteps {
    static func today() async -> Int? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()
        let type = HKQuantityType(.stepCount)

        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type,
                                       predicate: HKQuery.predicateForSamples(withStart: start,
                                                                              end: now)),
            options: .cumulativeSum)

        guard let stats = try? await descriptor.result(for: store),
              let sum = stats.sumQuantity() else { return nil }
        return Int(sum.doubleValue(for: HKUnit.count()))
    }
}
