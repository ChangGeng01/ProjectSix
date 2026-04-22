import XCTest
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration

/// M58 — L13 update-ticket main-chain wiring.
///
/// Before M58 the evolution service emitted a `[BASUpdateTicket]`
/// list, but no observation bundle was derived on the main-chain
/// thought frame. The L14 audit surface had no structured way to
/// reconcile "what L13 claimed about ticket T" against "what
/// governance accepted / rejected for ticket T". These tests pin
/// the main-chain behavior:
///
///   1. `BASUpdateTicketObservationBundle.derive(
///        fromUpdateTickets:turnID:sessionID:emittedAt:)` emits a
///      bundle whose contents deterministically mirror the input
///      ticket list (same inputs → same bundle byte-for-byte).
///   2. Two disjoint paths route the derivation —
///        primary (tickets non-empty) and empty (tickets empty).
///      The empty path is the legitimate "no-evolution turn"
///      signal and correctly yields `hasCoreSignalCoverage ==
///      false` + zero observations.
///   3. Each of the six signal kinds (.submission /
///      .hostChangeProposed / .memoryWriteProposed /
///      .ruleCandidateProposed / .conflictDetected /
///      .reviewRequired) is emitted iff the structural
///      precondition holds; no ghost signals.
///   4. Shape classification follows the 5-case rule: zero
///      mutations → .reviewOnly; exactly one → the matching shape;
///      two or more → .composite.
///   5. `BASThoughtFrame.withDerivedUpdateTicketObservationBundle(
///      updateTickets:turnID:sessionID:emittedAt:)` returns a copy
///      with the bundle attached and leaves every other field
///      untouched.
///   6. The bundle feeds the M32 L13 coverage projection
///      (`hasCoreSignalCoverage` == has `.submission`;
///      `subjectIDs` == distinct ticketIDs first-seen).
///   7. Budget stays clamped in [0, 1] even when many signals are
///      emitted simultaneously.
///   8. Legacy `hostProfileChangeSuggestion` paths route through
///      `resolvedHostChangeCandidate` and emit `.hostChangeProposed`.
final class BASUpdateTicketObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)
    private let turnID = "t-abc"
    private let sessionID = "s-xyz"

    /// Builds a minimal ticket with explicit knobs for every flag
    /// that derivation reads. Defaults produce a submission-only
    /// ticket with shape=.reviewOnly and requiresReview=true (the
    /// default carries review semantics because M58 treats
    /// "requires review but no mutation" as review-only, not as
    /// an empty ticket).
    private func ticket(
        id: String = "tix-1",
        confidence: Double = 0.75,
        memoryWrite: String? = nil,
        hostChange: BASHostChangeCandidate? = nil,
        hostProfileSuggestion: String? = nil,
        ruleRef: String? = nil,
        conflictFlag: Bool = false,
        requiresReview: Bool = true
    ) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "session-fixture",
            summary: "t-\(id)",
            memoryWriteSuggestion: memoryWrite,
            hostChangeCandidate: hostChange,
            hostProfileChangeSuggestion: hostProfileSuggestion,
            ruleCandidateRef: ruleRef,
            confidence: confidence,
            conflictFlag: conflictFlag,
            requiresReview: requiresReview
        )
    }

    private func hostChangeCandidate(
        id: String = "hc-1",
        changeType: String = "boundary.soften",
        confidence: Double = 0.7,
        conflictRefs: [String] = [],
        approvalState: String = "pending"
    ) -> BASHostChangeCandidate {
        BASHostChangeCandidate(
            candidateID: id,
            changeType: changeType,
            proposedDelta: ["delta-1", "delta-2"],
            evidenceRefs: ["ev-a"],
            cooldownUntil: fixedDate,
            confidence: confidence,
            conflictRefs: conflictRefs,
            hostVersionRef: "hv-1",
            previewState: "idle",
            approvalState: approvalState
        )
    }

    private func derive(
        _ tickets: [BASUpdateTicket]
    ) -> BASUpdateTicketObservationBundle {
        BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: tickets,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate
        )
    }

    // MARK: - Path 1: empty tickets → empty bundle

    func testEmptyTicketsYieldEmptyBundle() {
        let bundle = derive([])
        XCTAssertEqual(bundle.turnID, turnID)
        XCTAssertEqual(bundle.sessionID, sessionID)
        XCTAssertEqual(bundle.emittedAt, fixedDate)
        XCTAssertEqual(bundle.observations.count, 0)
        XCTAssertEqual(bundle.subjectIDs, [])
    }

    func testEmptyBundleHasNoCoverage() {
        let bundle = derive([])
        XCTAssertFalse(bundle.hasAnySubmission)
        XCTAssertFalse(bundle.hasAnyMutationProposal)
        XCTAssertFalse(bundle.hasAnyConflict)
        XCTAssertFalse(bundle.hasAnyReviewRequirement)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
    }

    func testEmptyBundleBudgetIsZero() {
        let bundle = derive([])
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.totalCost(for: bundle),
            0.0,
            accuracy: 1e-9)
    }

    // MARK: - Path 2: single-ticket shapes

    func testReviewOnlyTicketShape() {
        // No mutation evidence, requiresReview=true.
        let t = ticket(id: "tix-ro")
        let bundle = derive([t])
        // submission + reviewRequired = 2
        XCTAssertEqual(bundle.observations.count, 2)
        let submission = bundle.observations(of: .submission)
        XCTAssertEqual(submission.count, 1)
        XCTAssertEqual(submission[0].shape, .reviewOnly)
        XCTAssertEqual(submission[0].subjectID, "tix-ro")
        XCTAssertFalse(bundle.hasAnyMutationProposal)
        XCTAssertTrue(bundle.hasAnyReviewRequirement)
    }

    func testMemoryWriteOnlyTicketShape() {
        let t = ticket(
            id: "tix-mw",
            memoryWrite: "Remember: coffee after dinner",
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertEqual(bundle.observations.count, 2)
        XCTAssertEqual(
            bundle.observations(of: .submission)[0].shape,
            .memoryWrite)
        XCTAssertEqual(
            bundle.observations(of: .memoryWriteProposed).count, 1)
        XCTAssertFalse(bundle.hasAnyConflict)
        XCTAssertFalse(bundle.hasAnyReviewRequirement)
        XCTAssertTrue(bundle.hasAnyMutationProposal)
    }

    func testHostChangeOnlyTicketShape() {
        let t = ticket(
            id: "tix-hc",
            hostChange: hostChangeCandidate(),
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertEqual(bundle.observations.count, 2)
        XCTAssertEqual(
            bundle.observations(of: .submission)[0].shape,
            .hostChange)
        let hostObs = bundle.observations(of: .hostChangeProposed)
        XCTAssertEqual(hostObs.count, 1)
        XCTAssertEqual(hostObs[0].shape, .hostChange)
        XCTAssertTrue(hostObs[0].content.contains("boundary.soften"))
        XCTAssertTrue(hostObs[0].content.contains("delta-count:2"))
    }

    func testRuleCandidateOnlyTicketShape() {
        let t = ticket(
            id: "tix-rc",
            ruleRef: "rule-42",
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertEqual(bundle.observations.count, 2)
        XCTAssertEqual(
            bundle.observations(of: .submission)[0].shape,
            .ruleCandidate)
        let ruleObs = bundle.observations(of: .ruleCandidateProposed)
        XCTAssertEqual(ruleObs.count, 1)
        XCTAssertEqual(ruleObs[0].shape, .ruleCandidate)
        XCTAssertTrue(ruleObs[0].content.contains("rule-42"))
    }

    func testCompositeShapeFromTwoMutations() {
        let t = ticket(
            id: "tix-mix",
            memoryWrite: "Write note",
            hostChange: hostChangeCandidate(),
            requiresReview: false)
        let bundle = derive([t])
        // submission + hostChange + memoryWrite = 3
        XCTAssertEqual(bundle.observations.count, 3)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .composite)
        }
    }

    func testCompositeShapeFromThreeMutations() {
        let t = ticket(
            id: "tix-triple",
            memoryWrite: "Note",
            hostChange: hostChangeCandidate(),
            ruleRef: "rule-X",
            requiresReview: false)
        let bundle = derive([t])
        // submission + hostChange + memoryWrite + ruleCandidate = 4
        XCTAssertEqual(bundle.observations.count, 4)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .composite)
        }
        XCTAssertEqual(
            bundle.observations(of: .hostChangeProposed).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .memoryWriteProposed).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .ruleCandidateProposed).count, 1)
    }

    // MARK: - Path 3: per-signal kind gating

    func testConflictFlagTriggersConflictDetected() {
        let t = ticket(
            id: "tix-conf",
            conflictFlag: true,
            requiresReview: false)
        let bundle = derive([t])
        // submission + conflictDetected = 2
        XCTAssertEqual(bundle.observations.count, 2)
        XCTAssertTrue(bundle.hasAnyConflict)
        let conflict = bundle.observations(of: .conflictDetected)
        XCTAssertEqual(conflict.count, 1)
        XCTAssertEqual(conflict[0].salience, 1.0)
    }

    func testReviewRequiredTriggersReviewRequired() {
        let t = ticket(id: "tix-rev", requiresReview: true)
        let bundle = derive([t])
        XCTAssertTrue(bundle.hasAnyReviewRequirement)
        let review = bundle.observations(of: .reviewRequired)
        XCTAssertEqual(review.count, 1)
        XCTAssertEqual(review[0].salience, 0.85)
        XCTAssertTrue(review[0].content.contains("conflict:false"))
    }

    func testFullSignalStack() {
        let t = ticket(
            id: "tix-full",
            memoryWrite: "All together",
            hostChange: hostChangeCandidate(),
            ruleRef: "rule-F",
            conflictFlag: true,
            requiresReview: true)
        let bundle = derive([t])
        // submission + hostChange + memoryWrite + ruleCandidate
        //   + conflict + review = 6
        XCTAssertEqual(bundle.observations.count, 6)
        XCTAssertTrue(bundle.hasAnySubmission)
        XCTAssertTrue(bundle.hasAnyMutationProposal)
        XCTAssertTrue(bundle.hasAnyConflict)
        XCTAssertTrue(bundle.hasAnyReviewRequirement)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
        // conflict + review are both set, review content should
        // reflect conflict:true
        let review = bundle.observations(of: .reviewRequired)[0]
        XCTAssertTrue(review.content.contains("conflict:true"))
    }

    // MARK: - Path 4: no ghost signals

    func testEmptyMemoryWriteIsTreatedAsAbsent() {
        let t = ticket(
            id: "tix-empty-mw",
            memoryWrite: "   \n\t  ",
            requiresReview: false)
        let bundle = derive([t])
        // Whitespace-only memoryWrite should be treated as absent
        // → reviewOnly shape, no memoryWriteProposed.
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertEqual(
            bundle.observations(of: .submission)[0].shape,
            .reviewOnly)
        XCTAssertFalse(bundle.hasAnyMutationProposal)
    }

    func testEmptyRuleRefIsTreatedAsAbsent() {
        let t = ticket(
            id: "tix-empty-rr",
            ruleRef: "",
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertFalse(bundle.hasAnyMutationProposal)
    }

    func testNoConflictFlagSkipsConflictSignal() {
        let t = ticket(
            id: "tix-no-conf",
            memoryWrite: "text",
            conflictFlag: false,
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertFalse(bundle.hasAnyConflict)
        XCTAssertEqual(
            bundle.observations(of: .conflictDetected).count, 0)
    }

    func testNoReviewRequirementSkipsReviewSignal() {
        let t = ticket(
            id: "tix-no-rev",
            memoryWrite: "text",
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertFalse(bundle.hasAnyReviewRequirement)
        XCTAssertEqual(
            bundle.observations(of: .reviewRequired).count, 0)
    }

    // MARK: - Path 5: legacy hostProfileChangeSuggestion

    func testLegacyHostProfileSuggestionTriggersHostChange() {
        let t = ticket(
            id: "tix-legacy",
            hostProfileSuggestion: "Align boundary to protective",
            requiresReview: false)
        let bundle = derive([t])
        // Legacy path synthesizes a resolvedHostChangeCandidate,
        // which should emit .hostChangeProposed.
        XCTAssertEqual(bundle.observations.count, 2)
        XCTAssertEqual(
            bundle.observations(of: .submission)[0].shape,
            .hostChange)
        XCTAssertEqual(
            bundle.observations(of: .hostChangeProposed).count, 1)
    }

    func testEmptyLegacySuggestionDoesNotTriggerHostChange() {
        let t = ticket(
            id: "tix-empty-legacy",
            hostProfileSuggestion: "   ",
            requiresReview: false)
        let bundle = derive([t])
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertEqual(
            bundle.observations(of: .submission)[0].shape,
            .reviewOnly)
    }

    // MARK: - Path 6: multi-ticket ordering + subjects

    func testMultipleTicketsPreserveSourceOrder() {
        let t1 = ticket(id: "t1", requiresReview: false)
        let t2 = ticket(id: "t2", requiresReview: false)
        let t3 = ticket(id: "t3", requiresReview: false)
        let bundle = derive([t1, t2, t3])
        let ids = bundle.observations(of: .submission).map(\.subjectID)
        XCTAssertEqual(ids, ["t1", "t2", "t3"])
    }

    func testMultipleTicketsYieldDistinctSubjects() {
        let t1 = ticket(id: "t1", requiresReview: false)
        let t2 = ticket(
            id: "t2", memoryWrite: "a", requiresReview: false)
        let t3 = ticket(
            id: "t3", ruleRef: "r", requiresReview: false)
        let bundle = derive([t1, t2, t3])
        XCTAssertEqual(bundle.subjectIDs, ["t1", "t2", "t3"])
    }

    func testDuplicateTicketIDEmitsTwiceButDedupesSubjectList() {
        let a = ticket(id: "dup", requiresReview: false)
        let b = ticket(id: "dup", memoryWrite: "x", requiresReview: false)
        let bundle = derive([a, b])
        // 1 submission (from a) + 1 submission (from b) + 1
        // memoryWriteProposed (from b) = 3
        XCTAssertEqual(bundle.observations.count, 3)
        XCTAssertEqual(
            bundle.observations(of: .submission).count, 2)
        // But subjectIDs dedupes to one.
        XCTAssertEqual(bundle.subjectIDs, ["dup"])
    }

    func testSubjectFilterReturnsOnlyMatchingTickets() {
        let t1 = ticket(id: "t1", requiresReview: false)
        let t2 = ticket(
            id: "t2",
            memoryWrite: "x",
            conflictFlag: true,
            requiresReview: true)
        let bundle = derive([t1, t2])
        let t2Obs = bundle.observations(forSubject: "t2")
        // submission + memoryWrite + conflict + review = 4
        XCTAssertEqual(t2Obs.count, 4)
        for obs in t2Obs {
            XCTAssertEqual(obs.subjectID, "t2")
        }
    }

    // MARK: - Path 7: shape-based filtering

    func testShapeFilterReturnsOnlyMatchingObservations() {
        let a = ticket(id: "a", requiresReview: false)
        let b = ticket(
            id: "b", memoryWrite: "x", requiresReview: false)
        let c = ticket(
            id: "c", hostChange: hostChangeCandidate(),
            requiresReview: false)
        let bundle = derive([a, b, c])
        let reviewOnly =
            bundle.observations(forShape: .reviewOnly)
        let memoryWrite =
            bundle.observations(forShape: .memoryWrite)
        let hostChange =
            bundle.observations(forShape: .hostChange)
        XCTAssertEqual(reviewOnly.count, 1)
        XCTAssertEqual(memoryWrite.count, 2)   // submission + write
        XCTAssertEqual(hostChange.count, 2)    // submission + hostChange
    }

    // MARK: - Path 8: Salience & confidence semantics

    func testSubmissionSalienceMatchesTicketConfidence() {
        let high = ticket(
            id: "hi", confidence: 0.90, requiresReview: false)
        let low = ticket(
            id: "lo", confidence: 0.10, requiresReview: false)
        let bundle = derive([high, low])
        let subs = bundle.observations(of: .submission)
        XCTAssertEqual(subs[0].salience, 0.90)
        XCTAssertEqual(subs[1].salience, 0.10)
    }

    func testSubmissionConfidenceHasFloor() {
        let t = ticket(
            id: "zero", confidence: 0.0, requiresReview: false)
        let bundle = derive([t])
        let sub = bundle.observations(of: .submission)[0]
        // Submission confidence has a 0.5 floor.
        XCTAssertEqual(sub.confidence, 0.5)
    }

    func testHostChangeConfidenceHasFloor() {
        // Candidate-level confidence=0 should floor to 0.5 on the
        // emitted observation.
        let t = ticket(
            id: "hc-low",
            hostChange: hostChangeCandidate(confidence: 0.0),
            requiresReview: false)
        let bundle = derive([t])
        let hc = bundle.observations(of: .hostChangeProposed)[0]
        XCTAssertEqual(hc.confidence, 0.5)
    }

    func testConfidenceClampedInRange() {
        // Salience/confidence values on observations are clamped
        // to [0, 1] in the BASUpdateTicketObservation initializer.
        let t = BASUpdateTicket(
            ticketID: "clamp",
            sessionRef: "s",
            summary: "c",
            confidence: 1.5,
            conflictFlag: false,
            requiresReview: false)
        let bundle = derive([t])
        let sub = bundle.observations(of: .submission)[0]
        XCTAssertLessThanOrEqual(sub.salience, 1.0)
        XCTAssertGreaterThanOrEqual(sub.salience, 0.0)
    }

    // MARK: - Path 9: content payload contracts

    func testSubmissionContentIsDeterministic() {
        let t = ticket(
            id: "fixed-id",
            confidence: 0.50,
            requiresReview: false)
        let bundle = derive([t])
        let sub = bundle.observations(of: .submission)[0]
        XCTAssertEqual(
            sub.content,
            "l13.submission.ticket:fixed-id"
            + ".shape:reviewOnly"
            + ".confidence:0.50")
    }

    func testHostChangeContentCarriesChangeType() {
        let t = ticket(
            id: "hc-t",
            hostChange: hostChangeCandidate(
                changeType: "relation.revoke"),
            requiresReview: false)
        let bundle = derive([t])
        let hc = bundle.observations(of: .hostChangeProposed)[0]
        XCTAssertTrue(hc.content.contains("type:relation.revoke"))
    }

    func testMemoryWriteContentTruncatesLongPreview() {
        let longText = String(repeating: "A", count: 200)
        let t = ticket(
            id: "mw-long",
            memoryWrite: longText,
            requiresReview: false)
        let bundle = derive([t])
        let mw = bundle.observations(of: .memoryWriteProposed)[0]
        // Length field reflects the full trimmed length; preview
        // is truncated to 40 chars + ellipsis.
        XCTAssertTrue(mw.content.contains("len:200"))
        XCTAssertTrue(mw.content.contains("…"))
        XCTAssertFalse(mw.content.contains(longText))
    }

    func testMemoryWriteContentShortDoesNotTruncate() {
        let t = ticket(
            id: "mw-short",
            memoryWrite: "Short note",
            requiresReview: false)
        let bundle = derive([t])
        let mw = bundle.observations(of: .memoryWriteProposed)[0]
        XCTAssertTrue(mw.content.contains("preview:Short note"))
        XCTAssertFalse(mw.content.contains("…"))
    }

    func testRuleCandidateContentCarriesRef() {
        let t = ticket(
            id: "rc-t",
            ruleRef: "rule-namespace.key",
            requiresReview: false)
        let bundle = derive([t])
        let rc = bundle.observations(of: .ruleCandidateProposed)[0]
        XCTAssertTrue(rc.content.contains("rule-namespace.key"))
    }

    // MARK: - Path 10: budget semantics

    func testBudgetCostPerKindMatchesTable() {
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.cost(for: .submission),
            0.10, accuracy: 1e-9)
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.cost(
                for: .hostChangeProposed),
            0.20, accuracy: 1e-9)
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.cost(
                for: .memoryWriteProposed),
            0.15, accuracy: 1e-9)
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.cost(
                for: .ruleCandidateProposed),
            0.15, accuracy: 1e-9)
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.cost(
                for: .conflictDetected),
            0.25, accuracy: 1e-9)
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.cost(
                for: .reviewRequired),
            0.15, accuracy: 1e-9)
    }

    func testBudgetClampedAtOne() {
        // 20 tickets, each emitting full stack → way over 1.0 raw
        // but clamp holds.
        let tickets = (0..<20).map { i in
            ticket(
                id: "t\(i)",
                memoryWrite: "note",
                hostChange: hostChangeCandidate(id: "hc-\(i)"),
                ruleRef: "r-\(i)",
                conflictFlag: true,
                requiresReview: true)
        }
        let bundle = derive(tickets)
        let total =
            BASUpdateTicketObservationBudget.totalCost(for: bundle)
        XCTAssertLessThanOrEqual(total, 1.0)
        XCTAssertGreaterThanOrEqual(total, 0.0)
    }

    func testSingleReviewOnlyBudget() {
        let t = ticket(id: "t1", requiresReview: true)
        let bundle = derive([t])
        // submission(0.10) + review(0.15) = 0.25
        XCTAssertEqual(
            BASUpdateTicketObservationBudget.totalCost(for: bundle),
            0.25, accuracy: 1e-9)
    }

    // MARK: - Path 11: determinism

    func testSameInputsProduceByteEqualBundles() {
        let tickets = [
            ticket(
                id: "a", memoryWrite: "x",
                requiresReview: false),
            ticket(
                id: "b",
                hostChange: hostChangeCandidate(),
                conflictFlag: true,
                requiresReview: true)
        ]
        let a = derive(tickets)
        let b = derive(tickets)
        XCTAssertEqual(a, b)
    }

    func testDifferentTurnIDsProduceDifferentBundles() {
        let tickets = [ticket(id: "t1", requiresReview: false)]
        let a = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: tickets,
            turnID: "turn-a",
            sessionID: sessionID,
            emittedAt: fixedDate)
        let b = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: tickets,
            turnID: "turn-b",
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.turnID, "turn-a")
        XCTAssertEqual(b.turnID, "turn-b")
    }

    // MARK: - Path 12: coherence with turn coordinates

    func testBundleCarriesCallerTurnAndSessionIDs() {
        let bundle = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: [
                ticket(id: "a", requiresReview: false)
            ],
            turnID: "turn-123",
            sessionID: "session-456",
            emittedAt: fixedDate)
        XCTAssertEqual(bundle.turnID, "turn-123")
        XCTAssertEqual(bundle.sessionID, "session-456")
    }

    // MARK: - Path 13: withDerived helper integration

    func testFrameHelperAttachesBundle() {
        let base = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-1")
        XCTAssertNil(base.updateTicketObservationBundle)
        let withBundle = base
            .withDerivedUpdateTicketObservationBundle(
                updateTickets: [
                    ticket(id: "t1", requiresReview: false)
                ],
                turnID: "turn-1",
                sessionID: "session-1",
                emittedAt: fixedDate)
        XCTAssertNotNil(withBundle.updateTicketObservationBundle)
        XCTAssertEqual(
            withBundle.updateTicketObservationBundle?.turnID,
            "turn-1")
        XCTAssertEqual(
            withBundle.updateTicketObservationBundle?
                .observations.count,
            1)
    }

    func testFrameHelperOverwritesExistingBundle() {
        let prior = BASUpdateTicketObservationBundle(
            turnID: "old",
            sessionID: "old",
            observations: [],
            emittedAt: fixedDate)
        let base = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-1",
            updateTicketObservationBundle: prior)
        let reDerived = base
            .withDerivedUpdateTicketObservationBundle(
                updateTickets: [
                    ticket(id: "n1", requiresReview: false)
                ],
                turnID: "new",
                sessionID: "new",
                emittedAt: fixedDate)
        XCTAssertEqual(
            reDerived.updateTicketObservationBundle?.turnID, "new")
        XCTAssertEqual(
            reDerived.updateTicketObservationBundle?.observations
                .count,
            1)
    }

    func testFrameHelperPreservesOtherFields() {
        let base = BASThoughtFrame(
            stepIndex: 3,
            decomposeRef: "decomp-7",
            memoryRefs: ["m1", "m2"],
            stabilityScore: 0.42)
        let withBundle = base
            .withDerivedUpdateTicketObservationBundle(
                updateTickets: [],
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)
        XCTAssertEqual(withBundle.stepIndex, 3)
        XCTAssertEqual(withBundle.decomposeRef, "decomp-7")
        XCTAssertEqual(withBundle.memoryRefs, ["m1", "m2"])
        XCTAssertEqual(withBundle.stabilityScore, 0.42)
    }

    // MARK: - Path 14: schema version
    //
    // M58 bumped the frame from 1.7.0 → 1.8.0 for the L13 bundle.
    // M59 subsequently bumped it to 1.9.0 for the L4 world-prior
    // bundle (additive — the L13 field is unchanged). M60 moved
    // it to 1.10.0 for the L1 lease-life bundle (still additive —
    // the L13 field is unchanged). The test asserts the current
    // version so any future additive bundle field prompts an
    // explicit bump review.

    func testThoughtFrameSchemaVersionAtOrAboveOneEightZero() {
        // Sanity floor: M58 established 1.8.0 as the L13-bundle
        // floor; M59 moved it to 1.9.0; M60 moved it to 1.10.0;
        // M61 moved it to 1.11.0; M62 moved it to 1.12.0.
        // Downstream legacy decoders expect the field to exist at
        // or above this floor.
        XCTAssertEqual(
            BASThoughtFrame.currentSchemaVersion, "1.12.0")
    }

    // MARK: - Path 15: bundle helpers

    func testObservationsOfKindFilter() {
        let t = ticket(
            id: "t1",
            memoryWrite: "x",
            conflictFlag: true,
            requiresReview: true)
        let bundle = derive([t])
        XCTAssertEqual(
            bundle.observations(of: .submission).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .memoryWriteProposed).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .conflictDetected).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .reviewRequired).count, 1)
        // Kinds not emitted should return empty.
        XCTAssertEqual(
            bundle.observations(of: .hostChangeProposed).count, 0)
        XCTAssertEqual(
            bundle.observations(of: .ruleCandidateProposed).count, 0)
    }

    func testHasCoreSignalCoverageRequiresSubmission() {
        let bundle = derive([])
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
        let withTicket = derive([
            ticket(id: "t1", requiresReview: false)
        ])
        XCTAssertTrue(withTicket.hasCoreSignalCoverage)
    }

    // MARK: - Path 16: ledger semantics

    func testLedgerRecordAndSnapshot() async {
        let ledger = BASUpdateTicketObservationLedger(capacity: 3)
        let a = derive([ticket(id: "a", requiresReview: false)])
        let b = derive([ticket(id: "b", requiresReview: false)])
        await ledger.record(a)
        await ledger.record(b)
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot[0], a)
        XCTAssertEqual(snapshot[1], b)
    }

    func testLedgerRingBufferEviction() async {
        let ledger = BASUpdateTicketObservationLedger(capacity: 2)
        for i in 0..<5 {
            let bundle = derive([
                ticket(id: "t\(i)", requiresReview: false)
            ])
            await ledger.record(bundle)
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        // Only the last two survive.
        XCTAssertEqual(
            snapshot[0].observations(of: .submission)[0].subjectID,
            "t3")
        XCTAssertEqual(
            snapshot[1].observations(of: .submission)[0].subjectID,
            "t4")
    }

    func testLedgerBundlesForSession() async {
        let ledger = BASUpdateTicketObservationLedger()
        let a = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: [
                ticket(id: "a", requiresReview: false)
            ],
            turnID: "t1",
            sessionID: "session-one",
            emittedAt: fixedDate)
        let b = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: [
                ticket(id: "b", requiresReview: false)
            ],
            turnID: "t2",
            sessionID: "session-two",
            emittedAt: fixedDate)
        await ledger.record(a)
        await ledger.record(b)
        let oneOnly = await ledger.bundles(
            forSession: "session-one")
        XCTAssertEqual(oneOnly.count, 1)
        XCTAssertEqual(oneOnly[0], a)
    }

    func testLedgerBundleForTurn() async {
        let ledger = BASUpdateTicketObservationLedger()
        let a = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: [
                ticket(id: "a", requiresReview: false)
            ],
            turnID: "alpha",
            sessionID: "s",
            emittedAt: fixedDate)
        await ledger.record(a)
        let resolved = await ledger.bundle(forTurn: "alpha")
        XCTAssertEqual(resolved, a)
        let missing = await ledger.bundle(forTurn: "missing")
        XCTAssertNil(missing)
    }

    func testLedgerClear() async {
        let ledger = BASUpdateTicketObservationLedger()
        await ledger.record(derive([
            ticket(id: "t", requiresReview: false)
        ]))
        let preClear = await ledger.count()
        XCTAssertEqual(preClear, 1)
        await ledger.clear()
        let postClear = await ledger.count()
        XCTAssertEqual(postClear, 0)
    }

    // MARK: - Path 17: mutation proposal detection

    func testHasAnyMutationProposalFalseOnReviewOnly() {
        let t = ticket(id: "r", requiresReview: true)
        let bundle = derive([t])
        XCTAssertFalse(bundle.hasAnyMutationProposal)
    }

    func testHasAnyMutationProposalTrueOnAnyMutation() {
        // Try each mutation kind in turn — each should trip the
        // rollup flag.
        let mw = ticket(
            id: "mw", memoryWrite: "x", requiresReview: false)
        let hc = ticket(
            id: "hc", hostChange: hostChangeCandidate(),
            requiresReview: false)
        let rc = ticket(
            id: "rc", ruleRef: "r", requiresReview: false)
        XCTAssertTrue(derive([mw]).hasAnyMutationProposal)
        XCTAssertTrue(derive([hc]).hasAnyMutationProposal)
        XCTAssertTrue(derive([rc]).hasAnyMutationProposal)
    }

    // MARK: - Path 18: encodability

    func testBundleIsCodable() throws {
        let bundle = derive([
            ticket(
                id: "enc",
                memoryWrite: "Encode me",
                hostChange: hostChangeCandidate(),
                conflictFlag: true,
                requiresReview: true)
        ])
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(bundle)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let round =
            try dec.decode(
                BASUpdateTicketObservationBundle.self,
                from: data)
        XCTAssertEqual(round, bundle)
    }
}
