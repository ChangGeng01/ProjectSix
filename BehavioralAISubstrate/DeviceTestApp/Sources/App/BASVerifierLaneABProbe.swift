// MARK: - BASVerifierLaneABProbe — A2 verifier default-flip evidence (2026-06-12)
//
// The verifier-pipeline decode-lane seam (b071b72d5) is reachable but defaults to `.scout` (temp 0.1).
// Flipping the DEFAULT to `.greedy` would make the certified 1.34× spec-decode the production default for
// verification AND make verdicts byte-reproducible — but a default flip that changes output bytes needs
// EVIDENCE (ADR-014, 亏的不要). This probe (`BAS_VERIFIER_LANE_AB=1`) supplies it: it runs the SAME
// verification task through the verifier pipeline in BOTH lanes on the real device and emits, for human
// read, the per-stage outputs side by side + the speed delta.
//
// Decision rule (recorded by the operator after reading): flip the verifier default to `.greedy` ONLY if
// the greedy verdicts are at least as good as the .scout ones (they should be — temp 0.1 is already
// near-greedy, and greedy is reproducible + faster); else keep the reachable-seam default.
//
// One MLX Llama-3.2-3B (+1B draft for spec-decode in the greedy lane) wired to all 4 verifier stages.
// Observation-only, MLX-free of the substrate.

import Foundation
import os
import BASOrgan
import BASMLXAdapter

enum BASVerifierLaneABProbe {

    // A draft that has a checkable factual claim + a reasoning step (where greedy vs sampled diverges).
    private static let draftBody =
        "The Great Wall of China is visible from the Moon with the naked eye, and it was built "
        + "entirely during the Ming dynasty in a single decade."

    private static let userPrompt = "Is this statement accurate? Verify each claim."

    // FileLog consolidated into the shared ProbeFileLog (BASProbeCommon.swift) — Tier-B dedup.

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "verifier-lane-ab", category: "verifier-lane-ab", alsoPrint: false)
        defer { fileLog.close() }
        fileLog.emit("📊 verifier-lane-ab START — same verification task, .scout vs .greedy lane")

        do {
            // Single shared adapter (greedy default-on → engages spec-decode when the greedy lane sends
            // temp==0). Load once; both lanes use the same loaded weights (only the per-call preset differs).
            // MEMORY-SAFE (2026-06-14): cap decode to 256 tokens. An uncapped 4-stage verify (preset budget
            // up to 1024/stage) on the dual-residency pair (Llama-3B + 1B draft ≈ 2542 MB) spiked past the
            // ~3376 MB jetsam cap and SIGKILL'd this probe 39× (memoryException). 256 tokens is plenty to
            // human-read a verdict's gist; both lanes share the cap so the quality comparison stays fair.
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.speculativeOptimalTarget,
                maxOutputTokens: 256)
            try await adapter.loadModel()

            let draft = BASOrganDraft(
                requestID: "vlab-draft", providerID: "probe", role: .core,
                body: draftBody, inputTokensEstimated: 0, outputTokensEstimated: 0,
                producedAt: Date(), traceID: "vlab")
            let task = BASLLMTaskPackage(
                taskID: "vlab-task", originSessionID: "vlab-session",
                compiledAtMs: 0, intent: userPrompt, goal: "verify claims")

            for lane: BASDecodeLane? in [nil, .greedy] {
                let label = lane == nil ? "scout-default" : "greedy"
                // Draft residency per lane (U1): the scout lane is single-model — drop the ~700 MB draft (dead
                // weight, never used at temp 0.1) to free headroom; the greedy lane needs it for spec-decode.
                if lane == .greedy {
                    try? await adapter.loadDraftModel()
                } else {
                    _ = await adapter.unloadDraftModel(reason: "scout lane is single-model")
                }
                let pipeline = BASLLMVerifierPipeline(
                    adapters: [
                        .reviewer: adapter, .redTeam: adapter,
                        .factChecker: adapter, .compressor: adapter,
                    ],
                    contractInstall: nil,   // observe contract off — measure raw decode
                    decodeLane: lane)
                let start = DispatchTime.now().uptimeNanoseconds
                let report = await pipeline.verify(draft: draft, taskPackage: task)
                let ms = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
                fileLog.emit(String(format: "📊 verifier-lane-ab LANE=%@ total_ms=%.0f stages=%d",
                    label, ms, report.perStage.count))
                for stage in BASLLMVerifierStage.allCases {
                    if let out = report.perStage[stage] {
                        fileLog.emit("―― [\(label)] \(stage.rawValue): "
                            + clean(out.rawOutput))
                    }
                }
                fileLog.emit("―― [\(label)] FINAL: \(clean(report.finalRecommendedAnswer))")
            }
            fileLog.emit("📊 verifier-lane-ab DONE — human-read both lanes; flip the verifier DEFAULT to "
                + ".greedy ONLY if greedy verdicts ≥ scout (reproducible + faster is the tiebreak).")
        } catch {
            fileLog.emit("📊 verifier-lane-ab ERROR=\(error)")
        }
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(700).description
    }
}
