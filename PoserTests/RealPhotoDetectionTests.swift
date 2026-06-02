import XCTest
import SwiftUI
import SnapshotTesting
@testable import Poser

/// End-to-end tests against the real photos in `PoserTests/TestImages/`.
/// These run the actual Vision pipeline, so they are **device-only** — body-pose
/// detection isn't available on the Simulator. They `XCTSkip` there so Simulator
/// and CI runs stay green.
@MainActor
final class RealPhotoDetectionTests: XCTestCase {

    // MARK: Helpers

    private func loadImage(_ name: String,
                           file: StaticString = #filePath,
                           line: UInt = #line) throws -> UIImage {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "jpg")
                ?? bundle.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            throw XCTSkip("Missing test image '\(name)'. Add it under PoserTests/TestImages/.")
        }
        return image
    }

    /// Runs detection and waits (up to a timeout) for it to finish.
    private func detectPose(in image: UIImage) async -> DetectedPose? {
        let detector = PoseDetector()
        detector.detect(in: image)
        let deadline = Date().addingTimeInterval(20)
        while detector.isProcessing && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)   // 50 ms
        }
        return detector.pose
    }

    private func skipOnSimulator() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Vision body-pose detection isn't supported on the Simulator; run on a device.")
        #endif
    }

    // MARK: Detection assertions

    private func assertDetects(_ name: String,
                               file: StaticString = #filePath,
                               line: UInt = #line) async throws {
        try skipOnSimulator()
        let image = try loadImage(name, file: file, line: line)
        let pose = await detectPose(in: image)
        XCTAssertNotNil(pose, "No pose detected in \(name).", file: file, line: line)
        if let pose {
            XCTAssertTrue(pose.isValid,
                          "Pose in \(name) has too few confident joints.",
                          file: file, line: line)
        }
    }

    func testDetectsPose1() async throws { try await assertDetects("pose1") }
    func testDetectsPose2() async throws { try await assertDetects("pose2") }
    func testDetectsPose3() async throws { try await assertDetects("pose3") }

    // MARK: Overlay snapshots (device-only; baselines are device-specific)

    private func assertOverlaySnapshot(_ name: String,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) async throws {
        try skipOnSimulator()
        let image = try loadImage(name, file: file, line: line)
        guard let pose = await detectPose(in: image) else {
            XCTFail("No pose detected in \(name); cannot snapshot.", file: file, line: line)
            return
        }
        let view = ZStack {
            Image(uiImage: image).resizable().scaledToFit()
            PoseOverlayView(pose: pose, modes: [.lines, .shapes, .outline])
        }
        .frame(width: 320, height: 480)
        .background(Color(white: 0.85))

        assertSnapshot(of: view,
                       as: .tolerant(width: 320, height: 480),
                       named: name,
                       file: file, line: line)
    }

    func testSnapshotPose1() async throws { try await assertOverlaySnapshot("pose1") }
    func testSnapshotPose2() async throws { try await assertOverlaySnapshot("pose2") }
    func testSnapshotPose3() async throws { try await assertOverlaySnapshot("pose3") }
}
