import SwiftUI
import SceneKit
import ARKit

enum MeshStyle: String, CaseIterable {
    case original = "Original"
    case hologram = "Hologram"
    case wireframe = "Wireframe"
    case xray = "X-Ray"
    case toon = "Toon"
    case chrome = "Chrome"
    case neon = "Neon"
    case glitch = "Glitch"
    case roseGold = "Rose Gold"
    case crystal = "Crystal"
    case aurora = "Aurora"
    case pearl = "Pearl"
    case galaxy = "Galaxy"
    case sunset = "Sunset"
    case lavender = "Lavender"
    case cherryBlossom = "Cherry Blossom"
    // Anime/Game styles
    case genshin = "Genshin"
    case zelda = "Zelda"
    case fortnite = "Fortnite"
    case valorant = "Valorant"
    case persona = "Persona"
    case anime = "Anime"
}

struct ContentView: View {
    @StateObject private var viewModel = SceneViewModel()
    @State private var showARView = false
    @State private var currentStyle: MeshStyle = .original
    @State private var showStylePicker = false

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
                // Frame info, style picker, and AR button
                HStack {
                    Text("Frame: \(viewModel.currentFrame + 1)/\(viewModel.totalFrames)")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.5))
                        .cornerRadius(8)

                    Spacer()

                    // Style picker button
                    Button(action: { showStylePicker.toggle() }) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                            Text(currentStyle.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }

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

            // Style picker overlay
            if showStylePicker {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { showStylePicker = false }

                VStack(spacing: 12) {
                    Text("Choose Style")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(MeshStyle.allCases, id: \.self) { style in
                            Button(action: {
                                currentStyle = style
                                viewModel.applyStyle(style)
                                showStylePicker = false
                            }) {
                                Text(style.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(currentStyle == style ? Color.purple : Color.gray.opacity(0.6))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color(UIColor.systemGray6).opacity(0.95))
                .cornerRadius(16)
                .padding(.horizontal, 40)
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

    func applyStyle(_ style: MeshStyle) {
        for node in meshNodes {
            guard let geometry = node.geometry else { continue }

            let material = SCNMaterial()

            switch style {
            case .original:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor.white
                material.roughness.contents = 0.6
                material.metalness.contents = 0.0
                material.isDoubleSided = true
                node.opacity = 1.0

            case .hologram:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.7)
                material.emission.contents = UIColor(red: 0.0, green: 0.5, blue: 0.8, alpha: 1.0)
                material.transparent.contents = UIColor(white: 1.0, alpha: 0.6)
                material.isDoubleSided = true
                material.writesToDepthBuffer = true
                material.readsFromDepthBuffer = true
                material.blendMode = .add
                node.opacity = 0.8

            case .wireframe:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor.black
                material.emission.contents = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
                material.isDoubleSided = true
                material.fillMode = .lines
                node.opacity = 1.0

            case .xray:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3)
                material.emission.contents = UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.5)
                material.transparent.contents = UIColor(white: 1.0, alpha: 0.4)
                material.isDoubleSided = true
                material.blendMode = .alpha
                material.writesToDepthBuffer = false
                node.opacity = 0.6

            case .toon:
                material.lightingModel = .phong
                material.diffuse.contents = UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)
                material.specular.contents = UIColor.white
                material.shininess = 0.1
                material.isDoubleSided = true
                node.opacity = 1.0

            case .chrome:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 0.8, green: 0.8, blue: 0.85, alpha: 1.0)
                material.metalness.contents = 1.0
                material.roughness.contents = 0.1
                material.isDoubleSided = true
                node.opacity = 1.0

            case .neon:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
                material.emission.contents = UIColor(red: 1.0, green: 0.0, blue: 0.8, alpha: 1.0)
                material.isDoubleSided = true
                material.fresnelExponent = 3.0
                node.opacity = 1.0

            case .glitch:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.0, green: 0.1, blue: 0.0, alpha: 1.0)
                material.emission.contents = UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0)
                material.isDoubleSided = true
                material.transparency = 0.9
                node.opacity = 0.95

            case .roseGold:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 0.92, green: 0.7, blue: 0.65, alpha: 1.0)
                material.metalness.contents = 0.9
                material.roughness.contents = 0.25
                material.emission.contents = UIColor(red: 0.3, green: 0.15, blue: 0.12, alpha: 1.0)
                material.isDoubleSided = true
                node.opacity = 1.0

            case .crystal:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.6)
                material.metalness.contents = 0.1
                material.roughness.contents = 0.0
                material.emission.contents = UIColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 0.3)
                material.transparent.contents = UIColor(white: 1.0, alpha: 0.5)
                material.fresnelExponent = 2.0
                material.isDoubleSided = true
                material.blendMode = .alpha
                node.opacity = 0.85

            case .aurora:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 1.0)
                material.emission.contents = UIColor(red: 0.4, green: 0.8, blue: 0.7, alpha: 1.0)
                material.transparent.contents = UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 0.7)
                material.fresnelExponent = 2.5
                material.isDoubleSided = true
                material.blendMode = .add
                node.opacity = 0.9

            case .pearl:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1.0)
                material.metalness.contents = 0.3
                material.roughness.contents = 0.15
                material.emission.contents = UIColor(red: 0.95, green: 0.9, blue: 0.92, alpha: 0.2)
                material.fresnelExponent = 4.0
                material.isDoubleSided = true
                node.opacity = 1.0

            case .galaxy:
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.1, green: 0.05, blue: 0.2, alpha: 1.0)
                material.emission.contents = UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
                material.transparent.contents = UIColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 0.8)
                material.fresnelExponent = 3.0
                material.isDoubleSided = true
                node.opacity = 0.95

            case .sunset:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)
                material.emission.contents = UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 0.4)
                material.metalness.contents = 0.2
                material.roughness.contents = 0.5
                material.isDoubleSided = true
                node.opacity = 1.0

            case .lavender:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 0.85, green: 0.75, blue: 0.95, alpha: 1.0)
                material.emission.contents = UIColor(red: 0.6, green: 0.5, blue: 0.8, alpha: 0.3)
                material.metalness.contents = 0.1
                material.roughness.contents = 0.4
                material.fresnelExponent = 2.0
                material.isDoubleSided = true
                node.opacity = 1.0

            case .cherryBlossom:
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.88, alpha: 1.0)
                material.emission.contents = UIColor(red: 1.0, green: 0.6, blue: 0.7, alpha: 0.35)
                material.metalness.contents = 0.05
                material.roughness.contents = 0.35
                material.fresnelExponent = 1.5
                material.isDoubleSided = true
                node.opacity = 1.0

            // ANIME / GAME STYLES

            case .genshin:
                // Genshin Impact style - soft cel-shading, warm skin, rim light
                material.lightingModel = .phong
                material.diffuse.contents = UIColor(red: 1.0, green: 0.88, blue: 0.82, alpha: 1.0)
                material.specular.contents = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
                material.shininess = 0.15
                material.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.75, alpha: 0.15)
                material.fresnelExponent = 4.0
                material.isDoubleSided = true
                node.opacity = 1.0

            case .zelda:
                // Zelda BOTW style - soft pastel toon
                material.lightingModel = .phong
                material.diffuse.contents = UIColor(red: 0.95, green: 0.9, blue: 0.85, alpha: 1.0)
                material.specular.contents = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
                material.shininess = 0.1
                material.emission.contents = UIColor(red: 0.85, green: 0.9, blue: 0.95, alpha: 0.2)
                material.fresnelExponent = 3.0
                material.isDoubleSided = true
                node.opacity = 1.0

            case .fortnite:
                // Fortnite style - bold, saturated, plastic-like
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 1.0, green: 0.75, blue: 0.65, alpha: 1.0)
                material.metalness.contents = 0.0
                material.roughness.contents = 0.7
                material.emission.contents = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 0.1)
                material.isDoubleSided = true
                node.opacity = 1.0

            case .valorant:
                // Valorant style - clean, sharp, slightly stylized
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(red: 0.95, green: 0.85, blue: 0.8, alpha: 1.0)
                material.metalness.contents = 0.05
                material.roughness.contents = 0.5
                material.emission.contents = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.1)
                material.fresnelExponent = 2.5
                material.isDoubleSided = true
                node.opacity = 1.0

            case .persona:
                // Persona 5 style - high contrast, bold reds
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.15, green: 0.1, blue: 0.1, alpha: 1.0)
                material.emission.contents = UIColor(red: 1.0, green: 0.1, blue: 0.2, alpha: 1.0)
                material.fresnelExponent = 5.0
                material.isDoubleSided = true
                node.opacity = 1.0

            case .anime:
                // Classic anime style - soft skin, clean look
                material.lightingModel = .phong
                material.diffuse.contents = UIColor(red: 1.0, green: 0.92, blue: 0.88, alpha: 1.0)
                material.specular.contents = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
                material.shininess = 0.2
                material.emission.contents = UIColor(red: 1.0, green: 0.8, blue: 0.75, alpha: 0.1)
                material.fresnelExponent = 3.5
                material.isDoubleSided = true
                node.opacity = 1.0
            }

            geometry.materials = [material]
        }

        // Update scene background based on style
        switch style {
        case .hologram, .glitch:
            scene.background.contents = UIColor.black
        case .neon:
            scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        case .xray:
            scene.background.contents = UIColor(red: 0.0, green: 0.05, blue: 0.1, alpha: 1.0)
        case .roseGold:
            scene.background.contents = UIColor(red: 0.15, green: 0.1, blue: 0.1, alpha: 1.0)
        case .crystal:
            scene.background.contents = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
        case .aurora:
            scene.background.contents = UIColor(red: 0.02, green: 0.05, blue: 0.1, alpha: 1.0)
        case .pearl:
            scene.background.contents = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        case .galaxy:
            scene.background.contents = UIColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 1.0)
        case .sunset:
            scene.background.contents = UIColor(red: 0.15, green: 0.08, blue: 0.1, alpha: 1.0)
        case .lavender:
            scene.background.contents = UIColor(red: 0.1, green: 0.08, blue: 0.15, alpha: 1.0)
        case .cherryBlossom:
            scene.background.contents = UIColor(red: 0.12, green: 0.08, blue: 0.1, alpha: 1.0)
        case .genshin:
            scene.background.contents = UIColor(red: 0.12, green: 0.15, blue: 0.2, alpha: 1.0)
        case .zelda:
            scene.background.contents = UIColor(red: 0.15, green: 0.18, blue: 0.2, alpha: 1.0)
        case .fortnite:
            scene.background.contents = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)
        case .valorant:
            scene.background.contents = UIColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 1.0)
        case .persona:
            scene.background.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        case .anime:
            scene.background.contents = UIColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
        default:
            scene.background.contents = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        }
    }
}

#Preview {
    ContentView()
}
