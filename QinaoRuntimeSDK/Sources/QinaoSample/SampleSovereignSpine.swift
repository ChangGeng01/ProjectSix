// integration sample-upgrade (2026-07-12) — the sample now TEACHES the integrated pattern.
//
// Pre-upgrade, QinaoSample was the turn-path map's path B: it drove QinaoLoop directly and
// its output never touched audit, coverage, ledger, or memory. As the SDK's reference
// consumer, it taught new hosts the loop-direct posture. This file upgrades it to the
// charter posture (Docs/QINAO_INTEGRATION_CHARTER_2026-07-12.md):
//
//   LLM endpoint  ── stays on the SAMPLE's side of the boundary (QinaoAppleFoundation/MLX)
//   its output    ── crosses the boundary as DATA into the assembled LLM-free sovereign
//                    host: memory admission + a sendSession turn (audit, coverage,
//                    PERSISTENT keyed ledger) per exchange.
//
// The spine is `QinaoDefaults.makeSovereignHost` — the boundary-pinned assembly. Nothing
// here hands the endpoint to the spine; the sample is the demonstration that a host links
// BOTH sides while the assembly itself stays LLM-free.

import Foundation
import QinaoDefaults
import QinaoRuntime
import QinaoSovereign
import QinaoMemory

extension SampleSession {

    /// Lazily assemble the LLM-free sovereign spine. The keyed ledger persists under
    /// `ledgerDirectory` (default: Application Support/QinaoSample) with a locally
    /// generated random HMAC secret stored beside it — no hardcoded secret, and the
    /// ledger chain stays verifiable across app restarts.
    public func sovereignHost() async throws -> QinaoSovereignHost {
        if let cached = cachedSovereignHost { return cached }

        let dir = try resolvedLedgerDirectory()
        let secret = try Self.loadOrCreateLedgerSecret(in: dir)
        let host = try await QinaoDefaults.makeSovereignHost(
            hostID: "qinao.sample",
            activeVersion: "sample.v1",
            ledgerSigningSecret: secret,
            ledgerDatabasePath: dir
                .appendingPathComponent("sovereign-ledger.sqlite").path,
            // The sample wires no real tools; the executor is a stub so the
            // three-signature gate surface exists but nothing fires it from the UI.
            toolExecutor: { _, _ in Data() })
        cachedSovereignHost = host
        return host
    }

    /// Feed one finished LLM exchange into the sovereign spine AS DATA: admit it into
    /// governed memory, then run a full audited turn (sendSession → audit + coverage +
    /// keyed-ledger append; the runtime's own memory feeds L8 per S1).
    ///
    /// Returns a compact human-readable audit line for the UI. Fail-soft by design —
    /// a demo surface reports an audit failure honestly instead of crashing — but the
    /// failure text is explicit, never a silent success.
    public func recordTurn(
        sessionID: String,
        prompt: String,
        responseBody: String,
        providerID: String
    ) async -> String {
        do {
            let host = try await sovereignHost()

            // L2 output crossing the boundary as data (memory admission).
            // charter audit 2026-07-12 honesty fixes: (a) sourceType truthfully labels the
            // content as LLM-authored — it previously defaulted to "host", so model text
            // entered governed memory wearing the host's provenance; (b) admission goes
            // through the CONSTITUTION-AWARE gate (consent-lattice memoryWriteScope), the
            // first production use of that overload; (c) the outcome is SURFACED in the
            // returned audit line — a governance refusal was previously `_ = try?`-swallowed
            // while this file's own header promised "never a silent success".
            let constitution = await host.host.currentConstitution()
            let memoryLine: String
            do {
                let admitted = try await host.memory.admit(
                    QinaoMemory.AdmitRequest(
                        kind: .episodic,
                        content: "Q: \(prompt) → A(\(providerID)): \(responseBody.prefix(200))",
                        scope: .session,
                        sensitivity: .low,
                        confidence: 0.7,
                        sourceType: "qinao-sample.llm:\(providerID)"),
                    under: constitution)
                // deep-audit HIGH-1 (2026-07-13): the admission is now truthfully labeled by
                // its governance OUTCOME. Under the seed constitution (memoryPromotionScope
                // "review_required"), LLM-authored content lands as `.candidate` — HELD for
                // review, NOT frontstage-eligible, NOT feeding the next turn's L8. That is the
                // correct governance: raw model output is not auto-promoted into governed
                // memory. A host whose constitution permits promotion sees `.governed`.
                memoryLine = admitted.governanceStatus == .governed
                    ? "memory admitted (governed)"
                    : "memory held (\(admitted.governanceStatus))"
            } catch {
                memoryLine = "memory REFUSED (\(error))"
            }

            var inputs = QinaoRuntime.TurnInputs(
                observations: QinaoSovereignControlPlane.TurnObservations(
                    sessionID: sessionID,
                    turnID: "turn-\(UUID().uuidString.prefix(8))",
                    snapshotRef: "snap.sample",
                    policyHash: "policy.sample"),
                coordinatorSeverity: nil)
            inputs.expectedCoverageLayerIDs = ["L8", "L14"]

            let outcome = try await host.runtime.sendSession(inputs)
            return "sovereign: audit \(outcome.audit.severity) · "
                + "coverage \(outcome.coverage.severity) · "
                + (outcome.sessionHalted ? "HALTED" : "ledger appended") + " · "
                + memoryLine
        } catch {
            return "sovereign: turn REFUSED — \(error)"
        }
    }

    // MARK: - Ledger location + local secret

    private func resolvedLedgerDirectory() throws -> URL {
        let dir: URL
        if let injected = ledgerDirectory {
            dir = injected
        } else {
            guard let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first
            else {
                throw SampleError.providerNotWired("application-support-unavailable")
            }
            dir = support.appendingPathComponent("QinaoSample", isDirectory: true)
        }
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 32 random bytes generated on first run, stored beside the ledger. Reusing the
    /// stored secret keeps the HMAC chain verifiable across restarts; regenerating it
    /// would quarantine the prior chain (integrity > availability, honestly surfaced).
    static func loadOrCreateLedgerSecret(in dir: URL) throws -> Data {
        let url = dir.appendingPathComponent("ledger-secret.key")
        if let existing = try? Data(contentsOf: url), existing.count == 32 {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
        let secret = Data(bytes)
        try secret.write(to: url, options: [.atomic])
        return secret
    }
}
