import Foundation

public struct StoredTemplateTimerState: Codable, Hashable, Sendable {
    public var id: String
    public var startedAtMs: Int64?
    public var elapsedMs: Int64?
    public var durationMs: Int64
    public var status: String
    public var updatedAtMs: Int64

    public init(
        id: String,
        startedAtMs: Int64?,
        durationMs: Int64,
        status: String,
        updatedAtMs: Int64,
        elapsedMs: Int64? = nil
    ) {
        self.id = id
        self.startedAtMs = startedAtMs
        self.elapsedMs = elapsedMs
        self.durationMs = durationMs
        self.status = status
        self.updatedAtMs = updatedAtMs
    }
}

public struct StoredTemplateActivityEnvelope: Codable, Hashable, Sendable {
    public var activityId: String
    public var templateId: String
    public var definitionData: Data
    public var stateData: Data
    public var timers: [String: StoredTemplateTimerState]
    public var status: String
    public var openUrl: String?
    public var updatedAtMs: Int64
    public var revision: Int
    public var nativeActivityId: String?

    public init(
        activityId: String,
        templateId: String,
        definitionData: Data,
        stateData: Data,
        timers: [String: StoredTemplateTimerState],
        status: String,
        openUrl: String?,
        updatedAtMs: Int64,
        revision: Int,
        nativeActivityId: String?
    ) {
        self.activityId = activityId
        self.templateId = templateId
        self.definitionData = definitionData
        self.stateData = stateData
        self.timers = timers
        self.status = status
        self.openUrl = openUrl
        self.updatedAtMs = updatedAtMs
        self.revision = revision
        self.nativeActivityId = nativeActivityId
    }
}

public struct StoredTemplateActionEvent: Codable, Hashable, Sendable {
    public var eventId: String
    public var activityId: String
    public var actionId: String
    public var eventName: String?
    public var sourceId: String?
    public var createdAtMs: Int64
    public var acknowledgedAtMs: Int64?
    public var payloadData: Data?
    public var stateData: Data
    public var timers: [String: StoredTemplateTimerState]

    public init(
        eventId: String,
        activityId: String,
        actionId: String,
        eventName: String?,
        sourceId: String?,
        createdAtMs: Int64,
        acknowledgedAtMs: Int64?,
        payloadData: Data?,
        stateData: Data,
        timers: [String: StoredTemplateTimerState]
    ) {
        self.eventId = eventId
        self.activityId = activityId
        self.actionId = actionId
        self.eventName = eventName
        self.sourceId = sourceId
        self.createdAtMs = createdAtMs
        self.acknowledgedAtMs = acknowledgedAtMs
        self.payloadData = payloadData
        self.stateData = stateData
        self.timers = timers
    }
}

public final class TemplateActivityStore {
    private static let activityIdsKey = "capgo.widgetkit.template.activity-ids"
    private static let nativeActivityMapKey = "capgo.widgetkit.template.native-activity-map"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public static func make(bundle: Bundle = .main) throws -> TemplateActivityStore {
        TemplateActivityStore(defaults: try CapgoWidgetKitSharedStore.defaults(bundle: bundle))
    }

    public func loadEnvelope(activityId: String) -> StoredTemplateActivityEnvelope? {
        guard let data = defaults.data(forKey: activityKey(activityId)) else {
            return nil
        }
        return try? decoder.decode(StoredTemplateActivityEnvelope.self, from: data)
    }

    public func saveEnvelope(_ envelope: StoredTemplateActivityEnvelope) throws {
        let data = try encoder.encode(envelope)
        defaults.set(data, forKey: activityKey(envelope.activityId))
        var ids = activityIds()
        if !ids.contains(envelope.activityId) {
            ids.append(envelope.activityId)
            defaults.set(ids, forKey: Self.activityIdsKey)
        }
        defaults.synchronize()
    }

