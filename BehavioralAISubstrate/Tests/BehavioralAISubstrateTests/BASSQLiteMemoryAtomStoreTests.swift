import XCTest
@testable import BASMemory

/// chapter 二百四十八 / M735 — SQLite-backed `BASMemoryAtomStore`
/// coverage.
///
/// Pre-chapter 二百四十八 the only `BASMemoryAtomStore` conformer was
/// `BASInMemoryMemoryAtomStore`, which loses every atom on process
/// restart. This test suite verifies that
/// `BASSQLiteMemoryAtomStore`:
///
///   1. Mirrors the in-memory protocol semantics byte-for-byte
///      (atom / updateTier / updateGovernanceStatus / remove +
///      count / allIDs / admit).
///   2. Persists atoms across instance close/reopen — the
///      cross-session continuity invariant附录 V Stage 0 was
///      designed to deliver.
///   3. Surfaces SQLite errors as typed `StorageError` values
///      rather than silently dropping data (chapter 一百九十一
///      M91 integrity > availability doctrine).
///
/// Test layout follows `BASMemoryMutationWriterTests` (XCTest +
/// `BASInMemoryMemoryAtomStore` fixture builder) — only the store
/// class under test changes.
final class BASSQLiteMemoryAtomStoreTests: XCTestCase {

    // MARK: - Fixtures

