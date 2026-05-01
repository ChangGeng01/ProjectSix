import Foundation
import BASObservability
import BASRuntimeCore
import BASSovereign

/// M357 — bench mode for sovereign audit ledger append latency.
///
/// Measures `BASSovereignAuditLedger.append(_:)` per-call latency
/// across N entries. Default 10,000 entries (much larger than
/// M334's 100-turn state-machine bench).
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. The numbers measure
/// in-process audit ledger append + Ed25519 signature
/// computation only. They are NOT customer-facing latency
/// commitments.
///
/// What the bench measures:
///   - Per-entry append latency (compute Ed25519 signature,
///     append to in-memory chain, update audit-ref index)
///   - Storage: in-memory only (no SQLite I/O — that's M91
///     territory and would dominate / vary with disk speed)
///
/// What the bench does NOT measure:
///   - SQLite persistence overhead
///   - Network propagation
///   - Cross-process verification
///
/// ## Output
///
/// `BASBenchLatencyStats` (M355) with p50/p95/p99/p99.9/max/min/
/// mean/stddev/outliers. Caller may compare to a baseline JSON
/// via M356 `BASBenchBaselineStorage`.
public struct AuditLedgerBench {

    public static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "in-process audit ledger append + Ed25519 signature " +
        "compute only — no SQLite I/O, no network, no actor " +
        "hops across runtime layers. do not quote these numbers " +
        "as customer-facing latency."

    public struct Outcome: Sendable, Equatable {
        public let entryCount: Int
        public let elapsedSeconds: Double
        public let latency: BASBenchLatencyStats
        public init(
            entryCount: Int,
            elapsedSeconds: Double,
            latency: BASBenchLatencyStats
        ) {
            self.entryCount = entryCount
            self.elapsedSeconds = elapsedSeconds
            self.latency = latency
        }
    }

    /// Run the bench: build a fresh Ed25519-backed ledger and
    /// append `entryCount` entries, measuring per-entry latency
    /// in milliseconds.
    public static func run(
        entryCount: Int = 10_000
    ) async throws -> Outcome {
        let ledger = try BASSovereignAuditLedger
            .withEd25519Seed("bench-m357-seed")
        var samplesMs = [Double]()
        samplesMs.reserveCapacity(entryCount)

        let startWall = Date()
        for i in 0..<entryCount {
            let entry = makeEntry(index: i)
            let t0 = Date()
            _ = try await ledger.append(entry)
            let elapsedMs = Date()
                .timeIntervalSince(t0) * 1000.0
            samplesMs.append(Swift.max(0, elapsedMs))
        }
        let elapsedSeconds = Date()
            .timeIntervalSince(startWall)

        let stats = BASBenchLatencyStats.compute(
            samples: samplesMs)
            ?? BASBenchLatencyStats(
                sampleCount: 0, min: 0, max: 0, mean: 0,
                p50: 0, p95: 0, p99: 0, p999: 0,
                standardDeviation: 0, outlierCount: 0)
        return Outcome(
            entryCount: entryCount,
            elapsedSeconds: elapsedSeconds,
            latency: stats)
    }

    /// Build a deterministic audit entry for the bench. Each
    /// entry has a unique audit ID; otherwise fields are static
    /// to keep the bench focused on append cost not entry
    /// construction cost.
    private static func makeEntry(
        index: Int
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: "bench.audit.\(index)",
            sessionID: "bench-session-\(index / 100)",
            turnID: "bench-turn-\(index)",
            verdictRef: "bench-verdict",
            ruleIDs: ["BR-001"],
            signalRefs: ["bench.signal:\(index)"],
            actionRefs: [],
            snapshotRef: "bench-snap",
            actor: .system,
            signature: "",
            appendedAt: Date(
                timeIntervalSince1970:
                    1_700_000_000 + Double(index)))
    }
}
