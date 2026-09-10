import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASLayerCellMembraneTests: XCTestCase {
    private struct Input: Codable, Sendable, Hashable {
        let value: String
    }

    private struct Output: Codable, Sendable, Hashable {
        let value: String
    }

    private final class CountingCore: BASSemanticLayerCore, @unchecked Sendable {
        typealias Input = BASLayerCellMembraneTests.Input
        typealias Output = BASLayerCellMembraneTests.Output

        static let layerID: BASSemanticLayerID = .mirrorBlade

        private let lock = NSLock()
        private var storedCallCount = 0
        private var storedResumeCallCount = 0
        let decision: BASLayerCoreDecision<Output>

        init(request: BASLayerActorInput) {
            self.decision = .invoke(request)
        }

        init(decision: BASLayerCoreDecision<Output>) {
            self.decision = decision
        }

        var callCount: Int {
            lock.withLock { storedCallCount }
        }

        var resumeCallCount: Int {
            lock.withLock { storedResumeCallCount }
        }

        func evaluate(_ input: Input) throws -> BASLayerCoreDecision<Output> {
            lock.withLock { storedCallCount += 1 }
            return decision
        }

        func resume(
            _ actorOutput: BASLayerActorOutput,
            input: Input
        ) throws -> Output {
            lock.withLock { storedResumeCallCount += 1 }
            return Output(value: actorOutput.payloadRef ?? input.value)
        }
    }

    private enum ActorMode: Sendable {
        case normal
        case throwing
        case outputSchema(String)
        case outputLayer(BASMotherboardLayer14)
        case outputTurn(String)
    }

    private actor CountingActor: BASLayerActor {
        nonisolated let layerID: BASMotherboardLayer14
        let mode: ActorMode
        private(set) var callCount = 0
        private(set) var lastInput: BASLayerActorInput?

        init(
            layerID: BASMotherboardLayer14 = .l7,
            mode: ActorMode = .normal
        ) {
            self.layerID = layerID
            self.mode = mode
        }

        func process(
            input: BASLayerActorInput
        ) async throws -> BASLayerActorOutput {
            callCount += 1
            lastInput = input
            if case .throwing = mode {
                throw BASLayerActorError.internalFailure(
                    layerID: layerID,
                    message: "fixture throw")
            }
            let schemaVersion: String
            let outputLayer: BASMotherboardLayer14
            let turnID: String
            switch mode {
            case .normal, .throwing:
                schemaVersion = BASLayerActorOutput.currentSchemaVersion
                outputLayer = input.layerID
                turnID = input.turnID
            case let .outputSchema(value):
                schemaVersion = value
                outputLayer = input.layerID
                turnID = input.turnID
            case let .outputLayer(value):
                schemaVersion = BASLayerActorOutput.currentSchemaVersion
                outputLayer = value
                turnID = input.turnID
            case let .outputTurn(value):
                schemaVersion = BASLayerActorOutput.currentSchemaVersion
                outputLayer = input.layerID
                turnID = value
            }
            return BASLayerActorOutput(
                schemaVersion: schemaVersion,
                layerID: outputLayer,
                turnID: turnID,
                status: .completed,
                payloadRef: "actor-output",
                producedAt: Date(timeIntervalSince1970: 2))
        }
    }

    private func artifact(_ byte: String) -> BASArtifactID {
        BASArtifactID(
            integrityAlgorithm: "sha256",
            commitmentKeyEpoch: 7,
            commitmentHex: String(repeating: byte, count: 64))
    }

    private func fixture(
        ingressKillGeneration: UInt64 = 11,
        contextKillGeneration: UInt64 = 11,
        proposedTurnID: String = "forged-core-turn"
    ) throws -> (
        ingress: BASLayerCellIngress<Input>,
        context: BASLayerCellMembraneContext,
        turn: BASTurnOperationRef
    ) {
        let inputID = artifact("a")
        let parentIDs = [artifact("b"), artifact("c")]
        let grantID = artifact("d")
        let turn = try BASTurnOperationRef(artifactID: artifact("e"))
        let snapshotID = artifact("f")
        let budget = BASLayerSlice(
            layerID: .l7,
            allocatedMs: 4,
            hardCapMs: 8,
            decodeTokenAllowance: 2,
            loopAllowance: 2,
            bytesAllowance: 512,
            costMicrounitsAllowance: 20,
            branchAllowance: 2,
            remandRoundAllowance: 2,
            hopAllowance: 3)
        let body = BASLayerCellIngressBody(
            inputArtifactID: inputID,
            orderedParentArtifactIDs: parentIDs,
            payload: Input(value: proposedTurnID),
            grantArtifactID: grantID,
            turnOperationRef: turn,
            causalTurnBranchRef: nil,
            logicalEpoch: 19,
            snapshotRootArtifactID: snapshotID,
            killGeneration: ingressKillGeneration,
            revocationGeneration: 23,
            monotonicDeadlineNanos: 10_000,
            budget: budget)
        let ingress = BASFrameEnvelope(
            header: BASFrameEnvelopeHeader(
                schemaVersion: "1.0.0",
                correlationID: "correlation",
                producer: "test",
                emittedAtMs: 1),
            body: body)
        let context = BASLayerCellMembraneContext(
            inputArtifactID: inputID,
            orderedParentArtifactIDs: parentIDs,
            grantArtifactID: grantID,
            turnOperationRef: turn,
            causalTurnBranchRef: nil,
            logicalEpoch: 19,
            snapshotRootArtifactID: snapshotID,
            killSwitchState: BASLayerKillSwitchState(
                switchID: .l7MirrorBlade,
                active: false,
                monotonicGeneration: contextKillGeneration,
                activationSequence: 5,
                authority: "host.sovereign"),
            revocationGeneration: 23,
            monotonicDeadlineNanos: 10_000,
            monotonicNowNanos: 9_000,
            budget: budget)
        return (ingress, context, turn)
    }

    private func proposedRequest(turnID: String) -> BASLayerActorInput {
        BASLayerActorInput(
            layerID: .l7,
            turnID: turnID,
            payloadRef: "payload",
            parentLayerID: .l6,
            arrivedAt: Date(timeIntervalSince1970: 1),
            correlationID: "legacy-metadata")
    }

    private func replacingIngress(
        _ ingress: BASLayerCellIngress<Input>,
        headerSchema: String? = nil,
        inputArtifactID: BASArtifactID? = nil,
        orderedParentArtifactIDs: [BASArtifactID]? = nil,
        grantArtifactID: BASArtifactID? = nil,
        turnOperationRef: BASTurnOperationRef? = nil,
        causalTurnBranchRef: BASTurnBranchRef? = nil,
        logicalEpoch: UInt64? = nil,
        snapshotRootArtifactID: BASArtifactID? = nil,
        killGeneration: UInt64? = nil,
        revocationGeneration: UInt64? = nil,
        monotonicDeadlineNanos: UInt64? = nil,
        budget: BASLayerSlice? = nil
    ) -> BASLayerCellIngress<Input> {
        let body = ingress.body
        return BASFrameEnvelope(
            header: BASFrameEnvelopeHeader(
                schemaVersion: headerSchema
                    ?? ingress.header.schemaVersion,
                correlationID: ingress.header.correlationID,
                producer: ingress.header.producer,
                emittedAtMs: ingress.header.emittedAtMs),
            body: BASLayerCellIngressBody(
                inputArtifactID: inputArtifactID
                    ?? body.inputArtifactID,
                orderedParentArtifactIDs: orderedParentArtifactIDs
                    ?? body.orderedParentArtifactIDs,
                payload: body.payload,
                grantArtifactID: grantArtifactID
                    ?? body.grantArtifactID,
                turnOperationRef: turnOperationRef
                    ?? body.turnOperationRef,
                causalTurnBranchRef: causalTurnBranchRef
                    ?? body.causalTurnBranchRef,
                logicalEpoch: logicalEpoch ?? body.logicalEpoch,
                snapshotRootArtifactID: snapshotRootArtifactID
                    ?? body.snapshotRootArtifactID,
                killGeneration: killGeneration
                    ?? body.killGeneration,
                revocationGeneration: revocationGeneration
                    ?? body.revocationGeneration,
                monotonicDeadlineNanos: monotonicDeadlineNanos
                    ?? body.monotonicDeadlineNanos,
                budget: budget ?? body.budget))
    }

    private func replacingContext(
        _ context: BASLayerCellMembraneContext,
        inputArtifactID: BASArtifactID? = nil,
        orderedParentArtifactIDs: [BASArtifactID]? = nil,
        grantArtifactID: BASArtifactID? = nil,
        turnOperationRef: BASTurnOperationRef? = nil,
        causalTurnBranchRef: BASTurnBranchRef? = nil,
        logicalEpoch: UInt64? = nil,
        snapshotRootArtifactID: BASArtifactID? = nil,
        killSwitchState: BASLayerKillSwitchState? = nil,
        revocationGeneration: UInt64? = nil,
        monotonicDeadlineNanos: UInt64? = nil,
        monotonicNowNanos: UInt64? = nil,
        budget: BASLayerSlice? = nil
    ) -> BASLayerCellMembraneContext {
        BASLayerCellMembraneContext(
            inputArtifactID: inputArtifactID
                ?? context.inputArtifactID,
            orderedParentArtifactIDs: orderedParentArtifactIDs
                ?? context.orderedParentArtifactIDs,
            grantArtifactID: grantArtifactID
                ?? context.grantArtifactID,
            turnOperationRef: turnOperationRef
                ?? context.turnOperationRef,
            causalTurnBranchRef: causalTurnBranchRef
                ?? context.causalTurnBranchRef,
            logicalEpoch: logicalEpoch ?? context.logicalEpoch,
            snapshotRootArtifactID: snapshotRootArtifactID
                ?? context.snapshotRootArtifactID,
            killSwitchState: killSwitchState
                ?? context.killSwitchState,
            revocationGeneration: revocationGeneration
                ?? context.revocationGeneration,
            monotonicDeadlineNanos: monotonicDeadlineNanos
                ?? context.monotonicDeadlineNanos,
            monotonicNowNanos: monotonicNowNanos
                ?? context.monotonicNowNanos,
            budget: budget ?? context.budget)
    }

    private func replacingKillState(
        _ state: BASLayerKillSwitchState,
        switchID: BASLayerKillSwitchID? = nil,
        active: Bool? = nil,
        reason: BASLayerKillSwitchReason? = nil,
        detail: String? = nil,
        activatedAt: Date? = nil,
        activatedBy: String? = nil,
        monotonicGeneration: UInt64? = nil,
        activationSequence: UInt64? = nil,
        authority: String? = nil,
        signatureAttestationArtifactID: BASArtifactID? = nil
    ) -> BASLayerKillSwitchState {
        BASLayerKillSwitchState(
            schemaVersion: state.schemaVersion,
            switchID: switchID ?? state.switchID,
            active: active ?? state.active,
            reason: reason ?? state.reason,
            detail: detail ?? state.detail,
            activatedAt: activatedAt ?? state.activatedAt,
            activatedBy: activatedBy ?? state.activatedBy,
            monotonicGeneration: monotonicGeneration
                ?? state.monotonicGeneration,
            activationSequence: activationSequence
                ?? state.activationSequence,
            authority: authority ?? state.authority,
            signatureAttestationArtifactID:
                signatureAttestationArtifactID
                    ?? state.signatureAttestationArtifactID)
    }

    private func assertPrepareRejected(
        _ expected: BASLayerCellError,
        ingress: BASLayerCellIngress<Input>,
        context: BASLayerCellMembraneContext,
        actor: CountingActor = CountingActor()
    ) async {
        let core = CountingCore(
            request: proposedRequest(turnID: "forged"))
        let cell = BASLayerCell(core: core, actor: actor)
        XCTAssertThrowsError(
            try cell.prepare(ingress, context: context)
        ) { error in
            XCTAssertEqual(error as? BASLayerCellError, expected)
        }
        XCTAssertEqual(core.callCount, 0)
        let actorCallCount = await actor.callCount
        XCTAssertEqual(actorCallCount, 0)
    }

    private func assertFreshContextRejected(
        _ expected: BASLayerCellError,
        ingress: BASLayerCellIngress<Input>,
        initialContext: BASLayerCellMembraneContext,
        freshContext: BASLayerCellMembraneContext
    ) async throws {
        let core = CountingCore(
            request: proposedRequest(turnID: "forged"))
        let actor = CountingActor()
        let cell = BASLayerCell(core: core, actor: actor)
        let prepared = try cell.prepare(
            ingress,
            context: initialContext)
        do {
            _ = try await cell.revalidateAndInvoke(
                prepared,
                context: freshContext)
            XCTFail("expected \(expected)")
        } catch {
            XCTAssertEqual(error as? BASLayerCellError, expected)
        }
        XCTAssertEqual(core.callCount, 1)
        let actorCallCount = await actor.callCount
        XCTAssertEqual(actorCallCount, 0)
    }

    private func remandArtifact(
        budget: BASLayerSlice
    ) throws -> BASRemandArtifact {
        try BASRemandArtifact(
            parentArtifactID: artifact("1"),
            inputArtifactID: artifact("2"),
            targetLayerID: .mirrorBlade,
            orderedMissingEvidenceArtifactIDs: [artifact("3")],
            orderedMissingSchemaIDs: ["schema.required-v1"],
            orderedConflictArtifactIDs: [],
            orderedEvidenceArtifactIDs: [],
            round: 1,
            hop: 1,
            visitedStateDecisionDigestSetCommitment:
                String(repeating: "4", count: 64),
            remainingBudget: budget,
            budgetLeaseArtifactID: artifact("5"),
            priorBudgetUseReceiptArtifactID: artifact("6"),
            progressWitnessArtifactID: artifact("7"),
            controlLoopEnvelopeArtifactID: artifact("8"),
            monotonicDeadlineNanos: 10_000)
    }

    private func refusalArtifact(
        turnOperationRef: BASTurnOperationRef
    ) throws -> BASRefusalArtifact {
        try BASRefusalArtifact(
            turnOperationRef: turnOperationRef,
            refusingLayerID: .mirrorBlade,
            refusedArtifactID: artifact("1"),
            reasonCode: "policy.denied-v1",
            orderedEvidenceArtifactIDs: [artifact("2")],
            policyEpoch: 19,
            monotonicDeadlineNanos: 10_000)
    }

    func testStaleKillGenerationStopsBeforeCoreAndActor() async throws {
        let values = try fixture(
            ingressKillGeneration: 10,
            contextKillGeneration: 11)
        let core = CountingCore(request: proposedRequest(turnID: "forged"))
        let actor = CountingActor()
        let cell = BASLayerCell(core: core, actor: actor)

        XCTAssertThrowsError(
            try cell.prepare(values.ingress, context: values.context))
        XCTAssertEqual(core.callCount, 0)
        let actorCallCount = await actor.callCount
        XCTAssertEqual(actorCallCount, 0)
    }

    func testPrepareRejectsMismatchesBeforeCoreAndActor() async throws {
        let values = try fixture()
        await assertPrepareRejected(
            .unsupportedIngressSchema(found: "2.0.0"),
            ingress: replacingIngress(
                values.ingress,
                headerSchema: "2.0.0"),
            context: values.context)
        await assertPrepareRejected(
            .orderedParentArtifactsMismatch,
            ingress: values.ingress,
            context: replacingContext(
                values.context,
                orderedParentArtifactIDs:
                    Array(values.context.orderedParentArtifactIDs.reversed())))
        await assertPrepareRejected(
            .inputArtifactMismatch,
            ingress: replacingIngress(
                values.ingress,
                inputArtifactID: artifact("9")),
            context: values.context)
        await assertPrepareRejected(
            .grantMismatch,
            ingress: replacingIngress(
                values.ingress,
                grantArtifactID: artifact("9")),
            context: values.context)
        let otherTurn = try BASTurnOperationRef(
            artifactID: artifact("8"))
        await assertPrepareRejected(
            .turnOperationMismatch,
            ingress: replacingIngress(
                values.ingress,
                turnOperationRef: otherTurn),
            context: values.context)
        let branch = try BASTurnBranchRef(
            turnOperationRef: values.turn,
            kind: .effect,
            ordinal: 1)
        await assertPrepareRejected(
            .causalBranchMismatch,
            ingress: replacingIngress(
                values.ingress,
                causalTurnBranchRef: branch),
            context: values.context)
        await assertPrepareRejected(
            .logicalEpochMismatch,
            ingress: replacingIngress(
                values.ingress,
                logicalEpoch: values.context.logicalEpoch + 1),
            context: values.context)
        await assertPrepareRejected(
            .snapshotRootMismatch,
            ingress: replacingIngress(
                values.ingress,
                snapshotRootArtifactID: artifact("8")),
            context: values.context)
        await assertPrepareRejected(
            .revocationGenerationMismatch,
            ingress: replacingIngress(
                values.ingress,
                revocationGeneration:
                    values.context.revocationGeneration + 1),
            context: values.context)
        await assertPrepareRejected(
            .deadlineMismatch,
            ingress: replacingIngress(
                values.ingress,
                monotonicDeadlineNanos:
                    values.context.monotonicDeadlineNanos + 1),
            context: values.context)
        let narrowed = try values.context.budget.attenuated(
            bytesAllowance: values.context.budget.bytesAllowance - 1)
        await assertPrepareRejected(
            .budgetMismatch,
            ingress: replacingIngress(
                values.ingress,
                budget: narrowed),
            context: values.context)
    }

    func testPrepareValidatesArtifactIDsAndKillAuthorityBounds() async throws {
        let values = try fixture()
        let invalidID = BASArtifactID(
            integrityAlgorithm: "SHA256",
            commitmentKeyEpoch: 7,
            commitmentHex: "not-hex")
        await assertPrepareRejected(
            .invalidArtifactID(field: "ingress.inputArtifactID"),
            ingress: replacingIngress(
                values.ingress,
                inputArtifactID: invalidID),
            context: values.context)

        let invalidSignatureKill = replacingKillState(
            values.context.killSwitchState,
            signatureAttestationArtifactID: invalidID)
        await assertPrepareRejected(
            .invalidArtifactID(
                field: "killSwitchState.signatureAttestationArtifactID"),
            ingress: values.ingress,
            context: replacingContext(
                values.context,
                killSwitchState: invalidSignatureKill))

        let nonCanonicalAuthority = replacingKillState(
            values.context.killSwitchState,
            authority: " host.sovereign ")
        await assertPrepareRejected(
            .invalidKillSwitchAuthority,
            ingress: values.ingress,
            context: replacingContext(
                values.context,
                killSwitchState: nonCanonicalAuthority))

        let tooLongAuthority = replacingKillState(
            values.context.killSwitchState,
            authority: String(repeating: "a", count: 257))
        await assertPrepareRejected(
            .invalidKillSwitchAuthority,
            ingress: values.ingress,
            context: replacingContext(
                values.context,
                killSwitchState: tooLongAuthority))

        let maximumAuthority = replacingKillState(
            values.context.killSwitchState,
            authority: String(repeating: "a", count: 256))
        let maximumContext = replacingContext(
            values.context,
            killSwitchState: maximumAuthority)
        let core = CountingCore(
            request: proposedRequest(turnID: "forged"))
        let actor = CountingActor()
        XCTAssertNoThrow(try BASLayerCell(core: core, actor: actor).prepare(
            values.ingress,
            context: maximumContext))
        XCTAssertEqual(core.callCount, 1)
    }

    func testCausalBranchMustBelongToTurnRoot() async throws {
        let values = try fixture()
        let otherTurn = try BASTurnOperationRef(artifactID: artifact("7"))
        let branch = try BASTurnBranchRef(
            turnOperationRef: otherTurn,
            kind: .effect,
            ordinal: 1)
        let ingress = replacingIngress(
            values.ingress,
            causalTurnBranchRef: branch)
        let context = replacingContext(
            values.context,
            causalTurnBranchRef: branch)

        await assertPrepareRejected(
            .branchParentMismatch,
            ingress: ingress,
            context: context)
    }

    func testPrepareRejectsActorBudgetKillAndDeadlineOwnership() async throws {
        let values = try fixture()
        await assertPrepareRejected(
            .semanticActorLayerMismatch,
            ingress: values.ingress,
            context: values.context,
            actor: CountingActor(layerID: .l8))

        let wrongBudget = BASLayerSlice(
            layerID: .l8,
            allocatedMs: 4,
            hardCapMs: 8,
            decodeTokenAllowance: 2,
            loopAllowance: 2,
            bytesAllowance: 512,
            costMicrounitsAllowance: 20,
            branchAllowance: 2,
            remandRoundAllowance: 2,
            hopAllowance: 3)
        await assertPrepareRejected(
            .budgetLayerMismatch,
            ingress: replacingIngress(
                values.ingress,
                budget: wrongBudget),
            context: replacingContext(
                values.context,
                budget: wrongBudget))

        let wrongKill = replacingKillState(
            values.context.killSwitchState,
            switchID: .l8Memory)
        await assertPrepareRejected(
            .killSwitchLayerMismatch,
            ingress: values.ingress,
            context: replacingContext(
                values.context,
                killSwitchState: wrongKill))

        let activeKill = replacingKillState(
            values.context.killSwitchState,
            active: true)
        await assertPrepareRejected(
            .killSwitchActive,
            ingress: values.ingress,
            context: replacingContext(
                values.context,
                killSwitchState: activeKill))

        let expired = replacingContext(
            values.context,
            monotonicNowNanos:
                values.context.monotonicDeadlineNanos)
        await assertPrepareRejected(
            .deadlineExpired,
            ingress: values.ingress,
            context: expired)

        let invalidBudget = BASLayerSlice(
            schemaVersion: "2.0.0",
            layerID: .l7,
            allocatedMs: 4,
            hardCapMs: 8)
        await assertPrepareRejected(
            .invalidBudgetProjection,
            ingress: replacingIngress(
                values.ingress,
                budget: invalidBudget),
            context: replacingContext(
                values.context,
                budget: invalidBudget))

        var structurallyInvalidBudget = values.context.budget
        structurallyInvalidBudget.allocatedMs = .nan
        await assertPrepareRejected(
            .invalidBudgetProjection,
            ingress: replacingIngress(
                values.ingress,
                budget: structurallyInvalidBudget),
            context: replacingContext(
                values.context,
                budget: structurallyInvalidBudget))
    }

    func testCanonicalSemanticMappingRemainsTotalAcrossAll14Layers() {
        XCTAssertEqual(BASSemanticLayerID.allCases.count, 14)
        XCTAssertEqual(BASMotherboardLayer14.allCases.count, 14)
        for semanticLayer in BASSemanticLayerID.allCases {
            XCTAssertEqual(
                semanticLayer.motherboardLayer14.semanticLayerID,
                semanticLayer)
        }
    }

    func testCoreTurnIsRebuiltAndExistingActorRunsExactlyOnce() async throws {
        let values = try fixture()
        var proposed = proposedRequest(turnID: "forged-core-turn")
        proposed.payloadRef = "  preserve payload whitespace  "
        proposed.correlationID = "  preserve correlation whitespace  "
        let core = CountingCore(request: proposed)
        let actor = CountingActor()
        let cell = BASLayerCell(core: core, actor: actor)

        let prepared = try cell.prepare(
            values.ingress,
            context: values.context)
        let actorOutput = try await cell.revalidateAndInvoke(
            prepared,
            context: values.context)

        let expectedTurnID = try values.turn.canonicalLegacyProjection()
        let actorCallCount = await actor.callCount
        let actorInput = await actor.lastInput
        XCTAssertEqual(actorCallCount, 1)
        XCTAssertEqual(actorInput?.turnID, expectedTurnID)
        XCTAssertEqual(actorInput?.payloadRef, proposed.payloadRef)
        XCTAssertEqual(actorInput?.parentLayerID, proposed.parentLayerID)
        XCTAssertEqual(actorInput?.arrivedAt, proposed.arrivedAt)
        XCTAssertEqual(actorInput?.correlationID, proposed.correlationID)
        XCTAssertEqual(actorOutput.turnID, expectedTurnID)
        XCTAssertEqual(core.callCount, 1)
    }

    func testInvalidCoreActorTemplateStopsBeforeActor() async throws {
        let values = try fixture()

        var staleSchema = proposedRequest(turnID: "forged")
        staleSchema.schemaVersion = "2.0.0"
        let schemaCore = CountingCore(request: staleSchema)
        let schemaActor = CountingActor()
        XCTAssertThrowsError(
            try BASLayerCell(core: schemaCore, actor: schemaActor).prepare(
                values.ingress,
                context: values.context)
        ) { error in
            XCTAssertEqual(
                error as? BASLayerCellError,
                .invalidActorInputSchema(found: "2.0.0"))
        }
        XCTAssertEqual(schemaCore.callCount, 1)
        let schemaActorCalls = await schemaActor.callCount
        XCTAssertEqual(schemaActorCalls, 0)

        var wrongLayer = proposedRequest(turnID: "forged")
        wrongLayer.layerID = .l8
        let layerCore = CountingCore(request: wrongLayer)
        let layerActor = CountingActor()
        XCTAssertThrowsError(
            try BASLayerCell(core: layerCore, actor: layerActor).prepare(
                values.ingress,
                context: values.context)
        ) { error in
            XCTAssertEqual(
                error as? BASLayerCellError,
                .coreActorLayerMismatch)
        }
        XCTAssertEqual(layerCore.callCount, 1)
        let layerActorCalls = await layerActor.callCount
        XCTAssertEqual(layerActorCalls, 0)
    }

    func testAdapterRejectsBeforeCallAndValidatesAfterOneCall() async throws {
        let values = try fixture()
        let canonicalTurn = try values.turn.canonicalLegacyProjection()

        var staleRequest = proposedRequest(turnID: canonicalTurn)
        staleRequest.schemaVersion = "2.0.0"
        let untouchedActor = CountingActor()
        do {
            _ = try await BASLayerActorMechanismAdapter(
                actor: untouchedActor
            ).invoke(staleRequest, turnOperationRef: values.turn)
            XCTFail("stale input schema must be rejected")
        } catch let error as BASLayerActorError {
            guard case .internalFailure = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        let untouchedCount = await untouchedActor.callCount
        XCTAssertEqual(untouchedCount, 0)

        var wrongLayerRequest = proposedRequest(turnID: canonicalTurn)
        wrongLayerRequest.layerID = .l8
        let wrongLayerActor = CountingActor()
        do {
            _ = try await BASLayerActorMechanismAdapter(
                actor: wrongLayerActor
            ).invoke(wrongLayerRequest, turnOperationRef: values.turn)
            XCTFail("wrong request layer must be rejected")
        } catch let error as BASLayerActorError {
            guard case .internalFailure = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        let wrongLayerCount = await wrongLayerActor.callCount
        XCTAssertEqual(wrongLayerCount, 0)

        let wrongTurnActor = CountingActor()
        do {
            _ = try await BASLayerActorMechanismAdapter(
                actor: wrongTurnActor
            ).invoke(
                proposedRequest(turnID: "wrong-turn"),
                turnOperationRef: values.turn)
            XCTFail("wrong request turn must be rejected")
        } catch let error as BASLayerActorError {
            guard case .internalFailure = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        let wrongTurnCount = await wrongTurnActor.callCount
        XCTAssertEqual(wrongTurnCount, 0)

        let modes: [ActorMode] = [
            .outputSchema("2.0.0"),
            .outputLayer(.l8),
            .outputTurn("wrong-turn"),
        ]
        for mode in modes {
            let actor = CountingActor(mode: mode)
            do {
                _ = try await BASLayerActorMechanismAdapter(
                    actor: actor
                ).invoke(
                    proposedRequest(turnID: canonicalTurn),
                    turnOperationRef: values.turn)
                XCTFail("invalid output identity must be rejected")
            } catch let error as BASLayerActorError {
                guard case .internalFailure = error else {
                    return XCTFail("unexpected \(error)")
                }
            }
            let count = await actor.callCount
            XCTAssertEqual(count, 1)
        }

        let throwingActor = CountingActor(mode: .throwing)
        do {
            _ = try await BASLayerActorMechanismAdapter(
                actor: throwingActor
            ).invoke(
                proposedRequest(turnID: canonicalTurn),
                turnOperationRef: values.turn)
            XCTFail("fixture throw expected")
        } catch let error as BASLayerActorError {
            XCTAssertEqual(
                error,
                .internalFailure(layerID: .l7, message: "fixture throw"))
        }
        let throwingCount = await throwingActor.callCount
        XCTAssertEqual(throwingCount, 1)
    }

    func testFreshContextDriftStopsActorWithoutCoreReevaluation() async throws {
        let values = try fixture()
        let baseKill = values.context.killSwitchState

        let changedGeneration = replacingKillState(
            baseKill,
            monotonicGeneration: baseKill.monotonicGeneration + 1)
        try await assertFreshContextRejected(
            .killGenerationMismatch,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                killSwitchState: changedGeneration))

        let fullKillDrifts = [
            replacingKillState(
                baseKill,
                reason: .thermalEmergency),
            replacingKillState(
                baseKill,
                detail: "changed-detail"),
            replacingKillState(
                baseKill,
                activatedAt: Date(timeIntervalSince1970: 3)),
            replacingKillState(
                baseKill,
                activatedBy: "changed-activator"),
            replacingKillState(
                baseKill,
                activationSequence: baseKill.activationSequence + 1),
            replacingKillState(
                baseKill,
                authority: "host.alternate"),
            replacingKillState(
                baseKill,
                signatureAttestationArtifactID: artifact("6")),
        ]
        for changedKill in fullKillDrifts {
            try await assertFreshContextRejected(
                .killStateChanged,
                ingress: values.ingress,
                initialContext: values.context,
                freshContext: replacingContext(
                    values.context,
                    killSwitchState: changedKill))
        }

        try await assertFreshContextRejected(
            .revocationGenerationMismatch,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                revocationGeneration:
                    values.context.revocationGeneration + 1))
        try await assertFreshContextRejected(
            .logicalEpochMismatch,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                logicalEpoch: values.context.logicalEpoch + 1))
        try await assertFreshContextRejected(
            .snapshotRootMismatch,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                snapshotRootArtifactID: artifact("5")))
        try await assertFreshContextRejected(
            .deadlineMismatch,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                monotonicDeadlineNanos:
                    values.context.monotonicDeadlineNanos + 1))
        let narrowedBudget = try values.context.budget.attenuated(
            bytesAllowance: values.context.budget.bytesAllowance - 1)
        try await assertFreshContextRejected(
            .budgetMismatch,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                budget: narrowedBudget))
        try await assertFreshContextRejected(
            .monotonicClockRegressed,
            ingress: values.ingress,
            initialContext: values.context,
            freshContext: replacingContext(
                values.context,
                monotonicNowNanos:
                    values.context.monotonicNowNanos - 1))
    }

    func testPreparedStateCannotMoveToAnotherActor() async throws {
        let values = try fixture()
        let core = CountingCore(
            request: proposedRequest(turnID: "forged"))
        let originalActor = CountingActor()
        let originalCell = BASLayerCell(
            core: core,
            actor: originalActor)
        let prepared = try originalCell.prepare(
            values.ingress,
            context: values.context)
        let otherActor = CountingActor()
        let otherCell = BASLayerCell(core: core, actor: otherActor)

        do {
            _ = try await otherCell.revalidateAndInvoke(
                prepared,
                context: values.context)
            XCTFail("prepared actor identity must be fixed")
        } catch {
            XCTAssertEqual(
                error as? BASLayerCellError,
                .preparedActorMismatch)
        }
        XCTAssertEqual(core.callCount, 1)
        let originalCount = await originalActor.callCount
        let otherCount = await otherActor.callCount
        XCTAssertEqual(originalCount, 0)
        XCTAssertEqual(otherCount, 0)
    }

    func testResumeAndEgressTruthTableAndReceiptRules() async throws {
        let values = try fixture()
        let outputArtifactID = artifact("1")
        let receiptArtifactID = artifact("2")

        let emitCore = CountingCore(
            decision: .emit(Output(value: "emitted")))
        let emitActor = CountingActor()
        let emitCell = BASLayerCell(core: emitCore, actor: emitActor)
        let emitPrepared = try emitCell.prepare(
            values.ingress,
            context: values.context)
        XCTAssertFalse(emitPrepared.requiresMechanism)
        do {
            _ = try await emitCell.revalidateAndInvoke(
                emitPrepared,
                context: values.context)
            XCTFail("emit must not cross the mechanism")
        } catch {
            XCTAssertEqual(
                error as? BASLayerCellError,
                .mechanismNotRequested)
        }
        let emitResolved = try emitCell.resume(
            emitPrepared,
            actorOutput: nil)
        XCTAssertEqual(emitResolved.output, Output(value: "emitted"))
        XCTAssertEqual(emitResolved.terminalState, .converged)
        let emitEgress = try emitCell.makeEgress(
            from: emitResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: nil)
        XCTAssertTrue(emitEgress.success)
        XCTAssertEqual(emitEgress.body.output, Output(value: "emitted"))
        XCTAssertEqual(emitEgress.body.outputArtifactID, outputArtifactID)
        XCTAssertNil(emitEgress.body.capabilityUseReceiptArtifactID)
        XCTAssertEqual(
            emitEgress.body.orderedParentArtifactIDs,
            values.ingress.body.orderedParentArtifactIDs)
        XCTAssertThrowsError(try emitCell.makeEgress(
            from: emitResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: receiptArtifactID)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .capabilityUseReceiptForbidden)
            }

        let invokeCore = CountingCore(
            request: proposedRequest(turnID: "forged"))
        let invokeActor = CountingActor()
        let invokeCell = BASLayerCell(
            core: invokeCore,
            actor: invokeActor)
        let invokePrepared = try invokeCell.prepare(
            values.ingress,
            context: values.context)
        XCTAssertTrue(invokePrepared.requiresMechanism)
        XCTAssertThrowsError(try invokeCell.resume(
            invokePrepared,
            actorOutput: nil)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .actorOutputRequired)
            }
        let actorOutput = try await invokeCell.revalidateAndInvoke(
            invokePrepared,
            context: replacingContext(
                values.context,
                monotonicNowNanos:
                    values.context.monotonicNowNanos + 1))
        let invokeResolved = try invokeCell.resume(
            invokePrepared,
            actorOutput: actorOutput)
        XCTAssertEqual(
            invokeResolved.output,
            Output(value: "actor-output"))
        XCTAssertEqual(invokeCore.resumeCallCount, 1)
        XCTAssertThrowsError(try invokeCell.makeEgress(
            from: invokeResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: nil)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .capabilityUseReceiptRequired)
            }
        let invokeEgress = try invokeCell.makeEgress(
            from: invokeResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: receiptArtifactID)
        XCTAssertTrue(invokeEgress.success)
        XCTAssertEqual(invokeEgress.body.terminalState, .converged)
        XCTAssertEqual(
            invokeEgress.body.capabilityUseReceiptArtifactID,
            receiptArtifactID)
        let invalidArtifactID = BASArtifactID(
            integrityAlgorithm: "SHA256",
            commitmentKeyEpoch: 7,
            commitmentHex: "not-hex")
        XCTAssertThrowsError(try emitCell.makeEgress(
            from: emitResolved,
            outputArtifactID: invalidArtifactID,
            capabilityUseReceiptArtifactID: nil)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .invalidArtifactID(field: "outputArtifactID"))
            }
        XCTAssertThrowsError(try invokeCell.makeEgress(
            from: invokeResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: invalidArtifactID)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .invalidArtifactID(
                        field: "capabilityUseReceiptArtifactID"))
            }

        let remandCore = CountingCore(
            decision: .remand(try remandArtifact(
                budget: values.context.budget)))
        let remandCell = BASLayerCell(
            core: remandCore,
            actor: CountingActor())
        let remandPrepared = try remandCell.prepare(
            values.ingress,
            context: values.context)
        let remandResolved = try remandCell.resume(
            remandPrepared,
            actorOutput: nil)
        let remandEgress = try remandCell.makeEgress(
            from: remandResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: nil)
        XCTAssertFalse(remandEgress.success)
        XCTAssertNil(remandEgress.body.output)
        XCTAssertEqual(remandEgress.body.outputArtifactID, outputArtifactID)
        XCTAssertEqual(remandEgress.body.terminalState, .deferred)
        XCTAssertThrowsError(try remandCell.makeEgress(
            from: remandResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: receiptArtifactID)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .capabilityUseReceiptForbidden)
            }

        let refuseCore = CountingCore(
            decision: .refuse(try refusalArtifact(
                turnOperationRef: values.turn)))
        let refuseCell = BASLayerCell(
            core: refuseCore,
            actor: CountingActor())
        let refusePrepared = try refuseCell.prepare(
            values.ingress,
            context: values.context)
        let refuseResolved = try refuseCell.resume(
            refusePrepared,
            actorOutput: nil)
        let refuseEgress = try refuseCell.makeEgress(
            from: refuseResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: nil)
        XCTAssertFalse(refuseEgress.success)
        XCTAssertNil(refuseEgress.body.output)
        XCTAssertEqual(refuseEgress.body.outputArtifactID, outputArtifactID)
        XCTAssertEqual(refuseEgress.body.terminalState, .rejected)
        XCTAssertThrowsError(try refuseCell.makeEgress(
            from: refuseResolved,
            outputArtifactID: outputArtifactID,
            capabilityUseReceiptArtifactID: receiptArtifactID)) { error in
                XCTAssertEqual(
                    error as? BASLayerCellError,
                    .capabilityUseReceiptForbidden)
            }

        for prepared in [remandPrepared, refusePrepared] {
            XCTAssertThrowsError(try remandCell.resume(
                prepared,
                actorOutput: actorOutput)) { error in
                    XCTAssertEqual(
                        error as? BASLayerCellError,
                        .actorOutputForbidden)
                }
        }
    }

    func testActorFramesAreHashableWithoutWireDrift() throws {
        let input = proposedRequest(turnID: "legacy-turn")
        let output = BASLayerActorOutput(
            layerID: .l7,
            turnID: "legacy-turn",
            status: .completed,
            payloadRef: "legacy-output",
            latencyMs: 1,
            confidence: .high,
            reasonCodes: ["legacy.reason"],
            producedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(Set([input, input]).count, 1)
        XCTAssertEqual(Set([output, output]).count, 1)
        XCTAssertEqual(
            try JSONDecoder().decode(
                BASLayerActorInput.self,
                from: JSONEncoder().encode(input)),
            input)
        XCTAssertEqual(
            try JSONDecoder().decode(
                BASLayerActorOutput.self,
                from: JSONEncoder().encode(output)),
            output)
        let inputObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(input)) as? [String: Any])
        XCTAssertEqual(Set(inputObject.keys), [
            "schemaVersion", "layerID", "turnID", "payloadRef",
            "parentLayerID", "arrivedAt", "correlationID",
        ])
        let outputObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(output)) as? [String: Any])
        XCTAssertEqual(Set(outputObject.keys), [
            "schemaVersion", "layerID", "turnID", "status",
            "payloadRef", "latencyMs", "confidence", "reasonCodes",
            "producedAt",
        ])
    }

    func testValueFieldOrderIsFrozen() async throws {
        let values = try fixture()
        XCTAssertEqual(
            Mirror(reflecting: values.ingress.body).children
                .compactMap(\.label),
            [
                "inputArtifactID", "orderedParentArtifactIDs", "payload",
                "grantArtifactID", "turnOperationRef",
                "causalTurnBranchRef", "logicalEpoch",
                "snapshotRootArtifactID", "killGeneration",
                "revocationGeneration", "monotonicDeadlineNanos", "budget",
            ])
        XCTAssertEqual(
            Mirror(reflecting: values.context).children
                .compactMap(\.label),
            [
                "inputArtifactID", "orderedParentArtifactIDs",
                "grantArtifactID", "turnOperationRef",
                "causalTurnBranchRef", "logicalEpoch",
                "snapshotRootArtifactID", "killSwitchState",
                "revocationGeneration", "monotonicDeadlineNanos",
                "monotonicNowNanos", "budget",
            ])

        let core = CountingCore(
            decision: .emit(Output(value: "ordered")))
        let cell = BASLayerCell(core: core, actor: CountingActor())
        let prepared = try cell.prepare(
            values.ingress,
            context: values.context)
        let resolved = try cell.resume(prepared, actorOutput: nil)
        let egress = try cell.makeEgress(
            from: resolved,
            outputArtifactID: artifact("1"),
            capabilityUseReceiptArtifactID: nil)
        XCTAssertEqual(
            Mirror(reflecting: egress.body).children.compactMap(\.label),
            [
                "output", "outputArtifactID",
                "capabilityUseReceiptArtifactID",
                "orderedParentArtifactIDs", "terminalState",
            ])
    }

    func testLayerCellMarkerHasOneCrossingAndNoOwnerLeak() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let actorURL = packageRoot
            .appendingPathComponent("Sources/BASRuntimeCore/BASLayerActor.swift")
        let source = try String(contentsOf: actorURL, encoding: .utf8)
        XCTAssertEqual(
            source.components(
                separatedBy: "// BEGIN BASLayerCell").count - 1,
            1)
        XCTAssertEqual(
            source.components(
                separatedBy: "// END BASLayerCell").count - 1,
            1)
        XCTAssertEqual(
            source.components(
                separatedBy: "public struct BASLayerCell<").count - 1,
            1)
        let start = try XCTUnwrap(source.range(of: "// BEGIN BASLayerCell"))
        let end = try XCTUnwrap(
            source.range(of: "// END BASLayerCell", range: start.upperBound..<source.endIndex))
        let marker = String(source[start.lowerBound..<end.upperBound])

        XCTAssertEqual(
            marker.components(separatedBy: "mechanism.invoke(").count - 1,
            1)
        XCTAssertEqual(
            marker.components(separatedBy: "await").count - 1,
            1)
        XCTAssertTrue(marker.contains(
            "let output = try await mechanism.invoke("))
        for forbidden in [
            "private var", "actorRegistry", "scheduler", "retry",
            "cache", "SQLite", "FileManager", "URLSession", ".put(",
            "reserve", "claim", "mint", "rank(", "advanceKill",
            "attenuated(", "validateCapability", "BASLayerBudget",
            "BASKillEpoch",
        ] {
            XCTAssertFalse(marker.contains(forbidden), forbidden)
        }
    }

    func testPreparedAndResolvedStatesCannotBePubliclyOrDecodablyForged()
        throws
    {
        let testURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let actorURL = packageRoot
            .appendingPathComponent("Sources/BASRuntimeCore/BASLayerActor.swift")
        let source = try String(contentsOf: actorURL, encoding: .utf8)
        let runtimeCoreURL = actorURL.deletingLastPathComponent()
        let sourceEnumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: runtimeCoreURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]))
        var runtimeCoreSourceURLs: [URL] = []
        for case let sourceURL as URL in sourceEnumerator
        where sourceURL.pathExtension == "swift" {
            runtimeCoreSourceURLs.append(sourceURL)
        }
        let runtimeCoreSource = try runtimeCoreSourceURLs
            .sorted { $0.path < $1.path }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        func declaration(
            from startToken: String,
            through endToken: String
        ) throws -> String {
            let start = try XCTUnwrap(source.range(of: startToken))
            let end = try XCTUnwrap(source.range(
                of: endToken,
                range: start.upperBound..<source.endIndex))
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let prepared = try declaration(
            from: "public struct BASLayerCellPreparedState<",
            through: "public struct BASLayerCellResolvedState<")
        let resolved = try declaration(
            from: "public struct BASLayerCellResolvedState<",
            through: "private enum BASLayerCellValidation")
        let context = try declaration(
            from: "public struct BASLayerCellMembraneContext:",
            through: "public enum BASLayerCellError")
        let egress = try declaration(
            from: "public struct BASLayerCellEgressBody<",
            through: "public typealias BASLayerCellEgress<")

        for state in [prepared, resolved] {
            XCTAssertFalse(state.contains("Codable"))
            XCTAssertFalse(state.contains("public init"))
            XCTAssertTrue(state.contains("fileprivate init"))
        }
        XCTAssertFalse(context.contains("Codable"))
        XCTAssertTrue(context.contains("Sendable, Equatable"))
        XCTAssertFalse(egress.contains("public init"))
        XCTAssertTrue(egress.contains("fileprivate init"))
        for typeName in [
            "BASLayerCell",
            "BASLayerCellPreparedState",
            "BASLayerCellResolvedState",
            "BASLayerCellEgressBody",
            "BASLayerCellMembraneContext",
        ] {
            XCTAssertNil(
                runtimeCoreSource.range(
                    of: #"\bextension\s+"# + typeName + #"\b"#,
                    options: .regularExpression),
                typeName)
        }
        XCTAssertEqual(
            runtimeCoreSource.components(
                separatedBy: "public protocol BASSemanticLayerCore").count - 1,
            1)
        XCTAssertFalse(
            runtimeCoreSource.contains("protocol BASLayerActorMechanism"))
    }
}
