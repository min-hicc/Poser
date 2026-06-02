import XCTest
import CoreGraphics
@testable import Poser

final class DetectedPoseTests: XCTestCase {

    private func kp(_ x: CGFloat, _ y: CGFloat, _ c: Float = 1) -> Keypoint {
        Keypoint(point: CGPoint(x: x, y: y), confidence: c)
    }

    func testMidShoulderIsAverage() {
        let pose = DetectedPose(leftShoulder: kp(0.4, 0.8),
                                rightShoulder: kp(0.6, 0.8))
        XCTAssertEqual(pose.midShoulder?.x ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(pose.midShoulder?.y ?? -1, 0.8, accuracy: 0.0001)
    }

    func testMidShoulderNilWhenLowConfidence() {
        let pose = DetectedPose(leftShoulder: kp(0.4, 0.8, 0.1),   // below 0.3 threshold
                                rightShoulder: kp(0.6, 0.8))
        XCTAssertNil(pose.midShoulder)
    }

    func testMidHipIsAverage() {
        let pose = DetectedPose(leftHip: kp(0.45, 0.5), rightHip: kp(0.55, 0.5))
        XCTAssertEqual(pose.midHip?.x ?? -1, 0.5, accuracy: 0.0001)
    }

    func testWeightBearingLegPicksAnkleNearestHipCenter() {
        // Left ankle is directly under hip center, right ankle is far out.
        let pose = DetectedPose(leftHip: kp(0.5, 0.5), rightHip: kp(0.5, 0.5),
                                leftAnkle: kp(0.50, 0.1), rightAnkle: kp(0.80, 0.1))
        XCTAssertEqual(pose.weightBearingLeg, .left)
    }

    func testIsValidRequiresAtLeastFourConfidentJoints() {
        let weak = DetectedPose(nose: kp(0.5, 0.9), neck: kp(0.5, 0.85))
        XCTAssertFalse(weak.isValid)

        let strong = DetectedPose(nose: kp(0.5, 0.9),
                                  neck: kp(0.5, 0.85),
                                  leftShoulder: kp(0.4, 0.83),
                                  rightShoulder: kp(0.6, 0.83))
        XCTAssertTrue(strong.isValid)
    }
}
