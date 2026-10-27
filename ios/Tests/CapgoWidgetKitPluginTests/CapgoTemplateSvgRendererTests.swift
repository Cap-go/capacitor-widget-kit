#if canImport(UIKit)
import UIKit
import XCTest
@testable import CapgoWidgetKitShared

final class CapgoTemplateSvgRendererTests: XCTestCase {
    private let redBar = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 40">\
    <rect x="0" y="0" width="100" height="40" fill="#ff0000"/>\
    </svg>
    """

    func testRendersSvgMarkupAtRequestedSize() throws {
        let image = try XCTUnwrap(
            CapgoTemplateSvgRenderer.render(svg: redBar, size: CGSize(width: 200, height: 80), scale: 1)
        )

        XCTAssertEqual(image.size, CGSize(width: 200, height: 80))
        let center = try XCTUnwrap(pixel(in: image, column: 100, row: 40))
        XCTAssertEqual(center.red, 255)
        XCTAssertEqual(center.alpha, 255)
    }

    func testAspectFitsAndCentersInsideTargetSize() throws {
        let image = try XCTUnwrap(
            CapgoTemplateSvgRenderer.render(svg: redBar, size: CGSize(width: 200, height: 200), scale: 1)
        )

        XCTAssertEqual(image.size, CGSize(width: 200, height: 200))
        let letterbox = try XCTUnwrap(pixel(in: image, column: 100, row: 10))
        XCTAssertEqual(letterbox.alpha, 0)
        let content = try XCTUnwrap(pixel(in: image, column: 100, row: 100))
        XCTAssertEqual(content.red, 255)
        XCTAssertEqual(content.alpha, 255)
    }

    func testRendersResolvedTemplateWithText() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 40">\
        <rect width="100" height="40" fill="#000000"/>\
        <text x="6" y="26" font-size="20" fill="#ffffff">1:30</text>\
        </svg>
        """
        let image = try XCTUnwrap(
            CapgoTemplateSvgRenderer.render(svg: svg, size: CGSize(width: 100, height: 40), scale: 2)
        )

        XCTAssertEqual(image.size, CGSize(width: 100, height: 40))
        var hasLightPixel = false
        for column in 6..<60 {
            for row in 10..<30 where (pixel(in: image, column: column, row: row)?.red ?? 0) > 128 {
                hasLightPixel = true
            }
        }
        XCTAssertTrue(hasLightPixel, "Expected the <text> element to be drawn")
    }

    func testReturnsNilForInvalidMarkupOrEmptySize() {
        XCTAssertNil(CapgoTemplateSvgRenderer.render(svg: "not an svg", size: CGSize(width: 10, height: 10)))
        XCTAssertNil(CapgoTemplateSvgRenderer.render(svg: "", size: CGSize(width: 10, height: 10)))
        XCTAssertNil(CapgoTemplateSvgRenderer.render(svg: redBar, size: .zero))
    }

    func testRendersAtIntrinsicSize() throws {
        let image = try XCTUnwrap(CapgoTemplateSvgRenderer.render(svg: redBar, scale: 1))
        XCTAssertEqual(image.size, CGSize(width: 100, height: 40))
    }

    func testFontNormalizerDefaultsRootToSansSerif() {
        let normalized = CapgoTemplateSvgFontNormalizer.normalize(#"<svg viewBox="0 0 10 10"><text>A</text></svg>"#)
        XCTAssertEqual(normalized, #"<svg viewBox="0 0 10 10" font-family="'Helvetica Neue'"><text>A</text></svg>"#)
    }

    func testFontNormalizerMapsBoldWeightsToBoldFaces() {
        let normalized = CapgoTemplateSvgFontNormalizer.normalize(
            #"<svg><text font-weight="700">A</text>"#
                + #"<text font-family="serif" font-weight='bold'>B</text><textPath font-weight="400"/></svg>"#
        )

        XCTAssertTrue(normalized.contains(#"<text font-weight="700" font-family="'HelveticaNeue-Bold', 'Helvetica Neue'">"#))
        XCTAssertTrue(normalized.contains(#"<text font-weight='bold' font-family="'TimesNewRomanPS-BoldMT', serif">"#))
        XCTAssertTrue(normalized.contains(#"<textPath font-weight="400" font-family="'Helvetica Neue'"/>"#))
    }

    func testFontNormalizerKeepsGenericFallbacksFromInheritedFamilies() {
        let normalized = CapgoTemplateSvgFontNormalizer.normalize(
            #"<svg font-family="Avenir Next, sans-serif"><text font-weight="700">A</text><textPath font-weight="400"/></svg>"#
        )

        XCTAssertTrue(normalized.contains(#"<svg font-family="Avenir Next, sans-serif">"#))
        XCTAssertTrue(normalized.contains(
            #"<text font-weight="700" font-family="'AvenirNext-Bold', 'HelveticaNeue-Bold', 'Avenir Next', sans-serif">"#
        ))
        XCTAssertTrue(normalized.contains(#"<textPath font-weight="400" font-family="'Avenir Next', sans-serif"/>"#))
    }

    func testFontNormalizerKeepsExplicitFamiliesWithoutWeights() {
        let markup = #"<svg font-family="Menlo"><rect width="1"/><text font-family="Georgia">A</text></svg>"#
        XCTAssertEqual(CapgoTemplateSvgFontNormalizer.normalize(markup), markup)
    }

    func testFontNormalizerResolvesWeightsAgainstInheritedFamilies() {
        let normalized = CapgoTemplateSvgFontNormalizer.normalize(
            #"<svg font-family="Menlo"><g><text font-weight="700">A</text></g>"#
                + #"<g font-family="Georgia" font-weight="bold"><text font-weight="400">B</text></g>"#
                + #"<text font-weight="normal">C</text></svg>"#
        )

        XCTAssertTrue(normalized.contains(#"<text font-weight="700" font-family="'Menlo-Bold', 'Menlo'">A"#))
        XCTAssertTrue(normalized.contains(#"<g font-weight="bold" font-family="'Georgia-Bold', 'Georgia'">"#))
        XCTAssertTrue(normalized.contains(#"<text font-weight="400" font-family="'Georgia'">B"#))
        XCTAssertTrue(normalized.contains(#"</g><text font-weight="normal" font-family="'Menlo'">C"#))
    }

    func testBoldTextRendersHeavierThanRegularText() throws {
        func inkCoverage(weight: String) throws -> Int {
            let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 40">\
            <text x="4" y="30" font-size="28" font-weight="\(weight)" fill="#000000">Hello</text>\
            </svg>
            """
            let image = try XCTUnwrap(
                CapgoTemplateSvgRenderer.render(svg: svg, size: CGSize(width: 100, height: 40), scale: 1)
            )
            var covered = 0
            for column in 0..<100 {
                for row in 0..<40 where (pixel(in: image, column: column, row: row)?.alpha ?? 0) > 128 {
                    covered += 1
                }
            }
            return covered
        }

        XCTAssertGreaterThan(try inkCoverage(weight: "700"), try inkCoverage(weight: "400"))
    }

    private struct Pixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// Samples one pixel in point coordinates.
    private func pixel(in image: UIImage, column: Int, row: Int) -> Pixel? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        let pixelX = Int(CGFloat(column) * image.scale)
        let pixelY = Int(CGFloat(row) * image.scale)
        var data = [UInt8](repeating: 0, count: 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.translateBy(x: CGFloat(-pixelX), y: CGFloat(pixelY - cgImage.height + 1))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return true
        }
        guard drawn else {
            return nil
        }
        return Pixel(red: data[0], green: data[1], blue: data[2], alpha: data[3])
    }
}
#endif
