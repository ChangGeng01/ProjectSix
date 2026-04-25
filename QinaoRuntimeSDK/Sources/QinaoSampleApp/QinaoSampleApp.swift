import SwiftUI
import QinaoLoop
import QinaoAppleFoundation
import QinaoMLX

/// SwiftUI demo for the Qinao Runtime SDK.
///
/// `swift run QinaoSampleApp` opens a window with a provider
/// picker, prompt input, run/stream pair of buttons, and a
/// response/audit panel. Same `QinaoLoop` API surface as
/// `QinaoSampleHost` (M203) — just visible instead of CLI-only.
///
/// Wired providers (M222):
///   * Apple Foundation Models — Apple Intelligence on macOS 26+
///   * Gemma 3 4B (MLX, 4-bit) — open-weights, downloaded on first
///     use to ~3 GB local cache
///   * Gemma 3n E4B (MLX, 4-bit) — recommended default; MatFormer
///     architecture, faster + lower memory than Gemma 3 4B
///   * Gemma 3n E2B (MLX, 4-bit) — smallest variant, ~1.4 GB
///
/// API providers (OpenAI-compatible) and other roadmap entries
/// surface as a non-selectable picker hint until M223+.
@main
struct QinaoSampleApp: App {
    var body: some Scene {
        WindowGroup("Qinao Sample") {
            ContentView()
                .frame(minWidth: 600, idealWidth: 760,
                       minHeight: 460, idealHeight: 600)
        }
        #if canImport(AppKit)
        .windowResizability(.contentSize)
        #endif
    }
}

/// Provider picker entries. Wired entries call into the matching
/// Qinao factory; the API entry remains a placeholder until the
/// `BASChatCompletionsAdapter` consumer surface is M222-grade.
enum SampleProvider: String, CaseIterable, Identifiable {
    case appleFoundation = "Apple Foundation Models"
    case mlxGemma3_4B = "Gemma 3 4B (MLX, 4-bit)"
    case mlxGemma3nE4B = "Gemma 3n E4B (MLX, 4-bit)"
    case mlxGemma3nE2B = "Gemma 3n E2B (MLX, 4-bit)"
    case chatCompletions = "OpenAI-compatible API (M223)"

    var id: String { rawValue }

    var isAvailable: Bool {
        self != .chatCompletions
    }

    /// Map picker entries to MLX model identity. `nil` for non-MLX
    /// entries; the caller branches on this before invoking the
    /// MLX factory.
    var mlxModel: QinaoMLXModel? {
        switch self {
        case .mlxGemma3_4B: return .gemma3_4B
        case .mlxGemma3nE4B: return .gemma3nE4B
        case .mlxGemma3nE2B: return .gemma3nE2B
        default: return nil
        }
    }
}

/// Cached endpoints per provider. MLX endpoints take seconds to
/// minutes on first load (download + on-device weight load);
/// reusing the loaded endpoint avoids paying that cost on every
/// prompt.
@MainActor
final class SampleSession: ObservableObject {
    @Published var status: String = "ready"
    @Published var loadingMessage: String = ""
    @Published var loadingProgress: Double = 0
    @Published var isLoading: Bool = false

    private var cachedAppleEndpoint: (any QinaoOrganEndpoint)?
    private var cachedMLX: (
        model: QinaoMLXModel,
        endpoint: any QinaoOrganEndpoint
    )?

    /// Lazily build (or fetch from cache) the endpoint for the
    /// selected provider. Throws if the provider is not yet wired.
    func endpoint(
        for provider: SampleProvider
    ) async throws -> any QinaoOrganEndpoint {
        switch provider {
        case .appleFoundation:
            if let cached = cachedAppleEndpoint { return cached }
            let endpoint = await QinaoLoop
                .makeAppleFoundationEndpoint()
            cachedAppleEndpoint = endpoint
            return endpoint

        case .mlxGemma3_4B,
             .mlxGemma3nE4B,
             .mlxGemma3nE2B:
            guard let model = provider.mlxModel else {
                throw SampleError.providerNotWired(provider.rawValue)
            }
            if let cached = cachedMLX, cached.model == model {
                return cached.endpoint
            }
            isLoading = true
            loadingMessage = "Downloading \(model.displayName)…"
            loadingProgress = 0
            defer {
                isLoading = false
                loadingMessage = ""
                loadingProgress = 0
            }
            let endpoint = try await QinaoLoop.makeMLXEndpoint(
                model: model,
                progressHandler: { progress in
                    let frac = progress.fractionCompleted
                    Task { @MainActor [weak self] in
                        self?.loadingProgress = frac
                    }
                })
            cachedMLX = (model, endpoint)
            return endpoint

        case .chatCompletions:
            throw SampleError.providerNotWired(provider.rawValue)
        }
    }
}

