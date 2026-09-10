// MARK: - SampleHostResumeBannerPanel
//
// chapter 二百二十八 / M809 — extracted from SampleHostView.swift.
//
// Resume-from-checkpoint banner (chapter 一百九十三 / M726 + chapter
// 一百九十九 / M748). When a previous bench task crashed before
// finishing, the SampleHostBenchCheckpointStore writes a checkpoint
// to disk. On next app launch, SampleHostModel detects it and surfaces
// it via `hybridBenchResumableCheckpoint`. This banner offers two
// actions:
//   - "Resume Settings" — restores smokeMode / duration / mutation /
//     stride from checkpoint, clears banner, starts fresh bench.
//     Counter state NOT restored (chapter 一百九十九 doctrine: resume
//     SETTINGS, fresh state).
//   - "Dismiss" — clears checkpoint from disk without resuming.
//
// Pre-this-batch: ~58 LOC of inline `@ViewBuilder private func
// resumeBannerPanel(_:)` on SampleHostView.
// Post-this-batch: dedicated standalone View struct. SampleHostView
// body composes via `SampleHostResumeBannerPanel(model: model,
// checkpoint: cp)`.
//
// Doctrine pins:
//   - chapter 一百九十三 / M726: banner is INFORMATIONAL —
//     never auto-restarts.
//   - chapter 一百九十九 / M748: resume restores SETTINGS only,
//     not running counter state (would corrupt new bench's
//     anomaly windows + Welford running means).
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering, no decision.

import SwiftUI

struct SampleHostResumeBannerPanel: View {
    @ObservedObject var model: SampleHostModel
    let checkpoint: SampleHostBenchCheckpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⚠️ Previous bench did not finish cleanly")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                // M748 chapter 一百九十九 — actual Resume button.
                // Restores smokeMode / duration / mutation /
                // stride from checkpoint, clears banner, starts
                // bench. Counter state NOT restored (fresh).
                Button("Resume Settings") {
                    Task { await model.resumeBenchFromCheckpoint() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
                Button("Dismiss") {
                    Task { await model.clearResumableCheckpoint() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Text("Last known state:")
                .font(.caption.bold())
            Text("• iter \(checkpoint.iter) of "
                + "\(String(format: "%.1f", checkpoint.durationHours))h target "
                + "(\(checkpoint.smokeMode))")
                .font(.caption.monospacedDigit())
            Text("• AFM ok \(checkpoint.afmOk) / Gemma ok \(checkpoint.gemmaOk) / "
                + "both-failed \(checkpoint.bothFailed)")
                .font(.caption.monospacedDigit())
            if checkpoint.stuckSubstrates > 0 || checkpoint.stuckLLMs > 0 {
                Text("• stuck-substrates \(checkpoint.stuckSubstrates) / "
                    + "stuck-LLMs \(checkpoint.stuckLLMs)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Text("• last update: \(checkpoint.lastUpdatedIso)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("Starting a new bench will overwrite the checkpoint.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.5), lineWidth: 1)
        )
    }
}
