#if canImport(ActivityKit) && canImport(WidgetKit)
import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
public struct CapgoWorkoutLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityRootView(
                attributes: context.attributes,
                contentState: context.state,
                displayContext: .lockScreen
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutDynamicIslandLeadingView(attributes: context.attributes)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutDynamicIslandTrailingView(attributes: context.attributes, contentState: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    WorkoutDynamicIslandCenterView(attributes: context.attributes)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    WorkoutDynamicIslandBottomView(attributes: context.attributes, contentState: context.state)
                }
            } compactLeading: {
                WorkoutCompactLeadingView(contentState: context.state)
            } compactTrailing: {
                WorkoutCompactTrailingView(contentState: context.state)
            } minimal: {
                WorkoutMinimalView(contentState: context.state)
            }
        }
    }
}

private enum WorkoutDisplayContext {
    case lockScreen
    case dynamicIsland
}

@available(iOS 16.2, *)
private struct WorkoutActivityRootView: View {
    let attributes: WorkoutActivityAttributes
    let contentState: WorkoutActivityAttributes.ContentState
    let displayContext: WorkoutDisplayContext

    private var session: WorkoutSession? {
        try? WorkoutActivityStore.make().loadEnvelope(sessionId: attributes.sessionId)?.session
    }

    private var widgetURL: URL? {
        if let explicit = attributes.deepLinkUrl.flatMap(URL.init(string:)) {
            return explicit
        }
        if let explicit = session?.deepLinkUrl.flatMap(URL.init(string:)) {
            return explicit
        }
        return URL(string: "widgetkitdemo://session/\(attributes.sessionId)")
    }

    var body: some View {
        Group {
            if let session {
                WorkoutLiveActivityView(
                    session: session,
                    contentState: contentState,
                    displayContext: displayContext
                )
            } else {
                MissingSessionView()
            }
        }
        .widgetURL(widgetURL)
    }
}

@available(iOS 16.2, *)
private struct WorkoutLiveActivityView: View {
    let session: WorkoutSession
    let contentState: WorkoutActivityAttributes.ContentState
    let displayContext: WorkoutDisplayContext

    private var timer: WorkoutActiveTimer? {
        session.activeTimer()
    }

    private var currentExercise: WorkoutExercise? {
        session.currentExercise
    }

    private var currentSet: WorkoutSet? {
        session.currentSet
    }

    var body: some View {
        if session.isComplete {
            CompletedWorkoutView(session: session)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let activeTimer = session.activeTimer(now: timeline.date)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black)

                    if let activeTimer {
                        RestProgressBackground(timer: activeTimer, now: timeline.date)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        WorkoutIndicatorBar(session: session)
                        HStack(alignment: .top, spacing: 12) {
                            WorkoutExerciseThumbnail(exercise: currentExercise)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentExercise?.title ?? session.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                if let subtitle = currentExercise?.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                }

                                if let recommendation = currentSet?.recommendation, !recommendation.isEmpty {
                                    WorkoutRecommendationPill(text: recommendation)
                                }
                            }

                            Spacer(minLength: 8)

                            if let activeTimer {
                                WorkoutTimerLabel(timer: activeTimer, now: timeline.date)
                            }
                        }

                        HStack(alignment: .bottom, spacing: 12) {
                            Text(currentSet?.title ?? "No active set")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.7)
                                .lineLimit(2)

                            Spacer(minLength: 8)

                            WorkoutCompletionButton(sessionId: session.sessionId)
                        }
                    }
                    .padding(18)
                }
            }
        }
    }
}

@available(iOS 16.2, *)
private struct CompletedWorkoutView: View {
    let session: WorkoutSession

    var body: some View {
        VStack(spacing: 16) {
            WorkoutIndicatorBar(session: session)

            Text(session.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text("All sets completed")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capgoMint)

            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.capgoMint)
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
private struct WorkoutIndicatorBar: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                if index == session.activeExerciseIndex {
                    HStack(spacing: 4) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { setIndex, set in
                            Capsule()
                                .fill(color(for: setIndex, set: set))
                                .frame(width: 10, height: 6)
                        }
                    }
                    .padding(.trailing, 2)
                } else {
                    Capsule()
                        .fill(session.exerciseCompleted(at: index) ? Color.capgoMint : Color.white.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
        }
    }

    private func color(for setIndex: Int, set: WorkoutSet) -> Color {
        if set.completedAt != nil {
            return .capgoMint
        }
        if setIndex == session.activeSetIndex {
            return .white
        }
        return Color.white.opacity(0.28)
    }
}

@available(iOS 16.2, *)
private struct WorkoutExerciseThumbnail: View {
    let exercise: WorkoutExercise?

    var body: some View {
        Group {
            if let imageAssetName = exercise?.imageAssetName, !imageAssetName.isEmpty {
                Image(imageAssetName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: exercise?.iconSystemName ?? "figure.strengthtraining.traditional")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif
