// MARK: - BASRustMemoryUsageTrackerActor
// chapter 七百六 / M2189 第三刀 — Swift actor wrapping
//                                 the M2187 Rust crate
//                                 (bas-memory-usage-
//                                 tracker via the
//                                 BASRustMemoryTracker
//                                 Binary XCFramework)。
//                                 Opt-in via
//                                 `BASLanguageAugmentation
//                                 FeatureFlags
//                                 .rustCoreEnabled`
//                                 (default false → V1
//                                 Swift BASMemoryUsage
//                                 Tracker in-memory path
//                                 unchanged)。
//
// ## Surface
//
// Mirrors the V1 BASMemoryUsageTracker in-memory mode
// at the public-API level so a future "use Rust for
// in-memory tracking" caller can hot-swap behind the
// feature flag without restructuring call sites。
//
// V1 (`BASMemoryUsageTracker` init() with no DB URL):
//   - record(atomID:sessionRef:turnRef:permitMode:
//            retrievedAt:) async throws -> String (recordID)
//   - recordCount: Int
//   - allRecords() -> [BASMemoryUsageRecord]
//
// V2 (THIS actor):
//   - same shape;values flow through Rust ABI calls
//   - Codable wire format byte-equality verified by
//     M2189 第三刀 tests
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 — actor isolates Rust pointer,
//     never mutates host runtime
//   - 红线 7 — no permit / watcher gate touched
//   - chapter 477 ADR-014 OPT-IN — flag default-off →
//     V1 Swift path unchanged
//   - chapter 一百八十五 anti-magic-number — error
//     cases typed,ABI version pinned via cross-mirror
//   - V1 byte-equality preserved (770 → 771 consecutive
//     clean commits after this lands)
//
// ## Platform gating
//
// `#if os(iOS) || os(macOS)` guard。
// watchOS / Linux build hosts compile to a stub whose
// public surface throws `.rustBridgeUnavailableOnPlatform`
// on every call。 Production Apple platforms get the
// real wrapper。

import Foundation
import BASRuntimeCore
import BASMemory
// M2189 第三刀 — module map in XCFramework's Headers/
// directory exposes `BASRustMemoryTrackerBinary` as
// importable C module on iOS + macOS slices。
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

/// 持续性 发展 — Codable entry of the
/// `topKAtoms(limit:)` result。 Pairs atomID with its
/// occurrence count。 Decodable from Rust-emitted JSON
/// `{"atomID": "...", "count": N}` objects。
public struct BASTopAtomEntry: Codable, Equatable,
    Sendable, Hashable
{
    /// SHA256-prefix atomID (matches the
    /// BASBrainHistoryAtomID canonical derivation)。
    public let atomID: String

    /// Number of records in the Rust tracker carrying
    /// this atomID。
    public let count: Int

    public init(atomID: String, count: Int) {
        self.atomID = atomID
        self.count = count
    }
}

/// 主线 核心 抽取 — Codable entry of the Rust-computed
/// memory importance score per atom。 Emitted by
/// `bas_rust_tracker_atom_importance_scores` FFI,sorted
/// descending by score。
///
/// Hosts use this to:
///   - find "most-important" atoms for memory tier
///     promotion
///   - identify "least-important" atoms for forget
///     cascade demotion
///   - render memory-importance dashboards
public struct BASAtomImportanceEntry: Codable, Equatable,
    Sendable, Hashable
{
    /// SHA256-prefix atomID (matches the canonical
    /// BASBrainHistoryAtomID derivation)。
    public let atomID: String

    /// Number of records carrying this atomID。
    public let count: Int

    /// Helped rate in [0.5, 1.0]:helped /
    /// (helped + notHelped),clamped to ≥ 0.5。 1.0
    /// when no non-unknown helped state recorded
    /// (absent-signal defaults to "treat positive")。
    public let helpedRate: Double

    /// Epoch milliseconds of the most recent retrieval
    /// for this atom。
    public let lastRetrievedMs: Int64

    /// Composite importance score:
    ///   score = ln(1 + count)
    ///         × exp(-(now - lastRetrieved) / halfLife)
    ///         × helpedRate
    public let score: Double

    public init(
        atomID: String,
        count: Int,
        helpedRate: Double,
        lastRetrievedMs: Int64,
        score: Double
    ) {
        self.atomID = atomID
        self.count = count
        self.helpedRate = helpedRate
        self.lastRetrievedMs = lastRetrievedMs
        self.score = score
    }
}

