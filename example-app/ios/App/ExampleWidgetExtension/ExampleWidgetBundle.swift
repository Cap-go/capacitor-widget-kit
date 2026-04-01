import ActivityKit
import SwiftUI
import WidgetKit
import CapgoWidgetKitPlugin

@main
struct ExampleWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            ExampleTemplateLiveActivityWidget()
        }
    }
}

@available(iOS 16.2, *)
struct ExampleTemplateLiveActivityWidget: Widget {
    private let bridge = CapgoTemplateWidgetBridge()

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CapgoTemplateActivityAttributes.self) { context in
            let layout = resolvedLayout(activityId: context.attributes.activityId, surface: .lockScreen)
            ExampleTemplateSurfaceCard(layout: layout)
                .widgetURL(layout?.openUrl.flatMap(URL.init(string:)))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExampleTemplateDynamicIslandLabel(
                        layout: resolvedLayout(activityId: context.attributes.activityId, surface: .dynamicIslandExpanded)
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExampleTemplateHotspotRow(
                        layout: resolvedLayout(activityId: context.attributes.activityId, surface: .dynamicIslandExpanded)
                    )
                }
            } compactLeading: {
                ExampleTemplateBadge(
                    layout: resolvedLayout(activityId: context.attributes.activityId, surface: .dynamicIslandCompactLeading)
                )
            } compactTrailing: {
                ExampleTemplateBadge(
                    layout: resolvedLayout(activityId: context.attributes.activityId, surface: .dynamicIslandCompactTrailing)
                )
            } minimal: {
                ExampleTemplateBadge(
                    layout: resolvedLayout(activityId: context.attributes.activityId, surface: .dynamicIslandMinimal)
                )
            }
        }
    }

    private func resolvedLayout(activityId: String, surface: CapgoTemplateSurface) -> CapgoResolvedTemplateLayout? {
        try? bridge.resolveLayout(activityId: activityId, surface: surface)
    }
}

@available(iOS 16.2, *)
private struct ExampleTemplateSurfaceCard: View {
    let layout: CapgoResolvedTemplateLayout?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)

            VStack(alignment: .leading, spacing: 10) {
                Text(layout?.templateId ?? "No template activity")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Plug your SVG renderer here")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green.opacity(0.9))

                Text(previewText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(4)

                Spacer(minLength: 0)

                ExampleTemplateHotspotRow(layout: layout)
            }
            .padding(18)
        }
    }

    private var previewText: String {
        guard let layout else {
            return "The widget extension can resolve SVG, hotspots, and deep links from the shared store."
        }

        return layout.svg
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .prefix(160)
            .description
    }
}

@available(iOS 16.2, *)
private struct ExampleTemplateDynamicIslandLabel: View {
    let layout: CapgoResolvedTemplateLayout?

    var body: some View {
        Text(layout?.templateId ?? "Template")
            .font(.headline)
            .lineLimit(1)
    }
}

@available(iOS 16.2, *)
private struct ExampleTemplateBadge: View {
    let layout: CapgoResolvedTemplateLayout?

    var body: some View {
        if let layout {
            Text("\(layout.revision)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.green)
        } else {
            Image(systemName: "square.dashed")
                .foregroundStyle(.green)
        }
    }
}

@available(iOS 16.2, *)
private struct ExampleTemplateHotspotRow: View {
    let layout: CapgoResolvedTemplateLayout?

    var body: some View {
        HStack(spacing: 8) {
            if let hotspots = layout?.hotspots, !hotspots.isEmpty {
                ForEach(Array(hotspots.prefix(2)), id: \.id) { hotspot in
                    ExampleTemplateHotspotButton(
                        activityId: layout?.activityId ?? "",
                        actionId: hotspot.actionId,
                        sourceId: hotspot.id,
                        payloadJSON: hotspot.payloadJSON,
                        label: hotspot.label ?? hotspot.actionId
                    )
                }
            } else {
                Text("No hotspots")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

@available(iOS 16.2, *)
private struct ExampleTemplateHotspotButton: View {
    let activityId: String
    let actionId: String
    let sourceId: String
    let payloadJSON: String?
    let label: String

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Button(
                    intent: CapgoTemplateActionIntent(
                        activityId: activityId,
                        actionId: actionId,
                        sourceId: sourceId,
                        payloadJSON: payloadJSON
                    )
                ) {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.green.opacity(0.24)))
            }
        }
    }
}
