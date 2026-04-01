// swiftlint:disable function_body_length
import XCTest
@testable import CapgoWidgetKitPlugin

final class CapgoWidgetKitPluginTests: XCTestCase {
    func testResolveSvgInterpolatesStateTimerAndMetaScope() {
        let definition = makeTemplateDefinition()
        let record = TemplateRuntime.makeRecord(
            activityId: "activity-1",
            definitionObject: definition,
            stateObject: ["title": "Chest Day"],
            openUrl: "widgetkitdemo://session/session-1",
            nowMs: 1_000
        )

        let layoutObject = ((definition["layouts"] as? [String: Any])?["lockScreen"] as? [String: Any]) ?? [:]
        let svg = TemplateRuntime.resolveSvg(layoutObject: layoutObject, record: record, nowMs: 1_000)

        XCTAssertTrue(svg.contains("Chest Day"))
        XCTAssertTrue(svg.contains("1:30"))
        XCTAssertTrue(svg.contains("template-1"))
    }

    func testApplyActionUsesSourceIdPayloadAndTimerMutation() throws {
        let definition = makeTemplateDefinition()
        let record = TemplateRuntime.makeRecord(
            activityId: "activity-1",
            definitionObject: definition,
            stateObject: ["title": "Chest Day", "count": 0],
            openUrl: nil,
            nowMs: 1_000
        )

        let (nextRecord, event) = try TemplateRuntime.applyAction(
            actionId: "complete-set",
            sourceId: "primary-complete-button",
            payloadObject: [
                "label": "Bench Press",
                "durationMs": 30_000
            ],
            record: record,
            nowMs: 5_000
        )

        XCTAssertEqual((nextRecord.state["count"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(nextRecord.state["lastSource"] as? String, "primary-complete-button")
        XCTAssertEqual(nextRecord.state["lastLabel"] as? String, "Bench Press")
        XCTAssertEqual(nextRecord.state["summary"] as? String, "primary-complete-button :: Bench Press")

        let timer = nextRecord.timers["cooldown"]
        XCTAssertEqual(timer?.durationMs, 30_000)
        XCTAssertEqual(timer?.startedAtMs, 5_000)
        XCTAssertEqual(timer?.status, "running")

        XCTAssertEqual(event.sourceId, "primary-complete-button")

        let serializedEvent = try TemplateRuntime.serializeEvent(event)
        XCTAssertEqual(serializedEvent["sourceId"] as? String, "primary-complete-button")

        let payload = serializedEvent["payload"] as? [String: Any]
        XCTAssertEqual(payload?["label"] as? String, "Bench Press")

        let timers = serializedEvent["timers"] as? [String: Any]
        let cooldown = timers?["cooldown"] as? [String: Any]
        XCTAssertEqual((cooldown?["durationMs"] as? NSNumber)?.intValue, 30_000)
        XCTAssertEqual((cooldown?["startedAt"] as? NSNumber)?.intValue, 5_000)
        XCTAssertEqual(cooldown?["status"] as? String, "running")
    }

    private func makeTemplateDefinition() -> [String: Any] {
        [
            "id": "template-1",
            "timers": [
                [
                    "id": "cooldown",
                    "durationMs": 90_000,
                    "autoStart": true
                ]
            ],
            "actions": [
                [
                    "id": "complete-set",
                    "eventName": "widget.set.completed",
                    "patches": [
                        [
                            "op": "increment",
                            "path": "count",
                            "amount": 1
                        ],
                        [
                            "op": "set",
                            "path": "lastSource",
                            "valueTemplate": "{{action.sourceId}}"
                        ],
                        [
                            "op": "set",
                            "path": "lastLabel",
                            "valueTemplate": "{{action.payload.label}}"
                        ],
                        [
                            "op": "set",
                            "path": "summary",
                            "valueTemplate": "{{action.sourceId}} :: {{action.payload.label}}"
                        ]
                    ],
                    "timerMutations": [
                        [
                            "op": "setDuration",
                            "timerId": "cooldown",
                            "durationPath": "action.payload.durationMs"
                        ],
                        [
                            "op": "restart",
                            "timerId": "cooldown",
                            "durationPath": "action.payload.durationMs"
                        ]
                    ]
                ]
            ],
            "layouts": [
                "lockScreen": [
                    "width": 100,
                    "height": 40,
                    "svg": "<svg>{{state.title}}|{{timers.cooldown.remainingText}}|{{meta.template.id}}</svg>"
                ]
            ]
        ]
    }
}
// swiftlint:enable function_body_length
