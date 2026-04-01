#if canImport(ActivityKit) && canImport(WidgetKit)
import ActivityKit
import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

@available(iOS 16.2, *)
struct WorkoutRecommendationPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.bold())
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.capgoBlue))
    }
}

@available(iOS 16.2, *)
struct WorkoutTimerLabel: View {
    let timer: WorkoutActiveTimer
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.subheadline.bold())
            Text(timer.remainingText(now: now))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(Color.capgoMint)
    }
}

@available(iOS 16.2, *)
struct RestProgressBackground: View {
    let timer: WorkoutActiveTimer
    let now: Date

    var body: some View {
        GeometryReader { proxy in
            let progress = timer.progress(now: now)
            let remainingWidth = proxy.size.width * (1 - progress)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.capgoMint.opacity(0.75))
                    .frame(width: remainingWidth)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

@available(iOS 16.2, *)
struct WorkoutCompletionButton: View {
    let sessionId: String

    var body: some View {
        Group {
            #if canImport(AppIntents)
            if #available(iOS 17.0, *) {
                Button(intent: CompleteSetIntent(sessionId: sessionId)) {
                    buttonBody
                }
                .buttonStyle(.plain)
            } else {
                buttonBody
            }
            #else
            buttonBody
            #endif
        }
    }

    private var buttonBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.capgoMint)
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 76, height: 62)
    }
}

@available(iOS 16.2, *)
struct MissingSessionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capgo Widget Kit")
                .font(.headline)
                .foregroundStyle(.white)
            Text("No shared workout session was found. Check the App Group and Info.plist setup.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
        )
    }
}

@available(iOS 16.2, *)
struct WorkoutDynamicIslandLeadingView: View {
    let attributes: WorkoutActivityAttributes

    var body: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .foregroundStyle(Color.capgoMint)
    }
}

@available(iOS 16.2, *)
struct WorkoutDynamicIslandTrailingView: View {
    let attributes: WorkoutActivityAttributes
    let contentState: WorkoutActivityAttributes.ContentState

    private var session: WorkoutSession? {
        try? WorkoutActivityStore.make().loadEnvelope(sessionId: attributes.sessionId)?.session
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if let timer = session?.activeTimer(now: timeline.date) {
                Text(timer.remainingText(now: timeline.date))
                    .monospacedDigit()
                    .foregroundStyle(Color.capgoMint)
            } else if contentState.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.capgoMint)
            }
        }
    }
}

@available(iOS 16.2, *)
struct WorkoutDynamicIslandCenterView: View {
    let attributes: WorkoutActivityAttributes

    var body: some View {
        Text(attributes.title)
            .font(.headline)
            .lineLimit(1)
    }
}

@available(iOS 16.2, *)
struct WorkoutDynamicIslandBottomView: View {
    let attributes: WorkoutActivityAttributes
    let contentState: WorkoutActivityAttributes.ContentState

    private var session: WorkoutSession? {
        try? WorkoutActivityStore.make().loadEnvelope(sessionId: attributes.sessionId)?.session
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(session?.currentSet?.title ?? "Session complete")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            if !(session?.isComplete ?? contentState.isComplete) {
                WorkoutCompletionButton(sessionId: attributes.sessionId)
                    .frame(width: 54, height: 42)
            }
        }
    }
}

@available(iOS 16.2, *)
struct WorkoutCompactLeadingView: View {
    let contentState: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let activeExerciseIndex = contentState.activeExerciseIndex, let activeSetIndex = contentState.activeSetIndex {
            Text("\(activeExerciseIndex + 1).\(activeSetIndex + 1)")
                .font(.caption2.monospacedDigit())
        } else {
            Image(systemName: "checkmark")
        }
    }
}

@available(iOS 16.2, *)
struct WorkoutCompactTrailingView: View {
    let contentState: WorkoutActivityAttributes.ContentState

    var body: some View {
        if contentState.isComplete {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.capgoMint)
        } else if let timerStartedAtMs = contentState.timerStartedAtMs, let timerDurationMs = contentState.timerDurationMs {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let timer = WorkoutActiveTimer(
                    source: WorkoutSetReference(
                        exerciseIndex: 0,
                        setIndex: 0,
                        set: WorkoutSet(title: ""),
                        exercise: WorkoutExercise(id: "placeholder", title: "", sets: [])
                    ),
                    startedAtMs: timerStartedAtMs,
                    durationMs: timerDurationMs
                )
                Text(timer.remainingText(now: timeline.date))
                    .font(.caption2.monospacedDigit())
            }
        }
    }
}

@available(iOS 16.2, *)
struct WorkoutMinimalView: View {
    let contentState: WorkoutActivityAttributes.ContentState

    var body: some View {
        if contentState.isComplete {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.capgoMint)
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(Color.capgoMint)
        }
    }
}

extension Color {
    static let capgoMint = Color(red: 0.0, green: 0.85, blue: 0.62)
    static let capgoBlue = Color(red: 0.33, green: 0.56, blue: 1.0)
}
#endif
