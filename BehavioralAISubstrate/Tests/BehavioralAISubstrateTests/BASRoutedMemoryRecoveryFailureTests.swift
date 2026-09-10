import Foundation
import SQLite3
import XCTest

@testable import BASHostKit
@testable import BASMemory

#if os(iOS) || os(macOS)
final class BASRoutedMemoryRecoveryFailureTests: XCTestCase {
    private enum Event: Hashable {
        case legacyAtoms
        case strictAtoms
        case legacyVector
        case strictVector
        case embed
        case backfill
    }

    private enum FixtureError: Error, CustomStringConvertible {
        case sqlite(operation: String, code: Int32, message: String)
        case unexpectedStep(
            expectedRows: [String],
            actualRows: [String],
            finalCode: Int32,
            message: String
        )

        var description: String {
            switch self {
            case let .sqlite(operation, code, message):
                return "\(operation) failed with SQLite code \(code): \(message)"
            case let .unexpectedStep(expectedRows, actualRows, finalCode, message):
                return "expected rows \(expectedRows) followed by SQLITE_ERROR; "
                    + "got rows \(actualRows), final code \(finalCode): \(message)"
            }
        }
    }

    private final class EventCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var counts: [Event: Int] = [:]

        func record(_ event: Event) {
            lock.lock()
            counts[event, default: 0] += 1
            lock.unlock()
        }

