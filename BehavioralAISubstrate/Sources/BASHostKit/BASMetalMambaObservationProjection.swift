// MARK: - BASMetalMambaObservationProjection — Step 4 (per-turn Metal/Mamba observation, byte-equal)
//
// Emits per-turn Metal (MPSGraph plasticity) / Mamba (SSM selective-scan) telemetry WITHOUT
// affecting the answer — the user's directive "先做 observation-only 每 turn 输出，不要急着影响答案".
//
// Mirrors `BASSovereignTurnObservationProjection` exactly: a host turn loop (or the device
// endurance runner) calls `shadowProbeResult(...)` once AFTER a turn. When `harness` or `sink` is
// nil the probe never runs — so the turn is byte-identical (红线 7, observation-only). This is a
// HOST-DRIVEN seam: it does NOT touch the synchronous `runTurn` (which cannot await the async
// harness — the same ch883 boundary), so there is zero change to the cognitive main chain.
//
// A probe error is swallowed (the shadow must NEVER break a real turn). The emitted observation is
// NOT part of any canonical-bytes / seal / hash path — it is pure telemetry.
//
// ADR-014 — purely additive; default-OFF (nil harness/sink) is byte-equal.

import Foundation
import BASMetalSubstrate

/// Typed per-turn Metal/Mamba telemetry. Codable/Sendable; carries derived means + a coarse
/// verdict. NOT in any canonical-bytes / seal / hash path (telemetry only).
public struct BASMetalMambaObservation:
    Codable, Equatable, Hashable, Sendable
{
    public enum Verdict: String, Codable, Hashable, Sendable, CaseIterable {
        /// GPU path ran (Metal available).
        case gpuOK = "gpu-ok"
        /// GPU unavailable (simulator / no-Metal); CPU path ran.
        case cpuOnly = "cpu-only"
    }

    public let sessionID: String
    public let turnID: String
    public let mambaCPUMicrosecondsMean: Double
    public let mambaGPUMicrosecondsMean: Double
    public let gpuAvailable: Bool
    public let verdict: Verdict

    public init(
        sessionID: String,
        turnID: String,
        mambaCPUMicrosecondsMean: Double,
        mambaGPUMicrosecondsMean: Double,
        gpuAvailable: Bool,
        verdict: Verdict
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.mambaCPUMicrosecondsMean = mambaCPUMicrosecondsMean
        self.mambaGPUMicrosecondsMean = mambaGPUMicrosecondsMean
        self.gpuAvailable = gpuAvailable
        self.verdict = verdict
    }
}

public enum BASMetalMambaObservationProjection {

    /// Lightweight default Mamba shape for a per-turn probe (chapter 一百八十五 — named, not magic).
    /// Small enough to run cheaply once per turn off the answer path.
    public static let defaultProbeBatch: Int = 1
    public static let defaultProbeHiddenDim: Int = 16
    public static let defaultProbeStateDim: Int = 8
    public static let defaultProbeSequenceLength: Int = 8

    /// Pure, deterministic projection of a benchmark report into a typed observation. Means are
    /// computed from the public sample arrays (no dependency on derived report accessors).
    public static func project(
        sessionID: String,
        turnID: String,
        report: BASMetalBenchmarkReport
    ) -> BASMetalMambaObservation {
        BASMetalMambaObservation(
            sessionID: sessionID,
            turnID: turnID,
            mambaCPUMicrosecondsMean: mean(report.cpuMicrosecondsSamples),
            mambaGPUMicrosecondsMean: mean(report.gpuMicrosecondsSamples),
            gpuAvailable: report.gpuAvailable,
            verdict: report.gpuAvailable ? .gpuOK : .cpuOnly)
    }

    /// Run a lightweight Mamba probe and emit the observation — IFF both `harness` and `sink` are
    /// non-nil. Either nil ⇒ returns nil and runs nothing (the byte-equal path). A probe error is
    /// swallowed (returns nil). OBSERVATION-ONLY — never mutates the turn / never halts.
    @discardableResult
    public static func runShadowIfEnabled(
        sessionID: String,
        turnID: String,
        harness: BASMetalBenchmarkHarness?,
        sink: (@Sendable (BASMetalMambaObservation) -> Void)? = nil
    ) async -> BASMetalMambaObservation? {
        guard let harness, let sink else { return nil }
        guard let report = try? await harness.runMambaScan(
            batch: defaultProbeBatch,
            hiddenDim: defaultProbeHiddenDim,
            stateDim: defaultProbeStateDim,
            sequenceLength: defaultProbeSequenceLength)
        else { return nil }
        let observation = project(
            sessionID: sessionID, turnID: turnID, report: report)
        sink(observation)
        return observation
    }

    /// One-call per-turn probe from a completed result — the host loop calls this after the turn,
    /// alongside the sovereign shadow-parity call. No-op / byte-equal when `harness`/`sink` is nil.
    @discardableResult
    public static func shadowProbeResult(
        _ result: BASEBrainTurnResult,
        harness: BASMetalBenchmarkHarness?,
        sink: (@Sendable (BASMetalMambaObservation) -> Void)? = nil
    ) async -> BASMetalMambaObservation? {
        return await runShadowIfEnabled(
            sessionID: result.runtimeTrace.sessionID,
            turnID: result.thoughtFold.foldID,
            harness: harness,
            sink: sink)
    }

    // MARK: - helpers

    private static func mean(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }
}
