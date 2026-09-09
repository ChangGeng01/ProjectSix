import Foundation
import SQLite3
import XCTest

@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)
final class BASGlobalRecallRecoveryTests: XCTestCase {
    private enum FixtureError: Error {
        case sqlite(operation: String, code: Int32, message: String)
    }

    private var databaseURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in databaseURLs {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + "-shm"))
        }
    }

    func testEmptyDurableStoresProduceOneEmptyStagedResult() async throws {
        let stores = try makeStores()

        let result = try await BASGlobalRecallRecovery.recover(
            atomStore: stores.atoms,
            vectorStorage: stores.vectors,
            expectedDimension: 2,
            requestedCap: 1
        )

        let engineCount = await result.engine.totalCount
        XCTAssertEqual(engineCount, 0)
        XCTAssertEqual(result.resolver.count, 0)
        XCTAssertEqual(result.syncedAtomIDs, Set<String>())
        XCTAssertEqual(result.seam.cosineTopK([1, 0], 3).count, 0)
    }

    func testColdReopenedCompleteStoresRecoverReferencesSyncedIDsAndRealDomains() async throws {
        let atomURL = makeDatabaseURL(label: "complete-atoms")
        let vectorURL = makeDatabaseURL(label: "complete-vectors")
        let first = atom(1, content: "first", domain: "health")
        let second = atom(2, content: "second", domain: "finance")
        do {
            let atoms = try BASSQLiteMemoryAtomStore(databaseURL: atomURL)
            let vectors = try BASSQLiteVectorIndexStorage(databaseURL: vectorURL)
            try await atoms.admit(first)
            try await atoms.admit(second)
            try await vectors.upsert(entry(for: first, vector: [1, 0]))
            try await vectors.upsert(entry(for: second, vector: [0, 1]))
        }

        let atoms = try BASSQLiteMemoryAtomStore(databaseURL: atomURL)
        let vectors = try BASSQLiteVectorIndexStorage(databaseURL: vectorURL)
        let result = try await BASGlobalRecallRecovery.recover(
            atomStore: atoms,
            vectorStorage: vectors,
            expectedDimension: 2,
            requestedCap: BASGlobalRecallResolver.minCap
        )

        let engineCount = await result.engine.totalCount
        let firstResolved = result.seam.atomForID(first.id.uuidString)
        let secondResolved = result.seam.atomForID(second.id.uuidString)
        let top = result.seam.cosineTopK([1, 0], 2)
        XCTAssertEqual(engineCount, 2)
        XCTAssertEqual(result.resolver.count, 2)
        XCTAssertEqual(result.syncedAtomIDs, [first.id.uuidString, second.id.uuidString])
        XCTAssertEqual(firstResolved?.atom.memoryID, first.id.uuidString)
        XCTAssertEqual(firstResolved?.domain, "health")
        XCTAssertEqual(secondResolved?.domain, "finance")
        XCTAssertEqual(top.first?.atomID, first.id.uuidString)
    }

    func testRequestedCapBelowFloorUsesSameEffectiveCapForSuffixAndResolver() async throws {
        let stores = try makeStores()
        let records = (1...66).map {
            atom($0, content: "record-\($0)", domain: "domain-\($0)")
        }
        for (offset, record) in records.enumerated() {
            try await stores.atoms.admit(record)
            try await stores.vectors.upsert(
                entry(for: record, vector: [Float(offset + 1), 1])
            )
        }

        let result = try await BASGlobalRecallRecovery.recover(
            atomStore: stores.atoms,
            vectorStorage: stores.vectors,
            expectedDimension: 2,
            requestedCap: 1
        )

        let engineCount = await result.engine.totalCount
        XCTAssertEqual(engineCount, BASGlobalRecallResolver.minCap)
        XCTAssertEqual(result.resolver.count, BASGlobalRecallResolver.minCap)
        XCTAssertEqual(result.syncedAtomIDs.count, 66)
        XCTAssertNil(result.seam.atomForID(records[0].id.uuidString))
        XCTAssertNil(result.seam.atomForID(records[1].id.uuidString))
        XCTAssertEqual(
            result.seam.atomForID(records[2].id.uuidString)?.domain,
            "domain-3"
        )
        XCTAssertEqual(
            result.seam.atomForID(records[65].id.uuidString)?.domain,
            "domain-66"
        )
    }

    func testMissingNewestVectorRemainsUnseenWithoutReembedding() async throws {
        let stores = try makeStores()
        let first = atom(101, content: "first", domain: "one")
        let missing = atom(102, content: "missing", domain: "two")
        let third = atom(103, content: "third", domain: "three")
        for record in [first, missing, third] {
            try await stores.atoms.admit(record)
        }
        try await stores.vectors.upsert(entry(for: first, vector: [1, 0]))
        try await stores.vectors.upsert(entry(for: third, vector: [0, 1]))

        let result = try await BASGlobalRecallRecovery.recover(
            atomStore: stores.atoms,
            vectorStorage: stores.vectors,
            expectedDimension: 2,
            requestedCap: BASGlobalRecallResolver.minCap
        )

        let engineCount = await result.engine.totalCount
        XCTAssertEqual(engineCount, 2)
        XCTAssertEqual(
            result.syncedAtomIDs,
            [first.id.uuidString, third.id.uuidString]
        )
        XCTAssertFalse(result.syncedAtomIDs.contains(missing.id.uuidString))
        XCTAssertNil(result.seam.atomForID(missing.id.uuidString))
    }

    func testAtomEnumerationErrorAbortsRecovery() async throws {
        let stores = try makeStores()
        let record = atom(201, content: "atom-error", domain: "general")
        try await stores.atoms.admit(record)
        let atomURL = await stores.atoms.databaseURL
        try installAtomReadErrorView(
            at: atomURL,
            failingAtomID: record.id.uuidString
        )

        do {
            _ = try await BASGlobalRecallRecovery.recover(
                atomStore: stores.atoms,
                vectorStorage: stores.vectors,
                expectedDimension: 2,
                requestedCap: 64
            )
            XCTFail("an incomplete atom scan must abort staged recovery")
        } catch let error as BASSQLiteMemoryAtomStore.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected atom stepFailed, got \(error)")
            }
        }
    }

    func testVectorEnumerationErrorAbortsRecovery() async throws {
        let stores = try makeStores()
        let record = atom(301, content: "vector-error", domain: "general")
        try await stores.atoms.admit(record)
        try await stores.vectors.upsert(entry(for: record, vector: [1, 0]))
        let vectorURL = await stores.vectors.databaseURL
        try installVectorReadErrorView(
            at: vectorURL,
            failingAtomID: record.id.uuidString
        )

        do {
            _ = try await BASGlobalRecallRecovery.recover(
                atomStore: stores.atoms,
                vectorStorage: stores.vectors,
                expectedDimension: 2,
                requestedCap: 64
            )
            XCTFail("an incomplete vector scan must abort staged recovery")
        } catch let error as BASSQLiteVectorIndexStorage.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected vector stepFailed, got \(error)")
            }
        }
    }

    func testMixedSelectedDimensionsAreRejectedBeforeRecoveryPublication() async throws {
        let stores = try makeStores()
        let twoDimensional = atom(351, content: "two-dimensional", domain: "legacy")
        let threeDimensional = atom(352, content: "three-dimensional", domain: "migrated")
        try await stores.atoms.admit(twoDimensional)
        try await stores.atoms.admit(threeDimensional)
        try await stores.vectors.upsert(entry(for: twoDimensional, vector: [1, 0]))
        try await stores.vectors.upsert(entry(for: threeDimensional, vector: [1, 0, 0]))

        do {
            _ = try await BASGlobalRecallRecovery.recover(
                atomStore: stores.atoms,
                vectorStorage: stores.vectors,
                expectedDimension: 2,
                requestedCap: BASGlobalRecallResolver.minCap
            )
            XCTFail("mixed selected dimensions must reject recovery before publication")
        } catch let error as BASRoutedMemoryRecoveryError {
            XCTAssertEqual(
                error,
                .embeddingDimensionMismatch(
                    atomID: threeDimensional.id.uuidString,
                    expected: 2,
                    got: 3
                )
            )
        } catch {
            XCTFail("expected BASRoutedMemoryRecoveryError, got \(error)")
        }
    }

    func testUniformVectorsStillRejectTheWrongExplicitHostDimension() async throws {
        let stores = try makeStores()
        let first = atom(353, content: "first-three-dimensional", domain: "legacy")
        let second = atom(354, content: "second-three-dimensional", domain: "legacy")
        try await stores.atoms.admit(first)
        try await stores.atoms.admit(second)
        try await stores.vectors.upsert(entry(for: first, vector: [1, 0, 0]))
        try await stores.vectors.upsert(entry(for: second, vector: [0, 1, 0]))

        do {
            _ = try await BASGlobalRecallRecovery.recover(
                atomStore: stores.atoms,
                vectorStorage: stores.vectors,
                expectedDimension: 2,
                requestedCap: BASGlobalRecallResolver.minCap
            )
            XCTFail("uniform vectors must still match the host's explicit query dimension")
        } catch let error as BASRoutedMemoryRecoveryError {
            XCTAssertEqual(
                error,
                .embeddingDimensionMismatch(
                    atomID: first.id.uuidString,
                    expected: 2,
                    got: 3
                )
            )
        } catch {
            XCTFail("expected BASRoutedMemoryRecoveryError, got \(error)")
        }
    }

    func testZeroVectorWithExpectedDimensionRemainsRecoverable() async throws {
        let stores = try makeStores()
        let zero = atom(355, content: "zero", domain: "valid-zero")
        try await stores.atoms.admit(zero)
        try await stores.vectors.upsert(entry(for: zero, vector: [0, 0]))

        let result = try await BASGlobalRecallRecovery.recover(
            atomStore: stores.atoms,
            vectorStorage: stores.vectors,
            expectedDimension: 2,
            requestedCap: BASGlobalRecallResolver.minCap
        )

        let engineCount = await result.engine.totalCount
        XCTAssertEqual(engineCount, 1)
        XCTAssertEqual(result.resolver.count, 1)
        XCTAssertEqual(result.syncedAtomIDs, [zero.id.uuidString])
        XCTAssertEqual(
            result.seam.atomForID(zero.id.uuidString)?.domain,
            "valid-zero"
        )
    }

    func testPersistedNaNSelectedVectorIsRejectedBeforeRecoveryPublication() async throws {
        let stores = try makeStores()
        let finite = atom(361, content: "finite", domain: "current")
        let nonfinite = atom(362, content: "nonfinite", domain: "legacy")
        try await stores.atoms.admit(finite)
        try await stores.atoms.admit(nonfinite)
        try await stores.vectors.upsert(entry(for: finite, vector: [1, 0]))
        try await stores.vectors.upsert(entry(for: nonfinite, vector: [.nan, 0]))

        let persistedEntry = try await stores.vectors.entryOrThrow(
            forID: nonfinite.id.uuidString
        )
        let persisted = try XCTUnwrap(persistedEntry)
        XCTAssertEqual(persisted.normalizedEmbedding.dimension, 2)
        XCTAssertEqual(persisted.normalizedEmbedding.vector.count, 2)
        XCTAssertTrue(
            persisted.normalizedEmbedding.vector[0].isNaN,
            "the real SQLite round-trip must preserve the NaN fixture before recovery is exercised"
        )

        do {
            _ = try await BASGlobalRecallRecovery.recover(
                atomStore: stores.atoms,
                vectorStorage: stores.vectors,
                expectedDimension: 2,
                requestedCap: BASGlobalRecallResolver.minCap
            )
            XCTFail("a persisted same-dimension NaN must reject recovery before publication")
        } catch let error as BASRoutedMemoryRecoveryError {
            XCTAssertEqual(
                error,
                .nonFiniteEmbedding(atomID: nonfinite.id.uuidString)
            )
        } catch {
            XCTFail("expected BASRoutedMemoryRecoveryError, got \(error)")
        }
    }

    func testRealEngineDimensionCapRejectionDoesNotReplacePriorCompleteResult() async throws {
        let good = try makeStores()
        let priorAtom = atom(401, content: "prior", domain: "prior-domain")
        try await good.atoms.admit(priorAtom)
        try await good.vectors.upsert(entry(for: priorAtom, vector: [1, 0]))
        var published = try await BASGlobalRecallRecovery.recover(
            atomStore: good.atoms,
            vectorStorage: good.vectors,
            expectedDimension: 2,
            requestedCap: 64
        )

        let bad = try makeStores()
        let rejected = atom(502, content: "oversized", domain: "bad-domain")
        try await bad.atoms.admit(rejected)
        try await bad.vectors.upsert(
            entry(
                for: rejected,
                vector: Array(repeating: 1, count: BASRoutedVectorIndexStorage.queryDimCap + 1)
            )
        )

        do {
            published = try await BASGlobalRecallRecovery.recover(
                atomStore: bad.atoms,
                vectorStorage: bad.vectors,
                expectedDimension: BASRoutedVectorIndexStorage.queryDimCap + 1,
                requestedCap: 64
            )
            XCTFail("a real engine dimension-cap rejection must abort the staged result")
        } catch let error as BASRoutedVectorIndexStorage.StoreError {
            XCTAssertEqual(error, .upsertFailed(code: -3))
        }

        let priorCount = await published.engine.totalCount
        XCTAssertEqual(priorCount, 1)
        XCTAssertEqual(
            published.seam.atomForID(priorAtom.id.uuidString)?.domain,
            "prior-domain"
        )
        XCTAssertNil(published.seam.atomForID(rejected.id.uuidString))
    }

    #if os(macOS)
    func testEnduranceAppPublishesOnlyTheProductionHelperResult() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let runnerURL = packageRoot.appendingPathComponent(
            "DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift"
        )
        let source = try String(contentsOf: runnerURL, encoding: .utf8)
        let helperCall = try XCTUnwrap(
            source.range(of: "BASGlobalRecallRecovery.recover(")
        )
        let globalExpectedDimension = try XCTUnwrap(
            source.range(of: "expectedDimension: BASMiniLMEmbeddingProvider.embeddingDim")
        )
        let strictAtoms = try XCTUnwrap(
            source.range(of: "loadAllAtomsOrThrow: { try await store.allAtoms() }")
        )
        let strictVectors = try XCTUnwrap(
            source.range(of: "loadEmbeddingOrThrow:")
        )
        let brainFactory = try XCTUnwrap(
            source.range(of: "brain = try await BASCognitiveBrain.makeWithDefaults(")
        )
        let brainExpectedDimension = try XCTUnwrap(
            source.range(of: "memoryEmbedDim: BASMiniLMEmbeddingProvider.embeddingDim")
        )
        let authoritativeRefresh = try XCTUnwrap(
            source.range(of: "try await brain.refreshMemoryOrThrow()")
        )
        let strictVectorCount = try XCTUnwrap(
            source.range(of: "try await vindex.totalCountOrThrow()")
        )
        let enginePublish = try XCTUnwrap(
            source.range(of: "globalRecallEngine = recovered.engine")
        )
        let resolverPublish = try XCTUnwrap(
            source.range(of: "globalRecallResolver = recovered.resolver")
        )
        let syncedPublish = try XCTUnwrap(
            source.range(of: "globalRecallSynced = recovered.syncedAtomIDs")
        )
        let seamPublish = try XCTUnwrap(
            source.range(of: "globalSeam = recovered.seam")
        )
        let activeLog = try XCTUnwrap(
            source.range(of: "ADR-037 global recall ACTIVE")
        )

        XCTAssertLessThan(helperCall.lowerBound, enginePublish.lowerBound)
        XCTAssertLessThan(helperCall.lowerBound, globalExpectedDimension.lowerBound)
        XCTAssertLessThan(helperCall.lowerBound, resolverPublish.lowerBound)
        XCTAssertLessThan(helperCall.lowerBound, syncedPublish.lowerBound)
        XCTAssertLessThan(helperCall.lowerBound, seamPublish.lowerBound)
        XCTAssertLessThan(enginePublish.lowerBound, activeLog.lowerBound)
        XCTAssertLessThan(resolverPublish.lowerBound, activeLog.lowerBound)
        XCTAssertLessThan(syncedPublish.lowerBound, activeLog.lowerBound)
        XCTAssertLessThan(seamPublish.lowerBound, activeLog.lowerBound)
        XCTAssertLessThan(strictAtoms.lowerBound, brainFactory.lowerBound)
        XCTAssertLessThan(strictVectors.lowerBound, brainFactory.lowerBound)
        XCTAssertLessThan(brainFactory.lowerBound, brainExpectedDimension.lowerBound)
        XCTAssertLessThan(brainFactory.lowerBound, authoritativeRefresh.lowerBound)
        XCTAssertLessThan(authoritativeRefresh.lowerBound, strictVectorCount.lowerBound)
        XCTAssertNil(source.range(of: "await brain.refreshMemory()"))
    }
    #endif

    private func makeStores() throws -> (
        atoms: BASSQLiteMemoryAtomStore,
        vectors: BASSQLiteVectorIndexStorage
    ) {
        let atomURL = makeDatabaseURL(label: "atoms")
        let vectorURL = makeDatabaseURL(label: "vectors")
        return (
            try BASSQLiteMemoryAtomStore(databaseURL: atomURL),
            try BASSQLiteVectorIndexStorage(databaseURL: vectorURL)
        )
    }

    private func makeDatabaseURL(label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-global-recovery-\(label)-\(UUID().uuidString).sqlite"
            )
        databaseURLs.append(url)
        return url
    }

    private func atom(
        _ number: Int,
        content: String,
        domain: String
    ) -> BASGovernedMemory {
        let suffix = String(format: "%012llX", Int64(number))
        return BASGovernedMemory(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!,
            kind: .semantic,
            content: content,
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.7,
            sourceType: domain,
            governanceStatus: .governed,
            provenanceSummary: "task-12"
        )
    }

    private func entry(
        for atom: BASGovernedMemory,
        vector: [Float]
    ) -> BASVectorIndexEntry {
        BASVectorIndexEntry(
            atomID: atom.id.uuidString,
            normalizedEmbedding: BASEmbedding(
                vector: vector,
                dimension: vector.count,
                providerVersion: "task-12"
            ),
            domain: atom.sourceType,
            metadata: ["source": atom.id.uuidString]
        )
    }

    private func installAtomReadErrorView(
        at url: URL,
        failingAtomID: String
    ) throws {
        try execute(at: url, sql: """
            ALTER TABLE memory_atoms RENAME TO memory_atoms_backing;
            CREATE VIEW memory_atoms AS
            SELECT atom_id, kind, scope, sensitivity, tier, governance_status,
                   created_at_ms, last_updated_at_ms,
                   CASE WHEN atom_id = '\(failingAtomID)'
                        THEN abs(-9223372036854775808)
                        ELSE payload_json
                   END AS payload_json
            FROM memory_atoms_backing;
            """)
    }

    private func installVectorReadErrorView(
        at url: URL,
        failingAtomID: String
    ) throws {
        try execute(at: url, sql: """
            ALTER TABLE vector_index RENAME TO vector_index_backing;
            CREATE VIEW vector_index AS
            SELECT atom_id, dimension, provider_version, embedding_blob, domain,
                   CASE WHEN atom_id = '\(failingAtomID)'
                        THEN abs(-9223372036854775808)
                        ELSE metadata_json
                   END AS metadata_json
            FROM vector_index_backing;
            """)
    }

    private func execute(at url: URL, sql: String) throws {
        var db: OpaquePointer?
        let openCode = sqlite3_open_v2(
            url.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openCode == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) }
                ?? "sqlite3_open_v2 returned \(openCode)"
            if db != nil { sqlite3_close_v2(db) }
            throw FixtureError.sqlite(
                operation: "open fixture database",
                code: openCode,
                message: message
            )
        }
        defer { sqlite3_close_v2(db) }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        defer { sqlite3_free(errorMessage) }
        guard code == SQLITE_OK else {
            throw FixtureError.sqlite(
                operation: "install read-error view",
                code: code,
                message: errorMessage.map { String(cString: $0) }
                    ?? String(cString: sqlite3_errmsg(db))
            )
        }
    }
}
#endif
