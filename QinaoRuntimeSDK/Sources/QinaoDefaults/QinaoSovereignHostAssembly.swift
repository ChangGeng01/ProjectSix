// integration S2 (2026-07-12) — the LLM-free integrated Qinao SDK host assembly.
//
// Charter: Docs/QINAO_INTEGRATION_CHARTER_2026-07-12.md. Operator directive: ALL Qinao
// components compose into one SDK host; the LLM stays OUTSIDE a clean boundary and crosses
// it only as data.
//
// This is QinaoRuntime's first production construction path (turn-path audit finding C:
// the façade previously had zero non-test constructors). One call composes:
//   QinaoHost + QinaoMemory (S1: participates in sendSession) + QinaoRiskGate (with the
//   M103 permit→sovereign-audit wire) + QinaoSovereignControlPlane (persistent keyed
//   ledger when a path is given) + endpoint-LESS QinaoLoop over a seeded world-prior
//   vault + the full 9-seat council + QinaoRuntime (P0–P9 sendSession, coverage, halt,
//   three-signature execute).
//
// BOUNDARY (mechanically pinned by QinaoBoundaryPinTests): this module has NO dependency
// on QinaoAppleFoundation / QinaoMLX. The loop's organEndpoint stays nil — generation
// paths give the existing typed refusal ("no-endpoint-configured"). A host that wants an
// LLM attaches an endpoint on ITS side of the boundary and feeds results back as data
// (TurnInputs observations / CandidateInput / memory admissions).

import Foundation
import CryptoKit
import BASRuntimeCore
import BASMemory
import QinaoHost
import QinaoMemory
import QinaoRisk
import QinaoSovereign
import QinaoLoop
import QinaoLoopSeats
import QinaoSeats
import QinaoWorldPrior
import QinaoRuntime

/// The integrated, LLM-free sovereign host. Every component is reachable so hosts can
/// admit memories, register extra seats, or drive `runtime.sendSession` / `execute`
/// directly; the runtime is the turn-driving spine.
public struct QinaoSovereignHost: Sendable {
    public let runtime: QinaoRuntime
    public let loop: QinaoLoop
    public let seats: QinaoSeatRegistry
    public let sovereign: QinaoSovereignControlPlane
    public let substrate: QinaoSovereignControlPlane.SubstrateHandle
    public let memory: QinaoMemory
    public let risk: QinaoRiskGate
    public let host: QinaoHost
}

extension QinaoDefaults {

    /// One-call factory for the integrated LLM-free sovereign host.
    ///
    /// - Parameters:
    ///   - hostID / activeVersion: host constitution identity.
    ///   - ledgerSigningSecret: HMAC secret for the sovereign audit ledger chain.
    ///   - ledgerDatabasePath: when non-nil, the keyed ledger persists to SQLite at this
    ///     path (created on cold start, rehydrated on reopen; open failure is FATAL per
    ///     ledger doctrine). Nil = in-memory (tests / ephemeral hosts).
    ///   - toolExecutor: the host's tool side-effect surface, guarded by the runtime's
    ///     three-signature gate.
    ///   - now: injectable clock (tests pass a frozen clock).
    public static func makeSovereignHost(
        hostID: String,
        activeVersion: String,
        ledgerSigningSecret: Data,
        ledgerDatabasePath: String? = nil,
        tokenSigningKey: Data? = nil,
        warrantTTLSeconds: TimeInterval = 30,
        permitTTLSeconds: TimeInterval = 30,
        toolExecutor: @escaping QinaoRuntime.ToolExecutor,
        now: @escaping @Sendable () -> Date = { Date() },
        lifecycle: QinaoLifecycle? = nil,
        metricsRecorder: QinaoRuntime.MetricsRecorder? = nil
    ) async throws -> QinaoSovereignHost {
        // Sovereign control plane — the ONLY public construction path (bootstrap).
        // Persistent keyed ledger iff ledgerDatabasePath is non-nil.
        let (sovereign, substrate) = QinaoSovereignControlPlane.bootstrap(
            configuration: .init(
                warrantTTLSeconds: warrantTTLSeconds,
                ledgerSigningSecret: ledgerSigningSecret,
                tokenSigningKey: tokenSigningKey,
                ledgerDatabasePath: ledgerDatabasePath,
                now: now))

        // Risk gate with the M103 wire: every issued permit lands in the sovereign audit
        // trail (fail-closed — a permit whose recording throws never escapes). Permit
        // signing (integration permit-signing): the gate gets a STABLE key derived from
        // the same host secret as the warrant/proof tags — domain separation comes from
        // the "qinao.permit.v1" label inside the tag, so a permit tag can never collide
        // with a warrant/proof tag. Cross-process hosts re-derive the same key on both
        // sides and a permit minted on one gate verifies on the other.
        let risk = QinaoRiskGate(
            permitTTLSeconds: permitTTLSeconds,
            permitEventRecorder: QinaoRuntime
                .makeSovereignPermitEventRecorder(sovereign: sovereign),
            now: now,
            // deep-audit P1-6: HKDF-derive the permit key with its own domain label ("qinao.permit.v1")
            // so it is cryptographically separated from the ledger key AND the warrant/proof key —
            // the single-secret fallback no longer shares the raw ledger secret across domains.
            permitTagKey: QinaoSovereignControlPlane.deriveDomainKey(
                tokenSigningKey ?? ledgerSigningSecret, domain: "qinao.permit.v1"))

        let constitution = BASHostConstitution(
            hostID: hostID, activeVersion: activeVersion)
        let versionTree = BASHostVersionTree(
            activeVersionID: activeVersion,
            versions: [
                BASHostVersion(
                    versionID: activeVersion,
                    createdAt: now(),
                    changedFields: [],
                    reason: "sovereign-host-assembly-seed",
                    approvedByPolicy: true)
            ])
        let host = QinaoHost(pipeline: BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: versionTree,
            clock: now))

        let memory = QinaoMemory(now: now)

        // Endpoint-LESS loop over the seeded vault + full 9-seat council. The LLM seam
        // (organEndpoint) deliberately stays empty — see the boundary note in the header.
        let vault = try await QinaoWorldPriorVault(seedingBuiltIns: true)
        let loop = QinaoLoop(worldPrior: vault)
        let seats = await QinaoSeatRegistry.allDefaultLoopSeats(loop: loop)

        let runtime = QinaoRuntime(
            host: host, memory: memory, risk: risk,
            sovereign: sovereign, loop: loop,
            toolExecutor: toolExecutor, now: now,
            lifecycle: lifecycle,
            metricsRecorder: metricsRecorder)

        return QinaoSovereignHost(
            runtime: runtime, loop: loop, seats: seats,
            sovereign: sovereign, substrate: substrate,
            memory: memory, risk: risk, host: host)
    }
}
