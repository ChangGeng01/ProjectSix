// MARK: - BASMambaGPUShadowParity
// chapter 一百八十七 — GPU-vs-CPU selective-scan parity (the Metal/Mamba per-turn GPU SHADOW)
//
// Runs the SAME state-space selective-scan on BOTH the CPU (`selectiveScan`) and the GPU
// (`selectiveScanGPU`) over identical inputs and returns the mean-absolute-error (MAE) between their
// output sequences `y`. This is the "GPU shadow" telemetry: it quantifies how closely the
// non-deterministic Metal kernel tracks its deterministic CPU twin on real (per-turn-derived) inputs —
// a step toward an eventual GPU-authoritative path (which needs a determinism story the CPU twin
// supplies). OBSERVATION/TELEMETRY ONLY: nothing here is on any byte-deterministic value path; the
// authoritative SSM operator value remains the sync per-channel CPU reference.
//
// Returns nil when the GPU is unavailable (no Metal device / pipeline) or a scan errors — the caller
// then simply records "no GPU shadow this run", with no effect on the CPU value.

import Foundation

public enum BASMambaGPUShadowParity {

    /// Mean-absolute-error between the CPU and GPU selective-scan outputs for `inputs` under `shape`,
    /// or nil if the GPU is unavailable / either scan fails. Uses a FRESH actor per path so neither
    /// scan inherits the other's persisted hidden state (a clean, order-independent comparison).
    public static func parityMAE(
        inputs: BASMambaSSMScanInputs,
        shape: BASMambaSSMShape
    ) async -> Double? {
        let cpuState = BASMambaSSMState(shape: shape)
        let gpuState = BASMambaSSMState(shape: shape)
        guard let cpu = try? await cpuState.selectiveScan(inputs: inputs) else { return nil }
        // .gpuUnavailable (or any GPU error) → nil → "no shadow this run".
        guard let gpu = try? await gpuState.selectiveScanGPU(inputs: inputs) else { return nil }
        guard !cpu.y.isEmpty, cpu.y.count == gpu.y.count else { return nil }
        var sum = 0.0
        for i in cpu.y.indices {
            let d = Double(cpu.y[i]) - Double(gpu.y[i])
            sum += d < 0 ? -d : d
        }
        return sum / Double(cpu.y.count)
    }
}
