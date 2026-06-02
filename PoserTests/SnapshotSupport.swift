import SwiftUI
import UIKit
import SnapshotTesting

extension Snapshotting where Value: SwiftUI.View, Format == UIImage {
    /// Fixed-size image snapshot with tolerance for sub-pixel / anti-aliasing
    /// noise (text and SF Symbols rarely rasterize byte-identically between the
    /// record pass and later compares).
    ///   - precision: fraction of pixels that must match.
    ///   - perceptualPrecision: how close each pixel must be.
    static func tolerant(width: CGFloat, height: CGFloat) -> Snapshotting {
        .image(precision: 0.98,
               perceptualPrecision: 0.97,
               layout: .fixed(width: width, height: height))
    }
}
