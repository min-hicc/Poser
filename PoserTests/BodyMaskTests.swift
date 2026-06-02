import XCTest
import CoreGraphics
@testable import Poser

final class BodyMaskTests: XCTestCase {

    /// A mask where only the TOP half of the image is "body".
    private func topHalfMask(size: Int = 100) -> BodyMask {
        var data = [UInt8](repeating: 0, count: size * size)
        for row in 0 ..< size / 2 {          // rows 0..<50 = top of image
            for col in 0 ..< size {
                data[row * size + col] = 255
            }
        }
        return BodyMask(width: size, height: size, data: data)
    }

    /// An hourglass: wide near the top/bottom, narrow in the middle.
    private func hourglassMask(size: Int = 100) -> BodyMask {
        var data = [UInt8](repeating: 0, count: size * size)
        for row in 0 ..< size {
            let yNorm = 1.0 - Double(row) / Double(size)      // bottom-left y
            let half = 0.08 + abs(yNorm - 0.5) * 0.4          // narrowest at y = 0.5
            let lo = Int((0.5 - half) * Double(size))
            let hi = Int((0.5 + half) * Double(size))
            for col in max(0, lo) ..< min(size, hi) {
                data[row * size + col] = 255
            }
        }
        return BodyMask(width: size, height: size, data: data)
    }

    func testIsBodyFlipsYCorrectly() {
        let mask = topHalfMask()
        // Vision y is bottom-left: y≈0.9 is near the top of the image (body),
        // y≈0.1 is near the bottom (background).
        XCTAssertTrue(mask.isBody(normalized: CGPoint(x: 0.5, y: 0.9)))
        XCTAssertFalse(mask.isBody(normalized: CGPoint(x: 0.5, y: 0.1)))
    }

    func testIsBodyOutOfBoundsIsFalse() {
        let mask = topHalfMask()
        XCTAssertFalse(mask.isBody(normalized: CGPoint(x: -0.1, y: 0.9)))
        XCTAssertFalse(mask.isBody(normalized: CGPoint(x: 1.5, y: 0.9)))
    }

    func testSpanFindsLeftAndRightEdges() {
        let mask = hourglassMask()
        // Scan horizontally (perpendicular to a vertical axis) across the waist.
        let span = mask.span(atNormalized: CGPoint(x: 0.5, y: 0.5),
                             axis: CGVector(dx: 0, dy: -1))
        XCTAssertNotNil(span)
        // At y=0.5 the half-width is ~0.08, so edges ~0.42 and ~0.58.
        XCTAssertEqual(span!.left.x,  0.42, accuracy: 0.03)
        XCTAssertEqual(span!.right.x, 0.58, accuracy: 0.03)
    }

    func testSpanNilWhenCenterOffBody() {
        let mask = hourglassMask()
        // Far left of the hourglass at mid-height is background.
        let span = mask.span(atNormalized: CGPoint(x: 0.05, y: 0.5),
                             axis: CGVector(dx: 0, dy: -1))
        XCTAssertNil(span)
    }

    func testTorsoSpansWaistIsNarrowest() {
        let mask = hourglassMask()
        let result = mask.torsoSpans(shoulderCenter: CGPoint(x: 0.5, y: 0.8),
                                     hipCenter: CGPoint(x: 0.5, y: 0.2))
        XCTAssertNotNil(result)
        let (chest, waist, hip) = result!
        XCTAssertLessThan(waist.widthPx, chest.widthPx)
        XCTAssertLessThan(waist.widthPx, hip.widthPx)
        // Waist should sit roughly in the vertical middle of the torso.
        XCTAssertEqual(waist.center.y, 0.5, accuracy: 0.12)
    }

    func testPixelBufferInitFailsGracefullyIsNotTestedHere() {
        // BodyMask(pixelBuffer:) needs a real CVPixelBuffer; covered by integration,
        // not unit tests. This placeholder documents the boundary.
        XCTAssertTrue(true)
    }
}
