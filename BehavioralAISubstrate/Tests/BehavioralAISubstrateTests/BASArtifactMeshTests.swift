import Crypto
import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASArtifactMeshTests: XCTestCase {
    private struct GovernedFixture: BASSchemaVersioned, Hashable {
        static let currentSchemaVersion = "1.0.0"

        let schemaVersion: String
        let value: String

        init(
            schemaVersion: String = Self.currentSchemaVersion,
            value: String
        ) {
            self.schemaVersion = schemaVersion
            self.value = value
        }
    }

    private static let key = SymmetricKey(
        data: Data("artifact-mesh-test-key".utf8))

    private static let bindingID = BASArtifactID(
        integrityAlgorithm: "hmac-sha256",
        commitmentKeyEpoch: 1,
        commitmentHex: String(repeating: "a", count: 64))

    private static let secondID = BASArtifactID(
        integrityAlgorithm: "hmac-sha256",
        commitmentKeyEpoch: 2,
        commitmentHex: String(repeating: "b", count: 64))

    private static let canonicalPayload =
        Data(#"{"schemaVersion":"1.0.0","value":"payload"}"#.utf8)

    private static func identityCore(
        canonicalizationVersion: String =
            "bas-governed-artifact-payload-v1",
        schemaID: String = "test.payload",
        schemaVersion: String = "1.0.0",
        kind: String = "audit-record",
        parentArtifactIDs: [BASArtifactID] = [],
        producerLayerID: BASSemanticLayerID = .sovereign,
        scopeBinding: BASArtifactScopeBinding = .publicArtifact,
        logicalEpoch: UInt64 = 2,
        createdLogicalTime: UInt64 = 3,
        canonicalPayloadBytes: Data = canonicalPayload,
        payloadLength: UInt64? = nil,
        confidentialityLabel: String = "test-confidential",
        provenanceArtifactIDs: [BASArtifactID] = [],
        snapshotRootArtifactID: BASArtifactID? = nil
    ) -> BASArtifactIdentityCore {
        BASArtifactIdentityCore(
            canonicalizationVersion: canonicalizationVersion,
            schemaID: schemaID,
            schemaVersion: schemaVersion,
            kind: kind,
            parentArtifactIDs: parentArtifactIDs,
            producerLayerID: producerLayerID,
            scopeBinding: scopeBinding,
            logicalEpoch: logicalEpoch,
            createdLogicalTime: createdLogicalTime,
            canonicalPayloadBytes: canonicalPayloadBytes,
            payloadLength: payloadLength
                ?? UInt64(canonicalPayloadBytes.count),
            confidentialityLabel: confidentialityLabel,
            provenanceArtifactIDs: provenanceArtifactIDs,
            snapshotRootArtifactID: snapshotRootArtifactID)
    }

    func testDomainPayloadHasNoSelfIdentityOrProof() throws {
        let core = Self.identityCore()
        let encoded = try JSONEncoder().encode(core)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any])
        let keys = Set(object.keys)

        XCTAssertFalse(keys.contains("artifactID"))
        XCTAssertFalse(keys.contains("payloadRef"))
        XCTAssertFalse(keys.contains("signature"))
        XCTAssertFalse(keys.contains("turnID"))
        XCTAssertFalse(keys.contains("branchID"))
    }

    func testArtifactIDStorageScalarFixedVectorRoundTrips() throws {
        let commitment = String(
            repeating: "0123456789abcdef", count: 4)
        let id = BASArtifactID(
            integrityAlgorithm: "hmac-sha256",
            commitmentKeyEpoch: 7,
            commitmentHex: commitment)
        let expected =
            "MjY6YmFzLWFydGlmYWN0LWlkLXN0b3JhZ2UtdjExMTpobWFjLXNoYTI1NjE6NzY0OjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="

        XCTAssertEqual(try id.storageScalar, expected)
        XCTAssertEqual(
            try BASArtifactID(storageScalar: expected), id)
    }

    func testArtifactIDStorageScalarRejectsExactMalformedTable()
        throws
    {
        func scalar(_ fields: [String]) -> String {
            BASSovereignCanonicalBytes.lengthPrefixed(fields)
                .base64EncodedString()
        }
        let validFields = [
            "bas-artifact-id-storage-v1",
            "hmac-sha256",
            "7",
            "0123456789abcdef",
        ]
        let validBytes = BASSovereignCanonicalBytes
            .lengthPrefixed(validFields)
        let malformed = [
            "",
            String(repeating: "A", count: 4_097),
            "%%%",
            "Zh==",
            Data("026:bas-artifact-id-storage-v1".utf8)
                .base64EncodedString(),
            Data(validBytes.dropLast()).base64EncodedString(),
            (validBytes + Data("x".utf8)).base64EncodedString(),
            scalar(Array(validFields.dropLast())),
            scalar(validFields + ["extra"]),
            scalar(["bas-artifact-id-storage-v2"]
                + Array(validFields.dropFirst())),
            scalar([validFields[0], "HMAC-sha256", "7", "aa"]),
            scalar([validFields[0], "hmac-sha256", "07", "aa"]),
            scalar([
                validFields[0], "hmac-sha256",
                "18446744073709551616", "aa",
            ]),
            scalar([validFields[0], "hmac-sha256", "7", "abc"]),
            scalar([validFields[0], "hmac-sha256", "7", "AB"]),
            scalar([validFields[0], "hmac-sha256", "7", "zz"]),
        ]

        XCTAssertEqual(malformed.count, 16)
        for (index, candidate) in malformed.enumerated() {
            XCTAssertThrowsError(
                try BASArtifactID(storageScalar: candidate),
                "malformed case \(index) unexpectedly decoded")
        }
    }

    func testScopeBindingUsesExactTaggedCanonicalJSONVectors()
        throws
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let idJSON =
            #"{"commitmentHex":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","commitmentKeyEpoch":1,"integrityAlgorithm":"hmac-sha256"}"#
        let vectors: [(BASArtifactScopeBinding, String)] = [
            (.publicArtifact, #"{"tag":"public"}"#),
            (
                .workspaceAuthority(Self.bindingID),
                #"{"artifactID":\#(idJSON),"tag":"workspace-authority"}"#
            ),
            (
                .attempt(Self.bindingID),
                #"{"artifactID":\#(idJSON),"tag":"attempt"}"#
            ),
            (
                .durableWarrant(Self.bindingID),
                #"{"artifactID":\#(idJSON),"tag":"durable-warrant"}"#
            ),
        ]

        for (value, expected) in vectors {
            let bytes = try encoder.encode(value)
            XCTAssertEqual(String(decoding: bytes, as: UTF8.self), expected)
            XCTAssertEqual(
                try JSONDecoder().decode(
                    BASArtifactScopeBinding.self, from: bytes),
                value)
        }
    }

    func testScopeBindingRejectsIllegalAndSynthesizedShapes() {
        let illegal = [
            #"{"tag":"public","artifactID":{"integrityAlgorithm":"hmac-sha256","commitmentKeyEpoch":1,"commitmentHex":"aa"}}"#,
            #"{"tag":"workspace-authority"}"#,
            #"{"tag":"attempt"}"#,
            #"{"tag":"durable-warrant"}"#,
            #"{"publicArtifact":{}}"#,
            #"{"attempt":{"_0":{"integrityAlgorithm":"hmac-sha256","commitmentKeyEpoch":1,"commitmentHex":"aa"}}}"#,
        ]

        for json in illegal {
            XCTAssertThrowsError(
                try JSONDecoder().decode(
                    BASArtifactScopeBinding.self,
                    from: Data(json.utf8)))
        }
    }

    func testCanonicalIdentityBytesHaveFourExactScopeVectors()
        throws
    {
        let expected: [(BASArtifactScopeBinding, String)] = [
            (.publicArtifact, "MjQ6YmFzLWFydGlmYWN0LWlkZW50aXR5LXYxMzI6YmFzLWdvdmVybmVkLWFydGlmYWN0LXBheWxvYWQtdjExMjp0ZXN0LnBheWxvYWQ1OjEuMC4wMTI6YXVkaXQtcmVjb3JkMTowMzpMMTQ2OnB1YmxpYzE6MjE6MzYwOmV5SnpZMmhsYldGV1pYSnphVzl1SWpvaU1TNHdMakFpTENKMllXeDFaU0k2SW5CaGVXeHZZV1FpZlE9PTI6NDMxNzp0ZXN0LWNvbmZpZGVudGlhbDE6MDE6MA=="),
            (.workspaceAuthority(Self.bindingID), "MjQ6YmFzLWFydGlmYWN0LWlkZW50aXR5LXYxMzI6YmFzLWdvdmVybmVkLWFydGlmYWN0LXBheWxvYWQtdjExMjp0ZXN0LnBheWxvYWQ1OjEuMC4wMTI6YXVkaXQtcmVjb3JkMTowMzpMMTQxOTp3b3Jrc3BhY2UtYXV0aG9yaXR5MTUyOk1qWTZZbUZ6TFdGeWRHbG1ZV04wTFdsa0xYTjBiM0poWjJVdGRqRXhNVHBvYldGakxYTm9ZVEkxTmpFNk1UWTBPbUZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0U9MToyMTozNjA6ZXlKelkyaGxiV0ZXWlhKemFXOXVJam9pTVM0d0xqQWlMQ0oyWVd4MVpTSTZJbkJoZVd4dllXUWlmUT09Mjo0MzE3OnRlc3QtY29uZmlkZW50aWFsMTowMTow"),
            (.attempt(Self.bindingID), "MjQ6YmFzLWFydGlmYWN0LWlkZW50aXR5LXYxMzI6YmFzLWdvdmVybmVkLWFydGlmYWN0LXBheWxvYWQtdjExMjp0ZXN0LnBheWxvYWQ1OjEuMC4wMTI6YXVkaXQtcmVjb3JkMTowMzpMMTQ3OmF0dGVtcHQxNTI6TWpZNlltRnpMV0Z5ZEdsbVlXTjBMV2xrTFhOMGIzSmhaMlV0ZGpFeE1UcG9iV0ZqTFhOb1lUSTFOakU2TVRZME9tRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRT0xOjIxOjM2MDpleUp6WTJobGJXRldaWEp6YVc5dUlqb2lNUzR3TGpBaUxDSjJZV3gxWlNJNkluQmhlV3h2WVdRaWZRPT0yOjQzMTc6dGVzdC1jb25maWRlbnRpYWwxOjAxOjA="),
            (.durableWarrant(Self.bindingID), "MjQ6YmFzLWFydGlmYWN0LWlkZW50aXR5LXYxMzI6YmFzLWdvdmVybmVkLWFydGlmYWN0LXBheWxvYWQtdjExMjp0ZXN0LnBheWxvYWQ1OjEuMC4wMTI6YXVkaXQtcmVjb3JkMTowMzpMMTQxNTpkdXJhYmxlLXdhcnJhbnQxNTI6TWpZNlltRnpMV0Z5ZEdsbVlXTjBMV2xrTFhOMGIzSmhaMlV0ZGpFeE1UcG9iV0ZqTFhOb1lUSTFOakU2TVRZME9tRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRmhZV0ZoWVdGaFlXRT0xOjIxOjM2MDpleUp6WTJobGJXRldaWEp6YVc5dUlqb2lNUzR3TGpBaUxDSjJZV3gxWlNJNkluQmhlV3h2WVdRaWZRPT0yOjQzMTc6dGVzdC1jb25maWRlbnRpYWwxOjAxOjA="),
        ]

        XCTAssertEqual(expected.count, 4)
        for (scope, vector) in expected {
            XCTAssertEqual(
                try BASArtifactMesh.canonicalIdentityBytes(
                    for: Self.identityCore(scopeBinding: scope))
                    .base64EncodedString(),
                vector)
        }
    }

    func testIdentityMutationAndSemanticOrderingChangeKeyedID()
        throws
    {
        let original = Self.identityCore(
            parentArtifactIDs: [Self.bindingID, Self.secondID],
            provenanceArtifactIDs: [Self.bindingID, Self.secondID],
            snapshotRootArtifactID: Self.bindingID)
        func variant(
            canonicalizationVersion: String? = nil,
            schemaID: String? = nil,
            kind: String? = nil,
            parentArtifactIDs: [BASArtifactID]? = nil,
            producerLayerID: BASSemanticLayerID? = nil,
            scopeBinding: BASArtifactScopeBinding? = nil,
            logicalEpoch: UInt64? = nil,
            createdLogicalTime: UInt64? = nil,
            canonicalPayloadBytes: Data? = nil,
            payloadLength: UInt64? = nil,
            confidentialityLabel: String? = nil,
            provenanceArtifactIDs: [BASArtifactID]? = nil,
            snapshotRootArtifactID: BASArtifactID? = nil
        ) -> BASArtifactIdentityCore {
            let payload = canonicalPayloadBytes
                ?? original.canonicalPayloadBytes
            return Self.identityCore(
                canonicalizationVersion: canonicalizationVersion
                    ?? original.canonicalizationVersion,
                schemaID: schemaID ?? original.schemaID,
                schemaVersion: original.schemaVersion,
                kind: kind ?? original.kind,
                parentArtifactIDs: parentArtifactIDs
                    ?? original.parentArtifactIDs,
                producerLayerID: producerLayerID
                    ?? original.producerLayerID,
                scopeBinding: scopeBinding ?? original.scopeBinding,
                logicalEpoch: logicalEpoch ?? original.logicalEpoch,
                createdLogicalTime: createdLogicalTime
                    ?? original.createdLogicalTime,
                canonicalPayloadBytes: payload,
                payloadLength: payloadLength ?? UInt64(payload.count),
                confidentialityLabel: confidentialityLabel
                    ?? original.confidentialityLabel,
                provenanceArtifactIDs: provenanceArtifactIDs
                    ?? original.provenanceArtifactIDs,
                snapshotRootArtifactID: snapshotRootArtifactID
                    ?? original.snapshotRootArtifactID)
        }
        let baseline = try BASArtifactMesh.artifactID(
            for: original,
            commitmentKey: Self.key,
            commitmentKeyEpoch: 7)
        let variants = [
            variant(canonicalizationVersion: "other-v1"),
            variant(schemaID: "other.payload"),
            variant(kind: "audit-other"),
            variant(parentArtifactIDs: [Self.bindingID]),
            variant(producerLayerID: .leaseLife),
            variant(scopeBinding: .attempt(Self.bindingID)),
            variant(logicalEpoch: 4),
            variant(createdLogicalTime: 5),
            variant(
                canonicalPayloadBytes: Data(
                    #"{"schemaVersion":"1.0.0","value":"payloae"}"#.utf8)),
            variant(confidentialityLabel: "other-label"),
            variant(provenanceArtifactIDs: [Self.bindingID]),
            variant(snapshotRootArtifactID: Self.secondID),
            variant(
                parentArtifactIDs: [Self.secondID, Self.bindingID]),
            variant(
                provenanceArtifactIDs: [Self.secondID, Self.bindingID]),
        ]

        for variant in variants {
            XCTAssertNotEqual(
                try BASArtifactMesh.artifactID(
                    for: variant,
                    commitmentKey: Self.key,
                    commitmentKeyEpoch: 7),
                baseline)
        }
        XCTAssertThrowsError(
            try BASArtifactMesh.canonicalIdentityBytes(
                for: variant(payloadLength: 999)))
        let schemaOnlyMutation = BASArtifactIdentityCore(
            canonicalizationVersion: original.canonicalizationVersion,
            schemaID: original.schemaID,
            schemaVersion: "1.0.1",
            kind: original.kind,
            parentArtifactIDs: original.parentArtifactIDs,
            producerLayerID: original.producerLayerID,
            scopeBinding: original.scopeBinding,
            logicalEpoch: original.logicalEpoch,
            createdLogicalTime: original.createdLogicalTime,
            canonicalPayloadBytes: original.canonicalPayloadBytes,
            payloadLength: original.payloadLength,
            confidentialityLabel: original.confidentialityLabel,
            provenanceArtifactIDs: original.provenanceArtifactIDs,
            snapshotRootArtifactID: original.snapshotRootArtifactID)
        XCTAssertThrowsError(
            try BASArtifactMesh.canonicalIdentityBytes(
                for: schemaOnlyMutation))
    }

    func testAttemptPayloadRejectsRawTurnAndBranchKeys() {
        for key in ["turnID", "branchID"] {
            let payload = Data(
                "{\"schemaVersion\":\"1.0.0\",\"\(key)\":\"raw\"}"
                    .utf8)
            XCTAssertThrowsError(
                try BASArtifactMesh.canonicalIdentityBytes(
                    for: Self.identityCore(
                        scopeBinding: .attempt(Self.bindingID),
                        canonicalPayloadBytes: payload)))
        }
    }

    func testGovernedPayloadCodecGatesVersionBeforeTypedDecode()
        throws
    {
        let current = GovernedFixture(value: "hello")
        let bytes = try BASGovernedArtifactPayloadCodec
            .canonicalBytes(for: current)
        XCTAssertEqual(
            String(decoding: bytes, as: UTF8.self),
            #"{"schemaVersion":"1.0.0","value":"hello"}"#)
        XCTAssertEqual(
            try BASGovernedArtifactPayloadCodec.decodeCurrent(
                GovernedFixture.self, from: bytes),
            current)

        XCTAssertThrowsError(
            try BASGovernedArtifactPayloadCodec.canonicalBytes(
                for: GovernedFixture(
                    schemaVersion: "2.0.0", value: "future")))
        for malformed in [
            #"{"value":"missing"}"#,
            #"{"schemaVersion":"2.0.0","value":"future"}"#,
            #"{ "schemaVersion":"1.0.0", "value":"noncanonical" }"#,
            #"{"value":"reordered","schemaVersion":"1.0.0"}"#,
            #"{"schemaVersion":"1.0.0","unknown":1,"value":"x"}"#,
            #"[{"schemaVersion":"1.0.0","value":"array"}]"#,
        ] {
            XCTAssertThrowsError(
                try BASGovernedArtifactPayloadCodec.decodeCurrent(
                    GovernedFixture.self,
                    from: Data(malformed.utf8)))
        }
    }

    func testRelocationCannotChangeIdentity() throws {
        let id = try BASArtifactMesh.artifactID(
            for: Self.identityCore(),
            commitmentKey: Self.key,
            commitmentKeyEpoch: 7)
        let first = BASArtifactStorageEnvelope(
            artifactID: id,
            payloadRef: "random-a",
            storedLength: 43,
            storageEncoding: nil,
            compression: nil,
            encryptionKeyID: nil,
            encryptionMetadata: [])
        let second = BASArtifactStorageEnvelope(
            artifactID: id,
            payloadRef: "random-b",
            storedLength: 43,
            storageEncoding: "opaque",
            compression: "none",
            encryptionKeyID: "key-1",
            encryptionMetadata: [
                BASArtifactStorageMetadataEntry(
                    key: "zone", value: "test"),
            ])

        XCTAssertEqual(first.artifactID, id)
        XCTAssertEqual(second.artifactID, id)
    }

    func testVerifyRejectsTamperedIdentity() throws {
        let core = Self.identityCore()
        let id = try BASArtifactMesh.artifactID(
            for: core,
            commitmentKey: Self.key,
            commitmentKeyEpoch: 7)
        XCTAssertNoThrow(
            try BASArtifactMesh.verify(
                id, for: core, commitmentKey: Self.key))
        XCTAssertThrowsError(
            try BASArtifactMesh.verify(
                id,
                for: Self.identityCore(kind: "audit-tampered"),
                commitmentKey: Self.key))
    }

    func testRecordVerificationDoesNotMakeStoragePartOfIdentity()
        throws
    {
        let core = Self.identityCore()
        let id = try BASArtifactMesh.artifactID(
            for: core,
            commitmentKey: Self.key,
            commitmentKeyEpoch: 7)
        let relocated = BASArtifactMeshRecord(
            artifactID: id,
            identityCore: core,
            storage: BASArtifactStorageEnvelope(
                artifactID: id,
                payloadRef: "compressed-ciphertext-ref",
                storedLength: 17,
                storageEncoding: "opaque-v1",
                compression: "zstd",
                encryptionKeyID: "key-9",
                encryptionMetadata: [
                    BASArtifactStorageMetadataEntry(
                        key: "nonce", value: "fixture"),
                ]))

        XCTAssertNoThrow(
            try BASArtifactMesh.verify(
                relocated, commitmentKey: Self.key))
    }

    func testAlternateCanonicalizationStillValidatesPayloadSchema() {
        XCTAssertThrowsError(
            try BASArtifactMesh.canonicalIdentityBytes(
                for: Self.identityCore(
                    canonicalizationVersion: "other-v1",
                    canonicalPayloadBytes: Data(
                        #"{ "schemaVersion":"1.0.0", "value":"payload" }"#
                            .utf8))))
        XCTAssertThrowsError(
            try BASArtifactMesh.canonicalIdentityBytes(
                for: Self.identityCore(
                    canonicalizationVersion: "other-v1",
                    schemaVersion: "2.0.0")))
    }

    func testHeadKeyLegacyProjectionIsCanonicalAndBounded()
        throws
    {
        let key = BASArtifactHeadKey(
            scope: .attempt(Self.bindingID),
            purpose: .semanticSnapshot)
        let projection = try key.canonicalLegacyProjection()

        XCTAssertEqual(
            try BASArtifactHeadKey(
                validatingCanonicalLegacyProjection: projection),
            key)
        XCTAssertThrowsError(
            try BASArtifactHeadKey(
                validatingCanonicalLegacyProjection:
                    projection.replacingOccurrences(
                        of: "=", with: "")))
        XCTAssertThrowsError(
            try BASArtifactHeadKey(
                validatingCanonicalLegacyProjection:
                    String(repeating: "A", count: 4_097)))

        let workspaceKey = BASArtifactHeadKey(
            scope: .workspaceAuthority(Self.secondID),
            purpose: .workspaceRoot)
        XCTAssertEqual(
            try BASArtifactHeadKey(
                validatingCanonicalLegacyProjection:
                    workspaceKey.canonicalLegacyProjection()),
            workspaceKey)

        func makeProjection(_ fields: [String]) -> String {
            BASSovereignCanonicalBytes.lengthPrefixed(fields)
                .base64EncodedString()
        }
        let scalar = try Self.bindingID.storageScalar
        let malformed = [
            makeProjection([
                "bas-artifact-head-key-v2", "attempt", scalar,
                "semanticSnapshot",
            ]),
            makeProjection([
                "bas-artifact-head-key-v1", "public", scalar,
                "semanticSnapshot",
            ]),
            makeProjection([
                "bas-artifact-head-key-v1", "attempt", scalar,
                "callerDefined",
            ]),
            makeProjection([
                "bas-artifact-head-key-v1", "attempt", "bad",
                "semanticSnapshot",
            ]),
            makeProjection([
                "bas-artifact-head-key-v1", "attempt", scalar,
                "semanticSnapshot", "trailing",
            ]),
        ]
        for candidate in malformed {
            XCTAssertThrowsError(
                try BASArtifactHeadKey(
                    validatingCanonicalLegacyProjection: candidate))
        }
    }

    func testDurableWarrantScopeRejectsExecutableShortcut() {
        for kind in ["executable-command", "executable-audit"] {
            XCTAssertThrowsError(
                try BASArtifactMesh.canonicalIdentityBytes(
                    for: Self.identityCore(
                        kind: kind,
                        scopeBinding: .durableWarrant(Self.bindingID))))
        }
    }

    func testMeshRecordIsCurrentGovernedSchema() throws {
        let id = try BASArtifactMesh.artifactID(
            for: Self.identityCore(),
            commitmentKey: Self.key,
            commitmentKeyEpoch: 7)
        let storage = BASArtifactStorageEnvelope(
            artifactID: id,
            payloadRef: "random-record",
            storedLength: 43,
            storageEncoding: nil,
            compression: nil,
            encryptionKeyID: nil,
            encryptionMetadata: [])
        let record = BASArtifactMeshRecord(
            artifactID: id,
            identityCore: Self.identityCore(),
            storage: storage)

        XCTAssertEqual(
            BASArtifactMeshRecord.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(record.schemaVersion, "1.0.0")
        XCTAssertEqual(record.canonicalPayloadBytes, Self.canonicalPayload)
        XCTAssertEqual(
            try BASGovernedArtifactPayloadCodec.decodeCurrent(
                BASArtifactMeshRecord.self,
                from: BASGovernedArtifactPayloadCodec
                    .canonicalBytes(for: record)),
            record)
    }

    func testMeshRecordWireHasSeparateBoundFromDomainPayload()
        throws
    {
        let prefix = Data(
            #"{"schemaVersion":"1.0.0","value":""#.utf8)
        let suffix = Data(#""}"#.utf8)
        let payload = prefix
            + Data(repeating: 97, count: 12_700_000)
            + suffix
        XCTAssertLessThan(
            payload.count,
            BASCanonicalPayloadValidator.maximumPayloadBytes)
        let core = Self.identityCore(
            canonicalPayloadBytes: payload)
        let storage = BASArtifactStorageEnvelope(
            artifactID: Self.bindingID,
            payloadRef: "large-record-fixture",
            storedLength: UInt64(payload.count),
            storageEncoding: nil,
            compression: nil,
            encryptionKeyID: nil,
            encryptionMetadata: [])
        let record = BASArtifactMeshRecord(
            artifactID: Self.bindingID,
            identityCore: core,
            storage: storage)

        let bytes = try BASGovernedArtifactPayloadCodec
            .canonicalBytes(for: record)
        XCTAssertGreaterThan(
            bytes.count,
            BASCanonicalPayloadValidator.maximumPayloadBytes)
        XCTAssertEqual(
            try BASGovernedArtifactPayloadCodec.decodeCurrent(
                BASArtifactMeshRecord.self, from: bytes),
            record)
    }
}
