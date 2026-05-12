import Foundation
import BASRuntimeCore

/// Coordinates the sovereign "clean reboot" path — what happens
/// when the verdict engine returns `.rollback` or `.deadStop`.
///
/// ## Why this exists
///
/// Before today the `.rollback` and `.deadStop` verdict levels were
/// *strings the engine returned* — nothing actually orchestrated a
/// safe reboot. A verdict could say "rollback" and the runtime
/// could happily keep running, because the sovereign kernel exposed
/// no coordinated teardown path.
///
/// This coordinator is the missing path. It does NOT execute
/// teardown itself (process lifetime belongs to the façade layer);
/// it produces a `RebootPlan` that names:
///
/// 1. The target host version to restore to (latest-known-good
///    ancestor, with chain integrity verified against the snapshot
///    manager).
/// 2. The action sequence the façade must run: quarantine current
///    session, teardown active locks, close the audit ledger for
///    this session, restore from the chosen snapshot, boot a fresh
///    session.
/// 3. A single `auditRef` so the entire reboot is traceable.
///
/// On `.deadStop` we still return a plan — but with
/// `bootstrapNextSession = false`. The façade is expected to
/// surface the deadStop reason to the host and wait for an explicit
/// human intervention before booting again.
public actor BASSovereignCleanRebootCoordinator {
    public enum CoordinatorError: Error, Equatable, Sendable {
        case verdictDoesNotRequireReboot(level: BASSovereignVerdictLevel)
        case noKnownGoodAncestor(fromVersionID: String)
        case currentVersionUnknown(id: String)
        case snapshotNotRegistered(anchorID: String)
        case versionHasNoAnchor(versionID: String)
    }

    /// Single step in the reboot sequence. Purely declarative — the
    /// façade is the actor that actually performs each.
    public enum RebootAction: String, Sendable, Equatable, Codable {
        case quarantineActiveSession
        case releaseSovereignLocks
        case closeAuditLedgerForSession
        case restoreSnapshot
        case verifyRestoredIntegrity
        case bootstrapNextSession
        case haltAndAwaitHostIntervention
    }

    public struct RebootPlan: Sendable, Equatable {
        public let planID: String
        public let sessionID: String
        public let sourceVersionID: String
        public let targetVersionID: String
        public let targetAnchorID: String
        public let actions: [RebootAction]
        public let auditRef: String
        public let verdictLevel: BASSovereignVerdictLevel
        public let bootstrapNextSession: Bool
        public let issuedAt: Date
    }

    // MARK: - Dependencies

    private let snapshotManager: BASSovereignSnapshotManager
    private let versionTree: BASSovereignHostVersionTree
    private let ledger: BASSovereignAuditLedger
    private let now: @Sendable () -> Date

    /// chapter 五百三十九 / M1534 — typed observability
    /// sink for the documented silent-swallow at the
    /// reboot-plan audit append site (line ~237)。 nil
    /// → behavior unchanged (silent swallow per the
    /// coordinator's best-effort audit-trail contract);
    /// non-nil → record each failed append。
    private let auditFailureLog:
        BASAuditEmissionFailureLog?

    /// Map from hostVersionID → anchorID. Populated by `bindAnchor`
    /// whenever a snapshot is registered for a known version. The
    /// coordinator needs this to pick an anchor for a given
    /// rollback target.
    private var anchorByVersion: [String: String] = [:]

    public init(
        snapshotManager: BASSovereignSnapshotManager,
        versionTree: BASSovereignHostVersionTree,
        ledger: BASSovereignAuditLedger,
        now: @escaping @Sendable () -> Date = { Date() },
        auditFailureLog:
            BASAuditEmissionFailureLog? = nil
    ) {
        self.snapshotManager = snapshotManager
        self.versionTree = versionTree
        self.ledger = ledger
        self.now = now
        self.auditFailureLog = auditFailureLog
    }

    // MARK: - Anchor binding

    /// Bind a registered snapshot anchor to a host version. The
    /// coordinator refuses bindings where the anchor isn't known to
    /// the snapshot manager or the version isn't known to the tree.
    public func bindAnchor(
        anchorID: String,
        toVersionID versionID: String
    ) async throws {
        let anchorKnown = await snapshotManager.isRegistered(
            anchorID: anchorID)
        guard anchorKnown else {
            throw CoordinatorError.snapshotNotRegistered(
                anchorID: anchorID)
        }
        guard await versionTree.node(versionID) != nil else {
            throw CoordinatorError.currentVersionUnknown(id: versionID)
        }
        anchorByVersion[versionID] = anchorID
    }

    public func anchor(forVersion versionID: String) -> String? {
        anchorByVersion[versionID]
    }

    // MARK: - Plan generation

    /// Given a verdict that demands a reboot, compute the plan.
    ///
    /// Preconditions:
    /// - `verdict.verdictLevel` must be `.rollback` or `.deadStop`.
    /// - `currentHostVersionID` must be registered with the tree.
    /// - The rollback target (latest-known-good ancestor) must have
    ///   an anchor bound.
    public func planReboot(
        verdict: BASSovereignVerdict,
        sessionID: String,
        currentHostVersionID: String
    ) async throws -> RebootPlan {
        guard
            verdict.verdictLevel == .rollback
                || verdict.verdictLevel == .deadStop
        else {
            throw CoordinatorError.verdictDoesNotRequireReboot(
                level: verdict.verdictLevel)
        }

        guard
            await versionTree.node(currentHostVersionID) != nil
        else {
            throw CoordinatorError.currentVersionUnknown(
                id: currentHostVersionID)
        }

        // Rollback target selection: walk from current (inclusive)
        // up through ancestors. Skip bad nodes. The first good node
        // with an anchor bound wins. Track the first good node we
        // encounter ("nearest good") so that if the walk ends
        // without finding a good-with-anchor, we can still surface a
        // precise `versionHasNoAnchor` error keyed to what would
        // have been the target in a better-bound tree.
        //
        // This reconciles three semantics that the suite exercises:
        //   1. "rollback from v1 where only v0 has an anchor" picks
        //      v0, not v1 — rollback prefers a bound ancestor.
        //   2. "rollback from v0 (no anchor anywhere)" surfaces
        //      versionHasNoAnchor(v0), not noKnownGoodAncestor —
        //      the tree has a good target, the coordinator just
        //      can't execute on it.
        //   3. "rollback from v0 where v0 is bad" surfaces
        //      noKnownGoodAncestor — no trustworthy target at all.
        // node(_:) is non-throwing (returns Node?);ancestors(of:)
        // throws — keep `try` only on the latter
        let walkStart = await versionTree.node(currentHostVersionID)
        let walkAncestors =
            try await versionTree.ancestors(of: currentHostVersionID)
        let walk: [BASSovereignHostVersionTree.Node] =
            (walkStart.map { [$0] } ?? []) + walkAncestors

        var nearestGood: BASSovereignHostVersionTree.Node?
        var chosen: (node: BASSovereignHostVersionTree.Node,
                     anchor: String)?
        for node in walk where node.isKnownGood {
            if nearestGood == nil { nearestGood = node }
            if let anc = anchorByVersion[node.versionID] {
                chosen = (node, anc)
                break
            }
        }

        guard let (targetNode, anchor) = chosen else {
            if let fallback = nearestGood {
                throw CoordinatorError.versionHasNoAnchor(
                    versionID: fallback.versionID)
            }
            throw CoordinatorError.noKnownGoodAncestor(
                fromVersionID: currentHostVersionID)
        }

        let bootstrap = verdict.verdictLevel == .rollback
        let actions: [RebootAction] = {
            var seq: [RebootAction] = [
                .quarantineActiveSession,
                .releaseSovereignLocks,
                .closeAuditLedgerForSession,
                .restoreSnapshot,
                .verifyRestoredIntegrity,
            ]
            if bootstrap {
                seq.append(.bootstrapNextSession)
            } else {
                seq.append(.haltAndAwaitHostIntervention)
            }
            return seq
        }()

        let planID = "rp-\(UUID().uuidString)"
        let auditID = "ar-\(UUID().uuidString)"
        let plan = RebootPlan(
            planID: planID,
            sessionID: sessionID,
            sourceVersionID: currentHostVersionID,
            targetVersionID: targetNode.versionID,
            targetAnchorID: anchor,
            actions: actions,
            auditRef: auditID,
            verdictLevel: verdict.verdictLevel,
            bootstrapNextSession: bootstrap,
            issuedAt: now())

        // Record the plan in the ledger. Failure to append is NOT
        // fatal to plan generation — the caller needs the plan even
        // if the ledger is degraded — but we attempt best-effort so
        // a successful plan ALWAYS has a trail.
        let entry = BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: sessionID,
            turnID: verdict.verdictID,
            verdictRef: verdict.verdictID,
            ruleIDs: ["REBOOT_PLAN:\(verdict.verdictLevel.rawValue)"],
            signalRefs: [],
            actionRefs: actions.map(\.rawValue),
            snapshotRef: anchor,
            actor: .system,
            signature: "",
            appendedAt: plan.issuedAt)
        // chapter 五百三十九 / M1534 — wire-in of typed
        // observability sink (M1533)。 Default nil →
        // silent swallow continues (best-effort audit
        // trail per the coordinator's contract);non-nil
        // → record failure with kind
        // `.sovereignRebootAuditAppend` for diagnostic
        // inspection。 ADR-014 OPT-IN preserved。
        do {
            try await ledger.append(entry)
        } catch {
            if let failureLog = auditFailureLog {
                await failureLog.record(
                    kind: .sovereignRebootAuditAppend,
                    error: error,
                    turnID: verdict.verdictID,
                    sessionID: sessionID)
            }
        }

        return plan
    }

    // MARK: - Plan execution helpers (verification only)

    /// Verify that the restored snapshot matches the plan's target
    /// anchor. Called by the façade after the restore action has
    /// re-hydrated the payload from durable storage. Returns `true`
    /// iff integrity holds.
    public func verifyRestoredPayload(
        plan: RebootPlan,
        presentedPayload: Data
    ) async -> Bool {
        do {
            try await snapshotManager.verifyRestore(
                anchorID: plan.targetAnchorID,
                presentedPayload: presentedPayload)
            return true
        } catch {
            return false
        }
    }
}
