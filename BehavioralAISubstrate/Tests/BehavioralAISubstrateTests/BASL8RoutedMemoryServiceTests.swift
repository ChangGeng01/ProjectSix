// Step 2 — proofs for the routed (Rust-cosine + SQL/event-store) memory backend.
//
// Proves: (1) retrieve() is deterministic for a fixed snapshot+frame; (2) it is VECTOR retrieval —
// it ranks the lexically/semantically closest atom first, which the Jaccard-over-typed-signals
// backend structurally cannot do (it has no text); (3) constitution restrictedMemoryDomains drop
// restricted atoms; (4) promote/freeze transitions + drainIntents() write governance changes to
// the store (a BASEventSourcedMemoryAtomStore would record these as the event/log/provenance
// trail); (5) refresh() materializes the snapshot; (6) retrieve() is SYNC (called without await —
// the ch883 contract this whole design preserves).

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASOrchestration

#if !os(iOS) // ch1022 source-gate (parity with BASMLMemoryServiceTests)
final class BASL8RoutedMemoryServiceTests: XCTestCase {

    // MARK: - Helpers

    private func budget() -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guard, maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 180,
            retrievalDepth: 3, precisionProfile: .protected, deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch, maintenanceAllowed: false)
    }
    private func profile() -> BASHostProfile { BASHostProfile(hostID: "test") }
    private func frame(_ text: String) -> BASDecomposeFrame {
        var f = BASDecomposeFrame()
        f.mirrorText = text
        return f
    }
    private func governed(
        id: UUID,
        content: String,
        domain: String,
        status: BASMemoryGovernanceStatus = .candidate,
        sensitivity: BASMemorySensitivity = .low
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id, kind: .semantic, content: content, scope: .user,
            sensitivity: sensitivity, tier: .warm, confidence: 0.7,
            sourceType: domain, governanceStatus: status, provenanceSummary: "test")
    }
    private func makeService(
        atoms: [BASGovernedMemory],
        restricted: [String] = [],
        store: (any BASMemoryAtomStore)? = nil
    ) -> BASL8RoutedMemoryService {
        BASL8RoutedMemoryService(
            loadAllAtoms: { atoms },
            syncEmbed: BASL8RoutedMemoryService.lexicalEmbed(),
            embeddingDimension: BASL8RoutedMemoryService.Parameters.defaultLexicalDimension,
            restrictedMemoryDomains: restricted,
            atomStore: store)
    }

    private let weatherID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let taxID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!

    // MARK: - 1. determinism

    func testRetrieveIsDeterministicForSameSnapshotAndFrame() async {
        let svc = makeService(atoms: [
            governed(id: weatherID, content: "weather forecast sunny rain", domain: "general"),
            governed(id: taxID, content: "tax invoice payment deadline", domain: "general"),
        ])
        await svc.refresh()
        let f = frame("will it rain today sunny weather")
        let r1 = svc.retrieve(decomposeFrame: f, hostContext: profile(), budget: budget())
        let r2 = svc.retrieve(decomposeFrame: f, hostContext: profile(), budget: budget())
        XCTAssertEqual(r1.atoms.map(\.memoryID), r2.atoms.map(\.memoryID))
        XCTAssertEqual(r1.atoms.map(\.confidence), r2.atoms.map(\.confidence))
    }

    // MARK: - 2. vector/semantic ranking (Jaccard-over-signals cannot do this)

    func testVectorRetrievalSurfacesSemanticallyClosestAtom() async {
        let svc = makeService(atoms: [
            governed(id: weatherID, content: "weather forecast sunny rain clouds", domain: "general"),
            governed(id: taxID, content: "tax invoice payment deadline office", domain: "general"),
        ])
        await svc.refresh()
        let r = svc.retrieve(
            decomposeFrame: frame("will it rain today sunny weather"),
            hostContext: profile(), budget: budget())
        XCTAssertFalse(r.atoms.isEmpty, "the weather query must recall the weather atom")
        XCTAssertEqual(r.atoms.first?.memoryID, weatherID.uuidString,
            "vector retrieval must rank the lexically/semantically closest atom first")
        XCTAssertFalse(r.atoms.contains { $0.memoryID == taxID.uuidString },
            "the unrelated tax atom must fall below the relevance floor")
    }

    // MARK: - 3. constitution domain filter

    func testConstitutionFilterDropsRestrictedDomain() async {
        let healthID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
        let svc = makeService(
            atoms: [governed(id: healthID, content: "blood pressure medication dosage", domain: "health")],
            restricted: ["health"])
        await svc.refresh()
        let r = svc.retrieve(
            decomposeFrame: frame("blood pressure medication"),
            hostContext: profile(), budget: budget())
        XCTAssertFalse(r.atoms.contains { $0.memoryID == healthID.uuidString },
            "restricted-domain atom must be filtered out before surfacing")
    }

    // MARK: - 4. promote transition + drain writes governed status

    func testPromoteTransitionsAndDrainWritesGovernedStatus() async {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000D4")!
        let g = governed(id: id, content: "user prefers dark mode", domain: "profile", status: .candidate)
        let store = BASInMemoryMemoryAtomStore(initial: [g])
        let svc = makeService(atoms: [g], store: store)
        await svc.refresh()

        let atom = BASL8RoutedMemoryService.memoryAtom(from: g) // promotionState == .candidate
        XCTAssertEqual(atom.promotionState, .candidate)
        let next = svc.promote(atom: atom, hostContext: profile())
        XCTAssertEqual(next, .admitted)

        let drained = await svc.drainIntents()
        XCTAssertEqual(drained.promoted, 1)
        let stored = await store.atom(forID: id.uuidString)
        XCTAssertEqual(stored?.governanceStatus, .governed,
            "drainIntents must persist the promotion to the store (event/log/provenance via store)")
    }

    // MARK: - 5. freeze queues only for snapshot members

    func testFreezeQueuesOnlyWhenAtomInSnapshot() async {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000E5")!
        let g = governed(id: id, content: "frozen memory content", domain: "general")
        let store = BASInMemoryMemoryAtomStore(initial: [g])
        let svc = makeService(atoms: [g], store: store)
        await svc.refresh()

        XCTAssertTrue(svc.freeze(memoryID: id.uuidString))
        XCTAssertFalse(svc.freeze(memoryID: "not-in-snapshot"))

        let drained = await svc.drainIntents()
        XCTAssertEqual(drained.frozen, 1)
        let stored = await store.atom(forID: id.uuidString)
        XCTAssertEqual(stored?.governanceStatus, .archived)
    }

    // MARK: - 6. refresh materializes the snapshot

    func testRefreshBuildsSnapshot() async {
        let svc = makeService(atoms: [
            governed(id: UUID(), content: "one", domain: "g"),
            governed(id: UUID(), content: "two", domain: "g"),
        ])
        XCTAssertEqual(svc.snapshotCount, 0)
        await svc.refresh()
        XCTAssertEqual(svc.snapshotCount, 2)
    }

    // MARK: - 7. empty snapshot

    func testEmptySnapshotReturnsNoAtoms() {
        let svc = makeService(atoms: [])
        let r = svc.retrieve(
            decomposeFrame: frame("anything"), hostContext: profile(), budget: budget())
        XCTAssertTrue(r.atoms.isEmpty)
        XCTAssertTrue(r.retrievalTags.contains("memory.no_relevant_atoms"))
    }

    // MARK: - 8. ch883: retrieve() is SYNC (called below WITHOUT await)

    func testRetrieveStaysSynchronous() async {
        let svc = makeService(atoms: [governed(id: UUID(), content: "sync path", domain: "g")])
        await svc.refresh()
        // No `await` on retrieve — the hot path is synchronous (the ch883 contract).
        let r: BASMemoryBundle = svc.retrieve(
            decomposeFrame: frame("sync path"), hostContext: profile(), budget: budget())
        XCTAssertEqual(r.atoms.first?.summary, "sync path")
    }
}
#endif
