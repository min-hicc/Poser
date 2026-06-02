import SwiftUI

struct AnalysisView: View {
    let image: UIImage
    @ObservedObject var detector: PoseDetector

    @State private var modes: Set<DrawingMode> = [.lines]
    @State private var overlayOpacity: Double = 1.0
    @State private var imageOpacity: Double = 1.0
    @State private var showOriginal = false
    @State private var shareItem: ShareItem?
    @Environment(\.dismiss) private var dismiss

    // Wrapper so we can drive `.sheet(item:)` with a URL.
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

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
                    Button {
                        exportForSharing()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(detector.pose == nil)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 12)

                // MARK: Image + Overlay
                GeometryReader { geo in
                    let size = fitSize(image: image, in: geo.size)

                    ZStack {
                        // Gray backdrop so the photo can fade to gray.
                        Color(white: 0.85)
                            .frame(width: size.width, height: size.height)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                            .opacity(imageOpacity)

                        if let pose = detector.pose, !showOriginal {
                            PoseOverlayView(pose: pose, modes: modes)
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
                        ModePickerView(selected: $modes)
                            .padding(.horizontal, 16)

                        // Overlay opacity
                        HStack(spacing: 16) {
                            Label("Overlay", systemImage: "scribble.variable")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $overlayOpacity, in: 0...1)
                                .tint(Color.poserAccent)

//                            Toggle("", isOn: $showOriginal)
//                                .labelsHidden()
//                                .tint(.orange)
                        }
                        .padding(.horizontal, 20)

                        // Photo opacity (fades to the white backdrop)
                        HStack(spacing: 16) {
                            Label("Photo", systemImage: "photo")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $imageOpacity, in: 0...1)
                                .tint(Color.poserAccent)
                        }
                        .padding(.horizontal, 20)

                        // Selected styles (ordered)
                        Text(selectedSummary)
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
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Helpers

    /// Selected style names in a stable order, or a hint when none are on.
    private var selectedSummary: String {
        let ordered = DrawingMode.allCases.filter { modes.contains($0) }
        return ordered.isEmpty
            ? "Tap a style to begin"
            : ordered.map(\.rawValue).joined(separator: " + ")
    }

    private func fitSize(image: UIImage, in available: CGSize) -> CGSize {
        let imgW = image.size.width
        let imgH = image.size.height
        let scale = min(available.width / imgW, available.height / imgH)
        return CGSize(width: imgW * scale, height: imgH * scale)
    }

    /// Renders the image + overlay to a PNG and presents the share sheet.
    /// Called ONLY when the user taps Share — never during normal rendering.
    @MainActor
    private func exportForSharing() {
        let renderer = ImageRenderer(
            content:
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    if let pose = detector.pose {
                        PoseOverlayView(pose: pose, modes: modes)
                    }
                }
                .frame(width: image.size.width, height: image.size.height)
        )

        // image.size is already in native pixels for our frame, so scale 1.0
        // yields full resolution without the 3x blow-up that was killing perf.
        renderer.scale = 1.0

        guard
            let uiImage = renderer.uiImage,
            let data = uiImage.pngData()
        else {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pose-\(UUID().uuidString).png")

        do {
            try data.write(to: url)
            shareItem = ShareItem(url: url)
        } catch {
            // Silently ignore — sharing simply won't open.
        }
    }
}
