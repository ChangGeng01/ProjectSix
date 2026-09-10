// MARK: - BASHostConfigurationStorageOptionsIntegrationTests
//
// chapter 三百〇四 / M791 — Phase Gamma 2nd code cut integration test。
// ADR-014 guardrail #2 ("Integration test per chapter") for the
// `BASHostStorageOptions` field on `BASHostConfiguration`。
//
// Test groups:
//   - default value invariant (.legacyInMemory → backward-compat)
//   - encode/decode round-trip preserves storageOptions
//   - decode of pre-Phase-Gamma JSON (without storageOptions field)
//     successfully constructs config with default .legacyInMemory
//   - encoded JSON contains storageOptions field (audit trail)
//   - shouldUseSQLite predicates flow through BASHostConfiguration

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASHostConfigurationStorageOptionsIntegrationTests:
    XCTestCase
{
    // MARK: - Helpers

    /// Build a minimum-viable `BASHostConfiguration` for testing.
    /// Uses fixture defaults from existing init signatures.
    private func makeConfig(
        storageOptions: BASHostStorageOptions = .legacyInMemory
    ) -> BASHostConfiguration {
        BASHostConfiguration(
            runtimeProfileID: "test-runtime",
            policyProfileID: "test-policy",
            prefersPureLocal: true,
            defaultDeviceState: BASHostConfiguration
                .fixtureDefaultDeviceState,
            console: BASHostConsoleConfiguration.generic,
            lifecycleBehavior:
                BASHostLifecycleBehaviorConfiguration.generic,
            workflowBehavior:
                BASHostWorkflowBehaviorConfiguration.generic,
            cognitionBehavior:
                BASHostCognitionBehaviorConfiguration.generic,
            presentation:
                BASHostPresentationConfiguration.generic,
            runtimeTuning: .generic,
            hostRhythmProfile: .generic,
            storageOptions: storageOptions)
    }

    // MARK: - Default value invariants

    func testDefaultStorageOptionsIsLegacyInMemory() {
        let config = makeConfig()
        XCTAssertEqual(
            config.storageOptions,
            BASHostStorageOptions.legacyInMemory,
            "ADR-014 backward-compat: callers that don't pass " +
            "storageOptions get pre-Phase-Gamma behavior")
    }

    func testDefaultPreferenceIsInMemoryDefault() {
        let config = makeConfig()
        XCTAssertEqual(
            config.storageOptions.preference, .inMemoryDefault)
        XCTAssertFalse(
            config.storageOptions.shouldUseSQLiteAtomStore)
        XCTAssertFalse(
            config.storageOptions.shouldUseSQLiteVault)
        XCTAssertFalse(
            config.storageOptions.shouldUseSQLiteTicketLifecycle)
        XCTAssertFalse(
            config.storageOptions.shouldUseSQLiteAuditLedger)
    }

    // MARK: - Codable round-trip

    func testEncodeDecodeRoundTripPreservesLegacyDefault() throws {
        let original = makeConfig()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostConfiguration.self, from: data)
        XCTAssertEqual(decoded.storageOptions, original.storageOptions)
    }

    func testEncodeDecodeRoundTripPreservesSQLiteOptions() throws {
        let url = URL(fileURLWithPath: "/tmp/integration.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url,
            vaultURL: url,
            ticketLifecycleURL: url,
            auditLedgerURL: url)
        let original = makeConfig(storageOptions: options)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostConfiguration.self, from: data)
        XCTAssertEqual(decoded.storageOptions, options)
        XCTAssertTrue(
            decoded.storageOptions.shouldUseSQLiteAtomStore,
            "Phase Gamma migration default must preserve through " +
            "JSON round-trip")
    }

    // MARK: - Backward-compat decode

    func testDecodeOfPreviousVersionConfigDefaultsToLegacy() throws {
        // Construct a config, encode it, strip the storageOptions
        // field, decode again — simulates loading pre-Phase-Gamma
        // on-disk config where the field doesn't exist.
        let original = makeConfig()
        let encoded = try JSONEncoder().encode(original)

        guard
            let raw = try JSONSerialization.jsonObject(
                with: encoded) as? [String: Any]
        else {
            XCTFail("expected dictionary JSON")
            return
        }

        var stripped = raw
        stripped.removeValue(forKey: "storageOptions")
        let strippedData = try JSONSerialization.data(
            withJSONObject: stripped)

        let decoded = try JSONDecoder().decode(
            BASHostConfiguration.self, from: strippedData)
        XCTAssertEqual(
            decoded.storageOptions, .legacyInMemory,
            "ADR-014 backward-compat decodeIfPresent: missing " +
            "storageOptions field → default to legacyInMemory; " +
            "pre-Phase-Gamma configs load without modification")
    }

    func testEncodedJSONContainsStorageOptionsField() throws {
        let config = makeConfig()
        let encoded = try JSONEncoder().encode(config)
        guard
            let raw = try JSONSerialization.jsonObject(
                with: encoded) as? [String: Any]
        else {
            XCTFail("expected dictionary JSON")
            return
        }
        XCTAssertNotNil(
            raw["storageOptions"],
            "encoded JSON must contain storageOptions field for " +
            "audit trail (chapter 二百一一 single-source-of-truth)")
    }

    // MARK: - Wire report derivation through BASHostConfiguration

    func testWireReportDerivedFromConfigStorageOptions() {
        let config = makeConfig()
        let report = BASHostStorageWireReport.derive(
            from: config.storageOptions)
        XCTAssertFalse(report.anySQLiteUsed)
        XCTAssertEqual(report.preferenceApplied, .inMemoryDefault)
        XCTAssertTrue(
            report.reasonCodes
                .contains("storage-preference:in-memory-default"))
    }

    func testWireReportDerivedFromSQLiteConfigShowsSQLitePaths() {
        let url = URL(fileURLWithPath: "/tmp/wired.sqlite")
        let options = BASHostStorageOptions(
            preference: .sqliteWhenURLProvided,
            atomStoreURL: url,
            ticketLifecycleURL: url)
        let config = makeConfig(storageOptions: options)
        let report = BASHostStorageWireReport.derive(
            from: config.storageOptions)
        XCTAssertTrue(report.atomStoreUsedSQLite)
        XCTAssertFalse(report.vaultUsedSQLite)
        XCTAssertTrue(report.ticketLifecycleUsedSQLite)
        XCTAssertFalse(report.auditLedgerUsedSQLite)
        XCTAssertEqual(
            report.preferenceApplied, .sqliteWhenURLProvided)
        XCTAssertTrue(
            report.reasonCodes
                .contains("atom-store:sqlite-backed"))
        XCTAssertTrue(
            report.reasonCodes
                .contains("vault:in-memory"))
    }

    // MARK: - Equatable preserves storageOptions distinction

    func testTwoConfigsDifferingOnlyByStorageOptionsAreUnequal() {
        let url = URL(fileURLWithPath: "/tmp/x.sqlite")
        let a = makeConfig()
        let b = makeConfig(
            storageOptions: BASHostStorageOptions(
                preference: .sqliteWhenURLProvided,
                atomStoreURL: url))
        XCTAssertNotEqual(a, b,
            "BASHostConfiguration Equatable must distinguish " +
            "storageOptions changes (regression-pin: forgetting " +
            "to add storageOptions to == would cause silent " +
            "config drift)")
    }
}
