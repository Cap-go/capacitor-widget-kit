#if canImport(SwiftUI) && canImport(UIKit)
import SwiftDraw
import SwiftUI
import UIKit

/// Rasterizes resolved template SVG markup into a bitmap.
///
/// WidgetKit archives widget views as static snapshots, so the SVG is drawn into a `UIImage`
/// with CoreGraphics instead of relying on live SwiftUI drawing.
public enum CapgoTemplateSvgRenderer {
    /// Renders `svg` aspect-fit and centered inside `size` (in points).
    /// Returns `nil` when the markup cannot be parsed or the target size is empty.
    public static func render(svg: String, size: CGSize, scale: CGFloat = 0) -> UIImage? {
        guard size.width > 0, size.height > 0, let parsed = parse(svg) else {
            return nil
        }
        return fitted(parsed, in: size).rasterize(scale: scale)
    }

    /// Renders `svg` at the intrinsic size declared by its `width`/`height` or `viewBox`.
    public static func render(svg: String, scale: CGFloat = 0) -> UIImage? {
        guard let parsed = parse(svg), parsed.size.width > 0, parsed.size.height > 0 else {
            return nil
        }
        return parsed.rasterize(scale: scale)
    }

    private static func parse(_ svg: String) -> SVG? {
        SVG(xml: CapgoTemplateSvgFontNormalizer.normalize(svg))
    }

    private static func fitted(_ svg: SVG, in size: CGSize) -> SVG {
        guard svg.size.width > 0, svg.size.height > 0 else {
            return svg.sized(size)
        }
        let factor = min(size.width / svg.size.width, size.height / svg.size.height)
        let scaled = svg.scaled(factor)
        let horizontalInset = max(0, (size.width - scaled.size.width) / 2)
        let verticalInset = max(0, (size.height - scaled.size.height) / 2)
        return scaled.expanded(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
}

/// SwiftDraw resolves text fonts by face name only: it ignores `font-weight` and falls back to Times.
/// This rewrites `font-family` where a weight is declared, resolving the family inherited from ancestors,
/// so templates render sans-serif by default and bold weights pick a bold face, matching Android output.
enum CapgoTemplateSvgFontNormalizer {
    static let regularFamily = "Helvetica Neue"

    private static let genericFamilies: Set<String> = ["serif", "sans-serif", "monospace", "cursive", "fantasy"]
    // swiftlint:disable force_try
    // Comments, CDATA, and declarations match the first branch and pass through untouched; attribute
    // values are matched as quoted strings so a literal `>` inside them does not end the tag.
    private static let tagPattern = try! NSRegularExpression(
        pattern: #"<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<[?!][^>]*>|<(/?)([A-Za-z][\w:.-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>"#
    )
    private static let weightPattern = try! NSRegularExpression(pattern: #"\sfont-weight\s*=\s*(?:"([^"]*)"|'([^']*)')"#)
    private static let familyPattern = try! NSRegularExpression(pattern: #"\sfont-family\s*=\s*(?:"([^"]*)"|'([^']*)')"#)
    // swiftlint:enable force_try

    /// Declared (pre-rewrite) font state in effect for an open element, inherited by its descendants.
    private struct FontScope {
        var families: [String]?
        var isBold = false
    }

    static func normalize(_ svg: String) -> String {
        let source = svg as NSString
        var result = ""
        var cursor = 0
        // Weights and families inherit independently, so each element resolves its face against
        // the family and weight in effect from its ancestors.
        var scopes: [FontScope] = []
        for match in tagPattern.matches(in: svg, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            cursor = match.range.location + match.range.length
            guard match.range(at: 2).location != NSNotFound else {
                result += source.substring(with: match.range)
                continue
            }
            let name = source.substring(with: match.range(at: 2))
            if match.range(at: 1).length > 0 {
                _ = scopes.popLast()
                result += source.substring(with: match.range)
                continue
            }

            let attributes = source.substring(with: match.range(at: 3))
            let (rewritten, scope) = rewrite(attributes, inherited: scopes.last ?? FontScope(), isRoot: name == "svg")
            result += "<\(name)\(rewritten)>"
            if !attributes.hasSuffix("/") {
                scopes.append(scope)
            }
        }
        result += source.substring(from: cursor)
        return result
    }

    private static func rewrite(
        _ attributes: String,
        inherited: FontScope,
        isRoot: Bool
    ) -> (attributes: String, scope: FontScope) {
        var body = attributes
        var closing = ""
        if body.hasSuffix("/") {
            body.removeLast()
            closing = "/"
        }

        let declaredFamilies = value(of: familyPattern, in: body).map(parseFamilies)
        let declaredBold = value(of: weightPattern, in: body).map(isBold)
        let scope = FontScope(
            families: declaredFamilies ?? inherited.families,
            isBold: declaredBold ?? inherited.isBold
        )
        let families = scope.families ?? [regularFamily]
        let replacement: [String]?
        if declaredBold != nil || (declaredFamilies != nil && scope.isBold) {
            // Restating the family on regular weights keeps an ancestor's bold face from leaking in.
            replacement = scope.isBold ? families.compactMap(boldFace) + families : families
        } else {
            replacement = isRoot && declaredFamilies == nil ? [regularFamily] : nil
        }

        guard let replacement else {
            return (attributes, scope)
        }
        body = familyPattern.stringByReplacingMatches(
            in: body,
            range: NSRange(location: 0, length: (body as NSString).length),
            withTemplate: ""
        )
        let serialized = unique(replacement)
            .map { genericFamilies.contains($0) ? $0 : "'\($0)'" }
            .joined(separator: ", ")
        return ("\(body) font-family=\"\(serialized)\"\(closing)", scope)
    }

    private static func value(of pattern: NSRegularExpression, in text: String) -> String? {
        let source = text as NSString
        guard let match = pattern.firstMatch(in: text, range: NSRange(location: 0, length: source.length)) else {
            return nil
        }
        for group in 1...2 where match.range(at: group).location != NSNotFound {
            return source.substring(with: match.range(at: group))
        }
        return nil
    }

    private static func parseFamilies(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "'\""))) }
            .filter { !$0.isEmpty }
    }

