import CoreGraphics

/// Converts Vision's normalized coordinates (origin bottom-left, y-up)
/// into a UIKit/SwiftUI canvas rect (origin top-left, y-down).
struct CoordTransform {
    let canvasSize: CGSize

    func point(_ normalized: CGPoint) -> CGPoint {
        CGPoint(
            x: normalized.x * canvasSize.width,
            y: (1.0 - normalized.y) * canvasSize.height
        )
    }

    func length(_ fraction: CGFloat) -> CGFloat {
        fraction * min(canvasSize.width, canvasSize.height)
    }

    /// Inverse of `point(_:)` — canvas pixels back to Vision-normalized coords.
    func normalized(fromCanvas point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return .zero }
        return CGPoint(
            x: point.x / canvasSize.width,
            y: 1.0 - point.y / canvasSize.height
        )
    }
}
