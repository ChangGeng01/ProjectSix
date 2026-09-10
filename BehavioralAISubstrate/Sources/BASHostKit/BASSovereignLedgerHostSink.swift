// MARK: - BASSovereignLedgerHostSink — 主权闭环宿主接入 (2026-06-12)
//
// Closes the headline gap the default-loop promotion inventory found:
// per-turn `sovereignAuditEntry` values are produced UNCONDITIONALLY
// by the cascade and ride out on `BASEBrainTurnResult`, but no host
// ever appends them to a KEYED ledger — so the entry "dies unsigned
// in the result struct," and the per-turn sovereign-audit chain has
// no production producer。
//
// This actor is the reusable seam: a host hands it the per-turn
// result; the sink reads `result.sovereignAuditEntry`, hands it to a
// keyed `BASSovereignAuditLedger` (which SIGNS it with the host's
// Ed25519 key and CHAINS it via priorHash/selfHash), and persists it。
//
// ## Byte-safety (ADR-014 / 红线 7 — by construction)
//
// `recordTurn(_:)` is a pure SIDE EFFECT after the turn result is
// already composed:it READS the entry off the result and persists a
// signed copy。 It NEVER mutates the turn result, the replay-digest
// preimage, or any value path — exactly like the field-metrics
// collector。 A host that never constructs the sink is byte-identical
// (the entry is produced either way;only persistence differs)。
//
// ## Signing authority
//
// The HOST's ledger key is the signing authority。 The cascade emits
// the entry UNSIGNED;`recordTurn` defensively CLEARS any signature
// before append so the ledger always signs with the host key (an
// entry that arrived pre-signed by some other authority would
// otherwise be rejected by the keyed verify path)。
//
// ## Key custody (R1 / ADR-032)
//
// `makeReferenceHost(...)` persists a generated Ed25519 key to a
// FILE — acceptable for a TEST/REFERENCE host (DeviceTestApp, unit
// tests)。 PRODUCTION key custody (keychain / Secure Enclave / HSM +
// the ADR-032 dual-key/approver decision) stays an operator R1
// choice;a production host injects its own keypair + storage via the
// designated initializer。

import Foundation
import CryptoKit
import BASSovereign
import BASRuntimeCore

public actor BASSovereignLedgerHostSink {

    /// Outcome of recording one turn — honest about non-append
    /// (no entry on the result, or the ledger rejected the draft)。
    public struct AppendOutcome: Sendable, Equatable {
        /// True ⇒ the entry was signed + chained into the ledger。
        public let appended: Bool
        /// The chained self-hash (chain head after this append),or
        /// nil when nothing was appended。
        public let selfHash: String?
        /// The entry's schema version (e.g. "1.2.0" injective),or nil。
        public let schemaVersion: String?
        /// Why nothing was appended (nil when `appended`)。
        public let reason: String?

        public init(appended: Bool, selfHash: String?,
                    schemaVersion: String?, reason: String?) {
            self.appended = appended
            self.selfHash = selfHash
            self.schemaVersion = schemaVersion
            self.reason = reason
        }
    }

    private let ledger: BASSovereignAuditLedger
    private var appendedCountStore = 0
    private var lastSelfHashStore: String?

    /// Designated init — a production host injects its own keyed
    /// ledger (its own key custody + storage decision)。
    public init(ledger: BASSovereignAuditLedger) {
        self.ledger = ledger
    }

    /// Record one turn:if the result carries a sovereign audit
    /// entry,sign + chain it into the ledger。 Never throws — a
    /// rejected/absent entry is reported via the outcome, never
    /// crashes the host turn loop (errors are surfaced, not
    /// swallowed:the reason is returned)。
    @discardableResult
    public func recordTurn(
        _ result: BASEBrainTurnResult
    ) async -> AppendOutcome {
        guard var entry = result.sovereignAuditEntry else {
            return AppendOutcome(
                appended: false, selfHash: nil,
                schemaVersion: nil,
                reason: "no sovereignAuditEntry on turn result")
        }
        // Host ledger is the signing authority — clear any inbound
        // signature so the ledger signs with the host key。
        entry.signature = ""
        do {
            let appended = try await ledger.append(entry)
            appendedCountStore += 1
            lastSelfHashStore = appended.selfHash
            return AppendOutcome(
                appended: true,
                selfHash: appended.selfHash,
                schemaVersion: entry.schemaVersion,
                reason: nil)
        } catch {
            return AppendOutcome(
                appended: false, selfHash: lastSelfHashStore,
                schemaVersion: entry.schemaVersion,
                reason: "ledger.append rejected: \(error)")
        }
    }

    /// Number of entries this sink has chained。
    public func appendedCount() -> Int { appendedCountStore }

    /// Current chain head (nil before the first append)。
    public func headHash() -> String? { lastSelfHashStore }

    /// Verify the full persisted chain (delegates to the ledger's
    /// audit)。 Returns true when no corruptions are found。
    public func verifyChain() async -> Bool {
        await ledger.auditChainFull().corruptions.isEmpty
    }
}

// MARK: - Reference-host construction (TEST/REFERENCE ONLY)

extension BASSovereignLedgerHostSink {

    /// Build a sink with a FILE-persisted Ed25519 key + SQLite
    /// chain storage — for a TEST/REFERENCE host (DeviceTestApp,
    /// unit tests)。 Generate-once-reload:if `keyURL` exists its raw
    /// 32-byte private key is loaded;otherwise a fresh key is
    /// generated and written。 PRODUCTION hosts must NOT use this
    /// file-key path — see the type doc (ADR-032 key custody is an
    /// operator R1 decision)。
    ///
    /// Throws if the SQLite storage cannot open or the key file is
    /// present but malformed (fail-closed:a host that cannot
    /// honestly load its key must not sign under a different one)。
    public static func makeReferenceHost(
        keyURL: URL,
        storagePath: String,
        signingNamespace: String =
            BASSovereignTrustConstants.signingNamespace
    ) throws -> BASSovereignLedgerHostSink {
        let privateKey: Curve25519.Signing.PrivateKey
        if FileManager.default.fileExists(atPath: keyURL.path) {
            let raw = try Data(contentsOf: keyURL)
            privateKey = try Curve25519.Signing.PrivateKey(
                rawRepresentation: raw)
        } else {
            privateKey = Curve25519.Signing.PrivateKey()
            try privateKey.rawRepresentation.write(
                to: keyURL, options: [.atomic])
        }
        let keyPair = BASSovereignEd25519KeyPair(privateKey: privateKey)
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: storagePath)
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: keyPair,
            signingNamespace: signingNamespace,
            storage: storage)
        return BASSovereignLedgerHostSink(ledger: ledger)
    }
}
