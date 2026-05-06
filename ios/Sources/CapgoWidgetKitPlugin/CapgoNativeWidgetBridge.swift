import Foundation

public enum CapgoWidgetMessageDirection: String, Codable, Sendable {
    case appToWidget
    case widgetToApp
}

public enum CapgoWidgetMessageStatus: String, Codable, Sendable {
    case pending
    case completed
    case failed
}

public struct StoredWidgetSessionEnvelope: Codable, Hashable, Sendable {
    public var widgetId: String
    public var kind: String?
    public var stateData: Data
    public var metadataData: Data?
    public var status: String
    public var createdAtMs: Int64
    public var updatedAtMs: Int64
    public var revision: Int

    public init(
        widgetId: String,
        kind: String?,
        stateData: Data,
        metadataData: Data?,
        status: String,
        createdAtMs: Int64,
        updatedAtMs: Int64,
        revision: Int
    ) {
        self.widgetId = widgetId
        self.kind = kind
        self.stateData = stateData
        self.metadataData = metadataData
        self.status = status
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
        self.revision = revision
    }
}

public struct StoredWidgetBridgeMessage: Codable, Hashable, Sendable {
    public var messageId: String
    public var widgetId: String
    public var direction: CapgoWidgetMessageDirection
    public var name: String
    public var payloadData: Data?
    public var expectsResponse: Bool
    public var status: CapgoWidgetMessageStatus
    public var createdAtMs: Int64
    public var acknowledgedAtMs: Int64?
    public var completedAtMs: Int64?
    public var responseData: Data?
    public var error: String?

    public init(
        messageId: String,
        widgetId: String,
        direction: CapgoWidgetMessageDirection,
        name: String,
        payloadData: Data?,
        expectsResponse: Bool,
        status: CapgoWidgetMessageStatus,
        createdAtMs: Int64,
        acknowledgedAtMs: Int64?,
        completedAtMs: Int64?,
        responseData: Data?,
        error: String?
    ) {
        self.messageId = messageId
        self.widgetId = widgetId
        self.direction = direction
        self.name = name
        self.payloadData = payloadData
        self.expectsResponse = expectsResponse
        self.status = status
        self.createdAtMs = createdAtMs
        self.acknowledgedAtMs = acknowledgedAtMs
        self.completedAtMs = completedAtMs
        self.responseData = responseData
        self.error = error
    }
}

public final class CapgoNativeWidgetBridge {
    private let store: NativeWidgetBridgeStore

    public init(bundle: Bundle = .main) throws {
        store = NativeWidgetBridgeStore(defaults: try CapgoWidgetKitSharedStore.defaults(bundle: bundle))
    }

