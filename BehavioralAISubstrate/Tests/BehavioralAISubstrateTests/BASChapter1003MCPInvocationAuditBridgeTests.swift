// MARK: - BASChapter1003MCPInvocationAuditBridgeTests
// chapter 一千零三 / M3720 — `validateMCPInvocation` scaffold close
//
// Pre-ch-1003 state (per Docs/SCAFFOLD_VS_WIRED.md ch 996
// inventory + forward-closure item #4):
//   - `BASAgentFabricAdapters.validateMCPInvocation` shipped at
//     ch 990 with a (accepted, auditRefs) tuple
//   - The auditRefs included `agentMCP.permit:granted:...` and
//     `agentMCP.permit:rejected:reason=...:server=...` shapes
//   - But NO in-substrate consumer piped those refs into the
//     `BASSovereignAuditLedger` — DEAD-LETTER condition
//   - Per Root Law 7 (可回放),every MCP-permit decision MUST be
//     replayable from the audit ledger
//   - Doctrine: "host pipeline calls it before any actual MCP
//     tool dispatch + appends audit ref to the ledger"
//
// Ch 1003 ships `BASMCPInvocationAuditBridge` mirroring the
// ch 983 `BASSovereignWarrantAuditBridge` shape verbatim。
//
// Tests pin:
//   1. buildEntry produces a valid sovereign audit entry shape
//   2. Granted MCP invocation gets a `granted` outcome encoded
//      into auditID + verdictRef
//   3. Rejected MCP invocation gets a `rejected` outcome
//   4. signalRefs carries the gate's auditRefs verbatim
//   5. validateAndAppend end-to-end: validates + writes ledger
//   6. CRITICAL: rejected invocations ALSO append to ledger
//      (defense-in-depth — silent-drop on reject would lose
//      attack-surface signal per ch 977 doctrine)
//   7. Empty sessionID throws (ledger contract)
//   8. Ledger receipt's signature is auto-computed (non-empty)