        func count(_ event: Event) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return counts[event, default: 0]
        }

        func reset() {
            lock.lock()
            counts.removeAll()
            lock.unlock()
        }
    }

    private var databaseURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in databaseURLs {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + "-wal")
            )
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + "-shm")
            )
        }
    }

    func testFactoryAuthoritativeRefreshPrefersStrictColdReopenSources() async throws {
        let atomURL = makeDatabaseURL(label: "precedence-atoms")
        let vectorURL = makeDatabaseURL(label: "precedence-vectors")
        let record = atom(701, content: "cold reopen")
        do {
            let atoms = try BASSQLiteMemoryAtomStore(databaseURL: atomURL)
            let vectors = try BASSQLiteVectorIndexStorage(databaseURL: vectorURL)
            try await atoms.admit(record)
            try await vectors.upsert(entry(for: record, vector: [0, 1]))
        }
        let atoms = try BASSQLiteMemoryAtomStore(databaseURL: atomURL)
        let vectors = try BASSQLiteVectorIndexStorage(databaseURL: vectorURL)
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: atoms,
            vectors: vectors,
            counter: counter
        )

        let recovered = try await service.refreshOrThrow()

        XCTAssertEqual(recovered, 1)
        XCTAssertEqual(service.snapshotCount, 1)
        XCTAssertEqual(
            service.snapshotEmbedding(forAtomID: record.id.uuidString),
            [0, 1]
        )
        XCTAssertEqual(counter.count(.strictAtoms), 1)
        XCTAssertEqual(counter.count(.strictVector), 1)
        XCTAssertEqual(counter.count(.legacyAtoms), 0)
        XCTAssertEqual(counter.count(.legacyVector), 0)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
    }

    func testFactoryAuthoritativeRefreshAcceptsGenuinelyEmptyStores() async throws {
        let atoms = try BASSQLiteMemoryAtomStore(
            databaseURL: makeDatabaseURL(label: "empty-atoms")
        )
        let vectors = try BASSQLiteVectorIndexStorage(
            databaseURL: makeDatabaseURL(label: "empty-vectors")
        )
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: atoms,
            vectors: vectors,
            counter: counter
        )

        let recovered = try await service.refreshOrThrow()

        XCTAssertEqual(recovered, 0)
        XCTAssertEqual(service.snapshotCount, 0)
        XCTAssertEqual(counter.count(.strictAtoms), 1)
        XCTAssertEqual(counter.count(.strictVector), 0)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
    }

    func testFactoryAuthoritativeRefreshBackfillsOnlyAGenuineMissingVector() async throws {
        let atoms = try BASSQLiteMemoryAtomStore(
            databaseURL: makeDatabaseURL(label: "missing-atoms")
        )
        let vectors = try BASSQLiteVectorIndexStorage(
            databaseURL: makeDatabaseURL(label: "missing-vectors")
        )
        let record = atom(702, content: "missing vector")
        try await atoms.admit(record)
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: atoms,
            vectors: vectors,
            counter: counter
        )

        let recovered = try await service.refreshOrThrow()
        let persisted = try await vectors.entryOrThrow(forID: record.id.uuidString)

        XCTAssertEqual(recovered, 1)
        XCTAssertEqual(service.snapshotCount, 1)
        XCTAssertEqual(persisted?.normalizedEmbedding.vector, [1, 0])
        XCTAssertEqual(counter.count(.strictAtoms), 1)
        XCTAssertEqual(counter.count(.strictVector), 1)
        XCTAssertEqual(counter.count(.embed), 1)
        XCTAssertEqual(counter.count(.backfill), 1)
    }

    func testFactoryAtomPreRowFailurePropagatesAndBothRefreshesRetainSnapshot() async throws {
        try await assertAtomReadFailureRetainsSnapshot(
            label: "atom-pre-row",
            records: [atom(711, content: "only")],
            failingIndex: 0,
            expectedRowsBeforeError: []
        )
    }

    func testFactoryAtomMidRowFailurePropagatesAndBothRefreshesRetainSnapshot() async throws {
        try await assertAtomReadFailureRetainsSnapshot(
            label: "atom-mid-row",
            records: [
                atom(721, content: "first"),
                atom(722, content: "second")
            ],
            failingIndex: 1,
            expectedRowsBeforeError: [atomID(721)]
        )
    }

    func testFactoryAtomDecodeFailurePropagatesWithoutEmbedBackfillOrReplacement() async throws {
        let stores = try await makeSeededStores(
            label: "atom-decode",
            records: [atom(731, content: "decode")]
        )
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: stores.atoms,
            vectors: stores.vectors,
            counter: counter
        )
        _ = try await service.refreshOrThrow()
        counter.reset()
        try execute(
            at: stores.atomURL,
            sql: "UPDATE memory_atoms SET payload_json = '{' WHERE atom_id = '\(atomID(731))'"
        )

        do {
            _ = try await service.refreshOrThrow()
            XCTFail("malformed atom JSON must fail authoritative refresh")
        } catch let error as BASSQLiteMemoryAtomStore.StorageError {
            guard case let .decodeFailed(id, _) = error else {
                return XCTFail("expected decodeFailed, got \(error)")
            }
            XCTAssertEqual(id, atomID(731))
        }

        XCTAssertEqual(service.snapshotCount, 1)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
        await service.refresh()
        XCTAssertEqual(service.snapshotCount, 1)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
    }

    func testFactoryLaterVectorReadFailureDoesNotEmbedEarlierMissOrReplaceSnapshot() async throws {
        let first = atom(741, content: "first")
        let second = atom(742, content: "second")
        let stores = try await makeSeededStores(
            label: "vector-read",
            records: [first, second]
        )
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: stores.atoms,
            vectors: stores.vectors,
            counter: counter
        )
        _ = try await service.refreshOrThrow()
        counter.reset()
        try await stores.vectors.remove(atomID: first.id.uuidString)
        try installVectorReadErrorView(
            at: stores.vectorURL,
            failingAtomID: second.id.uuidString
        )

        do {
            _ = try await service.refreshOrThrow()
            XCTFail("a later vector read error must abort authoritative refresh")
        } catch let error as BASSQLiteVectorIndexStorage.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected vector stepFailed, got \(error)")
            }
        }

        XCTAssertEqual(service.snapshotCount, 2)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
        await service.refresh()
        XCTAssertEqual(service.snapshotCount, 2)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
    }

    func testFactoryRejectsWrongDimensionStoredVectorWithoutRepairOrReplacement() async throws {
        try await assertInvalidStoredVectorIsRejected(
            label: "wrong-dimension",
            replacement: [1, 0, 0],
            expectedError: .embeddingDimensionMismatch(
                atomID: atomID(751),
                expected: 2,
                got: 3
            )
        )
    }

    func testFactoryRejectsNaNStoredVectorWithoutRepairOrReplacement() async throws {
        try await assertInvalidStoredVectorIsRejected(
            label: "nan",
            replacement: [.nan, 0],
            expectedError: .nonFiniteEmbedding(atomID: atomID(751))
        )
    }

    private func assertAtomReadFailureRetainsSnapshot(
        label: String,
        records: [BASGovernedMemory],
        failingIndex: Int,
        expectedRowsBeforeError: [String]
    ) async throws {
        let stores = try await makeSeededStores(label: label, records: records)
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: stores.atoms,
            vectors: stores.vectors,
            counter: counter
        )
        _ = try await service.refreshOrThrow()
        counter.reset()
        try installAtomReadErrorView(
            at: stores.atomURL,
            failingAtomID: records[failingIndex].id.uuidString,
            supportsPrefix: !expectedRowsBeforeError.isEmpty
        )
        try verifyRuntimeErrorFixture(
            at: stores.atomURL,
            sql: Self.allAtomsSQL,
            expectedRowsBeforeError: expectedRowsBeforeError
        )

        do {
            _ = try await service.refreshOrThrow()
            XCTFail("an incomplete atom enumeration must fail authoritative refresh")
        } catch let error as BASSQLiteMemoryAtomStore.StorageError {
            guard case .stepFailed = error else {
                return XCTFail("expected atom stepFailed, got \(error)")
            }
        }

        XCTAssertEqual(service.snapshotCount, records.count)
        XCTAssertEqual(counter.count(.strictVector), 0)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
        await service.refresh()
        XCTAssertEqual(service.snapshotCount, records.count)
        XCTAssertEqual(counter.count(.strictVector), 0)
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
    }

    private func assertInvalidStoredVectorIsRejected(
        label: String,
        replacement: [Float],
        expectedError: BASRoutedMemoryRecoveryError
    ) async throws {
        let record = atom(751, content: label)
        let stores = try await makeSeededStores(label: label, records: [record])
        let counter = EventCounter()
        let service = try makeStrictFactoryService(
            atoms: stores.atoms,
            vectors: stores.vectors,
            counter: counter
        )
        _ = try await service.refreshOrThrow()
        counter.reset()
        try await stores.vectors.upsert(entry(for: record, vector: replacement))
        let persisted = try await stores.vectors.entryOrThrow(forID: record.id.uuidString)
        XCTAssertEqual(persisted?.normalizedEmbedding.vector.count, replacement.count)
        if replacement.contains(where: { !$0.isFinite }) {
            XCTAssertTrue(persisted?.normalizedEmbedding.vector.first?.isNaN == true)
        }

        do {
            _ = try await service.refreshOrThrow()
            XCTFail("an unusable stored vector must fail authoritative refresh")
        } catch let error as BASRoutedMemoryRecoveryError {
            XCTAssertEqual(error, expectedError)
        }

        XCTAssertEqual(service.snapshotCount, 1)
        XCTAssertEqual(
            service.snapshotEmbedding(forAtomID: record.id.uuidString),
            [1, 0]
        )
        XCTAssertEqual(counter.count(.embed), 0)
        XCTAssertEqual(counter.count(.backfill), 0)
    }

    private func makeStrictFactoryService(
        atoms: BASSQLiteMemoryAtomStore,
        vectors: BASSQLiteVectorIndexStorage,
        counter: EventCounter
    ) throws -> BASL8RoutedMemoryService {
        let persistence = BASRoutedMemoryPersistence(
            loadAllAtoms: {
                counter.record(.legacyAtoms)
                return []
            },
            admitAtom: { atom in _ = try? await atoms.admit(atom) },
            atomStore: atoms,
            loadEmbedding: { _ in
                counter.record(.legacyVector)
                return nil
            },
            upsertEmbedding: { id, vector, domain in
                counter.record(.backfill)
                _ = try? await vectors.upsert(BASVectorIndexEntry(
                    atomID: id,
                    normalizedEmbedding: BASEmbedding(
                        vector: vector,
                        dimension: vector.count,
                        providerVersion: "fix-round"
                    ),
                    domain: domain
                ))
            },
            loadAllAtomsOrThrow: {
                counter.record(.strictAtoms)
                return try await atoms.allAtoms()
            },
            loadEmbeddingOrThrow: { id in
                counter.record(.strictVector)
                return try await vectors.entryOrThrow(forID: id)?
                    .normalizedEmbedding.vector
            }
        )
        let resolved = BASCognitiveBrain.resolveMemoryService(
            memoryEmbed: { _ in
                counter.record(.embed)
                return [1, 0]
            },
            dim: 2,
            persistence: persistence
        )
        return try XCTUnwrap(resolved as? BASL8RoutedMemoryService)
    }

    private func makeSeededStores(
        label: String,
        records: [BASGovernedMemory]
    ) async throws -> (
        atoms: BASSQLiteMemoryAtomStore,
        vectors: BASSQLiteVectorIndexStorage,
        atomURL: URL,
        vectorURL: URL
    ) {
        let atomURL = makeDatabaseURL(label: "\(label)-atoms")
        let vectorURL = makeDatabaseURL(label: "\(label)-vectors")
        let atoms = try BASSQLiteMemoryAtomStore(databaseURL: atomURL)
        let vectors = try BASSQLiteVectorIndexStorage(databaseURL: vectorURL)
        for record in records {
            try await atoms.admit(record)
            try await vectors.upsert(entry(for: record, vector: [1, 0]))
        }
        return (atoms, vectors, atomURL, vectorURL)
    }

    private func atom(_ number: Int, content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(uuidString: atomID(number))!,
            kind: .semantic,
            content: content,
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.8,
            sourceType: "test.routed-recovery",
            governanceStatus: .governed,
            provenanceSummary: "fix-round"
        )
    }

    private func atomID(_ number: Int) -> String {
        let suffix = String(format: "%012llX", Int64(number))
        return "00000000-0000-0000-0000-\(suffix)"
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
                providerVersion: "fix-round"
            ),
            domain: atom.sourceType
        )
    }

    private static let allAtomsSQL = """
        SELECT atom_id, payload_json FROM memory_atoms
         ORDER BY created_at_ms ASC, atom_id ASC
        """

    private func makeDatabaseURL(label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-routed-recovery-\(label)-\(UUID().uuidString).sqlite"
            )
        databaseURLs.append(url)
        return url
    }

    private func installAtomReadErrorView(
        at url: URL,
        failingAtomID: String,
        supportsPrefix: Bool
    ) throws {
        let prefixSupportSQL = supportsPrefix
            ? """
              UPDATE memory_atoms_backing SET created_at_ms = rowid;
              CREATE INDEX memory_atoms_backing_created_id_idx
                  ON memory_atoms_backing(created_at_ms, atom_id);
              """
            : ""
        try execute(at: url, sql: """
            ALTER TABLE memory_atoms RENAME TO memory_atoms_backing;
            \(prefixSupportSQL)
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

    private func verifyRuntimeErrorFixture(
        at url: URL,
        sql: String,
        expectedRowsBeforeError: [String]
    ) throws {
        try withDatabase(at: url) { db in
            var statement: OpaquePointer?
            let prepareCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard prepareCode == SQLITE_OK, let statement else {
                throw FixtureError.sqlite(
                    operation: "prepare exact fixture probe",
                    code: prepareCode,
                    message: String(cString: sqlite3_errmsg(db))
                )
            }
            defer { sqlite3_finalize(statement) }
            var rows: [String] = []
            var finalCode = sqlite3_step(statement)
            while finalCode == SQLITE_ROW {
                if let text = sqlite3_column_text(statement, 0) {
                    rows.append(String(cString: text))
                }
                finalCode = sqlite3_step(statement)
            }
            let message = String(cString: sqlite3_errmsg(db))
            guard rows == expectedRowsBeforeError,
                  finalCode == SQLITE_ERROR,
                  message.contains("integer overflow")
            else {
                throw FixtureError.unexpectedStep(
                    expectedRows: expectedRowsBeforeError,
                    actualRows: rows,
                    finalCode: finalCode,
                    message: message
                )
            }
        }
    }

    private func execute(at url: URL, sql: String) throws {
        try withDatabase(at: url) { db in
            var errorMessage: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(db, sql, nil, nil, &errorMessage)
            defer { sqlite3_free(errorMessage) }
            guard code == SQLITE_OK else {
                throw FixtureError.sqlite(
                    operation: "execute fixture SQL",
                    code: code,
                    message: errorMessage.map { String(cString: $0) }
                        ?? String(cString: sqlite3_errmsg(db))
                )
            }
        }
    }

    private func withDatabase(
        at url: URL,
        _ body: (OpaquePointer) throws -> Void
    ) throws {
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
        try body(db)
    }
}
#endif