    public func startSession(
        widgetId requestedWidgetId: String? = nil,
        kind: String? = nil,
        stateObject: [String: Any] = [:],
        metadataObject: [String: Any]? = nil,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> StoredWidgetSessionEnvelope {
        let widgetId: String
        if let requestedWidgetId, !requestedWidgetId.isEmpty {
            widgetId = requestedWidgetId
        } else {
            widgetId = TemplateRuntime.createIdentifier(prefix: "widget")
        }
        let session = StoredWidgetSessionEnvelope(
            widgetId: widgetId,
            kind: kind,
            stateData: try TemplateRuntime.jsonData(from: stateObject),
            metadataData: try metadataObject.map(TemplateRuntime.jsonData(from:)),
            status: "active",
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
            revision: 1
        )
        try store.saveSession(session)
        return session
    }

    public func updateSession(
        widgetId: String,
        stateObject: [String: Any]?,
        metadataObject: [String: Any]?,
        merge: Bool = false,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> StoredWidgetSessionEnvelope? {
        guard var session = store.loadSession(widgetId: widgetId) else {
            return nil
        }

        if let stateObject {
            let current = try TemplateRuntime.jsonObject(from: session.stateData) as? [String: Any] ?? [:]
            session.stateData = try TemplateRuntime.jsonData(from: merge ? Self.merge(current, with: stateObject) : stateObject)
        }
        if let metadataObject {
            let current = try session.metadataData.map(TemplateRuntime.jsonObject(from:)) as? [String: Any] ?? [:]
            session.metadataData = try TemplateRuntime.jsonData(from: merge ? Self.merge(current, with: metadataObject) : metadataObject)
        }
        session.status = "active"
        session.updatedAtMs = nowMs
        session.revision += 1
        try store.saveSession(session)
        return session
    }

    public func stopSession(widgetId: String, stateObject: [String: Any]? = nil, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) throws {
        guard var session = store.loadSession(widgetId: widgetId) else {
            return
        }
        if let stateObject {
            session.stateData = try TemplateRuntime.jsonData(from: stateObject)
        }
        session.status = "stopped"
        session.updatedAtMs = nowMs
        session.revision += 1
        try store.saveSession(session)
    }

    public func loadSession(widgetId: String) -> StoredWidgetSessionEnvelope? {
        store.loadSession(widgetId: widgetId)
    }

    public func listSessions() -> [StoredWidgetSessionEnvelope] {
        store.listSessions()
    }

    public func sendMessage(
        widgetId: String,
        name: String,
        direction: CapgoWidgetMessageDirection = .appToWidget,
        payloadObject: [String: Any]? = nil,
        expectsResponse: Bool = false,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> StoredWidgetBridgeMessage {
        let message = StoredWidgetBridgeMessage(
            messageId: TemplateRuntime.createIdentifier(prefix: "message"),
            widgetId: widgetId,
            direction: direction,
            name: name,
            payloadData: try payloadObject.map(TemplateRuntime.jsonData(from:)),
            expectsResponse: expectsResponse,
            status: .pending,
            createdAtMs: nowMs,
            acknowledgedAtMs: nil,
            completedAtMs: nil,
            responseData: nil,
            error: nil
        )
        try store.saveMessage(message)
        return message
    }

    public func listMessages(
        widgetId: String? = nil,
        direction: CapgoWidgetMessageDirection? = nil,
        unacknowledgedOnly: Bool = false,
        pendingOnly: Bool = false
    ) -> [StoredWidgetBridgeMessage] {
        store.listMessages().filter { message in
            if let widgetId, message.widgetId != widgetId { return false }
            if let direction, message.direction != direction { return false }
            if unacknowledgedOnly, message.acknowledgedAtMs != nil { return false }
            if pendingOnly, message.status != .pending { return false }
            return true
        }
    }

    public func acknowledgeMessages(
        messageIds: [String]? = nil,
        widgetId: String? = nil,
        direction: CapgoWidgetMessageDirection? = nil,
        acknowledgedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws {
        let targetIds = Set(messageIds ?? [])
        for var message in store.listMessages() {
            let matchesMessageId = !targetIds.isEmpty && targetIds.contains(message.messageId)
            let matchesWidget = widgetId != nil && message.widgetId == widgetId
            let matchesDirection = direction == nil || message.direction == direction
            guard (matchesMessageId || matchesWidget) && matchesDirection else {
                continue
            }
            message.acknowledgedAtMs = acknowledgedAtMs
            try store.saveMessage(message)
        }
    }

    public func completeMessage(
        messageId: String,
        responseObject: [String: Any]? = nil,
        error: String? = nil,
        completedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> StoredWidgetBridgeMessage? {
        guard var message = store.loadMessage(messageId: messageId) else {
            return nil
        }
        message.status = error == nil ? .completed : .failed
        message.completedAtMs = completedAtMs
        message.responseData = try responseObject.map(TemplateRuntime.jsonData(from:))
        message.error = error
        try store.saveMessage(message)
        return message
    }

    public static func serializeSession(_ session: StoredWidgetSessionEnvelope) throws -> [String: Any] {
        [
            "widgetId": session.widgetId,
            "kind": session.kind as Any,
            "state": try TemplateRuntime.jsonObject(from: session.stateData),
            "metadata": try session.metadataData.map(TemplateRuntime.jsonObject(from:)) as Any,
            "status": session.status,
            "createdAt": session.createdAtMs,
            "updatedAt": session.updatedAtMs,
            "revision": session.revision
        ]
    }

    public static func serializeMessage(_ message: StoredWidgetBridgeMessage) throws -> [String: Any] {
        [
            "messageId": message.messageId,
            "widgetId": message.widgetId,
            "direction": message.direction.rawValue,
            "name": message.name,
            "payload": try message.payloadData.map(TemplateRuntime.jsonObject(from:)) as Any,
            "expectsResponse": message.expectsResponse,
            "status": message.status.rawValue,
            "createdAt": message.createdAtMs,
            "acknowledgedAt": message.acknowledgedAtMs as Any,
            "completedAt": message.completedAtMs as Any,
            "response": try message.responseData.map(TemplateRuntime.jsonObject(from:)) as Any,
            "error": message.error as Any
        ]
    }

    private static func merge(_ base: [String: Any], with patch: [String: Any]) -> [String: Any] {
        var merged = base
        for (key, value) in patch {
            if let currentObject = merged[key] as? [String: Any], let patchObject = value as? [String: Any] {
                merged[key] = merge(currentObject, with: patchObject)
            } else {
                merged[key] = value
            }
        }
        return merged
    }
}

private final class NativeWidgetBridgeStore {
    private static let sessionIdsKey = "capgo.widgetkit.native.session-ids"
    private static let messageIdsKey = "capgo.widgetkit.native.message-ids"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func loadSession(widgetId: String) -> StoredWidgetSessionEnvelope? {
        guard let data = defaults.data(forKey: sessionKey(widgetId)) else {
            return nil
        }
        return try? decoder.decode(StoredWidgetSessionEnvelope.self, from: data)
    }

    func saveSession(_ session: StoredWidgetSessionEnvelope) throws {
        defaults.set(try encoder.encode(session), forKey: sessionKey(session.widgetId))
        var ids = sessionIds()
        if !ids.contains(session.widgetId) {
            ids.append(session.widgetId)
            defaults.set(ids, forKey: Self.sessionIdsKey)
        }
        defaults.synchronize()
    }

    func listSessions() -> [StoredWidgetSessionEnvelope] {
        sessionIds().compactMap(loadSession(widgetId:))
            .sorted { $0.updatedAtMs > $1.updatedAtMs }
    }

    func loadMessage(messageId: String) -> StoredWidgetBridgeMessage? {
        guard let data = defaults.data(forKey: messageKey(messageId)) else {
            return nil
        }
        return try? decoder.decode(StoredWidgetBridgeMessage.self, from: data)
    }

    func saveMessage(_ message: StoredWidgetBridgeMessage) throws {
        defaults.set(try encoder.encode(message), forKey: messageKey(message.messageId))
        var ids = messageIds()
        if !ids.contains(message.messageId) {
            ids.append(message.messageId)
            defaults.set(ids, forKey: Self.messageIdsKey)
        }
        defaults.synchronize()
    }

    func listMessages() -> [StoredWidgetBridgeMessage] {
        messageIds().compactMap(loadMessage(messageId:))
            .sorted { $0.createdAtMs > $1.createdAtMs }
    }

    private func sessionIds() -> [String] {
        defaults.stringArray(forKey: Self.sessionIdsKey) ?? []
    }

    private func messageIds() -> [String] {
        defaults.stringArray(forKey: Self.messageIdsKey) ?? []
    }

    private func sessionKey(_ widgetId: String) -> String {
        "capgo.widgetkit.native.session.\(widgetId)"
    }

    private func messageKey(_ messageId: String) -> String {
        "capgo.widgetkit.native.message.\(messageId)"
    }
}
