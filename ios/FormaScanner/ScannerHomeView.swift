import SwiftUI
import RealityKit

struct ScannerHomeView: View {
    @State private var isPresentingCapture = false
    @State private var isPresentingSettings = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "viewfinder.rectangular").font(.system(size: 42, weight: .light)).foregroundStyle(.blue)
                Text("Gerçek ölçüde\nürün taraması").font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Text("Forma Scanner, iPhone’unuzdaki Object Capture ve LiDAR verileriyle metre ölçeğini koruyan bir tarama paketi oluşturur.").foregroundStyle(.secondary)
                Divider()
                Label("Tarama sırasında kareler otomatik toplanır.", systemImage: "checkmark.circle")
                Label("Model yayınlanmadan önce ölçüler doğrulanır.", systemImage: "ruler")
                if ObjectCaptureSession.isSupported {
                    Button("Taramayı başlat") { isPresentingCapture = true }.buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    ContentUnavailableView("Bu cihaz desteklenmiyor", systemImage: "iphone.slash", description: Text("Gerçek ölçülü tarama için LiDAR, A14 veya sonrası işlemci ve iOS 18 gerekir."))
                }
                Spacer()
            }
            .padding(28).navigationTitle("Forma Scanner")
            .toolbar { Button { isPresentingSettings = true } label: { Image(systemName: "gearshape") } }
            .fullScreenCover(isPresented: $isPresentingCapture) { NativeCaptureFlow() }
            .sheet(isPresented: $isPresentingSettings) { SettingsView() }
        }
    }
}

@available(iOS 18.0, *)
private struct NativeCaptureFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session = ObjectCaptureSession()
    @StateObject private var upload = ScanUploadCoordinator()
    @State private var captureDirectory: URL?
    @State private var isFinishing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ObjectCaptureView(session: session).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(statusText).font(.footnote.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule())
                if case let .uploading(completed, total) = upload.state {
                    ProgressView("Tarama paketi yükleniyor \(completed)/\(total)", value: Double(completed), total: Double(max(total, 1))).tint(.white).foregroundStyle(.white).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                HStack {
                    Button("İptal", role: .cancel) { session.cancel(); dismiss() }
                    Spacer()
                    Button(primaryButtonTitle) { primaryAction() }.buttonStyle(.borderedProminent).disabled(isFinishing)
                }
            }.padding()
        }
        .task { start() }
        .alert("Tarama başlatılamadı", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("Tamam") { dismiss() } } message: { Text(errorMessage ?? "Bilinmeyen hata") }
        .onChange(of: upload.state) { _, newValue in
            if case .queued = newValue { dismiss() }
            if case let .failed(message) = newValue { errorMessage = message }
        }
    }

    private var statusText: String {
        if isFinishing { return "Tarama paketi hazırlanıyor" }
        switch session.state {
        case .capturing: return "Ürünün çevresinde yavaşça dolaşın"
        case .detecting: return "Ürünü kadraja alın"
        default: return "Tarama hazırlanıyor"
        }
    }

    private var primaryButtonTitle: String {
        switch upload.state {
        case .idle: return isFinishing ? "Hazırlanıyor…" : "Taramayı bitir"
        case .preparing: return "Paket hazırlanıyor…"
        case .uploading: return "Yükleniyor…"
        case .queued: return "Kuyruğa alındı"
        case .failed: return "Tekrar dene"
        }
    }

    private func start() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "forma-scan-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            captureDirectory = directory
            session.start(imagesDirectory: directory, configuration: .init())
            session.startDetecting()
            session.startCapturing()
        } catch { errorMessage = error.localizedDescription }
    }

    private func primaryAction() {
        if case .failed = upload.state, let directory = captureDirectory { Task { await upload.submit(captureDirectory: directory) }; return }
        guard !isFinishing else { return }
        isFinishing = true
        session.finish()
        Task {
            while session.state != .completed { try? await Task.sleep(for: .milliseconds(350)) }
            guard let directory = captureDirectory else { return }
            await upload.submit(captureDirectory: directory)
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = AppConfiguration.apiBaseURL?.absoluteString ?? ""
    @State private var token = AppConfiguration.bearerToken ?? ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Bağlantı") {
                    TextField("https://api.forma.example", text: $endpoint).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                    SecureField("İşletme erişim anahtarı", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section { Text("Anahtar yalnızca cihazın Keychain alanında tutulur. Uygulama kaynağına veya Git’e yazılmaz.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Bağlantı ayarları")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } } }
            .alert("Ayarlar kaydedilemedi", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Tamam", role: .cancel) {} } message: { Text(error ?? "") }
        }
    }

    private func save() {
        guard let url = URL(string: endpoint), url.scheme == "https" else { error = "API adresi HTTPS olmalıdır."; return }
        do { AppConfiguration.save(baseURL: url); try AppConfiguration.save(bearerToken: token); dismiss() } catch { self.error = error.localizedDescription }
    }
}
