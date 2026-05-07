// MARK: - SampleHostChengluStressPanel — chapter 三百三九 / M826
//                                     + chapter 三百七五 / M862
//
// SwiftUI panel that drives `SampleHostChengluStressRunner` for
// the附录 X Chenglu mesh on real iPhone hardware。Closes v9 §8
// non-promise #4 (production deployment validation) for opt-in
// real-iPhone stress testing。
//
// Chapter 三百七五 / M862 adds an opt-in cognitive OS toggle that
// wires the M859 builder into the stress run for live G1/G2/G9
// data loop exercise。Default unchecked — preserves M826 / M837
// stress runner contract。
//
// Doctrine pins:
//   - 不变量 #1/#2/#3 全保 — stress runner is read-only,no
//     decision path mutation
//   - 红线 7 watcher hint only
//   - chapter 三百三四 (M821) Builder MLModel overload — panel
//     loads .mlmodelc via Bundle + passes through builder
//   - chapter 三百三八 (M825) Mac stress test pattern — same
//     determinism / latency / failure tracking on iPhone
//   - chapter 三百七五 (M862) cognitive OS toggle — default OFF

import SwiftUI
import BASHostKit

struct SampleHostChengluStressPanel: View {
    @StateObject private var runner =
        SampleHostChengluStressRunner()

    @State private var selectedDuration: Double = 1200

    /// Chapter 三百七五 / M862: opt-in cognitive OS toggle。
    /// Default OFF preserves M826 / M837 contract。When ON,
    /// builds in-memory event log + state store + knowledge
    /// graph (no SQLite — keeps the toggle a one-tap experience
    /// without filesystem permission concerns)。
    @State private var cognitiveOSEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chenglu Mesh — 附录 X stress")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            Text("Real-iPhone sustained run of all 5 .mlmodelc " +
                "(Preflight / MultiHead / PermitPredict / " +
                "LengthHead / LatencyHead) through chapter 三百" +
                "三四 Builder MLModel overload。Closes v9 §8 #4 " +
                "production deployment validation。")
                .font(.caption)
                .foregroundStyle(.secondary)

            durationPicker

            cognitiveOSToggle

            controlButtons

            if runner.iterations > 0
                || runner.status == .running
            {
                statsBlock
            }

            if runner.cognitiveOSEnabled {
                cognitiveOSStatsBlock
            }

            if let savedPath = runner.lastSavedRelativePath {
                savedPathBlock(savedPath)
            }

            if !runner.progressLog.isEmpty {
                logBlock
            }
        }
        .padding(16)
        .background(.thinMaterial,
            in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch runner.status {
        case .idle:
            Text("Idle").foregroundStyle(.secondary)
        case .loadingModels:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Loading…")
            }
        case .running:
            HStack(spacing: 4) {
                Circle().fill(.green).frame(
                    width: 8, height: 8)
                Text("Running")
            }
        case .finished:
            Text("Finished")
                .foregroundStyle(.green)
        case .error(let msg):
            Text("Error: \(msg)")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var durationPicker: some View {
        HStack {
            Text("Duration:")
            Picker("", selection: $selectedDuration) {
                Text("60s").tag(60.0)
                Text("2m").tag(120.0)
                Text("5m").tag(300.0)
                Text("20m").tag(1200.0)
                Text("60m").tag(3600.0)
                Text("8h").tag(28800.0)
            }
            .pickerStyle(.segmented)
            .disabled(runner.isRunning)
        }
    }

    @ViewBuilder
    private var cognitiveOSToggle: some View {
        Toggle(isOn: $cognitiveOSEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cognitive OS observer (M862)")
                    .font(.caption)
                Text("Wires M859 builder → event log + state " +
                    "+ graph during run。In-memory only。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(runner.isRunning)
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack {
            if !runner.isRunning {
                Button {
                    runner.start(
                        durationSeconds: selectedDuration,
                        cognitiveOSOptions: cognitiveOSOptions())
                } label: {
                    Label(
                        "Run \(Int(selectedDuration))s stress",
                        systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(role: .destructive) {
                    runner.cancel()
                } label: {
                    Label("Cancel",
                        systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// Chapter 三百七五 / M862: assemble the cognitive OS bundle
    /// options the panel chose。In-memory across all primitives
    /// (no SQLite URLs — keeps toggle frictionless)。
    private func cognitiveOSOptions()
        -> BASCognitiveOSBundleOptions
    {
        guard cognitiveOSEnabled else { return .allDisabled }
        return BASCognitiveOSBundleOptions(
            enableEventLog: true,
            enableUserState: true,
            enableKnowledgeGraph: true)
    }

    @ViewBuilder
    private var statsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            statLine("Iterations",
                "\(runner.iterations)")
            statLine("Elapsed",
                String(format: "%.1fs",
                    runner.elapsedSeconds))
            statLine("Throughput",
                String(format: "%.1f iter/s",
                    runner.throughput))
            statLine("Recent avg",
                String(format: "%.2fms",
                    runner.recentAvgMs))
            if runner.p50Ms > 0 {
                statLine("p50 / p95 / p99",
                    String(format: "%.2f / %.2f / %.2fms",
                        runner.p50Ms, runner.p95Ms,
                        runner.p99Ms))
            }
            statLine("Failures",
                "\(runner.failures)",
                color: runner.failures > 0 ? .red : .green)
            statLine("Determinism mismatches",
                "\(runner.determinismMismatches)",
                color: runner.determinismMismatches > 0
                    ? .red : .green)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(.quaternary,
            in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func statLine(
        _ label: String,
        _ value: String,
        color: Color = .primary
    ) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(color)
                .fontWeight(.semibold)
        }
    }

    /// Chapter 三百七五 / M862: surface cognitive OS observer
    /// stats during + after a run。Hidden by default;visible only
    /// when the toggle was on at start of run。
    @ViewBuilder
    private var cognitiveOSStatsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🧠 Cognitive OS observer (M862)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            statLine("Events appended",
                "\(runner.cognitiveOSEventCount)")
            statLine("State folds",
                "\(runner.cognitiveOSStateCount)")
            statLine("Graph nodes",
                "\(runner.cognitiveOSGraphNodeCount)")
            statLine("Graph edges",
                "\(runner.cognitiveOSGraphEdgeCount)")
        }
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(.quaternary,
            in: RoundedRectangle(cornerRadius: 8))
    }

    /// Chapter 三百四九 / M836: surface the persisted JSON file
    /// path so the result can be retrieved via `xcrun devicectl
    /// device copy from`。
    @ViewBuilder
    private func savedPathBlock(
        _ relativePath: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("💾 Saved (latest + history):")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Documents/\(relativePath)")
                .font(.system(.caption2,
                    design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.green)
                .lineLimit(2)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var logBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log (\(runner.progressLog.count) lines)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(
                        runner.progressLog.suffix(20).reversed(),
                        id: \.self
                    ) { line in
                        Text(line)
                            .font(.system(.caption2,
                                design: .monospaced))
                            .lineLimit(2)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 160)
            .background(.quaternary.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
