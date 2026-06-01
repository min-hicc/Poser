import Foundation
import CoreGraphics
import Vision

// MARK: - Drawing Mode

enum DrawingMode: String, CaseIterable, Identifiable {
    case gesture = "Gesture"
    case skeleton = "Skeleton"
    case mannequin = "Mannequin"
    case construction = "Construction"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gesture:     return "scribble"
        case .skeleton:    return "figure.stand"
        case .mannequin:   return "person.crop.rectangle"
        case .construction: return "square.on.circle"
        }
    }

    var description: String {
        switch self {
        case .gesture:      return "Line of action"
        case .skeleton:     return "Stick figure"
        case .mannequin:    return "3D forms"
        case .construction: return "Basic shapes"
        }
    }
}

// MARK: - Keypoint

struct Keypoint {
    let point: CGPoint     // normalized 0–1, origin bottom-left (Vision coords)
    let confidence: Float

    var isValid: Bool { confidence > 0.3 }
}

// MARK: - Detected Pose

struct DetectedPose {
    // Head / spine
    var nose: Keypoint?
    var neck: Keypoint?
    var leftShoulder: Keypoint?
    var rightShoulder: Keypoint?

    // Arms
    var leftElbow: Keypoint?
    var rightElbow: Keypoint?
    var leftWrist: Keypoint?
    var rightWrist: Keypoint?

    // Torso
    var leftHip: Keypoint?
    var rightHip: Keypoint?

    // Legs
    var leftKnee: Keypoint?
    var rightKnee: Keypoint?
    var leftAnkle: Keypoint?
    var rightAnkle: Keypoint?

    // MARK: Computed helpers

    var midShoulder: CGPoint? {
        guard let l = leftShoulder, l.isValid,
              let r = rightShoulder, r.isValid else { return nil }
        return CGPoint(x: (l.point.x + r.point.x) / 2,
                       y: (l.point.y + r.point.y) / 2)
    }

    var midHip: CGPoint? {
        guard let l = leftHip, l.isValid,
              let r = rightHip, r.isValid else { return nil }
        return CGPoint(x: (l.point.x + r.point.x) / 2,
                       y: (l.point.y + r.point.y) / 2)
    }

    var weightBearingLeg: Side {
        guard let lAnkle = leftAnkle, lAnkle.isValid,
              let rAnkle = rightAnkle, rAnkle.isValid,
              let hip = midHip else { return .left }
        let distL = abs(lAnkle.point.x - hip.x)
        let distR = abs(rAnkle.point.x - hip.x)
        return distL < distR ? .left : .right
    }

    enum Side { case left, right }

    var allKeypoints: [Keypoint?] {
        [nose, neck, leftShoulder, rightShoulder,
         leftElbow, rightElbow, leftWrist, rightWrist,
         leftHip, rightHip, leftKnee, rightKnee,
         leftAnkle, rightAnkle]
    }

    var isValid: Bool { allKeypoints.compactMap { $0 }.filter { $0.isValid }.count >= 4 }
}

// MARK: - Vision → DetectedPose

extension DetectedPose {
    init?(observation: VNHumanBodyPoseObservation) {
        func kp(_ joint: VNHumanBodyPoseObservation.JointName) -> Keypoint? {
            guard let recognized = try? observation.recognizedPoint(joint),
                  recognized.confidence > 0 else { return nil }
            return Keypoint(point: recognized.location, confidence: recognized.confidence)
        }

        nose          = kp(.nose)
        neck          = kp(.neck)
        leftShoulder  = kp(.leftShoulder)
        rightShoulder = kp(.rightShoulder)
        leftElbow     = kp(.leftElbow)
        rightElbow    = kp(.rightElbow)
        leftWrist     = kp(.leftWrist)
        rightWrist    = kp(.rightWrist)
        leftHip       = kp(.leftHip)
        rightHip      = kp(.rightHip)
        leftKnee      = kp(.leftKnee)
        rightKnee     = kp(.rightKnee)
        leftAnkle     = kp(.leftAnkle)
        rightAnkle    = kp(.rightAnkle)

        guard isValid else { return nil }
    }
}
