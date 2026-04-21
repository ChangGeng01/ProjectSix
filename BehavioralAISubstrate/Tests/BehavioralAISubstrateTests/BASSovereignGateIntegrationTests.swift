import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// M1 gate demo — end-to-end integration of the three L14 core modules.
///
/// These tests prove that AuditLedger + TokenAuthority + VerdictEngine
/// compose into a single functional commit gate. Each scenario models
/// a slice of the "神经不掌权" invariant end-to-end:
///
/// - Scenario A (happy): tool-call has a valid SCT → verifyCommitToken
///   passes → VerdictEngine emits `pass` → AuditLedger records the
///   decision. Execution would proceed.
///
/// - Scenario B (no SCT): tool-call arrives without a commit token →
///   the gate reports `externalSideEffectWithoutSCT = true` →
///   VerdictEngine emits `deadStop` with `BR-003` → AuditLedger records
///   the rejection. Execution must NOT proceed.
///
/// - Scenario C (forged SCT): tool-call carries a token tampered after
///   issue → verifyCommitToken throws `signatureInvalid` → the gate
///   raises `externalSideEffectWithoutSCT = true` → BR-003 → deadStop.
///
/// - Scenario D (expired SCT): tool-call carries an expired token →
///   verifyCommitToken throws `expired` → same rejection path.
///
/// - Scenario E (reused SCT): a single-use token is redeemed twice →
///   second verification throws `alreadyUsed` → rejection path.
///
/// - Scenario F (ledger fail-closed / BR-012): a downstream audit
///   append failure blocks the verdict emission → the engine surfaces
///   `auditAppendFailed` and the caller MUST abort.
///
/// Each scenario ends with an assertion on the audit chain so the
/// trail is observable for governance.
final class BASSovereignGateIntegrationTests: XCTestCase {
    // MARK: - Gate primitive

    /// A tiny commit-gate simulator that composes the three modules in
    /// the same order a real tool-call path would: verify SCT →
    /// translate verification failure into a hard observation → ask
    /// VerdictEngine to decide → check if the verdict is `pass` before
    /// allowing side-effect execution.
    private struct Gate {
        let authority: BASSovereignTokenAuthority
        let engine: BASSovereignVerdictEngine
        let ledger: BASSovereignAuditLedger

        /// Runs the gate. Returns the emitted verdict. Does NOT perform
        /// the side effect — callers inspect `.verdictLevel == .pass`
        /// to decide.
        func guardToolWrite(
            token: BASSovereignCommitToken?,
            sessionID: String,
            turnID: String,
            actionDigest: String
        ) async throws -> BASSovereignVerdict {
            var observations = BASSovereignVerdictEngine.HardObservations.clean

            if let token {
                do {
                    try await authority.verifyCommitToken(
                        token,
                        expectedScope: .toolWrite,
                        expectedActionDigest: actionDigest,
                        redeem: true
                    )
                } catch {
                    observations.externalSideEffectWithoutSCT = true
                }
            } else {
                observations.externalSideEffectWithoutSCT = true
            }

            return try await engine.evaluate(.init(
                sessionID: sessionID,
                turnID: turnID,
                operation: .toolWrite,
                hardObservations: observations,
                evidenceSufficient: true,
                snapshotRef: "snap-1"
            ))
        }
    }

    private func makeGate(seed: String = "m1-gate-demo") async -> Gate {
        let ledger = BASSovereignAuditLedger.withSeed(seed)
        let authority = BASSovereignTokenAuthority()
        let engine = BASSovereignVerdictEngine(ledger: ledger)
        return Gate(authority: authority, engine: engine, ledger: ledger)
    }

    private func issueValidToken(
        gate: Gate,
        session: String = "S1",
        turn: String = "T1",
        digest: String = "sha256:write-fs-cache"
    ) async throws -> BASSovereignCommitToken {
        try await gate.authority.issueCommitToken(
            for: .init(
                sessionID: session,
                turnID: turn,
                scope: .toolWrite,
                allowedTargets: ["fs.write:/tmp/x"],
                actionDigest: digest,
                snapshotRef: "snap-1"
            )
        )
    }

    // MARK: - Scenarios

    func testScenarioA_ValidSCT_AllowsToolCallAndLogsPass() async throws {
        let gate = await makeGate()
        let token = try await issueValidToken(gate: gate)

        let verdict = try await gate.guardToolWrite(
            token: token,
            sessionID: "S1",
            turnID: "T1",
            actionDigest: "sha256:write-fs-cache"
        )

        XCTAssertEqual(verdict.verdictLevel, .pass, "valid SCT must result in pass")
        XCTAssertEqual(verdict.reasonCodes, [])
        let ledgerCount = await gate.ledger.count()
        XCTAssertEqual(ledgerCount, 1)
    }

    func testScenarioB_NoSCT_RejectsWithBR003DeadStop() async throws {
        let gate = await makeGate()

        let verdict = try await gate.guardToolWrite(
            token: nil,
            sessionID: "S1",
            turnID: "T1",
            actionDigest: "sha256:write-fs-cache"
        )

        XCTAssertEqual(verdict.verdictLevel, .deadStop, "no SCT must rebound to DEAD_STOP")
        XCTAssertTrue(verdict.reasonCodes.contains("BR-003"))
        XCTAssertEqual(verdict.userStubMode, .refusalOnly)

        // Governance trail: audit entry must exist and be chain-valid.
        let ledgerCount = await gate.ledger.count()
        XCTAssertEqual(ledgerCount, 1)
        try await gate.ledger.verifyChainIntegrity()
    }

