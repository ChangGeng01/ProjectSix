// MARK: - SampleHostChengluStressPanel — chapter 三百三九 / M826
//
// SwiftUI panel that drives `SampleHostChengluStressRunner` for
// the附录 X Chenglu mesh on real iPhone hardware。Closes v9 §8
// non-promise #4 (production deployment validation) for opt-in
// real-iPhone stress testing。
//
// Doctrine pins:
//   - 不变量 #1/#2/#3 全保 — stress runner is read-only,no
//     decision path mutation
//   - 红线 7 watcher hint only
//   - chapter 三百三四 (M821) Builder MLModel overload — panel
//     loads .mlmodelc via Bundle + passes through builder
//   - chapter 三百三八 (M825) Mac stress test pattern — same
//     determinism / latency / failure tracking on iPhone

import SwiftUI

struct SampleHostChengluStressPanel: View {
    @StateObject private var runner =
        SampleHostChengluStressRunner()

    @State private var selectedDuration: Double = 1200

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

            controlButtons

            if runner.iterations > 0
                || runner.status == .running
            {
                statsBlock
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
    private var controlButtons: some View {
        HStack {
            if !runner.isRunning {
                Button {
                    runner.start(
                        durationSeconds: selectedDuration)
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
