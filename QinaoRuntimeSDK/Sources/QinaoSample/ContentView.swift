import SwiftUI
import QinaoLoop

/// SwiftUI view rendering the Qinao Sample app. Lifted from the
/// executable target into the QinaoSample library (M228) so it
/// can be exercised by snapshot + behaviour tests without driving
/// a real app launch.
@MainActor
public struct ContentView: View {
    @StateObject private var session: SampleSession
    @State private var prompt: String =
        "Reply with one short sentence about a calming evening habit."
    @State private var response: String = ""
    @State private var provider: SampleProvider = .appleFoundation
    @State private var traceID: String = "—"
    @State private var latencyMs: Double = 0
    @State private var isRunning: Bool = false

    /// Default-init: production sample-app path with the real
    /// QinaoLoop endpoint factories.
    public init() {
        _session = StateObject(wrappedValue: SampleSession())
    }

    /// Test seam: construct the view with a pre-built session
    /// (typically injected with a mock endpoint builder) and
    /// optional initial state. Snapshot tests use this to render
    /// deterministic states without async work.
    public init(
        session: SampleSession,
        prompt: String =
            "Reply with one short sentence about a calming evening habit.",
        response: String = "",
        provider: SampleProvider = .appleFoundation,
        traceID: String = "—",
        latencyMs: Double = 0
    ) {
        _session = StateObject(wrappedValue: session)
        _prompt = State(initialValue: prompt)
        _response = State(initialValue: response)
        _provider = State(initialValue: provider)
        _traceID = State(initialValue: traceID)
        _latencyMs = State(initialValue: latencyMs)
    }

    public var body: some View {
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
