#if canImport(SwiftUI)
import Foundation
import OSLog
import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

@available(iOS 16.0, *)
public struct CapgoTemplateClearHotspotLabel: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
    }
}

@available(iOS 16.0, *)
public struct CapgoTemplateHotspotButton<Label: View>: View {
    public let activityId: String
    public let hotspot: CapgoTemplateResolvedHotspot
    private let label: () -> Label

    public init(
        activityId: String,
        hotspot: CapgoTemplateResolvedHotspot,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.activityId = activityId
        self.hotspot = hotspot
        self.label = label
    }

    public var body: some View {
        Group {
            #if canImport(AppIntents)
            if #available(iOS 17.0, *) {
                Button(
                    intent: CapgoTemplateActionIntent(
                        activityId: activityId,
                        actionId: hotspot.actionId,
                        sourceId: hotspot.id,
                        payloadJSON: hotspot.payloadJSON
                    )
                ) {
                    label()
                }
                .buttonStyle(.plain)
            } else {
                fallbackLabel
            }
            #else
            fallbackLabel
            #endif
        }
        .accessibilityLabel(Text(hotspot.label ?? hotspot.actionId))
    }

    private var fallbackLabel: some View {
        label()
            .allowsHitTesting(false)
    }
}

@available(iOS 16.0, *)
public extension CapgoTemplateHotspotButton where Label == CapgoTemplateClearHotspotLabel {
    init(activityId: String, hotspot: CapgoTemplateResolvedHotspot) {
        self.init(activityId: activityId, hotspot: hotspot) {
            CapgoTemplateClearHotspotLabel()
        }
    }
}

@available(iOS 16.0, *)
public struct CapgoTemplateSurfaceView<SVGContent: View, Placeholder: View>: View {
    public let layout: CapgoResolvedTemplateLayout?
    public let showsHotspots: Bool
    private let svgContent: (CapgoResolvedTemplateLayout) -> SVGContent
    private let placeholder: () -> Placeholder

    public init(
        layout: CapgoResolvedTemplateLayout?,
        showsHotspots: Bool = true,
        @ViewBuilder svgContent: @escaping (CapgoResolvedTemplateLayout) -> SVGContent,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.layout = layout
        self.showsHotspots = showsHotspots
        self.svgContent = svgContent
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let layout {
                surface(layout)
            } else {
                placeholder()
            }
        }
    }

    private func surface(_ layout: CapgoResolvedTemplateLayout) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                svgContent(layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsHotspots {
                    ForEach(layout.hotspots, id: \.id) { hotspot in
                        CapgoTemplateHotspotButton(activityId: layout.activityId, hotspot: hotspot)
                            .frame(
                                width: hotspotWidth(hotspot, in: proxy.size, layout: layout),
                                height: hotspotHeight(hotspot, in: proxy.size, layout: layout)
                            )
                            .position(
                                x: hotspotCenterX(hotspot, in: proxy.size, layout: layout),
                                y: hotspotCenterY(hotspot, in: proxy.size, layout: layout)
                            )
                    }
                }
            }
        }
        .aspectRatio(CGFloat(layout.width / max(layout.height, 1)), contentMode: .fit)
    }

    private func hotspotWidth(
        _ hotspot: CapgoTemplateResolvedHotspot,
        in size: CGSize,
        layout: CapgoResolvedTemplateLayout
    ) -> CGFloat {
        max(1, size.width * CGFloat(hotspot.width / max(layout.width, 1)))
    }

    private func hotspotHeight(
        _ hotspot: CapgoTemplateResolvedHotspot,
        in size: CGSize,
        layout: CapgoResolvedTemplateLayout
    ) -> CGFloat {
        max(1, size.height * CGFloat(hotspot.height / max(layout.height, 1)))
    }

    private func hotspotCenterX(
        _ hotspot: CapgoTemplateResolvedHotspot,
        in size: CGSize,
        layout: CapgoResolvedTemplateLayout
    ) -> CGFloat {
        size.width * CGFloat((hotspot.x + hotspot.width / 2) / max(layout.width, 1))
    }

    private func hotspotCenterY(
        _ hotspot: CapgoTemplateResolvedHotspot,
        in size: CGSize,
        layout: CapgoResolvedTemplateLayout
    ) -> CGFloat {
        size.height * CGFloat((hotspot.y + hotspot.height / 2) / max(layout.height, 1))
    }
}

