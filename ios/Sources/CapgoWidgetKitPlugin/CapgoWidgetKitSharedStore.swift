import Foundation

public enum CapgoWidgetKitSharedStoreError: LocalizedError {
    case missingAppGroup
    case invalidSuite(String)

    public var errorDescription: String? {
        switch self {
        case .missingAppGroup:
            return "Missing App Group configuration. Set CapgoWidgetKitAppGroup in the app and widget extension Info.plist files."
        case .invalidSuite(let suiteName):
            return "Unable to open the shared App Group suite: \(suiteName)"
        }
    }
}

public enum CapgoWidgetKitSharedStore {
    public static let appGroupInfoKey = "CapgoWidgetKitAppGroup"

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

    public static func defaults(bundle: Bundle = .main) throws -> UserDefaults {
        guard let suiteName = resolveAppGroupId(bundle: bundle) else {
            throw CapgoWidgetKitSharedStoreError.missingAppGroup
        }
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CapgoWidgetKitSharedStoreError.invalidSuite(suiteName)
        }
        return defaults
    }
}
