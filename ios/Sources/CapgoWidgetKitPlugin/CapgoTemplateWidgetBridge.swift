// swiftlint:disable identifier_name
import Foundation

public enum CapgoTemplateSurface: String, CaseIterable, Sendable {
    case lockScreen
    case dynamicIslandExpanded
    case dynamicIslandCompactLeading
    case dynamicIslandCompactTrailing
    case dynamicIslandMinimal
}

public enum CapgoTemplateHotspotRole: String, Sendable {
    case button
    case link
}

public struct CapgoTemplateResolvedHotspot: Hashable, Sendable {
    public let id: String
    public let actionId: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let label: String?
    public let role: CapgoTemplateHotspotRole?
    public let payloadJSON: String?

    public init(
        id: String,
        actionId: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        label: String?,
        role: CapgoTemplateHotspotRole?,
        payloadJSON: String?
    ) {
        self.id = id
        self.actionId = actionId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.label = label
        self.role = role
        self.payloadJSON = payloadJSON
    }
}

public struct CapgoResolvedTemplateLayout: Hashable, Sendable {
    public let activityId: String
    public let templateId: String
    public let surface: CapgoTemplateSurface
    public let frameId: String?
    public let svg: String
    public let width: Double
    public let height: Double
    public let hotspots: [CapgoTemplateResolvedHotspot]
    public let openUrl: String?
    public let status: String
    public let revision: Int
    public let updatedAtMs: Int64

    public init(
        activityId: String,
        templateId: String,
        surface: CapgoTemplateSurface,
        frameId: String?,
        svg: String,
        width: Double,
        height: Double,
        hotspots: [CapgoTemplateResolvedHotspot],
        openUrl: String?,
        status: String,
        revision: Int,
        updatedAtMs: Int64
    ) {
        self.activityId = activityId
        self.templateId = templateId
        self.surface = surface
        self.frameId = frameId
        self.svg = svg
        self.width = width
        self.height = height
        self.hotspots = hotspots
        self.openUrl = openUrl
        self.status = status
        self.revision = revision
        self.updatedAtMs = updatedAtMs
    }
}

public final class CapgoTemplateWidgetBridge {
    public init() {}

    public func loadActivity(activityId: String, bundle: Bundle = .main) throws -> StoredTemplateActivityEnvelope? {
        try TemplateActivityStore.make(bundle: bundle).loadEnvelope(activityId: activityId)
    }

    public func listActivities(bundle: Bundle = .main) throws -> [StoredTemplateActivityEnvelope] {
        try TemplateActivityStore.make(bundle: bundle).listEnvelopes()
    }

    public func latestActivity(status: String? = "active", bundle: Bundle = .main) throws -> StoredTemplateActivityEnvelope? {
        try listActivities(bundle: bundle).first { envelope in
            guard let status else {
                return true
            }
            return envelope.status == status
        }
    }

    public func resolveLayout(
        activityId: String,
        surface: CapgoTemplateSurface,
        bundle: Bundle = .main,
        now: Date = Date()
    ) throws -> CapgoResolvedTemplateLayout? {
        guard let envelope = try loadActivity(activityId: activityId, bundle: bundle) else {
            return nil
        }

        let record = try TemplateRuntimeRecord(envelope: envelope)
        let layoutKey = surface.rawValue
        guard
            let layouts = record.definition["layouts"] as? [String: Any],
            let layoutObject = layouts[layoutKey] as? [String: Any]
        else {
            return nil
        }

        let resolvedLayout = TemplateRuntime.resolveLayout(
            layoutObject: layoutObject,
            record: record,
            nowMs: Int64(now.timeIntervalSince1970 * 1000)
        )

        return CapgoResolvedTemplateLayout(
            activityId: record.activityId,
            templateId: record.templateId,
            surface: surface,
            frameId: resolvedLayout["frameId"] as? String,
            svg: resolvedLayout["svg"] as? String ?? "",
            width: coerceDouble(layoutObject["width"]) ?? 1,
            height: coerceDouble(layoutObject["height"]) ?? 1,
            hotspots: parseHotspots(resolvedLayout["hotspots"]),
            openUrl: record.openUrl,
            status: record.status,
            revision: record.revision,
            updatedAtMs: record.updatedAtMs
        )
    }

    public func resolveLatestLayout(
        surface: CapgoTemplateSurface,
        status: String? = "active",
        bundle: Bundle = .main,
        now: Date = Date()
    ) throws -> CapgoResolvedTemplateLayout? {
        guard let envelope = try latestActivity(status: status, bundle: bundle) else {
            return nil
        }
        return try resolveLayout(activityId: envelope.activityId, surface: surface, bundle: bundle, now: now)
    }

    private func parseHotspots(_ value: Any?) -> [CapgoTemplateResolvedHotspot] {
        guard let hotspots = value as? [[String: Any]] else {
            return []
        }

        return hotspots.compactMap { hotspot in
            guard
                let id = hotspot["id"] as? String,
                let actionId = hotspot["actionId"] as? String
            else {
                return nil
            }

            return CapgoTemplateResolvedHotspot(
                id: id,
                actionId: actionId,
                x: coerceDouble(hotspot["x"]) ?? 0,
                y: coerceDouble(hotspot["y"]) ?? 0,
                width: coerceDouble(hotspot["width"]) ?? 0,
                height: coerceDouble(hotspot["height"]) ?? 0,
                label: hotspot["label"] as? String,
                role: (hotspot["role"] as? String).flatMap(CapgoTemplateHotspotRole.init(rawValue:)),
                payloadJSON: serializePayload(hotspot["payload"])
            )
        }
    }

    private func serializePayload(_ value: Any?) -> String? {
        guard let value else {
            return nil
        }

        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    private func coerceDouble(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }
}
// swiftlint:enable identifier_name
