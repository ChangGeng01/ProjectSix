import Foundation
import CryptoKit
import BASMemory
import QinaoMemory
import QinaoSovereign

/// M81 — cross-module bridge that wires the triple-gated offline
/// distillation exporter to the sovereign control plane's warrant
/// issuance.
///
/// Before M81, `QinaoLearningExporter` already implemented all three
/// gates in `QinaoRuntimeSDK/Sources/QinaoMemory/QinaoLearningExport.swift`:
///
///   1. **scrubbed** — deterministic PII regex pass over the
///      generalised skeleton.
///   2. **privacySafe** — sensitivity-boundary lookup against the
///      host-declared off-limits set.
///   3. **sovereignSafe** — caller-supplied approver closure
///      (`SovereignApprover`) that returns a non-nil token on
///      approval, `nil` on refusal.
///
/// The third gate was designed to take a closure that calls
/// `QinaoSovereignControlPlane.issueWarrant(for:)` under the hood,
/// but no composition-layer factory installed that closure for the
/// host. A host that wanted the full end-to-end path had to
/// hand-roll the bridge every time:
///
/// ```swift
/// // Pre-M81 boilerplate:
/// let exporter = QinaoLearningExporter(
///     approver: { candidate in
///         let intent = QinaoSovereignControlPlane.Intent(
///             digest: ...hand-rolled digest...,
///             sessionID: ...,
///             hostVersionID: ...)
///         do {
///             let warrant = try await plane.issueWarrant(for: intent)
///             return warrant.warrantID
///         } catch QinaoSovereignControlPlane.SovereignError
///             .sessionHalted {
///             return nil
///         }
///     })
/// ```
///
/// M81 replaces that boilerplate with a factory whose return value
/// is already wired to the sovereign control plane:
///
/// ```swift
/// let (plane, _) = QinaoSovereignControlPlane.bootstrap(
///     configuration: .init(
///         ledgerSigningSecret: Data("demo-secret".utf8)))
/// let exporter = QinaoRuntime.makeLearningExporter(
///     backedBy: plane,
///     sessionID: "session.distill.1",
///     hostVersionID: "host.v42")
/// let bundle = try await exporter.export(candidates: candidates)
/// // bundle.approvalToken now folds N warrant IDs (one per
/// // accepted candidate) under SHA-256. A downstream consumer
/// // that re-asks the plane for any individual warrant gets
/// // back the same ID.
/// ```
///
/// ## How the installed approver behaves
///
/// For each candidate the exporter sends across the sovereign gate,
/// the closure installed by this factory:
///
///   1. Builds a `QinaoSovereignControlPlane.Intent` whose `digest`
///      is SHA-256 over `sourceMemoryID || domain ||
///      generalizedSkeleton`. The digest is stable per-candidate, so
///      a warrant issued for one candidate cannot be misread as
///      approving another — swapping a candidate's skeleton after
///      approval would change its digest and break the warrant's
///      `intentDigest` binding.
///   2. Calls `plane.issueWarrant(for:)`. On success, returns the
///      warrant's `warrantID`; the exporter folds that ID into the
///      bundle's `approvalToken` (SHA-256 of concatenated warrant
///      IDs), which in turn feeds the bundle's overall `bundleDigest`.
///   3. Catches `SovereignError.sessionHalted(_)` and returns `nil`.
///      The exporter's `sovereignSafe` gate treats `nil` as a
///      sovereign refusal and emits a `.sovereignSafe` rejection
///      with code `sovereign-refused`; the whole bundle is refused
///      atomically (no partial emission — see
///      `QinaoLearningExport.swift` for the atomicity rationale).
///   4. Re-throws any other error. An unknown sovereign error should
///      not be silently degraded to "refused" — it's a bug signal
///      the host needs to see.
///
/// ## Fail-closed atomicity survives end-to-end
///
/// The existing three-gate discipline already refuses the whole
/// bundle on any rejection. The M81 bridge does not weaken that:
/// a single halted session on a single candidate still collapses
/// the entire export, because the approver returns `nil` and the
/// exporter's internal loop records the rejection and then throws
/// `.rejected` at the end of the sovereign stage. No partial bundle
/// is emitted, no side effects on the primary ledger, no leaked
/// warrant binding. This matches the M80 cross-chain ledger's own
/// fail-closed ordering (sovereign-first, primary-second) — at both
/// seams the sovereign side is authoritative and the other side
/// refuses to ship anything partial.
///
/// ## Why this lives in `QinaoRuntime`
///
/// `QinaoMemory` imports `BASMemory`; it cannot see
/// `QinaoSovereignControlPlane`. `QinaoSovereign` imports
/// `BASSovereign`; it cannot see `QinaoLearningExporter`. Only the
/// composition layer (`QinaoRuntime`) can import both. Keeping the
/// bridge here preserves the "每个 Qinao 模块只导入一层的 BAS 依赖"
/// invariant from the plan's module table and mirrors the M80
/// shadow-trial bridge pattern in `QinaoSovereignShadowTrialBridge.swift`.
///
/// ## Redaction compliance
///
/// The factory's public signature names only Qinao-local or
/// already-public types (`QinaoSovereignControlPlane`,
/// `QinaoMemory.PIIPattern`, `BASMemorySensitivity`,
/// `QinaoLearningExporter`). The closure's catch clause
/// reads the *case* `SovereignError.sessionHalted` but never names
/// any forbidden substrate module (IntegritySentinel, VerdictEngine,
/// TokenAuthority, AuditLedger, etc.) in a public declaration
/// fragment. `scripts/check_sovereign_redaction.sh` runs clean.
extension QinaoRuntime {

