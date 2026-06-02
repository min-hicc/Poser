import SwiftUI

/// A Canvas that renders the selected overlay modes (stacked) on top of the image.
struct PoseOverlayView: View {
    let pose: DetectedPose
    let modes: Set<DrawingMode>

    // Draw order (bottom → top): filled shapes first, then outline, then skeleton.
    private static let drawOrder: [DrawingMode] = [.shapes, .outline, .lines]

    var body: some View {
        Canvas { context, size in
            let transform = CoordTransform(canvasSize: size)
            for mode in Self.drawOrder where modes.contains(mode) {
                switch mode {
                case .lines:
                    GestureRenderer(pose: pose, transform: transform).draw(in: context)
                case .shapes:
                    ShapesRenderer(pose: pose, transform: transform).draw(in: context)
                case .outline:
                    OutlineRenderer(pose: pose, transform: transform).draw(in: context)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