enum SampleError: LocalizedError {
    case providerNotWired(String)

    var errorDescription: String? {
        switch self {
        case .providerNotWired(let name):
            return "provider not yet wired: \(name)"
        }
    }
}

@MainActor
struct ContentView: View {
    @StateObject private var session = SampleSession()
    @State private var prompt: String =
        "Reply with one short sentence about a calming evening habit."
    @State private var response: String = ""
    @State private var provider: SampleProvider = .appleFoundation
    @State private var traceID: String = "—"
    @State private var latencyMs: Double = 0
    @State private var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            providerRow
            if session.isLoading {
                loadingPanel
            }
            promptPanel
            Divider()
            responsePanel
            statusBar
        }
        .padding(20)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Qinao Sample")
                .font(.title)
                .fontWeight(.semibold)
            Spacer()
            Text("Three invariants enforced inside QinaoLoop.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var providerRow: some View {
        HStack(spacing: 12) {
            Text("Provider")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Provider", selection: $provider) {
                ForEach(SampleProvider.allCases) { entry in
                    Text(entry.rawValue)
                        .tag(entry)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
            if !provider.isAvailable {
                Text("not yet wired — pick another provider")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
    }

    private var loadingPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.loadingMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: session.loadingProgress)
                .progressViewStyle(.linear)
        }
    }

    // MARK: - Prompt panel

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: $prompt)
                .font(.body.monospaced())
                .frame(minHeight: 100, maxHeight: 140)
                .padding(8)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 12) {
                Button {
                    Task { await runRequest(streaming: false) }
                } label: {
                    Label("Send", systemImage: "paperplane")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(
                    isRunning || prompt.isEmpty
                        || !provider.isAvailable
                        || session.isLoading)

                Button {
                    Task { await runRequest(streaming: true) }
                } label: {
                    Label("Stream", systemImage: "waveform")
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(
                    isRunning || prompt.isEmpty
                        || !provider.isAvailable
                        || session.isLoading)

                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }
        }
    }

    // MARK: - Response panel

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(response.isEmpty ? "—" : response)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(minHeight: 120, maxHeight: .infinity)
            .background(.quaternary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            Label(session.status, systemImage: statusIcon)
                .font(.caption)
                .foregroundStyle(.primary)
            Text("trace: \(traceID)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(String(format: "latency: %.0f ms", latencyMs))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var statusIcon: String {
        if isRunning { return "circle.dotted" }
        if session.status == "ready"
            || session.status.hasPrefix("ok")
        {
            return "checkmark.circle"
        }
        return "exclamationmark.triangle"
    }

    // MARK: - Run

    private func runRequest(streaming: Bool) async {
        isRunning = true
        response = ""
        session.status = streaming ? "streaming…" : "running…"
        let started = Date()
        let sessionStr = sessionID()
        traceID = sessionStr

        do {
            let endpoint = try await session.endpoint(for: provider)
            let loop = QinaoLoop(organEndpoint: endpoint)

            if streaming {
                let stream = loop.streamBody(
                    sessionID: sessionStr,
                    prompt: prompt,
                    role: .core)
                var lastProvider = "—"
                for try await chunk in stream {
                    response = chunk.cumulativeBody
                    lastProvider = chunk.providerID
                }
                finish(provider: lastProvider,
                       trace: sessionStr,
                       elapsed: started,
                       success: true)
            } else {
                let seed = QinaoLoop.CandidateSeed(
                    candidateID: "demo",
                    title: "demo",
                    prompt: prompt,
                    role: .core,
                    expectedBenefit: 0.7,
                    expectedCost: 0.2,
                    reversibility: 0.9,
                    confidence: 0.8)
                let drafts = try await loop.generateCandidates(
                    sessionID: sessionStr,
                    seeds: [seed])
                if let draft = drafts.first {
                    response = draft.body
                    finish(provider: draft.providerID,
                           trace: String(draft.traceID.prefix(16)),
                           elapsed: started,
                           success: true)
                } else {
                    response = "(no candidate produced)"
                    finish(provider: "—",
                           trace: sessionStr,
                           elapsed: started,
                           success: false)
                }
            }
        } catch {
            response = "error: \(error)"
            finishError(error)
        }
        isRunning = false
    }

    private func finish(
        provider: String,
        trace: String,
        elapsed: Date,
        success: Bool
    ) {
        traceID = trace
        latencyMs = elapsedMs(elapsed)
        session.status = success
            ? "ok · \(provider)"
            : "fail · \(provider)"
    }

    private func finishError(_ error: Error) {
        latencyMs = 0
        session.status = "error: \(error)"
    }

    private func sessionID() -> String {
        "sample-\(Int(Date().timeIntervalSince1970))"
    }

    private func elapsedMs(_ start: Date) -> Double {
        Date().timeIntervalSince(start) * 1000
    }
}