import XCTest
import CryptoKit
@testable import BASMemory
@testable import BASPolicy
@testable import BASSovereign
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter1003MCPInvocationAuditBridgeTests:
    XCTestCase
{

    // MARK: - Test fixtures

    private static func makeInvocation(
        server: String = "mcp.filesystem",
        tool: String = "read-file"
    ) -> BASMCPInvocation {
        BASMCPInvocation(
            mcpServerID: server,
            toolID: tool,
            invocationID: "inv-1",
            rawOutput: "{}",
            permitID: "permit-1",
            allowedToolDomains: [server],
            nowNanos: 1000)
    }

    private static func makePermitGranting() -> BASActionPermit {
        BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.filesystem"],
            blockedDomains: [],
            toolScope: "tools.read")
    }

    private static func makePermitBlocking() -> BASActionPermit {
        BASActionPermit(
            mode: .block,
            allowedDomains: [],
            blockedDomains: [],
            toolScope: "none")
    }

    private static func makeLedger() -> BASSovereignAuditLedger {
        // Stable test-key — production hosts pass live secret
        let secret = SymmetricKey(size: .bits256)
        return BASSovereignAuditLedger(signingSecret: secret)
    }

    // MARK: - 1. buildEntry shape

    func test_BuildEntry_ProducesValidShape() {
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitGranting()
        let validation = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        let entry = BASMCPInvocationAuditBridge.buildEntry(
            invocation: invocation,
            permit: permit,
            validation: validation,
            sessionID: "session-1",
            turnID: "t-1")
        XCTAssertFalse(entry.auditID.isEmpty,
            "ch 1003: auditID MUST be non-empty (ledger contract)")
        XCTAssertEqual(entry.sessionID, "session-1")
        XCTAssertEqual(entry.turnID, "t-1")
        XCTAssertFalse(entry.verdictRef.isEmpty,
            "ch 1003: verdictRef MUST be non-empty (ledger contract)")
        XCTAssertEqual(entry.signature, "",
            "ch 1003: signature MUST be empty pre-append " +
            "(ledger auto-signs per ch 716 routed-seal discipline)")
    }

    // MARK: - 2. Granted outcome encoded into auditID + verdictRef

    func test_GrantedInvocation_EncodesGrantedOutcome() {
        let invocation = Self.makeInvocation(
            server: "mcp.filesystem", tool: "read-file")
        let permit = Self.makePermitGranting()
        let validation = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertTrue(validation.accepted,
            "ch 1003 precondition: permit MUST grant for this " +
            "test setup (server in allowedDomains + non-deny scope)")
        let entry = BASMCPInvocationAuditBridge.buildEntry(
            invocation: invocation,
            permit: permit,
            validation: validation,
            sessionID: "s", turnID: "t-1")
        XCTAssertTrue(
            entry.auditID.contains("granted"),
            "ch 1003: granted invocation auditID MUST include " +
            "`granted` outcome, got: \(entry.auditID)")
        XCTAssertTrue(
            entry.verdictRef.contains("granted"),
            "ch 1003: granted invocation verdictRef MUST include " +
            "`granted`, got: \(entry.verdictRef)")
        XCTAssertTrue(
            entry.auditID.contains("mcp.filesystem"),
            "ch 1003: auditID MUST include serverID for replay " +
            "scoping, got: \(entry.auditID)")
        XCTAssertTrue(
            entry.auditID.contains("read-file"),
            "ch 1003: auditID MUST include toolID, got: " +
            "\(entry.auditID)")
    }

    // MARK: - 3. Rejected outcome

    func test_RejectedInvocation_EncodesRejectedOutcome() {
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitBlocking()
        let validation = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(validation.accepted,
            "ch 1003 precondition: block-mode permit MUST reject")
        let entry = BASMCPInvocationAuditBridge.buildEntry(
            invocation: invocation,
            permit: permit,
            validation: validation,
            sessionID: "s", turnID: "t-1")
        XCTAssertTrue(
            entry.auditID.contains("rejected"),
            "ch 1003: rejected invocation auditID MUST include " +
            "`rejected` outcome")
        XCTAssertTrue(
            entry.verdictRef.contains("rejected"),
            "ch 1003: rejected invocation verdictRef MUST include " +
            "`rejected`")
    }

    // MARK: - 4. signalRefs carries gate auditRefs verbatim

    func test_SignalRefs_VerbatimFromGate() {
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitBlocking()
        let validation = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        let entry = BASMCPInvocationAuditBridge.buildEntry(
            invocation: invocation,
            permit: permit,
            validation: validation,
            sessionID: "s", turnID: "t-1")
        XCTAssertEqual(entry.signalRefs, validation.auditRefs,
            "ch 1003 CRITICAL: signalRefs MUST equal gate's " +
            "auditRefs verbatim — no transformation, no dropping。 " +
            "ch 977 defense-in-depth requires full diagnostic " +
            "to land in ledger for replay")
    }

    // MARK: - 5. validateAndAppend end-to-end

    func testCRITICAL_ValidateAndAppend_GrantedWritesLedger()
        async throws
    {
        let ledger = Self.makeLedger()
        let initialCount = await ledger.count()
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitGranting()
        let result = try await BASMCPInvocationAuditBridge
            .validateAndAppend(
                invocation: invocation,
                permit: permit,
                sessionID: "session-e2e",
                turnID: "t-1",
                ledger: ledger)
        XCTAssertTrue(result.validation.accepted,
            "ch 1003: granted invocation MUST report accepted=true")
        let postCount = await ledger.count()
        XCTAssertEqual(postCount, initialCount + 1,
            "ch 1003 CRITICAL: granted invocation MUST append " +
            "exactly 1 entry to ledger (closes DEAD-LETTER)")
        XCTAssertFalse(
            result.appendedEntry.entry.signature.isEmpty,
            "ch 1003: ledger MUST auto-sign the entry (HMAC mode)")
    }

    // MARK: - 6. CRITICAL — rejected ALSO writes ledger

    func testCRITICAL_ValidateAndAppend_RejectedWritesLedger()
        async throws
    {
        let ledger = Self.makeLedger()
        let initialCount = await ledger.count()
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitBlocking()
        let result = try await BASMCPInvocationAuditBridge
            .validateAndAppend(
                invocation: invocation,
                permit: permit,
                sessionID: "session-e2e",
                turnID: "t-1",
                ledger: ledger)
        XCTAssertFalse(result.validation.accepted,
            "ch 1003: blocked invocation MUST report accepted=false")
        let postCount = await ledger.count()
        XCTAssertEqual(postCount, initialCount + 1,
            "ch 1003 CRITICAL: REJECTED invocation MUST ALSO " +
            "append to ledger (defense-in-depth per ch 977 — " +
            "silently dropping rejections would lose attack-" +
            "surface signal)")
        XCTAssertTrue(
            result.appendedEntry.entry.verdictRef
                .contains("rejected"),
            "ch 1003: rejection verdict in ledger MUST encode " +
            "`rejected` outcome for replay clarity")
    }

    // MARK: - 7. Empty sessionID throws

    func test_EmptySessionID_Throws() async {
        let ledger = Self.makeLedger()
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitGranting()
        do {
            _ = try await BASMCPInvocationAuditBridge
                .validateAndAppend(
                    invocation: invocation,
                    permit: permit,
                    sessionID: "",  // ⚠ violates ledger contract
                    turnID: "t-1",
                    ledger: ledger)
            XCTFail("ch 1003: empty sessionID MUST throw " +
                "(ledger contract violation)")
        } catch {
            // Expected — ledger.append throws LedgerError
            // .invalidEntry for empty sessionID
        }
    }

    // MARK: - 8. Append-only variant works

    func test_AppendToLedger_PreValidatedResultWorks()
        async throws
    {
        let ledger = Self.makeLedger()
        let invocation = Self.makeInvocation()
        let permit = Self.makePermitGranting()
        let validation = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        let appended = try await BASMCPInvocationAuditBridge
            .appendToLedger(
                invocation: invocation,
                permit: permit,
                validation: validation,
                sessionID: "s", turnID: "t-1",
                ledger: ledger)
        XCTAssertFalse(appended.entry.signature.isEmpty,
            "ch 1003: pre-validated appendToLedger MUST also " +
            "produce signed ledger entry")
        XCTAssertEqual(appended.entry.signalRefs,
            validation.auditRefs,
            "ch 1003: appendToLedger preserves gate auditRefs " +
            "verbatim")
    }
}
