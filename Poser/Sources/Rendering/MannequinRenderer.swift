import SwiftUI

/// Draws 3D-ish capsule/box forms over each limb segment.
struct MannequinRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    // Thickness of each segment relative to canvas min dimension
    private let limbThickness: CGFloat = 0.04
    private let torsoThickness: CGFloat = 0.08

    func draw(in context: GraphicsContext) {
        let t = transform.length(limbThickness)
        let tt = transform.length(torsoThickness)

        drawHead(in: context)
        drawTorso(in: context, thickness: tt)
        drawPelvis(in: context, thickness: tt)

        // Arms
        drawSegment(from: pose.leftShoulder, to: pose.leftElbow,   thickness: t, color: .teal,   in: context)
        drawSegment(from: pose.leftElbow,    to: pose.leftWrist,   thickness: t * 0.85, color: .teal, in: context)
        drawSegment(from: pose.rightShoulder, to: pose.rightElbow, thickness: t, color: .mint,   in: context)
        drawSegment(from: pose.rightElbow,   to: pose.rightWrist,  thickness: t * 0.85, color: .mint, in: context)

        // Legs
        drawSegment(from: pose.leftHip,  to: pose.leftKnee,   thickness: t * 1.1, color: .indigo, in: context)
        drawSegment(from: pose.leftKnee, to: pose.leftAnkle,  thickness: t * 0.9, color: .indigo, in: context)
        drawSegment(from: pose.rightHip, to: pose.rightKnee,  thickness: t * 1.1, color: .purple, in: context)
        drawSegment(from: pose.rightKnee, to: pose.rightAnkle, thickness: t * 0.9, color: .purple, in: context)
    }

    private func drawSegment(from aKP: Keypoint?, to bKP: Keypoint?,
                              thickness: CGFloat, color: Color,
                              in context: GraphicsContext) {
        guard let a = aKP, a.isValid, let b = bKP, b.isValid else { return }
        let pt1 = transform.point(a.point)
        let pt2 = transform.point(b.point)
        drawCapsule(from: pt1, to: pt2, radius: thickness / 2, color: color, in: context)
    }

    private func drawCapsule(from p1: CGPoint, to p2: CGPoint,
                              radius: CGFloat, color: Color,
                              in context: GraphicsContext) {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let angle = atan2(dy, dx)

        var path = Path()
        // Build a rounded-rect that represents the capsule
        let rect = CGRect(x: -length / 2, y: -radius,
                          width: length, height: radius * 2)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))

        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)

        context.drawLayer { ctx in
            ctx.translateBy(x: mid.x, y: mid.y)
            ctx.rotate(by: .radians(angle))
            ctx.fill(path, with: .color(color.opacity(0.75)))
            ctx.stroke(path,
                       with: .color(color),
                       style: StrokeStyle(lineWidth: 1.5))
        }
    }

    private func drawHead(in context: GraphicsContext) {
        guard let nose = pose.nose, nose.isValid,
              let neck = pose.neck, neck.isValid else { return }

        let nosePt = transform.point(nose.point)
        let neckPt = transform.point(neck.point)
        let neckToNose = sqrt(pow(nosePt.x - neckPt.x, 2) + pow(nosePt.y - neckPt.y, 2))
        let headRadius = max(neckToNose * 0.6, transform.length(0.04))

        // Head center is slightly above nose
        let headCenter = CGPoint(x: nosePt.x,
                                 y: nosePt.y - headRadius * 0.3)

        let rect = CGRect(x: headCenter.x - headRadius,
                          y: headCenter.y - headRadius,
                          width: headRadius * 2,
                          height: headRadius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.yellow.opacity(0.7)))
        context.stroke(Path(ellipseIn: rect),
                       with: .color(.yellow),
                       style: StrokeStyle(lineWidth: 2))
    }

    private func drawTorso(in context: GraphicsContext, thickness: CGFloat) {
        guard let ls = pose.leftShoulder, ls.isValid,
              let rs = pose.rightShoulder, rs.isValid,
              let lh = pose.leftHip, lh.isValid,
              let rh = pose.rightHip, rh.isValid else { return }

        let tl = transform.point(ls.point)
        let tr = transform.point(rs.point)
        let bl = transform.point(lh.point)
        let br = transform.point(rh.point)

        var path = Path()
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath()

        context.fill(path, with: .color(.orange.opacity(0.5)))
        context.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 2))
    }

    private func drawPelvis(in context: GraphicsContext, thickness: CGFloat) {
        guard let lh = pose.leftHip, lh.isValid,
              let rh = pose.rightHip, rh.isValid else { return }

        let l = transform.point(lh.point)
        let r = transform.point(rh.point)
        let w = abs(r.x - l.x)
        let h = w * 0.5
        let midX = (l.x + r.x) / 2
        let midY = (l.y + r.y) / 2

        let rect = CGRect(x: midX - w / 2, y: midY - h / 4, width: w, height: h)
        context.fill(Path(roundedRect: rect, cornerRadius: 4),
                     with: .color(.orange.opacity(0.4)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 4),
                       with: .color(.orange),
                       style: StrokeStyle(lineWidth: 2))
    }
}
