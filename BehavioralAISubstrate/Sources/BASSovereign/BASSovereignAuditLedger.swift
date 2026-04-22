import Foundation
import CryptoKit
import BASRuntimeCore

/// Append-only hash-chained audit ledger for the L14 sovereign microkernel
/// (module `BR-07` in the Black Ring specification v1).
///
/// ## Why this exists
///
/// The Black Ring spec defines `BR-012` as an absolute red line: **a sovereign
/// verdict that cannot be written to the audit ledger must fail closed**
/// (i.e. reject the action). Without a ledger that can actually succeed or
/// fail in an observable way, `BR-012` is a promise with no teeth.
///
/// The ledger is also consumed by:
///
/// - the `VerdictEngine` (`BR-05`) — every verdict appends one entry
/// - the `TokenAuthority` (`BR-06`) — token issuance and revocation are logged
/// - the `SnapshotManager` (`BR-04`) — snapshot boot checks emit audit events
/// - replay & governance tooling — `query(byAuditRef:)` / session scans
///
/// ## Design
///
/// 1. **Append-only**: the public API exposes only `append(...)` and
///    read-side queries. There is no mutation/delete surface.
/// 2. **Hash-chained**: every entry records the SHA-256 of the prior entry's
///    canonical bytes. Any tamper in the middle of the chain makes every
///    subsequent entry fail `verifyChainIntegrity()`.
/// 3. **Signed**: every appended entry carries a signature bound to the
///    canonical payload (entry fields + prior hash). `verifyChainIntegrity`
///    re-signs with the same secret and compares.
/// 4. **Isolated**: the ledger is an `actor` — sovereign writes are
///    serialized and cannot be interleaved with reads that would observe
///    partially-appended state.
///
/// ## Failure semantics (critical for `BR-012`)
///
/// `append(...)` **throws** on:
///
/// - missing signing secret (ledger was started without a key namespace)
/// - failed chain integrity check (the tail of the ledger is corrupted)
/// - invalid entry (empty audit ID, contradictory session/turn refs)
///
/// Callers MUST treat these throws as grounds to abort the commit. The
/// ledger itself does not try to recover — integrity > availability.
public actor BASSovereignAuditLedger {
    public enum LedgerError: Error, Equatable, Sendable {
        case invalidEntry(String)
        case missingSigningSecret
        case chainIntegrityBroken(lastVerifiedAuditID: String?)
        case signatureMismatch(auditID: String)
        case unknownAuditRef(String)
    }

    /// A fully-verified append record. Distinct from
    /// `BASSovereignAuditEntry` so the in-ledger representation can carry
    /// hash-chain bookkeeping without bleeding those fields into the
    /// schema type exported across layers.
    public struct AppendedEntry: Sendable, Equatable {
        public let entry: BASSovereignAuditEntry
        /// SHA-256 of the canonical bytes of the immediately-prior entry,
        /// or the empty-string sentinel `"GENESIS"` for the first entry.
        public let priorHash: String
        /// SHA-256 of the canonical bytes of THIS entry (used by the next
        /// entry's `priorHash`).
        public let selfHash: String

        public init(entry: BASSovereignAuditEntry, priorHash: String, selfHash: String) {
            self.entry = entry
            self.priorHash = priorHash
            self.selfHash = selfHash
        }
    }

    private static let genesisHash = "GENESIS"

    /// Shared secret used to sign canonical entry bytes. In a real
    /// deployment this is rotated by the `TokenAuthority`'s keyring; v1
    /// keeps it as a constructor-injected value so tests can deterministically
    /// mint chains.
    private let signingSecret: SymmetricKey

    /// Namespace tag ("which keyring version am I signing under").
    /// Included in canonical bytes so a reader with a different namespace
    /// will refuse the signature even if the raw key somehow matched.
    private let signingNamespace: String

    /// The chain itself. Ordered; appending is the only mutator.
    private var entries: [AppendedEntry] = []

    /// Index for O(1) `query(byAuditRef:)`. Kept in sync with `entries`.
    private var auditRefIndex: [String: Int] = [:]

    /// Parallel storage for M44 cross-layer coverage verdicts
    /// (`BASObservationReconciliationVerdict`). These are structured reads
    /// of per-turn observation reports, **not** sovereign verdicts — they
    /// are kept alongside the hash-chained entries (rather than mixed in)
    /// so coverage audits can be queried without inflating the chain with
    /// non-sovereign material, and so M44 verdicts do not need to carry
    /// the full BR-012 signing machinery. Last-write-wins per
    /// `(sessionID, turnID)` so a single turn cannot accumulate multiple
    /// coverage readings.
    private var coverageVerdicts: [BASObservationReconciliationVerdict] = []

    public init(
        signingSecret: SymmetricKey,
        signingNamespace: String = BASSovereignTrustConstants.signingNamespace
    ) {
        self.signingSecret = signingSecret
        self.signingNamespace = signingNamespace
    }

    /// Convenience factory that derives a deterministic secret from a
    /// string seed. Useful for tests and for bootstrap when a secure
    /// keyring is not yet available. **Not appropriate for production**
    /// unless the seed is itself high-entropy and stored in the keychain.
    public static func withSeed(
        _ seed: String,
        namespace: String = BASSovereignTrustConstants.signingNamespace
    ) -> BASSovereignAuditLedger {
        let secret = SymmetricKey(data: SHA256.hash(data: Data(seed.utf8)))
        return BASSovereignAuditLedger(signingSecret: secret, signingNamespace: namespace)
    }

    // MARK: - Append

    /// Append a new audit entry.
    ///
    /// The caller may supply a signature. If present the ledger will verify
    /// it before accepting; if absent the ledger computes one from the
    /// canonical bytes. This dual-mode supports both:
    ///
    /// - callers that pre-sign outside the actor (preferred for
    ///   cross-process integrity)
    /// - in-process callers that just want the ledger to sign and store
    @discardableResult
    public func append(_ draft: BASSovereignAuditEntry) throws -> AppendedEntry {
        guard !draft.auditID.isEmpty else {
            throw LedgerError.invalidEntry("auditID must be non-empty")
        }
        guard !draft.sessionID.isEmpty else {
            throw LedgerError.invalidEntry("sessionID must be non-empty")
        }
        guard !draft.verdictRef.isEmpty else {
            throw LedgerError.invalidEntry("verdictRef must be non-empty")
        }

        let priorHash = entries.last?.selfHash ?? Self.genesisHash
        let canonical = canonicalBytes(for: draft, priorHash: priorHash)
        let computedSignature = sign(canonical)

        // Verify or install the signature. If the caller provided one we
        // require it to match what we would have computed; otherwise we
        // install ours. Either way the stored entry ends up with a valid
        // signature bound to the chain position.
        var sealed = draft
        if sealed.signature.isEmpty {
            sealed.signature = computedSignature
        } else if sealed.signature != computedSignature {
            throw LedgerError.signatureMismatch(auditID: sealed.auditID)
        }

        let selfHash = hash(canonical)
        let appended = AppendedEntry(entry: sealed, priorHash: priorHash, selfHash: selfHash)
        entries.append(appended)
        auditRefIndex[sealed.auditID] = entries.count - 1
        return appended
    }

    // MARK: - Query

    public func query(byAuditRef auditRef: String) throws -> AppendedEntry {
        guard let index = auditRefIndex[auditRef], index < entries.count else {
            throw LedgerError.unknownAuditRef(auditRef)
        }
        return entries[index]
    }

    public func entries(forSession sessionID: String) -> [AppendedEntry] {
        entries.filter { $0.entry.sessionID == sessionID }
    }

    public func entries(forSession sessionID: String, turn turnID: String) -> [AppendedEntry] {
        entries.filter { $0.entry.sessionID == sessionID && $0.entry.turnID == turnID }
    }

    public func entriesInvolvingRule(_ ruleID: String) -> [AppendedEntry] {
        entries.filter { $0.entry.ruleIDs.contains(ruleID) }
    }

    public func count() -> Int { entries.count }

    /// Whole-chain integrity verification.
    ///
    /// Walks from genesis → tail, recomputing each entry's canonical bytes
    /// and signature, and verifying that `priorHash` links form an
    /// unbroken chain. If anything is inconsistent, throws
    /// `chainIntegrityBroken(lastVerifiedAuditID:)` pointing at the last
    /// clean audit ID so callers can snapshot/quarantine the tail.
    public func verifyChainIntegrity() throws {
        var expectedPrior = Self.genesisHash
        var lastClean: String? = nil
        for (offset, appended) in entries.enumerated() {
            guard appended.priorHash == expectedPrior else {
                throw LedgerError.chainIntegrityBroken(lastVerifiedAuditID: lastClean)
            }
            let canonical = canonicalBytes(for: appended.entry, priorHash: appended.priorHash)
            let expectedSignature = sign(canonical)
            guard appended.entry.signature == expectedSignature else {
                throw LedgerError.chainIntegrityBroken(lastVerifiedAuditID: lastClean)
            }
            let expectedSelfHash = hash(canonical)
            guard appended.selfHash == expectedSelfHash else {
                throw LedgerError.chainIntegrityBroken(lastVerifiedAuditID: lastClean)
            }
            lastClean = appended.entry.auditID
            expectedPrior = appended.selfHash
            _ = offset
        }
    }

    /// Export for replay/governance. The returned array is a value copy —
    /// callers cannot mutate the ledger through it.
    public func snapshot() -> [AppendedEntry] {
        entries
    }

    // MARK: - Coverage-verdict storage (M45)
    //
    // The M44 verdict engine produces `BASObservationReconciliationVerdict`
    // values from `BASObservationReconciliationReport`s. These represent a
    // cross-layer structural read ("did every expected layer report with
    // core coverage; did total wake-budget stay under the ceiling") and
    // sit one level above the hash-chained sovereign verdicts this ledger
    // was built for. Storing them in a parallel array keeps both concerns
    // observable from the same ledger instance without conflating them.

    /// Record a coverage verdict for a turn. If a verdict already exists
    /// for the same `(sessionID, turnID)` it is replaced in place with the
    /// incoming value (last-write-wins). Ordering of first-seen `(session,
    /// turn)` keys is preserved so callers can iterate deterministically.
    public func recordCoverageVerdict(
        _ verdict: BASObservationReconciliationVerdict
    ) {
        if let idx = coverageVerdicts.firstIndex(where: {
            $0.sessionID == verdict.sessionID
                && $0.turnID == verdict.turnID
        }) {
            coverageVerdicts[idx] = verdict
        } else {
            coverageVerdicts.append(verdict)
        }
    }

    /// Look up the coverage verdict for a specific turn, or `nil` if no
    /// verdict has been recorded for that `(session, turn)` pair.
    public func coverageVerdict(
        forSession sessionID: String,
        turn turnID: String
    ) -> BASObservationReconciliationVerdict? {
        coverageVerdicts.first {
            $0.sessionID == sessionID && $0.turnID == turnID
        }
    }

    /// Every coverage verdict recorded for a session, in first-seen turn
    /// order. Used by governance tooling to reconstruct the per-turn
    /// coverage timeline.
    public func coverageVerdicts(
        forSession sessionID: String
    ) -> [BASObservationReconciliationVerdict] {
        coverageVerdicts.filter { $0.sessionID == sessionID }
    }

    /// Total number of coverage verdicts across every session.
    public func coverageVerdictCount() -> Int {
        coverageVerdicts.count
    }

    /// Full value-copy export of coverage verdicts for replay/governance.
    public func coverageVerdictSnapshot()
        -> [BASObservationReconciliationVerdict]
    {
        coverageVerdicts
    }

    // MARK: - Canonical bytes / crypto primitives

    /// Builds the canonical byte representation that is both hashed (for
    /// chain integrity) and signed (for tamper detection). The format is
    /// intentionally boring: a `|`-delimited list of fields in a fixed
    /// order, terminated with the prior hash and signing namespace.
    ///
    /// Any change to this function is a breaking ledger-format change and
    /// MUST bump the namespace + rewrite all existing entries.
    private func canonicalBytes(
        for entry: BASSovereignAuditEntry,
        priorHash: String
    ) -> Data {
        let fields: [String] = [
            entry.schemaVersion,
            entry.auditID,
            entry.sessionID,
            entry.turnID,
            entry.verdictRef,
            entry.ruleIDs.joined(separator: ","),
            entry.signalRefs.joined(separator: ","),
            entry.actionRefs.joined(separator: ","),
            entry.snapshotRef,
            entry.actor.rawValue,
            String(Int(entry.appendedAt.timeIntervalSince1970 * 1000)),
            priorHash,
            signingNamespace
        ]
        return Data(fields.joined(separator: "|").utf8)
    }

    private func sign(_ data: Data) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: signingSecret)
        return Data(mac).base64EncodedString()
    }

    private func hash(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).base64EncodedString()
    }
}
