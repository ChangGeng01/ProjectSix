// MARK: - BASHostGracefulDrainTests — U4 gate
//
// Load-bearing claims:run-ALL ordering (a failed step never blocks
// later truth);per-step honesty (errors land verbatim,never
// swallowed);idempotent second drain;the standard factory wires
// L8 drain + sovereign chain attestation against REAL components。

import XCTest
@testable import BASHostKit
@testable import BASSovereign

final class BASHostGracefulDrainTests: XCTestCase {

    private typealias Drain = BASHostGracefulDrain

    /// Lock-guarded execution recorder (steps are @Sendable)。
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var namesStore: [String] = []
        func mark(_ name: String) {
            lock.lock(); defer { lock.unlock() }
            namesStore.append(name)
        }
        var names: [String] {
            lock.lock(); defer { lock.unlock() }
            return namesStore
        }
    }

    private enum TestError: Error { case boom }

    // MARK: - Run-all ordering

    func testRunsEveryStepInOrderDespiteMidFailure() async {
        let rec = Recorder()
        let drain = Drain(steps: [
            Drain.Step(name: "first") { rec.mark("first"); return "ok1" },
            Drain.Step(name: "second-fails") {
                rec.mark("second-fails"); throw TestError.boom },
            Drain.Step(name: "third") { rec.mark("third"); return "ok3" },
        ])
        let report = await drain.drain()
        XCTAssertEqual(rec.names, ["first", "second-fails", "third"],
            "every step must run in order — a mid failure must not " +
            "block later truth (the chain attestation after a failed " +
            "L8 flush is exactly the point)")
        XCTAssertFalse(report.allSucceeded)
        XCTAssertEqual(report.outcomes.map(\.succeeded),
                       [true, false, true])
    }

    // MARK: - Honest failure detail

    func testFailureDetailCarriesTheVerbatimError() async {
        let drain = Drain(steps: [
            Drain.Step(name: "fails") { throw TestError.boom },
        ])
        let report = await drain.drain()
        XCTAssertEqual(report.outcomes.count, 1)
        XCTAssertFalse(report.outcomes[0].succeeded)
        XCTAssertTrue(report.outcomes[0].detail.contains("boom"),
            "the step error must land verbatim in the outcome " +
            "(never silently swallowed): \(report.outcomes[0].detail)")
        XCTAssertTrue(report.reportLine.contains("all_ok=false"))
        XCTAssertTrue(report.reportLine.contains("fails=FAIL"))
    }

    // MARK: - Idempotent second drain

    func testSecondDrainIsHonestNotHarmful() async {
        let rec = Recorder()
        let drain = Drain(steps: [
            Drain.Step(name: "flush") { rec.mark("flush"); return "n=0" },
        ])
        let r1 = await drain.drain()
        let r2 = await drain.drain()
        XCTAssertTrue(r1.allSucceeded && r2.allSucceeded,
            "a re-run drain must succeed (steps are re-run-safe)")
        XCTAssertEqual(rec.names.count, 2,
            "the second drain really re-runs the steps (no hidden " +
            "once-latch — honesty over memoization)")
    }

    // MARK: - Standard factory against REAL components

    func testStandardDrainVerifiesARealSovereignChain() async throws {
        // Real keyed ledger + sink with one appended entry。
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: BASSovereignEd25519KeyPair.generate())
        let sink = BASSovereignLedgerHostSink(ledger: ledger)
        let entry = BASSovereignAuditEntry(
            schemaVersion:
                BASSovereignAuditEntry.hardenedSchemaVersion,
            auditID: "drain-audit-1",
            sessionID: "drain-session",
            turnID: "turn-1",
            verdictRef: "verdict-1",
            ruleIDs: [], signalRefs: [], actionRefs: [],
            snapshotRef: "snap-1",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1_750_000_000))
        _ = try await ledger.append(entry)

        let drain = Drain.standard(
            memoryService: nil, sovereignSink: sink)
        let report = await drain.drain()
        XCTAssertEqual(report.outcomes.count, 1,
            "nil memory service ⇒ only the sovereign step")
        XCTAssertEqual(report.outcomes[0].name, "sovereign-verify-chain")
        XCTAssertTrue(report.allSucceeded,
            "a healthy keyed chain must attest: " +
            "\(report.outcomes[0].detail)")
        // entries=0 is CORRECT here: the entry was appended directly
        // on the ledger (not via the sink), and the sink counts only
        // its own appends — while verifyChain attests the FULL
        // persisted chain regardless of who appended。 This pins both
        // truths at once。
        XCTAssertTrue(report.outcomes[0].detail.contains("entries=0"),
            "sink count reflects sink-routed appends only: " +
            "\(report.outcomes[0].detail)")
        XCTAssertTrue(report.outcomes[0].detail.contains("verified"),
            "the attestation must cover the full ledger chain")
    }

    func testStandardDrainOmitsAbsentComponentsAndAppendsExtras() async {
        let rec = Recorder()
        let drain = Drain.standard(
            memoryService: nil, sovereignSink: nil,
            extraSteps: [
                Drain.Step(name: "host-checkpoint") {
                    rec.mark("host-checkpoint"); return "written" },
            ])
        let report = await drain.drain()
        XCTAssertEqual(report.outcomes.map(\.name), ["host-checkpoint"],
            "absent components contribute no steps;host extras append")
        XCTAssertTrue(report.allSucceeded)
        XCTAssertEqual(rec.names, ["host-checkpoint"])
    }
}
