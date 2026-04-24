import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// M90 — BAS-side tests for the per-turn observation-bundle parallel
/// storage on `BASSovereignAuditLedger`.
///
/// Pins:
///
/// 1. **Opt-in streaming** — a ledger that never receives
///    `recordObservationBundle(_:)` reports `observationBundleCount()
///    == 0` and returns `nil` on every lookup. Pre-M90 behaviour
///    preserved byte-for-byte.
///
/// 2. **Store + query** — `recordObservationBundle(_:)` persists; the
///    `observationBundle(forSession:turn:)` / `observationBundles(
///    forSession:)` / `observationBundleSnapshot()` reads return the
///    bundles.
///
/// 3. **Last-write-wins on same (session, turn)** — re-recording for
///    the same key replaces in place. First-seen insertion order
///    preserved.
///
/// 4. **Hash-chain untouched** — every test appends a real audit
///    entry first, then streams bundles, then verifies chain
///    integrity. The parallel storage must not bleed into the
///    hash chain or the signature ring.
///
/// 5. **Cross-session isolation** — streaming bundles for session A
///    does not appear in session B's queries.
///
/// 6. **Snapshot is a value copy** — mutating the returned array
///    does not mutate the ledger's own storage (discipline pattern
///    matching `coverageVerdictSnapshot()`).
final class BASSovereignAuditLedgerObservationStreamingTests: XCTestCase {

    // MARK: - Fixtures

    private func makeLedger() -> BASSovereignAuditLedger {
        BASSovereignAuditLedger.withSeed(
            "m90-observation-streaming-seed")
    }

