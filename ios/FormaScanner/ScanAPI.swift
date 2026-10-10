import Foundation
import UniformTypeIdentifiers

struct CaptureAsset: Codable, Identifiable {
    let id: String
    let relativePath: String
    let contentType: String
    let byteCount: Int64
}

struct CreateScanRequest: Codable {
    let manifest: ScaleManifest
    let assets: [CaptureAsset]
}

struct CreateScanResponse: Codable {
    let scanID: UUID
    let uploads: [UploadTarget]
}

struct UploadTarget: Codable, Identifiable {
    let id: String
    let relativePath: String
    let url: URL
    let headers: [String: String]
}

struct ScanStatus: Codable {
    enum Phase: String, Codable { case uploading, queued, reconstructing, validating, published, needsReview, failed }
    let id: UUID
    let phase: Phase
    let progress: Double
    let dimensionsMeters: ScaleManifest.Dimensions?
    let message: String?
}

enum ScanAPIError: LocalizedError {
    case missingConfiguration
    case malformedResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: return "Önce Ayarlar’dan güvenli API adresi ve erişim anahtarı ekleyin."
        case .malformedResponse: return "Sunucudan geçersiz yanıt geldi."
        case let .server(status, message): return "Sunucu hatası (\(status)): \(message)"
        }
    }
}

struct ScanAPI {
    private let session: URLSession = .shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func createScan(_ payload: CreateScanRequest) async throws -> CreateScanResponse {
        try await request("v1/scans", method: "POST", body: payload)
    }

    func completeScan(_ scanID: UUID) async throws -> ScanStatus {
        try await request("v1/scans/\(scanID.uuidString)/complete", method: "POST", body: EmptyBody())
    }

    func status(_ scanID: UUID) async throws -> ScanStatus {
        try await request("v1/scans/\(scanID.uuidString)", method: "GET", body: Optional<EmptyBody>.none)
    }

    func upload(_ file: URL, to target: UploadTarget) async throws {
        var request = URLRequest(url: target.url)
        request.httpMethod = "PUT"
        for (field, value) in target.headers { request.setValue(value, forHTTPHeaderField: field) }
        let (_, response) = try await session.upload(for: request, fromFile: file)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ScanAPIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Tarama dosyası yüklenemedi.") }
    }

    private func request<Body: Encodable, Response: Decodable>(_ path: String, method: String, body: Body?) async throws -> Response {
        guard let baseURL = AppConfiguration.apiBaseURL, let token = AppConfiguration.bearerToken else { throw ScanAPIError.missingConfiguration }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try encoder.encode(body) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ScanAPIError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw ScanAPIError.server(status: http.statusCode, message: String(decoding: data, as: UTF8.self)) }
        guard let decoded = try? decoder.decode(Response.self, from: data) else { throw ScanAPIError.malformedResponse }
        return decoded
    }

    private struct EmptyBody: Codable {}
}

enum CaptureAssetInventory {
    static func assets(in directory: URL) throws -> [CaptureAsset] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentTypeKey]
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { return nil }
            let contentType = values.contentType?.preferredMIMEType ?? "application/octet-stream"
            return CaptureAsset(id: url.lastPathComponent, relativePath: url.lastPathComponent, contentType: contentType, byteCount: Int64(values.fileSize ?? 0))
        }.sorted { $0.relativePath < $1.relativePath }
    }
}
