import Crypto
import Foundation
import SQLite3
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASArtifactStoreTests: XCTestCase {
    private enum FixtureError: Error, Sendable {
        case missingKey(UInt64)
    }

    private enum PutOutcome: Sendable {
        case success(BASArtifactStoreReceipt)
        case storageFailure(BASArtifactSQLiteStore.StorageError)
        case unexpectedFailure(String)
    }

    private static let keyData = Data(
        "artifact-store-test-key".utf8)

    private static let attemptID = BASArtifactID(
        integrityAlgorithm: "hmac-sha256",
        commitmentKeyEpoch: 1,
        commitmentHex: String(repeating: "c", count: 64))

    private static let otherAttemptID = BASArtifactID(
        integrityAlgorithm: "hmac-sha256",
        commitmentKeyEpoch: 1,
        commitmentHex: String(repeating: "d", count: 64))

    private static func temporaryDatabaseURL(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas-artifact-store-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        return directory.appendingPathComponent("artifacts.sqlite")
    }

    private static func makeStore(
        at url: URL,
        keyData: Data = keyData,
        activeEpoch: UInt64 = 7,
        availableEpoch: UInt64? = 7
    ) throws -> BASArtifactSQLiteStore {
        try BASArtifactSQLiteStore(
            databaseURL: url,
            activeCommitmentKeyEpoch: activeEpoch,
            commitmentKeyResolver: { epoch in
                guard epoch == availableEpoch else {
                    throw FixtureError.missingKey(epoch)
                }
                return SymmetricKey(data: keyData)
            })
    }

    private static func core(
        value: String = "payload",
        kind: String = "test-record",
        scope: BASArtifactScopeBinding = .attempt(attemptID),
        parentArtifactIDs: [BASArtifactID] = [],
        provenanceArtifactIDs: [BASArtifactID] = [],
        logicalEpoch: UInt64 = 1,
        logicalTime: UInt64 = 2
    ) -> BASArtifactIdentityCore {
        let payload = Data(
            "{\"schemaVersion\":\"1.0.0\",\"value\":\"\(value)\"}"
                .utf8)
        return BASArtifactIdentityCore(
            canonicalizationVersion:
                "bas-governed-artifact-payload-v1",
            schemaID: "test.store-payload",
            schemaVersion: "1.0.0",
            kind: kind,
            parentArtifactIDs: parentArtifactIDs,
            producerLayerID: .sovereign,
            scopeBinding: scope,
            logicalEpoch: logicalEpoch,
            createdLogicalTime: logicalTime,
            canonicalPayloadBytes: payload,
            payloadLength: UInt64(payload.count),
            confidentialityLabel: "test-confidential",
            provenanceArtifactIDs: provenanceArtifactIDs,
            snapshotRootArtifactID: nil)
    }

    private static func attestation(
        targeting target: BASArtifactID
    ) -> BASArtifactAttestationPayload {
        BASArtifactAttestationPayload(
            targetArtifactID: target,
            attestationPurpose: "test-proof",
            producerReceiptArtifactID: nil,
            usageReceiptArtifactIDs: [],
            proofSuite: "test-hmac",
            keyID: "test-key",
            keyEpoch: 7,
            custodyClass: "test",
            signedStatementDigest: String(repeating: "e", count: 64),
            proofBytes: Data("proof".utf8),
            logicalTime: 3,
            policyEpoch: 1)
    }

    private static func attestationCore(
        targeting target: BASArtifactID
    ) throws -> BASArtifactIdentityCore {
        let payload = try BASGovernedArtifactPayloadCodec
            .canonicalBytes(for: attestation(targeting: target))
        return BASArtifactIdentityCore(
            canonicalizationVersion:
                "bas-governed-artifact-payload-v1",
            schemaID: "bas.artifact-attestation",
            schemaVersion:
                BASArtifactAttestationPayload.currentSchemaVersion,
            kind: "artifact-attestation",
            parentArtifactIDs: [target],
            producerLayerID: .sovereign,
            scopeBinding: .attempt(attemptID),
            logicalEpoch: 1,
            createdLogicalTime: 3,
            canonicalPayloadBytes: payload,
            payloadLength: UInt64(payload.count),
            confidentialityLabel: "test-confidential",
            provenanceArtifactIDs: [],
            snapshotRootArtifactID: nil)
    }

    private static func capturePut(
        _ operation: @escaping @Sendable () async throws
            -> BASArtifactStoreReceipt
    ) async -> PutOutcome {
        do {
            return .success(try await operation())
        } catch let error as BASArtifactSQLiteStore.StorageError {
            return .storageFailure(error)
        } catch {
            return .unexpectedFailure(String(describing: error))
        }
    }

    func testAttestationUsesTheOrdinaryPutPath() async throws {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let target = try await store.put(
            identityCore: Self.core(), headUpdate: nil)
        let attestationCore = try Self.attestationCore(
            targeting: target.body.artifactID)
        let child = try await store.put(
            identityCore: attestationCore, headUpdate: nil)

        let indexed = try await store.attestationArtifactIDs(
            targeting: target.body.artifactID)
        let reopenedChild = try await store.read(child.body.artifactID)

        XCTAssertEqual(indexed.items, [child.body.artifactID])
        XCTAssertEqual(reopenedChild.identityCore, attestationCore)
    }

    func testAttestationQueryReopensItsTarget() async throws {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let target = try await store.put(
            identityCore: Self.core(), headUpdate: nil)
        let childCore = try Self.attestationCore(
            targeting: target.body.artifactID)
        _ = try await store.put(
            identityCore: childCore, headUpdate: nil)
        let targetScalar = try target.body.artifactID.storageScalar
        try Self.runRawSQL(
            at: url,
            sql: """
                PRAGMA foreign_keys=OFF;
                DELETE FROM artifact_mesh_records
                WHERE artifact_id = '\(targetScalar)';
                """)

        await XCTAssertThrowsErrorAsync {
            _ = try await store.attestationArtifactIDs(
                targeting: target.body.artifactID)
        }
    }

    func testIdenticalPutIsIdempotentAndRelocationIsNotIdentity()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let core = Self.core()

        let first = try await store.put(
            identityCore: core, headUpdate: nil)
        let second = try await store.put(
            identityCore: core, headUpdate: nil)
        let reopened = try await store.read(first.body.artifactID)

        XCTAssertEqual(first.body.artifactID, second.body.artifactID)
        XCTAssertEqual(first.body.storage, second.body.storage)
        XCTAssertEqual(reopened.identityCore, core)
    }

    func testTamperedPayloadAndSameIDConflictingBytesFailClosed()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let originalCore = Self.core()
        let receipt: BASArtifactStoreReceipt
        do {
            let store = try Self.makeStore(at: url)
            receipt = try await store.put(
                identityCore: originalCore, headUpdate: nil)
        }

        let tamperedCore = Self.core(value: "payloae")
        XCTAssertEqual(
            tamperedCore.payloadLength, originalCore.payloadLength)
        let tamperedRecord = BASArtifactMeshRecord(
            artifactID: receipt.body.artifactID,
            identityCore: tamperedCore,
            storage: receipt.body.storage)
        let tamperedBytes = try BASGovernedArtifactPayloadCodec
            .canonicalBytes(for: tamperedRecord)
        try Self.replaceRecordBytes(
            at: url,
            artifactID: receipt.body.artifactID,
            bytes: tamperedBytes)

        let reopened = try Self.makeStore(at: url)
        await XCTAssertThrowsErrorAsync {
            _ = try await reopened.read(receipt.body.artifactID)
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await reopened.put(
                identityCore: originalCore, headUpdate: nil)
        }
    }

    func testSQLiteTextIdentityAndEpochAreCanonicalAndTamperFails()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let receipt = try await store.put(
            identityCore: Self.core(), headUpdate: nil)
        let scalar = try receipt.body.artifactID.storageScalar

        XCTAssertEqual(
            try Self.rawText(
                at: url,
                sql: """
                    SELECT artifact_id || '|' || commitment_key_epoch
                    FROM artifact_mesh_records;
                """),
            "\(scalar)|7")

        let payloadRef = receipt.body.storage.payloadRef
        let nulPayloadRefHex = Self.hex(
            Data(payloadRef.utf8) + Data([0, 120]))
        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET payload_ref = CAST(X'\(nulPayloadRefHex)' AS TEXT)
                WHERE artifact_id = '\(scalar)';
                """)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.read(receipt.body.artifactID)
        }
        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET payload_ref = '\(payloadRef)'
                WHERE artifact_id = '\(scalar)';
                """)

        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET commitment_key_epoch = '07'
                WHERE artifact_id = '\(scalar)';
                """)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.read(receipt.body.artifactID)
        }

        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET commitment_key_epoch = CAST(X'370078' AS TEXT)
                WHERE artifact_id = '\(scalar)';
                """)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.read(receipt.body.artifactID)
        }
    }

    func testOversizedPayloadRefFailsBeforeTextMaterialization()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let receipt = try await store.put(
            identityCore: Self.core(), headUpdate: nil)
        let scalar = try receipt.body.artifactID.storageScalar
        XCTAssertEqual(receipt.body.storage.payloadRef.utf8.count, 88)

        let oversized = String(repeating: "p", count: 89)
        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET payload_ref = '\(oversized)'
                WHERE artifact_id = '\(scalar)';
                """)

        await Self.assertColumnTextBoundFailure(
            maximumBytes: 88,
            actualBytes: oversized.utf8.count)
        {
            _ = try await store.read(receipt.body.artifactID)
        }
    }

    func testOversizedCommitmentEpochFailsBeforeTextMaterialization()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let receipt = try await store.put(
            identityCore: Self.core(), headUpdate: nil)
        let scalar = try receipt.body.artifactID.storageScalar
        let oversized = String(repeating: "9", count: 21)

        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET commitment_key_epoch = '\(oversized)'
                WHERE artifact_id = '\(scalar)';
                """)

        await Self.assertColumnTextBoundFailure(
            maximumBytes: 20,
            actualBytes: oversized.utf8.count)
        {
            _ = try await store.read(receipt.body.artifactID)
        }
    }

    func testOversizedHeadRevisionFailsBeforeTextMaterialization()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let key = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .projectionCheckpoint)
        let core = Self.core(value: "head-revision-bound")
        let artifactID = try BASArtifactMesh.artifactID(
            for: core,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        _ = try await store.put(
            identityCore: core,
            headUpdate: BASArtifactHeadCAS(
                key: key,
                expected: nil,
                replacementArtifactID: artifactID))
        let scopeScalar = try Self.attemptID.storageScalar
        let oversized = String(repeating: "9", count: 21)

        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_heads
                SET revision = '\(oversized)'
                WHERE scope_tag = 'attempt'
                  AND scope_artifact_id = '\(scopeScalar)'
                  AND purpose = 'projectionCheckpoint';
                """)

        await Self.assertColumnTextBoundFailure(
            maximumBytes: 20,
            actualBytes: oversized.utf8.count)
        {
            _ = try await store.head(key)
        }
    }

    func testOversizedHeadArtifactIDFailsBeforeTextMaterialization()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let key = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .semanticSnapshot)
        let core = Self.core(value: "head-artifact-bound")
        let artifactID = try BASArtifactMesh.artifactID(
            for: core,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        _ = try await store.put(
            identityCore: core,
            headUpdate: BASArtifactHeadCAS(
                key: key,
                expected: nil,
                replacementArtifactID: artifactID))
        let scopeScalar = try Self.attemptID.storageScalar
        let oversized = String(repeating: "A", count: 4_097)

        try Self.runRawSQL(
            at: url,
            sql: """
                PRAGMA foreign_keys=OFF;
                UPDATE artifact_mesh_heads
                SET artifact_id = '\(oversized)'
                WHERE scope_tag = 'attempt'
                  AND scope_artifact_id = '\(scopeScalar)'
                  AND purpose = 'semanticSnapshot';
                """)

        await Self.assertColumnTextBoundFailure(
            maximumBytes: 4_096,
            actualBytes: oversized.utf8.count)
        {
            _ = try await store.head(key)
        }
    }

    func testReopenRevalidatesIdentityAndKeyEpoch() async throws {
        let url = try Self.temporaryDatabaseURL()
        let artifactID: BASArtifactID
        do {
            let store = try Self.makeStore(at: url)
            artifactID = try await store.put(
                identityCore: Self.core(), headUpdate: nil)
                .body.artifactID
        }

        do {
            let reopened = try Self.makeStore(at: url)
            let record = try await reopened.read(artifactID)
            XCTAssertEqual(record.artifactID, artifactID)
        }
        do {
            let missingEpoch = try Self.makeStore(
                at: url, availableEpoch: nil)
            await XCTAssertThrowsErrorAsync {
                _ = try await missingEpoch.read(artifactID)
            }
        }
        do {
            let wrongKey = try Self.makeStore(
                at: url, keyData: Data("wrong-key-material".utf8))
            await XCTAssertThrowsErrorAsync {
                _ = try await wrongKey.read(artifactID)
            }
        }
    }

    func testConcurrentCASWithSameExpectationHasOneWinner()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let headKey = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .attemptRoot)
        let initialCore = Self.core(value: "initial")
        let initialID = try BASArtifactMesh.artifactID(
            for: initialCore,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        let initial = try await store.put(
            identityCore: initialCore,
            headUpdate: BASArtifactHeadCAS(
                key: headKey,
                expected: nil,
                replacementArtifactID: initialID))
        let expected = try XCTUnwrap(initial.body.head)
        XCTAssertEqual(expected.revision, 0)
        let secondStore = try Self.makeStore(at: url)

        let firstCore = Self.core(value: "first")
        let secondCore = Self.core(value: "second")
        let firstID = try BASArtifactMesh.artifactID(
            for: firstCore,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        let secondID = try BASArtifactMesh.artifactID(
            for: secondCore,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)

        async let first = Self.capturePut {
            try await store.put(
                identityCore: firstCore,
                headUpdate: BASArtifactHeadCAS(
                    key: headKey,
                    expected: expected,
                    replacementArtifactID: firstID))
        }
        async let second = Self.capturePut {
            try await secondStore.put(
                identityCore: secondCore,
                headUpdate: BASArtifactHeadCAS(
                    key: headKey,
                    expected: expected,
                    replacementArtifactID: secondID))
        }
        let outcomes = await [first, second]
        let successCount = outcomes.reduce(into: 0) { count, outcome in
            if case .success = outcome { count += 1 }
        }
        let conflictCount = outcomes.reduce(into: 0) { count, outcome in
            if case .storageFailure(.headCASConflict) = outcome {
                count += 1
            }
        }
        let unexpectedCount = outcomes.reduce(into: 0) { count, outcome in
            switch outcome {
            case .success, .storageFailure(.headCASConflict):
                break
            case .storageFailure, .unexpectedFailure:
                count += 1
            }
        }
        XCTAssertEqual(successCount, 1)
        XCTAssertEqual(conflictCount, 1)
        XCTAssertEqual(unexpectedCount, 0)

        let persistedHead = try await store.head(headKey)
        let finalHead = try XCTUnwrap(persistedHead)
        XCTAssertEqual(finalHead.revision, 1)
        XCTAssertTrue([firstID, secondID].contains(finalHead.artifactID))

        var persistedReplacementCount = 0
        for id in [firstID, secondID] {
            if (try? await store.read(id)) != nil {
                persistedReplacementCount += 1
            }
        }
        XCTAssertEqual(persistedReplacementCount, 1)
    }

    func testCASRejectsCrossScopeReplacementAndStaleExpected()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let key = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .semanticSnapshot)
        let foreign = Self.core(
            value: "foreign",
            scope: .attempt(Self.otherAttemptID))
        let foreignID = try BASArtifactMesh.artifactID(
            for: foreign,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)

        await XCTAssertThrowsErrorAsync {
            _ = try await store.put(
                identityCore: foreign,
                headUpdate: BASArtifactHeadCAS(
                    key: key,
                    expected: nil,
                    replacementArtifactID: foreignID))
        }

        let local = Self.core(value: "local")
        let localID = try BASArtifactMesh.artifactID(
            for: local,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        let created = try await store.put(
            identityCore: local,
            headUpdate: BASArtifactHeadCAS(
                key: key,
                expected: nil,
                replacementArtifactID: localID))
        await XCTAssertThrowsErrorAsync {
            _ = try await store.put(
                identityCore: local,
                headUpdate: BASArtifactHeadCAS(
                    key: key,
                    expected: nil,
                    replacementArtifactID: localID))
        }
        XCTAssertEqual(created.body.head?.revision, 0)

        let workspaceIdentity = Self.core(
            value: "workspace",
            scope: .workspaceAuthority(Self.attemptID))
        let workspaceID = try BASArtifactMesh.artifactID(
            for: workspaceIdentity,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.put(
                identityCore: workspaceIdentity,
                headUpdate: BASArtifactHeadCAS(
                    key: key,
                    expected: created.body.head,
                    replacementArtifactID: workspaceID))
        }
    }

    func testCASRevisionOverflowRollsBackReplacement() async throws {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let key = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .projectionCheckpoint)
        let initialCore = Self.core(value: "overflow-initial")
        let initialID = try BASArtifactMesh.artifactID(
            for: initialCore,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        _ = try await store.put(
            identityCore: initialCore,
            headUpdate: BASArtifactHeadCAS(
                key: key,
                expected: nil,
                replacementArtifactID: initialID))
        let scopeScalar = try Self.attemptID.storageScalar
        try Self.runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_heads
                SET revision = '18446744073709551615'
                WHERE scope_tag = 'attempt'
                  AND scope_artifact_id = '\(scopeScalar)'
                  AND purpose = 'projectionCheckpoint';
                """)
        let persistedAtMaximum = try await store.head(key)
        let expected = try XCTUnwrap(persistedAtMaximum)
        XCTAssertEqual(expected.revision, UInt64.max)

        let replacementCore = Self.core(value: "overflow-next")
        let replacementID = try BASArtifactMesh.artifactID(
            for: replacementCore,
            commitmentKey: SymmetricKey(data: Self.keyData),
            commitmentKeyEpoch: 7)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.put(
                identityCore: replacementCore,
                headUpdate: BASArtifactHeadCAS(
                    key: key,
                    expected: expected,
                    replacementArtifactID: replacementID))
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await store.read(replacementID)
        }
        let persistedUnchanged = try await store.head(key)
        let unchanged = try XCTUnwrap(persistedUnchanged)
        XCTAssertEqual(unchanged, expected)
    }

    func testCASReopensAndVerifiesCurrentHeadBeforeUpdate()
        async throws
    {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let key = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .projectionCheckpoint)
        let currentCore = Self.core(value: "current-good")
        let commitmentKey = SymmetricKey(data: Self.keyData)
        let currentID = try BASArtifactMesh.artifactID(
            for: currentCore,
            commitmentKey: commitmentKey,
            commitmentKeyEpoch: 7)
        let currentReceipt = try await store.put(
            identityCore: currentCore,
            headUpdate: BASArtifactHeadCAS(
                key: key,
                expected: nil,
                replacementArtifactID: currentID))
        let expected = try XCTUnwrap(currentReceipt.body.head)

        let tamperedCore = Self.core(value: "current-evil")
        XCTAssertEqual(
            tamperedCore.payloadLength, currentCore.payloadLength)
        let tamperedRecord = BASArtifactMeshRecord(
            artifactID: currentID,
            identityCore: tamperedCore,
            storage: currentReceipt.body.storage)
        try Self.replaceRecordBytes(
            at: url,
            artifactID: currentID,
            bytes: BASGovernedArtifactPayloadCodec
                .canonicalBytes(for: tamperedRecord))

        let replacementCore = Self.core(value: "replacement")
        let replacementID = try BASArtifactMesh.artifactID(
            for: replacementCore,
            commitmentKey: commitmentKey,
            commitmentKeyEpoch: 7)
        await XCTAssertThrowsErrorAsync {
            _ = try await store.put(
                identityCore: replacementCore,
                headUpdate: BASArtifactHeadCAS(
                    key: key,
                    expected: expected,
                    replacementArtifactID: replacementID))
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await store.read(replacementID)
        }
    }

    func testHeadPurposesAreIndependentNamespaces() async throws {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(at: url)
        let firstKey = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .attemptRoot)
        let secondKey = BASArtifactHeadKey(
            scope: .attempt(Self.attemptID),
            purpose: .semanticSnapshot)
        let firstCore = Self.core(value: "purpose-a")
        let secondCore = Self.core(value: "purpose-b")
        let key = SymmetricKey(data: Self.keyData)
        let firstID = try BASArtifactMesh.artifactID(
            for: firstCore,
            commitmentKey: key,
            commitmentKeyEpoch: 7)
        let secondID = try BASArtifactMesh.artifactID(
            for: secondCore,
            commitmentKey: key,
            commitmentKeyEpoch: 7)

        _ = try await store.put(
            identityCore: firstCore,
            headUpdate: BASArtifactHeadCAS(
                key: firstKey,
                expected: nil,
                replacementArtifactID: firstID))
        _ = try await store.put(
            identityCore: secondCore,
            headUpdate: BASArtifactHeadCAS(
                key: secondKey,
                expected: nil,
                replacementArtifactID: secondID))

        let firstHead = try await store.head(firstKey)
        let secondHead = try await store.head(secondKey)
        XCTAssertEqual(firstHead?.artifactID, firstID)
        XCTAssertEqual(secondHead?.artifactID, secondID)
        XCTAssertEqual(firstHead?.revision, 0)
        XCTAssertEqual(secondHead?.revision, 0)
    }

    func testMissingActiveKeyEpochFailsBeforeAnyPut() async throws {
        let url = try Self.temporaryDatabaseURL()
        let store = try Self.makeStore(
            at: url, activeEpoch: 99, availableEpoch: 7)

        await XCTAssertThrowsErrorAsync {
            _ = try await store.put(
                identityCore: Self.core(), headUpdate: nil)
        }
    }

    func testPartialAndUnknownSchemasFailClosedWithoutRepair()
        throws
    {
        let partialURL = try Self.temporaryDatabaseURL()
        try Self.runRawSQL(
            at: partialURL,
            sql: """
                PRAGMA user_version=1;
                CREATE TABLE artifact_mesh_records (
                    artifact_id TEXT PRIMARY KEY,
                    record_bytes BLOB NOT NULL
                );
                """)
        XCTAssertThrowsError(try Self.makeStore(at: partialURL))

        let unknownURL = try Self.temporaryDatabaseURL()
        try Self.runRawSQL(
            at: unknownURL, sql: "PRAGMA user_version=99;")
        XCTAssertThrowsError(try Self.makeStore(at: unknownURL))
    }

    func testSchemaDefinitionDriftFailsClosedOnReopen() throws {
        XCTAssertEqual(ArtifactMeshV1Schema.statementCount, 5)

        let wrongIndexURL = try Self.temporaryDatabaseURL()
        do {
            _ = try Self.makeStore(at: wrongIndexURL)
        }
        try Self.runRawSQL(
            at: wrongIndexURL,
            sql: """
                DROP INDEX artifact_mesh_head_artifact_idx;
                CREATE INDEX artifact_mesh_head_artifact_idx
                    ON artifact_mesh_heads(revision);
                """)
        XCTAssertThrowsError(try Self.makeStore(at: wrongIndexURL))

        let unexpectedViewURL = try Self.temporaryDatabaseURL()
        do {
            _ = try Self.makeStore(at: unexpectedViewURL)
        }
        try Self.runRawSQL(
            at: unexpectedViewURL,
            sql: """
                CREATE VIEW artifact_mesh_shadow AS
                    SELECT artifact_id FROM artifact_mesh_records;
                """)
        XCTAssertThrowsError(try Self.makeStore(at: unexpectedViewURL))

        let weakenedTableURL = try Self.temporaryDatabaseURL()
        let weakenedSchema = ArtifactMeshV1Schema.allStatementsSQL
            .replacingOccurrences(
                of: "CHECK (length(commitment_key_epoch) > 0)",
                with: "")
        XCTAssertNotEqual(
            weakenedSchema, ArtifactMeshV1Schema.allStatementsSQL)
        try Self.runRawSQL(
            at: weakenedTableURL,
            sql: weakenedSchema + "\nPRAGMA user_version=1;")
        XCTAssertThrowsError(try Self.makeStore(at: weakenedTableURL))
    }

    private static func runRawSQL(at url: URL, sql: String) throws {
        try withRawDatabase(at: url) { db in
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw FixtureError.missingKey(0)
            }
        }
    }

    private static func assertColumnTextBoundFailure<T>(
        maximumBytes: Int,
        actualBytes: Int,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail(
                "expected bounded TEXT read to fail",
                file: file,
                line: line)
        } catch let error as BASArtifactSQLiteStore.StorageError {
            guard case .stepFailed(_, let message) = error else {
                XCTFail(
                    "expected stepFailed, got \(error)",
                    file: file,
                    line: line)
                return
            }
            XCTAssertEqual(
                message,
                "TEXT column exceeds \(maximumBytes)-byte bound "
                    + "(actual: \(actualBytes))",
                file: file,
                line: line)
        } catch {
            XCTFail(
                "expected typed StorageError, got \(error)",
                file: file,
                line: line)
        }
    }

    private static func replaceRecordBytes(
        at url: URL,
        artifactID: BASArtifactID,
        bytes: Data
    ) throws {
        let scalar = try artifactID.storageScalar
        let hex = hex(bytes)
        try runRawSQL(
            at: url,
            sql: """
                UPDATE artifact_mesh_records
                SET record_bytes = X'\(hex)'
                WHERE artifact_id = '\(scalar)';
                """)
    }

    private static func hex(_ bytes: Data) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func rawText(at url: URL, sql: String) throws -> String {
        try withRawDatabase(at: url) { db in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(
                db, sql, -1, &statement, nil) == SQLITE_OK,
                let statement
            else {
                throw FixtureError.missingKey(0)
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  sqlite3_column_type(statement, 0) == SQLITE_TEXT,
                  let value = sqlite3_column_text(statement, 0)
            else {
                throw FixtureError.missingKey(0)
            }
            let result = String(cString: value)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw FixtureError.missingKey(0)
            }
            return result
        }
    }

    private static func withRawDatabase<T>(
        at url: URL,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            url.path, &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nil) == SQLITE_OK,
            let db
        else {
            throw FixtureError.missingKey(0)
        }
        defer { sqlite3_close_v2(db) }
        return try body(db)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected async expression to throw", file: file, line: line)
    } catch {
        // Expected.
    }
}
