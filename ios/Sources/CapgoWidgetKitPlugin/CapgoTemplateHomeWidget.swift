#if canImport(SwiftUI) && canImport(WidgetKit)
import Foundation
import OSLog
import SwiftUI
import WidgetKit

@available(iOS 16.0, *)
public struct CapgoTemplateWidgetEntry: TimelineEntry, Sendable {
    public let date: Date
    public let layout: CapgoResolvedTemplateLayout?

    public init(date: Date, layout: CapgoResolvedTemplateLayout?) {
        self.date = date
        self.layout = layout
    }
}

@available(iOS 16.0, *)
public struct CapgoTemplateWidgetTimelineProvider: TimelineProvider {
    public typealias Entry = CapgoTemplateWidgetEntry

    private let surface: CapgoTemplateSurface
    private let status: String?
    private let bundle: Bundle
    private let refreshInterval: TimeInterval
    private let bridge: CapgoTemplateWidgetBridge

    public init(
        surface: CapgoTemplateSurface = .homeScreen,
        status: String? = "active",
        bundle: Bundle = .main,
        refreshInterval: TimeInterval = 15 * 60,
        bridge: CapgoTemplateWidgetBridge = CapgoTemplateWidgetBridge()
    ) {
        self.surface = surface
        self.status = status
        self.bundle = bundle
        self.refreshInterval = refreshInterval
        self.bridge = bridge
    }

    public func placeholder(in context: Context) -> CapgoTemplateWidgetEntry {
        CapgoTemplateWidgetEntry(date: Date(), layout: nil)
    }

    public func getSnapshot(in context: Context, completion: @escaping (CapgoTemplateWidgetEntry) -> Void) {
        completion(entry(date: Date()))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CapgoTemplateWidgetEntry>) -> Void) {
        let date = Date()
        let entry = entry(date: date)
        let nextReload = date.addingTimeInterval(max(refreshInterval, 60))
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func entry(date: Date) -> CapgoTemplateWidgetEntry {
        do {
            let layout = try bridge.resolveLatestLayout(surface: surface, status: status, bundle: bundle, now: date)
            return CapgoTemplateWidgetEntry(date: date, layout: layout)
        } catch {
            logTemplateHomeWidgetResolutionFailure(error, surface: surface, bundle: bundle, status: status)
            return CapgoTemplateWidgetEntry(date: date, layout: nil)
        }
    }
}

@available(iOS 16.0, *)
public struct CapgoTemplateHomeWidgetView<SVGContent: View, Placeholder: View>: View {
    private let entry: CapgoTemplateWidgetEntry
    private let showsHotspots: Bool
    private let svgContent: (CapgoResolvedTemplateLayout) -> SVGContent
    private let placeholder: () -> Placeholder

    public init(
        entry: CapgoTemplateWidgetEntry,
        showsHotspots: Bool = true,
        @ViewBuilder svgContent: @escaping (CapgoResolvedTemplateLayout) -> SVGContent,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.entry = entry
        self.showsHotspots = showsHotspots
        self.svgContent = svgContent
        self.placeholder = placeholder
    }

    public var body: some View {
        CapgoTemplateSurfaceView(
            layout: entry.layout,
            showsHotspots: showsHotspots,
            svgContent: svgContent,
            placeholder: placeholder
        )
        .widgetURL(entry.layout?.openUrl.flatMap(URL.init(string:)))
    }
}

@available(iOS 16.0, *)
private enum CapgoTemplateHomeWidgetLog {
    static let logger = Logger(subsystem: "app.capgo.widgetkit", category: "TemplateHomeWidget")
}

@available(iOS 16.0, *)
private func logTemplateHomeWidgetResolutionFailure(
    _ error: Error,
    surface: CapgoTemplateSurface,
    bundle: Bundle,
    status: String?
) {
    let statusContext = status ?? "any"
    let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
    let context = "status=\(statusContext) surface=\(surface.rawValue) bundle=\(bundleIdentifier)"
    CapgoTemplateHomeWidgetLog.logger.error(
        "Failed to resolve Home Screen widget template \(context, privacy: .public): \(error.localizedDescription, privacy: .public)"
    )
}
#endif
