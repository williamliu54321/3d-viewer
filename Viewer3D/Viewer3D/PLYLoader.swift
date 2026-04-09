import SceneKit
import Foundation

class PLYLoader {

    static func loadPLY(from url: URL) -> SCNNode? {
        guard let data = try? Data(contentsOf: url) else {
            print("PLYLoader: Failed to read file")
            return nil
        }

        // Find end of header
        guard let headerEnd = findHeaderEnd(in: data) else {
            print("PLYLoader: Could not find header end")
            return nil
        }

        // Parse header
        let headerData = data.subdata(in: 0..<headerEnd)
        guard let headerString = String(data: headerData, encoding: .ascii) else {
            print("PLYLoader: Could not parse header")
            return nil
        }

        let lines = headerString.components(separatedBy: .newlines)
        var vertexCount = 0
        var faceCount = 0
        var isBinary = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("binary_little_endian") {
                isBinary = true
            } else if trimmed.starts(with: "element vertex") {
                vertexCount = Int(trimmed.components(separatedBy: " ").last ?? "0") ?? 0
            } else if trimmed.starts(with: "element face") {
                faceCount = Int(trimmed.components(separatedBy: " ").last ?? "0") ?? 0
            }
        }

        print("PLYLoader: vertices=\(vertexCount), faces=\(faceCount), binary=\(isBinary)")

        guard isBinary else {
            print("PLYLoader: Only binary PLY supported")
            return nil
        }

        // Parse binary data
        // Vertex format: float x, float y, float z, uchar r, uchar g, uchar b, uchar a (16 bytes)
        let vertexSize = 16 // 3 floats (12) + 4 uchars (4)
        let dataStart = headerEnd + 1 // Skip newline after end_header

        var positions: [SCNVector3] = []
        var colors: [SCNVector3] = []
        positions.reserveCapacity(vertexCount)
        colors.reserveCapacity(vertexCount)

        // Calculate bounds for centering
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude

        // First pass: read vertices and find bounds
        var offset = dataStart
        for _ in 0..<vertexCount {
            guard offset + vertexSize <= data.count else { break }

            let x = readFloat(from: data, at: offset)
            let y = readFloat(from: data, at: offset + 4)
            let z = readFloat(from: data, at: offset + 8)
            let r = data[offset + 12]
            let g = data[offset + 13]
            let b = data[offset + 14]

            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
            minZ = min(minZ, z); maxZ = max(maxZ, z)

            positions.append(SCNVector3(x, y, z))
            colors.append(SCNVector3(Float(r) / 255.0, Float(g) / 255.0, Float(b) / 255.0))

            offset += vertexSize
        }

        // Center the mesh
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let centerZ = (minZ + maxZ) / 2

        for i in 0..<positions.count {
            positions[i].x -= centerX
            positions[i].y -= centerY
            positions[i].z -= centerZ
        }

        // Parse faces
        // Face format: uchar count, int idx0, int idx1, int idx2 (1 + 3*4 = 13 bytes for triangles)
        var indices: [Int32] = []
        indices.reserveCapacity(faceCount * 3)

        for _ in 0..<faceCount {
            guard offset + 1 <= data.count else { break }

            let count = data[offset]
            offset += 1

            guard offset + Int(count) * 4 <= data.count else { break }

            for _ in 0..<count {
                let idx = readInt32(from: data, at: offset)
                indices.append(idx)
                offset += 4
            }
        }

        print("PLYLoader: Parsed \(positions.count) vertices, \(indices.count / 3) faces")

        // Calculate smooth normals
        var normals = [SCNVector3](repeating: SCNVector3(0, 0, 0), count: positions.count)

        // Accumulate face normals for each vertex
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])

            guard i0 < positions.count && i1 < positions.count && i2 < positions.count else { continue }

            let v0 = positions[i0]
            let v1 = positions[i1]
            let v2 = positions[i2]

            // Calculate face normal using cross product
            let edge1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
            let edge2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)

            let faceNormal = SCNVector3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            )

            // Add face normal to each vertex of the triangle
            normals[i0] = SCNVector3(normals[i0].x + faceNormal.x, normals[i0].y + faceNormal.y, normals[i0].z + faceNormal.z)
            normals[i1] = SCNVector3(normals[i1].x + faceNormal.x, normals[i1].y + faceNormal.y, normals[i1].z + faceNormal.z)
            normals[i2] = SCNVector3(normals[i2].x + faceNormal.x, normals[i2].y + faceNormal.y, normals[i2].z + faceNormal.z)
        }

        // Normalize all vertex normals
        for i in 0..<normals.count {
            let n = normals[i]
            let length = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
            if length > 0 {
                normals[i] = SCNVector3(n.x / length, n.y / length, n.z / length)
            }
        }

        // Create geometry
        let positionSource = SCNGeometrySource(vertices: positions)
        let normalSource = SCNGeometrySource(normals: normals)

        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.stride)
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.stride
        )

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [positionSource, normalSource, colorSource], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor.white
        material.roughness.contents = 0.6
        material.metalness.contents = 0.0
        material.isDoubleSided = true
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.castsShadow = true
        return node
    }

    private static func findHeaderEnd(in data: Data) -> Int? {
        let endHeader = "end_header".data(using: .ascii)!
        if let range = data.range(of: endHeader) {
            return range.upperBound
        }
        return nil
    }

    // Safe unaligned binary reading helpers
    private static func readFloat(from data: Data, at offset: Int) -> Float {
        var value: Float = 0
        _ = withUnsafeMutableBytes(of: &value) { dest in
            data.copyBytes(to: dest, from: offset..<offset+4)
        }
        return value
    }

    private static func readInt32(from data: Data, at offset: Int) -> Int32 {
        var value: Int32 = 0
        _ = withUnsafeMutableBytes(of: &value) { dest in
            data.copyBytes(to: dest, from: offset..<offset+4)
        }
        return value
    }
}
