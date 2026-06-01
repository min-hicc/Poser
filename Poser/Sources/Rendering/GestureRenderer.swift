import SwiftUI

/// Draws a single flowing line of action through the body's major axis.
struct GestureRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    func draw(in context: GraphicsContext) {
        // Collect spine points top → bottom: head → neck → midShoulder → midHip → weight ankle
        var spinePoints: [CGPoint] = []

        if let nose = pose.nose, nose.isValid {
            spinePoints.append(transform.point(nose.point))
        }
        if let neck = pose.neck, neck.isValid {
            spinePoints.append(transform.point(neck.point))
        }
        if let ms = pose.midShoulder {
            spinePoints.append(transform.point(ms))
        }
        if let mh = pose.midHip {
            spinePoints.append(transform.point(mh))
        }

        // Weight-bearing ankle anchors the line
        let ankle: Keypoint? = pose.weightBearingLeg == .left ? pose.leftAnkle : pose.rightAnkle
        if let a = ankle, a.isValid {
            spinePoints.append(transform.point(a.point))
        }

        guard spinePoints.count >= 2 else { return }

        // Smooth catmull-rom curve through spine points
        var path = Path()
        path.move(to: spinePoints[0])

        if spinePoints.count == 2 {
            path.addLine(to: spinePoints[1])
        } else {
            for i in 1 ..< spinePoints.count {
                let prev = spinePoints[i - 1]
                let curr = spinePoints[i]
                let ctrl1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.35,
                                    y: prev.y + (curr.y - prev.y) * 0.35)
                let ctrl2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.65,
                                    y: prev.y + (curr.y - prev.y) * 0.65)
                path.addCurve(to: curr, control1: ctrl1, control2: ctrl2)
            }
        }

        context.stroke(path,
                       with: .color(.orange),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        // Small dot at top and bottom
        for pt in [spinePoints.first, spinePoints.last].compactMap({ $0 }) {
            let r: CGFloat = 6
            context.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                width: r * 2, height: r * 2)),
                         with: .color(.orange))
        }
    }
}
