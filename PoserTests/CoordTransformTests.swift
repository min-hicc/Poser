import XCTest
import CoreGraphics
@testable import Poser

final class CoordTransformTests: XCTestCase {

    func testPointFlipsYAndScales() {
        let t = CoordTransform(canvasSize: CGSize(width: 100, height: 200))

        // Vision origin (bottom-left) → canvas origin (top-left)
        XCTAssertEqual(t.point(CGPoint(x: 0, y: 0)), CGPoint(x: 0, y: 200))
        XCTAssertEqual(t.point(CGPoint(x: 1, y: 1)), CGPoint(x: 100, y: 0))
        XCTAssertEqual(t.point(CGPoint(x: 0.5, y: 0.5)), CGPoint(x: 50, y: 100))
    }

    func testLengthUsesSmallerDimension() {
        let t = CoordTransform(canvasSize: CGSize(width: 100, height: 200))
        XCTAssertEqual(t.length(0.1), 10, accuracy: 0.0001)   // 0.1 * min(100,200)
    }

    func testNormalizedIsInverseOfPoint() {
        let t = CoordTransform(canvasSize: CGSize(width: 320, height: 480))
        let original = CGPoint(x: 0.37, y: 0.82)
        let roundTripped = t.normalized(fromCanvas: t.point(original))
        XCTAssertEqual(roundTripped.x, original.x, accuracy: 0.0001)
        XCTAssertEqual(roundTripped.y, original.y, accuracy: 0.0001)
    }

    func testNormalizedHandlesZeroSizeSafely() {
        let t = CoordTransform(canvasSize: .zero)
        XCTAssertEqual(t.normalized(fromCanvas: CGPoint(x: 10, y: 10)), .zero)
    }
}
