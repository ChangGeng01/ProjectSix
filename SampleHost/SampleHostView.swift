import SwiftUI
import BASHostKit

// M811 chapter 二百三十 — `SampleHostWindGatePresentationSupport`
// extracted to dedicated foundation file
// `SampleHostWindGatePresentationSupport.swift`.

struct SampleHostView: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SampleHost")
                            .font(.largeTitle.weight(.bold))
                        Text("Minimal private SDK integration proving lifecycle bootstrap, session start, reopen, current-brain render, and console inspection through BASHostKit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("Bootstrap") { model.bootstrap() }
                        Button("Rapid") { model.start(.primary) }
                        Button("Deliberate") { model.start(.comparative) }
                        Button("Reflective") { model.start(.reflective) }
                        Button("Reopen") { model.reopen() }
                    }
                    .buttonStyle(.borderedProminent)

                    // M726 chapter 一百九十三 — resume banner.
                    // Surfaces a previous (possibly crashed) bench's
                    // last-known state so the user can decide whether
                    // to start fresh or treat the existing JSONL as
                    // continuing data. UI is hint-only — no auto-resume.
                    if let cp = model.hybridBenchResumableCheckpoint {
                        SampleHostResumeBannerPanel(model: model, checkpoint: cp)
                    }

                    SampleHostBenchPanel(model: model)

                    SampleHostAFMTestPanel(model: model)

                    SampleHostAFMBenchPanel(model: model)

                    SampleHostHybridTestPanel(model: model)

                    // Chapter 三百三九 (M826) — 附录 X Chenglu
                    // mesh stress on real iPhone
                    SampleHostChengluStressPanel()

                    // Chapter 四百一 (M934) — LLM Extraction
                    // Engine demo (M932 engine + M920 mock,
                    // surfaces all 9 byproducts in UI)
                    SampleHostLLMExtractionDemoView()

                    SampleHostHybridBenchPanel(model: model)

                    SampleHostActiveSessionPanel(model: model)

                    SampleHostThirteenLayerTurnDetailView(
                        turn: model.result.eBrainTurn,
                        sourceBadgeDetail: "SampleHost is currently rendering the active 13-layer runtime turn returned by BASHostKit.")

                    BASHostConsoleView(snapshot: model.result.consoleSnapshot)
                }
                .padding(24)
            }
            .navigationTitle("BASHostKit")
            // M726 chapter 一百九十三 — load resumable checkpoint
            // (if any) on first appear. Surfaces banner if a
            // previous bench crashed mid-run.
            .task { await model.loadResumableCheckpoint() }
        }
    }

    // M809 chapter 二百二十八 — `resumeBannerPanel` extracted to
    // dedicated standalone struct in `SampleHostResumeBannerPanel
    // .swift`. View body composes via
    // `SampleHostResumeBannerPanel(model: model, checkpoint: cp)`.

    // M807 chapter 二百二十六 — `benchPanel` + 2 status helpers
    // extracted to `SampleHostBenchPanel.swift` standalone struct.

    // M805 chapter 二百二十四 — `afmTestPanel` + `hybridTestPanel`
    // extracted to dedicated standalone SwiftUI structs in
    // `SampleHostTestPanels.swift`. View body composes via
    // `SampleHostAFMTestPanel(model: model)` + `SampleHostHybrid-
    // TestPanel(model: model)`.

    // M808 chapter 二百二十七 — `hybridBenchPanel` + 5 status
    // helpers (meridian / safety-kit / safety-tint / live / final)
    // extracted to `SampleHostHybridBenchPanel.swift` standalone
    // struct. Largest UI carve-out in the architectural deconstruction
    // arc (chapters 二百九 → 二百二十七).

    // M806 chapter 二百二十五 — `afmBenchPanel` + 2 status helpers
    // extracted to `SampleHostAFMBenchPanel.swift` standalone struct.

    // M807 chapter 二百二十六 — `benchLiveStatusText` +
    // `benchFinalStatusText` consolidated into `SampleHostBenchPanel`
    // (only callers were that panel).

    // M810 chapter 二百二十九 — `sourceBadge` ViewBuilder helper +
    // `if let turn = ...` 13-layer-turn detail block extracted to
    // `SampleHostThirteenLayerTurnDetailView.swift`. SampleHost-
    // SourceBadge is now a standalone struct co-located with the
    // turn-detail view.
}
