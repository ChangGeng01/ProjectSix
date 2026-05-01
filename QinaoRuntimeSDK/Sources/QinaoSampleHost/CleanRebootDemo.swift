import Foundation
import BASRuntimeCore
import BASSovereign

/// M322 — clean-reboot demo.
///
/// Drives `BASSovereignCleanRebootCoordinator` through a typical
/// rollback + deadStop scenario so hosts on first-day integration
/// see the M296.1 "净启" (clean reboot) contract end-to-end.
/// Pre-M322 the coordinator was production-shipped (chapter 56.1)
/// but no sample/demo path exercised it; the white paper M296.1
/// promise was reachable only via tests.
///
/// What the demo proves
///
///   1. A `.rollback` verdict against a tainted version selects
///      the latest known-good ancestor with a bound snapshot
///      anchor.
///   2. The resulting plan ALWAYS contains `quarantineActiveSession`
///      → `releaseSovereignLocks` → `closeAuditLedgerForSession`
///      → `restoreSnapshot` → `verifyRestoredIntegrity` plus
///      `bootstrapNextSession` (rollback) or
///      `haltAndAwaitHostIntervention` (deadStop).
///   3. The plan is recorded in the audit ledger with a single
///      `auditRef`.
///   4. A `.deadStop` verdict skips bootstrap.
///
/// ## Doctrine
///
/// - **Coordinator does not execute.** It produces a typed plan;
///   the façade is the actor that quarantines / restores /
///   bootstraps. Demo only inspects the plan.
/// - **No verdict mutation.** Demo synthesises verdicts at
///   `.rollback` and `.deadStop` levels; the coordinator's
///   precondition check rejects anything else (typed contract).
/// - **No real snapshot restore.** The fixture registers a
///   minimal anchor + genesis tree + a single tainted child,
///   enough to exercise the rollback target selection logic.
public struct CleanRebootDemo {

    /// One scenario's observable result. The demo runs two
    /// scenarios (rollback + deadStop); banner renders both.
    public struct ScenarioRecord: Sendable, Equatable {
        public let scenarioName: String
        public let verdictLevel: String
        public let sourceVersionID: String
        public let targetVersionID: String
        public let targetAnchorID: String
        public let actions: [String]
        public let bootstrapNextSession: Bool
        public let auditRef: String

        public init(
            scenarioName: String,
            verdictLevel: String,
            sourceVersionID: String,
            targetVersionID: String,
            targetAnchorID: String,
            actions: [String],
            bootstrapNextSession: Bool,
            auditRef: String
        ) {
            self.scenarioName = scenarioName
            self.verdictLevel = verdictLevel
            self.sourceVersionID = sourceVersionID
            self.targetVersionID = targetVersionID
            self.targetAnchorID = targetAnchorID
            self.actions = actions
            self.bootstrapNextSession = bootstrapNextSession
            self.auditRef = auditRef
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let rollback: ScenarioRecord
        public let deadStop: ScenarioRecord
        public let auditEntryCount: Int

        public init(
            rollback: ScenarioRecord,
            deadStop: ScenarioRecord,
            auditEntryCount: Int
        ) {
            self.rollback = rollback
            self.deadStop = deadStop
            self.auditEntryCount = auditEntryCount
        }
    }

    // MARK: - Fixture builders

    private static func buildStack() async throws -> (
        snapshots: BASSovereignSnapshotManager,
        tree: BASSovereignHostVersionTree,
        ledger: BASSovereignAuditLedger,
        coord: BASSovereignCleanRebootCoordinator
    ) {
        let snapshots = BASSovereignSnapshotManager()
        let tree = BASSovereignHostVersionTree()
        let ledger = BASSovereignAuditLedger.withSeed(
            "qinao-clean-reboot-demo")
        let coord = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshots,
            versionTree: tree,
            ledger: ledger)
        // Stack: v0 (good, anchor bound) ← v1 (tainted, current
        // for rollback scenario).
        let payload = Data("clean-reboot-demo-genesis".utf8)
        let anchor = BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: "anchor-v0",
            safeSnapshotRef: "safe-anchor-v0",
            integrityHash:
                BASSovereignSnapshotManager.hash(payload))
        try await snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await tree.registerGenesis(versionID: "v0")
        try await tree.registerVersion(
            versionID: "v1", parentID: "v0",
            diffSummary: "demo: tainted child")
        try await tree.markBad(
            versionID: "v1",
            reason: "demo-only tainted lineage")
        try await coord.bindAnchor(
            anchorID: "anchor-v0", toVersionID: "v0")
        return (snapshots, tree, ledger, coord)
    }

    private static func makeVerdict(
        level: BASSovereignVerdictLevel
    ) -> BASSovereignVerdict {
        BASSovereignVerdict(
            verdictID: "v-\(UUID().uuidString)",
            verdictLevel: level,
            latched: true,
            reasonCodes: ["BR-004", "demo:reboot-trigger"],
            revokedPermissions: [],
            userStubMode: .refusalOnly,
            policyHash:
                BASSovereignTrustConstants.builtInPolicyHash)
    }

    /// Run both rollback + deadStop scenarios against a fresh
    /// stack. Returns an `Outcome` carrying the two plans for
    /// the banner.
    public static func run() async throws -> Outcome {
        let stack = try await buildStack()

        // Scenario 1: rollback from v1 (tainted) → v0 (good).
        // Coordinator must walk ancestors, skip v1, land on v0,
        // and emit a plan with `bootstrapNextSession = true`.
        let rollbackPlan = try await stack.coord.planReboot(
            verdict: makeVerdict(level: .rollback),
            sessionID: "session-rollback",
            currentHostVersionID: "v1")

        // Scenario 2: deadStop while running on v0 (good but
        // engine has decided to halt). Plan must use v0 itself
        // as target and emit `haltAndAwaitHostIntervention`.
        let deadStopPlan = try await stack.coord.planReboot(
            verdict: makeVerdict(level: .deadStop),
            sessionID: "session-deadstop",
            currentHostVersionID: "v0")

        let entryCount = await stack.ledger.count()
        return Outcome(
            rollback: makeRecord(
                scenarioName: "rollback",
                plan: rollbackPlan),
            deadStop: makeRecord(
                scenarioName: "deadStop",
                plan: deadStopPlan),
            auditEntryCount: entryCount)
    }

    private static func makeRecord(
        scenarioName: String,
        plan: BASSovereignCleanRebootCoordinator.RebootPlan
    ) -> ScenarioRecord {
        ScenarioRecord(
            scenarioName: scenarioName,
            verdictLevel: plan.verdictLevel.rawValue,
            sourceVersionID: plan.sourceVersionID,
            targetVersionID: plan.targetVersionID,
            targetAnchorID: plan.targetAnchorID,
            actions: plan.actions.map(\.rawValue),
            bootstrapNextSession: plan.bootstrapNextSession,
            auditRef: plan.auditRef)
    }
}
