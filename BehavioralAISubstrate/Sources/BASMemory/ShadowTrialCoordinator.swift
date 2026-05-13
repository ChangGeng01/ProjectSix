import Foundation
import BASRuntimeCore

/// L13 shadow-trial coordinator.
///
/// ## Why this exists
///
/// Before M11 the L13 evolution-governance story was "schema only":
///
/// - `BASExperienceCandidate` carried stability / contamination signals
/// - `BASShadowTrialRecord` carried observed effects + fail conditions
/// - `BASEvolutionSeal` carried an approval state + allowed scope
/// - `BASRetractionOrder` carried target + cascade refs
/// - `BASEvolutionPromotionGate.evaluate` could compute block reasons
///
/// …but **no component actually drove the candidate through the
/// pipeline**, and no record of the transitions reached the sovereign
/// audit ledger. The public promise of "宿主私有经验不进基础权重"
/// ("host private experience never leaks into base weights") had no
/// executable home: schemas can be invented in a test, a trial record
/// can be set to `passed` by anyone, and nothing proves the decision
/// ever reached a tamper-evident log.
///
/// The coordinator closes that hole. Every transition:
///
///   `submit → (observe | reportFail) → finalize → promote/deny`
///
/// is a typed actor step that appends a signed entry to an injected
/// ledger before returning. Consumers that hand in a real
/// `BASSovereignAuditLedger` get the property that the shadow-trial
/// chain and the sovereign verdict chain share the same append-only
/// hash chain — i.e. if you can verify integrity of one you have
/// verified integrity of both.
///
/// ## The ledger seam (`BASShadowTrialLedger`)
///
/// `BASMemory` is a leaf module on `BASRuntimeCore`. It cannot
/// directly depend on `BASSovereign` (that module is an even tighter
/// leaf — it must not be influenced by memory/policy state). Instead
/// we take the ledger as a protocol-typed dependency:
///
///   coordinator <- any BASShadowTrialLedger
///
/// The real sovereign ledger conformance is added as a tiny extension
/// in `BASOrchestration` where both modules are in scope. Tests can
/// use `InMemoryShadowTrialLedger` here in `BASMemory` for unit
/// coverage, and integration tests wire the real sovereign ledger
/// through the bridge to prove the chain really joins.
///
/// ## Trial states (explicit, not clever)
///
/// `BASShadowTrialRecord.completionState` is a free-form String in the
/// schema. The coordinator pins the vocabulary it writes:
///
///   `"pending"`   after `submit`
///   `"observing"` after first `observe` or `reportFailCondition`
///   `"passed"`    after `finalize(outcome: .passed ...)`
///   `"failed"`    after `finalize(outcome: .failed ...)`
///   `"blocked"`   after `finalize(outcome: .blocked ...)`
///
/// `isPassed` / `isFailed` / `isPending` helpers on
/// `BASShadowTrialRecord` then line up with these values exactly.
///
/// ## Errors
///
/// Every failure mode is a typed `TrialError`. The coordinator never
/// writes a partial success: if the ledger append throws, the
/// in-memory state is not mutated. This matches the M9 "fail-closed"
/// discipline from the sovereign side.
public actor BASShadowTrialCoordinator {

    // MARK: - Errors

    public enum TrialError: Error, Equatable, Sendable {
        case duplicateCandidate(id: String)
        case unknownCandidate(id: String)
        case duplicateTrial(id: String)
        case unknownTrial(id: String)
        case trialAlreadyFinalized(id: String, state: String)
        case candidateAlreadyHasActiveTrial(candidateID: String, trialID: String)
        case ledgerAppendFailed(reason: String)
        case invalidInput(reason: String)
    }

    // MARK: - Finalization outcomes

    /// The three terminal states a trial can reach. Expressed as a
    /// typed enum so callers cannot invent a fourth state by handing
    /// in a free-form string.
    public enum FinalizeOutcome:
        Equatable, Sendable, Codable
    {
        case passed
        case failed
        case blocked

        fileprivate var completionState: String {
            switch self {
            case .passed:  return "passed"
            case .failed:  return "failed"
            case .blocked: return "blocked"
            }
        }

        fileprivate var eventKind: String {
            switch self {
            case .passed:  return "shadow_trial_passed"
            case .failed:  return "shadow_trial_failed"
            case .blocked: return "shadow_trial_blocked"
            }
        }

        /// When a trial reaches a terminal state the coordinator
        /// derives whether a seal should be issued or denied. Only
        /// `.passed` produces an approved seal; `.failed` / `.blocked`
        /// both deny the seal and queue a retraction.
        fileprivate var sealApprovalState: String {
            switch self {
            case .passed:           return "sealed"
            case .failed, .blocked: return "denied"
            }
        }
    }

    // MARK: - State

    private var candidates: [String: BASExperienceCandidate] = [:]
    /// All trials recorded for a candidate, in insertion order.
    /// Historical trials are kept so promotion-verdict replay can
    /// see the full picture.
    private var trialsByCandidate: [String: [BASShadowTrialRecord]] = [:]
    /// Flat lookup by `trialID` for O(1) state transitions.
    private var trialsByID: [String: BASShadowTrialRecord] = [:]
    /// The most recently issued seal for a candidate (at most one).
    private var sealsByCandidate: [String: BASEvolutionSeal] = [:]
    /// The most recently queued retraction for a candidate (at most one).
    private var retractionsByCandidate: [String: BASRetractionOrder] = [:]

    // MARK: - Dependencies

    private let ledger: any BASShadowTrialLedger
    private let clock: @Sendable () -> Date
    private let nextAuditID: @Sendable () -> String
    private let nextTrialID: @Sendable () -> String
    private let nextSealID: @Sendable () -> String
    private let nextRetractionID: @Sendable () -> String

    public init(
        ledger: any BASShadowTrialLedger,
        clock: @escaping @Sendable () -> Date = { Date() },
        nextAuditID: @escaping @Sendable () -> String = { "audit-" + UUID().uuidString },
        nextTrialID: @escaping @Sendable () -> String = { "trial-" + UUID().uuidString },
        nextSealID: @escaping @Sendable () -> String = { "seal-" + UUID().uuidString },
        nextRetractionID: @escaping @Sendable () -> String = { "retract-" + UUID().uuidString }
    ) {
        self.ledger = ledger
        self.clock = clock
        self.nextAuditID = nextAuditID
        self.nextTrialID = nextTrialID
        self.nextSealID = nextSealID
        self.nextRetractionID = nextRetractionID
    }

    // MARK: - Public transitions

    /// Admit a candidate and open a pending trial. A candidate can
    /// have at most one active trial; submitting a second time while
    /// the first is pending throws `candidateAlreadyHasActiveTrial`.
    ///
    /// The ledger entry event kind is `"shadow_trial_opened"`.
    @discardableResult
    public func submit(
        candidate: BASExperienceCandidate,
        sessionID: String,
        turnID: String,
        trialScope: String
    ) async throws -> BASShadowTrialRecord {
        try Self.ensureNonEmpty(candidate.candidateID, label: "candidateID")
        try Self.ensureNonEmpty(sessionID, label: "sessionID")
        try Self.ensureNonEmpty(turnID, label: "turnID")
        try Self.ensureNonEmpty(trialScope, label: "trialScope")

        if let existing = candidates[candidate.candidateID],
           existing.candidateID == candidate.candidateID,
           let active = activeTrialID(for: candidate.candidateID) {
            throw TrialError.candidateAlreadyHasActiveTrial(
                candidateID: candidate.candidateID,
                trialID: active)
        }

        let now = clock()
        let trialID = nextTrialID()
        let record = BASShadowTrialRecord(
            trialID: trialID,
            candidateRef: candidate.candidateID,
            trialScope: trialScope,
            startAt: now,
            endAt: nil,
            observedEffects: [],
            failConditions: [],
            promotionRecommendation: nil,
            completionState: "pending")

        let entry = BASShadowTrialLedgerEntry(
            auditID: nextAuditID(),
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "shadow_trial:\(trialID)",
            ruleIDs: ["L13.shadow_trial_opened"],
            signalRefs: candidate.sourceRefs,
            actionRefs: [candidate.candidateID],
            snapshotRef: trialScope,
            signaturePayload: Self.signaturePayload(
                eventKind: "shadow_trial_opened",
                trialID: trialID,
                candidateID: candidate.candidateID,
                completionState: "pending"),
            appendedAt: now,
            eventKind: "shadow_trial_opened")

        _ = try await appendOrThrow(entry)

        candidates[candidate.candidateID] = candidate
        trialsByID[trialID] = record
        var history = trialsByCandidate[candidate.candidateID] ?? []
        history.append(record)
        trialsByCandidate[candidate.candidateID] = history

        return record
    }

    /// Record a new observed effect. The trial moves from `"pending"`
    /// to `"observing"` on the first observation. Subsequent
    /// observations keep it at `"observing"`.
    ///
    /// Event kind: `"shadow_trial_effect_observed"`.
    @discardableResult
    public func observe(
        trialID: String,
        effect: String,
        sessionID: String,
        turnID: String
    ) async throws -> BASShadowTrialRecord {
        try Self.ensureNonEmpty(effect, label: "effect")
        return try await advanceOpenTrial(
            trialID: trialID,
            sessionID: sessionID,
            turnID: turnID,
            eventKind: "shadow_trial_effect_observed",
            rule: "L13.shadow_trial_effect_observed") { record in
                var updated = record
                var effects = updated.observedEffects
                effects.append(effect)
                updated.observedEffects = effects
                updated.completionState = "observing"
                return updated
            }
    }

    /// Record a new fail condition. Same state-machine semantics as
    /// `observe(...)`: first call flips `"pending"` → `"observing"`.
    /// Fail conditions do NOT automatically fail the trial; only
    /// `finalize(outcome: .failed ...)` does.
    ///
    /// Event kind: `"shadow_trial_fail_condition_recorded"`.
    @discardableResult
    public func reportFailCondition(
        trialID: String,
        reason: String,
        sessionID: String,
        turnID: String
    ) async throws -> BASShadowTrialRecord {
        try Self.ensureNonEmpty(reason, label: "reason")
        return try await advanceOpenTrial(
            trialID: trialID,
            sessionID: sessionID,
            turnID: turnID,
            eventKind: "shadow_trial_fail_condition_recorded",
            rule: "L13.shadow_trial_fail_condition_recorded") { record in
                var updated = record
                var failures = updated.failConditions
                failures.append(reason)
                updated.failConditions = failures
                updated.completionState = "observing"
                return updated
            }
    }

    /// Finalize a trial and derive seal + retraction.
    ///
    /// - `.passed`  → seal approved; no retraction queued
    /// - `.failed`  → seal denied;   retraction queued (cascade refs =
    ///                candidate.sourceRefs)
    /// - `.blocked` → seal denied;   retraction queued (same cascade)
    ///
    /// The whole finalize is atomic-ish: the trial ledger entry is
    /// appended first; if it fails, seal + retraction are not
    /// recorded. If the seal or retraction ledger append fails, the
    /// trial still reaches its terminal state but the seal /
    /// retraction fields are not populated — callers must treat
    /// `ledgerAppendFailed` as grounds to abort higher-level
    /// commits, same discipline as `BASSovereignAuditLedger`.
    @discardableResult
    public func finalize(
        trialID: String,
        outcome: FinalizeOutcome,
        promotionRecommendation: String?,
        sessionID: String,
        turnID: String
    ) async throws -> BASShadowTrialRecord {
        try Self.ensureNonEmpty(trialID, label: "trialID")
        try Self.ensureNonEmpty(sessionID, label: "sessionID")
        try Self.ensureNonEmpty(turnID, label: "turnID")

        guard let record = trialsByID[trialID] else {
            throw TrialError.unknownTrial(id: trialID)
        }
        guard record.isPending else {
            throw TrialError.trialAlreadyFinalized(
                id: trialID,
                state: record.completionState)
        }
        guard let candidate = candidates[record.candidateRef] else {
            // Unreachable in normal flow: candidate is admitted by
            // submit, which happens before any trialID exists.
            throw TrialError.unknownCandidate(id: record.candidateRef)
        }

        let now = clock()
        var finalized = record
        finalized.endAt = now
        finalized.completionState = outcome.completionState
        finalized.promotionRecommendation = promotionRecommendation

        let trialEntry = BASShadowTrialLedgerEntry(
            auditID: nextAuditID(),
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "shadow_trial:\(trialID)",
            ruleIDs: ["L13." + outcome.eventKind],
            signalRefs: candidate.sourceRefs,
            actionRefs: [candidate.candidateID],
            snapshotRef: record.trialScope,
            signaturePayload: Self.signaturePayload(
                eventKind: outcome.eventKind,
                trialID: trialID,
                candidateID: candidate.candidateID,
                completionState: finalized.completionState),
            appendedAt: now,
            eventKind: outcome.eventKind)

        _ = try await appendOrThrow(trialEntry)

        // Commit the trial state change only after the ledger entry
        // was accepted.
        trialsByID[trialID] = finalized
        replaceInHistory(finalized)

        // Derive seal + retraction. Both write their own ledger
        // entries; they run after the trial entry so the chain sees
        // "trial finalized → seal issued/denied → retraction queued".
        let sealID = nextSealID()
        let seal = BASEvolutionSeal(
            sealID: sealID,
            candidateRef: candidate.candidateID,
            allowedScope: candidate.sovereignScope,
            trialRequired: true,
            approvalRequirements: outcome == .passed
                ? ["L13.evolution_seal_issued"]
                : ["L13.evolution_seal_denied"],
            signature: Self.signaturePayload(
                eventKind: "evolution_seal:\(outcome.sealApprovalState)",
                trialID: trialID,
                candidateID: candidate.candidateID,
                completionState: outcome.sealApprovalState),
            approvalState: outcome.sealApprovalState)

        let sealEventKind: String = (outcome == .passed)
            ? "evolution_seal_issued"
            : "evolution_seal_denied"
        let sealEntry = BASShadowTrialLedgerEntry(
            auditID: nextAuditID(),
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "evolution_seal:\(sealID)",
            ruleIDs: ["L13." + sealEventKind],
            signalRefs: [trialID],
            actionRefs: [candidate.candidateID],
            snapshotRef: record.trialScope,
            signaturePayload: seal.signature,
            appendedAt: now,
            eventKind: sealEventKind)
        _ = try await appendOrThrow(sealEntry)
        sealsByCandidate[candidate.candidateID] = seal

        if outcome != .passed {
            let retractionID = nextRetractionID()
            let retraction = BASRetractionOrder(
                orderID: retractionID,
                targetRefs: [candidate.candidateID],
                cascadeRefs: candidate.sourceRefs,
                reasonCodes: outcome == .failed
                    ? ["L13.shadow_trial_failed"]
                    : ["L13.shadow_trial_blocked"],
                executionState: "queued")

            let retractionEntry = BASShadowTrialLedgerEntry(
                auditID: nextAuditID(),
                sessionID: sessionID,
                turnID: turnID,
                verdictRef: "retraction:\(retractionID)",
                ruleIDs: ["L13.retraction_order_queued"],
                signalRefs: [trialID],
                actionRefs: [candidate.candidateID],
                snapshotRef: record.trialScope,
                signaturePayload: Self.signaturePayload(
                    eventKind: "retraction_order_queued",
                    trialID: trialID,
                    candidateID: candidate.candidateID,
                    completionState: retraction.executionState),
                appendedAt: now,
                eventKind: "retraction_order_queued")
            _ = try await appendOrThrow(retractionEntry)
            retractionsByCandidate[candidate.candidateID] = retraction
        }

        return finalized
    }

    // MARK: - Read-side

    public func candidate(for candidateID: String) -> BASExperienceCandidate? {
        candidates[candidateID]
    }

    public func trial(for trialID: String) -> BASShadowTrialRecord? {
        trialsByID[trialID]
    }

    public func trials(for candidateID: String) -> [BASShadowTrialRecord] {
        trialsByCandidate[candidateID] ?? []
    }

    public func pendingTrials() -> [BASShadowTrialRecord] {
        trialsByID.values
            .filter { $0.isPending }
            .sorted { $0.trialID < $1.trialID }
    }

    public func seal(for candidateID: String) -> BASEvolutionSeal? {
        sealsByCandidate[candidateID]
    }

    public func retraction(for candidateID: String) -> BASRetractionOrder? {
        retractionsByCandidate[candidateID]
    }

    /// Derive a `BASEvolutionPromotionGateVerdict` from current
    /// in-memory state, mirroring the schema counter-based
    /// `blockedReasonCodes(for:)` path. This is the "would the L14
    /// promotion gate admit this candidate today?" question, answered
    /// entirely from observable coordinator state — no hidden channel.
    public func promotionVerdict(for candidateID: String) -> BASEvolutionPromotionGateVerdict {
        let history = trialsByCandidate[candidateID] ?? []
        let failedCount = history.filter { $0.isFailed }.count
        let pendingCount = history.filter { $0.isPending }.count
        let sealState = sealsByCandidate[candidateID]
        let deniedSeals = (sealState?.isDenied == true) ? 1 : 0
        let pendingSeals = (sealState?.isPending == true) ? 1 : 0
        let retractionPending = retractionsByCandidate[candidateID]?.executionState == "queued"
            ? 1 : 0

        var reasons: [String] = []
        if failedCount > 0 { reasons.append("evolution.shadow_trial_failed") }
        if pendingCount > 0 { reasons.append("evolution.shadow_trial_pending") }
        if deniedSeals > 0 { reasons.append("evolution.seal_denied") }
        if pendingSeals > 0 { reasons.append("evolution.seal_pending") }
        if retractionPending > 0 { reasons.append("evolution.retraction_pending") }

        return BASEvolutionPromotionGateVerdict(
            allowsPromotion: reasons.isEmpty,
            reasonCodes: reasons,
            primaryReason: reasons.first)
    }

    // MARK: - Internals

    private func activeTrialID(for candidateID: String) -> String? {
        guard let history = trialsByCandidate[candidateID] else { return nil }
        return history.first(where: { $0.isPending })?.trialID
    }

    private func replaceInHistory(_ updated: BASShadowTrialRecord) {
        guard var history = trialsByCandidate[updated.candidateRef] else { return }
        if let idx = history.firstIndex(where: { $0.trialID == updated.trialID }) {
            history[idx] = updated
            trialsByCandidate[updated.candidateRef] = history
        }
    }

    /// Shared implementation for `observe` and `reportFailCondition`.
    /// Both advance a pending/observing trial by appending to a field
    /// and refreshing state; both write a ledger entry before
    /// committing.
    private func advanceOpenTrial(
        trialID: String,
        sessionID: String,
        turnID: String,
        eventKind: String,
        rule: String,
        apply: (BASShadowTrialRecord) -> BASShadowTrialRecord
    ) async throws -> BASShadowTrialRecord {
        try Self.ensureNonEmpty(trialID, label: "trialID")
        try Self.ensureNonEmpty(sessionID, label: "sessionID")
        try Self.ensureNonEmpty(turnID, label: "turnID")

        guard let record = trialsByID[trialID] else {
            throw TrialError.unknownTrial(id: trialID)
        }
        guard record.isPending else {
            throw TrialError.trialAlreadyFinalized(
                id: trialID,
                state: record.completionState)
        }
        guard let candidate = candidates[record.candidateRef] else {
            throw TrialError.unknownCandidate(id: record.candidateRef)
        }

        let updated = apply(record)
        let now = clock()

        let entry = BASShadowTrialLedgerEntry(
            auditID: nextAuditID(),
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "shadow_trial:\(trialID)",
            ruleIDs: [rule],
            signalRefs: candidate.sourceRefs,
            actionRefs: [candidate.candidateID],
            snapshotRef: record.trialScope,
            signaturePayload: Self.signaturePayload(
                eventKind: eventKind,
                trialID: trialID,
                candidateID: candidate.candidateID,
                completionState: updated.completionState),
            appendedAt: now,
            eventKind: eventKind)

        _ = try await appendOrThrow(entry)

        trialsByID[trialID] = updated
        replaceInHistory(updated)
        return updated
    }

    private func appendOrThrow(_ entry: BASShadowTrialLedgerEntry) async throws -> String {
        do {
            return try await ledger.appendShadowTrialEvent(entry)
        } catch {
            throw TrialError.ledgerAppendFailed(reason: String(describing: error))
        }
    }

    // MARK: - Pure helpers

    private static func ensureNonEmpty(_ value: String, label: String) throws {
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            throw TrialError.invalidInput(reason: "empty-\(label)")
        }
    }

    /// Stable, content-addressed payload for ledger signatures.
    /// Keeping the vocabulary deterministic means two runs that pass
    /// the same inputs through the coordinator produce byte-equal
    /// ledger entries — a property relied on by the parity tests.
    private static func signaturePayload(
        eventKind: String,
        trialID: String,
        candidateID: String,
        completionState: String
    ) -> String {
        "\(eventKind)|\(trialID)|\(candidateID)|\(completionState)"
    }
}

