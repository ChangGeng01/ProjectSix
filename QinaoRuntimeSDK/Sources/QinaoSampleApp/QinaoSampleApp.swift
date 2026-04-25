import SwiftUI
import QinaoLoop
import QinaoAppleFoundation

/// M219 — minimal SwiftUI demo for the Qinao Runtime SDK.
///
/// `swift run QinaoSampleApp` opens a window with a prompt input, a
/// run/stream pair of buttons, and a response/audit panel. The same
/// `QinaoLoop` API surface as `QinaoSampleHost` (M203) — just visible
/// instead of CLI-only. Today the only wired provider is Apple
/// Foundation Models. The provider picker shows the planned MLX /
/// Gemma + ChatCompletions entries so the next milestones (M220+)
/// have a clear UI seat to fill in.
@main
struct QinaoSampleApp: App {
    var body: some Scene {
        WindowGroup("Qinao Sample") {
            ContentView()
                .frame(minWidth: 560, idealWidth: 720,
                       minHeight: 420, idealHeight: 560)
        }
        #if canImport(AppKit)
        .windowResizability(.contentSize)
        #endif
    }
}

/// Provider picker entries. Only `.appleFoundation` is wired today;
/// the rest are visible-but-disabled placeholders that document the
/// roadmap without lying about what runs.
enum SampleProvider: String, CaseIterable, Identifiable {
    case appleFoundation = "Apple Foundation Models"
    case mlxGemma3 = "Gemma 3 4B (MLX, M220)"
    case mlxGemma3n = "Gemma 3n e4b (MLX, M220)"
    case chatCompletions = "OpenAI-compatible API (M221)"

    var id: String { rawValue }

    var isAvailable: Bool {
        self == .appleFoundation
    }
}

@MainActor
struct ContentView: View {
    @State private var prompt: String =
        "Reply with one short sentence about a calming evening habit."
    @State private var response: String = ""
    @State private var status: String = "ready"
    @State private var provider: SampleProvider = .appleFoundation
    @State private var traceID: String = "—"
    @State private var latencyMs: Double = 0
    @State private var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            providerRow
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
                Text("not yet wired — falls back to Apple FM")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
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
                .disabled(isRunning || prompt.isEmpty)

                Button {
                    Task { await runRequest(streaming: true) }
                } label: {
                    Label("Stream", systemImage: "waveform")
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(isRunning || prompt.isEmpty)

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
            Label(status, systemImage: statusIcon)
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
        if status == "ready" || status.hasPrefix("ok") {
            return "checkmark.circle"
        }
        return "exclamationmark.triangle"
    }

    // MARK: - Run

    private func runRequest(streaming: Bool) async {
        isRunning = true
        response = ""
        status = streaming ? "streaming…" : "running…"
        let started = Date()
        let session = sessionID()
        traceID = session

        do {
            let endpoint = await QinaoLoop
                .makeAppleFoundationEndpoint()
            let loop = QinaoLoop(organEndpoint: endpoint)

            if streaming {
                let stream = loop.streamBody(
                    sessionID: session,
                    prompt: prompt,
                    role: .core)
                var lastProvider = "apple-fm"
                for try await chunk in stream {
                    response = chunk.cumulativeBody
                    lastProvider = chunk.providerID
                }
                finish(provider: lastProvider,
                       trace: session,
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
                    sessionID: session,
                    seeds: [seed])
                if let draft = drafts.first {
                    response = draft.body
                    finish(provider: draft.providerID,
                           trace: String(draft.traceID.prefix(16)),
                           elapsed: started,
                           success: true)
                } else {
                    response = "(no candidate produced)"
                    finish(provider: "apple-fm",
                           trace: session,
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
        status = success
            ? "ok · \(provider)"
            : "fail · \(provider)"
    }

    private func finishError(_ error: Error) {
        latencyMs = 0
        status = "error: \(error)"
    }

    private func sessionID() -> String {
        "sample-\(Int(Date().timeIntervalSince1970))"
    }

    private func elapsedMs(_ start: Date) -> Double {
        Date().timeIntervalSince(start) * 1000
    }
}
