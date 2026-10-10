import SwiftUI
import RealityKit

/// Native capture is intentionally separate from the web panel. Safari can open a
/// camera, but it cannot provide the calibrated ARKit depth, pose, and confidence
/// data that the reconstruction pipeline needs for metric scale.
struct ScannerHomeView: View {
    @State private var isPresentingCapture = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "viewfinder.rectangular")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.blue)
                Text("Gerçek ölçüde ürün taraması")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Text("Forma Scanner, iPhone’unuzdaki Object Capture ve LiDAR verilerini kullanarak ürünün tarama paketini metre biriminde hazırlar.")
                    .foregroundStyle(.secondary)
                if ObjectCaptureSession.isSupported {
                    Button("Taramayı başlat") { isPresentingCapture = true }
                        .buttonStyle(.borderedProminent)
                } else {
                    ContentUnavailableView("Bu cihaz desteklenmiyor", systemImage: "iphone.slash", description: Text("Gerçek ölçülü tarama için LiDAR, A14 veya sonrası işlemci ve iOS 18 gerekir. Ölçü kartı akışını kullanın."))
                }
                Spacer()
            }
            .padding(28)
            .navigationTitle("Forma Scanner")
            .fullScreenCover(isPresented: $isPresentingCapture) {
                NativeCaptureFlow()
            }
        }
    }
}

@available(iOS 18.0, *)
private struct NativeCaptureFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session = ObjectCaptureSession()
    @State private var archiveURL: URL?
    @State private var isFinishing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ObjectCaptureView(session: session)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Text(statusText).font(.footnote.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule())
                HStack {
                    Button("İptal", role: .cancel) { session.cancel(); dismiss() }
                    Spacer()
                    Button(isFinishing ? "Kaydediliyor…" : "Taramayı bitir") { finish() }
                        .buttonStyle(.borderedProminent).disabled(isFinishing)
                }
            }
            .padding()
        }
        .task { start() }
        .alert("Tarama başlatılamadı", isPresented: .constant(errorMessage != nil)) { Button("Tamam") { dismiss() } } message: { Text(errorMessage ?? "Bilinmeyen hata") }
    }

    private var statusText: String {
        switch session.state {
        case .capturing: return "Ürünün çevresinde yavaşça dolaşın"
        case .detecting: return "Ürünü kadraja alın"
        default: return "Tarama hazırlanıyor"
        }
    }

    private func start() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "forma-scan-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            archiveURL = directory
            session.start(imagesDirectory: directory, configuration: .init())
            session.startDetecting()
            session.startCapturing()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        isFinishing = true
        session.finish()
        // In production, observe session.state until .completed, then upload the
        // capture directory plus ScaleManifest to POST /v1/scans. Do not upload
        // from this callback until the ObjectCapture session has completed.
    }
}