// MARK: - Ledger seam

/// A neutral ledger entry the coordinator hands to whichever backing
/// log is configured. Stays free of sovereign-specific fields so that
/// `BASMemory` does not leak `BAS*Sovereign*` types into its public
/// surface (redaction-safe by construction — every field here is a
/// scalar `String` / `Date` / `[String]`).
public struct BASShadowTrialLedgerEntry:
    Codable, Sendable, Equatable
{
    public let auditID: String
    public let sessionID: String
    public let turnID: String
    public let verdictRef: String
    public let ruleIDs: [String]
    public let signalRefs: [String]
    public let actionRefs: [String]
    public let snapshotRef: String
    public let signaturePayload: String
    public let appendedAt: Date
    /// Human-readable event kind. The coordinator pins a small
    /// vocabulary here (see `ShadowTrialCoordinator` doc comment).
    public let eventKind: String

    public init(
        auditID: String,
        sessionID: String,
        turnID: String,
        verdictRef: String,
        ruleIDs: [String],
        signalRefs: [String],
        actionRefs: [String],
        snapshotRef: String,
        signaturePayload: String,
        appendedAt: Date,
        eventKind: String
    ) {
        self.auditID = auditID
        self.sessionID = sessionID
        self.turnID = turnID
        self.verdictRef = verdictRef
        self.ruleIDs = ruleIDs
        self.signalRefs = signalRefs
        self.actionRefs = actionRefs
        self.snapshotRef = snapshotRef
        self.signaturePayload = signaturePayload
        self.appendedAt = appendedAt
        self.eventKind = eventKind
    }
}

