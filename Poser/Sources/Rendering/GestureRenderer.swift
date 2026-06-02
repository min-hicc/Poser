import SwiftUI

/// Draws a stick figure: lines connecting joints with a filled ball at each joint.
struct GestureRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    // Each tuple is a pair of keypoints to draw a bone line between
    private typealias KP = KeyPath<DetectedPose, Keypoint?>

    private let bones: [(KP, KP)] = [
        // Head to torso
        (\.nose, \.neck),
        (\.neck, \.leftShoulder),
        (\.neck, \.rightShoulder),
        // Left arm
        (\.leftShoulder, \.leftElbow),
        (\.leftElbow, \.leftWrist),
        // Right arm
        (\.rightShoulder, \.rightElbow),
        (\.rightElbow, \.rightWrist),
        // Torso
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

    private let allJoints: [KP] = [
        \.nose, \.neck,
        \.leftShoulder, \.rightShoulder,
        \.leftElbow,    \.rightElbow,
        \.leftWrist,    \.rightWrist,
        \.leftHip,      \.rightHip,
        \.leftKnee,     \.rightKnee,
        \.leftAnkle,    \.rightAnkle,
    ]

    func draw(in context: GraphicsContext) {
        // 1. Draw lines first so balls render on top
        for (aPath, bPath) in bones {
            guard let a = pose[keyPath: aPath], a.isValid,
                  let b = pose[keyPath: bPath], b.isValid else { continue }

            var path = Path()
            path.move(to: transform.point(a.point))
            path.addLine(to: transform.point(b.point))

            context.stroke(path,
                           with: .color(.white),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // 2. Draw a filled ball at every valid joint
        for kp in allJoints {
            guard let joint = pose[keyPath: kp], joint.isValid else { continue }
            let pt = transform.point(joint.point)
            let r: CGFloat = 2

            // White fill with an orange outline
            context.fill(
                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                with: .color(.white)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                with: .color(.orange),
                style: StrokeStyle(lineWidth: 2)
            )
        }
    }
}
