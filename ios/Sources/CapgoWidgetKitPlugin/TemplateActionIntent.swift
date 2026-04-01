#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, *)
public struct CapgoTemplateActionIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Run Widget Template Action"

    @Parameter(title: "Activity Id")
    public var activityId: String

    @Parameter(title: "Action Id")
    public var actionId: String

    @Parameter(title: "Source Id")
    public var sourceId: String?

    @Parameter(title: "Payload JSON")
    public var payloadJSON: String?

    public init() {}

    public init(activityId: String, actionId: String, sourceId: String? = nil, payloadJSON: String? = nil) {
        self.activityId = activityId
        self.actionId = actionId
        self.sourceId = sourceId
        self.payloadJSON = payloadJSON
    }

    public func perform() async throws -> some IntentResult {
        let payloadObject: [String: Any]?
        if let payloadJSON {
            payloadObject = try parsePayload(payloadJSON)
        } else {
            payloadObject = nil
        }

        _ = try await TemplateLiveActivityManager.shared.performAction(
            activityId: activityId,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        )
        return .result()
    }

    private func parsePayload(_ payloadJSON: String) throws -> [String: Any]? {
        guard let data = payloadJSON.data(using: .utf8) else {
            return nil
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any]
    }
}
#endif
