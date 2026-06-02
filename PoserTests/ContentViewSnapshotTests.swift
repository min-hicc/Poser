import XCTest
import SwiftUI
import SnapshotTesting
@testable import Poser

/// Snapshot of the static landing screen. (The analysis screen isn't snapshotted
/// here because it kicks off Vision detection on appear, which is device-only and
/// non-deterministic.)
@MainActor
final class ContentViewSnapshotTests: XCTestCase {

    func testLandingScreen() {
        // iPhone 13 logical size.
        assertSnapshot(of: ContentView(),
                       as: .image(layout: .fixed(width: 390, height: 844)))
    }
}
