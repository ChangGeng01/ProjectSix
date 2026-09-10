import Foundation
import BASRuntimeCore

/// `BR-03` ContaminationGuard — the sovereign quarantine registry.
///
/// ## Role in the sovereign loop
///
/// VerdictEngine can decide `QUARANTINE` for a particular artifact
/// (a memory atom, a host-vault entry, or a tool output). That decision
/// has to be *remembered* so that future retrieval paths refuse to
/// hand out the artifact. That memory lives here.
///
/// `BASMemoryHorizonPersistencePolicy.contaminatedWriteMode` handles
/// the **write-side** question ("how aggressively do we tag ingress
/// claims?"). The guard handles the **read-side** question ("is this
/// id currently quarantined by sovereign decree?") and the **feedback
/// loop** question ("was a quarantined artifact just proposed for
/// reuse, triggering BR-003 memoryContaminationSpread?").
///
/// Scoping mirrors `BASSovereignLockScope`:
/// - `artifactID` identifies the item (memory atom id, host vault
///   version id, tool output hash, etc.)
/// - `kind` distinguishes memory / host / tool / retrieval channels,
///   so a quarantined tool output doesn't accidentally block a
///   same-named memory atom and vice versa.
///
/// Fail-closed: if the guard has no record, the item is considered
/// *clean*. Quarantine is an explicit signal. This is the inverse of
/// IntegritySentinel's policy because here the default world is
/// "everything is fine unless we've said otherwise" — making the
/// guard a targeted block-list rather than an allow-list.
public actor BASSovereignContaminationGuard {
    public enum ArtifactKind:
        String, Sendable, Equatable, CaseIterable, Codable
    {
        /// Memory atoms / ThoughtFold refs / L8 cache entries.
        case memoryAtom
        /// L5 Host Constitution vault entries.
        case hostVaultEntry
        /// Tool call outputs (network, filesystem, device I/O).
        case toolOutput
        /// Retrieval channels (WorldPrior horizons, DomainBridge hops).
        case retrievalChannel
    }

    public struct Key: Hashable, Sendable, Codable {
        public let id: String
        public let kind: ArtifactKind

        public init(id: String, kind: ArtifactKind) {
            self.id = id
            self.kind = kind
        }
    }

    public struct QuarantineRecord:
        Sendable, Equatable, Codable
    {
        public let key: Key
        public let reasonCode: String
        public let originatingVerdictID: String?
        public let quarantinedAt: Date

        public init(
            key: Key,
            reasonCode: String,
            originatingVerdictID: String?,
            quarantinedAt: Date
        ) {
            self.key = key
            self.reasonCode = reasonCode
            self.originatingVerdictID = originatingVerdictID
            self.quarantinedAt = quarantinedAt
        }
    }

    public struct ProbeReport: Sendable, Equatable, Codable {
        public let quarantinedIDs: [String]
        public let cleanIDs: [String]
        /// True iff any member of the probe batch hit a quarantined
        /// record. Callers wire this straight into
        /// `HardObservations.memoryContaminationSpread`.
        public var hasQuarantinedHits: Bool { !quarantinedIDs.isEmpty }
    }

    // MARK: - State

    private var records: [Key: QuarantineRecord] = [:]
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: - Mutation

    /// Quarantine an artifact explicitly. Idempotent — re-quarantining
    /// the same key overwrites metadata but does not double-record.
    public func quarantine(
        id: String,
        kind: ArtifactKind,
        reasonCode: String,
        originatingVerdictID: String? = nil
    ) {
        let key = Key(id: id, kind: kind)
        records[key] = QuarantineRecord(
            key: key,
            reasonCode: reasonCode,
            originatingVerdictID: originatingVerdictID,
            quarantinedAt: now()
        )
    }

    /// Apply a `BASSovereignVerdict`'s quarantine-bearing decisions to
    /// the named artifact set. The verdict doesn't enumerate artifact
    /// IDs itself (they live in the upstream observation payload), so
    /// callers pass them alongside the verdict.
    public func apply(
        verdict: BASSovereignVerdict,
        quarantining ids: [String],
        kind: ArtifactKind
    ) {
        // Only act if the verdict actually escalated to quarantine or
        // harder. A `pass/throttle/shadowLock` verdict must not
        // side-effect the guard.
        guard verdict.verdictLevel >= .quarantine else { return }
        let reason = verdict.reasonCodes.first ?? verdict.verdictID
        for id in ids {
            quarantine(
                id: id,
                kind: kind,
                reasonCode: reason,
                originatingVerdictID: verdict.verdictID
            )
        }
    }

    /// Lift a single quarantine. This is an explicit maintenance
    /// action — there is no automatic decay.
    public func lift(id: String, kind: ArtifactKind) {
        records.removeValue(forKey: Key(id: id, kind: kind))
    }

    public func liftAll(kind: ArtifactKind) {
        records = records.filter { $0.key.kind != kind }
    }

    // MARK: - Queries

    public func isQuarantined(id: String, kind: ArtifactKind) -> Bool {
        records[Key(id: id, kind: kind)] != nil
    }

    public func record(id: String, kind: ArtifactKind) -> QuarantineRecord? {
        records[Key(id: id, kind: kind)]
    }

    /// Batch probe — used by retrieval paths that are about to reuse
    /// multiple items (e.g. a ThoughtFold candidate set). Returns
    /// which items are clean vs quarantined so the caller can both
    /// filter and raise BR-003 if any were hit.
    public func probe(ids: [String], kind: ArtifactKind) -> ProbeReport {
        var bad: [String] = []
        var good: [String] = []
        for id in ids {
            if records[Key(id: id, kind: kind)] != nil {
                bad.append(id)
            } else {
                good.append(id)
            }
        }
        return ProbeReport(quarantinedIDs: bad, cleanIDs: good)
    }

    // MARK: - Diagnostics

    public func quarantineCount(kind: ArtifactKind? = nil) -> Int {
        guard let kind else { return records.count }
        return records.keys.filter { $0.kind == kind }.count
    }

    /// Snapshot for audit / display. Ordered by quarantine time
    /// descending so the freshest contamination is visible first.
    public func allRecords() -> [QuarantineRecord] {
        records.values.sorted { $0.quarantinedAt > $1.quarantinedAt }
    }
}

