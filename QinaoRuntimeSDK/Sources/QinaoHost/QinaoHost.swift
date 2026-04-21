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
