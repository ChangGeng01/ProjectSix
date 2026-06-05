// ch1044 DEFER-3 — replay-determinism guard for the CONSEQUENTIAL turn decision.
//
// FINDING (surfaced by this guard): the FULL `BASEBrainTurnResult` is NOT
// byte-identical across two runs of the same turn — `memoryBundle.retrievedAt` is a
// real-clock OBSERVATION timestamp (stamped `Date()` by the brain history store, a
// default param). That is an intentional observation field, not part of the replay
// contract; the consequential decision never depends on it.
//
// The HIGH-1 / red-line-7 replay contract covers the CONSEQUENTIAL decision — every
// field that authorizes or constrains an action: verdict, commit tokens, WARRANTS,
// ACTUATION COMMANDS, EXECUTION RECEIPTS, sovereign LOCK, QUARANTINE records,
// RECOVERY disposition, action permit, risk card, merged choice, host gate, update
// tickets — which this guard asserts is replay-stable. (Observation fields are
// EXCLUDED by design: `memoryBundle.retrievedAt` and `sovereignAuditEntry` carry
// real-clock timestamps, which are NOT authorization state.) Any future change that
// sneaks a UUID / clock / random into one of the guarded authorization fields breaks
// this guard — the automated tripwire behind the session's "byte-equal when off"
// carriers (parity shadow, dual Ed25519 sig, …).

import XCTest
@testable import BASHostKit
import BASRuntimeCore
import Foundation

final class BASCoordinatorTurnDeterminismTests: XCTestCase {

