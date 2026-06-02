import SwiftUI
import AVFoundation

private let bgColor = Color(red: 0.90, green: 0.90, blue: 0.90)

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var picked: PickedImage?
    @State private var showCameraDeniedAlert = false
    @State private var showCameraUnavailableAlert = false
    @StateObject private var detector = PoseDetector()

    /// Wraps the chosen image so navigation is driven by a fresh identity each
    /// time — re-picking the *same* photo still pushes a new analysis screen.
    private struct PickedImage: Identifiable, Hashable {
        let id = UUID()
        let image: UIImage

        static func == (lhs: PickedImage, rhs: PickedImage) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()   // backmost layer — fills the whole window
            mainStack
        }
        .sheet(isPresented: $showCamera) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
                .ignoresSafeArea()
        }
        .onChange(of: selectedImage) { _, img in
            guard let img else { return }
            detector.reset()
            picked = PickedImage(image: img)
            selectedImage = nil   // clear so re-picking the same photo fires again
        }
        .alert("Camera Access Needed", isPresented: $showCameraDeniedAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Poser needs camera access to take photos. Enable it in Settings.")
        }
        .alert("Camera Unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device has no available camera. Try choosing a photo from your library instead.")
        }
    }

    // MARK: - Layout pieces

    private var mainStack: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    heroSection
                    Spacer().frame(height: 140)
                    ctaButtons
                }
            }
            .scrollContentBackground(.hidden)
            .background(bgColor)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $picked) { item in
                AnalysisView(image: item.image, detector: detector)
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 60)

            Text("Pose Simplifier")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.black)

            Text("Reduce any body pose to easy anatomy")
                .font(.subheadline)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            modePills
        }
    }

    private var modePills: some View {
        HStack(spacing: 8) {
            ForEach(DrawingMode.allCases) { mode in
                HStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.caption)
                    Text(mode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.1), in: Capsule())
                .foregroundColor(.black)
            }
        }
    }

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Text("Get Started")
                .font(.system(size: 24))
                .foregroundColor(.black)
                .padding(.bottom, 10)

            Button {
                handleTakePhoto()
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.30, green: 0.3, blue: 0.3))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button { showLibrary = true } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    // MARK: - Camera permission

    private func handleTakePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                    else { showCameraDeniedAlert = true }
                }
            }
        default: // .denied, .restricted
            showCameraDeniedAlert = true
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.light)
}
