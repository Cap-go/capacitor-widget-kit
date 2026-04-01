#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import UserNotifications

public struct WorkoutActivityInfo: Hashable, Sendable {
    public let activityId: String
    public let sessionId: String
    public let state: String
    public let updatedAtMs: Int64
}

#if canImport(ActivityKit)
@available(iOS 16.2, *)
public struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable {
        public var revision: Int
        public var activeExerciseIndex: Int?
        public var activeSetIndex: Int?
        public var timerStartedAtMs: Int64?
        public var timerDurationMs: Int64?
        public var isComplete: Bool
    }

    public var sessionId: String
    public var title: String
    public var deepLinkUrl: String?

    public init(sessionId: String, title: String, deepLinkUrl: String?) {
        self.sessionId = sessionId
        self.title = title
        self.deepLinkUrl = deepLinkUrl
    }
}
#endif

public final class WorkoutLiveActivityManager {
    public static let shared = WorkoutLiveActivityManager()

    private init() {}

    public func areActivitiesSupported() -> (Bool, String?) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            let authorizationInfo = ActivityAuthorizationInfo()
            guard authorizationInfo.areActivitiesEnabled else {
                return (false, "Live Activities are disabled in Settings.")
            }
            return (true, nil)
        }
        return (false, "iOS 16.2 or later is required for the native workout live activity.")
        #else
        return (false, "ActivityKit is unavailable in this build configuration.")
        #endif
    }

    public func start(session: WorkoutSession) async throws -> (activityId: String, sessionId: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else {
            throw WorkoutActivityStoreError.missingAppGroup
        }

        let store = try WorkoutActivityStore.make()
        let updatedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        var envelope = StoredWorkoutEnvelope(
            session: session,
            revision: (store.loadEnvelope(sessionId: session.sessionId)?.revision ?? 0) + 1,
            activityId: nil,
            updatedAtMs: updatedAtMs
        )
        try store.saveEnvelope(envelope)

        let attributes = WorkoutActivityAttributes(
            sessionId: session.sessionId,
            title: session.title,
            deepLinkUrl: session.deepLinkUrl
        )
        let content = ActivityContent(state: makeContentState(from: envelope), staleDate: nil)
        let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)

        envelope.activityId = activity.id
        try store.saveEnvelope(envelope)
        store.setActivityId(activity.id, forSessionId: session.sessionId)
        scheduleTimerNotificationIfNeeded(for: session)

        return (activity.id, session.sessionId)
        #else
        throw WorkoutActivityStoreError.missingAppGroup
        #endif
    }

    public func update(activityId: String, session: WorkoutSession) async throws {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else {
            return
        }

        let store = try WorkoutActivityStore.make()
        let current = store.loadEnvelope(sessionId: session.sessionId)
        let envelope = StoredWorkoutEnvelope(
            session: session,
            revision: (current?.revision ?? 0) + 1,
            activityId: activityId,
            updatedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        try store.saveEnvelope(envelope)
        store.setActivityId(activityId, forSessionId: session.sessionId)

        if let activity = activity(with: activityId) {
            await activity.update(ActivityContent(state: makeContentState(from: envelope), staleDate: nil))
        }

        scheduleTimerNotificationIfNeeded(for: session)
        #endif
    }

    public func end(activityId: String, finalSession: WorkoutSession?) async throws {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else {
            return
        }

        let store = try WorkoutActivityStore.make()
        if let finalSession {
            let current = store.loadEnvelope(sessionId: finalSession.sessionId)
            let envelope = StoredWorkoutEnvelope(
                session: finalSession,
                revision: (current?.revision ?? 0) + 1,
                activityId: nil,
                updatedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
            try store.saveEnvelope(envelope)
        }

        if let activity = activity(with: activityId), let sessionId = store.sessionId(forActivityId: activityId) {
            let envelope = store.loadEnvelope(sessionId: sessionId)
            if let envelope {
                await activity.end(ActivityContent(state: makeContentState(from: envelope), staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        store.removeActivityId(activityId)
        #endif
    }

    @discardableResult
    public func completeSet(sessionId: String, activityId: String?) async throws -> WorkoutSession {
        let store = try WorkoutActivityStore.make()
        guard var envelope = store.loadEnvelope(sessionId: sessionId) else {
            throw NSError(domain: "CapgoWidgetKit", code: 404, userInfo: [NSLocalizedDescriptionKey: "No stored session found for \(sessionId)."])
        }

        envelope.session.completeActiveSet(at: Int64(Date().timeIntervalSince1970 * 1000))
        envelope.revision += 1
        envelope.updatedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        try store.saveEnvelope(envelope)

        let resolvedActivityId = activityId ?? envelope.activityId
        if let resolvedActivityId {
            store.setActivityId(resolvedActivityId, forSessionId: sessionId)
            try await update(activityId: resolvedActivityId, session: envelope.session)
        } else {
            scheduleTimerNotificationIfNeeded(for: envelope.session)
        }

        return envelope.session
    }

    public func storedSession(sessionId: String?, activityId: String?) throws -> WorkoutSession? {
        let store = try WorkoutActivityStore.make()

        if let sessionId {
            return store.loadEnvelope(sessionId: sessionId)?.session
        }

        if let activityId, let sessionId = store.sessionId(forActivityId: activityId) {
            return store.loadEnvelope(sessionId: sessionId)?.session
        }

        return nil
    }

    public func listActivities() throws -> [WorkoutActivityInfo] {
        let store = try WorkoutActivityStore.make()
        let activeIds: Set<String>
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            activeIds = Set(Activity<WorkoutActivityAttributes>.activities.map(\.id))
        } else {
            activeIds = []
        }
        #else
        activeIds = []
        #endif

        return store.allActivityMappings().compactMap { activityId, sessionId in
            guard let envelope = store.loadEnvelope(sessionId: sessionId) else {
                return nil
            }
            return WorkoutActivityInfo(
                activityId: activityId,
                sessionId: sessionId,
                state: activeIds.contains(activityId) ? "active" : "ended",
                updatedAtMs: envelope.updatedAtMs
            )
        }
        .sorted { $0.updatedAtMs > $1.updatedAtMs }
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private func makeContentState(from envelope: StoredWorkoutEnvelope) -> WorkoutActivityAttributes.ContentState {
        let timer = envelope.session.activeTimer()
        return WorkoutActivityAttributes.ContentState(
            revision: envelope.revision,
            activeExerciseIndex: envelope.session.activeExerciseIndex,
            activeSetIndex: envelope.session.activeSetIndex,
            timerStartedAtMs: timer?.startedAtMs,
            timerDurationMs: timer?.durationMs,
            isComplete: envelope.session.isComplete
        )
    }

    @available(iOS 16.2, *)
    private func activity(with activityId: String) -> Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == activityId })
    }
    #endif

    private func scheduleTimerNotificationIfNeeded(for session: WorkoutSession) {
        let notificationId = "capgo.widgetkit.timer.\(session.sessionId)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        guard let notificationSettings = session.timerNotifications, notificationSettings.enabled else {
            return
        }

        guard let timer = session.activeTimer(), timer.isActive() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notificationSettings.title ?? "Rest finished"
        content.body = notificationSettings.body ?? defaultTimerBody(for: session)
        content.sound = .default

        let seconds = max(1, Int(ceil(Double(timer.remainingMs()) / 1000.0)))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        center.add(request)
    }

    private func defaultTimerBody(for session: WorkoutSession) -> String {
        if let nextSet = session.currentSet {
            return "Start your next set: \(nextSet.title)"
        }
        return "Continue your session \(session.title)."
    }
}
