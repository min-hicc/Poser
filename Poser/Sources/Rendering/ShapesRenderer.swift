import SwiftUI

/// "Shapes" mode — sized to the *actual* body silhouette via the segmentation mask:
///  - Limbs → tapered isosceles triangles whose base spans the real limb width
///            at the proximal joint, converging to a point at the distal joint
///  - Torso → quadrilateral whose corners are pushed out to the real body edges
///  - Head  → circle from the detected face box (fallback: nose↔neck)
///  - Hands → rectangles at each wrist, oriented along the forearm
struct ShapesRenderer {
    let pose: DetectedPose
    let transform: CoordTransform

    private let fillColor   = Color.orange.opacity(0.6)
    private let strokeColor = Color.white.opacity(0.9)
    private let lineWidth: CGFloat = 2

    func draw(in context: GraphicsContext) {
        drawTorso(in: context)

        // Arms (fallback widths used only when no mask is available)
        drawTaper(from: pose.leftShoulder,  to: pose.leftElbow,  fallback: 0.055, in: context)
        drawTaper(from: pose.leftElbow,     to: pose.leftWrist,  fallback: 0.045, in: context)
        drawTaper(from: pose.rightShoulder, to: pose.rightElbow, fallback: 0.055, in: context)
        drawTaper(from: pose.rightElbow,    to: pose.rightWrist, fallback: 0.045, in: context)

        // Legs
        drawTaper(from: pose.leftHip,   to: pose.leftKnee,   fallback: 0.075, in: context)
        drawTaper(from: pose.leftKnee,  to: pose.leftAnkle,  fallback: 0.055, in: context)
        drawTaper(from: pose.rightHip,  to: pose.rightKnee,  fallback: 0.075, in: context)
        drawTaper(from: pose.rightKnee, to: pose.rightAnkle, fallback: 0.055, in: context)

        // Hands
        drawHand(wrist: pose.leftWrist,  elbow: pose.leftElbow,  in: context)
        drawHand(wrist: pose.rightWrist, elbow: pose.rightElbow, in: context)

        // Head on top
        drawHead(in: context)
    }

    // MARK: - Mask ray-march

    /// Marches from `p` along (dirX, dirY) until it leaves the body, returning
    /// the distance (canvas pts) to the silhouette edge. nil if no mask or the
    /// start point isn't on the body.
    private func edgeDistance(from p: CGPoint, dirX: CGFloat, dirY: CGFloat,
                              maxDist: CGFloat) -> CGFloat? {
        guard let mask = pose.bodyMask else { return nil }
        guard mask.isBody(normalized: transform.normalized(fromCanvas: p)) else { return nil }

        let step: CGFloat = 1.5
        var dist: CGFloat = step
        while dist <= maxDist {
            let pt = CGPoint(x: p.x + dirX * dist, y: p.y + dirY * dist)
            if !mask.isBody(normalized: transform.normalized(fromCanvas: pt)) {
                return dist            // first background pixel = the edge
            }
            dist += step
        }
        return maxDist
    }

    /// Distance between the hip joints, in canvas points (used to cap limb widths).
    private var hipWidth: CGFloat? {
        guard let lh = pose.leftHip, lh.isValid,
              let rh = pose.rightHip, rh.isValid else { return nil }
        let l = transform.point(lh.point)
        let r = transform.point(rh.point)
        return hypot(r.x - l.x, r.y - l.y)
    }

    // MARK: - Tapered triangle (wide base at A, point at B)