@available(iOS 16.0, *)
public struct CapgoTemplateWidgetSurface<SVGContent: View, Placeholder: View>: View {
    private let activityId: String
    private let surface: CapgoTemplateSurface
    private let bundle: Bundle
    private let showsHotspots: Bool
    private let now: () -> Date
    private let svgContent: (CapgoResolvedTemplateLayout) -> SVGContent
    private let placeholder: () -> Placeholder

    public init(
        activityId: String,
        surface: CapgoTemplateSurface = .lockScreen,
        bundle: Bundle = .main,
        showsHotspots: Bool = true,
        now: @escaping () -> Date = { Date() },
        @ViewBuilder svgContent: @escaping (CapgoResolvedTemplateLayout) -> SVGContent,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.activityId = activityId
        self.surface = surface
        self.bundle = bundle
        self.showsHotspots = showsHotspots
        self.now = now
        self.svgContent = svgContent
        self.placeholder = placeholder
    }

    public var body: some View {
        CapgoTemplateSurfaceView(
            layout: resolvedLayout,
            showsHotspots: showsHotspots,
            svgContent: svgContent,
            placeholder: placeholder
        )
    }

    private var resolvedLayout: CapgoResolvedTemplateLayout? {
        do {
            return try CapgoTemplateWidgetBridge().resolveLayout(
                activityId: activityId,
                surface: surface,
                bundle: bundle,
                now: now()
            )
        } catch {
            logTemplateWidgetResolutionFailure(error, surface: surface, bundle: bundle, activityId: activityId)
            return nil
        }
    }
}

@available(iOS 16.0, *)
public struct CapgoTemplateLatestWidgetSurface<SVGContent: View, Placeholder: View>: View {
    private let surface: CapgoTemplateSurface
    private let status: String?
    private let bundle: Bundle
    private let showsHotspots: Bool
    private let now: () -> Date
    private let svgContent: (CapgoResolvedTemplateLayout) -> SVGContent
    private let placeholder: () -> Placeholder

    public init(
        surface: CapgoTemplateSurface = .lockScreen,
        status: String? = "active",
        bundle: Bundle = .main,
        showsHotspots: Bool = true,
        now: @escaping () -> Date = { Date() },
        @ViewBuilder svgContent: @escaping (CapgoResolvedTemplateLayout) -> SVGContent,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.surface = surface
        self.status = status
        self.bundle = bundle
        self.showsHotspots = showsHotspots
        self.now = now
        self.svgContent = svgContent
        self.placeholder = placeholder
    }

    public var body: some View {
        CapgoTemplateSurfaceView(
            layout: resolvedLayout,
            showsHotspots: showsHotspots,
            svgContent: svgContent,
            placeholder: placeholder
        )
    }

    private var resolvedLayout: CapgoResolvedTemplateLayout? {
        do {
            return try CapgoTemplateWidgetBridge().resolveLatestLayout(
                surface: surface,
                status: status,
                bundle: bundle,
                now: now()
            )
        } catch {
            logTemplateWidgetResolutionFailure(error, surface: surface, bundle: bundle, status: status)
            return nil
        }
    }
}

@available(iOS 16.0, *)
private enum CapgoTemplateWidgetSurfaceLog {
    static let logger = Logger(subsystem: "app.capgo.widgetkit", category: "TemplateWidgetSurface")
}

@available(iOS 16.0, *)
private func logTemplateWidgetResolutionFailure(
    _ error: Error,
    surface: CapgoTemplateSurface,
    bundle: Bundle,
    activityId: String? = nil,
    status: String? = nil
) {
    let activityContext = activityId ?? "latest"
    let statusContext = status ?? "any"
    let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
    let context =
        "activityId=\(activityContext) status=\(statusContext) surface=\(surface.rawValue) bundle=\(bundleIdentifier)"
    CapgoTemplateWidgetSurfaceLog.logger.error(
        "Failed to resolve template widget surface \(context, privacy: .public): \(error.localizedDescription, privacy: .public)"
    )
}
#endif
