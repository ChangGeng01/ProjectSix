// MARK: - SampleHostAFMBenchPanel
//
// chapter 二百二十五 / M806 — extracted from SampleHostView.swift.
//
// AFM 8h long-running bench panel (chapter 一百七十六 / M610) +
// 2 status-string helpers used only by this panel. Standalone
// SwiftUI struct with `@ObservedObject var model: SampleHostModel`.
//
// Pre-this-batch: ~145 LOC across 1 inline panel computed property
// (`afmBenchPanel`) + 2 helper computed properties
// (`afmBenchLiveStatus`, `afmBenchFinalStatus`) on SampleHostView.
//
// Post-this-batch: panel struct owns its file. Status helpers
// move with it as private computed properties on the panel struct.
//
// Doctrine pins:
//   - All numeric params reach @Published flex via M710 chapter
//     一百九十一 update*Bounds setters (delegating to chapter
//     二百二十二 SampleHostHybridBenchBounds typed bundle).
//   - chapter 一百七十六 §176.14 doctrine: AFM bench is foreground-
//     policy-compliant (calls FoundationModels.LanguageModelSession
//     directly). Substrate routes 14 layers per turn; AFM body call
//     happens after substrate evaluation.
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering, no decision.

import SwiftUI

struct SampleHostAFMBenchPanel: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AFM 8-hour bench (flexible config)")
                    .font(.headline)
                Spacer()
                Button(model.afmBenchIsRunning ? "Stop" : "Start") {
                    if model.afmBenchIsRunning {
                        model.stopAFMBench()
                    } else {
                        model.startAFMBench()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(model.afmBenchIsRunning ? .red : .indigo)
            }

            Text(
                "Substrate routes 14 layers per turn (audit codes), " +
                "then AFM body call (foreground policy satisfied). " +
                "All numeric params below are flexible (not hard-coded)."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            // Flexible config grid
            Group {
                HStack {
                    Text("Hours:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.afmBenchDurationHours },
                            set: { model.updateAFMBenchDurationHours($0) }
                        ),
                        in: 0.1...24.0,
                        step: 0.5
                    ) {
                        Text(String(format: "%.1f h", model.afmBenchDurationHours))
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Text("Stride CSV:").font(.caption)
                    TextField("coprime to 40320", text: Binding(
                        get: { model.afmBenchStrideRotationCSV },
                        set: { model.updateAFMBenchStrideCSV($0) }
                    ))
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.afmBenchIsRunning)
                }
                HStack {
                    Text("Rotation iter:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.afmBenchRotationPeriodIter },
                            set: { model.updateAFMBenchRotationPeriod($0) }
                        ),
                        in: 1_000...100_000,
                        step: 1_000
                    ) {
                        Text("\(model.afmBenchRotationPeriodIter)")
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Text("Mutations:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.afmBenchMutationSeedCount },
                            set: { model.updateAFMBenchMutationCount($0) }
                        ),
                        in: 1...5,
                        step: 1
                    ) {
                        Text("\(model.afmBenchMutationSeedCount)")
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Toggle("Skip AFM on .block/.delay (saves AFM calls)", isOn: Binding(
                        get: { model.afmBenchSkipBlocked },
                        set: { model.updateAFMBenchSkipBlocked($0) }
                    ))
                    .font(.caption)
                    .disabled(model.afmBenchIsRunning)
                }
            }

            if model.afmBenchIsRunning {
                Text(liveStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.indigo)
            } else if model.afmBenchIterations > 0 {
                Text(finalStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
            }

            if !model.afmBenchOutputPath.isEmpty {
                Text("→ \(model.afmBenchOutputPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let err = model.afmBenchLastError {
                Text("Bench error: \(err)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status string helpers

    private var liveStatus: String {
        let elapsed = model.afmBenchStartTime.map {
            Date().timeIntervalSince($0)
        } ?? 0
        let perSec = elapsed > 0
            ? Double(model.afmBenchIterations) / elapsed
            : 0
        return String(
            format:
                "RUN • iter=%d • %.0fs/%.0fs • %.2f/s • " +
                "afm ok=%d skip=%d err=%d",
            model.afmBenchIterations,
            elapsed,
            model.afmBenchDurationHours * 3600,
            perSec,
            model.afmBenchAFMSuccessCount,
            model.afmBenchAFMSkippedCount,
            model.afmBenchAFMErrorCount)
    }

    private var finalStatus: String {
        return String(
            format:
                "DONE • iter=%d • afm ok=%d skip=%d err=%d",
            model.afmBenchIterations,
            model.afmBenchAFMSuccessCount,
            model.afmBenchAFMSkippedCount,
            model.afmBenchAFMErrorCount)
    }
}
