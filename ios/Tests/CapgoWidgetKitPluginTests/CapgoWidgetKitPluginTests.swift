import XCTest
@testable import CapgoWidgetKitPlugin

final class CapgoWidgetKitPluginTests: XCTestCase {
    func testNotificationSettingsDecodeFromBoolean() throws {
        let json = Data("true".utf8)
        let decoded = try JSONDecoder().decode(WorkoutNotificationSettings.self, from: json)

        XCTAssertTrue(decoded.enabled)
        XCTAssertNil(decoded.title)
        XCTAssertNil(decoded.body)
    }

    func testCompletingActiveSetMarksTimestampAndAdvances() {
        var session = WorkoutSession(
            sessionId: "session-1",
            title: "Chest Day",
            startedAt: 1_774_895_138_204,
            activeExerciseIndex: 0,
            activeSetIndex: 0,
            exercises: [
                WorkoutExercise(
                    id: "exercise-1",
                    title: "Arnold Press",
                    sets: [
                        WorkoutSet(
                            title: "120 kg · 9 reps",
                            completedAt: nil,
                            timerDurationMs: 90_000,
                            nextExerciseIndex: 0,
                            nextSetIndex: 1
                        ),
                        WorkoutSet(
                            title: "120 kg · 8 reps",
                            completedAt: nil,
                            timerDurationMs: nil,
                            nextExerciseIndex: 1,
                            nextSetIndex: 0
                        )
                    ]
                )
            ]
        )

        session.completeActiveSet(at: 1_000)

        XCTAssertEqual(session.exercises[0].sets[0].completedAt, 1_000)
        XCTAssertEqual(session.activeExerciseIndex, 0)
        XCTAssertEqual(session.activeSetIndex, 1)
    }

    func testActiveTimerIsDerivedFromPreviousSetTransition() {
        let session = WorkoutSession(
            sessionId: "session-1",
            title: "Chest Day",
            startedAt: 1_774_895_138_204,
            activeExerciseIndex: 0,
            activeSetIndex: 1,
            exercises: [
                WorkoutExercise(
                    id: "exercise-1",
                    title: "Arnold Press",
                    sets: [
                        WorkoutSet(
                            title: "120 kg · 9 reps",
                            completedAt: 1_000,
                            timerDurationMs: 90_000,
                            nextExerciseIndex: 0,
                            nextSetIndex: 1
                        ),
                        WorkoutSet(
                            title: "120 kg · 8 reps",
                            completedAt: nil,
                            timerDurationMs: nil,
                            nextExerciseIndex: nil,
                            nextSetIndex: nil
                        )
                    ]
                )
            ]
        )

        let timer = session.activeTimer(now: Date(timeIntervalSince1970: 30))

        XCTAssertNotNil(timer)
        XCTAssertEqual(timer?.startedAtMs, 1_000)
        XCTAssertEqual(timer?.durationMs, 90_000)
    }
}
