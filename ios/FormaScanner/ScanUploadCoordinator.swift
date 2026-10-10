import Foundation
import UIKit

@MainActor
final class ScanUploadCoordinator: ObservableObject {
    enum State: Equatable { case idle, preparing, uploading(completed: Int, total: Int), queued(UUID), failed(String) }
    @Published private(set) var state: State = .idle

    private let api = ScanAPI()

    func submit(captureDirectory: URL, scaleSource: ScaleManifest.ScaleSource = .lidar) async {
        state = .preparing
        do {
            let assets = try CaptureAssetInventory.assets(in: captureDirectory)
            guard assets.count >= 12 else { throw SubmissionError.notEnoughImages }
            let manifest = ScaleManifest(captureID: UUID(), deviceModel: UIDevice.current.model, hasLiDAR: scaleSource == .lidar, scaleSource: scaleSource, confidence: scaleSource == .lidar ? 0.9 : 0.75, dimensionsMeters: nil)
            let plan = try await api.createScan(CreateScanRequest(manifest: manifest, assets: assets))
            state = .uploading(completed: 0, total: plan.uploads.count)
            for (index, target) in plan.uploads.enumerated() {
                let file = captureDirectory.appending(path: target.relativePath)
                try await api.upload(file, to: target)
                state = .uploading(completed: index + 1, total: plan.uploads.count)
            }
            _ = try await api.completeScan(plan.scanID)
            state = .queued(plan.scanID)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    enum SubmissionError: LocalizedError { case notEnoughImages
        var errorDescription: String? { "Tarama yeterli sayıda kare üretmedi. Ürünün çevresinde bir tur daha atın." }
    }
}