    private func assertConsequentialEqual(
        _ a: BASEBrainTurnResult, _ b: BASEBrainTurnResult, _ ctx: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a.sovereignVerdict, b.sovereignVerdict, "verdict [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.sovereignCommitTokens, b.sovereignCommitTokens, "commitTokens [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.sovereignWarrants, b.sovereignWarrants, "warrants [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.sovereignActuationCommands, b.sovereignActuationCommands, "actuation [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.sovereignExecutionReceipts, b.sovereignExecutionReceipts, "receipts [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.sovereignLock, b.sovereignLock, "lock [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.quarantineRecords, b.quarantineRecords, "quarantine [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.recoveryDisposition, b.recoveryDisposition, "recovery [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.actionPermit, b.actionPermit, "permit [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.riskCard, b.riskCard, "risk [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.mergedChoice, b.mergedChoice, "mergedChoice [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.hostGateValue, b.hostGateValue, "hostGate [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.updateTickets, b.updateTickets, "updateTickets [\(ctx)]", file: file, line: line)
    }

    // MARK: - 1) The consequential decision is replay-stable (default request)

    func testConsequentialDecisionIsReplayStable() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let request = BASCoordinatorTestStubs.makeStubRequest()
        assertConsequentialEqual(
            coordinator.runTurn(request), coordinator.runTurn(request), "default")
    }

    // MARK: - 2) …across varied requests (incl. a high-risk one)

    func testVariedRequestsConsequentialDeterminism() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        for input in ["hello", "delete everything now", "what is 2+2", ""] {
            let req = BASCoordinatorTestStubs.makeStubRequest(userInput: input)
            assertConsequentialEqual(
                coordinator.runTurn(req), coordinator.runTurn(req), input.debugDescription)
        }
    }

    // MARK: - 3) The non-consequential difference is ONLY the observation clock

    /// Documents the finding: the memory bundle's CONTENT (atoms, tags) is stable;
    /// only the real-clock `retrievedAt` observation timestamp varies — never a
    /// consequential field.
    func testMemoryBundleContentIsStable() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let r1 = coordinator.runTurn(request)
        let r2 = coordinator.runTurn(request)
        XCTAssertEqual(r1.memoryBundle.atoms, r2.memoryBundle.atoms)
        XCTAssertEqual(r1.memoryBundle.retrievalTags, r2.memoryBundle.retrievalTags)
    }

    // MARK: - 4) The updateTickets → commit-token path is replay-stable (D1)

    /// The original guard wired `StubEvolution` (returns []), so the consequential
    /// path that derives a commit token from `updateTickets[].ticketID` was NEVER
    /// exercised — exactly how the production evolution services' `UUID()`/clock ticket
    /// ids leaked into commit-token/warrant/audit signature bytes undetected. Wire a
    /// NON-EMPTY evolution service so the path actually runs, and assert it is
    /// replay-stable (a future non-deterministic id reaching the token would break it).
    func testUpdateTicketCommitTokenPathIsReplayStable() {
        let coordinator = BASCoordinatorTestStubs.makeStub(
            evolutionService: DeterministicTicketStubEvolution())
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let r1 = coordinator.runTurn(request)
        let r2 = coordinator.runTurn(request)
        XCTAssertFalse(
            r1.updateTickets.isEmpty, "the non-empty updateTickets path must be exercised")
        assertConsequentialEqual(r1, r2, "non-empty-evolution")
    }

    // MARK: - 5) The HIGH-CONSEQUENCE turn shape is replay-stable (not just benign)

    /// ch1044 DEFER-3 gap-closure (audit follow-up). Guards 1–4 only ever drove the
    /// BENIGN shape (`StubRisk` → `.low` / `.answer`, no `requireSecondCheck`), so the
    /// consequential branches that actually matter — the `requireSecondCheck →
    /// .renderHighRisk` commit token (`+SovereignCommit.swift:76`), a non-`.pass`
    /// verdict's `sovereignLock`, the permit-driven revocations — were `nil`/empty in
    /// every covered case, and the replay-equality assertions passed VACUOUSLY
    /// (`nil == nil`). A non-determinism (UUID / clock / random) introduced INSIDE one
    /// of those branches would have slipped straight past guards 1–4. This drives a
    /// high-risk turn (`requireSecondCheck: true`, high risk card, `.delay` mode →
    /// protected-write lane), ASSERTS the high-consequence path actually fires
    /// (non-vacuity), then asserts the consequential decision is replay-stable.
    func testHighConsequenceTurnIsReplayStable() {
        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: HighRiskStub(),
            actionService: StubAction(),
            evolutionService: DeterministicTicketStubEvolution())
        let request = BASCoordinatorTestStubs.makeStubRequest(
            userInput: "execute the irreversible high-risk action now")
        let r1 = coordinator.runTurn(request)
        let r2 = coordinator.runTurn(request)

        // Non-vacuity guard: the high-risk turn MUST populate a high-consequence field,
        // otherwise the replay-equality below is the same vacuous nil==nil the benign
        // guards (1–4) already had. We accept any of the three consequential branches
        // the audit named (which one fires depends on the exact escalation level).
        let exercisedHighConsequence =
            r1.sovereignCommitTokens.contains { $0.scope == .renderHighRisk }
            || r1.sovereignLock != nil
            || !r1.quarantineRecords.isEmpty
        XCTAssertTrue(
            exercisedHighConsequence,
            "the high-risk turn must populate a high-consequence field (renderHighRisk " +
            "token / sovereignLock / quarantine); empty ⇒ this guard would be vacuous")

        assertConsequentialEqual(r1, r2, "high-consequence")
    }

    /// A risk service producing a HIGH-CONSEQUENCE turn: a high/irreversible risk card
    /// plus a permit that requires a second check (`requireSecondCheck: true`) and a
    /// `.delay` mode (→ `needsProtectedWriteLane`). This reaches the consequential
    /// commit-token / lock branches the benign `StubRisk` never does.
    struct HighRiskStub: BASRiskServicing {
        func calibrateRisk(
            contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame,
            triScores: [BASTriSelfScore], budget: BASBudgetFrame
        ) -> BASRiskCard {
            BASRiskCard(
                totalRisk: 0.85, riskLevel: .high, factors: ["stub.high"],
                uncertainty: 0.3, irreversibility: 0.9, manipulationStrength: 0.6,
                gsiScore: 0.85, recommendedMode: .delay)
        }
        func computeGSI(
            contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame
        ) -> Double { 0.85 }
        func gateAction(
            contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame,
            triScores: [BASTriSelfScore], budget: BASBudgetFrame
        ) -> (BASRiskCard, BASActionPermit) {
            (calibrateRisk(
                contextFrame: contextFrame, thoughtFrame: thoughtFrame,
                triScores: triScores, budget: budget),
             BASActionPermit(
                mode: .delay,
                reasonCodes: ["stub.high"],
                requireSecondCheck: true,
                outputLengthCap: 100,
                tonePolicy: "neutral",
                templatePolicy: "default"))
        }
    }
}
