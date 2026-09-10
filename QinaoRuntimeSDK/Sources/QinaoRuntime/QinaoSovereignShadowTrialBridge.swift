import Foundation
import BASMemory
import BASSovereign
import BASOrchestration
import QinaoHost
import QinaoSovereign

/// M80 — cross-chain shadow-trial ledger.
///
/// Before M80, `QinaoFurnace` (L13) and `QinaoSovereignControlPlane`
/// (L14) each owned an independent append-only chain: the furnace
/// wrote shadow-trial events to its in-memory `BASInMemoryShadowTrialLedger`,
/// and the control plane wrote verdicts / warrants / coverage reads
/// to its `BASSovereignAuditLedger`. Two chains, two hash roots,
/// zero cryptographic linkage. That was the last seam on the honesty
/// board's invariant 3 row ("宿主私有经验不进基础权重") — a host could
/// pass a shadow trial and have the event forgotten from the
/// sovereign-audited record, because the two chains didn't share
/// state.
///
/// M80 closes the seam. `QinaoSovereignCrossChainLedger` is an actor
/// that conforms to `BASShadowTrialLedger` (the protocol the
/// `BASShadowTrialCoordinator` appends through) and forks every
/// shadow-trial event onto both:
///
///   1. The sovereign append-only chain (via the
///      `BASSovereignAuditLedger: BASShadowTrialLedger` extension
///      that already exists in `BASOrchestration`), and
///   2. The furnace-owned in-memory ledger (so replay still works
///      without reaching into the sovereign side).
///
/// ## Fail-closed order
///
/// Write sovereign FIRST, primary SECOND. Reasoning:
///
/// - If the sovereign append throws (integrity break, missing signing
///   secret, invalid entry), nothing is written to primary. The
///   coordinator sees the throw and rolls back its in-memory state.
///   `replay(candidateID:)` stays clean.
/// - If the primary append throws (extremely rare — only happens
///   when the in-memory ledger is configured with a `failWhen`
///   closure in tests), the sovereign side has already recorded the
///   attempt. That is acceptable: the sovereign chain is meant to
///   record every attempted transition; an audit entry for an attempt
///   the coordinator rolled back is a truthful "we tried and it
///   didn't land" record.
///
/// The inverse order (primary first) would leak a stale entry into
/// primary on sovereign failure, and `replay` would then report a
/// transition the coordinator rolled back. That violates the read
/// contract.
///
/// ## Why this lives in `QinaoRuntime`
///
/// `QinaoHost` imports only `BASMemory`; it cannot see
/// `BASSovereignAuditLedger`. `QinaoSovereign` imports only
/// `BASSovereign`; it cannot see `BASShadowTrialLedger`. Only the
/// composition layer (`QinaoRuntime`) can import both plus
/// `BASOrchestration` (which provides the
/// `BASSovereignAuditLedger: BASShadowTrialLedger` conformance).
/// Keeping the bridge here preserves the "每个 Qinao 模块只导入一层
/// 的 BAS 依赖" invariant from the plan's module table.
///
/// ## Visibility
///
/// The actor is `internal` — tests use `@testable import QinaoRuntime`
/// to reach it; hosts use the `QinaoRuntime.makeFurnace(joinedTo:)`
/// factory at the bottom of this file, which is the only public
/// entry point. No Qinao public API mentions
/// `BASSovereignAuditLedger` by name (that would trip the redaction
/// scanner — "AuditLedger" is a forbidden token).
actor QinaoSovereignCrossChainLedger: BASShadowTrialLedger {

    /// In-memory read-side ledger the furnace hands to replay
    /// (`allTrialEvents()` / `replay(candidateID:)`).
    private let primary: BASInMemoryShadowTrialLedger

    /// External append-only chain that outlives any one furnace
    /// instance. Supplied as the protocol seam so tests can inject
    /// a failing stub to exercise fail-closed ordering; in the
    /// production path it is the sovereign control plane's audit
    /// chain.
    private let external: any BASShadowTrialLedger

    init(
        primary: BASInMemoryShadowTrialLedger,
        external: any BASShadowTrialLedger
    ) {
        self.primary = primary
        self.external = external
    }

    /// Fork the entry onto both chains (external first, primary
    /// second). Returns the primary's append reference, which for
    /// `BASInMemoryShadowTrialLedger` and `BASSovereignAuditLedger`
    /// both match `entry.auditID` — callers who use the return
    /// value as a correlation key are working against the same ID
    /// on either side.
    func appendShadowTrialEvent(
        _ entry: BASShadowTrialLedgerEntry
    ) async throws -> String {
        // Step 1: sovereign (fail-closed). If this throws, the
        // coordinator receives the throw and rolls back in-memory
        // state. The primary ledger is never touched.
        _ = try await external.appendShadowTrialEvent(entry)
        // Step 2: primary (the read-side). Any throw here leaves
        // the sovereign side with a recorded attempt — acceptable
        // per the fail-closed rationale in the type doc.
        return try await primary.appendShadowTrialEvent(entry)
    }
}

extension QinaoRuntime {

    /// M80 — build a `QinaoFurnace` whose shadow-trial ledger
    /// writes are forked onto the control plane's append-only
    /// chain. Every `submit / observe / reportFail / finalize`
    /// transition appends an entry to the sovereign chain AND the
    /// furnace's in-memory read-side ledger; if the sovereign side
    /// rejects the append (integrity break, BR-012 red line) the
    /// coordinator rolls back and no side records a committed
    /// transition.
    ///
    /// This is the path the plan's invariant 3 ("宿主私有经验不进
    /// 基础权重") has been promising: the host private experience
    /// pipeline is NOT confined to a local in-memory log — every
    /// transition is co-signed onto the sovereign audit chain, and
    /// chain integrity of the sovereign side is a necessary
    /// condition for trusting the evolution side.
    ///
    /// ```swift
    /// let (plane, _) = QinaoSovereignControlPlane.bootstrap(
    ///     configuration: .init(
    ///         ledgerSigningSecret: Data("demo-secret".utf8)))
    /// let furnace = await QinaoRuntime.makeFurnace(joinedTo: plane)
    /// try await furnace.submit(
    ///     candidate: candidate,
    ///     sessionID: sessionID, turnID: turnID,
    ///     trialScope: "scope.growth")
    /// // Ledger-side: primary has 1 entry, sovereign chain has 1 entry,
    /// // both keyed by the same auditID, both under one hash chain root.
    /// ```
    ///
    /// The returned furnace is independent from the control plane's
    /// rollback / warrant flows — halt / rollback actions taken on
    /// the plane do not implicitly freeze the furnace. The joining
    /// is about shared audit evidence, not shared locking.
    public static func makeFurnace(
        joinedTo controlPlane: QinaoSovereignControlPlane
    ) async -> QinaoFurnace {
        let primary = BASInMemoryShadowTrialLedger()
        let sovereignChain = await controlPlane.sharedAppendOnlyChain()
        let cross = QinaoSovereignCrossChainLedger(
            primary: primary,
            external: sovereignChain)
        return QinaoFurnace(
            primaryLedger: primary,
            coordinatorLedger: cross)
    }
}
