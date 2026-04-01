#if canImport(AppIntents)
import AppIntents

@available(iOS 17.0, *)
public struct CompleteSetIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Complete Set"
    public static var description = IntentDescription("Mark the current workout set as completed and advance the live activity.")
    public static var openAppWhenRun = false

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    public func perform() async throws -> some IntentResult {
        _ = try await WorkoutLiveActivityManager.shared.completeSet(sessionId: sessionId, activityId: nil)
        return .result()
    }
}
#endif
