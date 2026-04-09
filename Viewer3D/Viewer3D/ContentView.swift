import SwiftUI
import SceneKit
import ARKit

struct ContentView: View {
    @StateObject private var viewModel = SceneViewModel()
    @State private var showARView = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            SceneView(
                scene: viewModel.scene,
                pointOfView: viewModel.cameraNode,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .ignoresSafeArea()

            VStack {
                // Frame info and AR button
                HStack {
                    Text("Frame: \(viewModel.currentFrame + 1)/\(viewModel.totalFrames)")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.5))
                        .cornerRadius(8)
                    Spacer()

                    if ARWorldTrackingConfiguration.isSupported && viewModel.totalFrames > 0 {
                        Button(action: { showARView = true }) {
                            HStack {
                                Image(systemName: "arkit")
                                Text("AR")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()

                Spacer()

                // Frame slider
                if viewModel.totalFrames > 1 {
                    HStack {
                        Button(action: { viewModel.togglePlay() }) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 44)
                                .background(Color.green)
                                .cornerRadius(8)
                        }

                        Slider(value: Binding(
                            get: { Double(viewModel.currentFrame) },
                            set: { viewModel.setFrame(Int($0)) }
                        ), in: 0...Double(viewModel.totalFrames - 1))
                        .tint(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // View controls
                HStack(spacing: 10) {
                    ViewButton(title: "Front") { viewModel.setView(.front) }
                    ViewButton(title: "Back") { viewModel.setView(.back) }
                    ViewButton(title: "Left") { viewModel.setView(.left) }
                    ViewButton(title: "Right") { viewModel.setView(.right) }
                    ViewButton(title: "Top") { viewModel.setView(.top) }
                    ViewButton(title: "Bottom") { viewModel.setView(.bottom) }
                }
                .padding(.bottom, 30)
            }

            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading meshes... \(viewModel.loadedCount)/20")
                        .foregroundStyle(.white)
                        .padding(.top)
                }
            }

            if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .background(.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onAppear {
            viewModel.loadMeshes()
        }
        .fullScreenCover(isPresented: $showARView) {
            ARViewSheet(meshNodes: viewModel.meshNodes, isPresented: $showARView)
        }
    }
}

struct ViewButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
        }
    }
}

enum CameraView {
    case front, back, left, right, top, bottom
}

@MainActor
class SceneViewModel: ObservableObject {
    @Published var scene = SCNScene()
    @Published var cameraNode = SCNNode()
    @Published var currentFrame = 0
    @Published var totalFrames = 0
    @Published var isPlaying = false
    @Published var isLoading = true
    @Published var loadedCount = 0
    @Published var errorMessage: String?

    private(set) var meshNodes: [SCNNode] = []
    private var timer: Timer?
    private let cameraDistance: Float = 2.0

    var currentMeshNode: SCNNode? {
        guard currentFrame >= 0 && currentFrame < meshNodes.count else { return nil }
        return meshNodes[currentFrame]
    }

    // Path to PLY files
    private let meshFolderPath = "/Users/williamliu/IdeaProjects/3d-viewer/meshes"
    private let expectedFrameCount = 20

    init() {
        setupScene()
        setupCamera()
    }

    private func setupScene() {
        // Gradient background
        scene.background.contents = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)

        // Ambient light - soft fill
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 300
        ambientLight.light?.color = UIColor(red: 0.6, green: 0.65, blue: 0.8, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Key light - main directional with shadows
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1000
        keyLight.light?.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        keyLight.light?.castsShadow = true
        keyLight.light?.shadowMode = .deferred
        keyLight.light?.shadowColor = UIColor.black.withAlphaComponent(0.5)
        keyLight.light?.shadowRadius = 8
        keyLight.light?.shadowSampleCount = 16
        keyLight.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        keyLight.position = SCNVector3(3, 5, 4)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)

        // Fill light - softer, opposite side
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.light?.color = UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        fillLight.position = SCNVector3(-4, 2, 3)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)

        // Rim light - edge definition from behind
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 600
        rimLight.light?.color = UIColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 1.0)
        rimLight.position = SCNVector3(0, 3, -5)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)

        // Ground plane for shadows
        let groundGeometry = SCNFloor()
        groundGeometry.reflectivity = 0.05
        groundGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        groundGeometry.firstMaterial?.lightingModel = .physicallyBased
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.position = SCNVector3(0, -1, 0)
        scene.rootNode.addChildNode(groundNode)
    }

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 0, cameraDistance)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    func loadMeshes() {
        isLoading = true
        loadedCount = 0

        Task {
            for i in 0..<expectedFrameCount {
                let filename = String(format: "%08d", i)

                // Try loading from bundle (files are in root, not subdirectory)
                if let url = Bundle.main.url(forResource: filename, withExtension: "ply") {
                    print("DEBUG: Found in bundle: \(filename).ply")
                    if let node = PLYLoader.loadPLY(from: url) {
                        node.isHidden = (i != 0)
                        print("DEBUG: Loaded frame \(i)")
                        await MainActor.run {
                            scene.rootNode.addChildNode(node)
                            meshNodes.append(node)
                            loadedCount += 1
                            totalFrames = meshNodes.count
                        }
                    } else {
                        print("DEBUG: Failed to parse PLY: \(filename)")
                    }
                } else {
                    print("DEBUG: Not found in bundle: \(filename).ply")
                }
            }

            await MainActor.run {
                isLoading = false
                if totalFrames == 0 {
                    errorMessage = "No meshes loaded"
                }
            }
        }
    }

    func setFrame(_ frame: Int) {
        guard frame >= 0 && frame < meshNodes.count else { return }

        for (index, node) in meshNodes.enumerated() {
            node.isHidden = (index != frame)
        }
        currentFrame = frame
    }

    func togglePlay() {
        isPlaying.toggle()

        if isPlaying {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    let nextFrame = (self.currentFrame + 1) % self.totalFrames
                    self.setFrame(nextFrame)
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func setView(_ view: CameraView) {
        let position: SCNVector3
        let distance = cameraDistance

        switch view {
        case .front:
            position = SCNVector3(0, 0, distance)
        case .back:
            position = SCNVector3(0, 0, -distance)
        case .left:
            position = SCNVector3(-distance, 0, 0)
        case .right:
            position = SCNVector3(distance, 0, 0)
        case .top:
            position = SCNVector3(0, distance, 0.01)
        case .bottom:
            position = SCNVector3(0, -distance, 0.01)
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        cameraNode.position = position
        cameraNode.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }
}

#Preview {
    ContentView()
}
