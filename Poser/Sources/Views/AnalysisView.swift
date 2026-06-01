import SwiftUI

struct AnalysisView: View {
    let image: UIImage
    @ObservedObject var detector: PoseDetector

    @State private var mode: DrawingMode = .skeleton
    @State private var overlayOpacity: Double = 1.0
    @State private var showOriginal = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Toolbar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Text("Pose Simplifier")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let url = exportImageURL() {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 12)

                // MARK: Image + Overlay
                GeometryReader { geo in
                    let size = fitSize(image: image, in: geo.size)

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)

                        if let pose = detector.pose, !showOriginal {
                            PoseOverlayView(pose: pose, mode: mode)
                                .frame(width: size.width, height: size.height)
                                .opacity(overlayOpacity)
                                .transition(.opacity)
                        }

                        if detector.isProcessing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.4))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                // MARK: Error banner
                if let err = detector.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                // MARK: Controls
                if detector.pose != nil {
                    VStack(spacing: 12) {
                        ModePickerView(selected: $mode)
                            .padding(.horizontal, 16)

                        HStack(spacing: 16) {
                            Label("Opacity", systemImage: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Slider(value: $overlayOpacity, in: 0...1)
                                .tint(.white)

                            Toggle("", isOn: $showOriginal)
                                .labelsHidden()
                                .tint(.orange)
                        }
                        .padding(.horizontal, 20)

                        // Mode description
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.bottom, 4)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { detector.detect(in: image) }
    }

    // MARK: - Helpers

    private func fitSize(image: UIImage, in available: CGSize) -> CGSize {
        let imgW = image.size.width
        let imgH = image.size.height
        let scale = min(available.width / imgW, available.height / imgH)
        return CGSize(width: imgW * scale, height: imgH * scale)
    }

    private func exportImageURL() -> URL? {
        let renderer = ImageRenderer(
            content:
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    if let pose = detector.pose {
                        PoseOverlayView(pose: pose, mode: mode)
                    }
                }
                .frame(width: image.size.width, height: image.size.height)
        )

        renderer.scale = UIScreen.main.scale

        guard
            let uiImage = renderer.uiImage,
            let data = uiImage.pngData()
        else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pose.png")

        try? data.write(to: url)

        return url
    }
}
