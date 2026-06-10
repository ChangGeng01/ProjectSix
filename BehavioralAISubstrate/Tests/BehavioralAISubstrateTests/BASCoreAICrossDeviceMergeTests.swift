import XCTest
@testable import BASAppleAdapters
import BASMemory

/// T1.1 — CoreAI cross-device merge: fold TWO devices' coreai-e2e campaign logs through the REAL migration gate
/// (`BASCoreAIVerdictEvidenceComposer` → `BASCoreAIMigrationVerdict`) with `distinctDeviceCount=2` and the
/// operator-supplied paired memory from the standalone single-model runs.
///
/// Env-gated (default suite stays hermetic): `BAS_COREAI_MERGE_LOG1` + `BAS_COREAI_MERGE_LOG2` point at the two
/// pulled device logs; `BAS_COREAI_MEM_CANDIDATE_BYTES` + `BAS_COREAI_MEM_INCUMBENT_BYTES` carry the paired
/// memory evidence (paired-or-nothing — the composer refuses half a pair). Mirrors
/// `BASSpecDecodeCrossDeviceMergeTests`: the gate code is REUSED, never reimplemented.
///
/// Record reconstruction from the probe's own per-prompt lines:
///   `📊 coreai-e2e text=<i> incumbent=<L> candidate=<L> agree=<b> mae=<f|n/a> latency_ms=<f> inc_ms=<f>`
final class BASCoreAICrossDeviceMergeTests: XCTestCase {

    private func records(fromLog log: String, device: String) -> [BASShadowTrialRecord] {
        let pattern = #"coreai-e2e text=(\d+) incumbent=(\S+) candidate=(\S+) agree=(\S+) "#
            + #"mae=(\S+) latency_ms=([0-9.]+) inc_ms=([0-9.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var out: [BASShadowTrialRecord] = []
        for line in log.split(separator: "\n").map(String.init) {
            guard let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { continue }
            func group(_ i: Int) -> String {
                Range(m.range(at: i), in: line).map { String(line[$0]) } ?? ""
            }
            let effects = [
                "incumbent_label: \(group(2))",
                "candidate_label: \(group(3))",
                "labels_agree: \(group(4))",
                "logits_mae: \(group(5))",
                "candidate_latency_ms: \(group(6))",
                "incumbent_latency_ms: \(group(7))",
            ]
            out.append(BASShadowTrialRecord(
                trialID: "\(device)-coreai-\(group(1))",
                candidateRef: "coreai-classifier",
                trialScope: BASCoreAIVerdictEvidenceComposer.trialScope,
                observedEffects: effects,
                completionState: "observing"))
        }
        return out
    }

    func testMergeTwoDeviceCoreAICampaigns() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path1 = env["BAS_COREAI_MERGE_LOG1"], let path2 = env["BAS_COREAI_MERGE_LOG2"] else {
            throw XCTSkip("set BAS_COREAI_MERGE_LOG1/LOG2 to two pulled coreai-e2e campaign logs to run the merge")
        }
        let log1 = try String(contentsOfFile: path1, encoding: .utf8)
        let log2 = try String(contentsOfFile: path2, encoding: .utf8)
        let merged = records(fromLog: log1, device: "device1") + records(fromLog: log2, device: "device2")
        XCTAssertFalse(merged.isEmpty, "no coreai-e2e records reconstructed — are these campaign logs?")

        // Paired-or-nothing memory evidence from the standalone single-model runs.
        let memCandidate = env["BAS_COREAI_MEM_CANDIDATE_BYTES"].flatMap(Int.init)
        let memIncumbent = env["BAS_COREAI_MEM_INCUMBENT_BYTES"].flatMap(Int.init)
        let memPair = (memCandidate != nil && memIncumbent != nil)
            ? (memCandidate, memIncumbent) : (nil, nil)

        let (verdict, composition) = BASCoreAIVerdictEvidenceComposer.decide(
            records: merged,
            distinctDeviceCount: 2,
            candidatePeakMemoryBytes: memPair.0,
            incumbentPeakMemoryBytes: memPair.1)
        print("===== COREAI CROSS-DEVICE MERGED VERDICT (distinctDeviceCount=2) =====")
        print(BASCoreAIVerdictEvidenceComposer.render(verdict: verdict, composition: composition))
        print("(honest bound: two devices, ONE hardware model — both iPhone Air; memory pair from standalone "
            + "single-model sampled-max runs)")
        XCTAssertNotNil(verdict.recommendation)   // the merge only RENDERS; a human reads the verdict
    }
}