    /// M81 — build a `QinaoLearningExporter` whose `sovereignSafe` gate
    /// is wired to `controlPlane.issueWarrant(for:)`.
    ///
    /// The returned exporter behaves exactly like a hand-rolled
    /// `QinaoLearningExporter` except the `approver` parameter is
    /// already installed to call the sovereign control plane. All
    /// other gate knobs remain configurable:
    ///
    /// - `piiPatterns` replaces the default PII suite (e.g. for a
    ///   host that wants to prepend project-codename patterns).
    /// - `privateBoundary` replaces the default `[.high]`
    ///   sensitivity boundary (e.g. for a host that also considers
    ///   `.medium` off-limits for this particular export).
    /// - `now` injects a clock for deterministic testing.
    ///
    /// Every candidate the exporter accepts will first be shaped
    /// into a `QinaoSovereignControlPlane.Intent` (digest over
    /// `sourceMemoryID || domain || generalizedSkeleton`) and
    /// submitted to `issueWarrant(for:)`. A non-nil warrant ID is
    /// carried into the bundle's `approvalToken`; a `sessionHalted`
    /// refusal is captured as a `.sovereignSafe` rejection and the
    /// whole bundle is refused atomically.
    ///
    /// ## Parameters
    ///
    /// - Parameter controlPlane: the sovereign control plane the
    ///   approver closure consults. The factory does not retain
    ///   the plane itself — the closure captures the actor
    ///   reference (actors are `Sendable`), and the exporter holds
    ///   the closure.
    /// - Parameter sessionID: session identifier every candidate's
    ///   intent carries. Export is conceptually a discrete
    ///   sovereign-supervised episode; all candidates in one export
    ///   share one session. A halted session refuses the whole
    ///   export — that is the fail-closed property this parameter
    ///   enables.
    /// - Parameter hostVersionID: host version the export is tied
    ///   to. The control plane records this on each warrant so a
    ///   future rollback past this version can invalidate any
    ///   bundle still in flight.
    /// - Parameter piiPatterns: PII regex suite for the scrubbed
    ///   gate. Defaults to `QinaoMemory.PIIPattern.standardSuite`.
    /// - Parameter privateBoundary: sensitivity values that are
    ///   off-limits for export. Defaults to `[.high]`.
    /// - Parameter now: injected clock for deterministic testing.
    ///   Defaults to `Date()`.
    ///
    /// - Returns: a wired `QinaoLearningExporter` ready to accept
    ///   candidates via `export(candidates:)`.
    ///
    /// - SeeAlso: `QinaoLearningExporter.export(candidates:)`,
    ///   `QinaoSovereignControlPlane.issueWarrant(for:)`,
    ///   `QinaoRuntime.makeFurnace(joinedTo:)` (M80 sibling factory).
    public static func makeLearningExporter(
        backedBy controlPlane: QinaoSovereignControlPlane,
        sessionID: String,
        hostVersionID: String,
        piiPatterns: [QinaoMemory.PIIPattern]
            = QinaoMemory.PIIPattern.standardSuite,
        privateBoundary: Set<BASMemorySensitivity> = [.high],
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> QinaoLearningExporter {
        let approver: QinaoLearningExporter.SovereignApprover
        approver = { candidate in
            let intent = QinaoSovereignControlPlane.Intent(
                digest: Self.candidateIntentDigest(candidate),
                sessionID: sessionID,
                hostVersionID: hostVersionID)
            do {
                let warrant = try await controlPlane.issueWarrant(
                    for: intent)
                return warrant.warrantID
            } catch QinaoSovereignControlPlane.SovereignError
                .sessionHalted(_)
            {
                // The sovereign gate treats `nil` as a soft refusal
                // and records a `.sovereignSafe` rejection; the
                // bundle fails closed downstream.
                return nil
            }
        }
        return QinaoLearningExporter(
            piiPatterns: piiPatterns,
            privateBoundary: privateBoundary,
            approver: approver,
            now: now)
    }

    /// Deterministic SHA-256 digest for a learning-export candidate.
    ///
    /// Identical `sourceMemoryID || domain || generalizedSkeleton`
    /// produces identical digest. Used to bind a warrant to the
    /// exact candidate it approved — a warrant issued for one
    /// candidate cannot be misread as approving another, because
    /// swapping any of the three fields changes the digest and
    /// breaks the warrant's `intentDigest` binding.
    ///
    /// Visibility is `internal` so the test suite can verify
    /// determinism and field-sensitivity directly without going
    /// through the full factory. External callers never need to
    /// compute the digest themselves — the factory installs it in
    /// the approver closure.
    internal static func candidateIntentDigest(
        _ candidate: QinaoMemory.LearningExportCandidate
    ) -> String {
        let payload =
            candidate.sourceMemoryID.uuidString
            + "|" + candidate.domain
            + "|" + candidate.generalizedSkeleton
        let hash = SHA256.hash(data: Data(payload.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
