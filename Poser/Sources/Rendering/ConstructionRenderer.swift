import SwiftUI

/// Loomis-style construction shapes: rib cage ellipse, pelvis block, head sphere, limb cylinders.
struct ConstructionRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    func draw(in context: GraphicsContext) {
        drawRibCage(in: context)
        drawPelvisBlock(in: context)
        drawHead(in: context)
        drawLimbCylinders(in: context)
        drawCenterLine(in: context)
    }

    // MARK: - Rib Cage Ellipse

    private func drawRibCage(in context: GraphicsContext) {
        guard let ls = pose.leftShoulder, ls.isValid,
              let rs = pose.rightShoulder, rs.isValid,
              let lh = pose.leftHip, lh.isValid,
              let rh = pose.rightHip, rh.isValid else { return }

        let shoulderL = transform.point(ls.point)
        let shoulderR = transform.point(rs.point)
        let hipL = transform.point(lh.point)
        let hipR = transform.point(rh.point)

        let shoulderMid = CGPoint(x: (shoulderL.x + shoulderR.x) / 2,
                                  y: (shoulderL.y + shoulderR.y) / 2)
        let hipMid = CGPoint(x: (hipL.x + hipR.x) / 2,
                             y: (hipL.y + hipR.y) / 2)

        // Rib cage occupies upper 60% of torso height
        let torsoHeight = hypot(shoulderMid.x - hipMid.x, shoulderMid.y - hipMid.y)
        let cageHeight = torsoHeight * 0.60
        let cageWidth  = hypot(shoulderL.x - shoulderR.x, shoulderL.y - shoulderR.y) * 0.9

        let cageCenterX = shoulderMid.x + (hipMid.x - shoulderMid.x) * 0.25
        let cageCenterY = shoulderMid.y + (hipMid.y - shoulderMid.y) * 0.25

        let angle = atan2(hipMid.y - shoulderMid.y, hipMid.x - shoulderMid.x) - .pi / 2

        let rect = CGRect(x: cageCenterX - cageWidth / 2,
                          y: cageCenterY - cageHeight / 2,
                          width: cageWidth, height: cageHeight)

        context.drawLayer { ctx in
            ctx.translateBy(x: cageCenterX, y: cageCenterY)
            ctx.rotate(by: .radians(angle))
            ctx.translateBy(x: -cageCenterX, y: -cageCenterY)
            ctx.stroke(Path(ellipseIn: rect),
                       with: .color(.green),
                       style: StrokeStyle(lineWidth: 2.5, dash: [6, 3]))
        }
    }

    // MARK: - Pelvis Block

    private func drawPelvisBlock(in context: GraphicsContext) {
        guard let lh = pose.leftHip, lh.isValid,
              let rh = pose.rightHip, rh.isValid else { return }

        let l = transform.point(lh.point)
        let r = transform.point(rh.point)
        let w = hypot(r.x - l.x, r.y - l.y) * 1.1
        let h = w * 0.55
        let midX = (l.x + r.x) / 2
        let midY = (l.y + r.y) / 2
        let angle = atan2(r.y - l.y, r.x - l.x)

        let rect = CGRect(x: midX - w / 2, y: midY - h / 2, width: w, height: h)

        context.drawLayer { ctx in
            ctx.translateBy(x: midX, y: midY)
            ctx.rotate(by: .radians(angle))
            ctx.translateBy(x: -midX, y: -midY)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 6),
                       with: .color(.pink),
                       style: StrokeStyle(lineWidth: 2.5, dash: [6, 3]))
        }
    }

    // MARK: - Head Sphere

    private func drawHead(in context: GraphicsContext) {
        guard let nose = pose.nose, nose.isValid,
              let neck = pose.neck, neck.isValid else { return }

        let nosePt = transform.point(nose.point)
        let neckPt = transform.point(neck.point)
        let dist   = hypot(nosePt.x - neckPt.x, nosePt.y - neckPt.y)
        let r      = max(dist * 0.7, transform.length(0.05))

        let cx = nosePt.x
        let cy = nosePt.y - r * 0.4
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

        context.stroke(Path(ellipseIn: rect),
                       with: .color(.yellow),
                       style: StrokeStyle(lineWidth: 2.5, dash: [6, 3]))

        // Center cross
        var cross = Path()
        cross.move(to: CGPoint(x: cx - r * 0.6, y: cy))
        cross.addLine(to: CGPoint(x: cx + r * 0.6, y: cy))
        cross.move(to: CGPoint(x: cx, y: cy - r * 0.6))
        cross.addLine(to: CGPoint(x: cx, y: cy + r * 0.6))
        context.stroke(cross, with: .color(.yellow.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1))
    }

    // MARK: - Limb Cylinders (wireframe)

    private func drawLimbCylinders(in context: GraphicsContext) {
        let t = transform.length(0.035)
        drawCylinder(from: pose.leftShoulder,  to: pose.leftElbow,   radius: t,        color: .cyan, in: context)
        drawCylinder(from: pose.leftElbow,     to: pose.leftWrist,   radius: t * 0.85, color: .cyan, in: context)
        drawCylinder(from: pose.rightShoulder, to: pose.rightElbow,  radius: t,        color: .cyan, in: context)
        drawCylinder(from: pose.rightElbow,    to: pose.rightWrist,  radius: t * 0.85, color: .cyan, in: context)
        drawCylinder(from: pose.leftHip,  to: pose.leftKnee,   radius: t * 1.2, color: .purple, in: context)
        drawCylinder(from: pose.leftKnee, to: pose.leftAnkle,  radius: t * 1.0, color: .purple, in: context)
        drawCylinder(from: pose.rightHip, to: pose.rightKnee,  radius: t * 1.2, color: .purple, in: context)
        drawCylinder(from: pose.rightKnee, to: pose.rightAnkle, radius: t * 1.0, color: .purple, in: context)
    }

    private func drawCylinder(from aKP: Keypoint?, to bKP: Keypoint?,
                               radius: CGFloat, color: Color,
                               in context: GraphicsContext) {
        guard let a = aKP, a.isValid, let b = bKP, b.isValid else { return }
        let p1 = transform.point(a.point)
        let p2 = transform.point(b.point)
        let angle = atan2(p2.y - p1.y, p2.x - p1.x)
        let len   = hypot(p2.x - p1.x, p2.y - p1.y)
        let rect  = CGRect(x: -(len / 2), y: -radius, width: len, height: radius * 2)
        let mid   = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)

        context.drawLayer { ctx in
            ctx.translateBy(x: mid.x, y: mid.y)
            ctx.rotate(by: .radians(angle))
            ctx.stroke(Path(roundedRect: rect, cornerSize: CGSize(width: radius, height: radius)),
                       with: .color(color),
                       style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            // End-cap ellipses (foreshortening hint)
            let capRect = CGRect(x: -(len / 2) - 2, y: -radius,
                                 width: radius * 0.6, height: radius * 2)
            ctx.stroke(Path(ellipseIn: capRect),
                       with: .color(color.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1))
        }
    }

    // MARK: - Center Line

    private func drawCenterLine(in context: GraphicsContext) {
        guard let nose = pose.nose, nose.isValid,
              let mh = pose.midHip else { return }
        let top = transform.point(nose.point)
        let bot = transform.point(mh)

        var path = Path()
        path.move(to: top)
        path.addLine(to: bot)
        context.stroke(path,
                       with: .color(.white.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
}
