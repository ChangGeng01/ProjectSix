import Foundation
import CryptoKit
import BASRuntimeCore

/// `BR-04` SnapshotManager — the sovereign resolver for floating
/// snapshot references + integrity-verified restore gate.
///
/// ## Why this exists
///
/// Before today, `SnapshotAnchor.safeSnapshotRef` / `foldRefs` /
/// `hostVersionRef` were **unresolved strings**: no one could answer
/// "given anchor id X, is the payload I'm about to restore actually
/// the payload that was sealed?" SnapshotContinuityProof (the third
/// signature of the three-signature gate) was nominally nailed to
/// those fields — but without a registry and a hash verifier, there
/// was nothing for the proof to verify against.
///
/// This manager closes that gap. Every rollback anchor must be
/// registered with the payload bytes that were sealed at snapshot
/// time. The manager records the SHA-256 of that payload (plus the
/// set of fold/host refs the anchor names), and on restore the
/// caller hands the manager the payload bytes again — the manager
/// recomputes the hash and throws unless it matches.
///
/// ## Failure model
///
/// - Anchor unknown → `.unknownAnchor`
/// - Declared `integrityHash` in the anchor doesn't match what the
///   manager computes from the sealed payload → `.hashBinding-
///   Mismatch` at registration (anchor is rejected, not stored)
/// - Presented payload differs from the one at registration →
///   `.payloadHashMismatch` at verify time
/// - Fold/host ref not part of the anchor → `.referenceNotBound`
///
/// All four roll up into BR-004 `memoryOrHostWriteBypass` when fed
/// back into `HardObservations` via `markBrokenIfNeeded(anchorID:…)`,
/// because restoring without a verified continuity proof is exactly
/// the "third signature missing" case that BR-004 guards.
public actor BASSovereignSnapshotManager {
    /// Local mirror of `SnapshotAnchor`. Defined inside BASSovereign
    /// so this module remains a pure leaf — importing `BASOrchestration`
    /// (where the upstream type lives) would reverse the architectural
    /// dependency direction. A thin bridge at the integration boundary
    /// (BASHostKit / Qinao façade) converts between the two.
    public struct SnapshotAnchor:
        Sendable, Equatable, Codable
    {
        public let anchorID: String
        public let safeSnapshotRef: String
        public let foldRefs: [String]
        public let hostVersionRef: String?
        public let cacheStateRef: String?
        public let integrityHash: String

        public init(
            anchorID: String,
            safeSnapshotRef: String,
            foldRefs: [String] = [],
            hostVersionRef: String? = nil,
            cacheStateRef: String? = nil,
            integrityHash: String
        ) {
            self.anchorID = anchorID
            self.safeSnapshotRef = safeSnapshotRef
            self.foldRefs = foldRefs
            self.hostVersionRef = hostVersionRef
            self.cacheStateRef = cacheStateRef
            self.integrityHash = integrityHash
        }
    }

    public enum ManagerError:
        Error, Equatable, Sendable, Codable
    {
        case unknownAnchor(id: String)
        case hashBindingMismatch(anchorID: String, declared: String, computed: String)
        case payloadHashMismatch(anchorID: String, expected: String, actual: String)
        case referenceNotBound(anchorID: String, reference: String)
        case anchorAlreadyRegistered(id: String)
    }

    /// What we remember about each registered anchor. The `payloadHash`
    /// is the ground truth — verification at restore time recomputes
    /// it and compares. The `foldRefs` / `hostVersionRef` / `cacheStateRef`
    /// mirror the anchor's fields so lookup doesn't need to cache the
    /// anchor itself.
    public struct RegisteredSnapshot:
        Sendable, Equatable, Codable
    {
        public let anchor: SnapshotAnchor
        public let payloadHash: String
        public let registeredAt: Date

        public init(anchor: SnapshotAnchor, payloadHash: String, registeredAt: Date) {
            self.anchor = anchor
            self.payloadHash = payloadHash
            self.registeredAt = registeredAt
        }
    }

    private var snapshots: [String: RegisteredSnapshot] = [:]
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: - Registration

    /// Register an anchor + the payload bytes that were snapshotted.
    /// The manager computes SHA-256 of `sealedPayload` and demands
    /// that it equals `anchor.integrityHash`; otherwise the anchor is
    /// rejected. Two distinct ways this fails in production:
    ///
    /// 1. Caller computed the hash with a different encoding — a bug
    ///    we want to surface loudly, not silently record.
    /// 2. Payload was tampered between "sealed" and "registered" — the
    ///    attacker is trying to plant an anchor whose hash matches the
    ///    tampered bytes. Registration must still compute and compare
    ///    against the declared hash so we at least catch the mismatch
    ///    against the *declared* value.
    @discardableResult
    public func register(
        anchor: SnapshotAnchor,
        sealedPayload: Data,
        replaceExisting: Bool = false
    ) throws -> RegisteredSnapshot {
        if snapshots[anchor.anchorID] != nil, !replaceExisting {
            throw ManagerError.anchorAlreadyRegistered(id: anchor.anchorID)
        }
        let computed = Self.hash(sealedPayload)
        let declared = anchor.integrityHash.lowercased()
        guard declared == computed else {
            throw ManagerError.hashBindingMismatch(
                anchorID: anchor.anchorID,
                declared: declared,
                computed: computed
            )
        }
        let entry = RegisteredSnapshot(
            anchor: anchor,
            payloadHash: computed,
            registeredAt: now()
        )
        snapshots[anchor.anchorID] = entry
        return entry
    }

    // MARK: - Resolution

    public func resolve(anchorID: String) -> SnapshotAnchor? {
        snapshots[anchorID]?.anchor
    }

    public func isRegistered(anchorID: String) -> Bool {
        snapshots[anchorID] != nil
    }

    public func registeredSnapshot(anchorID: String) -> RegisteredSnapshot? {
        snapshots[anchorID]
    }

    // MARK: - Verification

    /// Verify that the payload about to be restored matches the hash
    /// recorded at registration. Called by the sovereign restore
    /// path **before** any state is mutated. On error, the caller
    /// must refuse the restore and set BR-004 on the next verdict.
    public func verifyRestore(anchorID: String, presentedPayload: Data) throws {
        guard let entry = snapshots[anchorID] else {
            throw ManagerError.unknownAnchor(id: anchorID)
        }
        let actual = Self.hash(presentedPayload)
        guard actual == entry.payloadHash else {
            throw ManagerError.payloadHashMismatch(
                anchorID: anchorID,
                expected: entry.payloadHash,
                actual: actual
            )
        }
    }

    /// Verify that a fold ref is actually part of the named anchor.
    /// Used when downstream code claims "I am restoring fold F under
    /// anchor A" — we refuse if F isn't bound to A.
    public func verifyFoldRef(_ foldRef: String, in anchorID: String) throws {
        guard let entry = snapshots[anchorID] else {
            throw ManagerError.unknownAnchor(id: anchorID)
        }
        guard entry.anchor.foldRefs.contains(foldRef) else {
            throw ManagerError.referenceNotBound(
                anchorID: anchorID,
                reference: "fold:\(foldRef)"
            )
        }
    }

    public func verifyHostVersion(_ hostVersionRef: String, in anchorID: String) throws {
        guard let entry = snapshots[anchorID] else {
            throw ManagerError.unknownAnchor(id: anchorID)
        }
        guard entry.anchor.hostVersionRef == hostVersionRef else {
            throw ManagerError.referenceNotBound(
                anchorID: anchorID,
                reference: "hostVersion:\(hostVersionRef)"
            )
        }
    }

    // MARK: - Observation helper

    /// Convenience: run `verifyRestore` and, on any manager error,
    /// flip BR-004 `snapshotContinuityBroken`. Non-throwing so the
    /// sovereign pipeline can stay infallible while still recording
    /// the failure for VerdictEngine to escalate to ROLLBACK/DEAD_STOP.
    ///
    /// Returns `true` iff the observation was marked broken (i.e.
    /// verification failed).
    @discardableResult
    public func markBrokenIfNeeded(
        anchorID: String,
        presentedPayload: Data,
        in observations: inout BASSovereignVerdictEngine.HardObservations
    ) -> Bool {
        do {
            try verifyRestore(anchorID: anchorID, presentedPayload: presentedPayload)
            return false
        } catch {
            observations.memoryOrHostWriteBypass = true
            return true
        }
    }

    // MARK: - Lifecycle

    public func unregister(anchorID: String) {
        snapshots.removeValue(forKey: anchorID)
    }

    public func registeredCount() -> Int {
        snapshots.count
    }

    /// Snapshot of all registered anchors, newest first. Audit use.
    public func allSnapshots() -> [RegisteredSnapshot] {
        snapshots.values.sorted { $0.registeredAt > $1.registeredAt }
    }

    // MARK: - Hashing

    /// Canonical SHA-256 hex used by the manager. Callers building
    /// anchors should use this to pre-compute `integrityHash` so that
    /// registration succeeds.
    public static func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        // LEGACY (chapter 七百十九 第三刀 / M2268 — kept as
        // comment for byte-pinned compat):
        //     return digest.map {
        //         String(format: "%02x", $0) }.joined()
        return BASAutoRouteRanker.bytesToHexLower(
            Array(digest))
    }
}