    private static func isBold(_ weight: String) -> Bool {
        let normalized = weight.trimmingCharacters(in: .whitespaces).lowercased()
        if normalized == "bold" || normalized == "bolder" {
            return true
        }
        return (Int(normalized) ?? 400) >= 600
    }

    private static func boldFace(for family: String) -> String? {
        switch family.lowercased() {
        case "sans-serif", "helvetica neue", "helveticaneue":
            return "HelveticaNeue-Bold"
        case "serif":
            return "TimesNewRomanPS-BoldMT"
        case "monospace":
            return "Menlo-Bold"
        case "cursive", "fantasy":
            return nil
        default:
            return family.replacingOccurrences(of: " ", with: "") + "-Bold"
        }
    }

    private static func unique(_ families: [String]) -> [String] {
        var seen = Set<String>()
        return families.filter { seen.insert($0.lowercased()).inserted }
    }
}

/// SwiftUI view that renders resolved template SVG markup in Home Screen widgets,
/// Live Activities, and in-app previews.
@available(iOS 16.0, *)
public struct CapgoTemplateSvgView<Fallback: View>: View {
    private let svg: String
    private let fallback: () -> Fallback

    @Environment(\.displayScale) private var displayScale

    public init(svg: String, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.svg = svg
        self.fallback = fallback
    }

    public init(layout: CapgoResolvedTemplateLayout, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.init(svg: layout.svg, fallback: fallback)
    }

    public var body: some View {
        GeometryReader { proxy in
            if let image = CapgoTemplateSvgRenderer.render(svg: svg, size: proxy.size, scale: displayScale) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                fallback()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

@available(iOS 16.0, *)
public extension CapgoTemplateSvgView where Fallback == EmptyView {
    init(svg: String) {
        self.init(svg: svg) { EmptyView() }
    }

    init(layout: CapgoResolvedTemplateLayout) {
        self.init(svg: layout.svg) { EmptyView() }
    }
}

// MARK: - Built-in renderer defaults
// The placeholder doubles as the fallback when the SVG markup cannot be rendered.

@available(iOS 16.0, *)
public extension CapgoTemplateSurfaceView where SVGContent == CapgoTemplateSvgView<Placeholder> {
    init(
        layout: CapgoResolvedTemplateLayout?,
        showsHotspots: Bool = true,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            layout: layout,
            showsHotspots: showsHotspots,
            svgContent: { CapgoTemplateSvgView(layout: $0, fallback: placeholder) },
            placeholder: placeholder
        )
    }
}

@available(iOS 16.0, *)
public extension CapgoTemplateWidgetSurface where SVGContent == CapgoTemplateSvgView<Placeholder> {
    init(
        activityId: String,
        surface: CapgoTemplateSurface = .lockScreen,
        bundle: Bundle = .main,
        showsHotspots: Bool = true,
        now: @escaping () -> Date = { Date() },
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            activityId: activityId,
            surface: surface,
            bundle: bundle,
            showsHotspots: showsHotspots,
            now: now,
            svgContent: { CapgoTemplateSvgView(layout: $0, fallback: placeholder) },
            placeholder: placeholder
        )
    }
}

@available(iOS 16.0, *)
public extension CapgoTemplateLatestWidgetSurface where SVGContent == CapgoTemplateSvgView<Placeholder> {
    init(
        surface: CapgoTemplateSurface = .lockScreen,
        status: String? = "active",
        bundle: Bundle = .main,
        showsHotspots: Bool = true,
        now: @escaping () -> Date = { Date() },
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            surface: surface,
            status: status,
            bundle: bundle,
            showsHotspots: showsHotspots,
            now: now,
            svgContent: { CapgoTemplateSvgView(layout: $0, fallback: placeholder) },
            placeholder: placeholder
        )
    }
}

#if canImport(WidgetKit)
@available(iOS 16.0, *)
public extension CapgoTemplateHomeWidgetView where SVGContent == CapgoTemplateSvgView<Placeholder> {
    init(
        entry: CapgoTemplateWidgetEntry,
        showsHotspots: Bool = true,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            entry: entry,
            showsHotspots: showsHotspots,
            svgContent: { CapgoTemplateSvgView(layout: $0, fallback: placeholder) },
            placeholder: placeholder
        )
    }
}
#endif
#endif
