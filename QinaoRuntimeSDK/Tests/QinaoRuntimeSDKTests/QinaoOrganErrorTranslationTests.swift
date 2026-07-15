import XCTest
import BASRuntimeCore
import BASOrgan
@testable import QinaoLoop

/// M181 — pin the `BASOrgan*Error → QinaoLoop.LoopError`
/// translation matrix.
///
/// ## Why this exists
///
/// `BASOrganRegistryEndpoint.callAdapter(...)` translates 5
/// `BASOrganError` cases + 2 `BASOrganRegistry.RegistryError` cases
/// + 1 "no-endpoint-configured" path into stable
/// `LoopError.organUnavailable(reason:)` codes. Hosts read those
/// reason strings to build typed UI / telemetry tags. If a future
/// refactor changes the reason-code grammar (e.g. drops the
/// `provider-unavailable:` prefix or merges two cases), every host
/// downstream silently mis-tags. This suite pins the contract: each
/// originating error produces exactly one stable, documented reason
/// code.
///
/// ## Coverage
///
/// 8 paths, each with a deterministic adapter that throws the
/// expected error. No real LLM, no env gate — runs every CI pass.
final class QinaoOrganErrorTranslationTests: XCTestCase {

    /// Mock adapter that throws a configured `BASOrganError` on
    /// every `draft(_:)` call. `currentCapacity()` returns
    /// `.unlimited` so registry resolution doesn't filter it out.
    private actor ThrowingAdapter: BASOrganAdapter {
        nonisolated let descriptor: BASOrganDescriptor
        private let errorToThrow: BASOrganError

        init(_ error: BASOrganError) {
            self.descriptor = BASOrganDescriptor(
                providerID: "test.throwing.v1",
                providerName: "Test Throwing Adapter",
                supportsStreaming: false,
                maxInputTokens: 4096,
                maxOutputTokens: 4096,
                runsOnDevice: true,
                supportedRoles: [.scout, .core])
            self.errorToThrow = error
        }

        func draft(
            _ request: BASOrganRequest
        ) async throws -> BASOrganDraft {
            throw errorToThrow
        }

        func currentCapacity() async -> BASOrganCapacity {
            .unlimited
        }
    }

    // MARK: - Helpers

    private func endpointThrowingAdapterError(
        _ error: BASOrganError
    ) -> BASOrganRegistryEndpoint {
        let mock = ThrowingAdapter(error)
        return BASOrganRegistryEndpoint(
            adapterOverride: { _ in mock })
    }

    private func callAndExpectLoopError(
        endpoint: BASOrganRegistryEndpoint,
        expectedReason: String,
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            _ = try await endpoint.produceBody(
                prompt: "ping",
                context: [],
                role: .scout,
                sessionID: "s")
            XCTFail(
                "expected throw with reason '\(expectedReason)'",
                file: file, line: line)
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(
                reason, expectedReason,
                "reason-code grammar drifted",
                file: file, line: line)
        } catch {
            XCTFail(
                "unexpected error: \(error)",
                file: file, line: line)
        }
    }

    // MARK: - 5 BASOrganError cases

    func testUnsupportedRoleTranslates() async {
        let endpoint = endpointThrowingAdapterError(
            .unsupportedRole(.scout))
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "unsupported-role:scout")
    }

    func testInputTooLongTranslates() async {
        let endpoint = endpointThrowingAdapterError(
            .inputTooLong(limit: 4096, actual: 5000))
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "input-too-long:5000/4096")
    }

    func testDeadlineExpiredTranslates() async {
        let endpoint = endpointThrowingAdapterError(
            .deadlineExpired)
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "deadline-expired")
    }

    func testProviderUnavailableTranslates() async {
        let endpoint = endpointThrowingAdapterError(
            .providerUnavailable(reason: "model-not-loaded"))
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "provider-unavailable:model-not-loaded")
    }

    func testPressureRefusalTranslates() async {
        let endpoint = endpointThrowingAdapterError(
            .pressureRefusal(reason: "thermal-emergency"))
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "pressure-refusal:thermal-emergency")
    }

    // MARK: - 2 BASOrganRegistry.RegistryError cases

    func testNoAdapterForRoleTranslates() async {
        // Empty registry — adapter(for:) throws .noAdapterForRole.
        let endpoint = BASOrganRegistryEndpoint(
            registry: BASOrganRegistry())
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "no-adapter-for-role:scout")
    }

    /// The registry's `unknownProvider(id:)` translation, on BOTH the buffered
    /// and streaming paths.
    ///
    /// Was an unconditional XCTSkip with zero assertions whose body conceded
    /// "code-presence check is implicit: this file imports the module" —
    /// importing a module is not a test. Its stated premise (unknown-provider is
    /// unreachable via `adapter(for:)`) is true, but the conclusion drawn from it
    /// was false: the case is reachable through the very hook the 7 sibling
    /// tests already use, because `adapterOverride` is declared `throws`. So the
    /// reason-code grammar for unknown-provider was unpinned on both paths while
    /// the file's docstring claimed "8 paths ... runs every CI pass" — 7 ran.
    func testUnknownProviderTranslates() async {
        let endpoint = BASOrganRegistryEndpoint(
            registry: BASOrganRegistry(),
            adapterOverride: { _ in
                throw BASOrganRegistry.RegistryError
                    .unknownProvider(id: "ghost.v1")
            })
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "unknown-provider:ghost.v1")
    }

    /// The streaming twin of the above — a separate catch site
    /// (BASOrganRegistryEndpoint.swift:163) that must produce the identical
    /// reason code.
    func testUnknownProviderTranslatesOnStreamingPath() async {
        let endpoint = BASOrganRegistryEndpoint(
            registry: BASOrganRegistry(),
            adapterOverride: { _ in
                throw BASOrganRegistry.RegistryError
                    .unknownProvider(id: "ghost.v1")
            })
        do {
            let stream = try await endpoint.streamBody(
                prompt: "ping", context: [], role: .scout, sessionID: "s")
            for try await _ in stream {}
            XCTFail("expected organUnavailable on the streaming path")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unknown-provider:ghost.v1")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 1 "no-endpoint-configured" path

    func testNoEndpointConfiguredTranslates() async {
        // Both `registry` and `adapterOverride` nil → endpoint
        // raises before touching any adapter.
        let endpoint = BASOrganRegistryEndpoint()
        await callAndExpectLoopError(
            endpoint: endpoint,
            expectedReason: "no-endpoint-configured")
    }
}
