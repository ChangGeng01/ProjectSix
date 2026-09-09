import Foundation
import BASMemory

#if os(iOS) || os(macOS)
/// A fully staged global-recall replica recovered from both durable SQLite stores.
/// Construction throws until both authoritative reads and every selected engine
/// insertion complete, so hosts can publish these references as one result.
public struct BASGlobalRecallRecovery: Sendable {
    public let engine: BASRoutedVectorIndexStorage
    public let resolver: BASGlobalRecallResolver
    public let syncedAtomIDs: Set<String>
    public let seam: BASGlobalRecallSeam

    private init(
        engine: BASRoutedVectorIndexStorage,
        resolver: BASGlobalRecallResolver,
        syncedAtomIDs: Set<String>,
        seam: BASGlobalRecallSeam
    ) {
        self.engine = engine
        self.resolver = resolver
        self.syncedAtomIDs = syncedAtomIDs
        self.seam = seam
    }

    /// Rebuild the private Rust `:memory:` replica without re-embedding. The host must
    /// keep startup writers quiescent while these two independent durable scans run.
    public static func recover(
        atomStore: BASSQLiteMemoryAtomStore,
        vectorStorage: BASSQLiteVectorIndexStorage,
        expectedDimension: Int,
        requestedCap: Int
    ) async throws -> BASGlobalRecallRecovery {
        let durableAtoms = try await atomStore.allAtoms()
        let durableEntries = try await vectorStorage.allEntriesOrThrow()
        let entryByID = Dictionary(
            durableEntries.map { ($0.atomID, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        let effectiveCap = max(BASGlobalRecallResolver.minCap, requestedCap)
        let newest = durableAtoms.suffix(effectiveCap)
        let newestIDs = Set(newest.map { $0.id.uuidString })
        for record in newest {
            let id = record.id.uuidString
            guard let entry = entryByID[id] else { continue }
            let embedding = entry.normalizedEmbedding
            guard embedding.dimension == expectedDimension else {
                throw BASRoutedMemoryRecoveryError.embeddingDimensionMismatch(
                    atomID: id,
                    expected: expectedDimension,
                    got: embedding.dimension
                )
            }
            guard embedding.vector.allSatisfy(\.isFinite) else {
                throw BASRoutedMemoryRecoveryError.nonFiniteEmbedding(atomID: id)
            }
        }

        let engine = try BASRoutedVectorIndexStorage(inMemory: ())
        let resolver = BASGlobalRecallResolver(cap: effectiveCap)
        let pin = BASL8RoutedMemoryService.Parameters.atomSource
        var syncedAtomIDs = Set<String>()

        for record in durableAtoms where !newestIDs.contains(record.id.uuidString) {
            syncedAtomIDs.insert(record.id.uuidString)
        }
        for record in newest {
            let id = record.id.uuidString
            guard let entry = entryByID[id] else {
                continue
            }
            _ = try await engine.upsert(BASVectorIndexEntry(
                atomID: id,
                normalizedEmbedding: entry.normalizedEmbedding,
                domain: pin
            ))
            _ = resolver.put(
                id: id,
                atom: BASL8RoutedMemoryService.memoryAtom(from: record),
                domain: record.sourceType
            )
            syncedAtomIDs.insert(id)
        }

        let seam = BASGlobalRecallSeam(
            cosineTopK: { [engine, pin, resolver] query, k in
                resolver.assertNotWriting()
                return (try? engine.cosineTopKAtomIDsSync(
                    forDomain: pin,
                    query: query,
                    k: k
                )) ?? []
            },
            atomForID: { [resolver] id in
                resolver.assertNotWriting()
                return resolver.lookupSync(id: id)
            }
        )
        return BASGlobalRecallRecovery(
            engine: engine,
            resolver: resolver,
            syncedAtomIDs: syncedAtomIDs,
            seam: seam
        )
    }
}
#endif
