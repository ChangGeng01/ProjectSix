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

    // MARK: - 主线 全面 提升: Rust-side aggregations

    /// Records grouped by permit mode (i.e. by safety
    /// verdict)。 Hosts use this for safety-dashboard
    /// rollups:
    ///   - "how many .block verdicts this session?"
    ///   - "how many .warn?"
    ///   - "how many .safe?"
    ///
    /// Goes through the Rust core's `allRecords()` then
    /// aggregates Swift-side。 Future commits could push
    /// the aggregation into Rust for true zero-copy hot
    /// paths,but the Swift fold is fast enough at the
    /// current corpus sizes。
    public func recordCountByPermitMode() async throws
        -> [String: Int]
    {
        let all = try await tracker.allRecords()
        var counts: [String: Int] = [:]
        for record in all {
            counts[record.permitMode, default: 0] += 1
        }
        return counts
    }

    /// Records grouped by session reference。 Useful for
    /// multi-session brain hosts that want to report
    /// "how many turns per session" without scanning
    /// the records array manually。
    public func recordCountBySession() async throws
        -> [String: Int]
    {
        let all = try await tracker.allRecords()
        var counts: [String: Int] = [:]
        for record in all {
            counts[record.sessionRef, default: 0] += 1
        }
        return counts
    }

    /// Codable aggregation snapshot — bundles the two
    /// rollups + total count for one-call telemetry。
    public func aggregationSnapshot() async throws
        -> BASRustBrainHistoryStoreAggregation
    {
        let all = try await tracker.allRecords()
        var byPermit: [String: Int] = [:]
        var bySession: [String: Int] = [:]
        for record in all {
            byPermit[record.permitMode, default: 0] += 1
            bySession[record.sessionRef, default: 0] += 1
        }
        return BASRustBrainHistoryStoreAggregation(
            totalRecords: all.count,
            recordsByPermitMode: byPermit,
            recordsBySession: bySession,
            distinctSessions: bySession.count)
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