/// 全面 开发 — three percentiles of the retrieval-
/// interval distribution computed inside the Rust
/// tracker。 Values are millisecond gaps between
/// consecutive retrievals。 Sentinel value -1 means
/// "fewer than 2 records — no interval available"。
public struct BASRetrievalIntervalPercentiles: Codable,
    Equatable, Sendable, Hashable
{
    /// 50th-percentile (median) gap between consecutive
    /// retrievals,milliseconds。
    public let p50Millis: Int64

    /// 95th-percentile gap,milliseconds。
    public let p95Millis: Int64

    /// 99th-percentile gap,milliseconds。
    public let p99Millis: Int64

    public init(
        p50Millis: Int64,
        p95Millis: Int64,
        p99Millis: Int64
    ) {
        self.p50Millis = p50Millis
        self.p95Millis = p95Millis
        self.p99Millis = p99Millis
    }

    /// True when all three are -1 (no interval signal
    /// available)。
    public var isEmpty: Bool {
        return p50Millis == -1
            && p95Millis == -1
            && p99Millis == -1
    }
}

/// 持续性 发展 — three percentiles of the count-per-atom
/// distribution computed inside the Rust tracker。 Each
/// value is the count threshold at the percentile rank。
/// Sentinel value -1 means "no records — no distribution"。
public struct BASAtomCountPercentiles: Codable, Equatable,
    Sendable, Hashable
{
    /// 50th-percentile (median) of count-per-atom。
    public let p50: Int64

    /// 95th-percentile of count-per-atom。
    public let p95: Int64

    /// 99th-percentile of count-per-atom。
    public let p99: Int64

    public init(p50: Int64, p95: Int64, p99: Int64) {
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
    }

    /// True when all three percentiles are -1 (no records
    /// to compute distribution over)。
    public var isEmpty: Bool {
        return p50 == -1 && p95 == -1 && p99 == -1
    }
}

