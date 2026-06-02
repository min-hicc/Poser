import CoreVideo
import CoreGraphics

/// A person-segmentation silhouette, flattened into a plain byte buffer so it's
/// Sendable and cheap to sample from the render path.
/// Values: 0 = background, 255 = person. Origin is top-left (row 0 == top).
struct BodyMask: Sendable {
    let width: Int
    let height: Int
    let data: [UInt8]

    /// Samples the mask at a Vision-normalized point (origin bottom-left, y-up).
    func isBody(normalized p: CGPoint, threshold: UInt8 = 128) -> Bool {
        guard width > 0, height > 0 else { return false }
        let col = Int((p.x * CGFloat(width)).rounded())
        let row = Int(((1 - p.y) * CGFloat(height)).rounded())   // flip y → top-left rows
        guard col >= 0, col < width, row >= 0, row < height else { return false }
        return data[row * width + col] >= threshold
    }
}

extension BodyMask {
    /// Copies a single-channel (OneComponent8) CVPixelBuffer into a BodyMask.
    init?(pixelBuffer pb: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        guard w > 0, h > 0, let base = CVPixelBufferGetBaseAddress(pb) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let src = base.assumingMemoryBound(to: UInt8.self)

        var out = [UInt8](repeating: 0, count: w * h)
        out.withUnsafeMutableBufferPointer { dst in
            for row in 0 ..< h {
                let rowPtr = src + row * bytesPerRow
                for col in 0 ..< w {
                    dst[row * w + col] = rowPtr[col]
                }
            }
        }

        self.width = w
        self.height = h
        self.data = out
    }
}

// MARK: - Torso width scanning

extension BodyMask {
    /// A horizontal slice across the body: its center plus the left and right
    /// silhouette edges (all normalized, Vision coords).
    struct Span: Sendable {
        let center: CGPoint
        let left: CGPoint
        let right: CGPoint
        let widthPx: CGFloat   // pixel width, for comparing levels
    }

    private func isBodyPixel(_ x: Int, _ y: Int, threshold: UInt8 = 128) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return data[y * width + x] >= threshold
    }

    /// Scans across the body at `center`, perpendicular to the torso `axis`
    /// (a normalized, y-up direction), returning the silhouette edges.
    func span(atNormalized center: CGPoint, axis: CGVector) -> Span? {
        guard width > 0, height > 0 else { return nil }

        // Center in pixel space (origin top-left, y-down).
        let cx = center.x * CGFloat(width)
        let cy = (1 - center.y) * CGFloat(height)

        // Torso axis → pixel space, then its perpendicular (the scan direction).
        var ax = axis.dx * CGFloat(width)
        var ay = -axis.dy * CGFloat(height)
        let al = hypot(ax, ay)
        guard al > 0 else { return nil }
        ax /= al; ay /= al
        let perpX = -ay, perpY = ax

        guard isBodyPixel(Int(cx.rounded()), Int(cy.rounded())) else { return nil }

        let maxStep = CGFloat(max(width, height))
        func march(_ sign: CGFloat) -> CGFloat {
            var d: CGFloat = 0
            while d <= maxStep {
                let x = Int((cx + perpX * sign * d).rounded())
                let y = Int((cy + perpY * sign * d).rounded())
                if !isBodyPixel(x, y) { return d }
                d += 1
            }
            return maxStep
        }
        let dR = march(1), dL = march(-1)

        func norm(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x / CGFloat(width), y: 1 - y / CGFloat(height))
        }
        return Span(
            center: center,
            left:  norm(cx - perpX * dL, cy - perpY * dL),
            right: norm(cx + perpX * dR, cy + perpY * dR),
            widthPx: dL + dR
        )
    }

    /// Walks the torso between the shoulder and hip centers and returns the
    /// chest (upper), waist (narrowest middle), and hip (lower) spans.
    /// The narrowest-in-band rule for the waist naturally ignores levels where
    /// the arms merge with the torso, since those rows are *wider*, not narrower.
    func torsoSpans(shoulderCenter s: CGPoint, hipCenter h: CGPoint,
                    samples: Int = 14) -> (chest: Span, waist: Span, hip: Span)? {
        let axis = CGVector(dx: h.x - s.x, dy: h.y - s.y)
        var levels: [(t: CGFloat, span: Span)] = []
        for i in 0...samples {
            let t = 0.12 + (0.95 - 0.12) * CGFloat(i) / CGFloat(samples)
            let c = CGPoint(x: s.x + axis.dx * t, y: s.y + axis.dy * t)
            if let sp = span(atNormalized: c, axis: axis) {
                levels.append((t, sp))
            }
        }
        guard let chest = levels.first?.span, let hip = levels.last?.span else { return nil }

        let midBand = levels.filter { $0.t >= 0.40 && $0.t <= 0.82 }
        let waist = (midBand.min { $0.span.widthPx < $1.span.widthPx }
                     ?? levels[levels.count / 2]).span
        return (chest, waist, hip)
    }
}
