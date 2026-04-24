import XCTest
@testable import BASOrgan
import BASRuntimeCore

/// M150 — pin the L2 Scout/Core differentiation contract at the
/// preset + adapter seam.
///
/// Self-critique #8 (L2 Scout/Core 真实双模型) — Swift-only 70%
/// closed. The last 30% (actually differentiated model outputs
/// from TWO SEPARATE MODELS) needs real CoreML / MLX infra. But
/// the STRUCTURE — that Scout and Core carry distinguishable
/// preset parameters, that adapters can opt into supporting only
/// one role, that the deterministic adapter round-trips both
/// without collision — is Swift-only and fully testable.
///
/// Pins:
///   1. Scout preset has cold (low) temperature + short output
///      + deterministic preference.
///   2. Core preset has warm (mid) temperature + long output +
///      non-deterministic by design.
///   3. Preset raw values differ byte-by-byte (scout.name !=
///      core.name; temperatures differ; maxOutputTokens
///      differ).
///   4. Adapter with `supportedRoles = [.scout]` rejects core
///      requests with `.unsupportedRole(.core)` error.
///   5. Same instruction + different role → different drafts
///      (deterministic adapter uses role in its digest).
final class BASOrganScoutCoreDifferentiationTests: XCTestCase {

    // MARK: - 1. Scout preset shape

    func testScoutPresetHasColdShortDeterministicShape() {
        let s = BASOrganPreset.scout
        XCTAssertEqual(s.name, "bas.scout.v1")
        XCTAssertLessThan(
            s.temperature, 0.3,
            "scout must be cold-sample (< 0.3)")
        XCTAssertLessThan(
            s.maxOutputTokens, 500,
            "scout must be short-output")
        XCTAssertTrue(
            s.deterministic,
            "scout prefers deterministic sampling")
    }

    // MARK: - 2. Core preset shape

    func testCorePresetHasWarmLongNonDeterministicShape() {
        let c = BASOrganPreset.core
        XCTAssertEqual(c.name, "bas.core.v1")
        XCTAssertGreaterThan(
            c.temperature, 0.3,
            "core must be warm-sample (> 0.3)")
        XCTAssertGreaterThan(
            c.maxOutputTokens, 500,
            "core must be long-output")
        XCTAssertFalse(
            c.deterministic,
            "core non-deterministic by design")
    }

    // MARK: - 3. Byte-level differentiation

    func testScoutAndCoreAreByteDistinguishable() {
        let s = BASOrganPreset.scout
        let c = BASOrganPreset.core
        XCTAssertNotEqual(s.name, c.name)
        XCTAssertNotEqual(s.temperature, c.temperature)
        XCTAssertNotEqual(s.maxOutputTokens, c.maxOutputTokens)
        XCTAssertNotEqual(s.deterministic, c.deterministic)
        // Codable round-trips differently too.
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        let sData = try? e.encode(s)
        let cData = try? e.encode(c)
        XCTAssertNotEqual(sData, cData)
    }

    // MARK: - 4. Role-restricted adapter rejects unsupported

    func testAdapterRestrictedToScoutRejectsCoreRequest()
        async throws {
        let adapter = BASOrganDeterministicAdapter(
            providerID: "bas.test.scout-only",
            supportedRoles: [.scout])
        let request = BASOrganRequest(
            requestID: "r.core",
            role: .core,
            preset: .core,
            instruction: "please analyze",
            context: [])
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected unsupportedRole error")
        } catch BASOrganError.unsupportedRole(let role) {
            XCTAssertEqual(role, .core)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 5. Role is part of digest → different drafts

    /// Same instruction + context, different role → adapter
    /// produces different draft bodies because role is part of
    /// the digest input. This proves Scout and Core are
    /// observably different even when backed by the same
    /// deterministic adapter.
    func testSameInstructionDifferentRoleProducesDifferentDrafts()
        async throws {
        let adapter = BASOrganDeterministicAdapter(
            providerID: "bas.test.m150",
            supportedRoles: [.scout, .core])
        let scoutReq = BASOrganRequest(
            requestID: "r.same",
            role: .scout,
            preset: .scout,
            instruction: "rephrase: Hello world",
            context: [])
        let coreReq = BASOrganRequest(
            requestID: "r.same",
            role: .core,
            preset: .core,
            instruction: "rephrase: Hello world",
            context: [])
        let scoutDraft = try await adapter.draft(scoutReq)
        let coreDraft = try await adapter.draft(coreReq)

        XCTAssertNotEqual(
            scoutDraft.body, coreDraft.body,
            "role in digest → differentiable outputs")
        XCTAssertNotEqual(
            scoutDraft.traceID, coreDraft.traceID,
            "traceID reflects the role differentiation")
        XCTAssertEqual(scoutDraft.role, .scout)
        XCTAssertEqual(coreDraft.role, .core)
    }
}
