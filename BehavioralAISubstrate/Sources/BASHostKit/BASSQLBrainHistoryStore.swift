// MARK: - BASSQLBrainHistoryStore
// SQL pilot integration:wraps BASMemoryUsageTracker
// (chapter 702 SQL pilot) for SQLite-backed history of
// brain summary() calls。
//
// Each brain.summary() call optionally writes one
// BASMemoryUsageRecord via BASMemoryUsageTracker:
//
//   - atomID:     SHA256-prefix hex of input (deterministic
//                 → same input collapses to same atomID)
//   - sessionRef: brain instance UUID
//   - turnRef:    monotonic per-brain turn counter
//   - permitMode: summary.safetyVerdict.rawValue
//                 (\"safe\" / \"warn\" / \"block\")
//
// **Why use BASMemoryUsageTracker**: this is the literal SQL
// pilot from chapter 702 (M2171-M2174). Before this commit
// it had no real consumer in the cognitive brain — just a
// pilot existence。 After this commit, real Swift→SQLite
// inserts happen on every brain.summary() call when the
// store is wired in。
//
// **Honest scope acknowledgments**:
//   - SQL pilot's schema is for *memory atom* usage tracking,
//     not arbitrary KV persistence。 The mapping
//     (input → atomID via hash) fits the schema but isn't
//     a perfect semantic match — a typed-summary table
//     would be a separate Phase D-real artifact。
//   - helpedFlag stays .unknown (no post-LLM feedback path
//     wired yet — host integration may call markHelped()
//     later via the underlying tracker)
//   - Persistence requires the host to construct the brain
//     with a non-nil databaseURL; in-memory mode loses
//     history on brain dealloc

import Foundation
import BASMemory
import CryptoKit

/// SQL-backed brain summary history store。 Wraps the
/// chapter 702 SQL pilot (BASMemoryUsageTracker)。
public actor BASSQLBrainHistoryStore {

    /// Stable session identifier for all records appended
    /// during this brain instance's lifetime。 New UUID
    /// per init so cross-instance queries can separate
    /// runs。
    public let sessionRef: String

    /// Monotonic turn counter。 Starts at 0,increments on
    /// every `recordSummary(_:)` call。
    private var turnCounter: Int = 0

    private let tracker: BASMemoryUsageTracker

    /// Sentinel value for permitMode when no safety
    /// verdict is available (defensive default — should
    /// not occur on the brain summary path)。
    public static let unknownPermitMode: String = "unknown"

    /// Deterministic hash function for atomID derivation。
    /// SHA256-prefix hex (first 16 chars = first 8 bytes
    /// of SHA256)。 Same input → same atomID,enabling
    /// `usageCount(forAtomID:)` queries from the underlying
    /// tracker。
    public static func atomID(forInput input: String)
        -> String
    {
        let digest = SHA256.hash(
            data: Data(input.utf8))
        var hex = ""
        hex.reserveCapacity(16)
        var emitted = 0
        for byte in digest {
            hex += String(
                format: "%02x", byte)
            emitted += 1
            if emitted >= 8 { break }
        }
        return hex
    }

    public init(tracker: BASMemoryUsageTracker) {
        self.tracker = tracker
        self.sessionRef = UUID().uuidString
    }

    /// Persist one brain summary as a memory-atom usage
    /// record。 Returns the underlying tracker's recordID
    /// for later `markHelped()` calls。
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

    /// Total persisted records (any session) seen by the
    /// underlying tracker。
    public var recordCount: Int {
        get async { await tracker.recordCount }
    }

    /// Number of distinct turns recorded by THIS brain
    /// instance (i.e. since `init`)。 Differs from
    /// `recordCount` when the host pre-populated the
    /// tracker with prior-session data。
    public var turnsThisSession: Int {
        return turnCounter
    }

    /// Read the N most-recent records from the tracker
    /// (across all sessions)。 Newest first by
    /// retrievedAt timestamp。
    public func recentRecords(
        limit: Int
    ) async -> [BASMemoryUsageRecord] {
        let all = await tracker.allRecords()
        let sorted = all.sorted {
            $0.retrievedAt > $1.retrievedAt
        }
        let take = min(max(0, limit), sorted.count)
        return Array(sorted.prefix(take))
    }

    /// Count how many times a given input has been seen
    /// (across all sessions) per the SQL pilot's
    /// usageCount API。 Useful for deduplication +
    /// "how often does this manipulation attempt repeat"
    /// telemetry。
    public func usageCount(
        forInput input: String
    ) async -> Int {
        let atomID = Self.atomID(forInput: input)
        return await tracker
            .usageCount(forAtomID: atomID)
    }
}
