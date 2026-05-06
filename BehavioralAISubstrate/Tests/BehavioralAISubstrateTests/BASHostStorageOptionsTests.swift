// MARK: - BASHostStorageOptionsTests — chapter 三百〇三 / M790
//
// Phase Gamma 1st code cut 测试覆盖:storage options typed primitive。

import XCTest
@testable import BASRuntimeCore

final class BASHostStorageOptionsTests: XCTestCase {

    // MARK: - Preference enum

    func testPreferenceCardinality() {
        XCTAssertEqual(
            BASHostStoragePreference.allCases.count, 3,
            "3 cases match ADR-014 migration spectrum: " +
            "legacy in-memory / migration default / fail-fast")
    }

    func testPreferenceRawValueStability() {
        XCTAssertEqual(
            BASHostStoragePreference.inMemoryDefault.rawValue,
            "in-memory-default")
        XCTAssertEqual(
            BASHostStoragePreference.sqliteWhenURLProvided.rawValue,
            "sqlite-when-url-provided")
        XCTAssertEqual(
            BASHostStoragePreference.sqliteRequired.rawValue,
            "sqlite-required")
    }

    func testPreferenceCodableRoundTrip() throws {
        for p in BASHostStoragePreference.allCases {
            let data = try JSONEncoder().encode(p)
            let decoded = try JSONDecoder().decode(
                BASHostStoragePreference.self, from: data)
            XCTAssertEqual(decoded, p)
        }
    }

    // MARK: - Storage root

    func testStorageRootDerivedURLs() {
        let base = URL(fileURLWithPath: "/tmp/qinao-test")
        let root = BASHostStorageRoot(rootURL: base)
        XCTAssertEqual(
            root.atomsURL.path,
            "/tmp/qinao-test/memory-atoms.sqlite")
        XCTAssertEqual(
            root.vaultURL.path,
            "/tmp/qinao-test/host-vault.sqlite")
        XCTAssertEqual(
            root.ticketLifecycleURL.path,
            "/tmp/qinao-test/ticket-lifecycle.sqlite")
        XCTAssertEqual(
            root.auditLedgerURL.path,
            "/tmp/qinao-test/audit-ledger.sqlite")
    }

