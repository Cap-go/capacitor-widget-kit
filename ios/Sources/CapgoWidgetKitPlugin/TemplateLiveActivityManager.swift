#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct TemplateActivityInfo: Hashable, Sendable {
    public let activityId: String
    public let templateId: String
    public let status: String
    public let updatedAtMs: Int64
}

#if canImport(ActivityKit)
@available(iOS 16.2, *)
public struct CapgoTemplateActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var revision: Int
        public var status: String
        public var updatedAtMs: Int64
    }

    public var activityId: String
    public var templateId: String
    public var openUrl: String?

    public init(activityId: String, templateId: String, openUrl: String?) {
        self.activityId = activityId
        self.templateId = templateId
        self.openUrl = openUrl
    }
}
#endif

public final class TemplateLiveActivityManager {
    public static let shared = TemplateLiveActivityManager()

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
        return (false, "iOS 16.2 or later is required for the native template activity bridge.")
        #else
        return (false, "ActivityKit is unavailable in this build configuration.")
        #endif
    }

    public func start(
        activityId requestedActivityId: String?,
        definitionObject: [String: Any],
        stateObject: [String: Any],
        openUrl: String?,
        startLiveActivity: Bool = true
    ) async throws -> StoredTemplateActivityEnvelope {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let activityId: String
        if let requestedActivityId, !requestedActivityId.isEmpty {
            activityId = requestedActivityId
        } else {
            activityId = TemplateRuntime.createIdentifier(prefix: "activity")
        }
        var record = TemplateRuntime.makeRecord(
            activityId: activityId,
            definitionObject: definitionObject,
            stateObject: stateObject,
            openUrl: openUrl,
            nowMs: nowMs
        )
        let store = try TemplateActivityStore.make()

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), startLiveActivity {
            let activity = try Activity.request(
                attributes: CapgoTemplateActivityAttributes(
                    activityId: activityId,
                    templateId: record.templateId,
                    openUrl: openUrl
                ),
                content: ActivityContent(state: contentState(from: record), staleDate: nil),
                pushType: nil
            )
            record.nativeActivityId = activity.id
            store.setNativeActivityId(activity.id, for: activityId)
        }
        #endif

        let envelope = try record.toEnvelope()
        try store.saveEnvelope(envelope)
        reloadWidgetTimelines()
        return envelope
    }

    public func update(
        activityId: String,
        definitionObject: [String: Any]?,
        stateObject: [String: Any]?,
        openUrl: String?
    ) async throws -> StoredTemplateActivityEnvelope? {
        let store = try TemplateActivityStore.make()
        guard var record = try store.loadEnvelope(activityId: activityId).map(TemplateRuntimeRecord.init(envelope:)) else {
            return nil
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if let definitionObject {
            record.definition = definitionObject
            record.templateId = (definitionObject["id"] as? String) ?? record.templateId
        }
        if let stateObject {
            record.state = stateObject
        }
        if let openUrl {
            record.openUrl = openUrl
        }
        record.updatedAtMs = nowMs
        record.revision += 1
        record.timers = TemplateRuntime.reconcileTimers(for: record, nowMs: nowMs)

        let envelope = try record.toEnvelope()
        try store.saveEnvelope(envelope)
        try await updateNativeActivity(for: envelope)
        reloadWidgetTimelines()
        return envelope
    }

    public func end(activityId: String, finalStateObject: [String: Any]?) async throws {
        let store = try TemplateActivityStore.make()
        guard var record = try store.loadEnvelope(activityId: activityId).map(TemplateRuntimeRecord.init(envelope:)) else {
            return
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if let finalStateObject {
            record.state = finalStateObject
        }
        record.status = "ended"
        record.updatedAtMs = nowMs
        record.revision += 1
        record.timers = TemplateRuntime.reconcileTimers(for: record, nowMs: nowMs)
        let envelope = try record.toEnvelope()
        try store.saveEnvelope(envelope)

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), let nativeActivity = nativeActivity(for: activityId, store: store) {
            await nativeActivity.end(ActivityContent(state: contentState(from: record), staleDate: nil), dismissalPolicy: .immediate)
        }
        #endif

        store.removeNativeActivityId(for: activityId)
        reloadWidgetTimelines()
    }

    public func performAction(
        activityId: String,
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?
    ) async throws -> (StoredTemplateActivityEnvelope, StoredTemplateActionEvent) {
        let store = try TemplateActivityStore.make()
        guard let currentEnvelope = store.loadEnvelope(activityId: activityId) else {
            throw CapgoWidgetKitBridgeError.invalidObject("No stored template activity found for \(activityId).")
        }

        let record = try TemplateRuntimeRecord(envelope: currentEnvelope)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let (nextRecord, event) = try TemplateRuntime.applyAction(
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject,
            record: record,
            nowMs: nowMs
        )

        let envelope = try nextRecord.toEnvelope()
        try store.saveEnvelope(envelope)
        try store.appendEvent(event)
        try await updateNativeActivity(for: envelope)
        reloadWidgetTimelines()
        return (envelope, event)
    }

    public func activity(activityId: String) throws -> StoredTemplateActivityEnvelope? {
        try TemplateActivityStore.make().loadEnvelope(activityId: activityId)
    }

    public func listActivities() throws -> [TemplateActivityInfo] {
        try TemplateActivityStore.make().listEnvelopes().map { envelope in
            TemplateActivityInfo(
                activityId: envelope.activityId,
                templateId: envelope.templateId,
                status: envelope.status,
                updatedAtMs: envelope.updatedAtMs
            )
        }
    }

    public func listEvents(activityId: String?, unacknowledgedOnly: Bool) throws -> [StoredTemplateActionEvent] {
        try TemplateActivityStore.make()
            .loadEvents(activityId: activityId)
            .filter { !unacknowledgedOnly || $0.acknowledgedAtMs == nil }
            .sorted { $0.createdAtMs > $1.createdAtMs }
    }

    public func acknowledgeEvents(activityId: String?, eventIds: [String]?) throws {
        try TemplateActivityStore.make()
            .acknowledgeEvents(
                eventIds: eventIds,
                activityId: activityId,
                acknowledgedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
        reloadWidgetTimelines()
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private func contentState(from record: TemplateRuntimeRecord) -> CapgoTemplateActivityAttributes.ContentState {
        CapgoTemplateActivityAttributes.ContentState(
            revision: record.revision,
            status: record.status,
            updatedAtMs: record.updatedAtMs
        )
    }

    @available(iOS 16.2, *)
    private func nativeActivity(for activityId: String, store: TemplateActivityStore) -> Activity<CapgoTemplateActivityAttributes>? {
        guard let nativeActivityId = store.nativeActivityId(for: activityId) else {
            return nil
        }
        return Activity<CapgoTemplateActivityAttributes>.activities.first(where: { $0.id == nativeActivityId })
    }

    private func updateNativeActivity(for envelope: StoredTemplateActivityEnvelope) async throws {
        guard #available(iOS 16.2, *) else {
            return
        }

        let store = try TemplateActivityStore.make()
        guard let record = try store.loadEnvelope(activityId: envelope.activityId).map(TemplateRuntimeRecord.init(envelope:)),
              let nativeActivity = nativeActivity(for: envelope.activityId, store: store)
        else {
            return
        }

        await nativeActivity.update(ActivityContent(state: contentState(from: record), staleDate: nil))
    }
    #else
    private func updateNativeActivity(for envelope: StoredTemplateActivityEnvelope) async throws {
        _ = envelope
    }
    #endif
}
