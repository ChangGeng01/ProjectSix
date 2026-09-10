import Foundation
import QinaoRisk
import QinaoSovereign

// M103 — T8(b) composition-layer bridge between
// `QinaoRiskGate.PermitEventRecorder` (M99) and
// `QinaoSovereignControlPlane.recordPermitIssued` (M103 sovereign
// half). Pre-M103 the two sides were fully ready in isolation but
// no wire existed between them — M99 left the recorder shape
// abstract and M103's sovereign method was only reachable through
// hand-built closures. This extension provides the canonical
// one-liner glue so hosts can drop-in the wiring.
//
// Why this lives on `QinaoRuntime`: `QinaoRuntime` is the only
// Qinao module that imports both `QinaoRisk` (supplying
// `ActionPermit` + `PermitEventRecorder` typealias) and
// `QinaoSovereign` (supplying `QinaoSovereignControlPlane`).
// Putting the bridge elsewhere would force one of those modules
// to import the other, violating the "each Qinao module imports
// one layer's BAS deps and sibling Qinao modules only as needed"
// boundary rule enforced by `check_qinao_import_boundaries.sh`.

extension QinaoRuntime {

    /// Return a closure suitable for
    /// `QinaoRiskGate(permitEventRecorder:)` that forwards every
    /// successfully-issued permit to
    /// `QinaoSovereignControlPlane.recordPermitIssued`, which
    /// appends a hash-chained `permit:issued` entry to the L14
    /// audit ledger.
    ///
    /// Fail-closed: if the ledger append throws (signature
    /// failure, invalid entry), the error propagates back through
    /// the recorder closure into `requestActionPermit`, which
    /// re-raises to the caller. The caller never sees the permit
    /// — matching the "append 失败立刻 halt" contract in plan
    /// §T8.
    ///
    /// Projection at the bridge site is pure value transform —
    /// the permit's primitive fields (permitID, sessionID, digest,
    /// reasonCodes, issuedAt) are forwarded directly.
    /// `ActionPermit` is never passed across the Qinao module
    /// boundary; the sovereign side sees only primitives.
    ///
    /// Usage:
    /// ```swift
    /// let sovereign = QinaoSovereignControlPlane.bootstrap(...)
    /// let risk = QinaoRiskGate(
    ///     permitTTLSeconds: 30,
    ///     permitEventRecorder:
    ///         QinaoRuntime.makeSovereignPermitEventRecorder(
    ///             sovereign: sovereign))
    /// ```
    ///
    /// - Parameter sovereign: the sovereign control plane whose
    ///   audit ledger should receive permit events.
    /// - Returns: a `PermitEventRecorder` closure ready to pass
    ///   to `QinaoRiskGate.init(permitEventRecorder:)`.
    public static func makeSovereignPermitEventRecorder(
        sovereign: QinaoSovereignControlPlane
    ) -> QinaoRiskGate.PermitEventRecorder {
        return { @Sendable permit in
            try await sovereign.recordPermitIssued(
                permitID: permit.permitID,
                sessionID: permit.sessionID,
                digest: permit.digest,
                reasonCodes: permit.reasonCodes,
                issuedAt: permit.issuedAt)
        }
    }
}
