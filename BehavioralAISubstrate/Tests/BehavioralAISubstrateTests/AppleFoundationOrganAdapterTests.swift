import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan
@testable import BASAppleAdapters

/// Tests the `AppleFoundationOrganAdapter`.
///
/// ## What this suite can and cannot prove
///
/// `swift test` on the M1 CI is macOS 14 (CryptoKit-only). That
/// means the availability-guarded FoundationModels path (iOS 26+ /
/// macOS 26+) *cannot run here*. We test the two things that can
/// always be tested:
///
/// 1. **Descriptor & role contract.** The adapter advertises the
///    right descriptor and rejects unsupported roles before touching
///    FoundationModels.
/// 2. **Stub fallthrough.** On macOS 14, `draft()` throws
///    `providerUnavailable` — a registered consumer can then fall
///    back to another adapter (e.g. `BASOrganDeterministicAdapter`).
/// 3. **Pure prompt helpers.** `systemInstructions(for:)` and
///    `prompt(for:)` are pure static functions; exercising them here
///    pins the scaffolding regardless of OS version.
final class AppleFoundationOrganAdapterTests: XCTestCase {

    // MARK: - Descriptor

    func testDefaultDescriptorMatchesContract() async {
        let adapter = AppleFoundationOrganAdapter()
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "apple.foundation-models.v1")
        XCTAssertTrue(adapter.descriptor.runsOnDevice)
        XCTAssertTrue(
            adapter.descriptor.supportedRoles.contains(.scout))
        XCTAssertTrue(
            adapter.descriptor.supportedRoles.contains(.core))
    }

    // MARK: - Role enforcement (runs even when FM unavailable,
    //         because role check happens before the dispatch).

    func testRejectsUnsupportedRole() async {
        let adapter = AppleFoundationOrganAdapter(
            supportedRoles: [.core]) // scout disallowed
        let request = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "hi")
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let r) {
            XCTAssertEqual(r, .scout)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Stub-path behaviour

    /// On macOS 14 (the substrate test environment) the adapter must
    /// surface `providerUnavailable` so the registry can fall through
    /// to another provider. We don't assert the *exact reason string*
    /// because it varies between the two `#if` branches; we just
    /// assert the case.
    func testProviderUnavailableOnUnsupportedOS() async throws {
        // Only meaningful on the test-environment OS. If someone
        // eventually runs the suite on a machine that does satisfy
        // the FoundationModels availability guard, skip — the path
        // exercised there is a real model call, not a stub.
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            throw XCTSkip(
                "FoundationModels available; stub-path not exercised")
        }
        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "ping")
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected providerUnavailable")
        } catch BASOrganError.providerUnavailable {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCapacityUnderPressureWhenUnavailable() async {
        if #available(iOS 26, macOS 26, visionOS 26, *) { return }
        let adapter = AppleFoundationOrganAdapter()
        let cap = await adapter.currentCapacity()
        XCTAssertTrue(cap.underPressure)
        XCTAssertEqual(cap.availableInputTokens, 0)
        XCTAssertEqual(cap.availableOutputTokens, 0)
        XCTAssertFalse(cap.reasonCodes.isEmpty)
    }

    // MARK: - Registry fallthrough

    /// Wires the real concern: if Apple FM is unavailable, the
    /// registry must produce a drafting path via another adapter
    /// instead of failing the session.
    func testRegistryFallsThroughToDeterministicAdapter() async throws {
        if #available(iOS 26, macOS 26, visionOS 26, *) { return }

        let registry = BASOrganRegistry()
        await registry.register(AppleFoundationOrganAdapter())
        await registry.register(BASOrganDeterministicAdapter())

        // Registry picks most-recent on-device adapter; both are
        // on-device. The deterministic adapter is registered last
        // so it wins and can *actually* produce a draft.
        let chosen = try await registry.adapter(for: .scout)
        let draft = try await chosen.draft(BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "hello"))
        XCTAssertEqual(draft.providerID, "bas.deterministic.v1")
        XCTAssertTrue(draft.body.contains("hello"))
    }

    // MARK: - Pure prompt helpers

    func testSystemInstructionsDifferPerRole() {
        let scout = AppleFoundationOrganAdapter.systemInstructions(
            for: BASOrganRequest(
                requestID: "r",
                role: .scout,
                preset: .scout,
                instruction: "x"))
        let core = AppleFoundationOrganAdapter.systemInstructions(
            for: BASOrganRequest(
                requestID: "r",
                role: .core,
                preset: .core,
                instruction: "x"))
        XCTAssertNotEqual(scout, core)
        XCTAssertTrue(scout.lowercased().contains("scout"))
        XCTAssertTrue(core.lowercased().contains("core"))
    }

    func testPromptIncludesContextWhenPresent() {
        let req = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "answer this",
            context: ["fact-one", "fact-two"])
        let prompt = AppleFoundationOrganAdapter.prompt(for: req)
        XCTAssertTrue(prompt.contains("Instruction:"))
        XCTAssertTrue(prompt.contains("answer this"))
        XCTAssertTrue(prompt.contains("Context:"))
        XCTAssertTrue(prompt.contains("[1] fact-one"))
        XCTAssertTrue(prompt.contains("[2] fact-two"))
    }

    func testPromptOmitsContextHeaderWhenEmpty() {
        let req = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "bare")
        let prompt = AppleFoundationOrganAdapter.prompt(for: req)
        XCTAssertTrue(prompt.contains("bare"))
        XCTAssertFalse(prompt.contains("Context:"))
    }
}
