import Vision
import UIKit
import Combine
import CoreVideo
import simd

@MainActor
final class PoseDetector: ObservableObject {
    @Published var pose: DetectedPose?
    @Published var isProcessing = false
    @Published var errorMessage: String?

    func detect(in image: UIImage) {
        isProcessing = true
        errorMessage = nil

        // Capture image data as PNG bytes so we can safely cross the actor boundary.
        // This avoids passing UIImage (which holds a non-Sendable CGImage) into a
        // detached task, which is what caused Vision's "Unable to setup request" crash.
        guard let imageData = image.pngData() else {
            isProcessing = false
            errorMessage = "Could not read image data."
            return
        }

        // This Task inherits the @MainActor isolation of the class, so touching
        // self here is always on the main actor — no cross-domain capture.
        Task {
            let result = await Self.runDetection(on: imageData)
            // Back on the main actor automatically.
            isProcessing = false
            switch result {
            case .success(let detected):
                pose = detected
                if detected == nil {
                    errorMessage = "No person detected. Try a photo with a clear full-body or upper-body view."
                }
            case .failure(let error):
                #if targetEnvironment(simulator)
                errorMessage = "Body pose detection isn't supported on the iOS Simulator. Please run Poser on a physical iPhone or iPad."
                #else
                errorMessage = "Pose detection failed: \(error.localizedDescription)"
                #endif
            }
        }
    }

    /// Heavy Vision work, fully off the main actor. Takes/returns only Sendable
    /// values (Data in, a Result out), so nothing crosses an isolation boundary.
    private nonisolated static func runDetection(
        on imageData: Data
    ) async -> Result<DetectedPose?, Error> {
        do {
            guard let bgImage = UIImage(data: imageData) else {
                throw DetectionError.badImage
            }
            let normalized = bgImage.normalizedUpright()
            guard let cgImage = normalized.cgImage else {
                throw DetectionError.badImage
            }

            // Create requests and handler together — Vision requires same-thread setup.
            //  • body pose      → skeleton joints
            //  • face landmarks → head box + eyes/nose/mouth/centerline
            //  • person segmentation → silhouette mask for true body widths
            let poseRequest = VNDetectHumanBodyPoseRequest()
            let faceRequest = VNDetectFaceLandmarksRequest()
            let segRequest  = VNGeneratePersonSegmentationRequest()
            segRequest.qualityLevel = .balanced
            segRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([poseRequest, faceRequest, segRequest])

            var detected = poseRequest.results?.first.flatMap { DetectedPose(observation: $0) }

            // Attach the largest detected face: head box + facial features.
            if detected != nil,
               let face = faceRequest.results?.max(by: {
                   $0.boundingBox.width * $0.boundingBox.height <
                   $1.boundingBox.width * $1.boundingBox.height
               }) {
                detected?.headBox = face.boundingBox
                detected?.face = Self.faceFeatures(from: face)
            }

            // Attach the silhouette mask + vectorized contours.
            if detected != nil,
               let maskBuffer = segRequest.results?.first?.pixelBuffer {
                detected?.bodyMask = BodyMask(pixelBuffer: maskBuffer)
                detected?.bodyContours = contours(from: maskBuffer)
            }
            return .success(detected)
        } catch {
            return .failure(error)
        }
    }

    /// Vectorizes the silhouette mask into normalized contour polygons.
    private nonisolated static func contours(from maskBuffer: CVPixelBuffer) -> [[CGPoint]] {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = false    // person (light) on dark background
        request.maximumImageDimension = 512   // downsample for speed

        let handler = VNImageRequestHandler(cvPixelBuffer: maskBuffer, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else { return [] }

        var polygons: [[CGPoint]] = []
        for i in 0 ..< observation.contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }
            let pts = contour.normalizedPoints
            guard pts.count >= 12 else { continue }           // drop specks

            let cgPts = pts.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

            // Skip a full-frame border contour, if Vision produces one.
            let xs = cgPts.map(\.x), ys = cgPts.map(\.y)
            let w = (xs.max() ?? 0) - (xs.min() ?? 0)
            let h = (ys.max() ?? 0) - (ys.min() ?? 0)
            if w > 0.97 && h > 0.97 { continue }

            polygons.append(cgPts)
        }
        return polygons
    }

    /// Extracts eye centers and the face centerline from a face observation,
    /// converted to full-image normalized coords (Vision, bottom-left origin).
    private nonisolated static func faceFeatures(from face: VNFaceObservation) -> FaceFeatures {
        guard let landmarks = face.landmarks else { return FaceFeatures() }
        let unit = CGSize(width: 1, height: 1)   // imageSize 1×1 → normalized coords

        func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let region, region.pointCount > 0 else { return nil }
            let pts = region.pointsInImage(imageSize: unit)
            let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(pts.count), y: sum.y / CGFloat(pts.count))
        }

        var features = FaceFeatures()
        features.leftEye  = centroid(landmarks.leftEye)
        features.rightEye = centroid(landmarks.rightEye)

        if let median = landmarks.medianLine, median.pointCount >= 2 {
            let pts = median.pointsInImage(imageSize: unit)
            // Bottom-left origin: largest y = top of face, smallest y = bottom.
            features.medianTop    = pts.max(by: { $0.y < $1.y })
            features.medianBottom = pts.min(by: { $0.y < $1.y })
        }
        return features
    }

    private enum DetectionError: LocalizedError {
        case badImage
        var errorDescription: String? { "Could not process image." }
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
