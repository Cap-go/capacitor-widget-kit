import Foundation

public struct StoredWorkoutEnvelope: Codable, Hashable, Sendable {
    public var session: WorkoutSession
    public var revision: Int
    public var activityId: String?
    public var updatedAtMs: Int64

    public init(session: WorkoutSession, revision: Int, activityId: String?, updatedAtMs: Int64) {
        self.session = session
        self.revision = revision
        self.activityId = activityId
        self.updatedAtMs = updatedAtMs
    }
}

enum WorkoutActivityStoreError: LocalizedError {
    case missingAppGroup
    case invalidSuite(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroup:
            return "Missing App Group configuration. Set CapgoWidgetKitAppGroup in the app and widget extension Info.plist files."
        case .invalidSuite(let suiteName):
            return "Unable to open the shared App Group suite: \(suiteName)"
        }
    }
}

public final class WorkoutActivityStore {
    public static let appGroupInfoKey = "CapgoWidgetKitAppGroup"

    private static let activityMapKey = "capgo.widgetkit.activity-map"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public static func make(bundle: Bundle = .main) throws -> WorkoutActivityStore {
        guard let suiteName = resolveAppGroupId(bundle: bundle) else {
            throw WorkoutActivityStoreError.missingAppGroup
        }
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw WorkoutActivityStoreError.invalidSuite(suiteName)
        }
        return WorkoutActivityStore(defaults: defaults)
    }

    public static func resolveAppGroupId(bundle: Bundle = .main) -> String? {
        if let configured = bundle.object(forInfoDictionaryKey: appGroupInfoKey) as? String, !configured.isEmpty {
            return configured
        }

        guard let bundleId = bundle.bundleIdentifier, !bundleId.isEmpty else {
            return nil
        }

        let lowercased = bundleId.lowercased()
        if lowercased.contains("widget") || lowercased.contains("extension"),
           bundleId.split(separator: ".").count > 1 {
            return "group.\(bundleId.split(separator: ".").dropLast().joined(separator: ".")).widgetkit"
        }

        return "group.\(bundleId).widgetkit"
    }

    public func loadEnvelope(sessionId: String) -> StoredWorkoutEnvelope? {
        guard let data = defaults.data(forKey: sessionKey(sessionId)) else {
            return nil
        }
        return try? decoder.decode(StoredWorkoutEnvelope.self, from: data)
    }

    public func saveEnvelope(_ envelope: StoredWorkoutEnvelope) throws {
        let data = try encoder.encode(envelope)
        defaults.set(data, forKey: sessionKey(envelope.session.sessionId))
        defaults.synchronize()
    }

    public func sessionId(forActivityId activityId: String) -> String? {
        activityMap()[activityId]
    }

    public func setActivityId(_ activityId: String, forSessionId sessionId: String) {
        var mapping = activityMap()
        mapping[activityId] = sessionId
        defaults.set(mapping, forKey: Self.activityMapKey)
    }

    public func removeActivityId(_ activityId: String) {
        var mapping = activityMap()
        mapping.removeValue(forKey: activityId)
        defaults.set(mapping, forKey: Self.activityMapKey)
    }

    public func allActivityMappings() -> [String: String] {
        activityMap()
    }

    private func activityMap() -> [String: String] {
        defaults.dictionary(forKey: Self.activityMapKey) as? [String: String] ?? [:]
    }

    private func sessionKey(_ sessionId: String) -> String {
        "capgo.widgetkit.session.\(sessionId)"
    }
}
