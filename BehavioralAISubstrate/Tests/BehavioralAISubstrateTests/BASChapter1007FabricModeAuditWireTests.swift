// MARK: - BASChapter1007FabricModeAuditWireTests
// chapter 一千零七 / M3740 — `BASAgentFabricMode` substrate-
// observability wire
//
// Pre-ch-1007: `BASAgentFabricMode.{observationOnly,
// authoritative}` shipped at ch 994 + ch 996 as host-observable
// signals only。 No substrate-side consumer made the signal
// substrate-observable for audit / replay。
//
// Ch 1007 ships `BASAgentFabricModeAuditEmitter` — pure-fn +
// ledger-bound helper that converts the per-turn mode flag
// into a sovereign audit-ledger entry。 Both
// `.observationOnly` and `.authoritative` are audited (with
// different verdictRefs) per ch 977 defense-in-depth doctrine。
//
// Substrate BEHAVIOR remains unchanged per ch 994 — the
// dispatcher / merge / apply output is byte-equal between the
// two modes。 The CHANGE is that the mode flag now has a
// canonical substrate-side audit representation。
//
// Tests pin:
//   1. buildEntry produces valid sovereign-entry shape
//   2. observationOnly + authoritative produce DIFFERENT
//      auditIDs + verdictRefs (replay can distinguish)
//   3. signalRefs encode the mode under the reserved
//      agentFabric.* prefix
//   4. CRITICAL: appendToLedger writes both modes to ledger
//      (defense-in-depth — claiming observation-only later has
//      explicit audit support)
//   5. Empty sessionID throws (ledger contract)

import XCTest
import CryptoKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter1007FabricModeAuditWireTests: XCTestCase {

    private static func makeLedger() -> BASSovereignAuditLedger
    {
        let secret = SymmetricKey(size: .bits256)
        return BASSovereignAuditLedger(signingSecret: secret)
    }

    // MARK: - 1. Entry shape

    func test_BuildEntry_ShapeValid() {
        let entry = BASAgentFabricModeAuditEmitter.buildEntry(
            mode: .observationOnly,
            sessionID: "s", turnID: "t-1")
        XCTAssertFalse(entry.auditID.isEmpty)
        XCTAssertFalse(entry.verdictRef.isEmpty)
        XCTAssertEqual(entry.signalRefs.count, 1)
        XCTAssertEqual(entry.signature, "",
            "ch 1007: signature empty pre-append (ledger auto-signs)")
    }

    // MARK: - 2. Two modes produce distinguishable entries

    func testCRITICAL_TwoModes_HaveDifferentAuditIDsAndVerdicts() {
        let obsEntry = BASAgentFabricModeAuditEmitter
            .buildEntry(
                mode: .observationOnly,
                sessionID: "s", turnID: "t-1")
        let authEntry = BASAgentFabricModeAuditEmitter
            .buildEntry(
                mode: .authoritative,
                sessionID: "s", turnID: "t-1")
        XCTAssertNotEqual(obsEntry.auditID, authEntry.auditID,
            "ch 1007 CRITICAL: two modes MUST produce different " +
            "auditIDs — replay tooling needs to scope by mode")
        XCTAssertNotEqual(
            obsEntry.verdictRef, authEntry.verdictRef,
            "ch 1007 CRITICAL: two modes MUST produce different " +
            "verdictRefs")
        XCTAssertTrue(
            obsEntry.verdictRef.contains("observationOnly"))
        XCTAssertTrue(
            authEntry.verdictRef.contains("authoritative"))
    }

    // MARK: - 3. signalRefs encode mode under reserved prefix

    func test_SignalRefs_UseReservedAgentFabricPrefix() {
        let entry = BASAgentFabricModeAuditEmitter.buildEntry(
            mode: .authoritative,
            sessionID: "s", turnID: "t-1")
        XCTAssertEqual(entry.signalRefs.count, 1)
        XCTAssertTrue(
            entry.signalRefs[0].hasPrefix("agentFabric."),
            "ch 1007: signalRef MUST use reserved agentFabric.* " +
            "prefix per ch 991 reserved-prefix discipline")
        XCTAssertTrue(
            entry.signalRefs[0].contains("mode=authoritative"))
    }

    // MARK: - 4. CRITICAL — both modes write to ledger

    func testCRITICAL_BothModes_WriteToLedger() async throws {
        let ledger = Self.makeLedger()
        let initial = await ledger.count()
        // Append observationOnly
        let appended1 = try await BASAgentFabricModeAuditEmitter
            .appendToLedger(
                mode: .observationOnly,
                sessionID: "session-ch1007",
                turnID: "t-obs",
                ledger: ledger)
        // Append authoritative
        let appended2 = try await BASAgentFabricModeAuditEmitter
            .appendToLedger(
                mode: .authoritative,
                sessionID: "session-ch1007",
                turnID: "t-auth",
                ledger: ledger)
        let postCount = await ledger.count()
        XCTAssertEqual(postCount, initial + 2,
            "ch 1007 CRITICAL: both modes MUST land in ledger " +
            "(symmetric audit per ch 977 defense-in-depth)")
        XCTAssertFalse(appended1.entry.signature.isEmpty)
        XCTAssertFalse(appended2.entry.signature.isEmpty)
        // Entries are distinguishable via verdictRef
        XCTAssertTrue(
            appended1.entry.verdictRef
                .contains("observationOnly"))
        XCTAssertTrue(
            appended2.entry.verdictRef.contains("authoritative"))
    }

    // MARK: - 5. Empty sessionID throws

    func test_EmptySessionID_Throws() async {
        let ledger = Self.makeLedger()
        do {
            _ = try await BASAgentFabricModeAuditEmitter
                .appendToLedger(
                    mode: .observationOnly,
                    sessionID: "",
                    turnID: "t-1",
                    ledger: ledger)
            XCTFail("ch 1007: empty sessionID MUST throw")
        } catch {
            // expected
        }
    }
}
