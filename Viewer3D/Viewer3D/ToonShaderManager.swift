import SceneKit

enum ToonStyle {
    case animeSkin      // Soft anime skin shader
    case gameStylized   // Genshin/Zelda style
    case celShaded2Band // Hard 2-band cel shading
    case celShaded3Band // 3-band cel shading
    case comic          // Comic book style with outlines
}

class ToonShaderManager {
    static let shared = ToonShaderManager()

    private init() {}

    func applyToonShader(to node: SCNNode, style: ToonStyle) {
        guard let geometry = node.geometry else { return }

        // Remove any existing outline nodes
        node.childNodes.filter { $0.name == "outline" }.forEach { $0.removeFromParentNode() }

        switch style {
        case .animeSkin:
            applyAnimeSkinShader(to: geometry)
        case .gameStylized:
            applyGameStylizedShader(to: geometry)
        case .celShaded2Band:
            applyCelShader(to: geometry, bands: 2)
        case .celShaded3Band:
            applyCelShader(to: geometry, bands: 3)
        case .comic:
            applyComicShader(to: node)
        }
    }

    // MARK: - Anime Skin Shader
    private func applyAnimeSkinShader(to geometry: SCNGeometry) {
        let material = SCNMaterial()
        material.lightingModel = .phong

        // Soft anime skin colors
        material.diffuse.contents = UIColor(red: 1.0, green: 0.92, blue: 0.87, alpha: 1.0)
        material.specular.contents = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 0.4)
        material.shininess = 0.08

        // Shader modifier for anime-style shading
        let fragmentShader = """
        #pragma transparent
        #pragma body

        // Get lighting info
        float3 lightDir = normalize(float3(0.3, 1.0, 0.5));
        float NdotL = dot(_surface.normal, lightDir);

        // Soft 3-band cel shading
        float3 skinBase = float3(1.0, 0.9, 0.85);
        float3 skinShadow = float3(0.92, 0.72, 0.68);
        float3 skinHighlight = float3(1.0, 0.96, 0.94);

        float3 color;
        if (NdotL > 0.4) {
            float t = smoothstep(0.4, 0.8, NdotL);
            color = mix(skinBase, skinHighlight, t * 0.6);
        } else if (NdotL > -0.1) {
            color = skinBase;
        } else {
            color = skinShadow;
        }

        // Rim light
        float rim = 1.0 - max(dot(_surface.normal, _surface.view), 0.0);
        rim = pow(rim, 2.5);
        color += float3(1.0, 0.92, 0.88) * rim * 0.35;

        _output.color.rgb = color;
        """

