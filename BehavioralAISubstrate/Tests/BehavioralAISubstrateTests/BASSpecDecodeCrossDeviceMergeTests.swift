import XCTest
@testable import BASAppleAdapters
import BASMemory

/// 结构大重构 — Phase 6 cross-device merge: fold TWO devices' spec-decode cert logs through the REAL gate
/// (`BASSpeculativeShadowComposer` / `BASSpeculativeMigrationVerdict`) with `distinctDeviceCount=2`.
///
/// Env-gated like the other capture-driven tests: set `BAS_SPEC_MERGE_LOG1` + `BAS_SPEC_MERGE_LOG2` to the two
/// pulled `spec-decode-<stamp>.log` files (and optionally `BAS_SPEC_MERGE_BUDGET_MB`). Unset ⇒ skip (the default
/// suite stays hermetic). The merge REUSES the production composer/verdict — no reimplementation drift.
///
/// Record reconstruction from the per-device log lines (the probe's own emissions):
///   `📊 spec-decode lane=<mode> p=<i> spec_ms=<ms>`                        → speculative side
///   `📊 spec-decode lane=baseline p=<i> greedy_ms=<ms> sampling_ms=<ms>`   → paired baselines
///   `  correctness=verified|FAILED` (per-mode render line)                 → per-mode aggregate correctness
///   `📊 spec-decode tier=<t> dual_peak_mb=<mb>`                            → per-device dual peak (max of both)
final class BASSpecDecodeCrossDeviceMergeTests: XCTestCase {

    private struct DeviceCapture {
        var specMs: [String: [Int: Double]] = [:]        // mode → promptIndex → ms
        var baseGreedyMs: [Int: Double] = [:]
        var baseSamplingMs: [Int: Double] = [:]
        var correctness: [String: Bool] = [:]            // mode → aggregate verified
        var dualPeakMB: Int = 0
    }

    private func parse(log: String) -> DeviceCapture {
        var capture = DeviceCapture()
        var currentRenderMode: String?
        for line in log.split(separator: "\n").map(String.init) {
            if let m = match(line, #"lane=(greedy|sampling) p=(\d+) spec_ms=([0-9.]+)"#) {
                capture.specMs[m[0], default: [:]][Int(m[1])!] = Double(m[2])!
            } else if let m = match(line, #"lane=baseline p=(\d+) greedy_ms=([0-9.]+) sampling_ms=([0-9.]+)"#) {
                capture.baseGreedyMs[Int(m[0])!] = Double(m[1])!
                capture.baseSamplingMs[Int(m[0])!] = Double(m[2])!
            } else if let m = match(line, #"speculative-decode-gate mode=(greedy|sampling)"#) {
                currentRenderMode = m[0]
            } else if line.contains("correctness="), let mode = currentRenderMode {
                if line.contains("correctness=verified") { capture.correctness[mode] = true }
                else if line.contains("correctness=FAILED") { capture.correctness[mode] = false }
            } else if let m = match(line, #"dual_peak_mb=(\d+)"#) {
                capture.dualPeakMB = max(capture.dualPeakMB, Int(m[0])!)
            }
        }
        return capture
    }

    private func match(_ line: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else { return nil }
        return (1..<m.numberOfRanges).compactMap {
            Range(m.range(at: $0), in: line).map { String(line[$0]) }
        }
    }

    private func records(from capture: DeviceCapture, device: String) -> [BASShadowTrialRecord] {
        var out: [BASShadowTrialRecord] = []
        for (mode, byPrompt) in capture.specMs {
            for (i, specMs) in byPrompt {
                let baseMs = mode == "greedy" ? capture.baseGreedyMs[i] : capture.baseSamplingMs[i]
                guard let baseMs else { continue }
                var effects = [
                    "mode: \(mode)",
                    "speculative_latency_ms: \(specMs)",
                    "baseline_latency_ms: \(baseMs)",
                ]
                // Per-mode aggregate correctness applies to every record of the mode (the probe's AND already
                // collapsed per-prompt outcomes; a FAILED aggregate honestly marks every record false).
                if let c = capture.correctness[mode] {
                    effects.append("correctness_verified: \(c)")
                }
                out.append(BASShadowTrialRecord(
                    trialID: "\(device)-\(mode)-\(i)",
                    candidateRef: "cross-device-merge",
                    trialScope: BASSpeculativeShadowComposer.trialScope,
                    observedEffects: effects,
                    completionState: "observing"))
            }
        }
        return out
    }

    func testMergeTwoDeviceCaptures() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path1 = env["BAS_SPEC_MERGE_LOG1"], let path2 = env["BAS_SPEC_MERGE_LOG2"] else {
            throw XCTSkip("set BAS_SPEC_MERGE_LOG1/LOG2 to two pulled spec-decode logs to run the merge")
        }
        let budgetMB = Int(env["BAS_SPEC_MERGE_BUDGET_MB"] ?? "6000") ?? 6000
        let log1 = try String(contentsOfFile: path1, encoding: .utf8)
        let log2 = try String(contentsOfFile: path2, encoding: .utf8)
        let c1 = parse(log: log1)
        let c2 = parse(log: log2)
        let merged = records(from: c1, device: "device1") + records(from: c2, device: "device2")
        XCTAssertFalse(merged.isEmpty, "no records reconstructed — are these spec-decode cert logs?")
        let dualPeak = max(c1.dualPeakMB, c2.dualPeakMB) * 1024 * 1024

        print("===== CROSS-DEVICE MERGED VERDICTS (distinctDeviceCount=2) =====")
        for mode in ["greedy", "sampling"] {
            let (verdict, composition) = BASSpeculativeShadowComposer.decide(
                records: merged,
                mode: mode,
                distinctDeviceCount: 2,
                dualPeakMemoryBytes: dualPeak > 0 ? dualPeak : nil,
                memoryBudgetBytes: budgetMB * 1024 * 1024)
            print(BASSpeculativeShadowComposer.render(verdict: verdict, composition: composition))
            // The merge NEVER auto-enables: whatever the verdict, this test only renders it for a human.
            XCTAssertNotNil(verdict.recommendation)
        }
        print("(honest bound: two devices, ONE hardware model — both iPhone Air; n_prompts/lane is small)")
    }
}
