import SwiftUI

/// A Canvas that renders the selected overlay mode on top of the image.
struct PoseOverlayView: View {
    let pose: DetectedPose
    let mode: DrawingMode

    var body: some View {
        Canvas { context, size in
            let transform = CoordTransform(canvasSize: size)
            switch mode {
            case .lines:
                GestureRenderer(pose: pose, transform: transform).draw(in: context)
            case .shapes:
                ShapesRenderer(pose: pose, transform: transform).draw(in: context)
            case .outline:
                OutlineRenderer(pose: pose, transform: transform).draw(in: context)
            }
        }
        .allowsHitTesting(false)
    }
}
