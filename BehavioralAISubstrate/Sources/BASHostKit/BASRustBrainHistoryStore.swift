// MARK: - BASRustBrainHistoryStore
// Rust pilot integration: wraps BASRustMemoryUsageTracker
// Actor (chapter 706 Rust pilot,XCFramework-vendored
// Rust core) as an alternative to BASSQLBrainHistoryStore
// for hosts that want fast in-process telemetry without
// SQLite durability。
//
// **Why this exists**: chapter 706 shipped the Rust
// pilot but no brain consumer wired it in。 After the
// 主线 push integrated SQL pilot (Swift+SQLite),C
// pilot (latency clock),and C++ pilot (Codable JSON
// cache),the Rust pilot remained scaffolded but
// unused。 This commit makes it a real,host-injectable
// brain history backend。
//
// **Mapping** (identical to BASSQLBrainHistoryStore
// for stable cross-backend behavior):
//
//   - atomID:     SHA256-prefix hex of input
//   - sessionRef: brain instance UUID
//   - turnRef:    monotonic per-brain turn counter
//   - permitMode: summary.safetyVerdict.rawValue
//
// **Pick this over SQL when**:
//   - You don't need cross-process durability
//   - You want sub-microsecond writes (Rust in-memory
//     vs SQLite WAL)
//   - You're aggregating telemetry within one process
//
// **Pick SQL when**:
//   - Cross-process / cross-launch durability matters
//   - You want SQLite query language access
//   - You want the broader BASMemoryUsageTracker
//     surface (markHelped, recentRecords, purge)
//
// **Both at once is fine**: pass both to brain init;
// every summary() writes to both stores。

import Foundation
import CryptoKit
import BASMemory
import BASRustCoreBridge