    private func drawTaper(from aKP: Keypoint?, to bKP: Keypoint?,
                           fallback: CGFloat, in context: GraphicsContext) {
        guard let a = aKP, a.isValid, let b = bKP, b.isValid else { return }
        let base = transform.point(a.point)   // wide end
        let apex = transform.point(b.point)   // pointed end

        let dx = apex.x - base.x, dy = apex.y - base.y
        let len = hypot(dx, dy)
        guard len > 0 else { return }

        let px = -dy / len, py = dx / len      // perpendicular unit vector
        let cap = transform.length(0.18)       // don't march across the whole torso

        // Measure the real body width to each side; on a limb both sides hit air,
        // at the shoulder/hip the outer side hits air while the inner runs into the
        // torso (capped) — so min() yields the true limb radius.
        var half: CGFloat
        if let dOut = edgeDistance(from: base, dirX: px, dirY: py, maxDist: cap),
           let dIn  = edgeDistance(from: base, dirX: -px, dirY: -py, maxDist: cap) {
            half = max(min(dOut, dIn), transform.length(0.02))
        } else {
            half = transform.length(fallback) / 2
        }

        // Cap the base so an over-wide joint detection can't blow it out:
        // the full base (2 × half) spans at most half the hip width.
        if let hw = hipWidth {
            half = min(half, hw * 0.25)
        }

        let baseL = CGPoint(x: base.x + px * half, y: base.y + py * half)
        let baseR = CGPoint(x: base.x - px * half, y: base.y - py * half)

        var path = Path()
        path.move(to: baseL)
        path.addLine(to: baseR)
        path.addLine(to: apex)
        path.closeSubpath()

        context.fill(path, with: .color(fillColor))
        context.stroke(path, with: .color(strokeColor),
                       style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
    }

    // MARK: - Torso quad (corners pushed out to the body edges)

    private func drawTorso(in context: GraphicsContext) {
        guard let ls = pose.leftShoulder, ls.isValid,
              let rs = pose.rightShoulder, rs.isValid,
              let lh = pose.leftHip, lh.isValid,
              let rh = pose.rightHip, rh.isValid else { return }

        // Shoulder corners go UP to the top of the shoulders (not out to the
        // arm). Hip corners go out to the body's sides.
        let shoulderL = extendUpward(ls.point)
        let shoulderR = extendUpward(rs.point)
        let hipL = extendOutward(lh.point, awayFrom: rh.point)
        let hipR = extendOutward(rh.point, awayFrom: lh.point)

        // Control point for a gentle dip at the neck along the top edge, instead
        // of a harsh straight collarbone line. The dip pushes "down" the torso
        // axis at the midpoint between the shoulders.
        let topMid = CGPoint(x: (shoulderL.x + shoulderR.x) / 2,
                             y: (shoulderL.y + shoulderR.y) / 2)
        var downX: CGFloat = 0, downY: CGFloat = 1
        if let sc = pose.midShoulder, let hc = pose.midHip {
            let s = transform.point(sc), h = transform.point(hc)
            let dx = h.x - s.x, dy = h.y - s.y
            let len = hypot(dx, dy)
            if len > 0 { downX = dx / len; downY = dy / len }
        }
        let shoulderSpan = hypot(shoulderR.x - shoulderL.x, shoulderR.y - shoulderL.y)
        let dip = shoulderSpan * 0.12            // ← tune the dip depth here
        let neckControl = CGPoint(x: topMid.x + downX * dip * 2,
                                  y: topMid.y + downY * dip * 2)

        var path = Path()

        if let mask = pose.bodyMask,
           let sc = pose.midShoulder, let hc = pose.midHip,
           let spans = mask.torsoSpans(shoulderCenter: sc, hipCenter: hc) {

            // Pull the waist edges in to the measured silhouette, re-centered on
            // the torso axis and clamped so it can only pinch in, never bulge out.
            let waistCenter = transform.point(spans.waist.center)
            let shoulderHalf = shoulderSpan / 2
            let hipHalf      = hypot(hipR.x - hipL.x, hipR.y - hipL.y) / 2
            let maxHalf      = min(shoulderHalf, hipHalf)

            let waistL = clamp(transform.point(spans.waist.left),  toward: waistCenter, maxDist: maxHalf)
            let waistR = clamp(transform.point(spans.waist.right), toward: waistCenter, maxDist: maxHalf)

            path.move(to: shoulderL)
            path.addQuadCurve(to: shoulderR, control: neckControl)   // dipped collar line
            path.addLine(to: waistR)
            path.addLine(to: hipR)
            path.addLine(to: hipL)
            path.addLine(to: waistL)
            path.closeSubpath()
        } else {
            // Fallback: straight sides, still with the dipped collar line.
            path.move(to: shoulderL)
            path.addQuadCurve(to: shoulderR, control: neckControl)
            path.addLine(to: hipR)
            path.addLine(to: hipL)
            path.closeSubpath()
        }

        context.fill(path, with: .color(fillColor))
        context.stroke(path, with: .color(strokeColor),
                       style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
    }

    /// Pulls `p` toward `center` if it's farther than `maxDist`.
    private func clamp(_ p: CGPoint, toward center: CGPoint, maxDist: CGFloat) -> CGPoint {
        let dx = p.x - center.x, dy = p.y - center.y
        let d = hypot(dx, dy)
        guard d > maxDist, d > 0 else { return p }
        let s = maxDist / d
        return CGPoint(x: center.x + dx * s, y: center.y + dy * s)
    }

    /// Pushes a joint upward (toward the head, along the torso axis) to the top
    /// of the silhouette — used for the torso's shoulder corners.
    private func extendUpward(_ normPoint: CGPoint) -> CGPoint {
        let p = transform.point(normPoint)

        // "Up" = from hip-center toward shoulder-center; default straight up.
        var ux: CGFloat = 0, uy: CGFloat = -1
        if let sc = pose.midShoulder, let hc = pose.midHip {
            let s = transform.point(sc), h = transform.point(hc)
            let dx = s.x - h.x, dy = s.y - h.y
            let len = hypot(dx, dy)
            if len > 0 { ux = dx / len; uy = dy / len }
        }

        if let d = edgeDistance(from: p, dirX: ux, dirY: uy, maxDist: transform.length(0.12)) {
            return CGPoint(x: p.x + ux * d, y: p.y + uy * d)
        }
        return p
    }

    /// Pushes a joint outward (away from its partner) to the silhouette edge.
    private func extendOutward(_ normPoint: CGPoint, awayFrom other: CGPoint) -> CGPoint {
        let p = transform.point(normPoint)
        let o = transform.point(other)
        let dx = p.x - o.x, dy = p.y - o.y
        let len = hypot(dx, dy)
        guard len > 0 else { return p }
        let ux = dx / len, uy = dy / len
        if let d = edgeDistance(from: p, dirX: ux, dirY: uy, maxDist: transform.length(0.12)) {
            return CGPoint(x: p.x + ux * d, y: p.y + uy * d)
        }
        return p
    }

    // MARK: - Hand rectangle

    private func drawHand(wrist wKP: Keypoint?, elbow eKP: Keypoint?,
                          in context: GraphicsContext) {
        guard let w = wKP, w.isValid else { return }
        let wrist = transform.point(w.point)

        var ux: CGFloat = 0, uy: CGFloat = 1
        var forearmLen = transform.length(0.12)
        if let e = eKP, e.isValid {
            let elbow = transform.point(e.point)
            let dx = wrist.x - elbow.x, dy = wrist.y - elbow.y
            let len = hypot(dx, dy)
            if len > 0 { ux = dx / len; uy = dy / len; forearmLen = len }
        }

        let px = -uy, py = ux
        let handLen = forearmLen * 0.55
        let halfW   = forearmLen * 0.22

        let tipX = wrist.x + ux * handLen
        let tipY = wrist.y + uy * handLen

        var path = Path()
        path.move(to:    CGPoint(x: wrist.x + px * halfW, y: wrist.y + py * halfW))
        path.addLine(to: CGPoint(x: wrist.x - px * halfW, y: wrist.y - py * halfW))
        path.addLine(to: CGPoint(x: tipX   - px * halfW, y: tipY   - py * halfW))
        path.addLine(to: CGPoint(x: tipX   + px * halfW, y: tipY   + py * halfW))
        path.closeSubpath()

        context.fill(path, with: .color(fillColor))
        context.stroke(path, with: .color(strokeColor),
                       style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
    }

    // MARK: - Head circle

    private func drawHead(in context: GraphicsContext) {
        let center: CGPoint
        var radius: CGFloat

        if let box = pose.headBox {
            let cs = transform.canvasSize
            center = transform.point(CGPoint(x: box.midX, y: box.midY))
            radius = max(box.width * cs.width, box.height * cs.height) / 2
        } else if let nose = pose.nose, nose.isValid,
                  let neck = pose.neck, neck.isValid {
            let n = transform.point(nose.point)
            let k = transform.point(neck.point)
            radius = max(hypot(n.x - k.x, n.y - k.y) * 0.9, transform.length(0.05))
            center = CGPoint(x: n.x, y: n.y - radius * 0.3)
        } else {
            return
        }

        // Keep the circle inside the head silhouette: march from the center
        // toward the top and sides and shrink the radius if it would poke out.
        // (Straight down is skipped — that's the neck, not the head edge.)
        if pose.bodyMask != nil {
            let dirs: [(CGFloat, CGFloat)] = [
                (0, -1),                            // top of head
                (-1, 0), (1, 0),                    // sides
                (-0.707, -0.707), (0.707, -0.707),  // upper temples
            ]
            for (dx, dy) in dirs {
                if let edge = edgeDistance(from: center, dirX: dx, dirY: dy, maxDist: radius * 1.5) {
                    radius = min(radius, edge)
                }
            }
        }

        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(fillColor))
        context.stroke(Path(ellipseIn: rect), with: .color(strokeColor),
                       style: StrokeStyle(lineWidth: lineWidth))
    }
}
