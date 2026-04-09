import SwiftUI
import ARKit
import SceneKit

struct ARViewContainer: UIViewRepresentable {
    let meshNode: SCNNode?
    @Binding var isPresented: Bool

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
            instructionLabel.bottomAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            instructionLabel.heightAnchor.constraint(equalToConstant: 40)
        ])

        context.coordinator.arView = arView
        context.coordinator.meshNode = meshNode

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.meshNode = meshNode
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var arView: ARSCNView?
        var meshNode: SCNNode?
        var placedNode: SCNNode?

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
                    placeMesh(at: firstResult)
                }
            }
        }

        func placeMesh(at raycastResult: ARRaycastResult) {
            guard let arView = arView else { return }

            // Remove existing placed mesh
            placedNode?.removeFromParentNode()

            // Clone the mesh node
            guard let originalNode = meshNode else {
                print("AR: No mesh node available")
                return
            }

            let clonedNode = originalNode.clone()
            clonedNode.isHidden = false

            // Scale down for AR (meshes are usually large)
            clonedNode.scale = SCNVector3(0.5, 0.5, 0.5)

            // Position at raycast hit point
            let transform = raycastResult.worldTransform
            clonedNode.position = SCNVector3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            // Add rotation animation
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10)
            let repeatRotation = SCNAction.repeatForever(rotation)
            clonedNode.runAction(repeatRotation)

            arView.scene.rootNode.addChildNode(clonedNode)
            placedNode = clonedNode

            // Hide instruction label
            if let label = arView.viewWithTag(100) {
                UIView.animate(withDuration: 0.3) {
                    label.alpha = 0
                }
            }

            print("AR: Placed mesh at \(clonedNode.position)")
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
    let meshNode: SCNNode?
    @Binding var isPresented: Bool

    var body: some View {
        ARViewContainer(meshNode: meshNode, isPresented: $isPresented)
            .ignoresSafeArea()
    }
}
