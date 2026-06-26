import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum CapgoWidgetKitBridgeError: LocalizedError {
    case missingObject(String)
    case invalidObject(String)

    public var errorDescription: String? {
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
        openUrl: String?,
        startLiveActivity: Bool
    ) async throws -> [String: Any] {
        let envelope = try await TemplateLiveActivityManager.shared.start(
            activityId: activityId,
            definitionObject: definitionObject,
            stateObject: stateObject,
            openUrl: openUrl,
            startLiveActivity: startLiveActivity
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

    public func startWidgetSession(
        widgetId: String?,
        kind: String?,
        stateObject: [String: Any]?,
        metadataObject: [String: Any]?
    ) throws -> [String: Any] {
        let session = try CapgoNativeWidgetBridge().startSession(
            widgetId: widgetId,
            kind: kind,
            stateObject: stateObject ?? [:],
            metadataObject: metadataObject
        )
        reloadWidgets(kind: nil)
        return ["session": try CapgoNativeWidgetBridge.serializeSession(session)]
    }

    public func updateWidgetSession(
        widgetId: String,
        stateObject: [String: Any]?,
        metadataObject: [String: Any]?,
        merge: Bool
    ) throws -> [String: Any] {
        let session = try CapgoNativeWidgetBridge().updateSession(
            widgetId: widgetId,
            stateObject: stateObject,
            metadataObject: metadataObject,
            merge: merge
        )
        guard let session else {
            return ["session": NSNull()]
        }
        reloadWidgets(kind: nil)
        return ["session": try CapgoNativeWidgetBridge.serializeSession(session)]
    }

    public func stopWidgetSession(widgetId: String, stateObject: [String: Any]?) throws {
        try CapgoNativeWidgetBridge().stopSession(widgetId: widgetId, stateObject: stateObject)
        reloadWidgets(kind: nil)
    }

    public func getWidgetSession(widgetId: String) throws -> [String: Any] {
        let session = try CapgoNativeWidgetBridge().loadSession(widgetId: widgetId)
        guard let session else {
            return ["session": NSNull()]
        }
        return ["session": try CapgoNativeWidgetBridge.serializeSession(session)]
    }

    public func listWidgetSessions() throws -> [String: Any] {
        let sessions = try CapgoNativeWidgetBridge().listSessions().map(CapgoNativeWidgetBridge.serializeSession)
        return ["sessions": sessions]
    }

    public func sendWidgetMessage(
        widgetId: String,
        direction: String?,
        name: String,
        payloadObject: [String: Any]?,
        expectsResponse: Bool
    ) throws -> [String: Any] {
        let message = try CapgoNativeWidgetBridge().sendMessage(
            widgetId: widgetId,
            name: name,
            direction: CapgoWidgetMessageDirection(rawValue: direction ?? "") ?? .appToWidget,
            payloadObject: payloadObject,
            expectsResponse: expectsResponse
        )
        reloadWidgets(kind: nil)
        return ["message": try CapgoNativeWidgetBridge.serializeMessage(message)]
    }

    public func listWidgetMessages(
        widgetId: String?,
        direction: String?,
        unacknowledgedOnly: Bool,
        pendingOnly: Bool
    ) throws -> [String: Any] {
        let messages = try CapgoNativeWidgetBridge().listMessages(
            widgetId: widgetId,
            direction: direction.flatMap(CapgoWidgetMessageDirection.init(rawValue:)),
            unacknowledgedOnly: unacknowledgedOnly,
            pendingOnly: pendingOnly
        ).map(CapgoNativeWidgetBridge.serializeMessage)
        return ["messages": messages]
    }

    public func acknowledgeWidgetMessages(messageIds: [String]?, widgetId: String?, direction: String?) throws {
        try CapgoNativeWidgetBridge().acknowledgeMessages(
            messageIds: messageIds,
            widgetId: widgetId,
            direction: direction.flatMap(CapgoWidgetMessageDirection.init(rawValue:))
        )
        reloadWidgets(kind: nil)
    }

    public func completeWidgetMessage(messageId: String, responseObject: [String: Any]?, error: String?) throws -> [String: Any] {
        let message = try CapgoNativeWidgetBridge().completeMessage(
            messageId: messageId,
            responseObject: responseObject,
            error: error
        )
        guard let message else {
            return ["message": NSNull()]
        }
        reloadWidgets(kind: nil)
        return ["message": try CapgoNativeWidgetBridge.serializeMessage(message)]
    }

    public func reloadWidgets(kind: String?) {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            if let kind, !kind.isEmpty {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            } else {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #else
        _ = kind
        #endif
    }

    public func getPluginVersion() -> [String: Any] {
        [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ios"
        ]
    }
}
