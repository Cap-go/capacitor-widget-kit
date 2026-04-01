import Capacitor
import Foundation

@objc(CapgoWidgetKitPlugin)
public class CapgoWidgetKitPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CapgoWidgetKitPlugin"
    public let jsName = "CapgoWidgetKit"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "areActivitiesSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startWorkoutLiveActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateWorkoutLiveActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endWorkoutLiveActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "completeWorkoutSet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getStoredWorkoutSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listWorkoutLiveActivities", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = CapgoWidgetKit()

    @objc func areActivitiesSupported(_ call: CAPPluginCall) {
        call.resolve(implementation.areActivitiesSupported())
    }

    @objc func startWorkoutLiveActivity(_ call: CAPPluginCall) {
        guard let session = call.getObject("session") else {
            call.reject(CapgoWidgetKitBridgeError.missingSession.localizedDescription)
            return
        }

        Task {
            do {
                let result = try await implementation.startWorkoutLiveActivity(sessionObject: session)
                call.resolve(result)
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func updateWorkoutLiveActivity(_ call: CAPPluginCall) {
        guard let activityId = call.getString("activityId") else {
            call.reject("The `activityId` is required.")
            return
        }

        guard let session = call.getObject("session") else {
            call.reject(CapgoWidgetKitBridgeError.missingSession.localizedDescription)
            return
        }

        Task {
            do {
                try await implementation.updateWorkoutLiveActivity(activityId: activityId, sessionObject: session)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func endWorkoutLiveActivity(_ call: CAPPluginCall) {
        guard let activityId = call.getString("activityId") else {
            call.reject("The `activityId` is required.")
            return
        }

        let session = call.getObject("session")
        Task {
            do {
                try await implementation.endWorkoutLiveActivity(activityId: activityId, sessionObject: session)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func completeWorkoutSet(_ call: CAPPluginCall) {
        guard let sessionId = call.getString("sessionId") else {
            call.reject("The `sessionId` is required.")
            return
        }

        Task {
            do {
                let payload = try await implementation.completeWorkoutSet(
                    sessionId: sessionId,
                    activityId: call.getString("activityId")
                )
                call.resolve(payload)
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func getStoredWorkoutSession(_ call: CAPPluginCall) {
        do {
            let payload = try implementation.getStoredWorkoutSession(
                sessionId: call.getString("sessionId"),
                activityId: call.getString("activityId")
            )
            call.resolve(payload)
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func listWorkoutLiveActivities(_ call: CAPPluginCall) {
        do {
            call.resolve(try implementation.listWorkoutLiveActivities())
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(implementation.getPluginVersion())
    }
}
