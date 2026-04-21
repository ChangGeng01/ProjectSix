import XCTest
import BASMemory
@testable import QinaoHost

/// M7.3 — QinaoHost façade over `BASHostCandidatePipeline`.
///
/// The substrate pipeline is exhaustively tested in
/// `BehavioralAISubstrate/Tests/.../BASHostCandidatePipelineTests`;
/// this suite only proves the *façade* behaviour:
///
///   1. The façade preserves the submit → preview → approve arc.
///   2. The façade translates pipeline errors into `HostError`
///      (so host code never has to import the substrate error
///      type, which would leak the BAS namespace).
///   3. The façade's `currentHost()` returns the projection of the
///      active version — the same bytes the pipeline's `project()`
///      returns directly.
final class QinaoHostTests: XCTestCase {

    private let now: @Sendable () -> Date = {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func makeHost() -> (QinaoHost, BASHostCandidatePipeline) {
        let constitution = BASHostConstitution(
            hostID: "host",
            activeVersion: "host.v1")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: now(),
                    changedFields: [],
                    reason: "seed",
                    approvedByPolicy: true)
            ])
        let pipeline = BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: tree,
            clock: now)
        return (QinaoHost(pipeline: pipeline), pipeline)
    }

    private func candidate(id: String = "cand.1") -> BASHostChangeCandidate {
        BASHostChangeCandidate(
            candidateID: id,
            changeType: "goal_spine",
            proposedDelta: ["add: long-run contemplation"],
            confidence: 0.8)
    }

    // MARK: - Happy path

    func testSubmitPreviewApproveArc() async throws {
        let (host, _) = makeHost()
        _ = try await host.submit(candidate())
        _ = try await host.preview(candidateID: "cand.1")
        _ = try await host.approve(candidateID: "cand.1")
    }

    func testFastTrackApproveWithoutExplicitPreview() async throws {
        let (host, _) = makeHost()
        _ = try await host.submit(candidate())
        _ = try await host.approve(candidateID: "cand.1")
    }

    func testRejectRecordsAndForbidsLaterApproval() async throws {
        let (host, _) = makeHost()
        _ = try await host.submit(candidate())
        _ = try await host.reject(
            candidateID: "cand.1",
            reason: "conflicts with existing boundary")
        do {
            _ = try await host.approve(candidateID: "cand.1")
            XCTFail("approve should reject a rejected candidate")
        } catch QinaoHost.HostError.candidateRejected(_, let reason) {
            XCTAssertTrue(reason.hasPrefix("already-"))
        }
    }

    // MARK: - Error translation

    func testDuplicateSubmitSurfacesTypedError() async throws {
        let (host, _) = makeHost()
        _ = try await host.submit(candidate())
        do {
            _ = try await host.submit(candidate())
            XCTFail("expected duplicate error")
        } catch QinaoHost.HostError.candidateRejected(let id, let reason) {
            XCTAssertEqual(id, "cand.1")
            XCTAssertEqual(reason, "duplicate")
        }
    }

    func testPreviewUnknownCandidateSurfacesTypedError() async throws {
        let (host, _) = makeHost()
        do {
            _ = try await host.preview(candidateID: "nonexistent")
            XCTFail("expected unknown error")
        } catch QinaoHost.HostError.candidateRejected(let id, let reason) {
            XCTAssertEqual(id, "nonexistent")
            XCTAssertEqual(reason, "unknown")
        }
    }

    func testRollbackUnknownVersionSurfacesTypedError() async throws {
        let (host, _) = makeHost()
        do {
            _ = try await host.rollback(toVersionID: "host.vX")
            XCTFail("expected unknownVersion error")
        } catch QinaoHost.HostError.unknownVersion(let id) {
            XCTAssertEqual(id, "host.vX")
        }
    }

    func testRollbackFrozenVersionSurfacesTypedError() async throws {
        let (host, _) = makeHost()
        // Advance to host.v2 (approve creates a new version).
        // Freezing only takes effect on *non-active* versions —
        // once we're on v2, v1 is eligible to freeze.
        _ = try await host.submit(candidate())
        _ = try await host.approve(candidateID: "cand.1")
        _ = try await host.freeze(versionID: "host.v1")

        do {
            _ = try await host.rollback(toVersionID: "host.v1")
            XCTFail("expected versionFrozen error")
        } catch QinaoHost.HostError.versionFrozen(let id) {
            XCTAssertEqual(id, "host.v1")
        }
    }

    // MARK: - Projection parity

    /// The façade's `currentHost()` MUST produce the same vault as
    /// the underlying pipeline's `project()`. If they diverge, the
    /// façade is smuggling state — a drift bug we want to catch
    /// at the gate, not after someone writes to the vault.
    func testCurrentHostMatchesPipelineProjection() async throws {
        let (host, pipeline) = makeHost()
        _ = try await host.submit(candidate())
        _ = try await host.approve(candidateID: "cand.1")

        let viaFacade = await host.currentHost()
        let viaPipeline = await pipeline.project()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let facadeBytes = try encoder.encode(viaFacade)
        let pipelineBytes = try encoder.encode(viaPipeline)
        XCTAssertEqual(facadeBytes, pipelineBytes,
            "QinaoHost.currentHost() drifted from pipeline.project()")
    }

    func testFreezeThawAreIdempotent() async throws {
        let (host, _) = makeHost()
        _ = try await host.freeze(versionID: "host.v1")
        _ = try await host.thaw(versionID: "host.v1")
        // After thaw the version is rollback-eligible again.
        _ = try await host.rollback(toVersionID: "host.v1")
    }
}