    func testStorageRootCodableRoundTrip() throws {
        let original = BASHostStorageRoot(
            rootURL: URL(fileURLWithPath: "/tmp/qinao-rt"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostStorageRoot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Storage options defaults

    func testOptionsDefaultsAreLegacyInMemory() {
        let options = BASHostStorageOptions()
        XCTAssertEqual(options.schemaVersion, "1.0.0")
        XCTAssertEqual(options.preference, .inMemoryDefault)
        XCTAssertNil(options.unifiedRoot)
        XCTAssertNil(options.atomStoreURL)
        XCTAssertNil(options.vaultURL)
        XCTAssertNil(options.ticketLifecycleURL)
        XCTAssertNil(options.auditLedgerURL)
    }

    func testLegacyInMemoryStaticEqualsDefaultInit() {
        XCTAssertEqual(
            BASHostStorageOptions.legacyInMemory,
            BASHostStorageOptions(),
            "ADR-014 backward-compat: legacy default never " +
            "triggers SQLite paths")
    }

    func testLegacyInMemoryAllShouldUseSQLiteFalse() {
        let legacy = BASHostStorageOptions.legacyInMemory
        XCTAssertFalse(legacy.shouldUseSQLiteAtomStore)
        XCTAssertFalse(legacy.shouldUseSQLiteVault)
        XCTAssertFalse(legacy.shouldUseSQLiteTicketLifecycle)
        XCTAssertFalse(legacy.shouldUseSQLiteAuditLedger)
    }

    // MARK: - URL effective resolution (unifiedRoot fallback)

    func testEffectiveURLPrefersExplicitOverUnifiedRoot() {
        let explicit = URL(fileURLWithPath: "/tmp/explicit.sqlite")
        let root = URL(fileURLWithPath: "/tmp/root")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(rootURL: root),
            atomStoreURL: explicit)
        XCTAssertEqual(
            options.effectiveAtomStoreURL, explicit,
            "explicit URL must win over unified root")
        XCTAssertEqual(
            options.effectiveVaultURL,
            root.appendingPathComponent("host-vault.sqlite"),
            "unifiedRoot resolves vault when explicit nil")
    }

    func testEffectiveURLNilWhenNeitherSet() {
        let options = BASHostStorageOptions()
        XCTAssertNil(options.effectiveAtomStoreURL)
        XCTAssertNil(options.effectiveVaultURL)
        XCTAssertNil(options.effectiveTicketLifecycleURL)
        XCTAssertNil(options.effectiveAuditLedgerURL)
    }

    // MARK: - shouldUseSQLite predicates

    func testShouldUseSQLiteRequiredAlwaysTrue() {
        // Even without URLs set, .sqliteRequired forces true
        // (caller will fail-fast at construction if URL is nil).
        let options = BASHostStorageOptions(
            preference: .sqliteRequired)
        XCTAssertTrue(options.shouldUseSQLiteAtomStore)
        XCTAssertTrue(options.shouldUseSQLiteVault)
        XCTAssertTrue(options.shouldUseSQLiteTicketLifecycle)
        XCTAssertTrue(options.shouldUseSQLiteAuditLedger)
    }

    func testShouldUseSQLiteWhenURLProvidedConditional() {
        let url = URL(fileURLWithPath: "/tmp/x.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url)
        XCTAssertTrue(options.shouldUseSQLiteAtomStore)
        XCTAssertFalse(
            options.shouldUseSQLiteVault,
            "vault URL nil → in-memory under sqliteWhenURLProvided")
    }

    func testShouldUseSQLiteInMemoryDefaultAlwaysFalse() {
        let url = URL(fileURLWithPath: "/tmp/y.sqlite")
        let options = BASHostStorageOptions(
            preference: .inMemoryDefault,
            atomStoreURL: url)
        XCTAssertFalse(
            options.shouldUseSQLiteAtomStore,
            "ADR-014 backward-compat: legacy preference IGNORES " +
            "URLs entirely. Set preference to migrate.")
    }

    // MARK: - Codable round-trip

    func testOptionsCodableRoundTrip() throws {
        let url1 = URL(fileURLWithPath: "/tmp/atoms.sqlite")
        let url2 = URL(fileURLWithPath: "/tmp/vault.sqlite")
        let original = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            unifiedRoot: BASHostStorageRoot(
                rootURL: URL(fileURLWithPath: "/tmp/root")),
            atomStoreURL: url1,
            vaultURL: url2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostStorageOptions.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Wire report

    func testWireReportAnyPredicate() {
        let none = BASHostStorageWireReport(
            atomStoreUsedSQLite: false,
            vaultUsedSQLite: false,
            ticketLifecycleUsedSQLite: false,
            auditLedgerUsedSQLite: false)
        XCTAssertFalse(none.anySQLiteUsed)

        let one = BASHostStorageWireReport(
            atomStoreUsedSQLite: true)
        XCTAssertTrue(one.anySQLiteUsed)
    }

    func testWireReportReasonCodesShape() {
        let codes = BASHostStorageWireReport.makeReasonCodes(
            atomStoreUsedSQLite: true,
            vaultUsedSQLite: false,
            ticketLifecycleUsedSQLite: false,
            auditLedgerUsedSQLite: false,
            preference: .sqliteWhenURLProvided)
        XCTAssertEqual(
            codes,
            [
                "storage-preference:sqlite-when-url-provided",
                "atom-store:sqlite-backed",
                "vault:in-memory",
                "ticket-lifecycle:in-memory",
                "audit-ledger:in-memory"
            ],
            "reason codes match audit-walker grep convention " +
            "(chapter 二百一一 single-source-of-truth)")
    }

    func testWireReportDeriveFromOptionsLegacy() {
        let report = BASHostStorageWireReport.derive(
            from: .legacyInMemory)
        XCTAssertFalse(report.atomStoreUsedSQLite)
        XCTAssertFalse(report.anySQLiteUsed)
        XCTAssertEqual(report.preferenceApplied, .inMemoryDefault)
        XCTAssertEqual(report.reasonCodes.count, 5)
    }

    func testWireReportDeriveFromOptionsAllSQLite() {
        let url = URL(fileURLWithPath: "/tmp/all.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url,
            vaultURL: url,
            ticketLifecycleURL: url,
            auditLedgerURL: url)
        let report = BASHostStorageWireReport.derive(from: options)
        XCTAssertTrue(report.atomStoreUsedSQLite)
        XCTAssertTrue(report.vaultUsedSQLite)
        XCTAssertTrue(report.ticketLifecycleUsedSQLite)
        XCTAssertTrue(report.auditLedgerUsedSQLite)
        XCTAssertTrue(report.anySQLiteUsed)
    }

    func testWireReportDeriveFromOptionsRequiredEvenWithoutURLs() {
        // .sqliteRequired forces all 4 SQLite booleans true even
        // without URLs (caller responsible for failing fast at
        // construction if URLs missing).
        let options = BASHostStorageOptions(
            preference: .sqliteRequired)
        let report = BASHostStorageWireReport.derive(from: options)
        XCTAssertTrue(report.atomStoreUsedSQLite)
        XCTAssertTrue(report.vaultUsedSQLite)
        XCTAssertTrue(report.ticketLifecycleUsedSQLite)
        XCTAssertTrue(report.auditLedgerUsedSQLite)
    }

    func testWireReportCodableRoundTrip() throws {
        let original = BASHostStorageWireReport(
            atomStoreUsedSQLite: true,
            vaultUsedSQLite: false,
            ticketLifecycleUsedSQLite: true,
            auditLedgerUsedSQLite: true,
            preferenceApplied: .sqliteWhenURLProvided,
            reasonCodes: ["test:rt"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostStorageWireReport.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testWireReportFiltersEmptyReasonCodes() {
        let report = BASHostStorageWireReport(
            reasonCodes: ["valid", "  ", "", " also-valid "])
        XCTAssertEqual(
            report.reasonCodes, ["valid", "also-valid"])
    }
}
