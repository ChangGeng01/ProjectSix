import XCTest
@testable import BASRuntimeCore

final class BASControlLoopValueTests: XCTestCase {
    func testControlLoopEnumCasesAndRawValuesAreFrozen() {
        XCTAssertEqual(
            BASCollaborationVerb.allCases.map(\.rawValue),
            ["query", "fan-out-join", "proposal-critique", "remand", "commit-saga"])
        XCTAssertEqual(
            BASControlRingTerminalState.allCases.map(\.rawValue),
            [
                "converged", "degraded-with-coverage", "deferred", "rejected",
                "needs-confirmation", "indeterminate-needs-reconciliation",
            ])
        XCTAssertEqual(
            BASJoinPolicy.allCases.map(\.rawValue),
            ["all", "quorum", "best-effort-with-coverage"])
        XCTAssertEqual(
            BASControlLoopProgressKind.allCases.map(\.rawValue),
            [
                "new-required-lane-coverage", "strict-deficiency-reduction",
                "strict-conflict-reduction", "resource-safe-transition",
                "effect-saga-rank-advance",
            ])
        XCTAssertEqual(
            BASControlLoopTerminationReason.allCases.map(\.rawValue),
            [
                "converged-verified", "coverage-bound", "resource-deferred",
                "policy-rejected", "confirmation-required", "cycle-detected",
                "budget-exhausted", "no-progress", "stale-epoch",
                "illegal-remand", "effect-reconciliation-indeterminate",
            ])
        XCTAssertEqual(
            BASCancellationReason.allCases.map(\.rawValue),
            [
                "user-requested", "deadline-exceeded", "resource-pressure",
                "authority-revoked", "superseded", "shutdown",
            ])
        XCTAssertEqual(
            BASCancellationDispatchBoundary.allCases.map(\.rawValue),
            ["pre-dispatch", "post-dispatch-possible", "post-dispatch-terminal"])
        XCTAssertEqual(
            BASBackpressureDisposition.allCases.map(\.rawValue),
            ["accepted", "deferred", "rejected"])
    }

    func testGovernedSchemaVersionsAreFrozen() {
        XCTAssertEqual(BASJoinArtifact.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASRemandArtifact.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASRefusalArtifact.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASControlLoopEnvelopePayload.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASControlLoopProgressWitnessPayload.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASControlLoopTerminalReceiptPayload.currentSchemaVersion, "1.0.0")
    }

    func testValidRootEnvelopeAndStrictProgressWitnessRoundTrip() throws {
        let root = try BASControlLoopEnvelopePayload(
            turnOperationRef: try turnRef(0),
            attemptRefArtifactID: artifactID(1),
            generationVectorArtifactID: artifactID(2),
            ringID: .grounding,
            logicalInvocationKey: "grounding:/root-1",
            parentInvocationArtifactID: nil,
            semanticSnapshotArtifactID: artifactID(3),
            capabilityGrantArtifactID: artifactID(4),
            budgetLeaseArtifactID: artifactID(5),
            priorBudgetUseReceiptArtifactID: nil,
            progressWitnessArtifactID: nil,
            visitedStateDecisionDigestSetCommitment: digest(6),
            declaredEdge: nil,
            depth: 0,
            maximumDepth: 8,
            branchCount: 1,
            maximumBranches: 16,
            monotonicDeadlineNanos: 1_000,
            policyEpoch: 7,
            deletionEpoch: 8,
            bootSessionID: "boot-1")
        XCTAssertEqual(
            try roundTrip(root, as: BASControlLoopEnvelopePayload.self), root)

        let witness = try BASControlLoopProgressWitnessPayload(
            kind: .newRequiredLaneCoverage,
            priorEvidenceArtifactID: artifactID(10),
            currentEvidenceArtifactID: artifactID(11),
            priorCanonicalMeasure: [1, 9],
            currentCanonicalMeasure: [2, 0],
            verifierReceiptArtifactID: artifactID(12))
        XCTAssertEqual(
            try roundTrip(witness, as: BASControlLoopProgressWitnessPayload.self),
            witness)
    }

