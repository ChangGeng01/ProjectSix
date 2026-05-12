import Foundation
import BASRuntimeCore

/// L5 host-constitution candidate pipeline.
///
/// ## Why this exists
///
/// Before M6 the pieces were all present but unwired:
///
/// - `BASHostChangeCandidate` — schema with lifecycle states
///   (pending / preview / approved / rejected)
/// - `BASHostConstitution.staged(with:)` — pure preview projection
///   that annotates narrativeLoom with candidate metadata
/// - `BASHostVersionTree.approving(_:)` — pure commit that appends
///   the candidate as a version and swaps `activeVersionID`
/// - `BASHostConstitutionVault` via `vaultSnapshot(versionTree:...)`
///   — the externally-visible projection
///
/// What was missing: **a single actor that composes them so the
/// same input always yields the same projection**. Without that, two
/// consumers (the runtime path and the SDK façade) can run the
/// exact same pure helpers in slightly different orders and end up
/// with divergent projections. That's the parity bug the plan's M6
/// is designed to close.
///
/// ## The parity contract (see tests)
///
/// For any base constitution C₀, version tree T₀, and candidate c,
/// running `submit(c) → approve(c.candidateID)` through this
/// pipeline MUST produce the same external `BASHostConstitutionVault`
/// as the direct pure composition:
///
///   pipeline.project()
///     ==
///   C₀.staged(with: c).with(activeVersion: c.candidateID)
///     .vaultSnapshot(versionTree: T₀.approving(c))
///
/// The parity test in `BASHostCandidatePipelineTests` pins this.
///
/// ## Error semantics
///
/// The pipeline is an actor: all mutations go through it. Every
/// error is a typed `PipelineError`; the pipeline never silently
/// swallows. Consumers that want to see `Result` semantics can wrap
/// the throwing calls.
public actor BASHostCandidatePipeline {

    // MARK: - Errors

    public enum PipelineError: Error, Equatable, Sendable {
        case duplicateCandidate(id: String)
        case unknownCandidate(id: String)
        case candidateNotInPreview(id: String)
        case candidateAlreadyDecided(id: String, state: String)
        case versionNotFound(id: String)
        case versionFrozen(id: String)
    }

    // MARK: - Decision log

    public struct RejectionRecord: Codable, Sendable, Equatable {
        public let candidateID: String
        public let reason: String
        public let recordedAt: Date

        public init(candidateID: String, reason: String, recordedAt: Date) {
            self.candidateID = candidateID
            self.reason = reason
            self.recordedAt = recordedAt
        }
    }

    // MARK: - State

    private var constitution: BASHostConstitution
    private var versionTree: BASHostVersionTree
    private var candidates: [String: BASHostChangeCandidate] = [:]
    private var rejections: [RejectionRecord] = []
    private let clock: @Sendable () -> Date

    public init(
        constitution: BASHostConstitution,
        versionTree: BASHostVersionTree,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.constitution = constitution
        self.versionTree = versionTree
        self.clock = clock
    }

    // MARK: - Inspection

    public func currentConstitution() -> BASHostConstitution { constitution }
    public func currentVersionTree() -> BASHostVersionTree { versionTree }
    public func pendingIDs() -> [String] { versionTree.pendingCandidateIDs }
    public func rejectionLog() -> [RejectionRecord] { rejections }
    public func candidate(_ id: String) -> BASHostChangeCandidate? {
        candidates[id]
    }

    // MARK: - Lifecycle

    /// Register a new candidate. The candidate enters `pendingCandidateIDs`
    /// and `approvalState` is normalized to `"pending"` so downstream
    /// consumers never have to guess the lifecycle state.
    @discardableResult
    public func submit(_ candidate: BASHostChangeCandidate) throws -> BASHostChangeCandidate {
        if candidates[candidate.candidateID] != nil {
            throw PipelineError.duplicateCandidate(id: candidate.candidateID)
        }
        var normalized = candidate
        normalized.approvalState = "pending"
        candidates[normalized.candidateID] = normalized
        versionTree.pendingCandidateIDs = basOrderedUnique(
            versionTree.pendingCandidateIDs + [normalized.candidateID])
        return normalized
    }

    /// Move a pending candidate into preview mode. Returns the
    /// staged constitution so callers (L9 candidate frontier, L12
    /// compare panel) can render the preview without mutating
    /// anything else. The stored candidate is updated with
    /// `previewState = "preview"` and `approvalState = "candidate"`
    /// so subsequent `.staged(_:)` calls are deterministic.
    @discardableResult
    public func preview(
        _ candidateID: String
    ) throws -> BASHostConstitution {
        guard var candidate = candidates[candidateID] else {
            throw PipelineError.unknownCandidate(id: candidateID)
        }
        if candidate.approvalState == "approved"
            || candidate.approvalState == "rejected"
        {
            throw PipelineError.candidateAlreadyDecided(
                id: candidateID, state: candidate.approvalState)
        }
        candidate.previewState = "preview"
        candidate.approvalState = "candidate"
        candidates[candidateID] = candidate
        return constitution.staged(with: candidate)
    }

    /// Approve a previewed candidate. Commits the candidate as a
    /// new version (via `versionTree.approving(_:)`) and rolls the
    /// live constitution's `activeVersion` + narrative annotations
    /// forward. Returns the post-commit constitution.
    @discardableResult
    public func approve(
        _ candidateID: String
    ) throws -> BASHostConstitution {
        guard var candidate = candidates[candidateID] else {
            throw PipelineError.unknownCandidate(id: candidateID)
        }
        if candidate.approvalState == "approved" {
            throw PipelineError.candidateAlreadyDecided(
                id: candidateID, state: "approved")
        }
        if candidate.approvalState == "rejected" {
            throw PipelineError.candidateAlreadyDecided(
                id: candidateID, state: "rejected")
        }

        // Ensure the candidate has walked through preview exactly
        // once, so the staged narrative is present in the committed
        // constitution. Consumers that skipped `preview()` still get
        // the full projection.
        if candidate.previewState.isEmpty || candidate.previewState == "idle" {
            candidate.previewState = "preview"
        }
        candidate.approvalState = "approved"
        candidates[candidateID] = candidate

        // Fold the staged narrative before bumping activeVersion
        // so the committed constitution carries the candidate's
        // unresolved-tensions + continuity-link annotations.
        var next = constitution.staged(with: candidate)
        next.activeVersion = candidate.candidateID

        self.versionTree = versionTree.approving(
            candidate, approvedAt: clock())
        self.constitution = next
        return next
    }

    /// Reject a candidate. Removes it from `pendingCandidateIDs`
    /// and appends a `RejectionRecord` to the decision log. The
    /// live constitution is untouched.
    @discardableResult
    public func reject(
        _ candidateID: String,
        reason: String
    ) throws -> RejectionRecord {
        guard var candidate = candidates[candidateID] else {
            throw PipelineError.unknownCandidate(id: candidateID)
        }
        if candidate.approvalState == "approved"
            || candidate.approvalState == "rejected"
        {
            throw PipelineError.candidateAlreadyDecided(
                id: candidateID, state: candidate.approvalState)
        }
        candidate.approvalState = "rejected"
        candidates[candidateID] = candidate
        versionTree.pendingCandidateIDs.removeAll { $0 == candidateID }

        let record = RejectionRecord(
            candidateID: candidateID,
            reason: reason,
            recordedAt: clock())
        rejections.append(record)
        return record
    }

    /// Roll back to a previously-approved version. Thin pass-through
    /// to `BASHostVersionTree.rollingBack(to:)` plus an `activeVersion`
    /// update on the live constitution so projections stay in sync.
    @discardableResult
    public func rollback(
        to versionID: String
    ) throws -> BASHostConstitution {
        guard versionTree.versions.contains(where: { $0.versionID == versionID }) else {
            throw PipelineError.versionNotFound(id: versionID)
        }
        if versionTree.frozenVersionIDs.contains(versionID) {
            throw PipelineError.versionFrozen(id: versionID)
        }
        self.versionTree = versionTree.rollingBack(to: versionID)
        var next = constitution
        next.activeVersion = versionID
        self.constitution = next
        return next
    }

    /// Freeze a historical version so rollback skips it. Pure
    /// pass-through to `BASHostVersionTree.freezing(versionID:)`.
    @discardableResult
    public func freeze(versionID: String) throws -> BASHostVersionTree {
        guard versionTree.versions.contains(where: { $0.versionID == versionID }) else {
            throw PipelineError.versionNotFound(id: versionID)
        }
        self.versionTree = versionTree.freezing(versionID: versionID)
        return versionTree
    }

    @discardableResult
    public func thaw(versionID: String) throws -> BASHostVersionTree {
        guard versionTree.versions.contains(where: { $0.versionID == versionID }) else {
            throw PipelineError.versionNotFound(id: versionID)
        }
        self.versionTree = versionTree.thawing(versionID: versionID)
        return versionTree
    }

    // MARK: - External projection

    /// The public-facing vault snapshot. This is the projection L11
    /// / L12 / Qinao SDK consumers read. Parity contract: this value
    /// is always equal to the result of applying the *same* pure
    /// helpers directly to the pipeline's current `constitution`
    /// and `versionTree`. That equivalence is what makes the
    /// pipeline safe to swap for raw pure helpers at any time —
    /// mostly useful for SDK façade unit tests.
    public func project(
        sourceDeviceID: String = "device.local",
        trustedDeviceIDs: [String] = [],
        forgetRequest: BASForgetRequest? = nil
    ) -> BASHostConstitutionVault {
        constitution.vaultSnapshot(
            versionTree: versionTree,
            forgetRequest: forgetRequest,
            sourceDeviceID: sourceDeviceID,
            trustedDeviceIDs: trustedDeviceIDs)
    }

    // MARK: - Pure parity helpers
    //
    // These helpers are public-static so tests (and an SDK façade
    // that wants to verify its own behaviour) can build the same
    // projection without instantiating the actor. The pipeline's
    // parity property is: sequential actor state after
    // `submit → approve` equals the output of these pure functions.

    /// Direct pure composition of the approval path. Given the
    /// base constitution C₀, version tree T₀, and candidate c,
    /// this returns the projection an outside observer would see
    /// after an approved commit. The pipeline's internal state
    /// after `submit(c) + approve(c.candidateID)` must match
    /// `parityProjection(of:)` exactly.
    public static func parityProjection(
        of candidate: BASHostChangeCandidate,
        from constitution: BASHostConstitution,
        versionTree: BASHostVersionTree,
        approvedAt: Date,
        sourceDeviceID: String = "device.local",
        trustedDeviceIDs: [String] = []
    ) -> BASHostConstitutionVault {
        // Mirror what `approve(_:)` does in-actor:
        //   1. normalize candidate state (pending → candidate → approved)
        //   2. fold narrative annotations via `.staged(with:)`
        //   3. bump activeVersion
        //   4. commit version tree via `.approving(_, approvedAt:)`
        var normalized = candidate
        if normalized.previewState.isEmpty
            || normalized.previewState == "idle"
        {
            normalized.previewState = "preview"
        }
        normalized.approvalState = "approved"

        // The pipeline also normalizes a freshly-submitted
        // candidate's ID into pendingCandidateIDs before approval
        // swings it back out — include that step so the snapshot
        // matches byte-for-byte.
        var startingTree = versionTree
        startingTree.pendingCandidateIDs = basOrderedUnique(
            startingTree.pendingCandidateIDs + [normalized.candidateID])

        var next = constitution.staged(with: normalized)
        next.activeVersion = normalized.candidateID

        let committed = startingTree.approving(
            normalized, approvedAt: approvedAt)
        return next.vaultSnapshot(
            versionTree: committed,
            sourceDeviceID: sourceDeviceID,
            trustedDeviceIDs: trustedDeviceIDs)
    }
}