/// Typed wrapper errors mirroring the Rust ABI return
/// codes + adding Swift-side platform-availability
/// case。
public enum BASRustMemoryUsageTrackerActorError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// Rust XCFramework unavailable on this build host
    /// (watchOS,Linux,or a host where the .binaryTarget
    /// `.when(platforms:)` condition excluded the slice)。
    case rustBridgeUnavailableOnPlatform

    /// `bas_rust_tracker_init` returned null (Rust-side
    /// allocation failure — extremely rare since
    /// Tracker is small)。
    case initFailed

    /// `bas_rust_tracker_append/query` returned -1
    /// (null pointer guard fired on Rust side — never
    /// expected at runtime,bridge always supplies
    /// valid pointers)。
    case nullPointer

    /// Rust-side internal error (lock poisoned,UTF-8
    /// decode failed,etc)。
    case rustInternalException

    /// JSON returned by `bas_rust_tracker_query` failed
    /// to decode as `[BASMemoryUsageRecord]` Codable。
    /// Indicates ABI / wire-format drift between Rust +
    /// Swift sides。
    case jsonDecodeFailed(message: String)

    /// Rust returned an unknown non-zero status code。
    case unknownReturnCode(Int32)

    /// Stable telemetry-friendly identifier for the error
    /// case discriminator,independent of associated value
    /// data。 See chapter 七百二十 / M2219 for the cross-
    /// pilot caseIdentifier contract。
    public var caseIdentifier: String {
        switch self {
        case .rustBridgeUnavailableOnPlatform:
            return "rustBridgeUnavailableOnPlatform"
        case .initFailed:
            return "initFailed"
        case .nullPointer:
            return "nullPointer"
        case .rustInternalException:
            return "rustInternalException"
        case .jsonDecodeFailed:
            return "jsonDecodeFailed"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

#if os(iOS) || os(macOS)

/// Real actor wrapping the Rust ABI on platforms where
/// the XCFramework slice is available。
public actor BASRustMemoryUsageTrackerActor {

    /// Sampled-once flag snapshot at construction time。
    private let useRustCore: Bool

    /// Opaque Rust handle。 nil when V1 path selected
    /// (no init called) OR when init failed。
    ///
    /// `nonisolated(unsafe)` mirrors the chapter 二百四十八
    /// (M735) / chapter 二百五十一 (M738) BASMemoryUsage
    /// Tracker SQLite handle pattern — required because
    /// the deinit must release the Rust-side
    /// `Box<Tracker>` and Swift 6 strict concurrency
    /// blocks non-Sendable access from nonisolated
    /// deinit otherwise。 Safe because the pointer is
    /// only ever mutated inside init (single-writer)
    /// and dropped in deinit (no other access can
    /// race after deinit fires)。
    private nonisolated(unsafe) var handle: OpaquePointer?

    public init(useRustCore: Bool = false) throws {
        self.useRustCore = useRustCore
        guard useRustCore else {
            // V1 path:no Rust handle created。
            self.handle = nil
            return
        }
        // V2 path:init Rust tracker。 The C function
        // signature returns `Tracker*` which Swift
        // imports as `OpaquePointer?`。
        guard let raw = bas_rust_tracker_init() else {
            throw BASRustMemoryUsageTrackerActorError
                .initFailed
        }
        self.handle = raw
    }

    deinit {
        if let h = handle {
            // Safe to call from deinit;Rust side just
            // drops the Box<Tracker>。
            _ = bas_rust_tracker_close(
                h)
        }
    }

    public var isUsingRustCore: Bool { useRustCore }

    // MARK: - V2 surface

    /// Append one record。 V1 path throws
    /// .rustBridgeUnavailableOnPlatform。
    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) throws -> String {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let recordID = UUID().uuidString
        let helped = BASMemoryUsageRecord.HelpedFlag
            .unknown.rawValue
        let retrievedMs = Int64(
            retrievedAt.timeIntervalSince1970 * 1000)
        let rc = recordID.withCString { ridPtr in
            atomID.withCString { aidPtr in
                sessionRef.withCString { sPtr in
                    turnRef.withCString { tPtr in
                        permitMode.withCString { pmPtr in
                            helped.withCString { hPtr in
                                bas_rust_tracker_append(
                                    h,
                                    ridPtr,
                                    aidPtr,
                                    retrievedMs,
                                    sPtr,
                                    tPtr,
                                    pmPtr,
                                    hPtr)
                            }
                        }
                    }
                }
            }
        }
        switch rc {
        case 0: return recordID
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
    }

    /// Current Rust-side record count snapshot。
    public func recordCount() throws -> Int {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let n = bas_rust_tracker_size(
            h)
        if n < 0 {
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        }
        return Int(n)
    }

    /// Decode all records via the Rust query API。 Mirrors
    /// V1 `BASMemoryUsageTracker.allRecords()` shape +
    /// sort order (ascending by retrievedAt)。
    public func allRecords() throws -> [BASMemoryUsageRecord] {
        return try queryRecords(forAtomID: "")
    }

    /// 主线 解构 重构 Round 3 — push the atom-id filter
    /// into the existing Rust FFI。 The `bas_rust_tracker_
    /// query` C function already accepts an atom_id arg
    /// (empty string = all records,non-empty = filter by
    /// that atom_id)。 Before this commit the Swift wrapper
    /// only ever passed empty string,doing any filtering
    /// in Swift after pulling the full JSON。 This commit
    /// pushes the WHERE-like operation into the Rust side。
    ///
    /// Mirrors the SQL pilot's `recentRecordsForAtomViaSQL`
    /// semantics:return only rows for one atom_id,without
    /// materializing the full record set in Swift。
    public func recordsForAtom(
        atomID: String
    ) throws -> [BASMemoryUsageRecord] {
        return try queryRecords(forAtomID: atomID)
    }

    // MARK: - 主线 全面 开发: Rust-native aggregation FFI

    /// Aggregation ABI version pin matching the Rust-side
    /// `bas_rust_tracker_aggregation_version`。 Distinct
    /// from `cargoCrateABIVersion` so future aggregation
    /// surface changes don't bump the main pin (which
    /// would invalidate existing wire-format byte-equality
    /// tests)。
    public static let aggregationABIVersion: Int32 = 1

    /// Live Rust-side aggregation ABI version read。
    public static func liveAggregationABIVersion() -> Int32 {
        return bas_rust_tracker_aggregation_version()
    }

    /// 主线 全面 开发 — native Rust-side aggregation。
    /// Iterates the HashMap inside Rust under one read
    /// lock,emits a JSON `{"permit_mode": count, ...}`
    /// map sorted alphabetically by key (byte-equality
    /// deterministic across runs)。
    ///
    /// Before this commit,
    /// `BASRustBrainHistoryStore.recordCountByPermitMode`
    /// did `tracker.allRecords()` (full record query)
    /// then folded in Swift。 This commit pushes the
    /// aggregation into Rust where the data lives。
    public func recordCountByPermitMode() throws
        -> [String: Int]
    {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        return try fetchCountMap { outBuf, outLen in
            bas_rust_tracker_count_by_permit_mode(
                h, outBuf, outLen)
        }
    }

    /// Counterpart of `recordCountByPermitMode` grouping
    /// by session_ref instead of permit_mode。
    public func recordCountBySession() throws
        -> [String: Int]
    {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        return try fetchCountMap { outBuf, outLen in
            bas_rust_tracker_count_by_session(
                h, outBuf, outLen)
        }
    }

    /// Number of distinct session_ref values across all
    /// records, computed by a HashSet pass inside Rust
    /// under one read lock。 Throws if the Rust core is
    /// unavailable or if the call returns negative。
    public func distinctSessionCount() throws -> Int {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let n = bas_rust_tracker_distinct_sessions(h)
        if n < 0 {
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        }
        return Int(n)
    }

    /// 持续性 发展 — top-K most-frequent atoms via Rust-
    /// native HashMap iteration + partial sort under one
    /// read lock。 Returns up to `limit` entries sorted
    /// descending by count,alphabetical tie-break on
    /// equal counts (byte-equality deterministic)。
    ///
    /// Doing this from Swift would require pulling the
    /// full record set, folding by atomID, then sorting
    /// in Swift — N+1 allocations + O(N) Swift work。
    /// In Rust it's one read lock + one map iteration +
    /// partial sort + JSON encode。 术业有专攻。
    ///
    /// 主线 核心 抽取 — Memory Importance Scorer in Rust。
    /// Computes the chapter 二百五十二 score formula
    /// per atom under one read lock + returns the array
    /// sorted descending by score。 Real cascade math
    /// (not just observability) — drives tier promotion
    /// + forget cascade decisions in Rust now,not Swift。
    ///
    /// - Parameters:
    ///   - now:reference time for recency decay
    ///   - halfLife:exponential half-life for the
    ///     recency factor (>= 1 millisecond)
    public func atomImportanceScores(
        now: Date,
        halfLife: TimeInterval
    ) throws -> [BASAtomImportanceEntry] {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let nowMs = Int64(
            now.timeIntervalSince1970 * 1000)
        let hlMs = Int64(max(1, halfLife * 1000))
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let rc =
            bas_rust_tracker_atom_importance_scores(
                h, nowMs, hlMs, &outBuf, &outLen)
        switch rc {
        case 0: break
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
        guard let outBuf else { return [] }
        defer { bas_rust_tracker_free_buffer(outBuf, outLen) }
        let data = Data(bytes: outBuf, count: outLen)
        do {
            return try JSONDecoder().decode(
                [BASAtomImportanceEntry].self,
                from: data)
        } catch {
            throw BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// 主线 核心 抽取 — Forget Cascade decision FFI。
    /// Returns the atomIDs falling below the retention
    /// threshold (top `retainFraction` of distinct atoms
    /// by importance score are kept,rest are returned
    /// as candidates for forget)。
    ///
    /// retainFraction is clamped to [0.0, 1.0] in Rust。
    public func forgetCandidates(
        now: Date,
        halfLife: TimeInterval,
        retainFraction: Double
    ) throws -> [String] {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let nowMs = Int64(
            now.timeIntervalSince1970 * 1000)
        let hlMs = Int64(max(1, halfLife * 1000))
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let rc =
            bas_rust_tracker_forget_candidates(
                h, nowMs, hlMs, retainFraction,
                &outBuf, &outLen)
        switch rc {
        case 0: break
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
        guard let outBuf else { return [] }
        defer { bas_rust_tracker_free_buffer(outBuf, outLen) }
        let data = Data(bytes: outBuf, count: outLen)
        do {
            return try JSONDecoder().decode(
                [String].self, from: data)
        } catch {
            throw BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// 主线 Integrity 抽取 — validator variant of the
    /// chain hash。 Compares the live tracker against
    /// an expected 32-byte hash inside Rust,saving
    /// hosts the byte-by-byte comparison。
    ///
    /// Returns true on match,false on mismatch
    /// (tamper / drift detected)。 Throws on null /
    /// internal errors。
    public func verifyChainHash(
        expected: Data
    ) throws -> Bool {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        guard expected.count == 32 else {
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(-99)
        }
        let rc = expected.withUnsafeBytes { raw -> Int32 in
            let ptr = raw.bindMemory(to: UInt8.self)
                .baseAddress!
            return bas_rust_tracker_verify_chain_hash(
                h, ptr)
        }
        switch rc {
        case 1: return true
        case 0: return false
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
    }

    /// 主线 Integrity 抽取 — compute the canonical chain
    /// hash over all records inside Rust。 Returns the
    /// 32-byte SHA256 digest as Data。 Hosts compare this
    /// against an expected value to detect tampering or
    /// drift across replicas。
    ///
    /// Algorithm:Rust walks the HashMap under read lock,
    /// sorts by (retrieved_at_ms, record_id),feeds each
    /// record's bytes length-prefixed into SHA256,
    /// returns the digest。 Empty tracker → SHA256 of
    /// empty bytes (well-known constant)。
    ///
    /// Deterministic:two trackers with identical records
    /// in any insertion order produce identical hashes。
    public func computeChainHash() throws -> Data {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        var hash = [UInt8](repeating: 0, count: 32)
        let rc = hash.withUnsafeMutableBufferPointer {
            ptr -> Int32 in
            bas_rust_tracker_compute_chain_hash(
                h, ptr.baseAddress!)
        }
        switch rc {
        case 0:
            return Data(hash)
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
    }

    /// 全面 开发 — retrieval-interval distribution
    /// percentiles via Rust-native sort + delta +
    /// percentile under one read lock。 Returns p50 /
    /// p95 / p99 of the milliseconds-between-consecutive-
    /// retrievals distribution。
    ///
    /// Hosts use this to characterize traffic rhythm:
    /// p50 = typical inter-call gap,p99 = "what's the
    /// longest quiet period" outlier。
    ///
    /// Sentinel -1 for all three when fewer than 2
    /// records (no interval can be computed)。
    public func retrievalIntervalPercentiles() throws
        -> BASRetrievalIntervalPercentiles
    {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        var p50: Int64 = 0
        var p95: Int64 = 0
        var p99: Int64 = 0
        let rc =
            bas_rust_tracker_retrieval_interval_percentiles(
                h, &p50, &p95, &p99)
        switch rc {
        case 0:
            return BASRetrievalIntervalPercentiles(
                p50Millis: p50,
                p95Millis: p95,
                p99Millis: p99)
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
    }

    /// 持续性 发展 — atom-count distribution percentiles
    /// via Rust-native sort under one read lock。 Returns
    /// p50 / p95 / p99 of count-per-atom values。
    ///
    /// Doing this from Swift would require pulling every
    /// record,folding by atomID,then sorting the count
    /// values — O(N log N) Swift work + N+1 allocations。
    /// Rust does it under one lock with a single Vec
    /// sort。 术业有专攻。
    public func atomCountPercentiles() throws
        -> BASAtomCountPercentiles
    {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        var p50: Int64 = 0
        var p95: Int64 = 0
        var p99: Int64 = 0
        let rc =
            bas_rust_tracker_atom_count_percentiles(
                h, &p50, &p95, &p99)
        switch rc {
        case 0:
            return BASAtomCountPercentiles(
                p50: p50, p95: p95, p99: p99)
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
    }

    /// limit == 0 returns empty array; limit > distinct
    /// atoms returns ALL atoms (no padding)。
    public func topKAtoms(
        limit: Int
    ) throws -> [BASTopAtomEntry] {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let rc = bas_rust_tracker_top_k_atoms(
            h, max(0, limit), &outBuf, &outLen)
        switch rc {
        case 0: break
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
        guard let outBuf else { return [] }
        defer { bas_rust_tracker_free_buffer(outBuf, outLen) }
        let data = Data(bytes: outBuf, count: outLen)
        do {
            return try JSONDecoder().decode(
                [BASTopAtomEntry].self, from: data)
        } catch {
            throw BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// Internal helper for the two count-map FFI calls。
    /// Both emit JSON `{"key": count, ...}` byte buffers
    /// that need the same decode + free-buffer wrap。
    private func fetchCountMap(
        ffiCall: (UnsafeMutablePointer<
            UnsafeMutablePointer<UInt8>?>,
            UnsafeMutablePointer<Int>) -> Int32
    ) throws -> [String: Int] {
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let rc = ffiCall(&outBuf, &outLen)
        switch rc {
        case 0: break
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
        guard let outBuf else { return [:] }
        defer { bas_rust_tracker_free_buffer(outBuf, outLen) }
        let data = Data(bytes: outBuf, count: outLen)
        do {
            // Rust emits JSON `{"key": 123, ...}`。 i64
            // values fit Swift Int on 64-bit platforms,
            // so decoding as [String: Int] is lossless。
            return try JSONDecoder().decode(
                [String: Int].self, from: data)
        } catch {
            throw BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// Internal helper shared by `allRecords` (empty atomID)
    /// and `recordsForAtom` (specific atomID)。 Calls the
    /// Rust FFI with the atom_id arg + decodes the JSON
    /// response。
    private func queryRecords(
        forAtomID atomID: String
    ) throws -> [BASMemoryUsageRecord] {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let rc: Int32 = atomID.withCString { keyPtr in
            bas_rust_tracker_query(
                h,
                keyPtr,
                &outBuf,
                &outLen)
        }
        switch rc {
        case 0: break
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
        guard let outBuf else { return [] }
        defer { bas_rust_tracker_free_buffer(outBuf, outLen) }
        let data = Data(
            bytes: outBuf, count: outLen)
        do {
            return try Self.decodeRecords(data: data)
        } catch {
            throw BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// Decode the Rust-side JSON output to a Swift
    /// [BASMemoryUsageRecord]。 Rust emits
    /// `retrievedAtMs: Int64` (epoch ms);Swift Codable
    /// default expects `retrievedAt: Date` ISO-8601 —
    /// custom decoding bridges the formats so the V1
    /// + V2 paths produce identical
    /// [BASMemoryUsageRecord] sequences。
    fileprivate static func decodeRecords(
        data: Data
    ) throws -> [BASMemoryUsageRecord] {
        struct RustRow: Decodable {
            let atomID: String
            let helpedFlag: String
            let permitMode: String
            let retrievedAtMs: Int64
            let recordID: String
            let schemaVersion: String
            let sessionRef: String
            let turnRef: String
        }
        let rows = try JSONDecoder().decode(
            [RustRow].self, from: data)
        return rows.map { row in
            BASMemoryUsageRecord(
                schemaVersion: row.schemaVersion,
                recordID: row.recordID,
                atomID: row.atomID,
                retrievedAt: Date(
                    timeIntervalSince1970:
                        Double(row.retrievedAtMs) / 1000),
                sessionRef: row.sessionRef,
                turnRef: row.turnRef,
                permitMode: row.permitMode,
                helpedFlag: BASMemoryUsageRecord
                    .HelpedFlag(rawValue: row.helpedFlag)
                    ?? .unknown)
        }
    }
}

#else

/// Stub on platforms where the XCFramework is unavailable
/// (watchOS,Linux build hosts)。 Every method throws
/// `.rustBridgeUnavailableOnPlatform`。 Lets the rest
/// of the substrate compile cleanly on watchOS。
public actor BASRustMemoryUsageTrackerActor {

    public init(useRustCore: Bool = false) throws {
        // Always throw on watchOS / Linux — there is no
        // path that doesn't require the binary。
        if useRustCore {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        // V1 path stub:no init,no state。
    }

    public var isUsingRustCore: Bool { false }

    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) throws -> String {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func recordCount() throws -> Int {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func allRecords() throws -> [BASMemoryUsageRecord] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func recordsForAtom(
        atomID: String
    ) throws -> [BASMemoryUsageRecord] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func recordCountByPermitMode() throws
        -> [String: Int]
    {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func recordCountBySession() throws
        -> [String: Int]
    {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func distinctSessionCount() throws -> Int {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func topKAtoms(
        limit: Int
    ) throws -> [BASTopAtomEntry] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func atomCountPercentiles() throws
        -> BASAtomCountPercentiles
    {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func atomImportanceScores(
        now: Date,
        halfLife: TimeInterval
    ) throws -> [BASAtomImportanceEntry] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func forgetCandidates(
        now: Date,
        halfLife: TimeInterval,
        retainFraction: Double
    ) throws -> [String] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func retrievalIntervalPercentiles() throws
        -> BASRetrievalIntervalPercentiles
    {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func computeChainHash() throws -> Data {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func verifyChainHash(
        expected: Data
    ) throws -> Bool {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }
}

#endif

// MARK: - Flag-aware factory

extension BASRustMemoryUsageTrackerActor {

    /// Async factory consulting
    /// `BASLanguageAugmentationFeatureFlags
    /// .rustCoreEnabled` to choose path。
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async throws -> BASRustMemoryUsageTrackerActor {
        let useRust = await flags.isEnabled(.rustCoreEnabled)
        return try BASRustMemoryUsageTrackerActor(
            useRustCore: useRust)
    }

    /// M2205 chapter 七百十三 第一刀 — host adoption
    /// convenience。 Returns the V2 Rust-backed path
    /// because chapter 七百十二 production wire-in
    /// flipped `rustCoreEnabled` to default-true。
    public static func makeWithDefaults() async throws -> BASRustMemoryUsageTrackerActor {
        let flags = BASLanguageAugmentationFeatureFlags()
        return try await make(flags: flags)
    }
}