    func testTerminalMatrixAndAdoptabilityAreExact() throws {
        let allowed: [BASControlRingTerminalState: Set<BASControlLoopTerminationReason>] = [
            .converged: [.convergedVerified],
            .degradedWithCoverage: [.coverageBound],
            .deferred: [.resourceDeferred, .budgetExhausted],
            .rejected: [.policyRejected, .cycleDetected, .noProgress, .staleEpoch, .illegalRemand],
            .needsConfirmation: [.confirmationRequired],
            .indeterminateNeedsReconciliation: [.effectReconciliationIndeterminate],
        ]

        for state in BASControlRingTerminalState.allCases {
            for reason in BASControlLoopTerminationReason.allCases {
                let make = {
                    try BASControlLoopTerminalReceiptPayload(
                        turnOperationRef: try self.turnRef(20),
                        invocationArtifactID: self.artifactID(21),
                        controlLoopEnvelopeArtifactID: self.artifactID(22),
                        budgetUseReceiptArtifactID: self.artifactID(23),
                        terminalState: state,
                        terminationReason: reason,
                        finalStateDecisionDigest: self.digest(24),
                        orderedEvidenceArtifactIDs: [self.artifactID(25)])
                }
                if allowed[state, default: []].contains(reason) {
                    let receipt = try make()
                    XCTAssertEqual(
                        receipt.isAdoptable,
                        state == .converged && reason == .convergedVerified)
                } else {
                    XCTAssertThrowsError(try make(), "unexpected pair: \(state)/\(reason)")
                }
            }
        }
    }

    func testJoinRequiresAnExactOrderedPartitionAndPolicyEvidence() throws {
        let expected = (30..<34).map { artifactID(UInt64($0)) }
        let complete = try makeJoin(
            expected: expected,
            received: expected,
            missing: [],
            policy: .all,
            quorum: 4)
        XCTAssertEqual(try roundTrip(complete, as: BASJoinArtifact.self), complete)

        let partial = try makeJoin(
            expected: expected,
            received: [expected[0], expected[2]],
            missing: [expected[1], expected[3]],
            policy: .bestEffortWithCoverage,
            quorum: 2,
            evidence: [artifactID(40)])
        XCTAssertEqual(partial.orderedReceivedInputArtifactIDs, [expected[0], expected[2]])
        XCTAssertEqual(partial.orderedMissingInputArtifactIDs, [expected[1], expected[3]])

        XCTAssertThrowsError(try makeJoin(
            expected: expected,
            received: [expected[2], expected[0]],
            missing: [expected[1], expected[3]],
            policy: .quorum,
            quorum: 2))
        XCTAssertThrowsError(try makeJoin(
            expected: expected,
            received: [expected[0]],
            missing: [expected[1], expected[2]],
            policy: .quorum,
            quorum: 1))
        XCTAssertThrowsError(try makeJoin(
            expected: expected,
            received: expected,
            missing: [],
            policy: .all,
            quorum: 3))
        XCTAssertThrowsError(try makeJoin(
            expected: expected,
            received: [expected[0], expected[1]],
            missing: [expected[2], expected[3]],
            policy: .bestEffortWithCoverage,
            quorum: 2,
            evidence: []))
    }

    func testJoinBoundsIdentityAndDecodeValidationCannotBeBypassed() throws {
        let only = artifactID(50)
        XCTAssertThrowsError(try makeJoin(
            expected: [], received: [], missing: [], policy: .all, quorum: 0))
        XCTAssertThrowsError(try makeJoin(
            expected: Array(repeating: only, count: 65),
            received: Array(repeating: only, count: 65),
            missing: [], policy: .all, quorum: 65))
        let unique65 = (1...65).map { artifactID(UInt64(300 + $0)) }
        XCTAssertThrowsError(try makeJoin(
            expected: unique65, received: unique65, missing: [],
            policy: .all, quorum: 65))
        XCTAssertThrowsError(try makeJoin(
            expected: [only, only], received: [only], missing: [only],
            policy: .quorum, quorum: 1))
        XCTAssertThrowsError(try makeJoin(
            expected: [only], received: [only], missing: [],
            policy: .all, quorum: 1,
            parent: invalidArtifactID()))
        XCTAssertThrowsError(try makeJoin(
            expected: [only], received: [only], missing: [],
            policy: .all, quorum: 1, deadline: 0))
        XCTAssertThrowsError(try makeJoin(
            expected: [only], received: [artifactID(51)], missing: [],
            policy: .quorum, quorum: 1))
        XCTAssertThrowsError(try makeJoin(
            expected: [only, artifactID(51)], received: [only],
            missing: [artifactID(51)], policy: .quorum, quorum: 2))

        let valid = try makeJoin(
            expected: [only], received: [only], missing: [],
            policy: .all, quorum: 1)
        let invalidBytes = try replacingJSONValue(
            in: valid, key: "orderedMissingInputArtifactIDs", value: [artifactJSONObject(only)])
        XCTAssertThrowsError(try JSONDecoder().decode(BASJoinArtifact.self, from: invalidBytes))
    }

