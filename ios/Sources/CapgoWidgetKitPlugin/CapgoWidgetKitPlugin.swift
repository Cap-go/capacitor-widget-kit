import Capacitor
import Foundation

@objc(CapgoWidgetKitPlugin)
public class CapgoWidgetKitPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CapgoWidgetKitPlugin"
    public let jsName = "CapgoWidgetKit"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "areActivitiesSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startTemplateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateTemplateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endTemplateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "performTemplateAction", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getTemplateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listTemplateActivities", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listTemplateEvents", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "acknowledgeTemplateEvents", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startWidgetSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateWidgetSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopWidgetSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getWidgetSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listWidgetSessions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sendWidgetMessage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listWidgetMessages", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "acknowledgeWidgetMessages", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "completeWidgetMessage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reloadWidgets", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = CapgoWidgetKit()

    @objc func areActivitiesSupported(_ call: CAPPluginCall) {
        call.resolve(implementation.areActivitiesSupported())
    }

    @objc func startTemplateActivity(_ call: CAPPluginCall) {
        guard let definition = call.getObject("definition") else {
            call.reject(CapgoWidgetKitBridgeError.missingObject("definition").localizedDescription)
            return
        }

        guard let state = call.getObject("state") else {
            call.reject(CapgoWidgetKitBridgeError.missingObject("state").localizedDescription)
            return
        }

        Task {
            do {
                let payload = try await implementation.startTemplateActivity(
                    activityId: call.getString("activityId"),
                    definitionObject: definition,
                    stateObject: state,
                    openUrl: call.getString("openUrl"),
                    startLiveActivity: call.getBool("startLiveActivity") ?? true
                )
                call.resolve(payload)
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func updateTemplateActivity(_ call: CAPPluginCall) {
        guard let activityId = call.getString("activityId") else {
            call.reject("The `activityId` is required.")
            return
        }

        Task {
            do {
                let payload = try await implementation.updateTemplateActivity(
                    activityId: activityId,
                    definitionObject: call.getObject("definition"),
                    stateObject: call.getObject("state"),
                    openUrl: call.getString("openUrl")
                )
                call.resolve(payload)
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func endTemplateActivity(_ call: CAPPluginCall) {
        guard let activityId = call.getString("activityId") else {
            call.reject("The `activityId` is required.")
            return
        }

        Task {
            do {
                try await implementation.endTemplateActivity(
                    activityId: activityId,
                    stateObject: call.getObject("state")
                )
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func performTemplateAction(_ call: CAPPluginCall) {
        guard let activityId = call.getString("activityId") else {
            call.reject("The `activityId` is required.")
            return
        }

        guard let actionId = call.getString("actionId") else {
            call.reject("The `actionId` is required.")
            return
        }

        Task {
            do {
                let payload = try await implementation.performTemplateAction(
                    activityId: activityId,
                    actionId: actionId,
                    sourceId: call.getString("sourceId"),
                    payloadObject: call.getObject("payload")
                )
                call.resolve(payload)
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func getTemplateActivity(_ call: CAPPluginCall) {
        guard let activityId = call.getString("activityId") else {
            call.reject("The `activityId` is required.")
            return
        }

        do {
            call.resolve(try implementation.getTemplateActivity(activityId: activityId))
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func listTemplateActivities(_ call: CAPPluginCall) {
        do {
            call.resolve(try implementation.listTemplateActivities())
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func listTemplateEvents(_ call: CAPPluginCall) {
        do {
            call.resolve(
                try implementation.listTemplateEvents(
                    activityId: call.getString("activityId"),
                    unacknowledgedOnly: call.getBool("unacknowledgedOnly") ?? false
                )
            )
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func acknowledgeTemplateEvents(_ call: CAPPluginCall) {
        let eventIds = call.getArray("eventIds", String.self)

        do {
            try implementation.acknowledgeTemplateEvents(
                activityId: call.getString("activityId"),
                eventIds: eventIds
            )
            call.resolve()
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func startWidgetSession(_ call: CAPPluginCall) {
        do {
            call.resolve(
                try implementation.startWidgetSession(
                    widgetId: call.getString("widgetId"),
                    kind: call.getString("kind"),
                    stateObject: call.getObject("state"),
                    metadataObject: call.getObject("metadata")
                )
            )
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func updateWidgetSession(_ call: CAPPluginCall) {
        guard let widgetId = call.getString("widgetId") else {
            call.reject("The `widgetId` is required.")
            return
        }

        do {
            call.resolve(
                try implementation.updateWidgetSession(
                    widgetId: widgetId,
                    stateObject: call.getObject("state"),
                    metadataObject: call.getObject("metadata"),
                    merge: call.getBool("merge") ?? false
                )
            )
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func stopWidgetSession(_ call: CAPPluginCall) {
        guard let widgetId = call.getString("widgetId") else {
            call.reject("The `widgetId` is required.")
            return
        }

        do {
            try implementation.stopWidgetSession(widgetId: widgetId, stateObject: call.getObject("state"))
            call.resolve()
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func getWidgetSession(_ call: CAPPluginCall) {
        guard let widgetId = call.getString("widgetId") else {
            call.reject("The `widgetId` is required.")
            return
        }

        do {
            call.resolve(try implementation.getWidgetSession(widgetId: widgetId))
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func listWidgetSessions(_ call: CAPPluginCall) {
        do {
            call.resolve(try implementation.listWidgetSessions())
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func sendWidgetMessage(_ call: CAPPluginCall) {
        guard let widgetId = call.getString("widgetId") else {
            call.reject("The `widgetId` is required.")
            return
        }

        guard let name = call.getString("name") else {
            call.reject("The `name` is required.")
            return
        }

        do {
            call.resolve(
                try implementation.sendWidgetMessage(
                    widgetId: widgetId,
                    direction: call.getString("direction"),
                    name: name,
                    payloadObject: call.getObject("payload"),
                    expectsResponse: call.getBool("expectsResponse") ?? false
                )
            )
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func listWidgetMessages(_ call: CAPPluginCall) {
        do {
            call.resolve(
                try implementation.listWidgetMessages(
                    widgetId: call.getString("widgetId"),
                    direction: call.getString("direction"),
                    unacknowledgedOnly: call.getBool("unacknowledgedOnly") ?? false,
                    pendingOnly: call.getBool("pendingOnly") ?? false
                )
            )
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func acknowledgeWidgetMessages(_ call: CAPPluginCall) {
        do {
            try implementation.acknowledgeWidgetMessages(
                messageIds: call.getArray("messageIds", String.self),
                widgetId: call.getString("widgetId"),
                direction: call.getString("direction")
            )
            call.resolve()
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func completeWidgetMessage(_ call: CAPPluginCall) {
        guard let messageId = call.getString("messageId") else {
            call.reject("The `messageId` is required.")
            return
        }

        do {
            call.resolve(
                try implementation.completeWidgetMessage(
                    messageId: messageId,
                    responseObject: call.getObject("response"),
                    error: call.getString("error")
                )
            )
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func reloadWidgets(_ call: CAPPluginCall) {
        implementation.reloadWidgets(kind: call.getString("kind"))
        call.resolve()
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(implementation.getPluginVersion())
    }
}
