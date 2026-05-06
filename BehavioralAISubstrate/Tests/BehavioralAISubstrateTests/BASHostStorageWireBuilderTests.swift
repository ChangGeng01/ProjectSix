// MARK: - BASHostStorageWireBuilderTests — chapter 三百〇五 / M792
//
// Phase Gamma 3rd code cut integration tests:typed factory that
// converts BASHostStorageOptions into concrete BASMemoryAtomStore
// instances。
//
// ADR-014 guardrail #2 — integration test per chapter:these tests
// drive REAL store construction (not just enum/bool inspection),
// assert SQLite files are created when configured + in-memory store
// returns when not。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASHostStorageWireBuilderTests: XCTestCase {

    // MARK: - Test fixtures

    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-storage-wire-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: tempRoot,
            withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let root = tempRoot {
            try? FileManager.default.removeItem(at: root)
        }
        tempRoot = nil
        super.tearDown()
    }

    private func sampleAtom(
        id: UUID = UUID(),
        content: String = "wire-test"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: .episodic,
            content: content,
            scope: .session,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.7,
            sourceType: "wire-test",
            governanceStatus: .governed,
            provenanceSummary: "wire-test")
    }

    // MARK: - .inMemoryDefault → in-memory store

    func testLegacyInMemoryProducesInMemoryStore() throws {
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: .legacyInMemory)
        XCTAssertTrue(
            store is BASInMemoryMemoryAtomStore,
            "Legacy preference must always return in-memory " +
            "store, even if URLs were provided")
    }

    func testLegacyInMemoryIgnoresProvidedURL() throws {
        let url = tempRoot.appendingPathComponent(
            "should-not-be-created.sqlite")
        let options = BASHostStorageOptions(
            preference: .inMemoryDefault,
            atomStoreURL: url)
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(
            store is BASInMemoryMemoryAtomStore,
            "ADR-014 backward-compat: .inMemoryDefault ignores " +
            "URLs entirely (caller must explicitly migrate " +
            "preference to opt in)")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path),
            "no SQLite file must be created when preference is " +
            ".inMemoryDefault — even if URL is set")
    }

    // MARK: - .sqliteWhenURLProvided

    func testSQLiteWhenURLProvidedWithURLProducesSQLite() throws {
        let url = tempRoot.appendingPathComponent(
            "atoms.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url)
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(
            store is BASSQLiteMemoryAtomStore,
            "Phase Gamma migration default: URL set + " +
            "preference set → SQLite")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "SQLite database file must be created on disk")
    }

    func testSQLiteWhenURLProvidedWithoutURLFallsBackToInMemory()
        throws
    {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: nil)
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(
            store is BASInMemoryMemoryAtomStore,
            ".sqliteWhenURLProvided + nil URL must fall back " +
            "to in-memory (graceful degradation, not throw)")
    }

    func testSQLiteWhenURLProvidedWithUnifiedRoot() throws {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(rootURL: tempRoot))
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(
            store is BASSQLiteMemoryAtomStore,
            "Unified root resolves atomStoreURL via subdirectory " +
            "derivation")
        let expectedFile = tempRoot.appendingPathComponent(
            "memory-atoms.sqlite")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: expectedFile.path),
            "Unified-root-derived SQLite file must exist on disk")
    }

    // MARK: - .sqliteRequired

    func testSQLiteRequiredWithURLProducesSQLite() throws {
        let url = tempRoot.appendingPathComponent(
            "required.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            atomStoreURL: url)
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(store is BASSQLiteMemoryAtomStore)
    }

    func testSQLiteRequiredWithoutURLThrowsMissingURL() {
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            atomStoreURL: nil)
        XCTAssertThrowsError(
            try BASHostStorageWireBuilder.makeAtomStore(
                options: options)
        ) { error in
            guard let wireError =
                error as? BASHostStorageWireError
            else {
                XCTFail("expected BASHostStorageWireError, got " +
                    "\(type(of: error))")
                return
            }
            XCTAssertEqual(
                wireError,
                .missingSQLiteURL(component: "atom-store"),
                "fail-fast: .sqliteRequired with no URL must " +
                "throw .missingSQLiteURL — caller misconfigured")
        }
    }

    // MARK: - Initial atoms passthrough

    func testInitialAtomsPassedThroughToInMemoryStore() async throws
    {
        let atom1 = sampleAtom(content: "seed-a")
        let atom2 = sampleAtom(content: "seed-b")
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: .legacyInMemory,
            initial: [atom1, atom2])
        let recovered1 = await store.atom(
            forID: atom1.id.uuidString)
        let recovered2 = await store.atom(
            forID: atom2.id.uuidString)
        XCTAssertNotNil(
            recovered1,
            "initial: parameter must be passed through to " +
            "in-memory store; atom1 retrievable")
        XCTAssertNotNil(recovered2)
        XCTAssertEqual(recovered1?.content, "seed-a")
        XCTAssertEqual(recovered2?.content, "seed-b")
    }

    func testInitialAtomsPassedThroughToSQLiteStore() async throws {
        let url = tempRoot.appendingPathComponent("seeded.sqlite")
        let atom = sampleAtom(content: "sqlite-seed")
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            atomStoreURL: url)
        let store = try BASHostStorageWireBuilder.makeAtomStore(
            options: options,
            initial: [atom])
        let recovered = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(
            recovered?.content, "sqlite-seed",
            "initial: parameter must be passed through to " +
            "SQLite store init")
    }

    // MARK: - Reason codes

    func testReasonCodesForLegacyInMemory() {
        let codes = BASHostStorageWireBuilder
            .atomStoreWireReasonCodes(options: .legacyInMemory)
        XCTAssertEqual(codes.count, 3)
        XCTAssertTrue(
            codes.contains("atom-store-wire:in-memory"))
        XCTAssertTrue(
            codes.contains(
                "atom-store-preference:in-memory-default"))
        XCTAssertTrue(
            codes.contains("atom-store-url-provided:no"))
    }

    func testReasonCodesForSQLiteConfigured() {
        let url = URL(fileURLWithPath: "/tmp/x.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url)
        let codes = BASHostStorageWireBuilder
            .atomStoreWireReasonCodes(options: options)
        XCTAssertTrue(
            codes.contains("atom-store-wire:sqlite"))
        XCTAssertTrue(
            codes.contains(
                "atom-store-preference:sqlite-when-url-provided"))
        XCTAssertTrue(
            codes.contains("atom-store-url-provided:yes"))
    }

    // MARK: - Cross-session SQLite persistence

    func testSQLiteStorePersistsAcrossWireBuilds() async throws {
        let url = tempRoot.appendingPathComponent(
            "persistent.sqlite")
        let atom = sampleAtom(content: "persistent-payload")
        let atomID = atom.id.uuidString

        // Build 1: write through wire builder
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            atomStoreURL: url)
        do {
            let store1 = try BASHostStorageWireBuilder
                .makeAtomStore(
                    options: options,
                    initial: [atom])
            let stored = await store1.atom(forID: atomID)
            XCTAssertEqual(stored?.content, "persistent-payload")
        }

        // Build 2: same wire builder, no initial atoms — store
        // must reload the persisted atom from SQLite.
        let store2 = try BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        let reloaded = await store2.atom(forID: atomID)
        XCTAssertEqual(
            reloaded?.content, "persistent-payload",
            "atom must persist across wire builds via SQLite — " +
            "atom content must round-trip without re-passing " +
            "initial: parameter to second wire builder")
    }
}
