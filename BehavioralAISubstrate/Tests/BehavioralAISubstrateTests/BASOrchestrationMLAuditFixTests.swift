import XCTest
@testable import BASMemory
@testable import BASPolicy
@testable import BASOrchestration
@testable import BASRuntimeCore

/// audit M-l cluster (orchestration audit-write robustness) fixes.
final class BASOrchestrationMLAuditFixTests: XCTestCase {

    // MARK: - orchestration MED-1: no feedable process crash

    /// buildEntry previously `precondition`ed on `accepted → !auditRefs.empty` — a caller-supplied
    /// validation tuple with `(accepted: true, auditRefs: [])` CRASHED the sovereign process. The
    /// fail-safe fix RECORDS the anomaly in the audit entry instead of trapping.
    func testAcceptedWithEmptyAuditRefsRecordsAnomalyNotCrash() {
        let invocation = BASMCPInvocation(
            mcpServerID: "mcp.filesystem", toolID: "read.file", invocationID: "inv-1",
            rawOutput: "{}", permitID: "p", allowedToolDomains: ["mcp.filesystem"], nowNanos: 100)
        let permit = BASActionPermit(
            mode: .answer, allowedDomains: ["mcp.filesystem"], toolScope: "tools.read")

        // The anomaly the old precondition trapped on — must NOT crash now.
        let entry = BASMCPInvocationAuditBridge.buildEntry(
            invocation: invocation, permit: permit,
            validation: (accepted: true, auditRefs: []),
            sessionID: "s", turnID: "t-1")

        XCTAssertTrue(entry.signalRefs.contains { $0.contains("accepted-with-empty-auditRefs") },
            "the accepted-with-empty-refs anomaly must be recorded in the audit trail, not crash the process")
    }

    /// A NORMAL accepted invocation (non-empty refs) is byte-equal — the diagnostic is not injected.
    func testNormalAcceptedInvocationKeepsGateRefs() {
        let invocation = BASMCPInvocation(
            mcpServerID: "mcp.filesystem", toolID: "read.file", invocationID: "inv-1",
            rawOutput: "{}", permitID: "p", allowedToolDomains: ["mcp.filesystem"], nowNanos: 100)
        let permit = BASActionPermit(
            mode: .answer, allowedDomains: ["mcp.filesystem"], toolScope: "tools.read")
        let entry = BASMCPInvocationAuditBridge.buildEntry(
            invocation: invocation, permit: permit,
            validation: (accepted: true, auditRefs: ["gate-ref-1"]),
            sessionID: "s", turnID: "t-1")
        XCTAssertEqual(entry.signalRefs, ["gate-ref-1"], "normal case unchanged (byte-equal)")
    }

    // MARK: - orchestration MED-4: the partial write is observable

    func testRecordEventSurfacesOrphanedTraceSeqOnEventLogFailure() async throws {
        let traceLog = BASAgentTraceLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog, eventLog: ThrowingEventLog(), sessionID: "s")
        let event = BASAgentTraceEvent(
            sequenceNumber: 0, turnID: "t-1", createdAtNanos: 1,
            kind: .deltaEmitted, agentID: "a", deltaID: "d", payloadJson: "{}")

        do {
            _ = try await bridge.recordEvent(event)
            XCTFail("recordEvent must throw when the durable eventLog write fails")
        } catch let err as BASAgentTraceLogEventLogBridge.PartialWriteError {
            // The traceLog committed at some seq; the error surfaces it (was: a bare rethrow hid it).
            let traceCount = await traceLog.events(forTurn: "t-1").count
            XCTAssertEqual(traceCount, 1, "the traceLog write did commit (the orphan)")
            XCTAssertEqual(err.orphanedTraceSeq, 1,
                "the error must carry the orphaned traceSeq so success/partial-failure is distinguishable")
        } catch {
            XCTFail("expected PartialWriteError, got \(error)")
        }
    }
}

private enum ThrowingEventLogError: Error { case boom }

private actor ThrowingEventLog: BASEventLogStorage {
    func append(_ entry: BASEventLogEntry) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
        throw ThrowingEventLogError.boom
    }
    func events(forSession sessionID: String) async -> [BASEventLogEntry] { [] }
    func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] { [] }
    var totalCount: Int { 0 }
    func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int { 0 }
}