        material.shaderModifiers = [.fragment: fragmentShader]
        material.isDoubleSided = true
        geometry.materials = [material]
    }

    // MARK: - Game Stylized Shader (Genshin/Zelda style)
    private func applyGameStylizedShader(to geometry: SCNGeometry) {
        let material = SCNMaterial()
        material.lightingModel = .phong

        material.diffuse.contents = UIColor(red: 1.0, green: 0.88, blue: 0.82, alpha: 1.0)
        material.specular.contents = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 0.5)
        material.shininess = 0.12

        let fragmentShader = """
        #pragma transparent
        #pragma body

        float3 lightDir = normalize(float3(0.4, 0.9, 0.3));
        float NdotL = dot(_surface.normal, lightDir);

        // Game-style colors
        float3 baseColor = float3(1.0, 0.88, 0.82);
        float3 shadowColor = float3(0.82, 0.62, 0.58);
        float3 highlightColor = float3(1.0, 0.98, 0.95);

        // Smoother cel shading
        float shade = smoothstep(-0.15, 0.35, NdotL);
        float3 color = mix(shadowColor, baseColor, shade);

        // Highlight
        float highlight = smoothstep(0.55, 0.85, NdotL);
        color = mix(color, highlightColor, highlight * 0.5);

        // Strong rim light (characteristic of these games)
        float rim = 1.0 - max(dot(_surface.normal, _surface.view), 0.0);
        rim = pow(rim, 1.8);
        color += float3(0.85, 0.88, 1.0) * rim * 0.45;

        _output.color.rgb = color;
        """

        material.shaderModifiers = [.fragment: fragmentShader]
        material.isDoubleSided = true
        geometry.materials = [material]
    }

    // MARK: - Cel Shader (hard bands)
    private func applyCelShader(to geometry: SCNGeometry, bands: Int) {
        let material = SCNMaterial()
        material.lightingModel = .phong

        material.diffuse.contents = UIColor(red: 1.0, green: 0.88, blue: 0.8, alpha: 1.0)
        material.specular.contents = UIColor.white.withAlphaComponent(0.2)
        material.shininess = 0.05

        let fragmentShader: String
        if bands == 2 {
            fragmentShader = """
            #pragma transparent
            #pragma body

            float3 lightDir = normalize(float3(0.5, 1.0, 0.3));
            float NdotL = dot(_surface.normal, lightDir);

            // Hard 2-band cel shading
            float3 litColor = float3(1.0, 0.9, 0.85);
            float3 shadowColor = float3(0.7, 0.55, 0.52);

            float3 color = NdotL > 0.0 ? litColor : shadowColor;

            // Subtle rim
            float rim = 1.0 - max(dot(_surface.normal, _surface.view), 0.0);
            rim = pow(rim, 3.0);
            color += float3(1.0, 0.95, 0.9) * rim * 0.25;

            _output.color.rgb = color;
            """
        } else {
            fragmentShader = """
            #pragma transparent
            #pragma body

            float3 lightDir = normalize(float3(0.5, 1.0, 0.3));
            float NdotL = dot(_surface.normal, lightDir);

            // 3-band cel shading
            float3 highlightColor = float3(1.0, 0.98, 0.95);
            float3 midColor = float3(1.0, 0.88, 0.82);
            float3 shadowColor = float3(0.72, 0.55, 0.52);

            float3 color;
            if (NdotL > 0.5) {
                color = highlightColor;
            } else if (NdotL > -0.1) {
                color = midColor;
            } else {
                color = shadowColor;
            }

            // Rim light
            float rim = 1.0 - max(dot(_surface.normal, _surface.view), 0.0);
            rim = pow(rim, 2.5);
            color += float3(1.0, 0.95, 0.92) * rim * 0.3;

            _output.color.rgb = color;
            """
        }

        material.shaderModifiers = [.fragment: fragmentShader]
        material.isDoubleSided = true
        geometry.materials = [material]
    }

    // MARK: - Comic Style (with outline)
    private func applyComicShader(to node: SCNNode) {
        guard let geometry = node.geometry else { return }

        // Apply 2-band cel shading to main mesh
        applyCelShader(to: geometry, bands: 2)

        // Create outline effect using a scaled inverted copy
        if let outlineGeometry = geometry.copy() as? SCNGeometry {
            let outlineMaterial = SCNMaterial()
            outlineMaterial.lightingModel = .constant
            outlineMaterial.diffuse.contents = UIColor.black
            outlineMaterial.isDoubleSided = false
            outlineMaterial.cullMode = .front  // Only show back faces (inverted)
            outlineGeometry.materials = [outlineMaterial]

            let outlineNode = SCNNode(geometry: outlineGeometry)
            outlineNode.scale = SCNVector3(1.025, 1.025, 1.025)  // Slightly larger
            outlineNode.name = "outline"
            node.addChildNode(outlineNode)
        }
    }

    // MARK: - Remove toon shader
    func removeToonShader(from node: SCNNode) {
        // Remove outline nodes
        node.childNodes.filter { $0.name == "outline" }.forEach { $0.removeFromParentNode() }

        // Reset to default material
        if let geometry = node.geometry {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = UIColor.white
            material.roughness.contents = 0.6
            material.metalness.contents = 0.0
            material.isDoubleSided = true
            geometry.materials = [material]
        }
    }
}
