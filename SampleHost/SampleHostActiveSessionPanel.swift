// MARK: - SampleHostActiveSessionPanel
//
// chapter 二百三十 / M812 — extracted from SampleHostView.swift.
//
// Active-session status VStack rendering current-brain fields
// (workflow / posture / initiative / boundary / calibration /
// confidence ceiling / pending review count / dominant goals /
// active constraints / notices). Reads `model.result.*` +
// `model.lastError` + `model.result.currentBrain.*`.
//
// Pre-this-batch: ~30 LOC of inline VStack in SampleHostView body.
// Post-this-batch: dedicated standalone View struct.
//
// Doctrine pins:
//   - View is a pure projection of the CurrentBrain bundle.
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering.

import SwiftUI

struct SampleHostActiveSessionPanel: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.result.activeSessionTitle)
                .font(.headline)
            if let lastError = model.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text("Workflow: \(model.result.currentBrain.workflowTitle)")
                .font(.subheadline.weight(.medium))
            Text("Posture \(model.result.currentBrain.identityPosture.rawValue) • initiative \(model.result.currentBrain.identityInitiative.rawValue) • boundary \(model.result.currentBrain.boundaryMode.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Calibration \(model.result.currentBrain.calibrationStatus.rawValue) • confidence \(Int((model.result.currentBrain.confidenceCeiling * 100).rounded()))% • pending review \(model.result.currentBrain.evolutionPendingReviewCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !model.result.currentBrain.dominantGoals.isEmpty {
                Text(model.result.currentBrain.dominantGoals.joined(separator: " • "))
                    .font(.subheadline)
            }
            if !model.result.currentBrain.activeConstraints.isEmpty {
                Text(model.result.currentBrain.activeConstraints.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !model.result.notices.isEmpty {
                Text(model.result.notices.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
