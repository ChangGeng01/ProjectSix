// MARK: - BASMambaProbe
// chapter 一千零三十三 / M3905 — on-device Mamba SSM exercise
//
// ## Mandate
//
// User mandate「全面 解决 scaffold/backlog 最严苛 最诚实」。 Two parallel
// triage agents found ch 1033(Mamba SSM endurance)is a genuine
// Bucket-A(honestly-closable-now)item — the BACKLOG's "~50 LOC
// synthetic input" estimate was STALE:`BASMetalBenchmarkHarness
// .runMambaScan(batch:hiddenDim:stateDim:sequenceLength:)` takes plain
// Int args and SELF-SYNTHESIZES its inputs internally(x/delta/a/b/c),
// and is already proven by 2 passing XCTests
// (`BASMambaBenchmarkExpansionTests`)。 So exercising the Mamba
// selective-scan(biomimetic state-space layer)on a physical iPhone
// is just cloning the ch 1034 `BASMPSGraphProbe` pattern。
//
// ## What this closes
//
// The 10-hour + 1-hour endurance runs exercised MLX + L0-L14 cascade +
// MPSGraph kernels(ch 1034)but NEVER the Mamba SSM path — it was the
// top「NYI」 line in the boot inventory。 This probe runs the real
// CPU + GPU selective-scan on-device,proving the substrate's
// biomimetic SSM layer resolves + executes on the A19。
//
// Emitted as `📊 ch1033 mamba …`(idevicesyslog-visible,os.Logger,
// same pattern as ch 1027/1034 probes)。 Serial,runs once at boot,
// never concurrent with MLX(no GPU contention)。

import Foundation
import os
import BASMetalSubstrate

enum BASMambaProbe {

    private static let log = Logger(
        subsystem: "com.changgeng.basdevicetest",
        category: "ch1033-mamba")

    /// Run the Mamba selective-scan(CPU + GPU)on-device,emit a
    /// detail line,return a short verdict for the UI surface。 async
    /// because `runMambaScan` is async。
    @discardableResult
    static func run() async -> String {
        emit("📊 ch1033 mamba START")
        let harness = BASMetalBenchmarkHarness()
        do {
            // Small shape — exercise the scan path,not stress it。
            // Self-synthesizes x/delta/a/b/c internally。
            let report = try await harness.runMambaScan(
                batch: 1, hiddenDim: 8, stateDim: 8,
                sequenceLength: 32,
                warmupIterations: 2,
                timedIterations: 5)
            let cpuOK = report.cpuMicrosecondsMean > 0
                && !report.cpuMicrosecondsMean.isNaN
            // GPU may be unavailable(simulator)— that's not a fail,
            // the CPU selective-scan still proves the path runs。
            let gpuNote = report.gpuAvailable
                ? String(format: "gpu_mean_us=%.1f speedup=%.2f",
                         report.gpuMicrosecondsMean,
                         report.speedupMean)
                : "gpu=unavailable"
            emit(String(format:
                "📊 ch1033 mamba cpu_mean_us=%.1f " +
                "cpu_p95_us=%.1f samples=%d %@",
                report.cpuMicrosecondsMean,
                report.cpuMicrosecondsP95,
                report.cpuMicrosecondsSamples.count,
                gpuNote))
            let allOK = cpuOK
            emit("📊 ch1033 mamba VERDICT all_ok=\(allOK)")
            return allOK
                ? "✓ cpu scan ok (" +
                  String(format: "%.0fµs", report.cpuMicrosecondsMean)
                  + ")"
                : "✗ FAIL (see ch1033 log)"
        } catch {
            emit("⚠️ ch1033 mamba error=\(error)")
            return "✗ error"
        }
    }

    private static func emit(_ line: String) {
        print(line)
        log.notice("\(line, privacy: .public)")
    }
}