/// Rust-backed brain summary history store。 Wraps the
/// chapter 706 Rust pilot (BASRustMemoryUsageTrackerActor)。
public actor BASRustBrainHistoryStore {

    /// Stable session identifier — new UUID per init,
    /// matches BASSQLBrainHistoryStore semantics。
    public let sessionRef: String

    /// Monotonic turn counter。 Starts at 0,increments
    /// on every `recordSummary(_:)` call。
    private var turnCounter: Int = 0

    private let tracker: BASRustMemoryUsageTrackerActor

    /// Same SHA256-prefix algorithm as BASSQLBrainHistory
    /// Store。 Hosts using BOTH backends get IDENTICAL
    /// atomID values for identical inputs — enables
    /// cross-store joins / dedup。
    ///
    /// 主线 解构:delegates to `BASBrainHistoryAtomID.derive`
    /// — the canonical single source of truth。 Cross-store
    /// joins on atomID remain byte-equal by construction。
    public static func atomID(forInput input: String)
        -> String
    {
        return BASBrainHistoryAtomID.derive(
            forInput: input)
    }

    public init(
        tracker: BASRustMemoryUsageTrackerActor
    ) {
        self.tracker = tracker
        self.sessionRef = UUID().uuidString
    }

    /// Persist one brain summary as a memory-atom
    /// usage record via the Rust tracker。 Returns the
    /// underlying tracker's recordID。
    @discardableResult
    public func recordSummary(
        _ summary: BASCognitiveBrainSummary
    ) async throws -> String {
        turnCounter += 1
        let atomID = Self.atomID(
            forInput: summary.input)
        return try await tracker.record(
            atomID: atomID,
            sessionRef: sessionRef,
            turnRef: String(turnCounter),
            permitMode: summary.safetyVerdict.rawValue)
    }

    /// Total persisted records seen by the underlying
    /// Rust tracker。 Throws when the Rust core is
    /// unavailable (V1 mode or platform without XCFramework
    /// slice)。 Callers using `try?` get nil on those
    /// platforms。
    public var recordCount: Int {
        get async {
            (try? await tracker.recordCount()) ?? 0
        }
    }

    /// Number of distinct turns recorded by THIS brain
    /// instance (since `init`)。 Mirrors BASSQLBrain
    /// HistoryStore semantics — useful when the host
    /// pre-populated the tracker with prior-session
    /// records and wants to count THIS session only。
    public var turnsThisSession: Int {
        return turnCounter
    }

    /// Read the N most-recent records via the Rust
    /// tracker。 Newest first by retrievedAt timestamp。
    public func recentRecords(
        limit: Int
    ) async throws -> [BASMemoryUsageRecord] {
        let all = try await tracker.allRecords()
        let sorted = all.sorted {
            $0.retrievedAt > $1.retrievedAt
        }
        let take = min(max(0, limit), sorted.count)
        return Array(sorted.prefix(take))
    }

    /// Count how many times a given input has been seen
    /// across all stored records。
    public func usageCount(
        forInput input: String
    ) async throws -> Int {
        let atomID = Self.atomID(forInput: input)
        let all = try await tracker.allRecords()
        return all.filter { $0.atomID == atomID }.count
    }

    /// 主线 解构 重构 Round 3 — push the atom filter into
    /// Rust via the existing FFI atom_id arg。 The current
    /// `usageCount(forInput:)` pulls all records then folds
    /// Swift-side; this method asks Rust to return only
    /// records matching the atomID,then counts them。
    ///
    /// Same result,less Swift work,less wire data when
    /// most records belong to other atoms。
    public func usageCountViaRust(
        forInput input: String
    ) async throws -> Int {
        let atomID = Self.atomID(forInput: input)
        let filtered = try await tracker.recordsForAtom(
            atomID: atomID)
        return filtered.count
    }

    /// 主线 解构 重构 Round 3 — atom-scoped records via
    /// the Rust FFI's atom_id filter。 Mirrors the SQL
    /// pilot's `recentRecordsForInputViaSQL` shape so
    /// hosts can switch backends without changing call
    /// sites。 Returned records are sorted Rust-side
    /// ascending by retrievedAt (same as `allRecords()`)。
    public func recordsForInputViaRust(
        forInput input: String
    ) async throws -> [BASMemoryUsageRecord] {
        let atomID = Self.atomID(forInput: input)
        return try await tracker.recordsForAtom(
            atomID: atomID)
    }

    /// 持续性 发展 — top-K most-frequent atoms via the
    /// Rust-native FFI。 Returns BASTopAtomEntry array
    /// sorted descending by count,alphabetical tie-break。
    /// Hosts use this for "most-repeated input" leaderboards
    /// without pulling the full record set into Swift。
    public func topKAtoms(
        limit: Int
    ) async throws -> [BASTopAtomEntry] {
        return try await tracker.topKAtoms(limit: limit)
    }

    /// 持续性 发展 — atom-count distribution percentiles
    /// (p50 / p95 / p99) via Rust-native sort under one
    /// read lock。 Returns sentinel -1 values when no
    /// records exist。
    public func atomCountPercentiles() async throws
        -> BASAtomCountPercentiles
    {
        return try await tracker.atomCountPercentiles()
    }

    /// 主线 核心 抽取 — Memory Importance Scorer via Rust
    /// hard-core math。 Real chapter 二百五十二 算法 (count
    /// + recency + helped-rate) computed under one Rust
    /// read lock。 Returns array sorted descending by
    /// score。
    public func atomImportanceScores(
        now: Date = Date(),
        halfLife: TimeInterval = 24 * 3600
    ) async throws -> [BASAtomImportanceEntry] {
        return try await tracker.atomImportanceScores(
            now: now, halfLife: halfLife)
    }

    /// 主线 核心 抽取 — Forget Cascade decision via Rust
    /// hard-core math。 Returns atomIDs falling below the
    /// retain threshold for the host to forget。 Default
    /// retainFraction 0.8 keeps top 80% of distinct
    /// atoms。
    public func forgetCandidates(
        now: Date = Date(),
        halfLife: TimeInterval = 24 * 3600,
        retainFraction: Double = 0.8
    ) async throws -> [String] {
        return try await tracker.forgetCandidates(
            now: now,
            halfLife: halfLife,
            retainFraction: retainFraction)
    }

    /// 主线 Integrity 抽取 — Rust-computed SHA256 chain
    /// hash for tamper detection。 Returns the 32-byte
    /// digest hex-encoded as a lowercase string。 Hosts
    /// store this periodically + compare against future
    /// values to detect record-set drift。
    public func integrityChainHashHex() async throws
        -> String
    {
        let bytes = try await tracker.computeChainHash()
        var hex = ""
        hex.reserveCapacity(64)
        for byte in bytes {
            hex += String(format: "%02x", byte)
        }
        return hex
    }

    /// 主线 Integrity 抽取 — validator variant。 Compares
    /// the live tracker against the supplied hex hash
    /// (64 lowercase hex chars or `Data` with 32 bytes)
    /// inside Rust,returning the boolean result。
    /// Throws on hex-parse failure or Rust error。
    public func verifyChainHash(
        expectedHex: String
    ) async throws -> Bool {
        guard expectedHex.count == 64 else {
            throw BASRustLedgerCoreError
                .invalidInputSize
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(32)
        var index = expectedHex.startIndex
        for _ in 0..<32 {
            let next = expectedHex.index(
                index, offsetBy: 2)
            let byteHex = String(expectedHex[index..<next])
            guard let b = UInt8(byteHex, radix: 16)
            else {
                throw BASRustLedgerCoreError
                    .invalidInputSize
            }
            bytes.append(b)
            index = next
        }
        return try await tracker.verifyChainHash(
            expected: Data(bytes))
    }

    // MARK: - 主线 全面 提升: Rust-side aggregations

    /// Records grouped by permit mode (i.e. by safety
    /// verdict)。 Hosts use this for safety-dashboard
    /// rollups:
    ///   - "how many .block verdicts this session?"
    ///   - "how many .warn?"
    ///   - "how many .safe?"
    ///
    /// 主线 全面 开发:now uses the Rust-native aggregation
    /// FFI (`bas_rust_tracker_count_by_permit_mode`) —
    /// iterates the HashMap inside Rust under one read
    /// lock,returns a JSON map,Swift decodes that map
    /// instead of folding over the full record set。
    public func recordCountByPermitMode() async throws
        -> [String: Int]
    {
        return try await tracker
            .recordCountByPermitMode()
    }

    /// Records grouped by session reference。 Useful for
    /// multi-session brain hosts that want to report
    /// "how many turns per session" without scanning
    /// the records array manually。
    ///
    /// 主线 全面 开发:Rust-side native aggregation via
    /// `bas_rust_tracker_count_by_session`。
    public func recordCountBySession() async throws
        -> [String: Int]
    {
        return try await tracker.recordCountBySession()
    }

    /// Codable aggregation snapshot — bundles the two
    /// rollups + total count for one-call telemetry。
    /// 主线 全面 开发:每个 sub-aggregation 走 Rust 原生 FFI。
    public func aggregationSnapshot() async throws
        -> BASRustBrainHistoryStoreAggregation
    {
        let total = try await tracker.recordCount()
        let byPermit = try await tracker
            .recordCountByPermitMode()
        let bySession = try await tracker
            .recordCountBySession()
        let distinctSessions = try await tracker
            .distinctSessionCount()
        return BASRustBrainHistoryStoreAggregation(
            totalRecords: total,
            recordsByPermitMode: byPermit,
            recordsBySession: bySession,
            distinctSessions: distinctSessions)
    }
}

/// Codable aggregation snapshot from
/// BASRustBrainHistoryStore.aggregationSnapshot()。 Hosts
/// use this for dashboard / audit rollups。
public struct BASRustBrainHistoryStoreAggregation: Codable,
    Equatable, Sendable, Hashable
{
    /// Total records across all sessions / permit modes。
    public let totalRecords: Int

    /// Record count grouped by permit mode
    /// ("safe" / "warn" / "block")。
    public let recordsByPermitMode: [String: Int]

    /// Record count grouped by session UUID。
    public let recordsBySession: [String: Int]

    /// Number of distinct session UUIDs observed。
    public let distinctSessions: Int

    public init(
        totalRecords: Int,
        recordsByPermitMode: [String: Int],
        recordsBySession: [String: Int],
        distinctSessions: Int
    ) {
        self.totalRecords = totalRecords
        self.recordsByPermitMode = recordsByPermitMode
        self.recordsBySession = recordsBySession
        self.distinctSessions = distinctSessions
    }
}
