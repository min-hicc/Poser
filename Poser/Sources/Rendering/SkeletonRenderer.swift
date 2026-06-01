import SwiftUI

/// Draws a classic stick-figure skeleton over the detected keypoints.
struct SkeletonRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    // Bone connections as (KeyPath, KeyPath) pairs
    private typealias KP = KeyPath<DetectedPose, Keypoint?>

    private let bones: [(KP, KP)] = [
        // Spine
        (\.nose, \.neck),
        (\.neck, \.leftShoulder),
        (\.neck, \.rightShoulder),
        // Left arm
        (\.leftShoulder, \.leftElbow),
        (\.leftElbow, \.leftWrist),
        // Right arm
        (\.rightShoulder, \.rightElbow),
        (\.rightElbow, \.rightWrist),
        // Torso to hips
        (\.leftShoulder, \.leftHip),
        (\.rightShoulder, \.rightHip),
        (\.leftHip, \.rightHip),
        // Left leg
        (\.leftHip, \.leftKnee),
        (\.leftKnee, \.leftAnkle),
        // Right leg
        (\.rightHip, \.rightKnee),
        (\.rightKnee, \.rightAnkle),
    ]

    func draw(in context: GraphicsContext) {
        // Draw bones
        for (aPath, bPath) in bones {
            guard let a = pose[keyPath: aPath], a.isValid,
                  let b = pose[keyPath: bPath], b.isValid else { continue }

            var path = Path()
            path.move(to: transform.point(a.point))
            path.addLine(to: transform.point(b.point))

            context.stroke(path,
                           with: .color(.white.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Draw joint dots
        let keypaths: [KP] = [\.nose, \.neck, \.leftShoulder, \.rightShoulder,
                               \.leftElbow, \.rightElbow, \.leftWrist, \.rightWrist,
                               \.leftHip, \.rightHip, \.leftKnee, \.rightKnee,
                               \.leftAnkle, \.rightAnkle]

        for kp in keypaths {
            guard let joint = pose[keyPath: kp], joint.isValid else { continue }
            let pt = transform.point(joint.point)
            let r: CGFloat = 5
            context.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                width: r * 2, height: r * 2)),
                         with: .color(.cyan))
        }
    }
}