    func testRemandAndRefusalEnforceBoundedTypedEvidence() throws {
        let remand = try makeRemand()
        XCTAssertEqual(try roundTrip(remand, as: BASRemandArtifact.self), remand)
        XCTAssertThrowsError(try makeRemand(missingEvidence: [], missingSchemas: []))
        XCTAssertThrowsError(try makeRemand(missingSchemas: [""]))
        XCTAssertThrowsError(try makeRemand(missingSchemas: [String(repeating: "a", count: 129)]))
        XCTAssertThrowsError(try makeRemand(missingSchemas: ["schema.a", "schema.a"]))
        XCTAssertThrowsError(try makeRemand(round: 0))
        XCTAssertThrowsError(try makeRemand(round: 65_536))
        XCTAssertThrowsError(try makeRemand(hop: 0))
        XCTAssertThrowsError(try makeRemand(commitment: String(repeating: "A", count: 64)))
        XCTAssertThrowsError(try makeRemand(deadline: 0))
        XCTAssertThrowsError(try makeRemand(
            missingEvidence: (0..<65).map { artifactID(UInt64(400 + $0)) }))
        XCTAssertThrowsError(try makeRemand(
            missingEvidence: [invalidArtifactID()]))

        let refusal = try makeRefusal()
        XCTAssertEqual(try roundTrip(refusal, as: BASRefusalArtifact.self), refusal)
        XCTAssertThrowsError(try makeRefusal(reason: ""))
        XCTAssertThrowsError(try makeRefusal(reason: "Bad Reason"))
        XCTAssertThrowsError(try makeRefusal(reason: "é"))
        XCTAssertThrowsError(try makeRefusal(reason: String(repeating: "a", count: 129)))
        XCTAssertThrowsError(try makeRefusal(evidence: []))
        XCTAssertThrowsError(try makeRefusal(evidence: [artifactID(70), artifactID(70)]))
        XCTAssertThrowsError(try makeRefusal(
            evidence: (0..<65).map { artifactID(UInt64(500 + $0)) }))
        XCTAssertThrowsError(try makeRefusal(evidence: [invalidArtifactID()]))
        XCTAssertThrowsError(try makeRefusal(deadline: 0))
    }

    func testRemandAndRefusalDecodeReuseTheirValidators() throws {
        let remandBytes = try replacingJSONValue(
            in: makeRemand(), key: "round", value: 0)
        XCTAssertThrowsError(try JSONDecoder().decode(BASRemandArtifact.self, from: remandBytes))
        let refusalBytes = try replacingJSONValue(
            in: makeRefusal(), key: "reasonCode", value: "not valid")
        XCTAssertThrowsError(try JSONDecoder().decode(BASRefusalArtifact.self, from: refusalBytes))
    }

