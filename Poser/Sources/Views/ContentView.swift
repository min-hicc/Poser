import SwiftUI

private let bgColor = Color(red: 0.90, green: 0.90, blue: 0.90)

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var navigateToAnalysis = false
    @StateObject private var detector = PoseDetector()

    var body: some View {
      ZStack {
        bgColor.ignoresSafeArea()   // backmost layer — fills the whole window
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)


                    // Hero
                    VStack(spacing: 16) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .padding(.top, 60)

                        Text("Pose Simplifier")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        Text("Analyze any body pose into easy anatomy")
                            .font(.subheadline)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

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

                    Spacer().frame(height: 140)

                    // CTA Buttons
                    VStack(spacing: 12) {
                        Text("Get Started")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                            .padding(.bottom, 10)

                        Button {
                            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
                            showCamera = true
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
            }
            .scrollContentBackground(.hidden)
            .background(bgColor)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToAnalysis) {
                if let img = selectedImage {
                    AnalysisView(image: img, detector: detector)
                }
            }
        }
      } // ZStack
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

#Preview {
    ContentView()
        .preferredColorScheme(.light)
}
