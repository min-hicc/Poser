import SwiftUI

/// "Outline" mode — clean line-art:
///  - the body silhouette traced from the segmentation contours
///  - a simple cross on the face (horizontal eye line + vertical midface line)
struct OutlineRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    private let strokeColor = Color.white
    private let lineWidth: CGFloat = 2.5

    func draw(in context: GraphicsContext) {
        drawBodyOutline(in: context)
        drawFaceCross(in: context)
    }

    // MARK: - Body silhouette

    private func drawBodyOutline(in context: GraphicsContext) {
        for poly in pose.bodyContours where poly.count > 1 {
            var path = Path()
            path.move(to: transform.point(poly[0]))
            for p in poly.dropFirst() {
                path.addLine(to: transform.point(p))
            }
            path.closeSubpath()

            context.stroke(path,
                           with: .color(strokeColor),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Face cross

    private func drawFaceCross(in context: GraphicsContext) {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

        // Preferred: real facial features (eyes + centerline).
        if let face = pose.face, let le = face.leftEye, let re = face.rightEye {
            let lEye = transform.point(le)
            let rEye = transform.point(re)
            let dx = rEye.x - lEye.x, dy = rEye.y - lEye.y

            // Eye line, extended ~35% beyond each eye so it reads across the face.
            let ext: CGFloat = 0.35
            var eyeLine = Path()
            eyeLine.move(to: CGPoint(x: lEye.x - dx * ext, y: lEye.y - dy * ext))
            eyeLine.addLine(to: CGPoint(x: rEye.x + dx * ext, y: rEye.y + dy * ext))
            context.stroke(eyeLine, with: .color(strokeColor), style: style)

            // Vertical midface line — true centerline if available, else perpendicular.
            var vertical = Path()
            if let mt = face.medianTop, let mb = face.medianBottom {
                vertical.move(to: transform.point(mt))
                vertical.addLine(to: transform.point(mb))
            } else {
                let mid = CGPoint(x: (lEye.x + rEye.x) / 2, y: (lEye.y + rEye.y) / 2)
                let len = hypot(dx, dy)
                if len > 0 {
                    let px = -dy / len, py = dx / len   // perpendicular to eye line
                    let half = len * 0.95
                    vertical.move(to: CGPoint(x: mid.x - px * half, y: mid.y - py * half))
                    vertical.addLine(to: CGPoint(x: mid.x + px * half, y: mid.y + py * half))
                }
            }
            context.stroke(vertical, with: .color(strokeColor), style: style)
            return
        }

        // Fallback: head box / nose-neck estimate.
        let leftX, rightX, topY, bottomY, midX: CGFloat

        if let box = pose.headBox {
            // box is normalized, bottom-left origin → flip via transform.
            let topLeft     = transform.point(CGPoint(x: box.minX, y: box.maxY))
            let bottomRight = transform.point(CGPoint(x: box.maxX, y: box.minY))
            leftX = topLeft.x; rightX = bottomRight.x
            topY  = topLeft.y; bottomY = bottomRight.y
            midX  = (leftX + rightX) / 2
        } else if let nose = pose.nose, nose.isValid,
                  let neck = pose.neck, neck.isValid {
            // Fallback: estimate a head box from nose↔neck.
            let n = transform.point(nose.point)
            let k = transform.point(neck.point)
            let r = max(hypot(n.x - k.x, n.y - k.y) * 0.9, transform.length(0.05))
            let c = CGPoint(x: n.x, y: n.y - r * 0.3)
            leftX = c.x - r; rightX = c.x + r
            topY  = c.y - r; bottomY = c.y + r
            midX  = c.x
        } else {
            return
        }

        // Vertical midface line
        var vertical = Path()
        vertical.move(to: CGPoint(x: midX, y: topY))
        vertical.addLine(to: CGPoint(x: midX, y: bottomY))

        // Horizontal eye line, slightly above the face's vertical center
        let eyeY = topY + (bottomY - topY) * 0.45
        var horizontal = Path()
        horizontal.move(to: CGPoint(x: leftX, y: eyeY))
        horizontal.addLine(to: CGPoint(x: rightX, y: eyeY))

        context.stroke(vertical,   with: .color(strokeColor), style: style)
        context.stroke(horizontal, with: .color(strokeColor), style: style)
    }
}
