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
