// MARK: - SampleHostBenchPanel
//
// chapter 二百二十六 / M807 — extracted from SampleHostView.swift.
//
// Real-device substrate bench panel (chapter 一百四十七 / M573 part
// 2 — earliest bench format, simple iterations.jsonl output) plus
// 2 status-string helpers used only by this panel.
//
// Pre-this-batch: ~70 LOC of inline panel + helpers on
// SampleHostView (chapter 一百四十七 doctrine).
// Post-this-batch: dedicated standalone View struct.
//
// Doctrine pins:
//   - Loops BASHostRuntime.startSession() with rotating synthetic
//     prompts (5 personas × 3 scenarios)
//   - Per-iteration audit-code count + permit mode + duration
//     written to Documents/iphone-bench/iterations.jsonl
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering, no decision.

import SwiftUI

struct SampleHostBenchPanel: View {
    @ObservedObject var model: SampleHostModel

    @ViewBuilder
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Real-device substrate bench")
                    .font(.headline)
                Spacer()
                Button(model.benchIsRunning ? "Stop" : "Run Bench") {
                    model.toggleBench()
                }
                .buttonStyle(.bordered)
                .tint(model.benchIsRunning ? .red : .green)
            }

            Text(
                "Loops BASHostRuntime.startSession() with rotating " +
                "synthetic prompts (5 personas × 3 scenarios). " +
                "Per-iteration audit code count + permit mode + " +
                "duration written to Documents/iphone-bench/" +
                "iterations.jsonl. Keep app in foreground (iOS " +
                "suspends backgrounded apps after ~30s)."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if model.benchIsRunning {
                Text(liveStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
            } else if model.benchIterationsCompleted > 0 {
                Text(finalStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
            }

            if !model.benchOutputPath.isEmpty {
                Text("→ \(model.benchOutputPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let benchError = model.benchLastError {
                Text("Bench error: \(benchError)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status string helpers

    private var liveStatus: String {
        let elapsed: TimeInterval
        if let start = model.benchStartTime {
            elapsed = Date().timeIntervalSince(start)
        } else {
            elapsed = 0
        }
        let perSec = elapsed > 0
            ? Double(model.benchIterationsCompleted) / elapsed
            : 0
        return String(
            format: "RUNNING • iter=%d • %.1fs • %.2f/s • audit=%d",
            model.benchIterationsCompleted,
            elapsed,
            perSec,
            model.benchAuditCodesTotal)
    }

    private var finalStatus: String {
        return String(
            format: "DONE • iter=%d • audit=%d total • last error=%@",
            model.benchIterationsCompleted,
            model.benchAuditCodesTotal,
            model.benchLastError ?? "none")
    }
}
