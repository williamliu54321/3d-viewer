import SwiftUI
import ARKit
import SceneKit

struct ARViewContainer: UIViewRepresentable {
    let meshNodes: [SCNNode]
    @Binding var isPresented: Bool
    @Binding var currentFrame: Int
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        // Add tap gesture to place mesh
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 22
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(context.coordinator, action: #selector(Coordinator.closeTapped), for: .touchUpInside)
        arView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: arView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Tap on a surface to place the 3D model"
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.tag = 100
        arView.addSubview(instructionLabel)

        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            instructionLabel.bottomAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            instructionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            instructionLabel.heightAnchor.constraint(equalToConstant: 40)
        ])

        context.coordinator.arView = arView
        context.coordinator.meshNodes = meshNodes

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.meshNodes = meshNodes
        context.coordinator.updateFrame(currentFrame)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var arView: ARSCNView?
        var meshNodes: [SCNNode] = []
        var placedNodes: [SCNNode] = []
        var placementTransform: simd_float4x4?
        var meshScale: Float = 1.0
        var yOffset: Float = 0

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }

            let location = gesture.location(in: arView)

            // Raycast to find a surface
            if let query = arView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal) {
                let results = arView.session.raycast(query)

                if let firstResult = results.first {
                    placeMeshes(at: firstResult)
                }
            }
        }

        func placeMeshes(at raycastResult: ARRaycastResult) {
            guard let arView = arView, !meshNodes.isEmpty else {
                print("AR: No mesh nodes available")
                return
            }

            // Remove existing placed meshes
            for node in placedNodes {
                node.removeFromParentNode()
            }
            placedNodes.removeAll()

            // Store placement transform for frame updates
            placementTransform = raycastResult.worldTransform

            // Calculate scale and offset from first mesh
            let firstNode = meshNodes[0]
            let (minBound, maxBound) = firstNode.boundingBox
            let meshHeight = maxBound.y - minBound.y
            let meshWidth = maxBound.x - minBound.x
            let meshDepth = maxBound.z - minBound.z
            let meshSize = max(meshHeight, max(meshWidth, meshDepth))

            // Scale to human size (~1.7 meters tall)
            let targetHeight: Float = 1.7
            meshScale = targetHeight / meshSize
            yOffset = -minBound.y * meshScale

            // Clone and place all mesh nodes
            for (index, originalNode) in meshNodes.enumerated() {
                let clonedNode = originalNode.clone()
                clonedNode.scale = SCNVector3(meshScale, meshScale, meshScale)

                let transform = raycastResult.worldTransform
                clonedNode.position = SCNVector3(
                    transform.columns.3.x,
                    transform.columns.3.y + yOffset,
                    transform.columns.3.z
                )

                // Only show current frame
                clonedNode.isHidden = (index != parent.currentFrame)

                arView.scene.rootNode.addChildNode(clonedNode)
                placedNodes.append(clonedNode)
            }

            // Hide instruction label
            if let label = arView.viewWithTag(100) {
                UIView.animate(withDuration: 0.3) {
                    label.alpha = 0
                }
            }

            print("AR: Placed \(placedNodes.count) mesh frames")
        }

        func updateFrame(_ frame: Int) {
            guard !placedNodes.isEmpty else { return }

            for (index, node) in placedNodes.enumerated() {
                node.isHidden = (index != frame)
            }
        }

        @objc func closeTapped() {
            parent.isPresented = false
        }

        // ARSCNViewDelegate - add plane visualization
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

            let plane = SCNPlane(width: CGFloat(planeAnchor.planeExtent.width), height: CGFloat(planeAnchor.planeExtent.height))
            plane.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.3)

            let planeNode = SCNNode(geometry: plane)
            planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode.eulerAngles.x = -.pi / 2

            node.addChildNode(planeNode)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  let planeNode = node.childNodes.first,
                  let plane = planeNode.geometry as? SCNPlane else { return }

            plane.width = CGFloat(planeAnchor.planeExtent.width)
            plane.height = CGFloat(planeAnchor.planeExtent.height)
            planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        }
    }
}

struct ARViewSheet: View {
    let meshNodes: [SCNNode]
    @Binding var isPresented: Bool
    @State private var currentFrame: Int = 0
    @State private var isPlaying: Bool = true
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            ARViewContainer(
                meshNodes: meshNodes,
                isPresented: $isPresented,
                currentFrame: $currentFrame,
                isPlaying: $isPlaying
            )
            .ignoresSafeArea()

            // Timeline controls at bottom
            if meshNodes.count > 1 {
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Frame counter
                        Text("Frame: \(currentFrame + 1)/\(meshNodes.count)")
                            .font(.caption)
                            .foregroundStyle(.white)

                        HStack(spacing: 16) {
                            // Play/Pause button
                            Button(action: togglePlay) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 44)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }

                            // Timeline slider
                            Slider(
                                value: Binding(
                                    get: { Double(currentFrame) },
                                    set: { currentFrame = Int($0) }
                                ),
                                in: 0...Double(meshNodes.count - 1),
                                step: 1
                            )
                            .tint(.blue)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    .background(.black.opacity(0.7))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startPlayback()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    private func startPlayback() {
        guard meshNodes.count > 1 else { return }
        stopPlayback()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isPlaying {
                currentFrame = (currentFrame + 1) % meshNodes.count
            }
        }
    }

    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
    }
}
