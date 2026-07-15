import XCTest
import BASMemory
@testable import QinaoRuntime
@testable import QinaoMemory
@testable import QinaoSovereign

/// integration S1 (2026-07-12) — the runtime's own `memory` participates in sendSession.
///
/// Turn-path audit finding C: `QinaoRuntime.memory` was assigned in init and never read; the
/// L8 observation layer consumed only a caller-supplied `TurnInputs.memoryBundle`. S1 derives
/// the bundle from `memory.frontstageBundle()` when the caller supplies none.
///
/// Probe: `expectedCoverageLayerIDs: ["L8", "L14"]`. If L8 emits no summary the coverage
/// engine reports `.missingLayer("L8")` — so the finding's presence/absence is a
/// deterministic witness for whether memory reached the turn.
final class QinaoRuntimeMemorySeamTests: XCTestCase {

    /// deep-audit P1-7 (2026-07-13): the L8 auto-feed carries GOVERNED memory. Blind
    /// `admit(_:)` now holds as `.candidate` (no constitution → no promotion authority), so
    /// these seam probes admit through a permissive constitution — the real path a host with
    /// promotion authority uses to put frontstage-eligible memory in front of L8.
    private static let permissive: BASHostConstitution = {
        var c = BASHostConstitution(hostID: "seam-host", activeVersion: "v1")
        c.consentLattice.memoryWriteScope = "all"
        c.consentLattice.memoryPromotionScope = "auto"
        return c
    }()

    private func inputs(
        fx: QinaoTestFixture, turnID: String
    ) -> QinaoRuntime.TurnInputs {
        QinaoRuntime.TurnInputs(
            observations: fx.observations(turnID: turnID),
            coordinatorSeverity: nil
        ).with { $0.expectedCoverageLayerIDs = ["L8", "L14"] }
    }

    private func hasMissingL8(
        _ outcome: QinaoRuntime.TurnOutcome
    ) -> Bool {
        outcome.coverage.findings.contains(.missingLayer(layerID: "L8"))
    }

    /// An admitted atom + nil memoryBundle → the runtime derives the L8 bundle from its own
    /// memory → L8 emits → no missing-layer finding. RED without the S1 injection.
    func testAdmittedMemoryReachesL8WithoutCallerBundle() async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.memory.admit(QinaoMemory.AdmitRequest(
            kind: .semantic, content: "operator prefers tea over coffee",
            scope: .session, sensitivity: .low, confidence: 0.9),
            under: Self.permissive)

        let outcome = try await fx.runtime.sendSession(inputs(fx: fx, turnID: "turn.mem1"))
        XCTAssertFalse(hasMissingL8(outcome),
            "with an admitted atom and no caller bundle, the runtime must derive L8 from its own memory")
    }

    /// Empty memory + nil bundle → byte-equal to pre-S1 semantics: L8 skips, finding present.
    func testEmptyMemoryKeepsL8Skipped() async throws {
        let fx = await QinaoTestFixture.make()
        let outcome = try await fx.runtime.sendSession(inputs(fx: fx, turnID: "turn.mem2"))
        XCTAssertTrue(hasMissingL8(outcome),
            "empty memory must NOT synthesize a phantom L8 bundle (pre-S1 semantics preserved)")
    }

    /// A caller-supplied bundle always wins — the injection only fills nil.
    func testCallerSuppliedBundleWins() async throws {
        let fx = await QinaoTestFixture.make()
        // memory has an atom, AND the caller supplies an explicit bundle
        _ = try await fx.memory.admit(QinaoMemory.AdmitRequest(
            kind: .semantic, content: "memory-side atom",
            scope: .session, sensitivity: .low, confidence: 0.9))
        let callerBundle = BASMemoryBundle(
            atoms: [QinaoMemory.memoryAtom(
                from: BASGovernedMemory(
                    kind: .episodic, content: "caller-side atom", scope: .session,
                    sensitivity: .low, tier: .hot, confidence: 0.8,
                    sourceType: "caller", governanceStatus: .governed,
                    provenanceSummary: "test"),
                fallbackTimestamp: Date(timeIntervalSince1970: 1_700_000_000))],
            retrievedAt: Date(timeIntervalSince1970: 1_700_000_000))

        var turnInputs = inputs(fx: fx, turnID: "turn.mem3")
        turnInputs.memoryBundle = callerBundle
        let outcome = try await fx.runtime.sendSession(turnInputs)
        XCTAssertFalse(hasMissingL8(outcome), "caller bundle must flow to L8 untouched")
    }

    // MARK: - frontstageBundle mapping pins (mirror of the BASHostKit canonical projection)

    func testFrontstageBundleMapsCanonicalFields() async throws {
        let memory = QinaoMemory(now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let admitted = try await memory.admit(QinaoMemory.AdmitRequest(
            kind: .profile, content: "prefers dark mode",
            scope: .user, sensitivity: .high, confidence: 0.83,
            preferredTier: .hot, sourceType: "host-settings"),
            under: Self.permissive)

        let bundle = await memory.frontstageBundle(activeHostVersion: "host.v9")
        let atom = try XCTUnwrap(bundle?.atoms.first)
        XCTAssertEqual(atom.memoryID, admitted.id.uuidString)
        XCTAssertEqual(atom.summary, "prefers dark mode")
        XCTAssertEqual(atom.contentType, .hot)
        XCTAssertEqual(atom.source, "host-settings")
        XCTAssertEqual(atom.confidence, 0.83, accuracy: 1e-12)
        XCTAssertEqual(atom.riskRelevance, 0.82, accuracy: 1e-12)   // .high sensitivity
        XCTAssertEqual(atom.hostRelevance, 0.88, accuracy: 1e-12)   // .profile kind
        XCTAssertEqual(atom.promotionState, .admitted)              // .governed
        XCTAssertFalse(atom.frozen)
        XCTAssertEqual(atom.conflictFingerprint, admitted.id.uuidString)
        XCTAssertEqual(bundle?.activeHostVersion, "host.v9")
        XCTAssertEqual(bundle?.conflictRefs, [])                    // nothing frozen
    }

    func testFrontstageBundleNilWhenEmpty() async {
        let memory = QinaoMemory()
        let bundle = await memory.frontstageBundle()
        XCTAssertNil(bundle, "empty memory must not synthesize a bundle")
    }
}
