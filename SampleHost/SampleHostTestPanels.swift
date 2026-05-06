// MARK: - SampleHostTestPanels (single-prompt test panels)
//
// chapter 二百二十四 / M805 — extracted from SampleHostView.swift.
//
// Two SwiftUI single-prompt test panels (UI scaffolding for tap-once
// "is the system alive" smoke probes), pre-this-batch private
// computed properties on SampleHostView taking ~155 LOC of the View
// body's children. Now standalone `View` structs in dedicated file:
//
//   - SampleHostAFMTestPanel  (chapter 一百七十六 §176.13 / M609,
//     ~55 LOC) — AFM direct foreground test bypassing BAS substrate
//     to satisfy macOS 26 / iOS 26 modelmanagerd's foreground-only
//     policy
//   - SampleHostHybridTestPanel (chapter 一百七十七 §177 / M620,
//     ~100 LOC) — ChengluPreflight v0 router test with AFM⇄Gemma
//     fallback safety net + 5-head meridian inline predictions
//
// Pre-this-batch: ~160 LOC of computed view properties inline in
// SampleHostView (1146 LOC total).
// Post-this-batch: dedicated panel structs. SampleHostView body
// composes via `SampleHostAFMTestPanel(model: model)` etc.
//
// Doctrine pins:
//   - View structs are `internal` (no `private`) — reachable from
//     SampleHostView body via standard SwiftUI composition.
//   - Each panel takes `@ObservedObject var model: SampleHostModel`
//     so SwiftUI re-renders on @Published changes (parity with
//     pre-this-batch behavior).
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering, no
//     decision-making.
//   - chapter 二百十一 single-source-of-truth: panel UI invariant
//     owned by one file each.

import SwiftUI

// MARK: - M609 chapter 一百七十六 §176.13 — AFM direct foreground test panel

struct SampleHostAFMTestPanel: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AFM (Apple Foundation Models) direct test")
                    .font(.headline)
                Spacer()
                Button(model.afmIsRunning ? "Running…" : "Run AFM") {
                    model.runAFMTestNow()
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(model.afmIsRunning)
            }

            Text(
                "Bypasses BAS substrate (which has L2 organ stubbed). " +
                "Calls FoundationModels.LanguageModelSession directly " +
                "from foreground UI — only path that satisfies macOS 26 " +
                "/ iOS 26 modelmanagerd's foreground-only policy. " +
                "Requires Apple Intelligence enabled."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack {
                Text("Prompt:").font(.caption.bold())
                Spacer()
            }
            TextField("AFM prompt", text: Binding(
                get: { model.afmTestPrompt },
                set: { model.updateAFMTestPrompt($0) }
            ))
            .font(.caption)
            .textFieldStyle(.roundedBorder)
            .disabled(model.afmIsRunning)

            Text("Status: \(model.afmTestStatus)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(model.afmTestStatus.hasPrefix("ok") ? .green : (model.afmTestStatus.hasPrefix("error") ? .red : .secondary))

            if !model.afmTestOutput.isEmpty {
                Text("Response:")
                    .font(.caption.bold())
                Text(model.afmTestOutput)
                    .font(.caption.monospaced())
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - M620 chapter 一百七十七 §177 — Hybrid AFM+Gemma router test panel

struct SampleHostHybridTestPanel: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hybrid AFM⇄Gemma router test")
                    .font(.headline)
                Spacer()
                Button("Run Hybrid") {
                    model.runHybridSinglePrompt()
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }

            Text(
                "ChengluPreflight v0 (CoreML 3 KB, 88.5% test acc) " +
                "predicts AFM-success vs Gemma-fallback for the " +
                "current prompt, calls predicted LLM, falls back " +
                "on error so user sees no error (chapter 一百七十七)."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack {
                Text("Status:").font(.caption.bold())
                Spacer()
                if model.hybridGemmaLoadStatus != "idle" {
                    Text("Gemma: \(model.hybridGemmaLoadStatus)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.purple)
                }
            }
            Text(model.hybridSinglePromptStatus)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.cyan)

            if !model.hybridSinglePromptRoute.isEmpty {
                Text("Router: \(model.hybridSinglePromptRoute) (afm prob \(String(format: "%.3f", model.hybridSinglePromptProb)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.indigo)
            }

            // M659 chapter 一百八十三 — inline meridian predictions.
            // Visible AFTER predict (before LLM completes if slow)
            // so user sees full 5-head output without waiting for
            // bench. Each line is a separate head's prediction;
            // missing head shows nothing (graceful degradation).
            if model.hybridSinglePromptBlockProb != nil
                || model.hybridSinglePromptLengthChars != nil
                || model.hybridSinglePromptLatencyMs != nil
            {
                Divider().padding(.vertical, 2)
                Text("📡 Meridian (predictions before LLM)")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                if let p = model.hybridSinglePromptBlockProb {
                    Text(String(
                        format: "  PermitPredict: block=%.3f (%@)",
                        p,
                        p >= 0.5 ? "would-block" : "non-block"))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let len = model.hybridSinglePromptLengthChars {
                    Text(String(
                        format: "  Length predicted: %.0f chars",
                        len))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let ms = model.hybridSinglePromptLatencyMs {
                    Text(String(
                        format: "  Latency predicted: %.0f ms",
                        ms))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let vp = model.hybridSinglePromptVerbosityProb {
                    Text(String(
                        format: "  Verbosity: %.3f (%@)",
                        vp,
                        vp >= 0.5 ? "long >1500" : "short ≤1500"))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !model.hybridSinglePromptOutput.isEmpty {
                Text("Output:").font(.caption.bold())
                Text(model.hybridSinglePromptOutput)
                    .font(.caption.monospaced())
                    .padding(8)
                    .background(.regularMaterial,
                                in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(.thinMaterial,
                    in: RoundedRectangle(cornerRadius: 12))
    }
}
