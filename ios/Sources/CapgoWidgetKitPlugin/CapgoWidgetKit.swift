import Foundation

enum CapgoWidgetKitBridgeError: LocalizedError {
    case missingSession
    case invalidObject(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "The `session` object is required."
        case .invalidObject(let message):
            return message
        }
    }
}

public final class CapgoWidgetKit {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func areActivitiesSupported() -> [String: Any] {
        let result = WorkoutLiveActivityManager.shared.areActivitiesSupported()
        var payload: [String: Any] = ["supported": result.0]
        if let reason = result.1 {
            payload["reason"] = reason
        }
        return payload
    }

    public func startWorkoutLiveActivity(sessionObject: [String: Any]) async throws -> [String: Any] {
        let session = try decodeSession(from: sessionObject)
        let result = try await WorkoutLiveActivityManager.shared.start(session: session)
        return [
            "activityId": result.activityId,
            "sessionId": result.sessionId
        ]
    }

    public func updateWorkoutLiveActivity(activityId: String, sessionObject: [String: Any]) async throws {
        let session = try decodeSession(from: sessionObject)
        try await WorkoutLiveActivityManager.shared.update(activityId: activityId, session: session)
    }

    public func endWorkoutLiveActivity(activityId: String, sessionObject: [String: Any]?) async throws {
        let finalSession = try sessionObject.map(decodeSession(from:))
        try await WorkoutLiveActivityManager.shared.end(activityId: activityId, finalSession: finalSession)
    }

    public func completeWorkoutSet(sessionId: String, activityId: String?) async throws -> [String: Any] {
        let session = try await WorkoutLiveActivityManager.shared.completeSet(sessionId: sessionId, activityId: activityId)
        return ["session": try encodeSession(session) as Any]
    }

    public func getStoredWorkoutSession(sessionId: String?, activityId: String?) throws -> [String: Any] {
        let session = try WorkoutLiveActivityManager.shared.storedSession(sessionId: sessionId, activityId: activityId)
        if let session {
            return ["session": try encodeSession(session)]
        }
        return ["session": NSNull()]
    }

    public func listWorkoutLiveActivities() throws -> [String: Any] {
        let activities = try WorkoutLiveActivityManager.shared.listActivities().map { info in
            [
                "activityId": info.activityId,
                "sessionId": info.sessionId,
                "state": info.state,
                "updatedAt": info.updatedAtMs
            ]
        }
        return ["activities": activities]
    }

    public func getPluginVersion() -> [String: Any] {
        [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ios"
        ]
    }

    private func decodeSession(from object: [String: Any]) throws -> WorkoutSession {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CapgoWidgetKitBridgeError.invalidObject("The workout session payload contains unsupported values.")
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return try decoder.decode(WorkoutSession.self, from: data)
    }

    private func encodeSession(_ session: WorkoutSession) throws -> [String: Any] {
        let data = try encoder.encode(session)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = jsonObject as? [String: Any] else {
            throw CapgoWidgetKitBridgeError.invalidObject("Failed to encode the workout session for JavaScript.")
        }
        return dictionary
    }
}
