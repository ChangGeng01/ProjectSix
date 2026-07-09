import XCTest
@testable import BASEvaluation

/// audit organ-eval MED-3 — the judge now READS the pre-registered block-structure
/// fields: `mirroredBlocks` (the mirror block must exist — a single-block arm can't
/// satisfy the two-block same-sign realEffect test, so it is an explicit DNF, not a
/// silent .artifactSuspect) and `measuredPerArmBlock` (each block needs its own
/// measured quorum, not just the pooled total).
final class BASABBlockStructureTests: XCTestCase {

    private func rows(arm: String, block: Int, tps: Double, n: Int) -> [BASABMeasurementRow] {
        (0..<n).map { g in
            BASABMeasurementRow(block: block, arm: arm, gen: g + 1, prompt: g % 3,
                tokens: 192, seconds: 192.0 / tps, thermal: 0, measured: true, tokHash: nil)
        }
    }
    private func spec() -> BASABProtocolSpec {
        BASABProtocolSpec(arms: ["cand", "inc"], incumbentArm: "inc",
                          mirroredBlocks: true, measuredPerArmBlock: 6, minMeasuredRowsPerArm: 8)
    }
    private func incumbent() -> [BASABMeasurementRow] {
        rows(arm: "inc", block: 0, tps: 10, n: 6) + rows(arm: "inc", block: 1, tps: 10, n: 6)
    }
    private func finding(_ rows: [BASABMeasurementRow]) -> BASABArmFinding.Finding? {
        BASABJudge.judge(spec: spec(), rows: rows).arms.first { $0.arm == "cand" }?.finding
    }

    func testSingleBlockCandidateIsDNFNotSilentArtifact() {
        // 12 measured rows but ALL in block 0 — passes the pooled quorum yet has no
        // mirror block, so the two-block realEffect test is unreachable.
        let r = incumbent() + rows(arm: "cand", block: 0, tps: 12, n: 12)
        XCTAssertEqual(finding(r), .dnf,
            "a single-block arm (mirror required) must be DNF, not a silent artifactSuspect/realEffect")
    }

    func testBelowPerBlockQuorumIsDNF() {
        // 2 blocks, but block 1 has only 3 measured rows (< measuredPerArmBlock=6)
        let r = incumbent() + rows(arm: "cand", block: 0, tps: 12, n: 6) + rows(arm: "cand", block: 1, tps: 12, n: 3)
        XCTAssertEqual(finding(r), .dnf, "an arm below the per-block measured quorum must be DNF")
    }

    func testWellFormedCandidateNotDNFForStructure() {
        // 2 blocks × 6, ±1% vs incumbent ⇒ parity (well-formed, not a structure DNF)
        let r = incumbent() + rows(arm: "cand", block: 0, tps: 10.1, n: 6) + rows(arm: "cand", block: 1, tps: 9.9, n: 6)
        XCTAssertEqual(finding(r), .parity, "a well-formed parity arm is judged, not DNF'd for structure")
    }
}