    func testRemandMissingEvidenceCannotOverlapConflictOrEvidence() throws {
        let missing = artifactID(73)
        XCTAssertThrowsError(try makeRemand(
            missingEvidence: [missing],
            evidence: [missing])) { error in
            XCTAssertEqual(
                error as? BASControlLoopValueError,
                .missingEvidenceOverlapsOtherEvidence)
        }
        XCTAssertThrowsError(try makeRemand(
            missingEvidence: [missing],
            conflicts: [missing])) { error in
            XCTAssertEqual(
                error as? BASControlLoopValueError,
                .missingEvidenceOverlapsOtherEvidence)
        }

        let sharedConflictEvidence = artifactID(74)
        XCTAssertNoThrow(try makeRemand(
            missingEvidence: [missing],
            conflicts: [sharedConflictEvidence],
            evidence: [sharedConflictEvidence]))

        let bytes = try replacingJSONValue(
            in: makeRemand(missingEvidence: [missing]),
            key: "orderedEvidenceArtifactIDs",
            value: [artifactJSONObject(missing)])
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASRemandArtifact.self, from: bytes))
    }

    func testJoinAndRemandRejectInvalidRemainingBudgetProjection() throws {
        var negative = layerSlice()
        negative.allocatedMs = -1
        XCTAssertThrowsError(try makeJoin(
            expected: [artifactID(71)],
            received: [artifactID(71)],
            missing: [],
            policy: .all,
            quorum: 1,
            remainingBudget: negative))

        var futureSchema = layerSlice()
        futureSchema.schemaVersion = "2.0.0"
        XCTAssertThrowsError(try makeRemand(remainingBudget: futureSchema))

        let joinBytes = try replacingNestedJSONValue(
            in: makeJoin(
                expected: [artifactID(72)],
                received: [artifactID(72)],
                missing: [],
                policy: .all,
                quorum: 1),
            key: "remainingBudget",
            nestedKey: "loopAllowance",
            value: 0)
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASJoinArtifact.self, from: joinBytes))

        let remandBytes = try replacingNestedJSONValue(
            in: makeRemand(),
            key: "remainingBudget",
            nestedKey: "hardCapMs",
            value: -1)
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASRemandArtifact.self, from: remandBytes))
    }

    func testEnvelopeRootChildGroupAndBoundsAreExact() throws {
        let root = try makeEnvelope()
        XCTAssertEqual(root.depth, 0)
        XCTAssertEqual(root.branchCount, 1)
        XCTAssertNoThrow(try makeEnvelope(maximumDepth: 0))

        let child = try makeEnvelope(
            parent: artifactID(80),
            priorUse: artifactID(81),
            witness: artifactID(82),
            edge: .remand,
            depth: 1,
            branchCount: 2)
        XCTAssertEqual(try roundTrip(child, as: BASControlLoopEnvelopePayload.self), child)

        for mask in 1..<15 {
            let parent = mask & 1 == 0 ? nil : artifactID(80)
            let prior = mask & 2 == 0 ? nil : artifactID(81)
            let witness = mask & 4 == 0 ? nil : artifactID(82)
            let edge: BASCollaborationVerb? = mask & 8 == 0 ? nil : .remand
            XCTAssertThrowsError(try makeEnvelope(
                parent: parent, priorUse: prior, witness: witness, edge: edge,
                depth: 1, branchCount: 2), "partial option mask \(mask)")
        }
        XCTAssertThrowsError(try makeEnvelope(
            parent: artifactID(80), priorUse: artifactID(81),
            witness: artifactID(82), edge: .remand,
            depth: 0, branchCount: 2))
        XCTAssertThrowsError(try makeEnvelope(depth: 1))
        XCTAssertThrowsError(try makeEnvelope(branchCount: 2))
        XCTAssertThrowsError(try makeEnvelope(
            parent: artifactID(80), priorUse: artifactID(81),
            witness: artifactID(82), edge: .remand,
            depth: 1, branchCount: 1))
        XCTAssertThrowsError(try makeEnvelope(depth: 1, maximumDepth: 0))
        XCTAssertThrowsError(try makeEnvelope(maximumBranches: 0))
        XCTAssertThrowsError(try makeEnvelope(branchCount: 17, maximumBranches: 16))
        XCTAssertNoThrow(try makeEnvelope(
            parent: artifactID(80), priorUse: artifactID(81),
            witness: artifactID(82), edge: .remand,
            depth: UInt64.max, maximumDepth: UInt64.max,
            branchCount: 2, maximumBranches: UInt64.max))
    }

    func testEnvelopeBoundedStringsCommitmentIdentityAndDecodeValidation() throws {
        XCTAssertThrowsError(try makeEnvelope(logicalKey: ""))
        XCTAssertThrowsError(try makeEnvelope(logicalKey: "Bad Key"))
        XCTAssertThrowsError(try makeEnvelope(logicalKey: "é"))
        XCTAssertThrowsError(try makeEnvelope(logicalKey: String(repeating: "a", count: 257)))
        XCTAssertThrowsError(try makeEnvelope(bootSessionID: ""))
        XCTAssertThrowsError(try makeEnvelope(bootSessionID: String(repeating: "é", count: 129)))
        XCTAssertThrowsError(try makeEnvelope(commitment: String(repeating: "f", count: 63)))
        XCTAssertThrowsError(try makeEnvelope(commitment: String(repeating: "F", count: 64)))
        XCTAssertThrowsError(try makeEnvelope(deadline: 0))
        XCTAssertThrowsError(try makeEnvelope(attempt: invalidArtifactID()))

        let bytes = try replacingJSONValue(
            in: makeEnvelope(), key: "bootSessionID", value: "")
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASControlLoopEnvelopePayload.self, from: bytes))
    }

    func testProgressWitnessRequiresPairwiseDistinctIDsAndStrictLexicographicProgress() throws {
        let increasing: [BASControlLoopProgressKind] = [
            .newRequiredLaneCoverage, .resourceSafeTransition, .effectSagaRankAdvance,
        ]
        for kind in increasing {
            XCTAssertNoThrow(try makeWitness(kind: kind, prior: [1, 9], current: [2, 0]))
            XCTAssertThrowsError(try makeWitness(kind: kind, prior: [2], current: [1]))
        }
        for kind in [
            BASControlLoopProgressKind.strictDeficiencyReduction,
            .strictConflictReduction,
        ] {
            XCTAssertNoThrow(try makeWitness(kind: kind, prior: [2, 0], current: [1, 9]))
            XCTAssertThrowsError(try makeWitness(kind: kind, prior: [1], current: [2]))
        }
        XCTAssertThrowsError(try makeWitness(prior: [1], current: [1]))
        XCTAssertThrowsError(try makeWitness(prior: [], current: []))
        XCTAssertThrowsError(try makeWitness(prior: Array(repeating: 1, count: 9), current: Array(repeating: 2, count: 9)))
        XCTAssertThrowsError(try makeWitness(prior: [1], current: [1, 2]))
        XCTAssertThrowsError(try makeWitness(priorID: artifactID(90), currentID: artifactID(90)))
        XCTAssertThrowsError(try BASControlLoopProgressWitnessPayload(
            kind: .newRequiredLaneCoverage,
            priorEvidenceArtifactID: artifactID(90),
            currentEvidenceArtifactID: artifactID(91),
            priorCanonicalMeasure: [1],
            currentCanonicalMeasure: [2],
            verifierReceiptArtifactID: artifactID(90)))
        XCTAssertThrowsError(try makeWitness(priorID: invalidArtifactID()))

        let bytes = try replacingJSONValue(
            in: makeWitness(), key: "currentCanonicalMeasure", value: [1])
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASControlLoopProgressWitnessPayload.self, from: bytes))
    }

    func testTerminalReceiptBoundsIdentityAndDecodeValidation() throws {
        XCTAssertThrowsError(try makeTerminal(digest: "abc"))
        XCTAssertThrowsError(try makeTerminal(evidence: []))
        XCTAssertThrowsError(try makeTerminal(
            evidence: [artifactID(100), artifactID(100)]))
        XCTAssertThrowsError(try makeTerminal(
            evidence: (0..<65).map { artifactID(UInt64(600 + $0)) }))
        XCTAssertThrowsError(try makeTerminal(invocation: invalidArtifactID()))

        let bytes = try replacingJSONValue(
            in: makeTerminal(), key: "terminationReason", value: "policy-rejected")
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASControlLoopTerminalReceiptPayload.self, from: bytes))
    }

    func testGovernedPayloadsExposeNoSelfOrMutableAuthorityKeys() throws {
        let forbidden: Set<String> = [
            "artifactID", "joinID", "remandID", "refusalID", "currentInvocationArtifactID",
            "currentBudgetUseReceiptArtifactID", "remainingCounter", "remainingTokens",
            "spentTokens", "spentBytes", "mutableVisitedDigests", "executableClosure",
        ]
        let values: [any Encodable] = [
            try makeJoin(expected: [artifactID(110)], received: [artifactID(110)],
                         missing: [], policy: .all, quorum: 1),
            try makeRemand(), try makeRefusal(), try makeEnvelope(),
            try makeWitness(), try makeTerminal(),
        ]
        for value in values {
            let keys = try encodedKeys(value)
            XCTAssertTrue(keys.isDisjoint(with: forbidden), "forbidden keys: \(keys.intersection(forbidden))")
        }
    }

    func testCancellationValidatesRootIdentityAndSequence() throws {
        let root = try turnRef(120)
        let branch = try BASTurnBranchRef(
            turnOperationRef: root, kind: .effect, ordinal: 1)
        let body = try BASCancellationBody(
            turnOperationRef: root,
            attemptRefArtifactID: artifactID(121),
            generationVectorArtifactID: artifactID(122),
            targetBranchRef: branch,
            reason: .authorityRevoked,
            dispatchBoundary: .postDispatchPossible,
            monotonicSequence: 1)
        XCTAssertEqual(try roundTrip(body, as: BASCancellationBody.self), body)
        XCTAssertThrowsError(try BASCancellationBody(
            turnOperationRef: root,
            attemptRefArtifactID: invalidArtifactID(),
            generationVectorArtifactID: artifactID(122),
            targetBranchRef: nil,
            reason: .shutdown,
            dispatchBoundary: .preDispatch,
            monotonicSequence: 1))
        XCTAssertThrowsError(try BASCancellationBody(
            turnOperationRef: root,
            attemptRefArtifactID: artifactID(121),
            generationVectorArtifactID: artifactID(122),
            targetBranchRef: try BASTurnBranchRef(
                turnOperationRef: turnRef(123), kind: .effect, ordinal: 1),
            reason: .shutdown,
            dispatchBoundary: .preDispatch,
            monotonicSequence: 1))
        XCTAssertThrowsError(try BASCancellationBody(
            turnOperationRef: root,
            attemptRefArtifactID: artifactID(121),
            generationVectorArtifactID: artifactID(122),
            targetBranchRef: nil,
            reason: .shutdown,
            dispatchBoundary: .preDispatch,
            monotonicSequence: 0))

        let bytes = try replacingJSONValue(
            in: body, key: "monotonicSequence", value: 0)
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASCancellationBody.self, from: bytes))
    }

    func testBackpressureValidatesLoadRetryAndResultConsistency() throws {
        let accepted = try makeBackpressure(disposition: .accepted)
        XCTAssertTrue(try accepted.makeReceipt(success: true).success)
        XCTAssertThrowsError(try accepted.makeReceipt(success: false))

        let deferred = try makeBackpressure(
            disposition: .deferred, retryAfter: 1_000)
        XCTAssertFalse(try deferred.makeReceipt(success: false).success)
        XCTAssertThrowsError(try deferred.makeReceipt(success: true))
        let rejected = try makeBackpressure(disposition: .rejected)
        XCTAssertFalse(try rejected.makeReceipt(success: false).success)
        XCTAssertThrowsError(try makeBackpressure(disposition: .deferred, retryAfter: nil))
        XCTAssertThrowsError(try makeBackpressure(disposition: .deferred, retryAfter: 0))
        XCTAssertThrowsError(try makeBackpressure(disposition: .accepted, retryAfter: 1_000))
        XCTAssertThrowsError(try makeBackpressure(active: 5, limit: 4))
        XCTAssertThrowsError(try makeBackpressure(limit: 0))
        XCTAssertThrowsError(try makeBackpressure(sequence: 0))
        XCTAssertThrowsError(try makeBackpressure(attempt: invalidArtifactID()))

        let bytes = try replacingJSONValue(
            in: deferred, key: "retryAfterMonotonicNanos", value: NSNull())
        XCTAssertThrowsError(try JSONDecoder().decode(BASBackpressureBody.self, from: bytes))
        let zeroRetryBytes = try replacingJSONValue(
            in: deferred, key: "retryAfterMonotonicNanos", value: 0)
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASBackpressureBody.self, from: zeroRetryBytes))
    }

    func testBackpressureGenericResultRequiresExplicitValidationBoundary() throws {
        let accepted = try makeBackpressure(disposition: .accepted)
        let inconsistent: BASBackpressureReceipt = BASResult(
            success: false,
            body: accepted,
            diagnostics: ["forged-success-bit"])
        let reopened = try roundTrip(
            inconsistent,
            as: BASBackpressureReceipt.self)
        XCTAssertThrowsError(
            try reopened.validatedBackpressureReceipt()) { error in
                XCTAssertEqual(
                    error as? BASControlLoopValueError,
                    .resultDispositionMismatch)
            }

        let consistent: BASBackpressureReceipt = BASResult(
            success: true,
            body: accepted,
            diagnostics: [])
        XCTAssertEqual(
            try consistent.validatedBackpressureReceipt(),
            consistent)
    }

    private func makeJoin(
        expected: [BASArtifactID],
        received: [BASArtifactID],
        missing: [BASArtifactID],
        policy: BASJoinPolicy,
        quorum: UInt64,
        conflicts: [BASArtifactID] = [],
        evidence: [BASArtifactID] = [],
        parent: BASArtifactID? = nil,
        deadline: UInt64 = 1_000,
        remainingBudget: BASLayerSlice? = nil
    ) throws -> BASJoinArtifact {
        try BASJoinArtifact(
            parentArtifactID: parent ?? artifactID(200),
            orderedExpectedInputArtifactIDs: expected,
            orderedReceivedInputArtifactIDs: received,
            orderedMissingInputArtifactIDs: missing,
            policy: policy,
            quorum: quorum,
            orderedConflictArtifactIDs: conflicts,
            orderedEvidenceArtifactIDs: evidence,
            remainingBudget: remainingBudget ?? layerSlice(),
            budgetLeaseArtifactID: artifactID(201),
            priorBudgetUseReceiptArtifactID: artifactID(202),
            progressWitnessArtifactID: artifactID(203),
            controlLoopEnvelopeArtifactID: artifactID(204),
            monotonicDeadlineNanos: deadline)
    }

    private func makeRemand(
        missingEvidence: [BASArtifactID] = [
            BASArtifactID(integrityAlgorithm: "sha256", commitmentKeyEpoch: 1,
                          commitmentHex: String(format: "%064llx", 210)),
        ],
        missingSchemas: [String] = ["schema.required-v1"],
        conflicts: [BASArtifactID] = [],
        evidence: [BASArtifactID] = [],
        round: UInt64 = 1,
        hop: UInt64 = 1,
        commitment: String? = nil,
        deadline: UInt64 = 1_000,
        remainingBudget: BASLayerSlice? = nil
    ) throws -> BASRemandArtifact {
        try BASRemandArtifact(
            parentArtifactID: artifactID(211),
            inputArtifactID: artifactID(212),
            targetLayerID: .mirrorBlade,
            orderedMissingEvidenceArtifactIDs: missingEvidence,
            orderedMissingSchemaIDs: missingSchemas,
            orderedConflictArtifactIDs: conflicts,
            orderedEvidenceArtifactIDs: evidence,
            round: round,
            hop: hop,
            visitedStateDecisionDigestSetCommitment: commitment ?? digest(213),
            remainingBudget: remainingBudget ?? layerSlice(),
            budgetLeaseArtifactID: artifactID(214),
            priorBudgetUseReceiptArtifactID: artifactID(215),
            progressWitnessArtifactID: artifactID(216),
            controlLoopEnvelopeArtifactID: artifactID(217),
            monotonicDeadlineNanos: deadline)
    }

    private func makeRefusal(
        reason: String = "policy.denied-v1",
        evidence: [BASArtifactID] = [
            BASArtifactID(integrityAlgorithm: "sha256", commitmentKeyEpoch: 1,
                          commitmentHex: String(format: "%064llx", 220)),
        ],
        deadline: UInt64 = 1_000
    ) throws -> BASRefusalArtifact {
        try BASRefusalArtifact(
            turnOperationRef: turnRef(221),
            refusingLayerID: .sovereign,
            refusedArtifactID: artifactID(222),
            reasonCode: reason,
            orderedEvidenceArtifactIDs: evidence,
            policyEpoch: 7,
            monotonicDeadlineNanos: deadline)
    }

    private func makeEnvelope(
        attempt: BASArtifactID? = nil,
        logicalKey: String = "grounding:/root-1",
        parent: BASArtifactID? = nil,
        priorUse: BASArtifactID? = nil,
        witness: BASArtifactID? = nil,
        commitment: String? = nil,
        edge: BASCollaborationVerb? = nil,
        depth: UInt64 = 0,
        maximumDepth: UInt64 = 8,
        branchCount: UInt64 = 1,
        maximumBranches: UInt64 = 16,
        deadline: UInt64 = 1_000,
        bootSessionID: String = "boot-1"
    ) throws -> BASControlLoopEnvelopePayload {
        try BASControlLoopEnvelopePayload(
            turnOperationRef: turnRef(230),
            attemptRefArtifactID: attempt ?? artifactID(231),
            generationVectorArtifactID: artifactID(232),
            ringID: .grounding,
            logicalInvocationKey: logicalKey,
            parentInvocationArtifactID: parent,
            semanticSnapshotArtifactID: artifactID(233),
            capabilityGrantArtifactID: artifactID(234),
            budgetLeaseArtifactID: artifactID(235),
            priorBudgetUseReceiptArtifactID: priorUse,
            progressWitnessArtifactID: witness,
            visitedStateDecisionDigestSetCommitment: commitment ?? digest(236),
            declaredEdge: edge,
            depth: depth,
            maximumDepth: maximumDepth,
            branchCount: branchCount,
            maximumBranches: maximumBranches,
            monotonicDeadlineNanos: deadline,
            policyEpoch: 7,
            deletionEpoch: 8,
            bootSessionID: bootSessionID)
    }

    private func makeWitness(
        kind: BASControlLoopProgressKind = .newRequiredLaneCoverage,
        priorID: BASArtifactID? = nil,
        currentID: BASArtifactID? = nil,
        prior: [UInt64] = [1],
        current: [UInt64] = [2]
    ) throws -> BASControlLoopProgressWitnessPayload {
        try BASControlLoopProgressWitnessPayload(
            kind: kind,
            priorEvidenceArtifactID: priorID ?? artifactID(240),
            currentEvidenceArtifactID: currentID ?? artifactID(241),
            priorCanonicalMeasure: prior,
            currentCanonicalMeasure: current,
            verifierReceiptArtifactID: artifactID(242))
    }

    private func makeTerminal(
        invocation: BASArtifactID? = nil,
        state: BASControlRingTerminalState = .converged,
        reason: BASControlLoopTerminationReason = .convergedVerified,
        digest finalDigest: String? = nil,
        evidence: [BASArtifactID] = [
            BASArtifactID(integrityAlgorithm: "sha256", commitmentKeyEpoch: 1,
                          commitmentHex: String(format: "%064llx", 250)),
        ]
    ) throws -> BASControlLoopTerminalReceiptPayload {
        try BASControlLoopTerminalReceiptPayload(
            turnOperationRef: turnRef(251),
            invocationArtifactID: invocation ?? artifactID(252),
            controlLoopEnvelopeArtifactID: artifactID(253),
            budgetUseReceiptArtifactID: artifactID(254),
            terminalState: state,
            terminationReason: reason,
            finalStateDecisionDigest: finalDigest ?? digest(255),
            orderedEvidenceArtifactIDs: evidence)
    }

    private func makeBackpressure(
        attempt: BASArtifactID? = nil,
        active: UInt64 = 2,
        limit: UInt64 = 4,
        disposition: BASBackpressureDisposition = .accepted,
        retryAfter: UInt64? = nil,
        sequence: UInt64 = 1
    ) throws -> BASBackpressureBody {
        try BASBackpressureBody(
            turnOperationRef: turnRef(260),
            attemptRefArtifactID: attempt ?? artifactID(261),
            generationVectorArtifactID: artifactID(262),
            queueBytes: 4_096,
            activeConcurrency: active,
            concurrencyLimit: limit,
            resourceDebtMicrounits: 7,
            disposition: disposition,
            retryAfterMonotonicNanos: retryAfter,
            monotonicSequence: sequence)
    }

    private func layerSlice() -> BASLayerSlice {
        BASLayerSlice(
            layerID: .l7,
            allocatedMs: 10,
            hardCapMs: 20,
            decodeTokenAllowance: 32,
            loopAllowance: 2,
            bytesAllowance: 4_096,
            costMicrounitsAllowance: 100,
            branchAllowance: 4,
            remandRoundAllowance: 2,
            hopAllowance: 8)
    }

    private func invalidArtifactID() -> BASArtifactID {
        BASArtifactID(
            integrityAlgorithm: "INVALID",
            commitmentKeyEpoch: 1,
            commitmentHex: "zz")
    }

    private func artifactJSONObject(_ artifactID: BASArtifactID) -> Any {
        [
            "integrityAlgorithm": artifactID.integrityAlgorithm,
            "commitmentKeyEpoch": artifactID.commitmentKeyEpoch,
            "commitmentHex": artifactID.commitmentHex,
        ]
    }

    private func replacingJSONValue<T: Encodable>(
        in value: T,
        key: String,
        value replacement: Any
    ) throws -> Data {
        let data = try JSONEncoder().encode(value)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        object[key] = replacement
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func replacingNestedJSONValue<T: Encodable>(
        in value: T,
        key: String,
        nestedKey: String,
        value replacement: Any
    ) throws -> Data {
        let data = try JSONEncoder().encode(value)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        var nested = try XCTUnwrap(object[key] as? [String: Any])
        nested[nestedKey] = replacement
        object[key] = nested
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func encodedKeys(_ value: any Encodable) throws -> Set<String> {
        let data = try JSONEncoder().encode(value)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }

    private func artifactID(_ seed: UInt64) -> BASArtifactID {
        BASArtifactID(
            integrityAlgorithm: "sha256",
            commitmentKeyEpoch: 1,
            commitmentHex: String(format: "%064llx", seed))
    }

    private func turnRef(_ seed: UInt64) throws -> BASTurnOperationRef {
        try BASTurnOperationRef(artifactID: artifactID(seed))
    }

    private func digest(_ seed: UInt64) -> String {
        String(format: "%064llx", seed)
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(value))
    }
}
