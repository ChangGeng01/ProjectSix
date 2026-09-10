// MARK: - BASChapter983WarrantAuditBridgeTests
// chapter 九百八十三 / M3620 — Cross-Module Integration Arc ch1
//
// Closes ch 982.5 META-REVIEW cross-module Gap 7:warrant
// validation audit refs are DEAD-LETTER。 Tests pin the
// integration:
//   1. `buildEntry(...)` produces well-formed audit entries
//      (auditID + verdictRef non-empty;signalRefs preserved
//      verbatim including U+001F sentinels)
//   2. `appendToLedger(...)` actually appends + the ledger
//      accepts the auto-signed entry
//   3. The U+001F refs that ch 982.5 META-REVIEW C1 fixed
//      round-trip through the bridge unchanged
//   4. The granted/rejected outcome is reflected in both
//      auditID and verdictRef
//   5. Defense:empty sessionID rejected by ledger (not by
//      bridge — bridge stays pure-fn,ledger enforces)

import XCTest
import Crypto
@testable import BASOrchestration
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASChapter983WarrantAuditBridgeTests: XCTestCase {

    // MARK: - buildEntry pure-fn tests

    func testBuildEntry_GrantedOutcome() {
        let result = BASWarrantValidationResult(
            valid: true,
            auditRefs: [
                "agentExternal.warrant:granted:" +
                "host-root=h1\u{001F}per-agent=a1",
            ])
        let entry = BASSovereignWarrantAuditBridge.buildEntry(
            validationResult: result,
            sessionID: "sess.1",
            turnID: "t.42",
            externalAgentID: "ext.alpha",
            now: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertEqual(entry.sessionID, "sess.1")
        XCTAssertEqual(entry.turnID, "t.42")
        // ch 1010.6 / M3765 — Round-21 CRITICAL-3 fix: U+001F
        // separator between fixed-prefix CLASS and caller-supplied
        // fields。 Pre-fix `.` and `:` joins were injection-prone
        // when externalAgentID legitimately contained `.`。
        XCTAssertEqual(entry.auditID,
            "agentExternal.warrant.audit\u{001F}t.42" +
            "\u{001F}ext.alpha\u{001F}granted")
        XCTAssertEqual(entry.verdictRef,
            "agentExternal.warrant\u{001F}granted\u{001F}ext.alpha")
        XCTAssertEqual(entry.signalRefs,
            ["agentExternal.warrant:granted:" +
             "host-root=h1\u{001F}per-agent=a1"],
            "ch 983 Gap 7: signalRefs MUST preserve the " +
            "U+001F sentinel separator verbatim (ch 982.5 C1)")
        XCTAssertTrue(entry.ruleIDs.isEmpty)
        XCTAssertTrue(entry.actionRefs.isEmpty)
        XCTAssertEqual(entry.actor, .system)
        XCTAssertTrue(entry.signature.isEmpty,
            "ch 983: entry leaves ledger to auto-sign")
    }

    func testBuildEntry_RejectedOutcome() {
        let result = BASWarrantValidationResult(
            valid: false,
            auditRefs: [
                "agentExternal.warrant:invalid:" +
                "identity-mismatch",
            ])
        let entry = BASSovereignWarrantAuditBridge.buildEntry(
            validationResult: result,
            sessionID: "sess.1",
            turnID: "t.42",
            externalAgentID: "ext.beta",
            now: Date(timeIntervalSince1970: 2_000_000))
        // ch 1010.6 / M3765 — Round-21 CRITICAL-3 fix: U+001F format
        XCTAssertEqual(entry.auditID,
            "agentExternal.warrant.audit\u{001F}t.42" +
            "\u{001F}ext.beta\u{001F}rejected",
            "ch 983 Gap 7 + ch 1010.6 CRITICAL-3: outcome MUST " +
            "flow into auditID via U+001F discipline")
        XCTAssertEqual(entry.verdictRef,
            "agentExternal.warrant\u{001F}rejected\u{001F}ext.beta",
            "ch 983 Gap 7 + ch 1010.6: outcome MUST flow into " +
            "verdictRef via U+001F discipline")
    }

    func testBuildEntry_IsDeterministicGivenInputs() {
        let result = BASWarrantValidationResult(
            valid: true,
            auditRefs: ["a", "b", "c"])
        let now = Date(timeIntervalSince1970: 555)
        let e1 = BASSovereignWarrantAuditBridge.buildEntry(
            validationResult: result,
            sessionID: "s", turnID: "t",
            externalAgentID: "e", now: now)
        let e2 = BASSovereignWarrantAuditBridge.buildEntry(
            validationResult: result,
            sessionID: "s", turnID: "t",
            externalAgentID: "e", now: now)
        XCTAssertEqual(e1.auditID, e2.auditID)
        XCTAssertEqual(e1.verdictRef, e2.verdictRef)
        XCTAssertEqual(e1.signalRefs, e2.signalRefs)
        XCTAssertEqual(e1.appendedAt, e2.appendedAt,
            "ch 983: buildEntry MUST be deterministic given " +
            "all inputs (including `now`) — Root Law 7 可回放")
    }

    // MARK: - appendToLedger integration tests

    func testAppendToLedger_GrantedWarrantLandsInLedger()
        async throws
    {
        let ledger = makeLedger()
        let result = BASWarrantValidationResult(
            valid: true,
            auditRefs: [
                "agentExternal.warrant:granted:host-root=h1" +
                "\u{001F}per-agent=a1",
            ])
        let appended =
            try await BASSovereignWarrantAuditBridge
                .appendToLedger(
                    validationResult: result,
                    sessionID: "sess.1",
                    turnID: "t.7",
                    externalAgentID: "ext.gamma",
                    ledger: ledger)
        XCTAssertEqual(appended.entry.auditID,
            "agentExternal.warrant.audit\u{001F}t.7" +
            "\u{001F}ext.gamma\u{001F}granted")
        // Ledger auto-signed (signature was empty entering, must
        // be non-empty leaving)
        XCTAssertFalse(appended.entry.signature.isEmpty,
            "ch 983: ledger MUST auto-sign on empty signature")
        // Hash chain bootstrapped
        XCTAssertFalse(appended.selfHash.isEmpty)
        // U+001F sentinel survived round-trip
        XCTAssertEqual(
            appended.entry.signalRefs.first,
            "agentExternal.warrant:granted:" +
            "host-root=h1\u{001F}per-agent=a1",
            "ch 983 CRITICAL: U+001F sentinel MUST survive " +
            "ledger append unchanged (closes ch 982.5 C1 " +
            "DEAD-LETTER condition)")
    }

    func testAppendToLedger_LedgerCountIncrements()
        async throws
    {
        let ledger = makeLedger()
        let beforeAny = await ledger.count()
        XCTAssertEqual(beforeAny, 0)
        let result1 = BASWarrantValidationResult(
            valid: true, auditRefs: ["a"])
        _ = try await BASSovereignWarrantAuditBridge
            .appendToLedger(
                validationResult: result1,
                sessionID: "sess.1",
                turnID: "t.1",
                externalAgentID: "e.1",
                ledger: ledger)
        let result2 = BASWarrantValidationResult(
            valid: false, auditRefs: ["b"])
        _ = try await BASSovereignWarrantAuditBridge
            .appendToLedger(
                validationResult: result2,
                sessionID: "sess.1",
                turnID: "t.2",
                externalAgentID: "e.2",
                ledger: ledger)
        let afterTwo = await ledger.count()
        XCTAssertEqual(afterTwo, 2,
            "ch 983: each warrant validation MUST produce " +
            "exactly one ledger entry")
    }

    func testCRITICAL_AppendToLedger_RejectsEmptySession()
        async
    {
        let ledger = makeLedger()
        let result = BASWarrantValidationResult(
            valid: true, auditRefs: [])
        do {
            _ = try await BASSovereignWarrantAuditBridge
                .appendToLedger(
                    validationResult: result,
                    sessionID: "",
                    turnID: "t",
                    externalAgentID: "e",
                    ledger: ledger)
            XCTFail("Empty sessionID MUST throw")
        } catch {
            // Expected — ledger enforces sessionID non-empty
        }
    }

    // MARK: - End-to-end:validator → bridge → ledger

    func testE2E_ValidatorThroughBridgeIntoLedger()
        async throws
    {
        // Run the actual validator first
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.delta",
            reason: "trusted integration")
        let result = BASSovereignWarrantValidator.validate(
            chain: chain,
            forExternalAgentID: "ext.delta",
            nowNanos: 500_000_000_000)
        XCTAssertTrue(result.valid)
        // Bridge → ledger
        let ledger = makeLedger()
        let appended =
            try await BASSovereignWarrantAuditBridge
                .appendToLedger(
                    validationResult: result,
                    sessionID: "sess.1",
                    turnID: "t.99",
                    externalAgentID: "ext.delta",
                    ledger: ledger)
        XCTAssertEqual(appended.entry.auditID,
            "agentExternal.warrant.audit\u{001F}t.99" +
            "\u{001F}ext.delta\u{001F}granted")
        // Validator's audit ref made it through verbatim
        XCTAssertTrue(appended.entry.signalRefs.contains {
            $0.hasPrefix("agentExternal.warrant:granted:")
        }, "ch 983 E2E: validator's granted ref MUST appear " +
           "in ledger entry signalRefs")
    }

    func testE2E_RejectedValidationLandsAsRejectedEntry()
        async throws
    {
        // Identity mismatch case (per ch 981.7 CRITICAL test)
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.A")
        let result = BASSovereignWarrantValidator.validate(
            chain: chain,
            forExternalAgentID: "ext.B",  // mismatched
            nowNanos: 500_000_000_000)
        XCTAssertFalse(result.valid)
        let ledger = makeLedger()
        let appended =
            try await BASSovereignWarrantAuditBridge
                .appendToLedger(
                    validationResult: result,
                    sessionID: "sess.1",
                    turnID: "t.42",
                    externalAgentID: "ext.B",
                    ledger: ledger)
        XCTAssertEqual(appended.entry.auditID,
            "agentExternal.warrant.audit\u{001F}t.42" +
            "\u{001F}ext.B\u{001F}rejected",
            "ch 983 E2E + ch 1010.6 CRITICAL-3: identity-" +
            "mismatch MUST land as rejected entry with U+001F " +
            "separator discipline")
        // identity-mismatch audit ref made it through
        XCTAssertTrue(appended.entry.signalRefs.contains {
            $0.contains("identity-mismatch")
        }, "ch 983 E2E: validator's identity-mismatch signal " +
           "MUST appear in ledger entry signalRefs")
    }

    // MARK: - Helpers

    private func makeLedger() -> BASSovereignAuditLedger {
        let key = SymmetricKey(size: .bits256)
        return BASSovereignAuditLedger(signingSecret: key)
    }
}
