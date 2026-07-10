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
    public enum LedgerError:
        Error, Equatable, Sendable, Codable
    {
        case invalidEntry(String)
        case missingSigningSecret
        case chainIntegrityBroken(lastVerifiedAuditID: String?)
        case signatureMismatch(auditID: String)
        case unknownAuditRef(String)
        /// M83 — rotation was requested against a session that has no
        /// live (open) segment. This happens when a caller tries to
        /// double-close an already-closed session.
        case noOpenSegment(sessionID: String)
        /// M83 — LINEAGE_CUT referenced a root audit ID that doesn't
        /// exist in the current ledger scope.
        case lineageRootNotFound(auditID: String)
        /// ch1044 A2 append-floor — an append was rejected because its schemaVersion is
        /// below the ledger's configured `minimumSchemaVersion` (opt-in hardened-only mode).
        case schemaVersionBelowFloor(found: String, floor: String)
    }

    /// A fully-verified append record. Distinct from
    /// `BASSovereignAuditEntry` so the in-ledger representation can carry
    /// hash-chain bookkeeping without bleeding those fields into the
    /// schema type exported across layers.
    public struct AppendedEntry:
        Sendable, Equatable, Codable
    {
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

    /// M87 — internal signing mode.
    ///
    /// Before M87 the ledger hard-coded HMAC-SHA256 with a
    /// `SymmetricKey`. M87 adds Ed25519 as a first-class alternative
    /// for production cross-verifier integrity. See
    /// `BASSovereignEd25519Signing.swift` for why asymmetric signing
    /// matters here. The enum keeps both paths addressable from the
    /// same ledger instance so callers (tests, existing call sites
    /// using `withSeed(_:)`, new prod call sites using
    /// `init(ed25519KeyPair:)`) share one public surface.
    private enum SigningMode: Sendable {
        case hmac(SymmetricKey)
        case ed25519(BASSovereignEd25519KeyPair)
    }

    /// Active signing mode. Selected at construction and immutable
    /// for the ledger's lifetime — switching mode mid-chain would
    /// break `verifyChainIntegrity()` because the prior signatures
    /// were computed with a different scheme.
    private let signingMode: SigningMode

    /// ch1044 A2 — set true if the persisted chain FAILED integrity verification on
    /// cold-start reload (a tampered/downgraded entry whose signature or linkage no
    /// longer checks). A quarantined ledger REFUSES new appends (fail-closed, integrity
    /// > availability per BR-012/BR-013) and surfaces the state via
    /// `isIntegrityQuarantined` so a consumer can halt rather than treat forged history
    /// as authoritative.
    private var integrityQuarantined: Bool = false

    /// ch1044 A2 — verify-on-reload runs LAZILY on the first isolated operation (the
    /// actor's nonisolated init can't call isolated verification). Idempotent.
    private var reloadVerified: Bool = false

    /// ch1044 A2 — true iff the reloaded chain failed verify-on-reload. Triggers the
    /// (idempotent) lazy verification so a read-only consumer can gate on it.
    public var isIntegrityQuarantined: Bool {
        ensureReloadVerified()
        return integrityQuarantined
    }

    /// Convenience accessor for the Ed25519 public key when the
    /// ledger is in `.ed25519` mode; nil in `.hmac` mode. Cross-
    /// process verifiers that already hold the ledger instance can
    /// use this to pre-populate their verifier, though the
    /// **intended production pattern** is: provisioner generates the
    /// key pair once, stores the private half in a keychain, stores
    /// the public half in a well-known manifest, and hands the
    /// public half to every verifier at boot. The ledger's own copy
    /// here is a convenience for in-process paths.
    public var ed25519PublicKey: Curve25519.Signing.PublicKey? {
        switch signingMode {
        case .hmac: return nil
        case .ed25519(let pair): return pair.publicKey
        }
    }

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

    /// M90 — per-turn observation bundles the host chose to stream.
    /// Parallel to `coverageVerdicts[]`; same "off-chain" discipline.
    /// See the long doc-comment above `recordObservationBundle(_:)`
    /// for the contract.
    private var observationBundles:
        [BASObservationReconciliationReport] = []

    /// M123 — per-turn sovereign-frame aggregator.
    ///
    /// `BASSovereignFrame` is the L14 whitepaper §5.1 aggregator —
    /// the one struct that binds a single turn's sovereign surface
    /// together (session/turn IDs, device/host/continuity/fold/risk/
    /// permit refs, pending-action digests, jurisdiction + time-lock
    /// refs, contamination refs, policy hash).
    ///
    /// Pre-M123 the struct was shipped (M119) but had zero consumers
    /// on the hot path. M123 exposes a parallel storage + record
    /// method on the ledger so QinaoRuntime.sendSession can stream
    /// one frame per turn alongside the L1+L3+L5+L14 observation
    /// bundle already streamed via `observationBundles[]` (M122).
    /// Together the two parallel storages give the sovereign audit
    /// surface a complete per-turn residue: the coverage SUMMARIES
    /// (observationBundles) plus the aggregator REFS pointing at
    /// the artifacts that produced them (sovereignFrames).
    ///
    /// Same "off-chain" discipline as `observationBundles` — frames
    /// do NOT participate in the hash chain. Hash-chaining belongs
    /// to `entries[]`; the parallel storages are additive per-turn
    /// indexes a future replay path can walk alongside the chain.
    private var sovereignFrames: [BASSovereignFrame] = []

    /// M91 — optional cross-process storage. Defaults to
    /// `BASSovereignLedgerNullStorage` (in-memory-only, pre-M91
    /// behaviour byte-for-byte). When a `BASSovereignLedgerSQLiteStorage`
    /// is supplied at init, every `append(_:)` and segment state
    /// change is mirrored to disk. A later cold-start init with the
    /// same storage rehydrates the chain + segments before the
    /// ledger accepts new writes. See `BASSovereignLedgerStorage.swift`
    /// for the full M91 scope + partition rationale (what IS persisted
    /// vs what stays in-memory).
    ///
    /// Synchronous `BASSovereignLedgerStorage` dispatches happen only
    /// from inside this actor, so protocol conformance does not need
    /// `Sendable` — serialization is the actor's job.
    private let storage: any BASSovereignLedgerStorage

    /// ch1044 A2 append-floor — OPT-IN minimum schema version for NEW appends. `nil` (the
    /// default) = no floor = current behavior, byte-equal-off: any well-formed entry is
    /// accepted regardless of schemaVersion (old + new coexist, per-entry-version verify).
    /// When set to `BASSovereignAuditEntry.hardenedSchemaVersion` ("1.2.0"), `append`
    /// REJECTS entries whose schemaVersion is below the floor — i.e. the ambiguous
    /// delimiter-join forms ("1.0.0"/"1.1.0") whose canonical bytes are non-injective. A
    /// security-conscious host opts in once all its producers emit the hardened form; the
    /// critical producers (warrant bridge, verdict engine, clean-reboot) already do post-D2.
    /// This is a forward-only floor on appends; it does NOT touch already-persisted entries.
    private let minimumSchemaVersion: String?

    // MARK: - M83 state
    //
    // The ledger started life as one flat append-only chain. M83 adds
    // segment bookkeeping on top: every append remembers which segment
    // it belongs to; rotation closes the current segment (materialising
    // its tail hash) and opens a new one whose `startAnchor` is the
    // outgoing tail. The core chain invariant is unchanged — neighbor
    // `priorHash == prior.selfHash` — it just now spans segments.

    /// All segments ever observed, in creation order. The last element
    /// is the currently-open segment (unless the ledger has been drained
    /// to zero, which never happens under normal use — segments live as
    /// long as their session does).
    private var segments: [BASSovereignLedgerSegment] = []

    /// For each session, the segment index (into `segments`) that is
    /// currently open. A session with a closed segment and no fresh
    /// successor is absent from this map; the next append on that
    /// session lazily opens a new segment anchored to the closed one's
    /// tail.
    private var openSegmentBySession: [String: Int] = [:]

    /// Parallel storage for LINEAGE_CUT outcomes. Unlike audit entries
    /// these do not participate in the hash chain — the cut MARKER
    /// entry is hash-chained (it lives in `entries`), and
    /// `cutOutcomes[markerAuditID]` simply lets consumers (M84 forget
    /// cascade, M86 version arboretum) replay the cut intent without
    /// parsing signalRefs blobs.
    private var cutOutcomes: [String: BASSovereignLineageCutOutcome] = [:]

    /// HMAC-SHA256 constructor — the pre-M87 production path.
    ///
    /// Still supported (and still the default for in-process ledgers
    /// that don't need cross-verifier integrity), but for new
    /// production deployments prefer `init(ed25519KeyPair:
    /// signingNamespace:)` so verifiers can re-check entries without
    /// holding the signing secret. See `BASSovereignEd25519Signing.swift`
    /// for the full rationale.
    ///
    /// M91 — pass `storage:` to persist audit entries + segments to
    /// disk across process restarts. Default is
    /// `BASSovereignLedgerNullStorage` (pre-M91 in-memory only).
    public init(
        signingSecret: SymmetricKey,
        signingNamespace: String = BASSovereignTrustConstants.signingNamespace,
        storage: any BASSovereignLedgerStorage =
            BASSovereignLedgerNullStorage(),
        minimumSchemaVersion: String? = nil
    ) {
        self.signingMode = .hmac(signingSecret)
        self.signingNamespace = signingNamespace
        self.storage = storage
        self.minimumSchemaVersion = minimumSchemaVersion
        Self.rehydrate(
            storage: storage,
            entries: &self.entries,
            auditRefIndex: &self.auditRefIndex,
            segments: &self.segments,
            openSegmentBySession: &self.openSegmentBySession)
    }

    /// M87 — Ed25519 constructor for production cross-verifier
    /// integrity.
    ///
    /// A ledger built with this init produces entries whose
    /// signatures can be checked by any verifier holding only the
    /// matching public key (see `BASSovereignAuditLedger.verify(
    /// _:publicKey:signingNamespace:)`). The private key stays in
    /// the ledger — no verifier needs to see it. This is the
    /// production-grade signing path.
    ///
    /// M91 — pass `storage:` to persist audit entries + segments to
    /// disk across process restarts.
    public init(
        ed25519KeyPair: BASSovereignEd25519KeyPair,
        signingNamespace: String = BASSovereignTrustConstants.signingNamespace,
        storage: any BASSovereignLedgerStorage =
            BASSovereignLedgerNullStorage(),
        minimumSchemaVersion: String? = nil
    ) {
        self.signingMode = .ed25519(ed25519KeyPair)
        self.signingNamespace = signingNamespace
        self.storage = storage
        self.minimumSchemaVersion = minimumSchemaVersion
        Self.rehydrate(
            storage: storage,
            entries: &self.entries,
            auditRefIndex: &self.auditRefIndex,
            segments: &self.segments,
            openSegmentBySession: &self.openSegmentBySession)
    }

    /// M91 — Replay storage into actor state on init.
    ///
    /// Called from every public init that wires `storage:`. On cold
    /// start the storage returns `([], [])` so this is a no-op. On
    /// reopen it rebuilds the chain order, the audit ref index, the
    /// segments array, and the open-segment-by-session map. Segments
    /// missing `tailHash` are considered OPEN and their session keys
    /// point here; segments with non-nil `tailHash` are closed and
    /// excluded from the open map.
    ///
    /// If storage throws during `loadState()` the init **traps** —
    /// integrity-over-availability doctrine: a ledger that cannot
    /// honestly load its prior chain must not accept new writes.
    /// Hosts that want a graceful fallback should probe the storage
    /// independently before constructing the ledger.
    private static func rehydrate(
        storage: any BASSovereignLedgerStorage,
        entries: inout [AppendedEntry],
        auditRefIndex: inout [String: Int],
        segments: inout [BASSovereignLedgerSegment],
        openSegmentBySession: inout [String: Int]
    ) {
        let loaded: (entries: [AppendedEntry],
                     segments: [BASSovereignLedgerSegment])
        do {
            loaded = try storage.loadState()
        } catch {
            fatalError(
                "BASSovereignAuditLedger rehydrate: storage.loadState() failed — \(error)")
        }
        entries = loaded.entries
        for (idx, appended) in entries.enumerated() {
            auditRefIndex[appended.entry.auditID] = idx
        }
        segments = loaded.segments
        // A segment with non-nil `tailHash` is closed; open segments
        // have `tailHash == nil`. Map the latter back into the
        // sessionID → index lookup so new appends land in the
        // existing open segment rather than opening a duplicate.
        for (idx, seg) in segments.enumerated() where seg.tailHash == nil {
            openSegmentBySession[seg.sessionID] = idx
        }
    }

    /// ch1044 A2 — verify-on-reload (fail closed). A storage-wired ledger re-verifies the
    /// persisted chain on cold start. A tampered/downgraded entry — e.g. `schemaVersion`
    /// forced to a forgeable form with a recomputed UNKEYED selfHash + next priorHash —
    /// still fails the KEYED signature (and the linkage) check, because the attacker
    /// lacks the signing key. On any corruption the ledger QUARANTINES (refuses new
    /// appends) rather than serve forged history as authoritative — the integrity >
    /// availability doctrine the docstrings already promise but no code enforced.
    private func ensureReloadVerified() {
        guard !reloadVerified else { return }
        reloadVerified = true
        guard !entries.isEmpty else { return }
        // H14 (mega-audit 2026-07-07): tail truncation leaves an internally-consistent
        // prefix that auditChainFull() cannot detect (all priorHash links + signatures
        // still verify). Cross-check the loaded entry count against the persisted
        // per-segment entryCounts — a high-water mark storage already keeps but no code
        // consulted. entries < Σ entryCount ⇒ audit_entries rows were deleted; any
        // mismatch ⇒ tamper ⇒ quarantine. Scoped to segment-persisting storages
        // (segments non-empty); a segment-less storage stays byte-equal.
        if !segments.isEmpty {
            let segmentTotal = segments.reduce(0) { $0 + $1.entryCount }
            if segmentTotal != entries.count {
                integrityQuarantined = true
                FileHandle.standardError.write(Data(
                    ("[BASSovereignAuditLedger] QUARANTINED on reload — entry/segment "
                     + "count mismatch (entries=\(entries.count) segmentSum=\(segmentTotal))"
                     + "; tail truncation or tamper suspected; refusing new appends.\n").utf8))
                return
            }
        }
        let report = auditChainFull()
        guard !report.corruptions.isEmpty else { return }
        integrityQuarantined = true
        FileHandle.standardError.write(Data(
            ("[BASSovereignAuditLedger] QUARANTINED on reload — chain integrity FAILED "
             + "(\(report.corruptions.count) corruption(s)); refusing new appends.\n").utf8))
    }

    /// Convenience factory that derives a deterministic HMAC secret
    /// from a string seed. Useful for tests and for bootstrap when
    /// a secure keyring is not yet available. **Not appropriate for
    /// production** unless the seed is itself high-entropy and
    /// stored in the keychain. For production prefer the Ed25519
    /// path — see `withEd25519Seed(_:)` for a deterministic test
    /// fixture in that mode or call
    /// `init(ed25519KeyPair: BASSovereignEd25519KeyPair.generate())`
    /// for a fresh production key.
    public static func withSeed(
        _ seed: String,
        namespace: String = BASSovereignTrustConstants.signingNamespace
    ) -> BASSovereignAuditLedger {
        let secret = SymmetricKey(data: SHA256.hash(data: Data(seed.utf8)))
        return BASSovereignAuditLedger(signingSecret: secret, signingNamespace: namespace)
    }

    /// M87 — convenience factory that derives a deterministic
    /// Ed25519 key pair from a string seed (via
    /// `BASSovereignEd25519KeyPair.fromSeed(_:)`). Test-only — same
    /// warning as `withSeed(_:)`: low-entropy seeds are attackable.
    /// For production use `generate()` + keychain storage.
    public static func withEd25519Seed(
        _ seed: String,
        namespace: String = BASSovereignTrustConstants.signingNamespace
    ) throws -> BASSovereignAuditLedger {
        let pair = try BASSovereignEd25519KeyPair.fromSeed(seed)
        return BASSovereignAuditLedger(
            ed25519KeyPair: pair,
            signingNamespace: namespace)
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
    // ch1044 D2 — the step-1 "reject forbidden canonical separators at append"
    // validation was REVERTED: it is INFEASIBLE for this codebase. The hardened
    // canonical joins arrays with U+001F and fields with U+001E, but BOTH control
    // chars are LEGITIMATELY used as composite delimiters in real audit content —
    // `verdictRef = "shadow_trial\u{1F}<id>"` (scalar, shadow trial), warrant
    // witnessRefs → `signalRefs` carry U+001F (array elements), and
    // `BASAgentObservationAuditEmitter` joins records with U+001E. So no
    // byte-equal validation can reject them without breaking legitimate paths
    // (it broke the warrant-bridge + shadow-trial suites). The genuine fix is the
    // INJECTIVE re-encode (step-2): length-prefix the canonical under a new
    // schemaVersion gate so an in-band separator can't shift a boundary — a
    // version-gated chain migration, deferred (see CH_1044_FULL_AUDIT.md D2).
    /// Parse a "MAJOR.MINOR.PATCH" schema version into a comparable tuple (Swift tuples of
    /// Comparable elements are themselves Comparable). Missing/unparseable components rank
    /// as 0, so a malformed version sorts below any well-formed one — fail-closed for a
    /// floor comparison. ch1044 A2 append-floor.
    static func schemaRank(_ version: String) -> (Int, Int, Int) {
        let parts = version.split(separator: ".").map { Int($0) ?? 0 }
        return (
            parts.count > 0 ? parts[0] : 0,
            parts.count > 1 ? parts[1] : 0,
            parts.count > 2 ? parts[2] : 0)
    }

    @discardableResult
    public func append(_ draft: BASSovereignAuditEntry) throws -> AppendedEntry {
        // ch1044 A2 — verify the reloaded chain on first write; fail closed if corrupt.
        ensureReloadVerified()
        guard !integrityQuarantined else {
            throw LedgerError.invalidEntry(
                "ledger quarantined: reloaded chain failed integrity verification — "
                + "refusing new appends")
        }
        // ch1044 A2 append-floor (opt-in): reject sub-hardened (non-injective) entries when
        // the ledger is configured hardened-only. Default (nil floor) accepts any version.
        if let floor = minimumSchemaVersion,
           Self.schemaRank(draft.schemaVersion) < Self.schemaRank(floor) {
            throw LedgerError.schemaVersionBelowFloor(
                found: draft.schemaVersion, floor: floor)
        }
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

        // M87 — sign/verify dispatch on mode. HMAC is deterministic
        // so byte-equality works for caller-supplied signatures.
        // Ed25519 is non-deterministic in CryptoKit (fault-attack
        // entropy), so caller-supplied signatures must be verified
        // cryptographically with the public key, NOT by recomputing
        // a fresh signature and comparing bytes (which would
        // spuriously reject every valid caller-supplied signature
        // under Ed25519).
        var sealed = draft
        if sealed.signature.isEmpty {
            sealed.signature = sign(canonical)
        } else {
            switch signingMode {
            case .hmac(let key):
                // ch1044 audit fix: CONSTANT-TIME MAC verification. Was a recompute +
                // `String ==`, which short-circuits on the first differing byte — a
                // timing side-channel that could recover a valid MAC byte-by-byte.
                // isValidAuthenticationCode is constant-time; same accept/reject set.
                guard let providedMac = Data(base64Encoded: sealed.signature),
                      HMAC<SHA256>.isValidAuthenticationCode(
                        providedMac, authenticating: canonical, using: key)
                else {
                    throw LedgerError.signatureMismatch(auditID: sealed.auditID)
                }
            case .ed25519(let keyPair):
                guard let sigData = Data(
                    base64Encoded: sealed.signature)
                else {
                    throw LedgerError.signatureMismatch(auditID: sealed.auditID)
                }
                guard keyPair.publicKey.isValidSignature(
                    sigData, for: canonical)
                else {
                    throw LedgerError.signatureMismatch(auditID: sealed.auditID)
                }
            }
        }

        // chapter 七百十六 第三刀 / M2253 — opt-in routed seal。
        // The byte-equality test (chapter 七百十六 第一刀
        // BASChapter716AuditLedgerByteEqualityTests) proved both
        // paths produce mathematically identical output across
        // 50+ varied entry shapes,so flipping the flag at host
        // startup cannot break the chain of custody。 Default
        // stays OFF until chapter 七百十六 第五刀 close-out。
        //
        // LEGACY PATH (unchanged,kept for byte-pinned compat):
        //     let selfHash = hash(canonical)
        // audit sovereign LOW-8: seal AND verify must route through the SAME SHA impl. `sealHash`
        // is the single source of that routing (used here + in verifyChainIntegrity), so append and
        // verify can never diverge if the routed / plain implementations ever differ.
        let selfHash = sealHash(canonical)
        let appended = AppendedEntry(entry: sealed, priorHash: priorHash, selfHash: selfHash)

        // H13 (mega-audit 2026-07-07): capture rollback state BEFORE any mutation so a
        // persist failure leaves the in-memory chain byte-identical to disk. The prior
        // note ("actor state already mutated, acceptable") was WRONG: a phantom tail
        // survives in memory, the NEXT append's priorHash points at it, disk gets a
        // chain whose priorHash references a never-persisted entry, and cold-start
        // reload quarantines the whole persistent ledger on one transient disk hiccup.
        let priorRefIndex = auditRefIndex[sealed.auditID]
        let segmentsCountBefore = segments.count
        let priorOpenSegment = openSegmentBySession[sealed.sessionID]

        entries.append(appended)
        auditRefIndex[sealed.auditID] = entries.count - 1

        // M83 — record segment membership. The current session either
        // has an open segment we can grow, or we lazily open one whose
        // `startAnchor` is whatever our `priorHash` was (the prior
        // segment's tail, or GENESIS for the very first entry).
        let segIndex = ensureOpenSegment(
            for: sealed.sessionID,
            startAnchor: priorHash,
            openedAt: sealed.appendedAt)
        segments[segIndex].entryCount += 1

        // M91 — mirror to persistent storage; H13 — atomic across memory+disk.
        do {
            try storage.persistAppended(appended)
            try storage.persistSegment(segments[segIndex])
        } catch {
            // H13 rollback — undo every mutation in reverse so memory == disk.
            segments[segIndex].entryCount -= 1
            if segments.count > segmentsCountBefore {
                // ensureOpenSegment opened a fresh segment (only when none existed) —
                // drop it and restore the (nil) open-segment mapping.
                segments.removeLast(segments.count - segmentsCountBefore)
                openSegmentBySession[sealed.sessionID] = priorOpenSegment
            }
            if let priorRefIndex {
                auditRefIndex[sealed.auditID] = priorRefIndex
            } else {
                auditRefIndex.removeValue(forKey: sealed.auditID)
            }
            entries.removeLast()
            throw error
        }

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
            // M87 — signature verification must dispatch on signing
            // mode. HMAC is deterministic (recompute-and-compare
            // works); Ed25519 is NOT deterministic in CryptoKit
            // (Apple adds fault-attack entropy to the nonce on top
            // of RFC 8032's baseline), so each re-sign of the same
            // message yields a DIFFERENT signature. For Ed25519 we
            // therefore verify with `publicKey.isValidSignature(_:
            // for:)` against the stored signature, which is the
            // canonical verification primitive for the scheme.
            switch signingMode {
            case .hmac(let key):
                // audit-2026-06-12: CONSTANT-TIME read-side MAC verification. Was
                // recompute + `String ==`, which short-circuits on the first differing
                // byte — the SAME timing side-channel append() already closed (~line 493).
                // isValidAuthenticationCode is constant-time; identical accept/reject set
                // (malformed base64 ⇒ reject, as the Ed25519 branch already does below).
                guard let providedMac = Data(base64Encoded: appended.entry.signature),
                      HMAC<SHA256>.isValidAuthenticationCode(
                        providedMac, authenticating: canonical, using: key)
                else {
                    throw LedgerError.chainIntegrityBroken(lastVerifiedAuditID: lastClean)
                }
            case .ed25519(let keyPair):
                guard let sigData = Data(
                    base64Encoded: appended.entry.signature)
                else {
                    throw LedgerError.chainIntegrityBroken(lastVerifiedAuditID: lastClean)
                }
                guard keyPair.publicKey.isValidSignature(
                    sigData, for: canonical)
                else {
                    throw LedgerError.chainIntegrityBroken(lastVerifiedAuditID: lastClean)
                }
            }
            // audit sovereign LOW-8: recompute via the SAME routing the seal used (sealHash), not a
            // hardcoded plain `hash` — otherwise a routed-seal chain fails verify if routed ≠ plain.
            let expectedSelfHash = sealHash(canonical)
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

    // MARK: - M92 · BR-013 integrity sentinel primitive

    /// M92 — one category of corruption `auditChainFull()` can
    /// surface. All three map to "this entry fails its share of the
    /// chain invariant"; the distinction lets sentinels / audit
    /// consumers render a precise diagnostic per entry rather than
    /// a generic "broken".
    public enum BASSignatureAuditReason:
        String, Sendable, Equatable, Codable, CaseIterable {
        /// The entry's stored signature fails to verify under the
        /// ledger's active signing mode. For HMAC this means the
        /// recomputed MAC differs; for Ed25519 this means
        /// `publicKey.isValidSignature(_:for:)` returned false or
        /// the base64 signature was malformed.
        case signatureInvalid = "signature-invalid"
        /// The entry's stored `selfHash` differs from the SHA-256
        /// recomputed over its canonical bytes. This is a tamper in
        /// the entry fields themselves.
        case selfHashMismatch = "self-hash-mismatch"
        /// The entry's stored `priorHash` does not equal the
        /// immediately-preceding entry's `selfHash` (or the genesis
        /// sentinel for the first entry). This is a tamper in the
        /// chain linkage — either the prior entry was rewritten or
        /// this entry's priorHash was rewritten.
        case priorHashBroken = "prior-hash-broken"
    }

    /// M92 — one structured corruption finding for a single entry.
    ///
    /// `position` is the zero-based index in the ledger's chain
    /// order. `auditID` is the offending entry's stable ID for
    /// downstream audit logging. `reasons` may carry multiple codes
    /// when a single entry exhibits more than one broken invariant
    /// (e.g. both prior-hash-broken AND signature-invalid) — this
    /// preserves every signal rather than hiding them behind the
    /// first failure.
    public struct BASSignatureAuditCorruption:
        Sendable, Equatable, Codable, Hashable {
        public let position: Int
        public let auditID: String
        public let reasons: [BASSignatureAuditReason]

        public init(
            position: Int,
            auditID: String,
            reasons: [BASSignatureAuditReason]
        ) {
            self.position = position
            self.auditID = auditID
            self.reasons = reasons
        }
    }

    /// M92 — full-chain audit result. `isClean == true` iff
    /// `corruptions.isEmpty`. `totalEntriesScanned` is always equal
    /// to the chain length at the time of the scan.
    public struct BASSignatureAuditReport:
        Sendable, Equatable, Codable {
        public let isClean: Bool
        public let totalEntriesScanned: Int
        public let corruptions: [BASSignatureAuditCorruption]

        public init(
            isClean: Bool,
            totalEntriesScanned: Int,
            corruptions: [BASSignatureAuditCorruption]
        ) {
            self.isClean = isClean
            self.totalEntriesScanned = totalEntriesScanned
            self.corruptions = corruptions
        }
    }

    /// M92 — walk the full chain and collect every integrity
    /// corruption into a structured report.
    ///
    /// ## Why this exists (alongside `verifyChainIntegrity()`)
    ///
    /// `verifyChainIntegrity()` throws at the first corruption.
    /// That's the right semantic for guard checks on the hot path
    /// (fail-closed, integrity > availability). But for the
    /// **BR-013 integrity sentinel** — a runtime observer whose job
    /// is to describe the extent of tamper rather than just detect
    /// its presence — the host needs every broken entry, not just
    /// the first. `auditChainFull()` scans every entry, reports
    /// every finding, and returns without throwing.
    ///
    /// ## Semantics
    ///
    /// For each entry in chain order:
    /// - Reconstruct canonical bytes via the ledger's canonical
    ///   byte layout (`basSovereignAuditCanonicalBytes`).
    /// - Compute `selfHash = SHA-256(canonical)`; if `≠ entry.selfHash`,
    ///   append `.selfHashMismatch` to this entry's reasons.
    /// - Verify signature against `canonical`:
    ///   - HMAC mode: recompute MAC; if `≠ entry.signature`, append
    ///     `.signatureInvalid`.
    ///   - Ed25519 mode: `publicKey.isValidSignature(sigData, for:
    ///     canonical)`; if false OR base64 malformed, append
    ///     `.signatureInvalid`.
    /// - Compare `entry.priorHash` to the expected link (genesis
    ///   sentinel for position 0, else `entries[i-1].selfHash`). If
    ///   mismatch, append `.priorHashBroken`.
    /// - If any reasons collected for this entry, append a
    ///   `BASSignatureAuditCorruption` to the report.
    ///
    /// ## Non-throwing + non-halting
    ///
    /// This method **never throws** and **never halts the ledger**.
    /// The returned report is the full picture; hosts decide next
    /// action (halt session, emit sovereign verdict, notify host,
    /// request rotation, etc.). This is the BR-013 primitive; the
    /// runtime sentinel that consumes it is a future milestone.
    ///
    /// ## Cost
    ///
    /// O(N) in chain length with 1 canonical-byte computation, 1
    /// hash, and 1 signature verify per entry. On Ed25519 chains the
    /// per-entry cost is dominated by the signature verify (constant
    /// but non-trivial); hosts should call this on demand or on a
    /// low-frequency schedule rather than every turn.
    public func auditChainFull() -> BASSignatureAuditReport {
        var corruptions: [BASSignatureAuditCorruption] = []
        var expectedPrior = Self.genesisHash

        for (position, appended) in entries.enumerated() {
            var reasons: [BASSignatureAuditReason] = []

            // 1. Prior-hash linkage.
            if appended.priorHash != expectedPrior {
                reasons.append(.priorHashBroken)
            }

            // 2. Canonical-bytes-dependent checks.
            let canonical = canonicalBytes(
                for: appended.entry,
                priorHash: appended.priorHash)

            // 2a. Self-hash. audit sovereign LOW-8 (id14): recompute via
            // sealHash — the SAME impl append() sealed with and
            // verifyChainIntegrity() recomputes with — NOT plain hash(),
            // which ignores useRoutedSeal. auditChainFull was the missed
            // third site: under a routed seal it would flag a false
            // .selfHashMismatch on every entry if the routed digest ever
            // diverged from CryptoKit.
            if appended.selfHash != sealHash(canonical) {
                reasons.append(.selfHashMismatch)
            }

            // 2b. Signature.
            switch signingMode {
            case .hmac(let key):
                // audit-2026-06-12: CONSTANT-TIME read-side MAC verification (mirrors
                // append() + the Ed25519 malformed-base64 handling below).
                let macOK: Bool
                if let providedMac = Data(base64Encoded: appended.entry.signature) {
                    macOK = HMAC<SHA256>.isValidAuthenticationCode(
                        providedMac, authenticating: canonical, using: key)
                } else {
                    macOK = false
                }
                if !macOK {
                    reasons.append(.signatureInvalid)
                }
            case .ed25519(let keyPair):
                let valid: Bool
                if let sigData = Data(
                    base64Encoded: appended.entry.signature)
                {
                    valid = keyPair.publicKey.isValidSignature(
                        sigData, for: canonical)
                } else {
                    valid = false
                }
                if !valid {
                    reasons.append(.signatureInvalid)
                }
            }

            if !reasons.isEmpty {
                corruptions.append(BASSignatureAuditCorruption(
                    position: position,
                    auditID: appended.entry.auditID,
                    reasons: reasons))
            }

            // Advance expected-prior for next position. Even if
            // this entry's selfHash was tampered, we want to
            // continue scanning from the STORED selfHash so the
            // next entry's prior-hash check is meaningful (we
            // already flagged the mismatch on THIS entry).
            expectedPrior = appended.selfHash
        }

        return BASSignatureAuditReport(
            isClean: corruptions.isEmpty,
            totalEntriesScanned: entries.count,
            corruptions: corruptions)
    }

    /// M92 test-only tamper primitive.
    ///
    /// Directly mutates an entry at `position` in the actor's
    /// internal chain. Used by `BASSignatureAuditReportTests` to
    /// simulate disk corruption / memory tampering without requiring
    /// a full SQLite round-trip. Production callers **MUST NOT** use
    /// this — it reaches past every public contract the ledger
    /// otherwise enforces. The leading underscore + `TestTamper`
    /// suffix are the Swift convention for test-only hooks.
    ///
    /// Marked `internal` (default) rather than `private` so
    /// `@testable import BASSovereign` from the test module can
    /// reach it. Swift does not have a cleaner "test-only"
    /// visibility tier; discipline falls on the naming + doc.
    func _m92TestTamper(
        position: Int,
        replacement: @Sendable (AppendedEntry) -> AppendedEntry
    ) {
        guard position >= 0, position < entries.count else { return }
        entries[position] = replacement(entries[position])
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

    // MARK: - M90 · Observation-bundle streaming (L1–L13)
    //
    // The M45 coverage-verdict surface above stores ONE verdict per
    // turn — the cross-layer rollup. Hosts that want to stream the
    // underlying per-layer observation bundles (L1–L13) for an audit
    // replay need a richer record: every layer's raw observation
    // summary, preserved turn-by-turn, queryable without reading the
    // hash chain.
    //
    // M90 adds a parallel `observationBundles[]` storage alongside
    // `coverageVerdicts[]`. It uses the same "parallel to but not
    // on" hash-chain design:
    //
    //   - Hash chain stays the sole home of append-only sovereign
    //     verdicts — BR-012 integrity is unaffected.
    //   - `coverageVerdicts[]` (M45) holds the cross-layer rollup.
    //   - `observationBundles[]` (M90) holds the per-layer detail a
    //     caller chose to stream.
    //
    // A ledger that never receives `recordObservationBundle(_:)`
    // calls keeps the pre-M90 behaviour (L14-only audit chain +
    // L14-only coverage verdict). Streaming is opt-in.

    /// Record a per-turn observation bundle — typically the
    /// `BASObservationReconciliationReport` carrying L1–L13 summaries
    /// for one turn, built by the coordinator after every layer has
    /// emitted its observation bundle.
    ///
    /// If a report already exists for the same `(sessionID, turnID)`
    /// it is replaced in place (last-write-wins) so a coordinator
    /// that re-emits mid-turn doesn't accrete stale bundles. Ordering
    /// of first-seen `(session, turn)` keys is preserved for
    /// deterministic iteration.
    public func recordObservationBundle(
        _ report: BASObservationReconciliationReport
    ) {
        if let idx = observationBundles.firstIndex(where: {
            $0.sessionID == report.sessionID
                && $0.turnID == report.turnID
        }) {
            observationBundles[idx] = report
        } else {
            observationBundles.append(report)
        }
    }

    /// Look up the per-turn observation bundle for a specific
    /// `(sessionID, turnID)` pair, or `nil` if the ledger never
    /// received one for that turn (i.e. the host did not stream
    /// L1–L13 on that turn).
    public func observationBundle(
        forSession sessionID: String,
        turn turnID: String
    ) -> BASObservationReconciliationReport? {
        observationBundles.first {
            $0.sessionID == sessionID && $0.turnID == turnID
        }
    }

    /// Every per-turn observation bundle streamed for a session, in
    /// first-seen turn order.
    public func observationBundles(
        forSession sessionID: String
    ) -> [BASObservationReconciliationReport] {
        observationBundles.filter { $0.sessionID == sessionID }
    }

    /// Total number of per-turn observation bundles across every
    /// session.
    public func observationBundleCount() -> Int {
        observationBundles.count
    }

    /// Full value-copy export of observation bundles for replay /
    /// governance. Parallel to `coverageVerdictSnapshot()`.
    public func observationBundleSnapshot()
        -> [BASObservationReconciliationReport]
    {
        observationBundles
    }

    // MARK: - M123 · Sovereign frame parallel storage
    //
    // The L14 whitepaper §5.1 aggregator binds one turn's sovereign
    // surface (device/host/continuity/fold/risk/permit refs + policy
    // hash + contamination refs). Parallel storage, same off-chain
    // discipline as observationBundles[] — last-write-wins on
    // (sessionID, turnID), first-seen insertion order preserved.

    /// Record a per-turn `BASSovereignFrame`. If a frame already
    /// exists for the same `(sessionID, turnID)` the new frame
    /// replaces it in place — a coordinator that re-emits mid-turn
    /// (e.g. after a late risk card landed) overwrites cleanly with
    /// the latest aggregator. First-seen order is preserved.
    public func recordSovereignFrame(
        _ frame: BASSovereignFrame
    ) {
        if let idx = sovereignFrames.firstIndex(where: {
            $0.sessionID == frame.sessionID
                && $0.turnID == frame.turnID
        }) {
            sovereignFrames[idx] = frame
        } else {
            sovereignFrames.append(frame)
        }
    }

    /// Look up the per-turn sovereign frame for a specific
    /// `(sessionID, turnID)` pair, or `nil` if no frame was recorded
    /// for that turn.
    public func sovereignFrame(
        forSession sessionID: String,
        turn turnID: String
    ) -> BASSovereignFrame? {
        sovereignFrames.first {
            $0.sessionID == sessionID && $0.turnID == turnID
        }
    }

    /// Every per-turn sovereign frame recorded for a session, in
    /// first-seen turn order.
    public func sovereignFrames(
        forSession sessionID: String
    ) -> [BASSovereignFrame] {
        sovereignFrames.filter { $0.sessionID == sessionID }
    }

    /// Total number of sovereign frames across every session.
    public func sovereignFrameCount() -> Int {
        sovereignFrames.count
    }

    /// Full value-copy export of sovereign frames for replay /
    /// governance. Parallel to `observationBundleSnapshot()`.
    public func sovereignFrameSnapshot() -> [BASSovereignFrame] {
        sovereignFrames
    }

    // MARK: - M83 · Rotation
    //
    // Rotation closes the currently-open segment for a given session
    // by recording its tail hash, and opens a new successor anchored
    // to that tail. The chain-continuity invariant is unchanged:
    // neighboring entries still have `priorHash == prior.selfHash`.
    // The only thing rotation adds is a named segment boundary so
    // callers can snapshot, archive, or traverse the ledger in
    // bounded chunks without losing the ability to re-verify the
    // whole chain end-to-end.

    /// Rotate the audit ledger. Closes the currently-open segment for
    /// the plan's `sessionID` and opens a fresh successor anchored to
    /// the closed segment's tail hash. Returns the closed-segment
    /// descriptor.
    ///
    /// If the session has no open segment (i.e. nothing has been
    /// appended for it since the last rotation) this throws
    /// `noOpenSegment`. A caller that needs "rotate or else record
    /// nothing" semantics can check `currentSegment(forSession:)`
    /// first.
    ///
    /// The rotation itself is NOT a separate audit entry — it is a
    /// bookkeeping-only operation, so the hash chain's content is
    /// unchanged. A caller that wants an auditable rotation event
    /// (e.g. for a session closure or key rebaseline) should append
    /// a normal audit entry describing the rotation BEFORE calling
    /// `rotate(plan:)`. LINEAGE_CUT's internal rotation follows
    /// exactly this discipline: it appends a cut-marker entry, then
    /// rotates so the marker becomes the tail of the closed segment.
    @discardableResult
    public func rotate(
        plan: BASSovereignLedgerRotationPlan
    ) throws -> BASSovereignLedgerSegment {
        guard let segIndex = openSegmentBySession[plan.sessionID] else {
            throw LedgerError.noOpenSegment(sessionID: plan.sessionID)
        }
        var closing = segments[segIndex]
        // Tail hash is the latest appended entry's selfHash; the
        // `ensureOpenSegment` invariant guarantees the open segment
        // has at least one entry by the time rotation is valid
        // (entryCount > 0, checked via the noOpenSegment guard above).
        let tail = lastEntrySelfHash(forSession: plan.sessionID)
            ?? closing.startAnchor
        closing.tailHash = tail
        closing.closedAt = plan.requestedAt
        closing.closedBy = plan.reason
        closing.closingRotationID = plan.rotationID
        segments[segIndex] = closing
        openSegmentBySession.removeValue(forKey: plan.sessionID)

        // M91 — persist the now-closed segment so reopened ledgers
        // see the rotation state. Open-to-closed is the primary
        // transition whose metadata is not derivable from entries
        // alone.
        try storage.persistSegment(closing)

        return closing
    }

    /// Segment descriptor for the currently-open segment of a session,
    /// or `nil` when the session has nothing open.
    public func currentSegment(
        forSession sessionID: String
    ) -> BASSovereignLedgerSegment? {
        guard let idx = openSegmentBySession[sessionID] else { return nil }
        return segments[idx]
    }

    /// Every segment, closed or open, in creation order.
    public func allSegments() -> [BASSovereignLedgerSegment] {
        segments
    }

    /// Segments belonging to the given session, in creation order.
    public func segments(
        forSession sessionID: String
    ) -> [BASSovereignLedgerSegment] {
        segments.filter { $0.sessionID == sessionID }
    }

    // MARK: - M83 · LINEAGE_CUT
    //
    // LINEAGE_CUT is the sovereign-approved propagation primitive:
    // it does NOT delete audit entries (BR-012 forbids that), it
    // records a *marker* entry whose `signalRefs` enumerate the audit
    // IDs that downstream consumers (L8 forget cascade, L13 version
    // arboretum, L5 host candidate prune) should treat as cut. The
    // cascade traversal is deterministic and rooted at one audit ID,
    // hopping along reference edges up to the depth the plan
    // specifies. Entries whose `ruleIDs` intersect
    // `protectedRuleIDs` short-circuit the traversal — they are
    // recorded as "protected" and their own outgoing edges are NOT
    // followed.

    /// Apply a LINEAGE_CUT request. The cut's outcome is materialised
    /// as a regular hash-chained audit entry ("cut marker") followed
    /// by an immediate rotation so the marker closes its segment.
    /// Returns the outcome, which the caller can persist or forward
    /// to downstream consumers.
    @discardableResult
    public func lineageCut(
        request: BASSovereignLineageCutRequest
    ) throws -> BASSovereignLineageCutOutcome {
        guard !request.cutID.isEmpty else {
            throw LedgerError.invalidEntry("cutID must be non-empty")
        }
        guard !request.sessionID.isEmpty else {
            throw LedgerError.invalidEntry("sessionID must be non-empty")
        }
        guard auditRefIndex[request.rootAuditID] != nil else {
            throw LedgerError.lineageRootNotFound(
                auditID: request.rootAuditID)
        }

        // Traverse the reference graph from `rootAuditID` up to the
        // requested depth. Order is deterministic: BFS by insertion
        // layer, ties broken by the audit's original ledger position.
        let (affected, protected) = traverseLineage(
            rootAuditID: request.rootAuditID,
            depth: request.depth,
            protectedRuleIDs: request.protectedRuleIDs)

        let markerAuditID = "cut-\(request.cutID)"
        // chapter 九百九十六.5 Round-15 CRITICAL-2:hardened
        // canonical-bytes for LINEAGE_CUT marker (signalRefs
        // carry caller-supplied audit IDs which may contain `,`)
        let markerEntry = BASSovereignAuditEntry(
            // ch 1011 / M3770 — Round-21 HIGH-1: shared constant
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: markerAuditID,
            sessionID: request.sessionID,
            turnID: "lineage-cut",
            verdictRef: "lineage-cut:\(request.cutID)",
            ruleIDs: ["LINEAGE-CUT"],
            signalRefs: affected,
            actionRefs: protected,
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: request.requestedAt)
        _ = try append(markerEntry)

        // Close the segment so the marker becomes the tail of the
        // outgoing segment. Consumers that restore from a snapshot
        // see a clean segment-end at the cut, which simplifies
        // propagation state machines downstream.
        let rotationPlan = BASSovereignLedgerRotationPlan(
            rotationID: "rot-\(request.cutID)",
            sessionID: request.sessionID,
            beforeTurnID: nil,
            reason: .lineageCut,
            requestedAt: request.requestedAt)
        _ = try rotate(plan: rotationPlan)

        let outcome = BASSovereignLineageCutOutcome(
            cutID: request.cutID,
            sessionID: request.sessionID,
            affectedAuditIDs: affected,
            protectedAuditIDs: protected,
            rotation: rotationPlan,
            markerAuditID: markerAuditID,
            completedAt: request.requestedAt)
        cutOutcomes[markerAuditID] = outcome
        return outcome
    }

    /// Look up the full outcome record for a previously-applied cut,
    /// keyed by the marker audit ID the cut wrote into the chain.
    /// Returns `nil` if no cut with that marker has been recorded.
    public func lineageCutOutcome(
        markerAuditID: String
    ) -> BASSovereignLineageCutOutcome? {
        cutOutcomes[markerAuditID]
    }

    /// Every cut outcome on record, in marker-insertion order.
    public func allLineageCutOutcomes() -> [BASSovereignLineageCutOutcome] {
        // Iterate entries in ledger order to preserve determinism.
        entries.compactMap { cutOutcomes[$0.entry.auditID] }
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
        // M87 — delegate to the package-level shared helper so the
        // static `verify(_:publicKey:signingNamespace:)` path and the
        // instance `sign(_:)` path share exactly one byte-layout
        // definition. A desync between the two was the #1 risk of
        // adding a static verifier; routing both sites through
        // `basSovereignAuditCanonicalBytes` closes that risk.
        basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: priorHash,
            signingNamespace: signingNamespace)
    }

    private func sign(_ data: Data) -> String {
        // M87 — dispatch on the active signing mode. HMAC is deterministic and
        // verified by a constant-time MAC check. Ed25519 (CryptoKit) is RANDOMIZED
        // (hedged — ADR-025), so it is verified CRYPTOGRAPHICALLY via isValidSignature,
        // NEVER by recompute-and-compare. (ch1044 audit H2: an earlier comment here
        // wrongly claimed Ed25519 was deterministic — corrected.)
        switch signingMode {
        case .hmac(let key):
            let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
            return Data(mac).base64EncodedString()
        case .ed25519(let keyPair):
            // ch1044 audit H1: do NOT silently swallow a signing failure into an empty
            // signature (which would persist a knowingly-invalid entry into the
            // tamper-evident chain). `signature(for:)` realistically never throws for a
            // valid key, but it IS a throwing API — so surface any failure to stderr.
            // The empty sentinel still fails verification downstream, so a bad entry
            // cannot pass even if this ever fires.
            do {
                return try keyPair.privateKey.signature(for: data)
                    .base64EncodedString()
            } catch {
                FileHandle.standardError.write(Data(
                    "[BASSovereignAuditLedger] Ed25519 signing FAILED: \(error)\n".utf8))
                return ""
            }
        }
    }

    private func hash(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).base64EncodedString()
    }

    /// audit sovereign LOW-8 — the SINGLE source of the seal-hash routing decision, used by
    /// `append` (seal), `verifyChainIntegrity` (recompute), AND `auditChainFull` (recompute).
    /// Routing all three through one helper guarantees they can never use different SHA
    /// implementations for the same chain. (id14: auditChainFull was the missed third site —
    /// it recomputed via plain `hash(_:)`, ignoring the routed seal.)
    func sealHash(_ canonical: Data) -> String {
        Self.useRoutedSeal ? Self.hashViaAutoRouter(canonical) : hash(canonical)
    }

    // MARK: - M83 · Segment helpers (private)

    /// Return the segment index for a session's open segment, opening
    /// a new one if necessary. Called from `append` so every appended
    /// entry lands inside a tracked segment.
    private func ensureOpenSegment(
        for sessionID: String,
        startAnchor: String,
        openedAt: Date
    ) -> Int {
        if let existing = openSegmentBySession[sessionID] {
            return existing
        }
        let nextIndex = segments.count
        let priorForSession = segments
            .filter { $0.sessionID == sessionID }
            .count
        let segment = BASSovereignLedgerSegment(
            segmentID: "seg-\(sessionID)-\(priorForSession)",
            segmentIndex: priorForSession,
            sessionID: sessionID,
            startAnchor: startAnchor,
            tailHash: nil,
            entryCount: 0,
            openedAt: openedAt,
            closedAt: nil,
            closedBy: nil,
            closingRotationID: nil)
        segments.append(segment)
        openSegmentBySession[sessionID] = nextIndex
        return nextIndex
    }

    /// Self-hash of the most-recently-appended entry for a given
    /// session. Used by `rotate` to materialise the closed segment's
    /// tail.
    private func lastEntrySelfHash(forSession sessionID: String) -> String? {
        for appended in entries.reversed() {
            if appended.entry.sessionID == sessionID {
                return appended.selfHash
            }
        }
        return nil
    }

    // MARK: - M83 · Lineage traversal (private)

    /// Reference-graph traversal shared by `lineageCut`. Returns a
    /// deterministic tuple of `(affected, protected)` audit IDs.
    ///
    /// ## Direction: downstream cascade
    ///
    /// LINEAGE_CUT asks: "if I want to cut X, which OTHER entries
    /// depended on X and must therefore also be cut?" An entry Y that
    /// has X in its `verdictRef` / `signalRefs` / `actionRefs` /
    /// `snapshotRef` is *downstream* of X — Y cited X as an input, so
    /// cutting X must propagate forward to Y. Cascade therefore walks
    /// the REVERSE-reference edges: from a cut node, find entries
    /// that named it, and cascade to them. The root's own outgoing
    /// references are not followed (those are X's inputs — cutting X
    /// doesn't retroactively invalidate the events X drew on).
    ///
    /// ## Ordering and determinism
    ///
    /// First-seen BFS. Within a hop, candidate descendants are
    /// ordered by their original ledger-append position so replay is
    /// stable regardless of host code that triggered the cut.
    ///
    /// ## Depth rules
    ///
    ///   - `.root`: only the root; no descendants.
    ///   - `.bounded(K)`: root = hop 0; descend K additional hops.
    ///     K < 0 is clamped to 0.
    ///   - `.entireLineage`: descend until fixpoint.
    ///
    /// ## Protected short-circuit
    ///
    /// An entry whose `ruleIDs` intersect `protectedRuleIDs` moves to
    /// the `protected` list and its own outgoing edges are NOT
    /// followed. The cascade stops at it; anything further downstream
    /// through that guarded node is preserved alongside it. This is
    /// the sovereign-protected bail-out — deadStop / rollback /
    /// sovereign-lock events stay in the trail even if something
    /// further upstream asked for their removal.
    private func traverseLineage(
        rootAuditID: String,
        depth: BASSovereignLineageCutDepth,
        protectedRuleIDs: Set<String>
    ) -> (affected: [String], protected: [String]) {
        // Build a reverse-reference index: for each audit ID, the list
        // of OTHER audit IDs that cite it. We build it on demand here
        // because lineage cuts are rare enough that paying for a
        // persistent index on every append is not worth it. Ledger
        // sizes under tens-of-thousands keep this O(n) scan cheap.
        var referencedBy: [String: [Int]] = [:]
        for (idx, appended) in entries.enumerated() {
            let entry = appended.entry
            var cited: Set<String> = []
            if !entry.verdictRef.isEmpty {
                cited.insert(entry.verdictRef)
            }
            for ref in entry.signalRefs {
                cited.insert(ref)
            }
            for ref in entry.actionRefs {
                cited.insert(ref)
            }
            if !entry.snapshotRef.isEmpty {
                cited.insert(entry.snapshotRef)
            }
            for ref in cited {
                // Citations that don't resolve to a real audit ID are
                // skipped — verdictRef commonly names synthetic codes
                // that aren't themselves audit entries.
                guard auditRefIndex[ref] != nil else { continue }
                referencedBy[ref, default: []].append(idx)
            }
        }

        var affected: [String] = []
        var protected: [String] = []
        var seen: Set<String> = [rootAuditID]
        var frontier: [String] = [rootAuditID]

        let maxHops: Int
        switch depth {
        case .root: maxHops = 0
        case .bounded(let hops): maxHops = max(0, hops)
        case .entireLineage: maxHops = Int.max
        }

        var hopsConsumed = 0
        while !frontier.isEmpty {
            var nextFrontier: [String] = []
            // Stable ordering: sort frontier by original ledger pos.
            let ordered = frontier.compactMap { auditID -> (Int, String)? in
                guard let idx = auditRefIndex[auditID] else { return nil }
                return (idx, auditID)
            }.sorted { $0.0 < $1.0 }.map { $0.1 }

            for auditID in ordered {
                guard let idx = auditRefIndex[auditID] else { continue }
                let entry = entries[idx].entry
                let ruleSet = Set(entry.ruleIDs)
                if !ruleSet.isDisjoint(with: protectedRuleIDs) {
                    protected.append(auditID)
                    // Do NOT follow this entry's downstream edges.
                    continue
                }
                affected.append(auditID)
                if hopsConsumed >= maxHops { continue }
                // Downstream: entries that cite `auditID`.
                let downstreamIndices = (referencedBy[auditID] ?? [])
                    .sorted()
                for downIdx in downstreamIndices {
                    let downID = entries[downIdx].entry.auditID
                    if seen.contains(downID) { continue }
                    seen.insert(downID)
                    nextFrontier.append(downID)
                }
            }
            frontier = nextFrontier
            hopsConsumed += 1
            if hopsConsumed > maxHops { break }
        }
        return (affected, protected)
    }
}