    public func deleteEnvelope(activityId: String) {
        defaults.removeObject(forKey: activityKey(activityId))
        defaults.set(activityIds().filter { $0 != activityId }, forKey: Self.activityIdsKey)
        defaults.removeObject(forKey: eventsKey(activityId))

        var mapping = nativeActivityMap()
        mapping.removeValue(forKey: activityId)
        defaults.set(mapping, forKey: Self.nativeActivityMapKey)
    }

    public func listEnvelopes() -> [StoredTemplateActivityEnvelope] {
        activityIds().compactMap(loadEnvelope(activityId:))
            .sorted { $0.updatedAtMs > $1.updatedAtMs }
    }

    public func appendEvent(_ event: StoredTemplateActionEvent) throws {
        var events = loadEvents(activityId: event.activityId)
        events.insert(event, at: 0)
        let data = try encoder.encode(events)
        defaults.set(data, forKey: eventsKey(event.activityId))
    }

    public func loadEvents(activityId: String) -> [StoredTemplateActionEvent] {
        guard let data = defaults.data(forKey: eventsKey(activityId)) else {
            return []
        }
        return (try? decoder.decode([StoredTemplateActionEvent].self, from: data)) ?? []
    }

    public func loadEvents(activityId: String?) -> [StoredTemplateActionEvent] {
        if let activityId {
            return loadEvents(activityId: activityId)
        }

        return activityIds()
            .flatMap(loadEvents(activityId:))
            .sorted { $0.createdAtMs > $1.createdAtMs }
    }

    public func acknowledgeEvents(eventIds: [String]?, activityId: String?, acknowledgedAtMs: Int64) throws {
        let targetIds = Set(eventIds ?? [])

        for currentActivityId in targetActivityIds(activityId: activityId, eventIds: eventIds) {
            let updated = loadEvents(activityId: currentActivityId).map { event -> StoredTemplateActionEvent in
                let matchesEventId = !targetIds.isEmpty && targetIds.contains(event.eventId)
                let matchesActivity = activityId != nil && currentActivityId == activityId
                guard matchesEventId || matchesActivity else {
                    return event
                }

                var acknowledgedEvent = event
                acknowledgedEvent.acknowledgedAtMs = acknowledgedAtMs
                return acknowledgedEvent
            }
            let data = try encoder.encode(updated)
            defaults.set(data, forKey: eventsKey(currentActivityId))
        }
    }

    public func nativeActivityId(for activityId: String) -> String? {
        nativeActivityMap()[activityId]
    }

    public func setNativeActivityId(_ nativeActivityId: String, for activityId: String) {
        var mapping = nativeActivityMap()
        mapping[activityId] = nativeActivityId
        defaults.set(mapping, forKey: Self.nativeActivityMapKey)
    }

    public func removeNativeActivityId(for activityId: String) {
        var mapping = nativeActivityMap()
        mapping.removeValue(forKey: activityId)
        defaults.set(mapping, forKey: Self.nativeActivityMapKey)
    }

    private func targetActivityIds(activityId: String?, eventIds: [String]?) -> [String] {
        if let activityId {
            return [activityId]
        }
        guard let eventIds, !eventIds.isEmpty else {
            return []
        }
        let targetIds = Set(eventIds)
        return activityIds().filter { currentActivityId in
            loadEvents(activityId: currentActivityId).contains(where: { targetIds.contains($0.eventId) })
        }
    }

    private func activityIds() -> [String] {
        defaults.stringArray(forKey: Self.activityIdsKey) ?? []
    }

    private func nativeActivityMap() -> [String: String] {
        defaults.dictionary(forKey: Self.nativeActivityMapKey) as? [String: String] ?? [:]
    }

    private func activityKey(_ activityId: String) -> String {
        "capgo.widgetkit.template.activity.\(activityId)"
    }

    private func eventsKey(_ activityId: String) -> String {
        "capgo.widgetkit.template.events.\(activityId)"
    }
}
