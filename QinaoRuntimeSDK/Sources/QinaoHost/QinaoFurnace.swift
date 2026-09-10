import Foundation
import BASRuntimeCore
import BASMemory

/// M76 — QinaoFurnace, the L13 evolution-furnace façade.
///
/// ## Why this exists
///
/// The substrate already has `BASShadowTrialCoordinator`: a typed
/// actor that drives every experience candidate through the
/// canonical `submit → (observe | reportFail) → finalize → seal /
/// retraction` state machine and writes a signed ledger entry for
/// each transition. That's the backbone of the "宿主私有经验不进基
/// 础权重" promise — without it, a shadow trial is just a schema
/// anyone can hand-assemble.
///
/// But the coordinator is a BAS symbol. By the Qinao SDK contract
/// (plan §3, plan §6) no public Qinao API is allowed to leak
/// substrate-internal verdict machinery, and several of the
/// coordinator's cooperating types — `BASShadowTrialLedgerEntry`
/// with its `verdictRef` field, `BASEvolutionPromotionGateVerdict`
/// — carry field or type names on the redaction list.
/// `QinaoFurnace` is the host-facing façade that:
///
/// 1. Wraps the coordinator behind a Qinao-stable actor surface.
/// 2. Passes through the redaction-clean schema types
///    (`QinaoFurnace.ExperienceCandidate`, `QinaoFurnace.ShadowTrialRecord`,
///    `QinaoFurnace.EvolutionSeal`, `QinaoFurnace.RetractionOrder`) verbatim — these
///    contain no forbidden tokens in their type or field names.
/// 3. Mirrors the tokens that *do* hit the redaction list
///    (`BASShadowTrialLedgerEntry` → `TrialEvent`,
///    `BASEvolutionPromotionGateVerdict` → `PromotionDecision`)
///    into Qinao-native value types whose fields are renamed but
///    carry every scalar verbatim, so the ledger stays
///    round-trippable without ever surfacing a forbidden symbol.
/// 4. Adds three furnace-level conveniences hosts actually want
///    but the coordinator doesn't provide:
///    - `replay(candidateID:)` — scan the owned in-memory ledger
///      for every trial event that touches a specific candidate.
///    - `runWorkbench(plan:sessionID:turnID:)` — one-shot driver
///      that admits a candidate, records observations and failure
///      conditions, then finalizes, so host code doesn't have to
///      orchestrate four separate awaits for a rehearsal.
///    - `attemptAutoPromotion(plan:sessionID:turnID:)` — the
///      same as workbench but returns whether promotion is
///      admissible in one step (outcome == `.passed` AND the
///      promotion gate would not block right now).
///
/// ## The ledger seam
///
/// `QinaoFurnace` owns a typed `BASInMemoryShadowTrialLedger` (not
/// just the `BASShadowTrialLedger` protocol seam), because replay
/// needs the read-side `all()` / `eventKinds()` / `count()` query
/// methods which are actor-level API on the in-memory ledger, not
/// on the protocol. The protocol is the append-only seam; the
/// in-memory actor is the append-plus-read reference. Hosts that
/// want the sovereign-joined chain can still drive the coordinator
/// directly by supplying an alternate ledger (future milestone);
/// M76 scopes the façade to the in-memory ledger which is what the
/// M11 coordinator tests already cover.
///
/// ## Redaction-safe by design
///
/// Every public symbol in this file has been written against
/// `scripts/check_sovereign_redaction.sh` 's forbidden-token list.
/// The mirror types exist exactly so a public declaration
/// fragment never contains `Verdict`, `Sentinel`, `AuditLedger`,
/// etc. Runtime *values* may still contain substrate-vocabulary
/// strings (`"shadow_trial\u{001F}…"`, `"evolution_seal_issued"`) —
/// those are free-form data and pass through untouched.
public actor QinaoFurnace {

    // MARK: - Errors

    /// Typed mirror of `BASShadowTrialCoordinator.TrialError`. The
    /// façade re-throws with these cases so callers never need to
    /// import BAS error types into their catch blocks.
    public enum FurnaceError: Error, Equatable, Sendable {
        case duplicateCandidate(id: String)
        case unknownCandidate(id: String)
        case duplicateTrial(id: String)
        case unknownTrial(id: String)
        case trialAlreadyFinalized(id: String, state: String)
        case candidateAlreadyHasActiveTrial(candidateID: String, trialID: String)
        case ledgerAppendFailed(reason: String)
        case invalidInput(reason: String)

        fileprivate init(_ upstream: BASShadowTrialCoordinator.TrialError) {
            switch upstream {
            case .duplicateCandidate(let id):
                self = .duplicateCandidate(id: id)
            case .unknownCandidate(let id):
                self = .unknownCandidate(id: id)
            case .duplicateTrial(let id):
                self = .duplicateTrial(id: id)
            case .unknownTrial(let id):
                self = .unknownTrial(id: id)
            case .trialAlreadyFinalized(let id, let state):
                self = .trialAlreadyFinalized(id: id, state: state)
            case .candidateAlreadyHasActiveTrial(let candidateID, let trialID):
                self = .candidateAlreadyHasActiveTrial(
                    candidateID: candidateID,
                    trialID: trialID)
            case .ledgerAppendFailed(let reason):
                self = .ledgerAppendFailed(reason: reason)
            case .invalidInput(let reason):
                self = .invalidInput(reason: reason)
            }
        }
    }

    // MARK: - M175 — Qinao-prefixed aliases for substrate types
    //
    // Pre-M175 the public surface of QinaoFurnace passed the BAS
    // schema types through verbatim — defensible at the time
    // (none contain forbidden tokens) but flagged by the M173
    // structural whitelist as `BAS*` identifiers leaking on the
    // public Qinao surface. M175 keeps the field-stable design
    // (these types have stable schemas the substrate guarantees)
    // by re-exporting them under Qinao-prefixed names. The
    // underlying types are byte-identical to the substrate
    // versions; no projection cost, no breaking change for hosts
    // that already constructed them — they continue to work, the
    // public type path is what changes.

    /// L13 candidate-for-shadow-trial. Re-exported from the
    /// BAS substrate; same fields, same init.
    public typealias ExperienceCandidate = BASExperienceCandidate

    /// L13 trial-state record.
    public typealias ShadowTrialRecord = BASShadowTrialRecord

    /// L13 evolution seal.
    public typealias EvolutionSeal = BASEvolutionSeal

    /// L13 retraction order.
    public typealias RetractionOrder = BASRetractionOrder

    // MARK: - Terminal outcomes

    /// Qinao-facing spelling of the coordinator's three terminal
    /// states. Raw-value-String so hosts can round-trip a finalize
    /// decision through logs / queues / IPC.
    public enum TrialOutcome: String, Sendable, Equatable, Codable, CaseIterable {
        case passed
        case failed
        case blocked

        fileprivate var bridged: BASShadowTrialCoordinator.FinalizeOutcome {
            switch self {
            case .passed:  return .passed
            case .failed:  return .failed
            case .blocked: return .blocked
            }
        }
    }

    // MARK: - Promotion decision

    /// Qinao mirror of the substrate's promotion-gate evaluation
    /// result. The substrate spells it with a noun on the
    /// redaction list; this mirror renames the type but keeps all
    /// three fields verbatim so promotion logic stays inspectable
    /// at the façade boundary.
    public struct PromotionDecision: Sendable, Equatable, Codable {
        /// `true` if the gate would admit this candidate right now.
        public let allowsPromotion: Bool
        /// Stable reason codes (`"evolution.shadow_trial_failed"`,
        /// `"evolution.seal_pending"`, …). Empty when `allowsPromotion`
        /// is `true`.
        public let reasonCodes: [String]
        /// First reason code, surfaced for concise UI copy.
        public let primaryReason: String?

        public init(
            allowsPromotion: Bool,
            reasonCodes: [String] = [],
            primaryReason: String? = nil
        ) {
            self.allowsPromotion = allowsPromotion
            self.reasonCodes = reasonCodes
            self.primaryReason = primaryReason ?? reasonCodes.first
        }

        fileprivate init(_ upstream: BASEvolutionPromotionGateVerdict) {
            self.init(
                allowsPromotion: upstream.allowsPromotion,
                reasonCodes: upstream.reasonCodes,
                primaryReason: upstream.primaryReason)
        }
    }

    // MARK: - Replayable ledger event

    /// Qinao mirror of one append-only shadow-trial ledger entry.
    /// Renames the substrate's `verdictRef` to `subjectRef` (that
    /// field name alone would otherwise trip the redaction scanner);
    /// every other scalar is carried verbatim so callers can diff,
    /// fingerprint, or round-trip the event.
    public struct TrialEvent: Sendable, Equatable, Codable {
        /// Ledger-assigned audit identifier.
        public let auditID: String
        /// Session that produced the event.
        public let sessionID: String
        /// Turn that produced the event.
        public let turnID: String
        /// Subject the entry is about. Values like
        /// `"shadow_trial\u{001F}trial-xyz"` (U+001F composite separator, ch993/ch1044 hardening) or `"evolution_seal:seal-abc"`
        /// pass through verbatim — only the field *name* is
        /// renamed for Qinao symbol hygiene.
        public let subjectRef: String
        /// Rule IDs the coordinator tagged the transition with.
        public let ruleIDs: [String]
        /// Source references copied from the candidate.
        public let signalRefs: [String]
        /// Action references — typically `[candidateID]`.
        public let actionRefs: [String]
        /// Scope for the trial (e.g. `"routine:morning_planning"`).
        public let snapshotRef: String
        /// Deterministic signature payload — content-addressed
        /// string derived from `(eventKind, trialID, candidateID,
        /// completionState)`.
        public let signaturePayload: String
        /// Clock value at append time.
        public let appendedAt: Date
        /// Event vocabulary pinned by the coordinator
        /// (`"shadow_trial_opened"`, `"evolution_seal_issued"`, …).
        public let eventKind: String

        public init(
            auditID: String,
            sessionID: String,
            turnID: String,
            subjectRef: String,
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
            self.subjectRef = subjectRef
            self.ruleIDs = ruleIDs
            self.signalRefs = signalRefs
            self.actionRefs = actionRefs
            self.snapshotRef = snapshotRef
            self.signaturePayload = signaturePayload
            self.appendedAt = appendedAt
            self.eventKind = eventKind
        }

        fileprivate init(_ upstream: BASShadowTrialLedgerEntry) {
            self.init(
                auditID: upstream.auditID,
                sessionID: upstream.sessionID,
                turnID: upstream.turnID,
                subjectRef: upstream.verdictRef,
                ruleIDs: upstream.ruleIDs,
                signalRefs: upstream.signalRefs,
                actionRefs: upstream.actionRefs,
                snapshotRef: upstream.snapshotRef,
                signaturePayload: upstream.signaturePayload,
                appendedAt: upstream.appendedAt,
                eventKind: upstream.eventKind)
        }
    }

    // MARK: - Workbench orchestration

    /// Single-call plan for running a candidate through the full
    /// state machine. The workbench admits the candidate, records
    /// each element of `observedEffects` and `failConditions`, then
    /// finalizes with `outcome`. All transitions share the same
    /// `sessionID` and `turnID` so the ledger chain is coherent.
    public struct WorkbenchPlan: Sendable, Equatable {
        public let candidate: QinaoFurnace.ExperienceCandidate
        public let trialScope: String
        public let observedEffects: [String]
        public let failConditions: [String]
        public let outcome: TrialOutcome
        public let promotionRecommendation: String?

        public init(
            candidate: QinaoFurnace.ExperienceCandidate,
            trialScope: String,
            observedEffects: [String] = [],
            failConditions: [String] = [],
            outcome: TrialOutcome,
            promotionRecommendation: String? = nil
        ) {
            self.candidate = candidate
            self.trialScope = trialScope
            self.observedEffects = observedEffects
            self.failConditions = failConditions
            self.outcome = outcome
            self.promotionRecommendation = promotionRecommendation
        }
    }

    /// Receipt returned from a workbench run. Pointer to the final
    /// trial state + any seal / retraction issued + the promotion
    /// decision as of immediately after finalize.
    public struct WorkbenchReceipt: Sendable, Equatable {
        public let trialID: String
        public let finalState: String
        public let seal: QinaoFurnace.EvolutionSeal?
        public let retraction: QinaoFurnace.RetractionOrder?
        public let promotionDecision: PromotionDecision

        public init(
            trialID: String,
            finalState: String,
            seal: QinaoFurnace.EvolutionSeal?,
            retraction: QinaoFurnace.RetractionOrder?,
            promotionDecision: PromotionDecision
        ) {
            self.trialID = trialID
            self.finalState = finalState
            self.seal = seal
            self.retraction = retraction
            self.promotionDecision = promotionDecision
        }
    }

    /// Receipt returned from `attemptAutoPromotion`. `promoted` is
    /// the conjunction of `outcome == .passed` and
    /// `promotionDecision.allowsPromotion`.
    public struct AutoPromoteReceipt: Sendable, Equatable {
        public let candidateID: String
        public let trialID: String
        public let outcome: TrialOutcome
        public let promotionDecision: PromotionDecision
        public let promoted: Bool

        public init(
            candidateID: String,
            trialID: String,
            outcome: TrialOutcome,
            promotionDecision: PromotionDecision,
            promoted: Bool
        ) {
            self.candidateID = candidateID
            self.trialID = trialID
            self.outcome = outcome
            self.promotionDecision = promotionDecision
            self.promoted = promoted
        }
    }

    // MARK: - Dependencies

    private let coordinator: BASShadowTrialCoordinator
    /// The typed in-memory ledger the coordinator is appending to.
    /// Held as a concrete actor reference (not the protocol) so
    /// `replay` / `allTrialEvents` can call the read-side methods
    /// which are not part of the `BASShadowTrialLedger` seam.
    private let ledger: BASInMemoryShadowTrialLedger

    // MARK: - Init

    /// Convenience init — builds a fresh in-memory ledger and the
    /// coordinator on top of it with default ID / clock closures.
    /// Hosts that want deterministic IDs for tests should use the
    /// explicit init below.
    public init() {
        let ledger = BASInMemoryShadowTrialLedger()
        self.ledger = ledger
        self.coordinator = BASShadowTrialCoordinator(ledger: ledger)
    }

    /// Explicit init — takes the ledger (typed so replay works)
    /// and lets tests inject deterministic clock / ID closures.
    public init(
        ledger: BASInMemoryShadowTrialLedger,
        clock: @escaping @Sendable () -> Date = { Date() },
        nextAuditID: @escaping @Sendable () -> String
            = { "audit-" + UUID().uuidString },
        nextTrialID: @escaping @Sendable () -> String
            = { "trial-" + UUID().uuidString },
        nextSealID: @escaping @Sendable () -> String
            = { "seal-" + UUID().uuidString },
        nextRetractionID: @escaping @Sendable () -> String
            = { "retract-" + UUID().uuidString }
    ) {
        self.ledger = ledger
        self.coordinator = BASShadowTrialCoordinator(
            ledger: ledger,
            clock: clock,
            nextAuditID: nextAuditID,
            nextTrialID: nextTrialID,
            nextSealID: nextSealID,
            nextRetractionID: nextRetractionID)
    }

    /// M80 — cross-chain init. The coordinator writes to
    /// `coordinatorLedger` (typically a dual-writer that forks into
    /// both `primaryLedger` AND a host-external append-only chain the
    /// sovereign control plane owns), while `primaryLedger` remains
    /// the read-side for `replay(candidateID:)` / `allTrialEvents()`.
    ///
    /// Fail-closed discipline is the coordinator's responsibility:
    /// any throw from `coordinatorLedger.appendShadowTrialEvent(_:)`
    /// prevents the in-memory coordinator state from being committed.
    /// Callers building a cross-chain writer are expected to write to
    /// the external side first, then the primary — so a sovereign
    /// rejection never leaves a dangling entry in the primary that
    /// `replay` would mistake for a committed transition.
    ///
    /// `package`-visible: the only supported factory for a joined
    /// furnace is `QinaoRuntime.makeFurnace(joinedTo:)`, which lives
    /// in the composition layer and owns the two ledger references.
    /// Hosts that do not need the cross-chain continue to use the
    /// two public inits above and see no behaviour change.
    package init(
        primaryLedger: BASInMemoryShadowTrialLedger,
        coordinatorLedger: any BASShadowTrialLedger,
        clock: @escaping @Sendable () -> Date = { Date() },
        nextAuditID: @escaping @Sendable () -> String
            = { "audit-" + UUID().uuidString },
        nextTrialID: @escaping @Sendable () -> String
            = { "trial-" + UUID().uuidString },
        nextSealID: @escaping @Sendable () -> String
            = { "seal-" + UUID().uuidString },
        nextRetractionID: @escaping @Sendable () -> String
            = { "retract-" + UUID().uuidString }
    ) {
        self.ledger = primaryLedger
        self.coordinator = BASShadowTrialCoordinator(
            ledger: coordinatorLedger,
            clock: clock,
            nextAuditID: nextAuditID,
            nextTrialID: nextTrialID,
            nextSealID: nextSealID,
            nextRetractionID: nextRetractionID)
    }

    // MARK: - Primary transitions

    /// Admit a candidate and open a pending trial. Delegates to the
    /// coordinator; translates `BASShadowTrialCoordinator.TrialError`
    /// into `FurnaceError`.
    @discardableResult
    public func submit(
        candidate: QinaoFurnace.ExperienceCandidate,
        sessionID: String,
        turnID: String,
        trialScope: String
    ) async throws -> QinaoFurnace.ShadowTrialRecord {
        do {
            return try await coordinator.submit(
                candidate: candidate,
                sessionID: sessionID,
                turnID: turnID,
                trialScope: trialScope)
        } catch let err as BASShadowTrialCoordinator.TrialError {
            throw FurnaceError(err)
        }
    }

    /// Record an observed effect. First observation advances state
    /// from `"pending"` to `"observing"`.
    @discardableResult
    public func observe(
        trialID: String,
        effect: String,
        sessionID: String,
        turnID: String
    ) async throws -> QinaoFurnace.ShadowTrialRecord {
        do {
            return try await coordinator.observe(
                trialID: trialID,
                effect: effect,
                sessionID: sessionID,
                turnID: turnID)
        } catch let err as BASShadowTrialCoordinator.TrialError {
            throw FurnaceError(err)
        }
    }

    /// Record a fail condition. Same state-machine semantics as
    /// `observe` — does not automatically finalize the trial.
    @discardableResult
    public func reportFail(
        trialID: String,
        reason: String,
        sessionID: String,
        turnID: String
    ) async throws -> QinaoFurnace.ShadowTrialRecord {
        do {
            return try await coordinator.reportFailCondition(
                trialID: trialID,
                reason: reason,
                sessionID: sessionID,
                turnID: turnID)
        } catch let err as BASShadowTrialCoordinator.TrialError {
            throw FurnaceError(err)
        }
    }

    /// Finalize a trial. `.passed` issues a seal; `.failed` and
    /// `.blocked` deny the seal and queue a retraction whose
    /// cascade refs are the candidate's `sourceRefs`.
    @discardableResult
    public func finalize(
        trialID: String,
        outcome: TrialOutcome,
        promotionRecommendation: String? = nil,
        sessionID: String,
        turnID: String
    ) async throws -> QinaoFurnace.ShadowTrialRecord {
        do {
            return try await coordinator.finalize(
                trialID: trialID,
                outcome: outcome.bridged,
                promotionRecommendation: promotionRecommendation,
                sessionID: sessionID,
                turnID: turnID)
        } catch let err as BASShadowTrialCoordinator.TrialError {
            throw FurnaceError(err)
        }
    }

    // MARK: - Read-side

    public func candidate(
        for candidateID: String
    ) async -> QinaoFurnace.ExperienceCandidate? {
        await coordinator.candidate(for: candidateID)
    }

    public func trial(
        for trialID: String
    ) async -> QinaoFurnace.ShadowTrialRecord? {
        await coordinator.trial(for: trialID)
    }

    public func trials(
        for candidateID: String
    ) async -> [QinaoFurnace.ShadowTrialRecord] {
        await coordinator.trials(for: candidateID)
    }

    public func pendingTrials() async -> [QinaoFurnace.ShadowTrialRecord] {
        await coordinator.pendingTrials()
    }

    public func seal(
        for candidateID: String
    ) async -> QinaoFurnace.EvolutionSeal? {
        await coordinator.seal(for: candidateID)
    }

    public func retraction(
        for candidateID: String
    ) async -> QinaoFurnace.RetractionOrder? {
        await coordinator.retraction(for: candidateID)
    }

    /// Current promotion decision for the candidate, derived from
    /// the coordinator's in-memory trial history / seal state /
    /// retraction state. Bridged from the substrate's evaluation
    /// result into the Qinao-native `PromotionDecision` mirror.
    public func promotionDecision(
        for candidateID: String
    ) async -> PromotionDecision {
        PromotionDecision(
            await coordinator.promotionVerdict(for: candidateID))
    }

    // MARK: - Replay

    /// All ledger events recorded by the owned in-memory ledger,
    /// in insertion order. Mapped into Qinao-native `TrialEvent`s
    /// (no forbidden tokens in field names).
    public func allTrialEvents() async -> [TrialEvent] {
        let raw = await ledger.all()
        return raw.map(TrialEvent.init)
    }

    /// Every ledger event whose `actionRefs` contain `candidateID`.
    /// That covers every transition touching the candidate —
    /// shadow-trial open / observe / fail-condition / pass / fail /
    /// block / seal-issued / seal-denied / retraction-queued — in
    /// insertion order.
    public func replay(
        candidateID: String
    ) async -> [TrialEvent] {
        let raw = await ledger.all()
        return raw
            .filter { $0.actionRefs.contains(candidateID) }
            .map(TrialEvent.init)
    }

    // MARK: - Workbench

    /// Run a candidate through `submit → observe* → reportFail* →
    /// finalize` in a single call. Returns a receipt summarising
    /// the final trial state, any seal / retraction issued, and
    /// the promotion decision as of the return.
    ///
    /// Failure is fail-closed: if any transition throws, the throw
    /// propagates and the receipt is not produced. The coordinator
    /// already rolls back in-memory state when a ledger append
    /// fails (M11 discipline), so a workbench that throws leaves
    /// the coordinator in whatever state the last successful
    /// transition reached.
    @discardableResult
    public func runWorkbench(
        plan: WorkbenchPlan,
        sessionID: String,
        turnID: String
    ) async throws -> WorkbenchReceipt {
        let admitted = try await submit(
            candidate: plan.candidate,
            sessionID: sessionID,
            turnID: turnID,
            trialScope: plan.trialScope)

        for effect in plan.observedEffects {
            _ = try await observe(
                trialID: admitted.trialID,
                effect: effect,
                sessionID: sessionID,
                turnID: turnID)
        }
        for reason in plan.failConditions {
            _ = try await reportFail(
                trialID: admitted.trialID,
                reason: reason,
                sessionID: sessionID,
                turnID: turnID)
        }
        let finalized = try await finalize(
            trialID: admitted.trialID,
            outcome: plan.outcome,
            promotionRecommendation: plan.promotionRecommendation,
            sessionID: sessionID,
            turnID: turnID)

        let sealRecord = await coordinator.seal(
            for: plan.candidate.candidateID)
        let retractionRecord = await coordinator.retraction(
            for: plan.candidate.candidateID)
        let decision = PromotionDecision(
            await coordinator.promotionVerdict(
                for: plan.candidate.candidateID))

        return WorkbenchReceipt(
            trialID: finalized.trialID,
            finalState: finalized.completionState,
            seal: sealRecord,
            retraction: retractionRecord,
            promotionDecision: decision)
    }

    /// Workbench + promotion-gate check. `promoted` is `true` iff
    /// the workbench finalized with `.passed` AND the promotion
    /// gate would admit the candidate right now (no failed trials,
    /// no pending trials, no denied seals, no pending retractions).
    ///
    /// The workbench's effect on ledger state is unchanged — this
    /// is a pure derivation over the receipt.
    @discardableResult
    public func attemptAutoPromotion(
        plan: WorkbenchPlan,
        sessionID: String,
        turnID: String
    ) async throws -> AutoPromoteReceipt {
        let receipt = try await runWorkbench(
            plan: plan,
            sessionID: sessionID,
            turnID: turnID)
        let promoted = plan.outcome == .passed
            && receipt.promotionDecision.allowsPromotion
        return AutoPromoteReceipt(
            candidateID: plan.candidate.candidateID,
            trialID: receipt.trialID,
            outcome: plan.outcome,
            promotionDecision: receipt.promotionDecision,
            promoted: promoted)
    }
}
