import Foundation

// MARK: - 部位

/// 動かした部位。この6つで固定。
public enum BodyPart: String, CaseIterable, Codable, Sendable {
    case chest, back, shoulder, arm, leg, core

    /// 日本語の表示名。CSVにもこの名前で書き出す。
    public var japanese: String {
        switch self {
        case .chest: "胸"; case .back: "背"; case .shoulder: "肩"
        case .arm: "腕"; case .leg: "足"; case .core: "腹"
        }
    }

    public var english: String {
        switch self {
        case .chest: "Chest"; case .back: "Back"; case .shoulder: "Shldr"
        case .arm: "Arms"; case .leg: "Legs"; case .core: "Core"
        }
    }

    /// 日英どちらの表記からでも復元する。書き出した言語と読み込む言語が
    /// 違ってもバックアップが壊れないようにするため。
    public static func from(label: String) -> BodyPart? {
        allCases.first { $0.japanese == label || $0.english == label }
    }
}

// MARK: - 倍率

/// 1日に同じ部位を4種目やることはない、という前提で1〜3に固定。
/// 0を持たないので「選んでいない＝辞書にキーが無い」と一意に決まる。
public enum Volume: Int, CaseIterable, Codable, Sendable, Comparable {
    case one = 1, two = 2, three = 3

    public static func < (a: Volume, b: Volume) -> Bool { a.rawValue < b.rawValue }

    /// 押すたびに なし→×1→×2→×3→なし と巡回する
    public static func cycled(from current: Volume?) -> Volume? {
        switch current {
        case nil: .one
        case .one: .two
        case .two: .three
        case .three: nil
        }
    }
}

// MARK: - その他の運動

public enum ActivityUnit: String, Codable, CaseIterable, Sendable {
    case minute, meter, kilometer

    public var japanese: String {
        switch self { case .minute: "分"; case .meter: "m"; case .kilometer: "km" }
    }
    public var english: String {
        switch self { case .minute: "min"; case .meter: "m"; case .kilometer: "km" }
    }
}

/// ラジオ体操・水泳など、部位で表せない運動。
///
/// 記録は `id` で持ち、`name` は表示専用。こうしないと設定で名前を変えた
/// 瞬間に過去の記録が迷子になる。
public struct Activity: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var quantity: Int
    public var unit: ActivityUnit

    /// 換算の根拠（既定の運動のみ持つ）。ユーザーが量を変えたら失われる。
    public var met: Double?
    public var minutes: Double?

    /// その運動のうち、歩数として既に数えられてしまう割合（0...1）。
    /// 球技は走り回るぶんが歩数に入るので差し引く。
    public var stepOverlap: Double

    public init(id: String, name: String, quantity: Int, unit: ActivityUnit,
                met: Double? = nil, minutes: Double? = nil, stepOverlap: Double = 0) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.met = met
        self.minutes = minutes
        self.stepOverlap = stepOverlap
    }

    public var amountLabel: String { "\(quantity)\(unit.japanese)" }

    /// 実質の運動量（MET・分）。筋トレ1種目 ≒ 25 が基準。
    public var effectiveMetMinutes: Int? {
        guard let met, let minutes else { return nil }
        return Int((met * minutes * (1 - stepOverlap)).rounded())
    }

    /// 既定の6種目。ジョギングとダッシュは歩数に必ず入るので置かない。
    public static let defaults: [Activity] = [
        .init(id: "radio",   name: "ラジオ体操", quantity: 5,  unit: .minute, met: 4.0, minutes: 5),
        .init(id: "stretch", name: "ストレッチ", quantity: 10, unit: .minute, met: 2.3, minutes: 10),
        .init(id: "yoga",    name: "ヨガ",       quantity: 10, unit: .minute, met: 2.5, minutes: 10),
        .init(id: "swim",    name: "水泳",       quantity: 5,  unit: .minute, met: 6.0, minutes: 5),
        .init(id: "bike",    name: "自転車",     quantity: 5,  unit: .minute, met: 5.0, minutes: 5),
        .init(id: "ball",    name: "球技",       quantity: 30, unit: .minute, met: 6.0, minutes: 30,
              stepOverlap: 0.85)
    ]
}

// MARK: - 1日の記録

/// 1日の状態。歩数は自動で入るので「記録が無い日」は存在しない。
public enum DayState: Sendable {
    /// まだ本人が何も入力していない（カレンダーでは破線）
    case unlogged
    /// 運動しないと決めた日（歩数の点は入る）
    case rest
    /// 運動を1つ以上記録した
    case logged
}

public struct DayLog: Codable, Equatable, Sendable {
    /// ヘルスケアから入る歩数
    public var steps: Int
    /// 部位ごとの倍率。同じ部位に2つの値は入らない。
    public var parts: [BodyPart: Volume]
    /// その他の運動。キーは Activity.id
    public var activities: [String: Volume]
    /// 点数を直接指定した場合（20〜100の10刻み）
    public var manualScore: Int?
    /// 運動しないと決めた日
    public var isRest: Bool
    /// 確定した点数。3日経つと焼き付けられ、以後は設定を変えても動かない。
    public var lockedScore: Int?
    public init(steps: Int = 0,
                parts: [BodyPart: Volume] = [:],
                activities: [String: Volume] = [:],
                manualScore: Int? = nil,
                isRest: Bool = false,
                lockedScore: Int? = nil) {
        self.steps = steps
        self.parts = parts
        self.activities = activities
        self.manualScore = manualScore
        self.isRest = isRest
        self.lockedScore = lockedScore
    }

    /// 設定にある運動だけを数える。消された運動のidが残っていても無視する。
    public func exerciseCount(activities known: [Activity]) -> Int {
        let partSum = parts.values.reduce(0) { $0 + $1.rawValue }
        let ids = Set(known.map(\.id))
        let actSum = self.activities
            .filter { ids.contains($0.key) }
            .values.reduce(0) { $0 + $1.rawValue }
        return partSum + actSum
    }

    public func state(activities known: [Activity]) -> DayState {
        if exerciseCount(activities: known) > 0 { return .logged }
        return isRest ? .rest : .unlogged
    }

    /// 運動を足したら休養日は自動で外れる
    public mutating func setPart(_ part: BodyPart, to volume: Volume?) {
        if let volume { parts[part] = volume; isRest = false }
        else { parts[part] = nil }
    }

    public mutating func setActivity(_ id: String, to volume: Volume?) {
        if let volume { activities[id] = volume; isRest = false }
        else { activities[id] = nil }
    }

    /// 休養日にすると運動の記録は消える
    public mutating func setRest(_ on: Bool) {
        isRest = on
        if on { parts.removeAll(); activities.removeAll() }
    }
}

// MARK: - 辞書のキーに enum を使うための対応

/// `[BodyPart: Volume]` を素直なJSONにするために必要。
/// これが無いとキーと値が交互に並んだ配列になり、人が読めない。
extension BodyPart: CodingKeyRepresentable {
    public var codingKey: any CodingKey { RawKey(stringValue: rawValue) }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(rawValue: codingKey.stringValue)
    }

    private struct RawKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