    private func makeEntry(
        auditID: String,
        session: String = "session-m90",
        turn: String = "turn-1"
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: "verdict-m90",
            ruleIDs: ["BR-001"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-m90",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func makeSummary(
        layer: BASCognitiveLayer,
        turn: String = "turn-1",
        session: String = "session-m90",
        totalObservations: Int = 3,
        hasCoreSignalCoverage: Bool = true
    ) -> BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: layer,
            turnID: turn,
            sessionID: session,
            totalObservations: totalObservations,
            distinctSubjectCount: totalObservations,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost: 0.25,
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func makeReport(
        turn: String = "turn-1",
        session: String = "session-m90",
        layers: [BASCognitiveLayer] = [.sovereign]
    ) -> BASObservationReconciliationReport {
        BASObservationReconciliationReport(
            turnID: turn,
            sessionID: session,
            summaries: layers.map {
                makeSummary(layer: $0, turn: turn, session: session)
            })
    }

    // MARK: - 1. Opt-in streaming (pre-M90 behaviour preserved)

    func testLedgerWithoutStreamingReportsZeroBundleCount()
        async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))

        let count = await ledger.observationBundleCount()
        XCTAssertEqual(count, 0,
            "pre-M90 behaviour: no streaming until recorded")

        let lookup = await ledger.observationBundle(
            forSession: "session-m90", turn: "turn-1")
        XCTAssertNil(lookup)

        let sessionBundles = await ledger.observationBundles(
            forSession: "session-m90")
        XCTAssertTrue(sessionBundles.isEmpty)
    }

    // MARK: - 2. Store + query

    func testRecordObservationBundlePersists() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        let report = makeReport(layers: [.dreamLoop, .sovereign])

        await ledger.recordObservationBundle(report)

        let count = await ledger.observationBundleCount()
        XCTAssertEqual(count, 1)

        let lookup = await ledger.observationBundle(
            forSession: "session-m90", turn: "turn-1")
        XCTAssertNotNil(lookup)
        XCTAssertEqual(
            lookup?.summaries.map(\.layer),
            [.dreamLoop, .sovereign])
    }

    func testSnapshotExposesAllStreamedBundles() async throws {
        let ledger = makeLedger()
        let r1 = makeReport(turn: "turn-1")
        let r2 = makeReport(turn: "turn-2")
        let r3 = makeReport(turn: "turn-3")
        await ledger.recordObservationBundle(r1)
        await ledger.recordObservationBundle(r2)
        await ledger.recordObservationBundle(r3)

        let snap = await ledger.observationBundleSnapshot()
        XCTAssertEqual(snap.count, 3)
        XCTAssertEqual(
            snap.map(\.turnID),
            ["turn-1", "turn-2", "turn-3"],
            "first-seen insertion order preserved")
    }

    // MARK: - 3. Last-write-wins on same (session, turn)

    func testReRecordReplacesInPlaceAndKeepsInsertionOrder()
        async throws {
        let ledger = makeLedger()
        let original = makeReport(
            turn: "turn-1",
            layers: [.sovereign])
        let replacement = makeReport(
            turn: "turn-1",
            layers: [.sovereign, .dreamLoop, .triSelfTribunal])
        let other = makeReport(turn: "turn-2", layers: [.sovereign])

        await ledger.recordObservationBundle(original)
        await ledger.recordObservationBundle(other)
        await ledger.recordObservationBundle(replacement)

        let count = await ledger.observationBundleCount()
        XCTAssertEqual(count, 2,
            "re-record for same key replaces, does not append")

        let lookup = await ledger.observationBundle(
            forSession: "session-m90", turn: "turn-1")
        XCTAssertEqual(lookup?.summaries.count, 3,
            "replacement value is the stored one")

        let snap = await ledger.observationBundleSnapshot()
        XCTAssertEqual(
            snap.map(\.turnID),
            ["turn-1", "turn-2"],
            "turn-1 retains its original insertion position")
    }

    // MARK: - 4. Hash-chain integrity untouched

    func testHashChainIntegrityHoldsAfterStreamingBundles()
        async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))
        await ledger.recordObservationBundle(
            makeReport(turn: "turn-1"))
        await ledger.recordObservationBundle(
            makeReport(turn: "turn-2"))

        // Streaming bundles must not modify the audit chain.
        try await ledger.verifyChainIntegrity()
    }

    // MARK: - 5. Cross-session isolation

    func testObservationBundlesPerSessionAreIsolated() async throws {
        let ledger = makeLedger()
        let sessionA = makeReport(
            turn: "turn-1", session: "sess-A")
        let sessionBturn1 = makeReport(
            turn: "turn-1", session: "sess-B")
        let sessionBturn2 = makeReport(
            turn: "turn-2", session: "sess-B")
        await ledger.recordObservationBundle(sessionA)
        await ledger.recordObservationBundle(sessionBturn1)
        await ledger.recordObservationBundle(sessionBturn2)

        let aBundles = await ledger.observationBundles(
            forSession: "sess-A")
        let bBundles = await ledger.observationBundles(
            forSession: "sess-B")
        XCTAssertEqual(aBundles.count, 1)
        XCTAssertEqual(bBundles.count, 2)

        // Lookups by (session, turn) scope correctly.
        let aLookup = await ledger.observationBundle(
            forSession: "sess-A", turn: "turn-1")
        let bLookup = await ledger.observationBundle(
            forSession: "sess-B", turn: "turn-2")
        let crossLookup = await ledger.observationBundle(
            forSession: "sess-B", turn: "turn-1")  // exists
        let missLookup = await ledger.observationBundle(
            forSession: "sess-A", turn: "turn-2")  // does not
        XCTAssertNotNil(aLookup)
        XCTAssertNotNil(bLookup)
        XCTAssertNotNil(crossLookup)
        XCTAssertNil(missLookup)
    }

    // MARK: - 6. Snapshot is a value copy

    func testSnapshotIsValueCopyAndDoesNotMutateLedger() async {
        let ledger = makeLedger()
        await ledger.recordObservationBundle(
            makeReport(turn: "turn-1"))

        var snap = await ledger.observationBundleSnapshot()
        XCTAssertEqual(snap.count, 1)
        snap.removeAll()

        // Mutating the returned snapshot must not affect ledger state.
        let post = await ledger.observationBundleCount()
        XCTAssertEqual(post, 1, "snapshot is a value-copy")
    }

    // MARK: - 7. Full 14-layer payload survives round-trip

    func testFullFourteenLayerBundleRoundTrips() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-full"))
        let all14: [BASCognitiveLayer] = [
            .leaseLife, .neuralOrgan, .thoughtFold, .worldPrior,
            .hostConstitution, .presenceEye, .mirrorBlade,
            .hippocampalWell, .dreamLoop, .triSelfTribunal,
            .riskClimate, .gentleHand, .evolutionFurnace, .sovereign
        ]
        let full = makeReport(layers: all14)
        await ledger.recordObservationBundle(full)

        let back = await ledger.observationBundle(
            forSession: "session-m90", turn: "turn-1")
        XCTAssertEqual(back?.summaries.count, 14,
            "all 14 layers round-trip")
        XCTAssertEqual(
            back?.summaries.map(\.layer), all14,
            "layer ordering is stable")
    }

    // MARK: - 8. Streaming coexists with coverage verdicts

    func testStreamingCoexistsWithCoverageVerdictsSameKey()
        async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-coexist"))
        // Record a coverage verdict (M45 surface) first.
        let verdict = BASObservationReconciliationVerdict(
            turnID: "turn-1",
            sessionID: "session-m90",
            severity: .clean,
            findings: [],
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000))
        await ledger.recordCoverageVerdict(verdict)
        // Also stream the observation bundle for the same key.
        await ledger.recordObservationBundle(makeReport())

        let coverage = await ledger.coverageVerdict(
            forSession: "session-m90", turn: "turn-1")
        let bundle = await ledger.observationBundle(
            forSession: "session-m90", turn: "turn-1")
        XCTAssertNotNil(coverage)
        XCTAssertNotNil(bundle)
        // The two surfaces are independent — neither affects the other.
        let coverageCount = await ledger.coverageVerdictCount()
        let bundleCount = await ledger.observationBundleCount()
        XCTAssertEqual(coverageCount, 1)
        XCTAssertEqual(bundleCount, 1)
    }
}
