import Foundation

public struct WorkoutNotificationSettings: Codable, Hashable, Sendable {
    public var enabled: Bool
    public var title: String?
    public var body: String?

    public init(enabled: Bool, title: String? = nil, body: String? = nil) {
        self.enabled = enabled
        self.title = title
        self.body = body
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case title
        case body
    }

    public init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        if let enabled = try? singleValueContainer.decode(Bool.self) {
            self = .init(enabled: enabled)
            return
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try keyed.decode(Bool.self, forKey: .enabled)
        title = try keyed.decodeIfPresent(String.self, forKey: .title)
        body = try keyed.decodeIfPresent(String.self, forKey: .body)
    }
}

public struct WorkoutSet: Codable, Hashable, Sendable {
    public var id: String?
    public var title: String
    public var recommendation: String?
    public var completedAt: Int64?
    public var timerDurationMs: Int64?
    public var nextExerciseIndex: Int?
    public var nextSetIndex: Int?

    public init(
        title: String,
        id: String? = nil,
        recommendation: String? = nil,
        completedAt: Int64? = nil,
        timerDurationMs: Int64? = nil,
        nextExerciseIndex: Int? = nil,
        nextSetIndex: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.recommendation = recommendation
        self.completedAt = completedAt
        self.timerDurationMs = timerDurationMs
        self.nextExerciseIndex = nextExerciseIndex
        self.nextSetIndex = nextSetIndex
    }
}

public struct WorkoutExercise: Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var iconSystemName: String?
    public var imageAssetName: String?
    public var sets: [WorkoutSet]

    public init(
        id: String,
        title: String,
        sets: [WorkoutSet],
        subtitle: String? = nil,
        iconSystemName: String? = nil,
        imageAssetName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sets = sets
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.imageAssetName = imageAssetName
    }
}

public struct WorkoutSetReference: Hashable, Sendable {
    public let exerciseIndex: Int
    public let setIndex: Int
    public let set: WorkoutSet
    public let exercise: WorkoutExercise
}

public struct WorkoutActiveTimer: Hashable, Sendable {
    public let source: WorkoutSetReference
    public let startedAtMs: Int64
    public let durationMs: Int64

    public var endAtMs: Int64 {
        startedAtMs + durationMs
    }

    public func remainingMs(now: Date = Date()) -> Int64 {
        max(0, endAtMs - Int64(now.timeIntervalSince1970 * 1000))
    }

    public func isActive(now: Date = Date()) -> Bool {
        remainingMs(now: now) > 0
    }

    public func progress(now: Date = Date()) -> Double {
        guard durationMs > 0 else {
            return 0
        }
        let elapsed = Double(Int64(now.timeIntervalSince1970 * 1000) - startedAtMs)
        return min(max(elapsed / Double(durationMs), 0), 1)
    }

    public func remainingText(now: Date = Date()) -> String {
        let totalSeconds = Int(ceil(Double(remainingMs(now: now)) / 1000.0))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

public struct WorkoutSession: Codable, Hashable, Sendable {
    public var sessionId: String
    public var title: String
    public var startedAt: Int64
    public var activeExerciseIndex: Int?
    public var activeSetIndex: Int?
    public var deepLinkUrl: String?
    public var timerNotifications: WorkoutNotificationSettings?
    public var sessionNotifications: WorkoutNotificationSettings?
    public var exercises: [WorkoutExercise]

    public init(
        sessionId: String,
        title: String,
        startedAt: Int64,
        exercises: [WorkoutExercise],
        activeExerciseIndex: Int? = nil,
        activeSetIndex: Int? = nil,
        deepLinkUrl: String? = nil,
        timerNotifications: WorkoutNotificationSettings? = nil,
        sessionNotifications: WorkoutNotificationSettings? = nil
    ) {
        self.sessionId = sessionId
        self.title = title
        self.startedAt = startedAt
        self.exercises = exercises
        self.activeExerciseIndex = activeExerciseIndex
        self.activeSetIndex = activeSetIndex
        self.deepLinkUrl = deepLinkUrl
        self.timerNotifications = timerNotifications
        self.sessionNotifications = sessionNotifications
    }

    public var isComplete: Bool {
        activeExerciseIndex == nil || activeSetIndex == nil
    }

    public var currentExercise: WorkoutExercise? {
        guard let activeExerciseIndex, exercises.indices.contains(activeExerciseIndex) else {
            return nil
        }
        return exercises[activeExerciseIndex]
    }

    public var currentSet: WorkoutSet? {
        guard let activeSetIndex, let currentExercise, currentExercise.sets.indices.contains(activeSetIndex) else {
            return nil
        }
        return currentExercise.sets[activeSetIndex]
    }

    public func currentSetReference() -> WorkoutSetReference? {
        guard
            let activeExerciseIndex,
            exercises.indices.contains(activeExerciseIndex),
            let activeSetIndex,
            exercises[activeExerciseIndex].sets.indices.contains(activeSetIndex)
        else {
            return nil
        }

        let exercise = exercises[activeExerciseIndex]
        return WorkoutSetReference(
            exerciseIndex: activeExerciseIndex,
            setIndex: activeSetIndex,
            set: exercise.sets[activeSetIndex],
            exercise: exercise
        )
    }

    public func previousSetReference() -> WorkoutSetReference? {
        guard let activeExerciseIndex, let activeSetIndex else {
            return nil
        }

        for (exerciseIndex, exercise) in exercises.enumerated() {
            for (setIndex, set) in exercise.sets.enumerated() {
                if set.nextExerciseIndex == activeExerciseIndex, set.nextSetIndex == activeSetIndex {
                    return WorkoutSetReference(
                        exerciseIndex: exerciseIndex,
                        setIndex: setIndex,
                        set: set,
                        exercise: exercise
                    )
                }
            }
        }

        return nil
    }

    public func activeTimer(now: Date = Date()) -> WorkoutActiveTimer? {
        guard
            let previous = previousSetReference(),
            let completedAt = previous.set.completedAt,
            let duration = previous.set.timerDurationMs,
            duration > 0
        else {
            return nil
        }

        let timer = WorkoutActiveTimer(
            source: previous,
            startedAtMs: completedAt,
            durationMs: duration
        )

        return timer.isActive(now: now) ? timer : nil
    }

    public mutating func completeActiveSet(at timestampMs: Int64) {
        guard
            let currentExerciseIndex = activeExerciseIndex,
            exercises.indices.contains(currentExerciseIndex),
            let currentSetIndex = activeSetIndex,
            exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex)
        else {
            return
        }

        exercises[currentExerciseIndex].sets[currentSetIndex].completedAt = timestampMs
        let completedSet = exercises[currentExerciseIndex].sets[currentSetIndex]
        activeExerciseIndex = completedSet.nextExerciseIndex
        activeSetIndex = completedSet.nextSetIndex
    }

    public func exerciseCompleted(at index: Int) -> Bool {
        guard exercises.indices.contains(index) else {
            return false
        }

        if let activeExerciseIndex {
            if index < activeExerciseIndex {
                return true
            }
            if index > activeExerciseIndex {
                return false
            }
        } else if isComplete {
            return true
        }

        return exercises[index].sets.allSatisfy { $0.completedAt != nil }
    }
}