    func testScenarioC_ForgedSCTSignature_RejectsWithBR003() async throws {
        let gate = await makeGate()
        let real = try await issueValidToken(gate: gate)
        var tampered = real
        tampered.signature = String(real.signature.prefix(real.signature.count - 4)) + "AAAA"

        let verdict = try await gate.guardToolWrite(
            token: tampered,
            sessionID: "S1",
            turnID: "T1",
            actionDigest: "sha256:write-fs-cache"
        )

        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-003"))
    }

    func testScenarioD_ExpiredSCT_RejectsWithBR003() async throws {
        // Craft a ledger/engine pair with a mutable clock so we can
        // advance time past the SCT's TTL.
        let ledger = BASSovereignAuditLedger.withSeed("m1-gate-expiry")
        let clock = BASExpiryClock()
        let authority = BASSovereignTokenAuthority(now: { clock.read() })
        let engine = BASSovereignVerdictEngine(ledger: ledger)
        let gate = Gate(authority: authority, engine: engine, ledger: ledger)

        let token = try await authority.issueCommitToken(
            for: .init(
                sessionID: "S1",
                turnID: "T1",
                scope: .toolWrite,
                allowedTargets: [],
                actionDigest: "sha256:expire-me",
                snapshotRef: "snap-1",
                ttlMs: 1_000 // 1s TTL
            )
        )

        // Advance past TTL.
        clock.advance(byMs: 5_000)

        let verdict = try await gate.guardToolWrite(
            token: token,
            sessionID: "S1",
            turnID: "T1",
            actionDigest: "sha256:expire-me"
        )

        XCTAssertEqual(verdict.verdictLevel, .deadStop)
        XCTAssertTrue(verdict.reasonCodes.contains("BR-003"))
    }

    func testScenarioE_ReusedSingleUseSCT_RejectsSecondCall() async throws {
        let gate = await makeGate()
        let token = try await issueValidToken(gate: gate)

        let first = try await gate.guardToolWrite(
            token: token,
            sessionID: "S1",
            turnID: "T1",
            actionDigest: "sha256:write-fs-cache"
        )
        XCTAssertEqual(first.verdictLevel, .pass)

        let second = try await gate.guardToolWrite(
            token: token,
            sessionID: "S1",
            turnID: "T1",
            actionDigest: "sha256:write-fs-cache"
        )
        XCTAssertEqual(second.verdictLevel, .deadStop,
                       "reused single-use token must be rejected on second call")
        XCTAssertTrue(second.reasonCodes.contains("BR-003"))

        // Two audit entries total.
        let count = await gate.ledger.count()
        XCTAssertEqual(count, 2)
        try await gate.ledger.verifyChainIntegrity()
    }

    func testScenarioF_LedgerFailClosed_SurfacesBR012Semantic() async throws {
        // Simulate BR-012 fail-closed: the caller passes an invalid
        // context (empty sessionID) which the ledger refuses to
        // accept. The engine MUST re-throw, so the caller cannot
        // proceed with the commit.
        let gate = await makeGate()

        do {
            _ = try await gate.engine.evaluate(.init(
                sessionID: "", // ledger will reject
                turnID: "T1",
                operation: .toolWrite,
                evidenceSufficient: true
            ))
            XCTFail("ledger should refuse to append; engine should throw")
        } catch BASSovereignVerdictEngine.EngineError.auditAppendFailed {
            // expected — BR-012 fail-closed
        }

        // No audit entry was written.
        let count = await gate.ledger.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Full audit chain shape

    func testMultipleScenariosBuildOneCoherentAuditChain() async throws {
        let gate = await makeGate()

        let good = try await issueValidToken(gate: gate, turn: "T1")
        _ = try await gate.guardToolWrite(
            token: good,
            sessionID: "S1", turnID: "T1",
            actionDigest: "sha256:write-fs-cache"
        )

        _ = try await gate.guardToolWrite(
            token: nil,
            sessionID: "S1", turnID: "T2",
            actionDigest: "sha256:write-fs-cache"
        )

        let good2 = try await issueValidToken(gate: gate, turn: "T3")
        _ = try await gate.guardToolWrite(
            token: good2,
            sessionID: "S1", turnID: "T3",
            actionDigest: "sha256:write-fs-cache"
        )

        let count = await gate.ledger.count()
        XCTAssertEqual(count, 3)
        try await gate.ledger.verifyChainIntegrity()

        let s1 = await gate.ledger.entries(forSession: "S1")
        XCTAssertEqual(s1.count, 3)
        XCTAssertEqual(s1.map(\.entry.turnID), ["T1", "T2", "T3"])
    }
}

// MARK: - Test clock

private final class BASExpiryClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date = Date(timeIntervalSince1970: 1_700_000_000)

    func read() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(byMs ms: Int) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(TimeInterval(ms) / 1000.0)
    }
}