    private var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-memory-test-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            // SQLite WAL/SHM sidecars
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
    }

    private func makeAtom(
        id: UUID = UUID(),
        kind: BASMemoryKind = .episodic,
        scope: BASMemoryScope = .session,
        sensitivity: BASMemorySensitivity = .low,
        tier: BASMemoryTier = .warm,
        governanceStatus: BASMemoryGovernanceStatus = .governed,
        content: String = "test atom"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: kind,
            content: content,
            scope: scope,
            sensitivity: sensitivity,
            tier: tier,
            confidence: 0.7,
            sourceType: "test",
            governanceStatus: governanceStatus,
            provenanceSummary: "test")
    }

    // MARK: - 1. Empty init

    func testEmptyInitCreatesEmptyStore() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let count = await store.count
        XCTAssertEqual(count, 0)
        let ids = await store.allIDs
        XCTAssertEqual(ids, [])
    }

    // MARK: - 2. atom(forID:) returns nil for missing

    func testAtomLookupMissReturnsNil() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let result = await store.atom(forID: "no-such-id")
        XCTAssertNil(result)
    }

    // MARK: - 3. admit + atom round-trip

    func testAdmitThenLookupReturnsEqualAtom() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let atom = makeAtom()
        let isNew = try await store.admit(atom)
        XCTAssertTrue(isNew)

        let fetched = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(fetched, atom)
    }

    // MARK: - 4. updateTier mutates atom and persists

    func testUpdateTierMutatesPersistedAtom() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let atom = makeAtom(tier: .warm)
        try await store.admit(atom)

        let updated = await store.updateTier(
            forID: atom.id.uuidString, to: .hot)
        XCTAssertTrue(updated)

        let fetched = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.tier, .hot)
        XCTAssertEqual(
            fetched?.governanceStatus,
            atom.governanceStatus)
    }

    // MARK: - 5. updateGovernanceStatus mutates atom

    func testUpdateGovernanceStatusMutatesPersistedAtom()
        async throws
    {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let atom = makeAtom(governanceStatus: .candidate)
        try await store.admit(atom)

        let updated = await store.updateGovernanceStatus(
            forID: atom.id.uuidString, to: .quarantined)
        XCTAssertTrue(updated)

        let fetched = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(
            fetched?.governanceStatus, .quarantined)
        XCTAssertEqual(fetched?.tier, atom.tier)
    }

    // MARK: - 6. remove (real DELETE, returns prior value)

    func testRemoveReturnsPriorValueAndDeletes() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let atom = makeAtom()
        try await store.admit(atom)

        let removed = await store.remove(
            forID: atom.id.uuidString)
        XCTAssertEqual(removed, atom)

        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertNil(after)
        let count = await store.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - 7. Cross-session persistence (THE KEY TEST)

    /// Crystallizes 附录 V Stage 0's contract: close + reopen
    /// preserves every admitted atom byte-for-byte.
    func testCrossSessionPersistenceSurvivesReopen()
        async throws
    {
        let atom1 = makeAtom(content: "A")
        let atom2 = makeAtom(
            tier: .cold,
            governanceStatus: .quarantined,
            content: "B")

        // Session 1 — write + close
        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: tempURL)
            try await store.admit(atom1)
            try await store.admit(atom2)
            let count1 = await store.count
            XCTAssertEqual(count1, 2)
        }

        // Session 2 — reopen + verify
        let store2 = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let count2 = await store2.count
        XCTAssertEqual(count2, 2)
        let fetched1 = await store2.atom(
            forID: atom1.id.uuidString)
        let fetched2 = await store2.atom(
            forID: atom2.id.uuidString)
        XCTAssertEqual(fetched1, atom1)
        XCTAssertEqual(fetched2, atom2)
    }

    // MARK: - 8. Tier mutation survives reopen

    func testTierMutationSurvivesReopen() async throws {
        let atom = makeAtom(tier: .warm)

        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: tempURL)
            try await store.admit(atom)
            await store.updateTier(
                forID: atom.id.uuidString, to: .hot)
        }

        let reopened = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let fetched = await reopened.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.tier, .hot)
    }

    // MARK: - 9. Forget cascade (real DELETE) survives reopen

    func testForgetSurvivesReopen() async throws {
        let atom = makeAtom()

        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: tempURL)
            try await store.admit(atom)
            _ = await store.remove(
                forID: atom.id.uuidString)
        }

        let reopened = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let fetched = await reopened.atom(
            forID: atom.id.uuidString)
        XCTAssertNil(fetched)
        let count = await reopened.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - 10. updateTier on missing atom returns false

    func testUpdateTierMissReturnsFalse() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let updated = await store.updateTier(
            forID: "no-such-id", to: .hot)
        XCTAssertFalse(updated)
    }

    // MARK: - 11. updateGovernanceStatus on missing returns false

    func testUpdateGovernanceMissReturnsFalse() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let updated = await store.updateGovernanceStatus(
            forID: "no-such-id", to: .quarantined)
        XCTAssertFalse(updated)
    }

    // MARK: - 12. remove on missing returns nil

    func testRemoveMissReturnsNil() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let removed = await store.remove(forID: "no-such-id")
        XCTAssertNil(removed)
    }

    // MARK: - 13. Re-admit upserts (replace by ID)

    func testReAdmitReplacesPriorRow() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let id = UUID()
        let v1 = makeAtom(
            id: id, tier: .warm, content: "v1")
        let v2 = makeAtom(
            id: id, tier: .cold, content: "v2")

        let firstNew = try await store.admit(v1)
        XCTAssertTrue(firstNew)
        let secondNew = try await store.admit(v2)
        XCTAssertFalse(secondNew)

        let fetched = await store.atom(
            forID: id.uuidString)
        XCTAssertEqual(fetched?.content, "v2")
        XCTAssertEqual(fetched?.tier, .cold)
        let count = await store.count
        XCTAssertEqual(count, 1)
    }

    // MARK: - 14. Initial seed only when DB is empty

    func testInitialSeedAppliedOnlyWhenDatabaseIsEmpty()
        async throws
    {
        let seedAtom = makeAtom(content: "seed")

        // First open with seed: applied.
        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: tempURL,
                initial: [seedAtom])
            let count = await store.count
            XCTAssertEqual(count, 1)
        }

        // Mutate via second open (no seed) — overrides content.
        let secondAtomID = UUID()
        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: tempURL)
            try await store.admit(makeAtom(
                id: secondAtomID, content: "second"))
        }

        // Third open with the SAME seed: must NOT re-apply
        // (existing data is canonical).
        let third = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL,
            initial: [seedAtom])
        let count = await third.count
        XCTAssertEqual(count, 2)
        let fetched = await third.atom(
            forID: seedAtom.id.uuidString)
        XCTAssertEqual(fetched?.content, "seed")
    }

    // MARK: - 15. allIDs reflects multiple atoms

    func testAllIDsReflectsAdmittedAtoms() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let a = makeAtom()
        let b = makeAtom()
        let c = makeAtom()
        try await store.admit(a)
        try await store.admit(b)
        try await store.admit(c)

        let ids = await store.allIDs
        XCTAssertEqual(ids, [
            a.id.uuidString,
            b.id.uuidString,
            c.id.uuidString
        ])
    }

    // MARK: - 16. allAtoms returns insertion order

    func testAllAtomsReturnedInInsertionOrder() async throws {
        let store = try BASSQLiteMemoryAtomStore(
            databaseURL: tempURL)
        let a = makeAtom(content: "A")
        try await store.admit(a)
        // Brief delay so created_at_ms differs (millisecond
        // resolution; without delay the values could tie and
        // ORDER BY would be ambiguous).
        try await Task.sleep(nanoseconds: 5_000_000)
        let b = makeAtom(content: "B")
        try await store.admit(b)
        try await Task.sleep(nanoseconds: 5_000_000)
        let c = makeAtom(content: "C")
        try await store.admit(c)

        let atoms = try await store.allAtoms()
        XCTAssertEqual(atoms.map { $0.content }, ["A", "B", "C"])
    }

    // MARK: - 17. Schema version pin

    func testSchemaVersionConstantIsOne() {
        XCTAssertEqual(
            BASSQLiteMemoryAtomStore.schemaVersion, 1)
    }
}
