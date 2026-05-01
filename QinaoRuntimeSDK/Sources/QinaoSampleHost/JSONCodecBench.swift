import Foundation
import BASRuntimeCore
import BASObservability

/// M365 — bench mode for `BASSovereignAuditEntry` JSON
/// encode/decode round-trip throughput.
///
/// JSON serialization is on the hot path for audit ledger
/// persistence (M91 SQLite storage) and cross-process verifier
/// (M87 Ed25519 paths). M365 measures the codec round-trip cost
/// per audit entry — encode → decode — as a substrate-internal
/// reference for any future PR that touches the entry schema or
/// serialization path.
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. Numbers measure pure
/// in-process JSON encode + decode round-trip — no I/O, no
/// network, no actor hops.
public struct JSONCodecBench {

    public static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "pure in-process BASSovereignAuditEntry JSON " +
        "encode + decode round-trip — no I/O, no network, " +
        "no actor hops. do not quote these numbers as " +
        "customer-facing latency."

    public struct Outcome: Sendable, Equatable {
        public let roundTripCount: Int
        public let entrySerializedBytes: Int
        public let elapsedSeconds: Double
        public let outcome: BASBenchWarmupOutcome
        public init(
            roundTripCount: Int,
            entrySerializedBytes: Int,
            elapsedSeconds: Double,
            outcome: BASBenchWarmupOutcome
        ) {
            self.roundTripCount = roundTripCount
            self.entrySerializedBytes = entrySerializedBytes
            self.elapsedSeconds = elapsedSeconds
            self.outcome = outcome
        }
    }

    /// M370 chapter 八十四 evolution: cache encoder + decoder
    /// instances. Pre-M370 each `run(...)` call constructed
    /// fresh JSONEncoder + JSONDecoder which dominated cold
    /// samples (chapter 八十三.4 smoke: cold 343 µs vs warm
    /// 21 µs, 16x ratio). M370 hoists construction to static
    /// lazy properties so the encoder/decoder live for the
    /// process lifetime; cold/warm split shrinks because the
    /// first round-trip no longer pays construction cost.
    private static let cachedEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let cachedDecoder = JSONDecoder()

    /// Drive `roundTripCount` encode-then-decode cycles on a
    /// representative audit entry. Reports per-cycle latency
    /// in milliseconds.
    public static func run(
        roundTripCount: Int = 50_000
    ) throws -> Outcome {
        let entry = makeRepresentativeEntry()
        let encoder = cachedEncoder
        let decoder = cachedDecoder

        // Compute serialized size once for output.
        let probe = try encoder.encode(entry)
        let entryBytes = probe.count

        var samplesMs: [Double] = []
        samplesMs.reserveCapacity(roundTripCount)
        // M376 — high-res clock; nanosecond precision needed to
        // see encode/decode below the Date floor.
        let clock = BASBenchHighResClock()
        let startWall = Date()
        for _ in 0..<roundTripCount {
            let elapsedMs = try clock.measureMilliseconds {
                let data = try encoder.encode(entry)
                _ = try decoder.decode(
                    BASSovereignAuditEntry.self,
                    from: data)
            }
            samplesMs.append(Swift.max(0, elapsedMs))
        }
        let elapsedSeconds = Date()
            .timeIntervalSince(startWall)

        let outcome = BASBenchWarmupOutcome.compute(
            samples: samplesMs,
            config: .strictFirstSample)
            ?? BASBenchWarmupOutcome(
                combined: BASBenchLatencyStats(
                    sampleCount: 0, min: 0, max: 0,
                    mean: 0, p50: 0, p95: 0, p99: 0,
                    p999: 0,
                    standardDeviation: 0,
                    outlierCount: 0),
                cold: nil, warm: nil,
                config: .strictFirstSample)
        return Outcome(
            roundTripCount: roundTripCount,
            entrySerializedBytes: entryBytes,
            elapsedSeconds: elapsedSeconds,
            outcome: outcome)
    }

    /// Build a representative audit entry — typical session
    /// shape with ~5 ruleIDs and ~5 signal refs. Roughly the
    /// median size we expect in production.
    private static func makeRepresentativeEntry()
        -> BASSovereignAuditEntry
    {
        BASSovereignAuditEntry(
            auditID: "bench.audit.representative",
            sessionID:
                "bench-session-representative",
            turnID: "bench-turn-1",
            verdictRef: "bench-verdict-1",
            ruleIDs: [
                "BR-001", "BR-002", "BR-003",
                "BR-004", "BR-005",
            ],
            signalRefs: [
                "frontier.status:dominant-clear",
                "tribunal.status:full-body-converged",
                "lifecycle.tickets:1",
                "lifecycle.promoted:0",
                "humanAnchor.tone:stable",
            ],
            actionRefs: [],
            snapshotRef: "bench-snapshot-1",
            actor: .system,
            signature:
                "bench-signature-placeholder-string-of-some-length",
            appendedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
    }
}