/// Protocol seam for the coordinator's audit log. Defining it in
/// `BASMemory` keeps the leaf-discipline rule intact: sovereign can
/// stay on `BASRuntimeCore` only, and the real conformance lives in
/// a composition layer (see `BASOrchestration/ShadowTrialLedgerBridge`).
public protocol BASShadowTrialLedger: Sendable {
    /// Append an entry and return its audit reference. Implementers
    /// are expected to throw on any tampering / chain-integrity
    /// failure. The coordinator treats any throw as grounds to roll
    /// back the in-memory transition.
    func appendShadowTrialEvent(_ entry: BASShadowTrialLedgerEntry) async throws -> String
}

/// In-memory reference implementation. Useful for unit tests here in
/// `BASMemory` and for any downstream consumer that wants a
/// lightweight ledger without pulling in `BASSovereign`. Deterministic
/// insertion order; scans return entries in insertion order.
public actor BASInMemoryShadowTrialLedger: BASShadowTrialLedger {

    public enum LedgerError: Error, Equatable, Sendable {
        case forcedFailure(reason: String)
    }

    private var entries: [BASShadowTrialLedgerEntry] = []
    private let shouldFail: @Sendable (BASShadowTrialLedgerEntry) -> String?

    public init(
        failWhen: @escaping @Sendable (BASShadowTrialLedgerEntry) -> String? = { _ in nil }
    ) {
        self.shouldFail = failWhen
    }

    public func appendShadowTrialEvent(_ entry: BASShadowTrialLedgerEntry) async throws -> String {
        if let reason = shouldFail(entry) {
            throw LedgerError.forcedFailure(reason: reason)
        }
        entries.append(entry)
        return entry.auditID
    }

    public func all() -> [BASShadowTrialLedgerEntry] {
        entries
    }

    public func eventKinds() -> [String] {
        entries.map(\.eventKind)
    }

    public func count() -> Int {
        entries.count
    }
}
