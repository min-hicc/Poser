import Vision
import UIKit
import Combine

@MainActor
final class PoseDetector: ObservableObject {
    @Published var pose: DetectedPose?
    @Published var isProcessing = false
    @Published var errorMessage: String?

    func detect(in image: UIImage) {
        // Normalize first: redraw the image so pixel data is always upright (.up).
        // Passing a non-up CGImage + its orientation to VNImageRequestHandler causes
        // "Unable to setup request in VNDetectHumanBodyPoseRequest" on device.
        let normalized = image.normalizedUpright()
        guard let cgImage = normalized.cgImage else { return }
        isProcessing = true
        errorMessage = nil

        let request = VNDetectHumanBodyPoseRequest()
        // After normalization the orientation is always .up — no need to pass it.
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try handler.perform([request])
                let detected = request.results?.first.flatMap { DetectedPose(observation: $0) }
                await MainActor.run {
                    self?.pose = detected
                    self?.isProcessing = false
                    if detected == nil {
                        self?.errorMessage = "No person detected. Try a photo with a clear full-body or upper-body view."
                    }
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            }
        }
    }

    func reset() {
        pose = nil
        errorMessage = nil
    }
}

// MARK: - UIImage normalization

extension UIImage {
    /// Returns a copy of the image redrawn so its pixel data is upright (orientation == .up).
    /// This prevents Vision from throwing "Unable to setup request" errors caused by
    /// mismatches between raw CGImage pixel layout and the EXIF orientation tag.
    func normalizedUpright() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
