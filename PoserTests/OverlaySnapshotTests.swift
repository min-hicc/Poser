import XCTest
import SwiftUI
import SnapshotTesting
@testable import Poser

/// Snapshot tests for the overlay renderers, driven by a deterministic synthetic
/// pose (no Vision, no photo) so they run anywhere and stay reproducible.
///
/// First run: with no committed reference images, each `assertSnapshot` records a
/// baseline into `PoserTests/__Snapshots__/` and reports a failure. Commit those
/// PNGs, then subsequent runs compare against them.
@MainActor
final class OverlaySnapshotTests: XCTestCase {

    private let canvas = CGSize(width: 320, height: 480)

    private func overlay(_ modes: Set<DrawingMode>) -> some View {
        PoseOverlayView(pose: Fixtures.standingPose, modes: modes)
            .frame(width: canvas.width, height: canvas.height)
            .background(Color(white: 0.85))
    }

    func testLinesOverlay() {
        assertSnapshot(of: overlay([.lines]),
                       as: .tolerant(width: canvas.width, height: canvas.height))
    }

    func testShapesOverlay() {
        assertSnapshot(of: overlay([.shapes]),
                       as: .tolerant(width: canvas.width, height: canvas.height))
    }

    func testOutlineOverlay() {
        assertSnapshot(of: overlay([.outline]),
                       as: .tolerant(width: canvas.width, height: canvas.height))
    }

    func testAllModesStacked() {
        assertSnapshot(of: overlay([.lines, .shapes, .outline]),
                       as: .tolerant(width: canvas.width, height: canvas.height))
    }

    func testNoModesIsEmptyOverlay() {
        assertSnapshot(of: overlay([]),
                       as: .tolerant(width: canvas.width, height: canvas.height))
    }
}
