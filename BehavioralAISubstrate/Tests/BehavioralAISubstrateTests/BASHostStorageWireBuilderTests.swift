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

    func testLegacyInMemoryProducesInMemoryStore() async throws {
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
            options: .legacyInMemory)
        XCTAssertTrue(
            store is BASInMemoryMemoryAtomStore,
            "Legacy preference must always return in-memory " +
            "store, even if URLs were provided")
    }

    func testLegacyInMemoryIgnoresProvidedURL() async throws {
        let url = tempRoot.appendingPathComponent(
            "should-not-be-created.sqlite")
        let options = BASHostStorageOptions(
            preference: .inMemoryDefault,
            atomStoreURL: url)
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
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

    func testSQLiteWhenURLProvidedWithURLProducesSQLite() async throws {
        let url = tempRoot.appendingPathComponent(
            "atoms.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url)
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
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
        async throws
    {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: nil)
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(
            store is BASInMemoryMemoryAtomStore,
            ".sqliteWhenURLProvided + nil URL must fall back " +
            "to in-memory (graceful degradation, not throw)")
    }

    func testSQLiteWhenURLProvidedWithUnifiedRoot() async throws {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(rootURL: tempRoot))
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
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

    func testSQLiteRequiredWithURLProducesSQLite() async throws {
        let url = tempRoot.appendingPathComponent(
            "required.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            atomStoreURL: url)
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        XCTAssertTrue(store is BASSQLiteMemoryAtomStore)
    }

    func testSQLiteRequiredWithoutURLThrowsMissingURL() async {
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            atomStoreURL: nil)
        // audit M-l MED-8 — makeAtomStore is now async; XCTAssertThrowsError
        // takes a non-async autoclosure, so assert the throw via do/catch.
        do {
            _ = try await BASHostStorageWireBuilder.makeAtomStore(
                options: options)
            XCTFail("expected BASHostStorageWireError, got success")
        } catch let wireError as BASHostStorageWireError {
            XCTAssertEqual(
                wireError,
                .missingSQLiteURL(component: "atom-store"),
                "fail-fast: .sqliteRequired with no URL must " +
                "throw .missingSQLiteURL — caller misconfigured")
        } catch {
            XCTFail("expected BASHostStorageWireError, got " +
                "\(type(of: error))")
        }
    }

    // MARK: - Initial atoms passthrough

    func testInitialAtomsPassedThroughToInMemoryStore() async throws
    {
        let atom1 = sampleAtom(content: "seed-a")
        let atom2 = sampleAtom(content: "seed-b")
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
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
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
            options: options,
            initial: [atom])
        let recovered = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(
            recovered?.content, "sqlite-seed",
            "initial: parameter must be passed through to " +
            "SQLite store init")
    }

    /// audit M-l MED-8 — the EVENT-SOURCED seed path used a fire-and-forget
    /// `Task.detached`, so makeAtomStore returned the store BEFORE seeding
    /// finished and an immediate reader raced the seed (saw it empty). The
    /// seed now runs inline (awaited): the store is fully seeded on return.
    /// (The SQLite / in-memory branches always seeded synchronously — only
    /// this async event-sourced branch was fire-and-forget.)
    func testEventSourcedInitialAtomsSeededBeforeReturn() async throws {
        let atom1 = sampleAtom(content: "es-seed-a")
        let atom2 = sampleAtom(content: "es-seed-b")
        let options = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let store = try await BASHostStorageWireBuilder.makeAtomStore(
            options: options,
            initial: [atom1, atom2])
        // The FIRST read after return must already see BOTH atoms — with
        // the old detached seed this raced and could observe nil.
        let r1 = await store.atom(forID: atom1.id.uuidString)
        let r2 = await store.atom(forID: atom2.id.uuidString)
        XCTAssertNotNil(
            r1,
            "event-sourced store must be fully seeded on return (no detached race)")
        XCTAssertEqual(r1?.content, "es-seed-a")
        XCTAssertNotNil(r2)
        XCTAssertEqual(r2?.content, "es-seed-b")
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

    // MARK: - Vault factory (chapter 三百〇六 / M793)

    func testVaultLegacyInMemoryReturnsNil() throws {
        let result = try BASHostStorageWireBuilder
            .makeVaultStorage(options: .legacyInMemory)
        XCTAssertNil(
            result,
            "Legacy preference must return nil for vault " +
            "(caller falls back to value-type snapshot vault)")
    }

    func testVaultSQLiteWhenURLProvidedWithURLProducesActor()
        throws
    {
        let url = tempRoot.appendingPathComponent("vault.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            vaultURL: url)
        let storage = try BASHostStorageWireBuilder
            .makeVaultStorage(options: options)
        XCTAssertNotNil(
            storage,
            ".sqliteWhenURLProvided + URL → SQLite vault actor " +
            "constructed")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "vault SQLite database file must be created on disk")
    }

    func testVaultSQLiteWhenURLProvidedWithoutURLReturnsNil()
        throws
    {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            vaultURL: nil)
        let storage = try BASHostStorageWireBuilder
            .makeVaultStorage(options: options)
        XCTAssertNil(
            storage,
            ".sqliteWhenURLProvided + nil URL → nil (graceful " +
            "fallback to value-type vault)")
    }

    func testVaultSQLiteRequiredWithoutURLThrows() {
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            vaultURL: nil)
        XCTAssertThrowsError(
            try BASHostStorageWireBuilder.makeVaultStorage(
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
                .missingSQLiteURL(component: "vault"),
                "fail-fast: .sqliteRequired with no vault URL " +
                "must throw .missingSQLiteURL(component: vault)")
        }
    }

    func testVaultUnifiedRootDerivesURL() throws {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(rootURL: tempRoot))
        let storage = try BASHostStorageWireBuilder
            .makeVaultStorage(options: options)
        XCTAssertNotNil(storage)
        let expectedFile = tempRoot.appendingPathComponent(
            "host-vault.sqlite")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: expectedFile.path),
            "vault SQLite file must exist at unifiedRoot/" +
            "host-vault.sqlite (chapter 三百〇三 derivation pin)")
    }

    func testVaultReasonCodesForLegacyMode() {
        let codes = BASHostStorageWireBuilder
            .vaultWireReasonCodes(options: .legacyInMemory)
        XCTAssertTrue(codes.contains("vault-wire:in-memory"))
        XCTAssertTrue(
            codes.contains(
                "vault-preference:in-memory-default"))
        XCTAssertTrue(codes.contains("vault-url-provided:no"))
    }

    func testVaultReasonCodesForSQLiteConfigured() {
        let url = URL(fileURLWithPath: "/tmp/v.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            vaultURL: url)
        let codes = BASHostStorageWireBuilder
            .vaultWireReasonCodes(options: options)
        XCTAssertTrue(codes.contains("vault-wire:sqlite"))
        XCTAssertTrue(codes.contains("vault-url-provided:yes"))
    }

    // MARK: - Ticket lifecycle factory (chapter 三百〇七 / M794)

    func testLifecycleLegacyInMemoryProducesInMemoryCoordinator()
        async throws
    {
        let coord = try await BASHostStorageWireBuilder
            .makeTicketLifecycleCoordinator(
                options: .legacyInMemory)
        // Legacy mode: coordinator has nil storage; assert by
        // verifying coordinator works for in-memory operations
        // (no persistence behavior needed).
        let initialCount = await coord.count()
        XCTAssertEqual(
            initialCount, 0,
            "fresh in-memory coordinator starts at zero tickets")
    }

    func testLifecycleSQLiteRequiredWithoutURLThrows() async {
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            ticketLifecycleURL: nil)
        do {
            _ = try await BASHostStorageWireBuilder
                .makeTicketLifecycleCoordinator(options: options)
            XCTFail("expected throw for .sqliteRequired + nil URL")
        } catch let wireError as BASHostStorageWireError {
            XCTAssertEqual(
                wireError,
                .missingSQLiteURL(
                    component: "ticket-lifecycle"))
        } catch {
            XCTFail("expected BASHostStorageWireError, got " +
                "\(type(of: error))")
        }
    }

    func testLifecycleSQLiteWhenURLProvidedCreatesFile()
        async throws
    {
        let url = tempRoot.appendingPathComponent(
            "lifecycle.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            ticketLifecycleURL: url)
        let coord = try await BASHostStorageWireBuilder
            .makeTicketLifecycleCoordinator(options: options)
        // Verify SQLite file exists on disk
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "SQLite lifecycle database file must be created on disk")
        let initialCount = await coord.count()
        XCTAssertEqual(
            initialCount, 0,
            "fresh SQLite coordinator starts at zero tickets " +
            "after restore (empty file)")
    }

    func testLifecycleSQLiteWhenURLProvidedWithoutURLFallsBack()
        async throws
    {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            ticketLifecycleURL: nil)
        let coord = try await BASHostStorageWireBuilder
            .makeTicketLifecycleCoordinator(options: options)
        // Falls back to in-memory; coordinator constructed
        // successfully (graceful, doesn't throw).
        let initialCount = await coord.count()
        XCTAssertEqual(initialCount, 0)
    }

    func testLifecycleReasonCodesForLegacyMode() {
        let codes = BASHostStorageWireBuilder
            .ticketLifecycleWireReasonCodes(
                options: .legacyInMemory)
        XCTAssertTrue(
            codes.contains("ticket-lifecycle-wire:in-memory"))
        XCTAssertTrue(
            codes.contains(
                "ticket-lifecycle-preference:in-memory-default"))
        XCTAssertTrue(
            codes.contains(
                "ticket-lifecycle-url-provided:no"))
    }

    func testLifecycleReasonCodesForSQLiteConfigured() {
        let url = URL(fileURLWithPath: "/tmp/lc.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            ticketLifecycleURL: url)
        let codes = BASHostStorageWireBuilder
            .ticketLifecycleWireReasonCodes(options: options)
        XCTAssertTrue(
            codes.contains("ticket-lifecycle-wire:sqlite"))
        XCTAssertTrue(
            codes.contains(
                "ticket-lifecycle-url-provided:yes"))
    }

    // MARK: - Audit ledger factory (chapter 三百〇八 / M795)

    func testAuditLedgerLegacyInMemoryReturnsNil() throws {
        let result = try BASHostStorageWireBuilder
            .makeAuditLedgerStorage(options: .legacyInMemory)
        XCTAssertNil(
            result,
            "Legacy preference returns nil — caller falls back " +
            "to BASSovereignLedgerNullStorage default")
    }

    func testAuditLedgerSQLiteWhenURLProvidedCreatesFile()
        throws
    {
        let url = tempRoot.appendingPathComponent(
            "audit.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            auditLedgerURL: url)
        let storage = try BASHostStorageWireBuilder
            .makeAuditLedgerStorage(options: options)
        XCTAssertNotNil(
            storage,
            ".sqliteWhenURLProvided + URL → SQLite ledger storage")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "audit ledger SQLite database file must be created " +
            "on disk")
    }

    func testAuditLedgerSQLiteWhenURLProvidedWithoutURLReturnsNil()
        throws
    {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            auditLedgerURL: nil)
        let storage = try BASHostStorageWireBuilder
            .makeAuditLedgerStorage(options: options)
        XCTAssertNil(
            storage,
            ".sqliteWhenURLProvided + nil URL → nil (graceful)")
    }

    func testAuditLedgerSQLiteRequiredWithoutURLThrows() {
        let options = BASHostStorageOptions(
            preference: .sqliteRequired,
            auditLedgerURL: nil)
        XCTAssertThrowsError(
            try BASHostStorageWireBuilder
                .makeAuditLedgerStorage(options: options)
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
                .missingSQLiteURL(component: "audit-ledger"),
                "fail-fast: .sqliteRequired with no audit-ledger " +
                "URL must throw .missingSQLiteURL with component " +
                "audit-ledger")
        }
    }

    func testAuditLedgerUnifiedRootDerivesURL() throws {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(rootURL: tempRoot))
        let storage = try BASHostStorageWireBuilder
            .makeAuditLedgerStorage(options: options)
        XCTAssertNotNil(storage)
        let expectedFile = tempRoot.appendingPathComponent(
            "audit-ledger.sqlite")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: expectedFile.path),
            "audit-ledger SQLite file must exist at unifiedRoot/" +
            "audit-ledger.sqlite (chapter 三百〇三 derivation pin)")
    }

    func testAuditLedgerReasonCodesForLegacyMode() {
        let codes = BASHostStorageWireBuilder
            .auditLedgerWireReasonCodes(options: .legacyInMemory)
        XCTAssertTrue(
            codes.contains("audit-ledger-wire:in-memory"))
        XCTAssertTrue(
            codes.contains(
                "audit-ledger-preference:in-memory-default"))
        XCTAssertTrue(
            codes.contains("audit-ledger-url-provided:no"))
    }

    func testAuditLedgerReasonCodesForSQLiteConfigured() {
        let url = URL(fileURLWithPath: "/tmp/al.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            auditLedgerURL: url)
        let codes = BASHostStorageWireBuilder
            .auditLedgerWireReasonCodes(options: options)
        XCTAssertTrue(
            codes.contains("audit-ledger-wire:sqlite"))
        XCTAssertTrue(
            codes.contains(
                "audit-ledger-url-provided:yes"))
    }

    // MARK: - Bundle assembly (chapter 三百〇九 / M796)

    func testBundleLegacyInMemoryHasInMemoryAtomNoVaultNoLedger()
        async throws
    {
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(options: .legacyInMemory)
        XCTAssertTrue(bundle.atomStore is BASInMemoryMemoryAtomStore)
        XCTAssertNil(bundle.vault)
        XCTAssertNil(bundle.auditLedger)
        // Lifecycle is always non-nil (in-memory or SQLite path)
        let count = await bundle.ticketLifecycle.count()
        XCTAssertEqual(count, 0)
        // Wire report reflects all-in-memory
        XCTAssertFalse(bundle.wireReport.anySQLiteUsed)
    }

    func testBundleSQLiteEverywhereWithUnifiedRoot() async throws {
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(rootURL: tempRoot))
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(options: options)
        XCTAssertTrue(bundle.atomStore is BASSQLiteMemoryAtomStore)
        XCTAssertNotNil(bundle.vault)
        XCTAssertNotNil(bundle.auditLedger)
        // All 4 SQLite files exist on disk
        let expectedFiles = [
            "memory-atoms.sqlite",
            "host-vault.sqlite",
            "ticket-lifecycle.sqlite",
            "audit-ledger.sqlite"
        ]
        for filename in expectedFiles {
            let url = tempRoot.appendingPathComponent(filename)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "all 4 SQLite files must exist after bundle " +
                "assembly with unifiedRoot — missing: \(filename)")
        }
        XCTAssertTrue(bundle.wireReport.anySQLiteUsed)
        XCTAssertTrue(bundle.wireReport.atomStoreUsedSQLite)
        XCTAssertTrue(bundle.wireReport.vaultUsedSQLite)
        XCTAssertTrue(bundle.wireReport.ticketLifecycleUsedSQLite)
        XCTAssertTrue(bundle.wireReport.auditLedgerUsedSQLite)
    }

    func testBundleAbortsOnFirstFactoryFailure() async {
        // .sqliteRequired with no URLs at all should fail at the
        // FIRST factory call (atom store), not silently succeed
        // partial assembly.
        let options = BASHostStorageOptions(
            preference: .sqliteRequired)
        do {
            _ = try await BASHostStorageWireBuilder
                .makeBundle(options: options)
            XCTFail("expected throw — .sqliteRequired with no URLs")
        } catch let wireError as BASHostStorageWireError {
            XCTAssertEqual(
                wireError,
                .missingSQLiteURL(component: "atom-store"),
                "fail-fast: bundle assembly aborts at the FIRST " +
                "missing URL — atom store comes first in the chain")
        } catch {
            XCTFail("expected BASHostStorageWireError, got " +
                "\(type(of: error))")
        }
    }

    func testBundleAtomStoreSeedingPropagates() async throws {
        let atom = sampleAtom(content: "bundle-seed")
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(
                options: .legacyInMemory,
                atomStoreInitial: [atom])
        let recovered = await bundle.atomStore.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(
            recovered?.content, "bundle-seed",
            "atomStoreInitial: parameter must propagate to " +
            "constructed atom store within bundle")
    }

    // MARK: - Cross-session SQLite persistence (atom store)

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
            let store1 = try await BASHostStorageWireBuilder
                .makeAtomStore(
                    options: options,
                    initial: [atom])
            let stored = await store1.atom(forID: atomID)
            XCTAssertEqual(stored?.content, "persistent-payload")
        }

        // Build 2: same wire builder, no initial atoms — store
        // must reload the persisted atom from SQLite.
        let store2 = try await BASHostStorageWireBuilder.makeAtomStore(
            options: options)
        let reloaded = await store2.atom(forID: atomID)
        XCTAssertEqual(
            reloaded?.content, "persistent-payload",
            "atom must persist across wire builds via SQLite — " +
            "atom content must round-trip without re-passing " +
            "initial: parameter to second wire builder")
    }

    // MARK: - Seed-failure → observability sink (blindspot MED id30)

    func testSeedEventSourcedRecordsAdmitFailures() async {
        // Drive the shared seed helper through a store whose event log
        // ALWAYS throws on append (so every admit throws). Each failure
        // must be recorded to the failure log. Before extraction this
        // path had no direct coverage — a revert to silent-swallow
        // stayed green behind the PROOF-test mocks.
        let log = BASHostStorageInitialAtomAdmitFailureLog()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: ThrowingEventLog(),
            sessionID: "id30-test")
        await BASHostStorageWireBuilder.seedEventSourced(
            store: store,
            initial: [sampleAtom(content: "a"),
                      sampleAtom(content: "b")],
            failureLog: log)
        let count = await log.recordedCount
        XCTAssertEqual(count, 2,
            "both admit failures must be recorded to the sink")
    }

    func testSeedEventSourcedNilLogSilentlySwallows() async {
        // With failureLog == nil the M1517 silent-swallow behavior is
        // preserved: admit failures do not propagate / crash.
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: ThrowingEventLog(),
            sessionID: "id30-nil")
        await BASHostStorageWireBuilder.seedEventSourced(
            store: store,
            initial: [sampleAtom(content: "a")],
            failureLog: nil)
        // Reaching here without throwing == silent-swallow preserved.
    }
}

/// Event log whose append always throws — used to force
/// `BASEventSourcedMemoryAtomStore.admit` to throw so the seed
/// helper's failure → sink wiring is exercised. (blindspot MED id30)
private actor ThrowingEventLog: BASEventLogStorage {
    struct BoomError: Error {}
    @discardableResult
    func append(
        _ entry: BASEventLogEntry
    ) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
        throw BoomError()
    }
    func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] { [] }
    func events(
        sinceTimestampMs since: Int64, limit: Int
    ) async -> [BASEventLogEntry] { [] }
    var totalCount: Int { get async { 0 } }
    func pruneEventsBefore(
        timestampMs cutoff: Int64
    ) async throws -> Int { 0 }
}
