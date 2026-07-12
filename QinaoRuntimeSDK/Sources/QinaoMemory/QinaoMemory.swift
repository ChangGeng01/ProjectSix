import Foundation
import BASRuntimeCore
import BASMemory

/// QinaoMemory — the L8 façade.
///
/// The memory vault holds three tiers:
///
/// - **hot**   — recent episodic traces live in frontstage recall.
/// - **warm**  — distilled threads survive across sessions.
/// - **cold**  — canonicalised priors stay until explicitly deleted.
///
/// The façade exposes:
///
/// - `admit(_:)` — submit a candidate; runs the substrate's governance
///   gate (confidence floor + `BASMemoryGovernance.shouldAdmit`) and
///   promotes the candidate to a governed memory if it survives.
/// - `recall(scope:sensitivity:tiers:)` — scope-filtered, tier-filtered
///   read. Uses `BASMemoryTierFilter.filter` so the ordering is exactly
///   the substrate's canonical policy (tier descending, confidence
///   descending, id lexicographic).
/// - `recallFrontstage()` — "what you'd hear if you asked right now"
///   (drops cold, drops non-`governed`).
/// - `forget(id:)` / `forget(scope:)` / `forget(sensitivity:)` /
///   `forgetAll()` — cascade deletes that clear every tier at once.
///
/// The façade never surfaces the contamination policy, the persistence
/// horizon, or the quarantine set as public types — those are the
/// brain's decisions, not the host's knobs. What comes back is
/// always filtered by those internal rules.
///
/// Value types in the public API (`BASMemoryKind`, `BASMemoryScope`,
/// `BASMemorySensitivity`, `BASMemoryTier`, `BASGovernedMemory`) are
/// data, not verdict machinery — they are the intentionally-shared
/// public vocabulary per the Qinao four-layer nesting plan (§3.1).
public actor QinaoMemory {

    public enum MemoryError: Error, Equatable, Sendable {
        /// `forget(id:)` asked for a memory that was never admitted
        /// or has already been forgotten.
        case notFound(id: UUID)
        /// `admit(_:)` failed the governance gate — typically below
        /// the confidence floor. The reason string is stable enough
        /// to key UI copy on.
        case rejectedByGovernance(reason: String)
    }

    // MARK: - Public value types

    /// The minimal shape a host supplies to admit a memory. All
    /// fields are plain enums or scalars; nothing internal leaks.
    public struct AdmitRequest: Sendable, Equatable {
        public let kind: BASMemoryKind
        public let content: String
        public let scope: BASMemoryScope
        public let sensitivity: BASMemorySensitivity
        public let confidence: Double
        public let preferredTier: BASMemoryTier
        public let sourceType: String
        public let tags: [String]

        public init(
            kind: BASMemoryKind,
            content: String,
            scope: BASMemoryScope,
            sensitivity: BASMemorySensitivity,
            confidence: Double,
            preferredTier: BASMemoryTier = .warm,
            sourceType: String = "host",
            tags: [String] = []
        ) {
            self.kind = kind
            self.content = content
            self.scope = scope
            self.sensitivity = sensitivity
            self.confidence = confidence
            self.preferredTier = preferredTier
            self.sourceType = sourceType
            self.tags = tags
        }
    }

    // MARK: - State

    private var store: [UUID: BASGovernedMemory] = [:]
    private var cascadeReceipts: [QinaoForgetCascadeReceipt] = []
    private let minimumConfidence: Double
    private let now: @Sendable () -> Date
    private let cascadeIDFactory: @Sendable () -> String

    public init(
        minimumConfidence: Double = 0.6,
        now: @escaping @Sendable () -> Date = { Date() },
        cascadeIDFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        }
    ) {
        self.minimumConfidence = minimumConfidence
        self.now = now
        self.cascadeIDFactory = cascadeIDFactory
    }

    // MARK: - Admit

    /// Run a candidate through the substrate's governance gate. On
    /// success the returned `BASGovernedMemory` is stored; on
    /// failure no state changes and a typed error is thrown.
    @discardableResult
    public func admit(
        _ request: AdmitRequest
    ) throws -> BASGovernedMemory {
        let event = BASEventRecord(
            kind: request.kind,
            content: request.content,
            timestamp: now(),
            tags: request.tags)
        let candidate = BASMemoryCandidate(
            event: event,
            scope: request.scope,
            sensitivity: request.sensitivity,
            confidence: request.confidence,
            sourceType: request.sourceType,
            preferredTier: request.preferredTier)
        guard BASMemoryGovernance.shouldAdmit(
            candidate: candidate,
            minimumConfidence: minimumConfidence
        ) else {
            throw MemoryError.rejectedByGovernance(
                reason: "confidence-below-floor")
        }
        let governed = BASMemoryGovernance.promote(candidate: candidate)
        store[governed.id] = governed
        return governed
    }

    // MARK: - Recall

    /// Tier-ordered recall. Defaults return every tier (hot > warm >
    /// cold); pass a narrower `tiers` list to restrict to frontstage.
    /// `scope` / `sensitivity` are optional filters that compose
    /// with the tier filter.
    public func recall(
        scope: BASMemoryScope? = nil,
        sensitivity: BASMemorySensitivity? = nil,
        tiers: [BASMemoryTier] = [.hot, .warm, .cold]
    ) -> [BASGovernedMemory] {
        BASMemoryTierFilter.filter(
            Array(store.values),
            allowedTiers: tiers,
            scope: scope,
            sensitivity: sensitivity)
    }

    /// "What the brain would hear if it asked right now" — hot + warm
    /// only, `governed` status only, substrate-canonical ordering.
    public func recallFrontstage() -> [BASGovernedMemory] {
        BASMemoryTierFilter
            .frontstageEligibleMemories(Array(store.values))
            .sorted {
                if $0.tier != $1.tier {
                    return $0.tier.priority > $1.tier.priority
                }
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    /// integration S1 (2026-07-12) — the frontstage recall set packaged as the L8 turn
    /// bundle. This is the bridge that lets `QinaoRuntime.sendSession` feed its OWN memory
    /// into the Layer-8 observation pipeline instead of leaving the `memory` property a
    /// stored-but-unused seam (turn-path audit finding C).
    ///
    /// Returns nil when nothing is frontstage-eligible, so a host with an empty memory keeps
    /// today's exact semantics (L8 layer skips; no phantom `.bundleRetrieved` coverage from a
    /// zero-atom bundle).
    ///
    /// The governed→atom mapping MIRRORS the substrate-canonical one in
    /// `EBrainHostRuntime+MemoryService.memoryAtom(from:)` (BASHostKit) so both spines
    /// project identical L8 shapes; if that mapping changes, change this one with it.
    public func frontstageBundle(
        activeHostVersion: String? = nil
    ) -> BASMemoryBundle? {
        let records = recallFrontstage()
        guard !records.isEmpty else { return nil }
        let atoms = records.map { Self.memoryAtom(from: $0, fallbackTimestamp: now()) }
        return BASMemoryBundle(
            atoms: atoms,
            retrievalTags: [],
            conflictRefs: atoms.filter(\.frozen).map(\.memoryID),
            retrievedAt: now(),
            activeHostVersion: activeHostVersion)
    }

    /// Mirror of the canonical governed→atom projection (see `frontstageBundle` doc).
    /// `internal` so tests can pin the field mapping directly.
    static func memoryAtom(
        from record: BASGovernedMemory,
        fallbackTimestamp: Date
    ) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: record.id.uuidString,
            summary: record.content,
            contentType: Self.atomContentType(for: record.tier),
            source: record.sourceType,
            timestamp: record.lastConfirmedAt ?? fallbackTimestamp,
            confidence: record.confidence,
            emotionalWeight: record.kind == .semantic ? 0.55 : 0.22,
            riskRelevance: record.sensitivity == .high ? 0.82 : 0.38,
            hostRelevance: record.kind == .profile ? 0.88 : 0.54,
            conflictFingerprint: record.id.uuidString,
            promotionState: Self.atomPromotionState(for: record.governanceStatus),
            frozen: record.governanceStatus == .archived)
    }

    static func atomContentType(for tier: BASMemoryTier) -> BASMemoryAtomContentType {
        switch tier {
        case .hot: .hot
        case .warm: .warm
        case .cold: .cold
        }
    }

    static func atomPromotionState(
        for status: BASMemoryGovernanceStatus
    ) -> BASPromotionState {
        switch status {
        case .candidate: .candidate
        case .governed: .admitted
        case .archived: .frozen
        case .quarantined, .rejected: .retired
        }
    }

    // MARK: - Forget (cascade across all tiers)

    /// Delete one memory by ID across every tier.  Throws
    /// `.notFound` if nothing under that ID was admitted.
    ///
    /// Every call produces exactly one `QinaoForgetCascadeReceipt`
    /// recording the cascade outcome; the receipt is appended to
    /// `cascadeLedger()` and is the host's proof-of-delete.
    @discardableResult
    public func forget(id: UUID) throws -> BASGovernedMemory {
        guard let removed = store.removeValue(forKey: id) else {
            // Even a "not found" cascade produces a receipt — the
            // paper trail for a refused delete is as important as the
            // paper trail for a successful one.
            recordReceipt(
                .init(
                    cascadeID: cascadeIDFactory(),
                    rootTargets: [id.uuidString],
                    trigger: .singleID,
                    removedMemoryIDs: [],
                    cacheRefsInvalidated: [],
                    executedAt: now(),
                    executionState: .empty,
                    summary: "forget(id:) — no match"))
            throw MemoryError.notFound(id: id)
        }
        recordReceipt(
            .init(
                cascadeID: cascadeIDFactory(),
                rootTargets: [id.uuidString],
                trigger: .singleID,
                removedMemoryIDs: [removed.id],
                cacheRefsInvalidated: Self.defaultCacheRefs,
                executedAt: now(),
                executionState: .completed,
                summary: "forget(id:) — 1 row removed"))
        return removed
    }

    /// Cascade delete every memory under a scope.  Returns the
    /// removed memories in their pre-delete form so the caller can
    /// audit or show a receipt.
    ///
    /// Produces exactly one cascade receipt regardless of match count.
    @discardableResult
    public func forget(
        scope: BASMemoryScope
    ) -> [BASGovernedMemory] {
        let matches = store.values.filter { $0.scope == scope }
        for m in matches { store.removeValue(forKey: m.id) }
        let removedIDs = matches.map(\.id).sorted { $0.uuidString < $1.uuidString }
        recordReceipt(
            .init(
                cascadeID: cascadeIDFactory(),
                rootTargets: [scope.rawValue],
                trigger: .scope,
                removedMemoryIDs: removedIDs,
                cacheRefsInvalidated: removedIDs.isEmpty ? [] : Self.defaultCacheRefs,
                executedAt: now(),
                executionState: removedIDs.isEmpty ? .empty : .completed,
                summary: "forget(scope: .\(scope.rawValue)) — \(removedIDs.count) rows removed"))
        return Array(matches)
    }

    /// Cascade delete every memory at a given sensitivity level.
    /// Use this when a user says "forget anything sensitive".
    ///
    /// Produces exactly one cascade receipt regardless of match count.
    @discardableResult
    public func forget(
        sensitivity: BASMemorySensitivity
    ) -> [BASGovernedMemory] {
        let matches = store.values.filter {
            $0.sensitivity == sensitivity
        }
        for m in matches { store.removeValue(forKey: m.id) }
        let removedIDs = matches.map(\.id).sorted { $0.uuidString < $1.uuidString }
        recordReceipt(
            .init(
                cascadeID: cascadeIDFactory(),
                rootTargets: [sensitivity.rawValue],
                trigger: .sensitivity,
                removedMemoryIDs: removedIDs,
                cacheRefsInvalidated: removedIDs.isEmpty ? [] : Self.defaultCacheRefs,
                executedAt: now(),
                executionState: removedIDs.isEmpty ? .empty : .completed,
                summary: "forget(sensitivity: .\(sensitivity.rawValue)) — \(removedIDs.count) rows removed"))
        return Array(matches)
    }

    /// Wipe everything. Returns how many memories were removed.
    ///
    /// Produces exactly one cascade receipt carrying every removed ID
    /// for downstream audit reconciliation.
    @discardableResult
    public func forgetAll() -> Int {
        let removed = Array(store.values)
        let count = removed.count
        store.removeAll()
        let removedIDs = removed.map(\.id).sorted { $0.uuidString < $1.uuidString }
        recordReceipt(
            .init(
                cascadeID: cascadeIDFactory(),
                rootTargets: [],
                trigger: .all,
                removedMemoryIDs: removedIDs,
                cacheRefsInvalidated: removedIDs.isEmpty ? [] : Self.defaultCacheRefs,
                executedAt: now(),
                executionState: removedIDs.isEmpty ? .empty : .completed,
                summary: "forgetAll — \(count) rows removed"))
        return count
    }

    // MARK: - Introspection

    public func count() -> Int { store.count }

    /// Append-only cascade ledger.  Returns every receipt produced
    /// by this actor in execution order (oldest first).  The host
    /// uses this to prove-and-display every delete that ran.
    public func cascadeLedger() -> [QinaoForgetCascadeReceipt] {
        cascadeReceipts
    }

    /// Return the most recent N receipts, newest last.  Convenience
    /// for hosts that only need the tail of the ledger (e.g. for a
    /// "recent deletes" surface).
    public func recentCascadeReceipts(limit: Int) -> [QinaoForgetCascadeReceipt] {
        guard limit > 0 else { return [] }
        return Array(cascadeReceipts.suffix(limit))
    }

    // MARK: - Private helpers

    /// The frontstage recall + warm/cold projection share the same
    /// cache key surface in the current implementation, so every
    /// successful cascade invalidates this single ref.  Future
    /// milestones can extend the ref set per projection layer.
    private static let defaultCacheRefs: [String] = [
        "qinao.memory.recall-frontstage",
        "qinao.memory.recall-scoped",
        "qinao.memory.recall-sensitivity"
    ]

    private func recordReceipt(_ receipt: QinaoForgetCascadeReceipt) {
        cascadeReceipts.append(receipt)
    }
}

private extension BASMemoryTier {
    /// Ordering used by recall — higher priority surfaces earlier.
    var priority: Int {
        switch self {
        case .hot: return 3
        case .warm: return 2
        case .cold: return 1
        }
    }
}
