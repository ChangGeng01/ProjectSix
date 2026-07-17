import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASTurnOperationRefTests: XCTestCase {
    func testOperationAndAllTypedBranchesRoundTripToOneRoot() throws {
        let operation = try makeOperation(1)
        let branches = [
            try BASTurnBranchRef(
                turnOperationRef: operation,
                kind: .providerEgress,
                ordinal: 1),
            try BASTurnBranchRef(
                turnOperationRef: operation,
                kind: .provisionalStream,
                ordinal: 0),
            try BASTurnBranchRef(
                turnOperationRef: operation,
                kind: .finalPublication,
                ordinal: 0),
            try BASTurnBranchRef(
                turnOperationRef: operation,
                kind: .effect,
                ordinal: 1),
        ]

        XCTAssertEqual(Set(branches).count, 4)
        for branch in branches {
            let projection = try branch.canonicalLegacyProjection()
            let decoded = try BASTurnBranchRef(
                validatingCanonicalLegacyProjection: projection,
                expectedTurnOperationRef: operation)
            XCTAssertEqual(decoded, branch)
            XCTAssertEqual(decoded.turnOperationRef, operation)
        }
    }

    func testCanonicalLegacyProjectionFixedVectors() throws {
        let operation = try makeOperation(1)
        let operationProjection = try operation.canonicalLegacyProjection()
        XCTAssertEqual(
            operationProjection,
            "MjU6YmFzLXR1cm4tb3BlcmF0aW9uLXJlZi12MTE1MjpNalk2WW1GekxXRnlkR2xtWVdOMExXbGtMWE4wYjNKaFoyVXRkakV4TVRwb2JXRmpMWE5vWVRJMU5qRTZNVFkwT2pBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURFPQ==")
        XCTAssertEqual(
            try BASTurnOperationRef(
                validatingCanonicalLegacyProjection: operationProjection),
            operation)

        let branch = try BASTurnBranchRef(
            turnOperationRef: operation,
            kind: .providerEgress,
            ordinal: 7)
        let branchProjection = try branch.canonicalLegacyProjection()
        XCTAssertEqual(
            branchProjection,
            "MjI6YmFzLXR1cm4tYnJhbmNoLXJlZi12MTE1MjpNalk2WW1GekxXRnlkR2xtWVdOMExXbGtMWE4wYjNKaFoyVXRkakV4TVRwb2JXRmpMWE5vWVRJMU5qRTZNVFkwT2pBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURBd01EQXdNREF3TURFPTE0OnByb3ZpZGVyRWdyZXNzMTo3")
        XCTAssertEqual(
            try BASTurnBranchRef(
                validatingCanonicalLegacyProjection: branchProjection),
            branch)

        let maximum = try BASTurnBranchRef(
            turnOperationRef: operation,
            kind: .effect,
            ordinal: UInt64.max)
        XCTAssertEqual(
            try BASTurnBranchRef(
                validatingCanonicalLegacyProjection:
                    maximum.canonicalLegacyProjection()),
            maximum)
    }

    func testStreamAndFinalBranchesRejectNonzeroOrdinals() throws {
        let operation = try makeOperation(2)
        XCTAssertThrowsError(try BASTurnBranchRef(
            turnOperationRef: operation,
            kind: .provisionalStream,
            ordinal: 1))
        XCTAssertThrowsError(try BASTurnBranchRef(
            turnOperationRef: operation,
            kind: .finalPublication,
            ordinal: UInt64.max))
    }

    func testOperationRefRejectsUnvalidatedArtifactID() {
        let invalid = BASArtifactID(
            integrityAlgorithm: "HMAC-SHA256",
            commitmentKeyEpoch: 1,
            commitmentHex: "AB")
        XCTAssertThrowsError(try BASTurnOperationRef(artifactID: invalid))
    }

    func testOperationProjectionRejectsMalformedAndNoncanonicalInputs()
        throws
    {
        let valid = try makeOperation(3).canonicalLegacyProjection()
        var trailing = try XCTUnwrap(Data(base64Encoded: valid))
        trailing.append(120)
        let malformed = [
            "",
            "%%%",
            String(valid.dropLast()),
            String(valid.dropLast(3)) + "R==",
            frame(["bas-turn-operation-ref-v2", artifactIDScalar(3)]),
            frame(["bas-turn-operation-ref-v1"]),
            frame([
                "bas-turn-operation-ref-v1",
                artifactIDScalar(3),
                "extra",
            ]),
            frame(["bas-turn-operation-ref-v1", "not-an-artifact-id"]),
            trailing.base64EncodedString(),
            Data("01:x".utf8).base64EncodedString(),
            Data("4:abc".utf8).base64EncodedString(),
            Data([49, 58, 255]).base64EncodedString(),
            frame([
                "bas-turn-operation-ref-v1",
                String(repeating: "x", count: 1_025),
            ]),
            frame(["1", "2", "3", "4", "5", "6"]),
            String(repeating: "A", count: 4_097),
        ]

        for projection in malformed {
            XCTAssertThrowsError(try BASTurnOperationRef(
                validatingCanonicalLegacyProjection: projection), projection)
        }
    }

    func testBranchProjectionRejectsMalformedKindOrdinalAndShape()
        throws
    {
        let scalar = artifactIDScalar(4)
        let malformed = [
            "",
            "%%%",
            frame(["bas-turn-branch-ref-v2", scalar, "effect", "1"]),
            frame(["bas-turn-branch-ref-v1", scalar, "effect"]),
            frame([
                "bas-turn-branch-ref-v1", scalar, "effect", "1", "extra",
            ]),
            frame(["bas-turn-branch-ref-v1", scalar, "unknown", "1"]),
            frame(["bas-turn-branch-ref-v1", scalar, "effect", "01"]),
            frame(["bas-turn-branch-ref-v1", scalar, "effect", "-1"]),
            frame([
                "bas-turn-branch-ref-v1", scalar, "effect",
                "18446744073709551616",
            ]),
            frame([
                "bas-turn-branch-ref-v1", scalar, "provisionalStream", "1",
            ]),
            frame([
                "bas-turn-branch-ref-v1", scalar, "finalPublication", "2",
            ]),
        ]

        for projection in malformed {
            XCTAssertThrowsError(try BASTurnBranchRef(
                validatingCanonicalLegacyProjection: projection), projection)
        }
    }

    func testBranchProjectionRejectsForeignExpectedParent() throws {
        let operation = try makeOperation(5)
        let foreign = try makeOperation(6)
        let branch = try BASTurnBranchRef(
            turnOperationRef: operation,
            kind: .providerEgress,
            ordinal: 17)

        XCTAssertThrowsError(try BASTurnBranchRef(
            validatingCanonicalLegacyProjection:
                branch.canonicalLegacyProjection(),
            expectedTurnOperationRef: foreign))
    }

    func testProjectionFailuresStayInTheirTypedErrorDomains() {
        XCTAssertThrowsError(try BASTurnOperationRef(
            validatingCanonicalLegacyProjection: "%%%")) { error in
            XCTAssertEqual(
                error as? BASTurnOperationRefError,
                .malformedProjection)
        }
        XCTAssertThrowsError(try BASTurnBranchRef(
            validatingCanonicalLegacyProjection: "%%%")) { error in
            XCTAssertEqual(
                error as? BASTurnBranchRefError,
                .malformedProjection)
        }
        let canonical = try! makeOperation(1).canonicalLegacyProjection()
        let nonCanonical = String(canonical.dropLast(3)) + "R=="
        XCTAssertThrowsError(try BASTurnOperationRef(
            validatingCanonicalLegacyProjection: nonCanonical)) { error in
            XCTAssertEqual(
                error as? BASTurnOperationRefError,
                .nonCanonicalProjection)
        }
    }

    func testCodableCannotBypassSingletonBranchValidation() throws {
        let operation = try makeOperation(7)
        let object: [String: Any] = [
            "turnOperationRef": [
                "artifactID": [
                    "integrityAlgorithm": operation.artifactID.integrityAlgorithm,
                    "commitmentKeyEpoch": operation.artifactID.commitmentKeyEpoch,
                    "commitmentHex": operation.artifactID.commitmentHex,
                ],
            ],
            "kind": "provisionalStream",
            "ordinal": 1,
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASTurnBranchRef.self,
            from: data))
    }

    func testTurnOperationPayloadIsSelfIDFreeAndGoverned() throws {
        let payload = try turnPayload()
        let bytes = try BASGovernedArtifactPayloadCodec.canonicalBytes(
            for: payload)
        XCTAssertEqual(
            try BASGovernedArtifactPayloadCodec.decodeCurrent(
                BASTurnOperationPayload.self,
                from: bytes),
            payload)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? String, "1.0.0")
        XCTAssertEqual(Set(object.keys), [
            "schemaVersion",
            "workspaceAuthorityArtifactID",
            "workspaceIncarnationArtifactID",
            "attemptRefArtifactID",
            "generationVectorArtifactID",
            "inputArtifactID",
            "budgetLeaseArtifactID",
            "orderedSelectedModelProfileLineageArtifactIDs",
            "policyEpoch",
            "deletionEpoch",
            "restorationEpoch",
            "runtimeSchemaEpoch",
        ])
        XCTAssertTrue(Set(object.keys).isDisjoint(with: [
            "artifactID", "turnOperationArtifactID", "digest", "signature",
            "branchID", "receipt", "snapshotRootArtifactID", "payloadRef",
        ]))
    }

    func testBudgetLeasePayloadCarriesOnlyImmutableCeilings() throws {
        let payload = try budgetLease()
        let bytes = try BASGovernedArtifactPayloadCodec.canonicalBytes(
            for: payload)
        XCTAssertEqual(
            try BASGovernedArtifactPayloadCodec.decodeCurrent(
                BASBudgetLeasePayload.self,
                from: bytes),
            payload)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(Set(object.keys), [
            "schemaVersion",
            "attemptRefArtifactID",
            "generationVectorArtifactID",
            "authorizationGrantArtifactID",
            "policyEpoch",
            "deletionEpoch",
            "bootSessionID",
            "tokenCeiling",
            "byteCeiling",
            "branchCeiling",
            "remandRoundCeiling",
            "hopCeiling",
            "costMicrounitsCeiling",
            "monotonicDeadlineNanos",
        ])
        XCTAssertTrue(Set(object.keys).isDisjoint(with: [
            "artifactID", "budgetLeaseArtifactID", "remainingTokens",
            "remainingBytes", "spentTokens", "spentBytes", "revision",
            "terminalState", "receiptArtifactID", "signature",
        ]))
    }

    func testAdmissionPayloadsRejectInvalidIDsAndUnboundedAuthorityFields()
        throws
    {
        let invalidID = BASArtifactID(
            integrityAlgorithm: "HMAC-SHA256",
            commitmentKeyEpoch: 1,
            commitmentHex: "AB")
        XCTAssertThrowsError(try turnPayload(
            workspaceAuthorityArtifactID: invalidID))
        XCTAssertThrowsError(try turnPayload(lineage: [
            artifactID(30), artifactID(30),
        ]))
        XCTAssertThrowsError(try turnPayload(
            lineage: (100..<165).map { artifactID(UInt64($0)) }))
        XCTAssertNoThrow(try turnPayload(
            lineage: (200..<264).map { artifactID(UInt64($0)) }))

        XCTAssertThrowsError(try budgetLease(
            attemptRefArtifactID: invalidID))
        XCTAssertThrowsError(try budgetLease(bootSessionID: ""))
        XCTAssertThrowsError(try budgetLease(
            bootSessionID: String(repeating: "b", count: 257)))
        XCTAssertNoThrow(try budgetLease(
            bootSessionID: String(repeating: "b", count: 256)))
    }

    func testAdmissionPayloadCodableCannotBypassDomainValidation() throws {
        let operationBytes = try JSONEncoder().encode(turnPayload())
        var operationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: operationBytes)
                as? [String: Any])
        let lineage = try XCTUnwrap(
            operationObject[
                "orderedSelectedModelProfileLineageArtifactIDs"
            ] as? [Any])
        operationObject["orderedSelectedModelProfileLineageArtifactIDs"] = [
            lineage[0], lineage[0],
        ]
        let duplicateLineageBytes = try JSONSerialization.data(
            withJSONObject: operationObject,
            options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASTurnOperationPayload.self,
            from: duplicateLineageBytes))

        let leaseBytes = try JSONEncoder().encode(budgetLease())
        var leaseObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: leaseBytes)
                as? [String: Any])
        leaseObject["bootSessionID"] = ""
        let emptyBootBytes = try JSONSerialization.data(
            withJSONObject: leaseObject,
            options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASBudgetLeasePayload.self,
            from: emptyBootBytes))
    }

    func testGovernedPayloadCodecRejectsFutureSchemaWrites() throws {
        let future = try BASTurnOperationPayload(
            schemaVersion: "2.0.0",
            workspaceAuthorityArtifactID: artifactID(1),
            workspaceIncarnationArtifactID: artifactID(2),
            attemptRefArtifactID: artifactID(3),
            generationVectorArtifactID: artifactID(4),
            inputArtifactID: artifactID(5),
            budgetLeaseArtifactID: artifactID(6),
            orderedSelectedModelProfileLineageArtifactIDs: [],
            policyEpoch: 7,
            deletionEpoch: 8,
            restorationEpoch: 9,
            runtimeSchemaEpoch: 10)
        XCTAssertThrowsError(try BASGovernedArtifactPayloadCodec.canonicalBytes(
            for: future))
    }

    func testProviderVocabularyHasExactFrozenCasesAndJSONWire() throws {
        XCTAssertEqual(
            BASProviderStepPurpose.allCases.map(\.rawValue),
            ["groundingProposal", "turnStep", "verifierProposal"])
        XCTAssertEqual(
            BASProviderOutputRole.allCases.map(\.rawValue),
            ["internalProposal", "terminalAnswerCandidate"])
        XCTAssertEqual(
            BASProviderVisibilityMode.allCases.map(\.rawValue),
            ["incrementalVerified", "bufferedUntilVerified"])

        XCTAssertEqual(
            String(decoding: try JSONEncoder().encode(
                BASProviderStepPurpose.groundingProposal), as: UTF8.self),
            "\"groundingProposal\"")
        XCTAssertEqual(
            String(decoding: try JSONEncoder().encode(
                BASProviderOutputRole.terminalAnswerCandidate), as: UTF8.self),
            "\"terminalAnswerCandidate\"")
        XCTAssertEqual(
            String(decoding: try JSONEncoder().encode(
                BASProviderVisibilityMode.bufferedUntilVerified),
                as: UTF8.self),
            "\"bufferedUntilVerified\"")
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASProviderStepPurpose.self,
            from: Data("\"unknown\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASProviderOutputRole.self,
            from: Data("\"unknown\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(
            BASProviderVisibilityMode.self,
            from: Data("\"unknown\"".utf8)))
    }

    func testProviderExecutionRefHasExactFieldOrderAndSequenceZeroBase()
        throws
    {
        let value = try providerExecutionBase()

        XCTAssertEqual(
            Mirror(reflecting: value).children.compactMap(\.label),
            [
                "turnOperationRef", "providerEgressBranchRef",
                "attemptRef", "leaseID", "providerExecutionID",
                "acceptanceGeneration", "requestSequence",
            ])
        XCTAssertEqual(value.requestSequence, 0)
        XCTAssertEqual(Set([value, value]).count, 1)

        let baseBytes = try JSONEncoder().encode(value)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: baseBytes) as? [String: Any])
        XCTAssertEqual(Set(object.keys), [
            "turnOperationRef", "providerEgressBranchRef", "attemptRef",
            "leaseID", "providerExecutionID", "acceptanceGeneration",
            "requestSequence",
        ])
        let decoded = try JSONDecoder().decode(
            BASProviderExecutionRef.self,
            from: baseBytes)
        XCTAssertEqual(decoded, value)

        let event = try value.withRequestSequence(17)
        XCTAssertEqual(
            try JSONDecoder().decode(
                BASProviderExecutionRef.self,
                from: JSONEncoder().encode(event)),
            event)
    }

    func testProviderExecutionRefRejectsWrongParentKindAndInvalidIDs()
        throws
    {
        let root = try makeOperation(40)
        let foreignRoot = try makeOperation(41)
        let correctBranch = try BASTurnBranchRef(
            turnOperationRef: root,
            kind: .providerEgress,
            ordinal: 3)
        let foreignBranch = try BASTurnBranchRef(
            turnOperationRef: foreignRoot,
            kind: .providerEgress,
            ordinal: 3)
        let effectBranch = try BASTurnBranchRef(
            turnOperationRef: root,
            kind: .effect,
            ordinal: 3)
        let invalidID = BASArtifactID(
            integrityAlgorithm: "HMAC-SHA256",
            commitmentKeyEpoch: 1,
            commitmentHex: "AB")

        XCTAssertThrowsError(try BASProviderExecutionRef(
            turnOperationRef: root,
            providerEgressBranchRef: foreignBranch,
            attemptRef: artifactID(42),
            leaseID: artifactID(43),
            providerExecutionID: "provider-execution",
            acceptanceGeneration: 44))
        XCTAssertThrowsError(try BASProviderExecutionRef(
            turnOperationRef: root,
            providerEgressBranchRef: effectBranch,
            attemptRef: artifactID(42),
            leaseID: artifactID(43),
            providerExecutionID: "provider-execution",
            acceptanceGeneration: 44))
        XCTAssertThrowsError(try BASProviderExecutionRef(
            turnOperationRef: root,
            providerEgressBranchRef: correctBranch,
            attemptRef: invalidID,
            leaseID: artifactID(43),
            providerExecutionID: "provider-execution",
            acceptanceGeneration: 44))
        XCTAssertThrowsError(try BASProviderExecutionRef(
            turnOperationRef: root,
            providerEgressBranchRef: correctBranch,
            attemptRef: artifactID(42),
            leaseID: invalidID,
            providerExecutionID: "provider-execution",
            acceptanceGeneration: 44))
    }

    func testProviderExecutionIDIsNonemptyOpaqueExactUTF8() throws {
        let root = try makeOperation(45)
        let branch = try BASTurnBranchRef(
            turnOperationRef: root,
            kind: .providerEgress,
            ordinal: 0)

        XCTAssertThrowsError(try BASProviderExecutionRef(
            turnOperationRef: root,
            providerEgressBranchRef: branch,
            attemptRef: artifactID(46),
            leaseID: artifactID(47),
            providerExecutionID: "",
            acceptanceGeneration: 48))
        for exact in [
            " provider-execution ", "provider-execution\n",
            "\tprovider-execution", String(repeating: "p", count: 4_096),
        ] {
            let value = try BASProviderExecutionRef(
                turnOperationRef: root,
                providerEgressBranchRef: branch,
                attemptRef: artifactID(46),
                leaseID: artifactID(47),
                providerExecutionID: exact,
                acceptanceGeneration: 48)
            XCTAssertEqual(value.providerExecutionID, exact)
        }
    }

    func testProviderExecutionIDEqualityAndHashingAreRawUTF8Exact()
        throws
    {
        let composedID = "\u{00E9}"
        let decomposedID = "e\u{0301}"
        XCTAssertNotEqual(Array(composedID.utf8), Array(decomposedID.utf8))

        let composed = try providerExecutionBase(
            providerExecutionID: composedID)
        let decomposed = try providerExecutionBase(
            providerExecutionID: decomposedID)
        XCTAssertNotEqual(composed, decomposed)
        XCTAssertEqual(Set([composed, decomposed]).count, 2)

        for base in [composed, decomposed] {
            let event = try base.withRequestSequence(5)
            XCTAssertEqual(
                Array(event.providerExecutionID.utf8),
                Array(base.providerExecutionID.utf8))
            XCTAssertEqual(event.canonicalSequenceZeroBase(), base)
            let decoded = try JSONDecoder().decode(
                BASProviderExecutionRef.self,
                from: JSONEncoder().encode(event))
            XCTAssertEqual(decoded, event)
            XCTAssertEqual(
                Array(decoded.providerExecutionID.utf8),
                Array(base.providerExecutionID.utf8))
        }
    }

    func testOnlyCanonicalZeroBaseCanDerivePositiveEventSequence()
        throws
    {
        let base = try providerExecutionBase()

        XCTAssertThrowsError(try base.withRequestSequence(0))
        let event = try base.withRequestSequence(7)
        XCTAssertEqual(event.requestSequence, 7)
        XCTAssertThrowsError(try event.withRequestSequence(8))
        XCTAssertEqual(event.canonicalSequenceZeroBase(), base)
    }

    func testSequenceDerivationPreservesAllSixStableFields() throws {
        let base = try providerExecutionBase()
        let event = try base.withRequestSequence(UInt64.max)
        let canonical = event.canonicalSequenceZeroBase()

        XCTAssertEqual(event.turnOperationRef, base.turnOperationRef)
        XCTAssertEqual(
            event.providerEgressBranchRef,
            base.providerEgressBranchRef)
        XCTAssertEqual(event.attemptRef, base.attemptRef)
        XCTAssertEqual(event.leaseID, base.leaseID)
        XCTAssertEqual(event.providerExecutionID, base.providerExecutionID)
        XCTAssertEqual(
            event.acceptanceGeneration,
            base.acceptanceGeneration)
        XCTAssertEqual(canonical, base)
        XCTAssertEqual(canonical.requestSequence, 0)
    }

    func testDecodedEventCanCanonicalizeButCannotDeriveAgain() throws {
        let event = try providerExecutionBase().withRequestSequence(9)
        let decoded = try JSONDecoder().decode(
            BASProviderExecutionRef.self,
            from: JSONEncoder().encode(event))

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(
            decoded.canonicalSequenceZeroBase(),
            try providerExecutionBase())
        XCTAssertThrowsError(try decoded.withRequestSequence(10))
    }

    func testProviderExecutionRefDecodeCannotBypassValidation() throws {
        let base = try providerExecutionBase()
        let encoded = try JSONEncoder().encode(base)
        let validObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let foreignBranchObject = try branchObject(
            rootSeed: 70, kind: .providerEgress, ordinal: 3)
        let effectBranchObject = try branchObject(
            rootSeed: 40, kind: .effect, ordinal: 3)

        func rejects(_ mutation: (inout [String: Any]) -> Void) {
            var object = validObject
            mutation(&object)
            XCTAssertThrowsError(try JSONDecoder().decode(
                BASProviderExecutionRef.self,
                from: JSONSerialization.data(withJSONObject: object)))
        }

        rejects { object in
            object["providerEgressBranchRef"] = foreignBranchObject
        }
        rejects { object in
            object["providerEgressBranchRef"] = effectBranchObject
        }
        rejects { object in
            object["attemptRef"] = self.invalidArtifactIDObject()
        }
        rejects { object in
            object["leaseID"] = self.invalidArtifactIDObject()
        }
        rejects { object in
            object["providerExecutionID"] = ""
        }
    }

    func testProviderExecutionRefDecodeRejectsUnknownTopLevelKey() throws {
        let encoded = try JSONEncoder().encode(providerExecutionBase())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["unexpectedEighthKey"] = true

        XCTAssertThrowsError(try JSONDecoder().decode(
            BASProviderExecutionRef.self,
            from: JSONSerialization.data(withJSONObject: object)))
    }

    func testEachStableFieldMutationFailsBaseEquality() throws {
        let base = try providerExecutionBase()
        let otherRoot = try makeOperation(80)
        let otherRootBranch = try BASTurnBranchRef(
            turnOperationRef: otherRoot,
            kind: .providerEgress,
            ordinal: base.providerEgressBranchRef.ordinal)
        let otherBranch = try BASTurnBranchRef(
            turnOperationRef: base.turnOperationRef,
            kind: .providerEgress,
            ordinal: base.providerEgressBranchRef.ordinal + 1)
        let mutatedBases = [
            try providerExecutionBase(
                turnOperationRef: otherRoot,
                providerEgressBranchRef: otherRootBranch),
            try providerExecutionBase(providerEgressBranchRef: otherBranch),
            try providerExecutionBase(attemptRef: artifactID(81)),
            try providerExecutionBase(leaseID: artifactID(82)),
            try providerExecutionBase(providerExecutionID: "mutated"),
            try providerExecutionBase(acceptanceGeneration: 83),
        ]

        XCTAssertEqual(mutatedBases.count, 6)
        for mutated in mutatedBases {
            let event = try mutated.withRequestSequence(1)
            XCTAssertNotEqual(event.canonicalSequenceZeroBase(), base)
        }
    }

    func testProviderExecutionRefHasOneSequenceAPIAndNoEventRefSibling()
        throws
    {
        let sources = try allProductSwiftSources()
        let source = sources.map(\.text).joined(separator: "\n")
        let declarationPrefix = #"(?m)^[\t ]*(?:(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^{}\r\n]*\))?|[A-Za-z_][A-Za-z0-9_]*)[\t \r\n]+)*"#
        let refDeclarationKinds =
            #"(?:struct|enum|class|actor|protocol|typealias)[\t \r\n]+BASProviderExecutionRef\b"#
        XCTAssertEqual(
            matchCount(declarationPrefix + refDeclarationKinds, in: source),
            1)
        XCTAssertEqual(
            matchCount(
                declarationPrefix
                    + #"struct[\t \r\n]+BASProviderExecutionRef\b"#,
                in: source),
            1)
        for enumName in [
            "BASProviderStepPurpose", "BASProviderOutputRole",
            "BASProviderVisibilityMode",
        ] {
            XCTAssertEqual(
                source.components(
                    separatedBy: "public enum \(enumName)").count - 1,
                1,
                enumName)
        }
        XCTAssertEqual(
            matchCount(
                declarationPrefix
                    + #"(?:struct|enum|class|actor|protocol|typealias)[\t \r\n]+BAS[A-Za-z0-9_]*Provider[A-Za-z0-9_]*(?:Event|Execution)[A-Za-z0-9_]*Ref\b"#,
                in: source),
            1)
        XCTAssertEqual(
            matchCount(
                declarationPrefix
                    + #"extension[\t \r\n]+BASProviderExecutionRef\b"#,
                in: source),
            0)
        XCTAssertEqual(
            matchCount(
                declarationPrefix
                    + #"(?:struct|enum|class|actor|protocol|typealias)[\t \r\n]+BAS[A-Za-z0-9_]*Provider[A-Za-z0-9_]*(?:Event|Execution)[A-Za-z0-9_]*Codec\b"#,
                in: source),
            0)
        for forbidden in [
            "BASProviderEventRef", "BASProviderEventExecutionRef",
            "BASProviderExecutionEventRef", "BASProviderEventRefCodec",
            "BASProviderExecutionRefCodec",
            "BASProviderExecutionEventCodec",
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        XCTAssertFalse(matches(
            #"\bBAS\w*Provider\w*Event\w*Ref(?:Codec)?\b"#,
            in: source))
        let registry = try XCTUnwrap(sources.first {
            $0.url.lastPathComponent ==
                "EBrainSchemaGovernanceRegistry.swift"
        }).text
        for forbiddenRegistryEntry in [
            "BASProviderExecutionRef", "BASProviderStepPurpose",
            "BASProviderOutputRole", "BASProviderVisibilityMode",
        ] {
            XCTAssertFalse(
                registry.contains(forbiddenRegistryEntry),
                forbiddenRegistryEntry)
        }
    }

    func testProviderExecutionRefConstructionSurfaceIsExact() throws {
        let source = try lowEntropySource()
        let structStart = try XCTUnwrap(source.range(
            of: "public struct BASProviderExecutionRef"))
        let structEnd = try XCTUnwrap(source.range(
            of: "public enum BASProviderExecutionRefError",
            range: structStart.upperBound..<source.endIndex))
        let declaration = String(
            source[structStart.lowerBound..<structEnd.lowerBound])
        let members = directMemberSurface(of: declaration)
        let initPattern = #"\binit[!?]?\s*\("#
        XCTAssertEqual(matchCount(initPattern, in: members), 4)
        for expectedInitializer in [
            #"\bpublic\b[\t \r\n]+init[\t \r\n]*\([\t \r\n]*turnOperationRef\b"#,
            #"\bprivate\b[\t \r\n]+init[\t \r\n]*\([\t \r\n]*validating\b"#,
            #"\bprivate\b[\t \r\n]+init[\t \r\n]*\([\t \r\n]*canonicalSequenceZeroFrom\b"#,
            #"\bpublic\b[\t \r\n]+init[\t \r\n]*\([\t \r\n]*from\b"#,
        ] {
            XCTAssertEqual(matchCount(expectedInitializer, in: members), 1)
        }

        let functionNames = matchedCaptures(
            #"\bfunc\s+(==|[A-Za-z_][A-Za-z0-9_]*)\s*\("#,
            capture: 1,
            in: members)
        XCTAssertEqual(matchCount(#"\bfunc\b"#, in: members), 5)
        XCTAssertEqual(
            functionNames.sorted(),
            [
                "==", "canonicalSequenceZeroBase", "hash", "validate",
                "withRequestSequence",
            ])

        let uncommentedDeclaration = declaration.split(
            separator: "\n",
            omittingEmptySubsequences: false).map { line in
                line.split(
                    separator: "//",
                    maxSplits: 1,
                    omittingEmptySubsequences: false).first.map(String.init)
                    ?? ""
            }.joined(separator: "\n")
        let arbitraryModifiers = #"(?:(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^{}\r\n]*\))?|[A-Za-z_][A-Za-z0-9_]*(?:\([^{}\r\n]*\))?)\s+)*"#
        XCTAssertEqual(
            matchCount(
                #"(?m)^[\t ]*"# + arbitraryModifiers
                    + #"init[!?]?\s*\("#,
                in: uncommentedDeclaration),
            4)
        XCTAssertEqual(
            matchedCaptures(
                #"(?m)^[\t ]*"# + arbitraryModifiers
                    + #"func\s+(==|[A-Za-z_][A-Za-z0-9_]*)\s*\("#,
                capture: 1,
                in: uncommentedDeclaration).sorted(),
            [
                "==", "canonicalSequenceZeroBase", "hash", "validate",
                "withRequestSequence",
            ])
        XCTAssertEqual(
            matchCount(#"\bfunc\b"#, in: uncommentedDeclaration),
            5)
        let allTypeDeclarations = #"(?m)^[\t ]*"#
            + arbitraryModifiers
            + #"(?:struct|enum|class|actor|protocol|typealias)\s+[A-Za-z_][A-Za-z0-9_]*\b"#
        XCTAssertEqual(
            matchCount(allTypeDeclarations, in: uncommentedDeclaration),
            2)
        XCTAssertEqual(
            matchCount(
                #"\bprivate\b\s+enum\s+CodingKeys\b"#,
                in: uncommentedDeclaration),
            1)

        let letNames = matchedCaptures(
            #"\blet\s+([A-Za-z_][A-Za-z0-9_]*)\s*:"#,
            capture: 1,
            in: members)
        XCTAssertEqual(letNames, [
            "turnOperationRef", "providerEgressBranchRef", "attemptRef",
            "leaseID", "providerExecutionID", "acceptanceGeneration",
            "requestSequence",
        ])
        XCTAssertEqual(
            matchCount(
                #"\b(?:var|subscript)\b"#,
                in: members),
            0)
        XCTAssertEqual(
            matchCount(
                #"\bstatic\s+let\b"#,
                in: members),
            0)
        XCTAssertEqual(
            matchCount(
                #"return\s+try\s+Self\s*\(\s*validating\s*:"#,
                in: declaration),
            1)
        XCTAssertEqual(
            matchCount(
                #"try\s+self\.init\s*\(\s*validating\s*:"#,
                in: declaration),
            1)
        XCTAssertEqual(
            matchCount(#"\bvalidating\s*:"#, in: declaration),
            2)
        XCTAssertEqual(
            matchCount(
                #"Self\s*\(\s*canonicalSequenceZeroFrom\s*:\s*self\s*\)"#,
                in: declaration),
            1)
        XCTAssertEqual(
            declaration.components(
                separatedBy: "self.requestSequence = 0").count - 1,
            2)
    }

    private func makeOperation(_ seed: UInt64) throws
        -> BASTurnOperationRef
    {
        try BASTurnOperationRef(artifactID: artifactID(seed))
    }

    private func artifactID(_ seed: UInt64) -> BASArtifactID {
        BASArtifactID(
            integrityAlgorithm: "hmac-sha256",
            commitmentKeyEpoch: seed,
            commitmentHex: String(format: "%064llx", seed))
    }

    private func artifactIDScalar(_ seed: UInt64) -> String {
        try! artifactID(seed).storageScalar
    }

    private func frame(_ fields: [String]) -> String {
        BASSovereignCanonicalBytes.lengthPrefixed(fields)
            .base64EncodedString()
    }

    private func providerExecutionBase(
        turnOperationRef: BASTurnOperationRef? = nil,
        providerEgressBranchRef: BASTurnBranchRef? = nil,
        attemptRef: BASArtifactID? = nil,
        leaseID: BASArtifactID? = nil,
        providerExecutionID: String = "provider-execution-40",
        acceptanceGeneration: UInt64 = 44
    ) throws -> BASProviderExecutionRef {
        let root = try turnOperationRef ?? makeOperation(40)
        let branch = try providerEgressBranchRef ?? BASTurnBranchRef(
            turnOperationRef: root,
            kind: .providerEgress,
            ordinal: 3)
        return try BASProviderExecutionRef(
            turnOperationRef: root,
            providerEgressBranchRef: branch,
            attemptRef: attemptRef ?? artifactID(42),
            leaseID: leaseID ?? artifactID(43),
            providerExecutionID: providerExecutionID,
            acceptanceGeneration: acceptanceGeneration)
    }

    private func branchObject(
        rootSeed: UInt64,
        kind: BASTurnBranchKind,
        ordinal: UInt64
    ) throws -> Any {
        let branch = try BASTurnBranchRef(
            turnOperationRef: makeOperation(rootSeed),
            kind: kind,
            ordinal: ordinal)
        return try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(branch))
    }

    private func invalidArtifactIDObject() -> [String: Any] {
        [
            "integrityAlgorithm": "HMAC-SHA256",
            "commitmentKeyEpoch": 1,
            "commitmentHex": "AB",
        ]
    }

    private func lowEntropySource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: packageRoot.appendingPathComponent(
                "Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift"),
            encoding: .utf8)
    }

    private func allProductSwiftSources() throws
        -> [(url: URL, text: String)]
    {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = packageRoot.appendingPathComponent("Sources")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]))
        var sourceURLs: [URL] = []
        for case let url as URL in enumerator
        where url.pathExtension == "swift" {
            sourceURLs.append(url)
        }
        return try sourceURLs
            .sorted { $0.path < $1.path }
            .map { url in
                (url, try String(contentsOf: url, encoding: .utf8))
            }
    }

    private func matches(_ pattern: String, in text: String) -> Bool {
        matchCount(pattern, in: text) > 0
    }

    private func directMemberSurface(of declaration: String) -> String {
        var depth = 0
        var enteredDeclaration = false
        var surface = ""
        for rawLine in declaration.split(
            separator: "\n",
            omittingEmptySubsequences: false)
        {
            let line = String(rawLine)
            let code = line.split(
                separator: "//",
                maxSplits: 1,
                omittingEmptySubsequences: false).first.map(String.init) ?? ""
            if enteredDeclaration, depth == 1 {
                surface += code + "\n"
            }
            let openingCount = code.filter { $0 == "{" }.count
            let closingCount = code.filter { $0 == "}" }.count
            if !enteredDeclaration, openingCount > 0 {
                enteredDeclaration = true
            }
            depth += openingCount - closingCount
        }
        return surface
    }

    private func matchCount(_ pattern: String, in text: String) -> Int {
        matchedStrings(pattern, in: text).count
    }

    private func matchedStrings(
        _ pattern: String,
        in text: String
    ) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators])
        else {
            XCTFail("invalid source-gate regex: \(pattern)")
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else {
                return nil
            }
            return String(text[swiftRange])
        }
    }

    private func matchedCaptures(
        _ pattern: String,
        capture: Int,
        in text: String
    ) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators])
        else {
            XCTFail("invalid source-gate regex: \(pattern)")
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard capture < match.numberOfRanges,
                  match.range(at: capture).location != NSNotFound,
                  let swiftRange = Range(
                    match.range(at: capture),
                    in: text)
            else {
                return nil
            }
            return String(text[swiftRange])
        }
    }

    private func turnPayload(
        workspaceAuthorityArtifactID: BASArtifactID? = nil,
        lineage: [BASArtifactID]? = nil
    ) throws -> BASTurnOperationPayload {
        try BASTurnOperationPayload(
            workspaceAuthorityArtifactID:
                workspaceAuthorityArtifactID ?? artifactID(10),
            workspaceIncarnationArtifactID: artifactID(11),
            attemptRefArtifactID: artifactID(12),
            generationVectorArtifactID: artifactID(13),
            inputArtifactID: artifactID(14),
            budgetLeaseArtifactID: artifactID(15),
            orderedSelectedModelProfileLineageArtifactIDs:
                lineage ?? [artifactID(16), artifactID(17)],
            policyEpoch: 18,
            deletionEpoch: 19,
            restorationEpoch: 20,
            runtimeSchemaEpoch: 21)
    }

    private func budgetLease(
        attemptRefArtifactID: BASArtifactID? = nil,
        bootSessionID: String = "boot-session-1"
    ) throws -> BASBudgetLeasePayload {
        try BASBudgetLeasePayload(
            attemptRefArtifactID:
                attemptRefArtifactID ?? artifactID(22),
            generationVectorArtifactID: artifactID(23),
            authorizationGrantArtifactID: artifactID(24),
            policyEpoch: 25,
            deletionEpoch: 26,
            bootSessionID: bootSessionID,
            tokenCeiling: 2_048,
            byteCeiling: 16_384,
            branchCeiling: 8,
            remandRoundCeiling: 4,
            hopCeiling: 12,
            costMicrounitsCeiling: 50_000,
            monotonicDeadlineNanos: 9_000_000)
    }
}
