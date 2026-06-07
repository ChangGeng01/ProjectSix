// ADR-039 — the hybrid-determinism-boundary tripwire + BASApproxValue unit tests.
//
// The byte-deterministic SPINE (writers of the risk card / verdict / commit-token / durable stores /
// event-log / replay) must NEVER name a Metal dispatcher, `BASApproxValue`, or `approximateOnly` — if it
// does, a non-bit-reproducible Metal value could reach governance / durable-write / replay and break
// ch883 replay-stability. This test greps the real spine sources and FAILS THE BUILD on any reference.
// A Metal value may only reach the spine through `snapToDeterministic` (an audited deterministic snap),
// which happens in a boundary adapter — never in a spine file.

import XCTest
@testable import BASMetalSubstrate

final class BASMetalDeterminismBoundaryTests: XCTestCase {

    /// The byte-deterministic spine (relative to Sources/). A NEW spine writer MUST be added here, or the
    /// boundary guard has a hole. Representative + load-bearing set (governance + durable + replay).
    private static let spineFiles: [String] = [
        // Governance (risk → permit → verdict → commit-token)
        "BASHostKit/EBrainRuntimeCoordinator+SovereignVerdict.swift",
        "BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift",
        "BASHostKit/EBrainRuntimeCoordinator+Permit.swift",
        "BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift",
        "BASSovereign/BASSovereignVerdictEngine.swift",
        // Durable stores + event log
        "BASHostKit/BASSQLBrainHistoryStore.swift",
        "BASHostKit/BASRustBrainHistoryStore.swift",
        "BASMemory/BASSQLiteMemoryAtomStore.swift",
        "BASRuntimeCore/BASSQLiteEventLogStorage.swift",
        // Replay determinism
        "BASHostKit/BASEBrainTurnResultReplayDigest.swift",
        "BASHostKit/BASEBrainTurnResultReplayCanonicalizer.swift",
    ]

    /// Symbols that must NOT appear in any spine file (a Metal value crossing the boundary raw).
    private static let bannedInSpine: [String] = [
        "approximateOnly",                              // the un-snap escape hatch
        "BASApproxValue",                               // the spine receives only snapped plain T
        "BASMetalTopKDispatcher",
        "BASMetalSSMScanDispatcher",
        "BASMetalCosineSimilarityDispatcher",
        "BASMetalBatchedCosineSimilarityDispatcher",
        "BASMetalAttentionDispatcher",
        "BASMetalFlashAttentionDispatcher",
        "BASMetalMatMulDispatcher",
        "BASMetalRMSNormDispatcher",
        "BASMetalKernelDispatchRouter",
    ]

    func testSpineFilesAreFreeOfMetalSymbols() throws {
        let sources = Self.sourcesDir()
        var checked = 0
        for rel in Self.spineFiles {
            let url = sources.appendingPathComponent(rel)
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                XCTFail("spine file not found — update the allowlist or fix the path: \(rel)")
                continue
            }
            checked += 1
            for banned in Self.bannedInSpine {
                XCTAssertFalse(
                    content.contains(banned),
                    "DETERMINISM-BOUNDARY VIOLATION (ADR-039): spine file '\(rel)' references '\(banned)'. "
                    + "A non-bit-reproducible Metal value must NOT reach the byte-deterministic spine — "
                    + "cross only via snapToDeterministic in a boundary adapter, never in a spine file.")
            }
        }
        XCTAssertEqual(checked, Self.spineFiles.count, "every spine file must be present + checked")
    }

    // MARK: - BASApproxValue quarantine unit tests

    func testApproximateOnlyReturnsRaw() {
        let v = BASApproxValue([0.1, 0.2], provenance: .metal(kernel: "k", device: "gpu"))
        XCTAssertEqual(v.approximateOnly(), [0.1, 0.2])
        XCTAssertTrue(v.provenance.didRunOnGPU)
    }

    func testSnapToDeterministicRecordsAuditedCrossing() {
        let v = BASApproxValue(3.14159, provenance: .metal(kernel: "cosine", device: "gpu"))
        let (snapped, crossing) = v.snapToDeterministic(
            kernel: "cosine", snapDescription: "round-to-2dp") { (($0 * 100).rounded()) / 100 }
        XCTAssertEqual(snapped, 3.14, accuracy: 1e-9)
        XCTAssertEqual(crossing.kernel, "cosine")
        XCTAssertEqual(crossing.snapDescription, "round-to-2dp")
        XCTAssertEqual(crossing.provenance, .metal(kernel: "cosine", device: "gpu"))
    }

    func testMapPreservesProvenanceTaint() {
        let v = BASApproxValue(2, provenance: .cpuFallback(kernel: "topk"))
        let mapped = v.map { $0 * 10 }
        XCTAssertEqual(mapped.approximateOnly(), 20)
        XCTAssertEqual(mapped.provenance, .cpuFallback(kernel: "topk"))
        XCTAssertFalse(mapped.provenance.didRunOnGPU)
    }

    // Derive Sources/ from this test file's path: …/Tests/BehavioralAISubstrateTests/<this>.swift → root.
    private static func sourcesDir() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/BehavioralAISubstrateTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources")
    }
}
