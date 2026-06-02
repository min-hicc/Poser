import CoreGraphics
@testable import Poser

/// Deterministic, hand-built pose data so snapshot tests don't depend on Vision
/// or any real photo. Coordinates are normalized (Vision, bottom-left origin).
enum Fixtures {

    static func keypoint(_ x: CGFloat, _ y: CGFloat) -> Keypoint {
        Keypoint(point: CGPoint(x: x, y: y), confidence: 1)
    }

    /// A simple front-facing standing figure.
    static var standingPose: DetectedPose {
        DetectedPose(
            nose:          keypoint(0.50, 0.93),
            neck:          keypoint(0.50, 0.86),
            leftShoulder:  keypoint(0.40, 0.84),
            rightShoulder: keypoint(0.60, 0.84),
            leftElbow:     keypoint(0.35, 0.72),
            rightElbow:    keypoint(0.65, 0.72),
            leftWrist:     keypoint(0.33, 0.61),
            rightWrist:    keypoint(0.67, 0.61),
            leftHip:       keypoint(0.45, 0.55),
            rightHip:      keypoint(0.55, 0.55),
            leftKnee:      keypoint(0.44, 0.34),
            rightKnee:     keypoint(0.56, 0.34),
            leftAnkle:     keypoint(0.44, 0.12),
            rightAnkle:    keypoint(0.56, 0.12),
            headBox:       CGRect(x: 0.44, y: 0.85, width: 0.12, height: 0.14),
            bodyMask:      standingMask(),
            bodyContours:  [standingContour],
            face:          FaceFeatures(leftEye:   CGPoint(x: 0.47, y: 0.92),
                                        rightEye:  CGPoint(x: 0.53, y: 0.92),
                                        medianTop: CGPoint(x: 0.50, y: 0.97),
                                        medianBottom: CGPoint(x: 0.50, y: 0.87))
        )
    }

    /// Silhouette mask matching the standing figure (200×200, row 0 == top).
    static func standingMask(size: Int = 200) -> BodyMask {
        var data = [UInt8](repeating: 0, count: size * size)

        func fill(x0: Double, x1: Double, y0: Double, y1: Double) {
            let rLo = Int((1 - y1) * Double(size))   // y is bottom-left; flip to rows
            let rHi = Int((1 - y0) * Double(size))
            let cLo = Int(x0 * Double(size))
            let cHi = Int(x1 * Double(size))
            for row in max(0, rLo) ..< min(size, rHi) {
                for col in max(0, cLo) ..< min(size, cHi) {
                    data[row * size + col] = 255
                }
            }
        }

        fill(x0: 0.44, x1: 0.56, y0: 0.85, y1: 0.99)   // head
        fill(x0: 0.47, x1: 0.53, y0: 0.83, y1: 0.86)   // neck
        fill(x0: 0.38, x1: 0.62, y0: 0.78, y1: 0.85)   // shoulders / chest
        fill(x0: 0.42, x1: 0.58, y0: 0.66, y1: 0.78)   // waist (narrower)
        fill(x0: 0.40, x1: 0.60, y0: 0.54, y1: 0.66)   // hips
        fill(x0: 0.30, x1: 0.40, y0: 0.60, y1: 0.84)   // left arm
        fill(x0: 0.60, x1: 0.70, y0: 0.60, y1: 0.84)   // right arm
        fill(x0: 0.40, x1: 0.49, y0: 0.10, y1: 0.55)   // left leg
        fill(x0: 0.51, x1: 0.60, y0: 0.10, y1: 0.55)   // right leg

        return BodyMask(width: size, height: size, data: data)
    }

    /// Coarse outline polygon for the same figure (normalized, bottom-left).
    static let standingContour: [CGPoint] = [
        CGPoint(x: 0.44, y: 0.99), CGPoint(x: 0.56, y: 0.99),
        CGPoint(x: 0.56, y: 0.86), CGPoint(x: 0.62, y: 0.84),
        CGPoint(x: 0.70, y: 0.82), CGPoint(x: 0.70, y: 0.60),
        CGPoint(x: 0.60, y: 0.60), CGPoint(x: 0.60, y: 0.10),
        CGPoint(x: 0.51, y: 0.10), CGPoint(x: 0.51, y: 0.50),
        CGPoint(x: 0.49, y: 0.50), CGPoint(x: 0.49, y: 0.10),
        CGPoint(x: 0.40, y: 0.10), CGPoint(x: 0.40, y: 0.60),
        CGPoint(x: 0.30, y: 0.60), CGPoint(x: 0.30, y: 0.82),
        CGPoint(x: 0.38, y: 0.84), CGPoint(x: 0.44, y: 0.86),
    ]
}
