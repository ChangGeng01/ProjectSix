// MARK: - BASShadowMemoryEvidenceSampler — 全面进化 T2.3 低熵
//
// Turns the gate's LATENCY-style honesty onto MEMORY evidence。 The
// migration gates (`BASCoreAIMigrationVerdict` and clones) accept
// `candidatePeakMemoryBytes` / `incumbentPeakMemoryBytes` as caller-
// supplied inputs;until now only the on-device endurance runner
// (ch1044 `BASTaskVmInfoProbe` sampling) ever produced them。 This
// helper is the host-side producer:bracket a workload,sample
// `task_vm_info.phys_footprint` (the jetsam-relevant number) before /
// after each step,return the sampled MAX。
//
// ## Honesty bounds (R1)
//
// - TASK_VM_INFO reports CURRENT footprint,not a high-water mark —
//   the result is a SAMPLED max and can under-report transient peaks
//   between samples。 Callers feed it to the gate as exactly that
//   (the gate's memory dimension already documents sampled-max
//   semantics from the device campaign)。
// - Returns nil (never 0) when the probe fails — absent evidence
//   stays absent,and the gate reports MEMORY_NO_EVIDENCE。
// - Observation-only:no production turn path calls this;consumers
//   are evidence campaigns and tests (banned-in-spine discipline
//   rides the composer types this feeds)。

import Foundation
import BASRuntimeCore   // BASTaskVmInfoProbe

public enum BASShadowMemoryEvidenceSampler {

    /// Run `work` `steps` times,sampling phys_footprint before the
    /// first step and after every step;returns the sampled max in
    /// bytes,or nil if the probe is unavailable。 Synchronous by
    /// design — memory campaigns bracket synchronous inference calls。
    public static func sampledPeakFootprintBytes(
        steps: Int = 1,
        work: (_ step: Int) -> Void
    ) -> Int? {
        guard let initial = try? BASTaskVmInfoProbe.rawSnapshot()
        else { return nil }
        var peak = initial.physFootprintBytes
        for step in 0..<max(1, steps) {
            work(step)
            guard let sample = try? BASTaskVmInfoProbe.rawSnapshot()
            else { return nil }
            peak = max(peak, sample.physFootprintBytes)
        }
        // The gate takes Int;phys_footprint on any real device fits
        // comfortably (clamped defensively rather than trapping)。
        return Int(clamping: peak)
    }
}
