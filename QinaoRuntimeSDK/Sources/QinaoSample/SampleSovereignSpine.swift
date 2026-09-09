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
import CryptoKit
import QinaoDefaults
import QinaoRuntime
import QinaoSovereign
import QinaoMemory

private enum SampleLedgerSecretError: LocalizedError {
    case invalidByteCount(path: String, actual: Int)
    case missingKeyBesideLedgerHistory(path: String, artifact: String)

    var errorDescription: String? {
        switch self {
        case .invalidByteCount(let path, let actual):
            return "invalid ledger secret at \(path): expected 32 bytes, found \(actual)"
        case .missingKeyBesideLedgerHistory(let path, let artifact):
            return "refusing to create ledger secret at \(path): existing \(artifact) may require the original key"
        }
    }
}

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

            // deep-audit P1-12 (2026-07-13): BIND the audited turn to THIS exact exchange.
            // Previously snapshotRef/policyHash were fixed placeholders ("snap.sample"/
            // "policy.sample"), so the signed, persisted BASSovereignAuditEntry committed to
            // nothing about the prompt/response — two different exchanges produced
            // byte-identical audit content (modulo turnID). We derive snapshotRef from the
            // SHA-256 digests of prompt AND response, so the entry the verdict engine signs
            // and the keyed ledger persists is cryptographically content-bound to the
            // exchange; policyHash carries the host's REAL active constitution version.
            let promptDigest = Self.sha256Hex(prompt)
            let responseDigest = Self.sha256Hex(responseBody)
            let boundSnapshotRef =
                "snap.sample.\(promptDigest.prefix(8)).\(responseDigest.prefix(8))"

            var inputs = QinaoRuntime.TurnInputs(
                observations: QinaoSovereignControlPlane.TurnObservations(
                    sessionID: sessionID,
                    turnID: "turn-\(UUID().uuidString.prefix(8))",
                    snapshotRef: boundSnapshotRef,
                    policyHash: "policy.\(constitution.activeVersion)"),
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

    // MARK: - Content binding (deep-audit P1-12)

    /// Lowercase hex SHA-256 of a UTF-8 string — used to content-bind the audited turn's
    /// snapshotRef to the exact prompt/response exchange.
    static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
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
        let fileManager = FileManager.default
        let keyName = "ledger-secret.key"
        let url = dir.appendingPathComponent(keyName)

        do {
            let existing = try Data(contentsOf: url)
            guard existing.count == 32 else {
                throw SampleLedgerSecretError.invalidByteCount(
                    path: url.path,
                    actual: existing.count)
            }
            return existing
        } catch let error as SampleLedgerSecretError {
            throw error
        } catch {
            let readError = error
            let cocoaError = readError as NSError
            guard cocoaError.domain == NSCocoaErrorDomain,
                  cocoaError.code == CocoaError.Code.fileReadNoSuchFile.rawValue
            else {
                throw readError
            }

            func pathEntryExists(at candidate: URL) throws -> Bool {
                do {
                    _ = try fileManager.attributesOfItem(atPath: candidate.path)
                    return true
                } catch {
                    let attributeError = error as NSError
                    guard attributeError.domain == NSCocoaErrorDomain,
                          attributeError.code == CocoaError.Code.fileReadNoSuchFile.rawValue
                    else {
                        throw error
                    }
                }

                // attributesOfItem may follow a dangling link on some Foundation
                // implementations. Ask for the link destination before calling the
                // canonical path genuinely absent.
                do {
                    _ = try fileManager.destinationOfSymbolicLink(atPath: candidate.path)
                    return true
                } catch {
                    let linkError = error as NSError
                    guard linkError.domain == NSCocoaErrorDomain,
                          linkError.code == CocoaError.Code.fileReadNoSuchFile.rawValue
                    else {
                        throw error
                    }
                    return false
                }
            }

            let keyEntryExists: Bool
            do {
                keyEntryExists = try pathEntryExists(at: url)
            } catch {
                // The original key read remains the primary failure.
                throw readError
            }
            guard !keyEntryExists else {
                throw readError
            }

            let ledgerArtifactNames = [
                "sovereign-ledger.sqlite",
                "sovereign-ledger.sqlite-wal",
                "sovereign-ledger.sqlite-shm",
                "sovereign-ledger.sqlite-journal",
            ]
            for artifact in ledgerArtifactNames {
                let artifactExists: Bool
                do {
                    artifactExists = try pathEntryExists(
                        at: dir.appendingPathComponent(artifact))
                } catch {
                    throw readError
                }
                if artifactExists {
                    throw SampleLedgerSecretError.missingKeyBesideLedgerHistory(
                        path: url.path,
                        artifact: artifact)
                }
            }
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
        let secret = Data(bytes)
        try secret.write(to: url, options: [.withoutOverwriting])
        return secret
    }
}
