import XCTest
@testable import Poser

final class DrawingModeTests: XCTestCase {

    func testHasThreeModes() {
        XCTAssertEqual(DrawingMode.allCases.count, 3)
        XCTAssertEqual(Set(DrawingMode.allCases), [.lines, .shapes, .outline])
    }

    func testEveryModeHasIconAndDescription() {
        for mode in DrawingMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) missing icon")
            XCTAssertFalse(mode.description.isEmpty, "\(mode) missing description")
            XCTAssertFalse(mode.rawValue.isEmpty, "\(mode) missing rawValue")
        }
    }

    func testIdentifiableIDMatchesRawValue() {
        XCTAssertEqual(DrawingMode.lines.id, DrawingMode.lines.rawValue)
    }
}
