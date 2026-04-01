import Foundation

enum CapgoWidgetKitBridgeError: LocalizedError {
    case missingObject(String)
    case invalidObject(String)

    var errorDescription: String? {
        switch self {
        case .missingObject(let name):
            return "The `\(name)` object is required."
        case .invalidObject(let message):
            return message
        }
    }
}

public final class CapgoWidgetKit {
    public init() {}

    public func areActivitiesSupported() -> [String: Any] {
        let result = TemplateLiveActivityManager.shared.areActivitiesSupported()
        var payload: [String: Any] = ["supported": result.0]
        if let reason = result.1 {
            payload["reason"] = reason
        }
        return payload
    }

    public func startTemplateActivity(
        activityId: String?,
        definitionObject: [String: Any],
        stateObject: [String: Any],
        openUrl: String?
    ) async throws -> [String: Any] {
        let envelope = try await TemplateLiveActivityManager.shared.start(
            activityId: activityId,
            definitionObject: definitionObject,
            stateObject: stateObject,
            openUrl: openUrl
        )
        return ["activity": try TemplateRuntime.serializeActivity(envelope)]
    }

    public func updateTemplateActivity(
        activityId: String,
        definitionObject: [String: Any]?,
        stateObject: [String: Any]?,
        openUrl: String?
    ) async throws -> [String: Any] {
        let envelope = try await TemplateLiveActivityManager.shared.update(
            activityId: activityId,
            definitionObject: definitionObject,
            stateObject: stateObject,
            openUrl: openUrl
        )

        if let envelope {
            return ["activity": try TemplateRuntime.serializeActivity(envelope)]
        }

        return ["activity": NSNull()]
    }

    public func endTemplateActivity(activityId: String, stateObject: [String: Any]?) async throws {
        try await TemplateLiveActivityManager.shared.end(activityId: activityId, finalStateObject: stateObject)
    }

    public func performTemplateAction(
        activityId: String,
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?
    ) async throws -> [String: Any] {
        let (envelope, event) = try await TemplateLiveActivityManager.shared.performAction(
            activityId: activityId,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        )

        return [
            "activity": try TemplateRuntime.serializeActivity(envelope),
            "event": try TemplateRuntime.serializeEvent(event)
        ]
    }

    public func getTemplateActivity(activityId: String) throws -> [String: Any] {
        guard let envelope = try TemplateLiveActivityManager.shared.activity(activityId: activityId) else {
            return ["activity": NSNull()]
        }
        return ["activity": try TemplateRuntime.serializeActivity(envelope)]
    }

    public func listTemplateActivities() throws -> [String: Any] {
        let store = try TemplateActivityStore.make()
        let activities = try store.listEnvelopes().map(TemplateRuntime.serializeActivity)
        return ["activities": activities]
    }

    public func listTemplateEvents(activityId: String?, unacknowledgedOnly: Bool) throws -> [String: Any] {
        let events = try TemplateLiveActivityManager.shared
            .listEvents(activityId: activityId, unacknowledgedOnly: unacknowledgedOnly)
            .map(TemplateRuntime.serializeEvent)
        return ["events": events]
    }

    public func acknowledgeTemplateEvents(activityId: String?, eventIds: [String]?) throws {
        try TemplateLiveActivityManager.shared.acknowledgeEvents(activityId: activityId, eventIds: eventIds)
    }

    public func getPluginVersion() -> [String: Any] {
        [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ios"
        ]
    }
}
