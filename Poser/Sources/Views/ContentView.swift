import SwiftUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var navigateToAnalysis = false
    @StateObject private var detector = PoseDetector()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(white: 0.08), Color(white: 0.04)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Hero
                    VStack(spacing: 16) {
                        Image(systemName: "figure.stand.line.dotted.figure.stand")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )

                        Text("Pose Simplifier")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Analyze any body pose into gesture lines,\nskeletons, mannequins, and construction shapes.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    // Mode preview pills
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
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.bottom, 40)

                    // CTA Buttons
                    VStack(spacing: 12) {
                        Button {
                            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.orange, .pink],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button { showLibrary = true } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.1))
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
            }
            .navigationDestination(isPresented: $navigateToAnalysis) {
                if let img = selectedImage {
                    AnalysisView(image: img, detector: detector)
                }
            }
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
            if img != nil {
                detector.reset()
                navigateToAnalysis = true
            }
        }
    }
}
