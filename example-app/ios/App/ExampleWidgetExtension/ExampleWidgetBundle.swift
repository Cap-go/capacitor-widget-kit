import ActivityKit
import SwiftUI
import WidgetKit
import CapgoWidgetKitShared

@main
struct ExampleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExampleTemplateHomeWidget()

        if #available(iOS 16.2, *) {
            ExampleTemplateLiveActivityWidget()
        }
    }
}

struct ExampleTemplateHomeWidget: Widget {
    private let kind = "ExampleTemplateHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CapgoTemplateWidgetTimelineProvider()) { entry in
            CapgoTemplateHomeWidgetView(entry: entry) { layout in
                ExampleTemplateSurfaceCard(layout: layout)
            } placeholder: {
                ExampleTemplateSurfaceCard(layout: nil)
            }
        }
        .configurationDisplayName("Capgo Template")
        .description("Home Screen widget rendered from the shared Capgo SVG template store.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.12, blue: 0.08), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.28)))
                        .foregroundStyle(.green)

                    Spacer()

                    if let layout {
                        Text("rev \(layout.revision)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Text(displayTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(displaySubtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.green.opacity(0.92))

                Spacer(minLength: 0)

                ExampleTemplateHotspotRow(layout: layout)
            }
            .padding(18)
        }
    }

    private var displayTitle: String {
        guard let layout else {
            return "Capgo Template Widget"
        }

        if let title = extractSvgText(matching: "Chest Day|Bench Press|Workout") {
            return title
        }

        return layout.templateId.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private var displaySubtitle: String {
        guard let layout else {
            return "Start a template activity from the demo app"
        }

        if let timer = extractSvgText(matching: "\\d+:\\d{2}") {
            return "Rest timer · \(timer)"
        }

        return layout.status.capitalized
    }

    private func extractSvgText(matching pattern: String) -> String? {
        guard let layout else { return nil }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(layout.svg.startIndex..<layout.svg.endIndex, in: layout.svg)
        guard let match = regex.firstMatch(in: layout.svg, range: range),
              let swiftRange = Range(match.range, in: layout.svg) else {
            return nil
        }
        return String(layout.svg[swiftRange])
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
            Text(shortLabel(for: layout))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(.green)
        }
    }

    private func shortLabel(for layout: CapgoResolvedTemplateLayout) -> String {
        if let hotspot = layout.hotspots.first?.label, !hotspot.isEmpty {
            return String(hotspot.prefix(3)).uppercased()
        }
        return "\(layout.revision)"
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
