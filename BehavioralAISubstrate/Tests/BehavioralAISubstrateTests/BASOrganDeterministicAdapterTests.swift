import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan

/// Tests for the deterministic in-memory organ adapter.
///
/// The adapter is "deterministic" in a strict sense: given the same
/// `(providerID, role, preset, instruction, context)` it must
/// produce the same digest and therefore the same body. These tests
/// pin that contract so every downstream test in the substrate can
/// rely on it.
final class BASOrganDeterministicAdapterTests: XCTestCase {

    // MARK: - Digest determinism

    func testDigestIsStableForSameRequest() {
        let request = Self.makeRequest(instruction: "hello world")
        let a = BASOrganDeterministicAdapter.digest(
            for: request, providerID: "bas.deterministic.v1")
        let b = BASOrganDeterministicAdapter.digest(
            for: request, providerID: "bas.deterministic.v1")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64) // SHA-256 hex
    }

    func testDigestDiffersForDifferentInstruction() {
        let a = BASOrganDeterministicAdapter.digest(
            for: Self.makeRequest(instruction: "alpha"),
            providerID: "bas.deterministic.v1")
        let b = BASOrganDeterministicAdapter.digest(
            for: Self.makeRequest(instruction: "beta"),
            providerID: "bas.deterministic.v1")
        XCTAssertNotEqual(a, b)
    }

    func testDigestDiffersForDifferentRole() {
        let scout = Self.makeRequest(
            instruction: "same", role: .scout, preset: .scout)
        let core = Self.makeRequest(
            instruction: "same", role: .core, preset: .core)
        let a = BASOrganDeterministicAdapter.digest(
            for: scout, providerID: "p")
        let b = BASOrganDeterministicAdapter.digest(
            for: core, providerID: "p")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - draft()

    func testDraftReturnsDeterministicBody() async throws {
        let adapter = BASOrganDeterministicAdapter()
        let request = Self.makeRequest(instruction: "one ping only")

        let first = try await adapter.draft(request)
        let other = BASOrganDeterministicAdapter()
        let second = try await other.draft(request)

        // Trace is digest (pure); bodies differ only in callIndex.
        XCTAssertEqual(first.traceID, second.traceID)
        XCTAssertTrue(first.body.contains("one ping only"))
        XCTAssertEqual(first.role, .scout)
        XCTAssertEqual(first.providerID, "bas.deterministic.v1")
    }

    func testDraftRejectsUnsupportedRole() async {
        let adapter = BASOrganDeterministicAdapter(
            supportedRoles: [.core])
        let request = Self.makeRequest(
            instruction: "x", role: .scout, preset: .scout)
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let role) {
            XCTAssertEqual(role, .scout)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDraftRejectsExpiredDeadline() async {
        let past = Date(timeIntervalSinceNow: -10)
        let adapter = BASOrganDeterministicAdapter()
        let request = BASOrganRequest(
            requestID: "r1",
            role: .scout,
            preset: .scout,
            instruction: "late",
            deadline: past)
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected deadlineExpired")
        } catch BASOrganError.deadlineExpired {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDraftRejectsOverlongInput() async {
        let adapter = BASOrganDeterministicAdapter(
            maxInputTokens: 4) // ~16 chars
        let request = Self.makeRequest(
            instruction: String(repeating: "x", count: 200))
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected inputTooLong")
        } catch BASOrganError.inputTooLong(let limit, let actual) {
            XCTAssertEqual(limit, 4)
            XCTAssertGreaterThan(actual, limit)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCallCountIncrementsPerDraft() async throws {
        let adapter = BASOrganDeterministicAdapter()
        let request = Self.makeRequest(instruction: "tick")
        _ = try await adapter.draft(request)
        _ = try await adapter.draft(request)
        _ = try await adapter.draft(request)
        let calls = await adapter.calls()
        XCTAssertEqual(calls, 3)
    }

    // MARK: - capacity

    func testCapacityIsUnlimited() async {
        let adapter = BASOrganDeterministicAdapter()
        let c = await adapter.currentCapacity()
        XCTAssertFalse(c.underPressure)
        XCTAssertEqual(c.availableInputTokens, .max)
    }

    // MARK: - Token estimation

    func testTokenEstimateRoundsUp() {
        // total chars = 5; (5+3)/4 = 2
        let e = BASOrganDeterministicAdapter.estimateTokens(
            from: ["hello"])
        XCTAssertEqual(e, 2)
    }

    // MARK: - Fixture

    static func makeRequest(
        instruction: String,
        role: BASOrganRole = .scout,
        preset: BASOrganPreset = .scout
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "r-\(instruction.hashValue)",
            role: role,
            preset: preset,
            instruction: instruction,
            context: ["ctx-a", "ctx-b"])
    }
}
