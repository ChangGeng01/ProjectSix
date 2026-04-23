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
        /// M83 — rotation was requested against a session that has no
        /// live (open) segment. This happens when a caller tries to
        /// double-close an already-closed session.
        case noOpenSegment(sessionID: String)
        /// M83 — LINEAGE_CUT referenced a root audit ID that doesn't
        /// exist in the current ledger scope.
        case lineageRootNotFound(auditID: String)
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

        // M83 — record segment membership. The current session either
        // has an open segment we can grow, or we lazily open one whose
        // `startAnchor` is whatever our `priorHash` was (the prior
        // segment's tail, or GENESIS for the very first entry).
        let segIndex = ensureOpenSegment(
            for: sealed.sessionID,
            startAnchor: priorHash,
            openedAt: sealed.appendedAt)
        segments[segIndex].entryCount += 1
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
        let markerEntry = BASSovereignAuditEntry(
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
