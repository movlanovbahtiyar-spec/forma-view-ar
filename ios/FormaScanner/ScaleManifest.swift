import Foundation
import simd

/// The payload attached to a completed scan. All linear values are metres;
/// this invariant prevents a GLB/USDZ consumer from silently applying a scale.
struct ScaleManifest: Codable {
    let schemaVersion = 1
    let unit = "meter"
    let captureID: UUID
    let deviceModel: String
    let hasLiDAR: Bool
    let scaleSource: ScaleSource
    let confidence: Float
    let dimensionsMeters: Dimensions?

    enum ScaleSource: String, Codable { case lidar, referenceCard, operatorVerified }
    struct Dimensions: Codable { let width: Float; let height: Float; let depth: Float }
}
