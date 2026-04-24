import Foundation
import BASRuntimeCore
import BASMemory

/// QinaoHost — the L5 façade.
///
/// This module is the host's own handle on the second brain's
/// *Host Constitution Vault*: the 12-domain store of identity,
/// values, goals, boundaries, relations, rhythm, style, routines,
/// consents, narrative, protections, plus the version and candidate
/// tracks.
///
/// Everything here preserves three properties from the substrate:
///
/// 1. **Host changes are staged.** A new goal does not replace an
///    old one until the host explicitly approves it — submit,
///    preview, approve / reject, commit.
/// 2. **Every committed change is versioned.** The version tree
///    keeps parentage, freeze flags, and projection anchors so a
///    rollback is a pointer move, not a reconstruction.
/// 3. **Deletion is a first-class verb.** `revokeAuthorization`
///    and `forget` remove material from the vault *and* the
///    version tree's projection path.
///
/// The public surface deliberately uses `BASHostConstitutionVault`
/// and its siblings as the value types — they are data, they don't
/// leak the substrate's internal verdict machinery, and re-wrapping
/// them in mirror types would only add drift.
public actor QinaoHost {

    public enum HostError: Error, Equatable, Sendable {
        case noConstitutionLoaded
        case candidateRejected(id: String, reason: String)
        case unknownVersion(id: String)
        case versionFrozen(id: String)
    }

    private let pipeline: BASHostCandidatePipeline

    public init(pipeline: BASHostCandidatePipeline) {
        self.pipeline = pipeline
    }

    /// The current active host constitution vault (domain values
    /// projected from the active version).
    public func currentHost(
        sourceDeviceID: String = "device.local",
        trustedDeviceIDs: [String] = []
    ) async -> BASHostConstitutionVault {
        await pipeline.project(
            sourceDeviceID: sourceDeviceID,
            trustedDeviceIDs: trustedDeviceIDs)
    }

    // MARK: - M122 L5 governance surface (hot-path accessors)
    //
    // These pass-throughs expose the raw `BASHostConstitution` and
    // `BASHostVersionTree` the pipeline carries — not the domain-
    // projected vault. `QinaoRuntime.sendSession` uses them as the
    // ingredients for `BASHostConstitutionObservationBundle.derive(...)`
    // so the L5 governance observation lands in the audit ledger
    // alongside L1 (M121) and L14 (M9) every turn.
    //
    // The methods are deliberately thin — no staging, no approval
    // lifecycle — so their presence on the public surface doesn't
    // let callers circumvent `submit / preview / approve / reject`.
    // They read the already-committed state.

    /// M122 — The active `BASHostConstitution` currently committed
    /// in the pipeline. Non-nil once the pipeline has been
    /// initialised with a seed constitution (which every production
    /// call site does in `init`). Hosts that wire a pipeline without
    /// a seed would receive a degenerate value — but since the
    /// pipeline's own initialiser requires a non-optional seed, this
    /// accessor is always valid on any runtime built through the
    /// public surface.
    public func currentConstitution() async -> BASHostConstitution {
        await pipeline.currentConstitution()
    }

    /// M122 — The current `BASHostVersionTree` backing the
    /// pipeline's version pointer. Includes committed versions,
    /// pending candidate IDs, and frozen-version set — everything
    /// the L5 governance derivation in
    /// `BASHostConstitutionObservationBundle.derive(...)` needs.
    public func currentVersionTree() async -> BASHostVersionTree {
        await pipeline.currentVersionTree()
    }

    /// Stage a new host change candidate for preview.
    @discardableResult
    public func submit(
        _ candidate: BASHostChangeCandidate
    ) async throws -> BASHostChangeCandidate {
        do {
            return try await pipeline.submit(candidate)
        } catch BASHostCandidatePipeline.PipelineError
            .duplicateCandidate(let id)
        {
            throw HostError.candidateRejected(
                id: id, reason: "duplicate")
        }
    }

    /// Move a candidate into preview state (runs the shadow
    /// projection the host can inspect before approving).
    @discardableResult
    public func preview(
        candidateID: String
    ) async throws -> BASHostConstitution {
        do {
            return try await pipeline.preview(candidateID)
        } catch BASHostCandidatePipeline.PipelineError
            .unknownCandidate(let id)
        {
            throw HostError.candidateRejected(
                id: id, reason: "unknown")
        }
    }

    /// Approve a candidate — writes a new version and advances the
    /// active pointer. Fast-track: if the candidate is still in
    /// `idle`/`empty` preview, the pipeline will auto-stage it.
    @discardableResult
    public func approve(
        candidateID: String
    ) async throws -> BASHostConstitution {
        do {
            return try await pipeline.approve(candidateID)
        } catch BASHostCandidatePipeline.PipelineError
            .unknownCandidate(let id)
        {
            throw HostError.candidateRejected(
                id: id, reason: "unknown")
        } catch BASHostCandidatePipeline.PipelineError
            .candidateAlreadyDecided(let id, let state)
        {
            throw HostError.candidateRejected(
                id: id, reason: "already-\(state)")
        }
    }

    /// Reject a candidate — it leaves a `RejectionRecord` for
    /// audit but never touches the version tree.
    @discardableResult
    public func reject(
        candidateID: String,
        reason: String
    ) async throws -> BASHostCandidatePipeline.RejectionRecord {
        do {
            return try await pipeline.reject(candidateID, reason: reason)
        } catch BASHostCandidatePipeline.PipelineError
            .unknownCandidate(let id)
        {
            throw HostError.candidateRejected(
                id: id, reason: "unknown")
        } catch BASHostCandidatePipeline.PipelineError
            .candidateAlreadyDecided(let id, let state)
        {
            throw HostError.candidateRejected(
                id: id, reason: "already-\(state)")
        }
    }

    /// Roll the active version pointer to a named past version.
    @discardableResult
    public func rollback(
        toVersionID id: String
    ) async throws -> BASHostConstitution {
        do {
            return try await pipeline.rollback(to: id)
        } catch BASHostCandidatePipeline.PipelineError
            .versionNotFound(let id)
        {
            throw HostError.unknownVersion(id: id)
        } catch BASHostCandidatePipeline.PipelineError
            .versionFrozen(let id)
        {
            throw HostError.versionFrozen(id: id)
        }
    }

    /// Mark a version frozen so future rollbacks skip it.
    @discardableResult
    public func freeze(
        versionID: String
    ) async throws -> BASHostVersionTree {
        try await pipeline.freeze(versionID: versionID)
    }

    @discardableResult
    public func thaw(
        versionID: String
    ) async throws -> BASHostVersionTree {
        try await pipeline.thaw(versionID: versionID)
    }
}
