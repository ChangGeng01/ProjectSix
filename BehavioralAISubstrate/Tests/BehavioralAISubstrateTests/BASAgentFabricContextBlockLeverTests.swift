// ADR-038 §6 — tests for the feed-forward contextBlock falsification lever: the host can
// shrink the enriched prefill (smaller char cap and/or top-1 conclusion only) to test
// whether a smaller out-of-distribution prefill clears the on-device MLX wedge. Defaults
// reproduce the prior behavior EXACTLY (byte-equal-off).

import XCTest
@testable import BASHostKit

final class BASAgentFabricContextBlockLeverTests: XCTestCase {

    private func conclusion(_ i: Int) -> BASAgentFabricAuthoritativeInput.Conclusion {
        BASAgentFabricAuthoritativeInput.Conclusion(
            deltaID: "d\(i)",
            domain: "planner.primary.objective.\(i)",
            deltaType: "risk",
            confidence: 0.8,
            summary: "summary-\(i)",
            reasonCodes: ["evidence.recent"])
    }

    /// Shrinking `maxChars` truncates the block (the ADR-038 §6 size lever).
    func testContextBlockRespectsSmallerMaxChars() {
        let cs = (0..<8).map(conclusion)
        let full = BASAgentFabricAuthoritativeProjection.contextBlock(
            sourceTurnID: "T1", conclusions: cs, maxChars: 10_000)   // untruncated
        let small = BASAgentFabricAuthoritativeProjection.contextBlock(
            sourceTurnID: "T1", conclusions: cs, maxChars: 128)      // shrunk
        XCTAssertGreaterThan(full.count, 128, "the full block should exceed the small cap")
        XCTAssertLessThanOrEqual(small.count, 128, "the shrunk block must respect maxChars")
        XCTAssertLessThan(small.count, full.count)
    }

    /// fold-top-1-only keeps ONLY the first conclusion (and the header reflects 1).
    func testContextBlockTopConclusionsOnlyFoldsToOne() {
        let cs = (0..<5).map(conclusion)
        let folded = BASAgentFabricAuthoritativeProjection.contextBlock(
            sourceTurnID: "T1", conclusions: cs, topConclusionsOnly: true)
        XCTAssertTrue(folded.contains("1 accepted delta(s)"), "header must reflect the single folded conclusion")
        let conclusionLines = folded.split(separator: "\n").filter { $0.hasPrefix("- ") }
        XCTAssertEqual(conclusionLines.count, 1, "fold-top-1 must keep exactly one conclusion line")
    }

    /// Defaults reproduce the prior behavior EXACTLY (byte-equal-off) — what `project` relies on.
    func testContextBlockDefaultsAreByteEqual() {
        let cs = (0..<3).map(conclusion)
        let viaDefaults = BASAgentFabricAuthoritativeProjection.contextBlock(
            sourceTurnID: "T1", conclusions: cs)
        let viaExplicit = BASAgentFabricAuthoritativeProjection.contextBlock(
            sourceTurnID: "T1", conclusions: cs, maxChars: 512, topConclusionsOnly: false)
        XCTAssertEqual(viaDefaults, viaExplicit)
    }
}
