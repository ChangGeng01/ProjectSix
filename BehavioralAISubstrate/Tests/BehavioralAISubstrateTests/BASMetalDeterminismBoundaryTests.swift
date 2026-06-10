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
        // Governance RISK MATH — the actual writers of riskCard.totalRisk + the softmax that feeds the
        // context frame + the ssmCaution that may RAISE risk. ADR-039 §10.2 "governance wall": these must be
        // CPU-only; a Metal/approximate shortcut into governance scoring is forbidden. (Red-team GAP-2a: the
        // list above named +RunTurn.swift but NOT these — where totalRisk is actually computed — a real hole.)
        "BASHostKit/EBrainHostRuntime+RiskService.swift",
        "BASHostKit/BASMLRiskService.swift",
        "BASHostKit/BASMLContextService.swift",
        "BASHostKit/BASSSMCautionInput.swift",
        // Durable stores + event log
        "BASHostKit/BASSQLBrainHistoryStore.swift",
        "BASHostKit/BASRustBrainHistoryStore.swift",
        "BASMemory/BASSQLiteMemoryAtomStore.swift",
        "BASRuntimeCore/BASSQLiteEventLogStorage.swift",
        // Replay determinism
        "BASHostKit/BASEBrainTurnResultReplayDigest.swift",
        "BASHostKit/BASEBrainTurnResultReplayCanonicalizer.swift",
        "BASHostKit/BASEBrainTurnResultReplayHarness.swift",
        // Commit-token AUTHORITY + gate (the consequential irreversible-op path — audit GAP: these were
        // omitted, yet they are byte-deterministic governance/commit spine writers).
        "BASSovereign/BASSovereignTokenAuthority.swift",
        "BASSovereign/BASSovereignCommitEnforcer.swift",
        "BASSovereign/BASSovereignGatedCommit.swift",
        "BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift",
    ]

    // NOTE on the CoreML asymmetry (audit LOW): the tripwire bans Metal *dispatchers* + BASApproxValue, but NOT
    // CoreML inference. That is INTENTIONAL + audited: `BASMLContextService`'s CoreML classification produces
    // approximate context-frame INPUTS (emotionalLoad / ambiguity / …) that the DETERMINISTIC CPU governance
    // then scores (softmax → riskCard.totalRisk → verdict). The approximate value feeds the INPUT side and is
    // gated by the verdict; it never crosses into a byte-deterministic spine field raw. The governance MATH
    // (softmax + totalRisk) is pure CPU + lives in files that ARE in the allowlist above.

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
        // audit-2 defense-in-depth: reasoning-side symbols (MLX runtime config + the FoundationModels
        // structured-output / tool bridges) must never reach the spine. Already structurally impossible
        // (Package.swift: spine modules can't import BASMLXAdapter/BASAppleAdapters), so this is belt-and-
        // suspenders for a future accidental dependency — specific type names, no false-trip on comments.
        "MLXRuntimeConfig",
        "BASGuidedSchemaTranslator",
        "BASToolPromptRenderer",
        // Core AI (ADR-039 extension): the Core AI small-head adapter + runner + NDArray bridge + shadow
        // comparison + migration verdict are reasoning-side — Core AI tensor inference produces approximate
        // context-frame INPUTS (gated by the verdict, observation-only), exactly the CoreML asymmetry noted
        // above. They must never reach a byte-deterministic spine file. NOTE: unlike the MLX entries, this ban
        // is LOAD-BEARING, not belt-and-suspenders — BASHostKit (which contains most spine files) DOES depend
        // on BASAppleAdapters (Package.swift), so a spine file could legally `import BASAppleAdapters` and call
        // these types; only this tripwire stops that. Specific type names (a comment naming them in a spine
        // file also trips — accepted: spine files shouldn't discuss reasoning-side types either).
        "BASCoreAIModelRunner",
        "BASCoreAIContextClassifierAdapter",
        "BASCoreAINDArrayBridge",
        "BASCoreAIShadowComparison",
        // The migration verdict RANKS migrate/don't-migrate from shadow evidence — a recommendation a human
        // reads, never an auto-promotion. Its provider-preference output must never reach the deterministic spine.
        "BASCoreAIMigrationVerdict",
        // ADR-041 §D — the task→provider matrix is reasoning-side (it RANKS providers by preference; governance
        // still RESOLVES + gates the choice). Provider preference must never reach a byte-deterministic spine file.
        "BASNeuralProviderMatrix",
    ]

    /// The SHARED matcher used by BOTH the production tripwire (`testSpineFilesAreFreeOfMetalSymbols`) AND its
    /// negative control (`testSpineGrepActuallyCatchesABannedSymbol`). Extracting it means the control
    /// genuinely guards the production predicate: a refactor that broke this matcher fails the control too.
    static func firstBannedSymbol(in content: String) -> String? {
        bannedInSpine.first { content.contains($0) }
    }

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
            if let banned = Self.firstBannedSymbol(in: content) {
                XCTFail(
                    "DETERMINISM-BOUNDARY VIOLATION (ADR-039): spine file '\(rel)' references '\(banned)'. "
                    + "A non-bit-reproducible Metal value must NOT reach the byte-deterministic spine — "
                    + "cross only via snapToDeterministic in a boundary adapter, never in a spine file.")
            }
        }
        XCTAssertEqual(checked, Self.spineFiles.count, "every spine file must be present + checked")
    }

    // MARK: - Negative control (red-team GAP-1b): the grep actually catches a violation

    /// The spine tripwire passes today because the spine files are clean — but a passing tripwire is only
    /// meaningful if the underlying predicate WOULD fail on a real violation. This runs the EXACT shared
    /// predicate the production test uses (`Self.firstBannedSymbol(in:)`) over a fixture that embeds a banned
    /// symbol and asserts it is detected — and, symmetrically, that a clean fixture is not falsely flagged. Now
    /// that both call the same matcher, a refactor that broke it fails THIS control too (not just silently
    /// leaving the production tripwire passing).
    func testSpineGrepActuallyCatchesABannedSymbol() {
        // A line that a determinism-boundary violation would look like in a spine file. It embeds
        // `approximateOnly` (bannedInSpine[0]) and `BASMetalTopKDispatcher`; the matcher returns the first hit
        // by bannedInSpine order, i.e. "approximateOnly".
        let violatingFixture = """
            import BASMetalSubstrate
            let score = BASMetalTopKDispatcher.shared.run(...)
            atom.confidence = score.approximateOnly()   // <-- raw Metal value into the spine
            """
        XCTAssertEqual(Self.firstBannedSymbol(in: violatingFixture), "approximateOnly",
            "the SHARED matcher MUST flag a fixture embedding a banned symbol — otherwise "
            + "testSpineFilesAreFreeOfMetalSymbols could pass vacuously")

        // Symmetric: a clean fixture (only the deterministic atomID crosses; value already snapped) must NOT
        // be flagged by the same matcher.
        let cleanFixture = """
            let key = retrieved.atomID            // only the deterministic key crosses
            atom.confidence = snapped             // already snapped via snapToDeterministic upstream
            """
        XCTAssertNil(Self.firstBannedSymbol(in: cleanFixture),
            "a clean fixture must not trip the shared banned-symbol matcher (no false positive)")
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
