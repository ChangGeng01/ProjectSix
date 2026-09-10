import XCTest
import SwiftUI
@testable import QinaoSample
@testable import QinaoLoop
import QinaoMLX   // B — name QinaoMLXModel explicitly in the picker↔model exhaustiveness assertion

/// M228 — behavior coverage for `SampleSession`.
///
/// Tests inject a mock `SampleEndpointBuilder` that records calls
/// + returns a deterministic stub endpoint. No network, no MLX
/// load, no Apple FM availability dependency — pure state-machine
/// assertions on the session's caching + provider routing.
@MainActor
final class QinaoSampleSessionTests: XCTestCase {

    // MARK: - Mocks

    /// Trivial QinaoOrganEndpoint stub that returns a fixed body.
    /// Distinguishable across instances by its `tag` so tests can
    /// assert "the cached endpoint is the same instance" without
    /// relying on QinaoOrganEndpoint conforming to Equatable.
    final class StubEndpoint: QinaoOrganEndpoint, @unchecked Sendable {
        let tag: String
        init(tag: String) { self.tag = tag }

        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            QinaoLoop.OrganResponse(
                body: "stub:\(tag):\(prompt)",
                providerID: "stub.\(tag)",
                traceID: "trace-\(tag)-\(sessionID)")
        }
    }

    /// Test-only recorder for endpoint-builder calls. Each call
    /// appends a record so tests can assert "builder was called N
    /// times for provider X".
    final class BuilderRecorder: @unchecked Sendable {
        struct Call: Sendable {
            let provider: SampleProvider
            let didReceiveProgress: Bool
        }

        private(set) var calls: [Call] = []
        private(set) var stubsHandedOut: [StubEndpoint] = []

        func record(
            provider: SampleProvider,
            didReceiveProgress: Bool
        ) -> StubEndpoint {
            let stub = StubEndpoint(
                tag: "\(provider.rawValue)-call\(calls.count + 1)")
            calls.append(
                .init(
                    provider: provider,
                    didReceiveProgress: didReceiveProgress))
            stubsHandedOut.append(stub)
            return stub
        }
    }

    // MARK: - 1. Cache behaviour

    func testAppleFoundationEndpointIsCachedAcrossCalls() async throws {
        let recorder = BuilderRecorder()
        let session = SampleSession { provider, _ in
            recorder.record(
                provider: provider, didReceiveProgress: false)
        }

        let first = try await session.endpoint(
            for: .appleFoundation)
        let second = try await session.endpoint(
            for: .appleFoundation)

        XCTAssertEqual(
            recorder.calls.count, 1,
            "second call should hit the Apple FM cache, not " +
            "re-invoke the builder")
        XCTAssertTrue(
            (first as AnyObject) === (second as AnyObject),
            "cached endpoint must be the identical instance")
    }

    func testMLXEndpointCachedPerModelIdentity() async throws {
        let recorder = BuilderRecorder()
        let session = SampleSession { provider, _ in
            recorder.record(
                provider: provider, didReceiveProgress: false)
        }

        // Two calls with the SAME provider — should hit cache.
        _ = try await session.endpoint(for: .mlxGemma4E4B)
        _ = try await session.endpoint(for: .mlxGemma4E4B)
        XCTAssertEqual(
            recorder.calls.count, 1,
            "same MLX model should be cached")

        // Different provider — must re-build (different cache key).
        _ = try await session.endpoint(for: .mlxGemma3_4B)
        XCTAssertEqual(
            recorder.calls.count, 2,
            "switching MLX models must invalidate the cache and " +
            "re-build")
        XCTAssertEqual(
            recorder.calls[0].provider, .mlxGemma4E4B)
        XCTAssertEqual(
            recorder.calls[1].provider, .mlxGemma3_4B)
    }

    func testAppleAndMLXEndpointsCachedIndependently() async throws {
        let recorder = BuilderRecorder()
        let session = SampleSession { provider, _ in
            recorder.record(
                provider: provider, didReceiveProgress: false)
        }

        _ = try await session.endpoint(for: .appleFoundation)
        _ = try await session.endpoint(for: .mlxGemma4E4B)
        _ = try await session.endpoint(for: .appleFoundation)
        _ = try await session.endpoint(for: .mlxGemma4E4B)

        XCTAssertEqual(
            recorder.calls.count, 2,
            "Apple FM and MLX caches are separate; second " +
            "round-trip should hit both caches without rebuild")
    }

    // MARK: - 2. Loading-state lifecycle

    func testMLXBuildToggleslsLoadingFlag() async throws {
        let recorder = BuilderRecorder()
        let session = SampleSession { provider, _ in
            // Mid-flight: isLoading must be true.
            return recorder.record(
                provider: provider, didReceiveProgress: false)
        }

        XCTAssertFalse(
            session.isLoading,
            "fresh session must not start in loading state")

        _ = try await session.endpoint(for: .mlxGemma4E4B)

        // Defer block in SampleSession.endpoint(for:) should have
        // reset all three loading flags.
        XCTAssertFalse(session.isLoading)
        XCTAssertEqual(session.loadingMessage, "")
        XCTAssertEqual(session.loadingProgress, 0)
    }

    func testAppleFoundationDoesNotToggleLoadingFlag() async throws {
        let recorder = BuilderRecorder()
        let session = SampleSession { provider, _ in
            recorder.record(
                provider: provider, didReceiveProgress: false)
        }

        _ = try await session.endpoint(for: .appleFoundation)
        XCTAssertFalse(
            session.isLoading,
            "Apple FM path is fast and stays out of the loading " +
            "panel — only MLX downloads toggle isLoading")
    }

    // MARK: - 3. Unwired providers

    func testChatCompletionsThrowsProviderNotWired() async {
        let session = SampleSession { _, _ in
            XCTFail(
                "ChatCompletions must short-circuit before " +
                "invoking the builder")
            return StubEndpoint(tag: "should-not-reach")
        }

        do {
            _ = try await session.endpoint(for: .chatCompletions)
            XCTFail("expected SampleError.providerNotWired")
        } catch SampleError.providerNotWired(let name) {
            XCTAssertEqual(name, SampleProvider.chatCompletions.rawValue)
        } catch {
            XCTFail("expected providerNotWired but got \(error)")
        }
    }

    // MARK: - 4. Builder error propagation

    func testBuilderErrorPropagates() async {
        struct CustomError: Error, Equatable {}
        let session = SampleSession { _, _ in
            throw CustomError()
        }

        do {
            _ = try await session.endpoint(for: .appleFoundation)
            XCTFail("expected CustomError")
        } catch is CustomError {
            // expected
        } catch {
            XCTFail("expected CustomError but got \(error)")
        }
    }

    // MARK: - 5. Provider picker exhaustiveness

    func testEveryProviderCaseHasStableRawValue() {
        // Pinning the picker labels so a future rename in the enum
        // surfaces as a visible test diff (the rawValue strings
        // are visible in the picker UI and in audit logs).
        // M236 retired Gemma 3n picker entries; the MLX list is
        // now Gemma 4 e4b/e2b + Gemma 3 4B (long-context outlier).
        let labels = SampleProvider.allCases.map(\.rawValue)
        XCTAssertEqual(labels, [
            "Apple Foundation Models",
            "Gemma 4 E4B (MLX, 4-bit)",
            "Gemma 4 E2B (MLX, 4-bit)",
            "Gemma 3 4B (MLX, 4-bit)",
            "Llama 3.2 3B (MLX, 4-bit)",
            "Qwen2.5 3B (MLX, 4-bit)",
            "Llama 3.2 1B (MLX, 4-bit)",
            "Qwen2.5 1.5B (MLX, 4-bit)",
            "OpenAI-compatible API (M223)"
        ])
    }

    func testAvailabilityFlagsReflectWiredProviders() {
        XCTAssertTrue(SampleProvider.appleFoundation.isAvailable)
        XCTAssertTrue(SampleProvider.mlxGemma4E4B.isAvailable)
        XCTAssertTrue(SampleProvider.mlxGemma4E2B.isAvailable)
        XCTAssertTrue(SampleProvider.mlxGemma3_4B.isAvailable)
        XCTAssertTrue(SampleProvider.mlxLlama3_2_3B.isAvailable)
        XCTAssertTrue(SampleProvider.mlxQwen2_5_3B.isAvailable)
        XCTAssertTrue(SampleProvider.mlxLlama3_2_1B.isAvailable)
        XCTAssertTrue(SampleProvider.mlxQwen2_5_1_5B.isAvailable)
        XCTAssertFalse(
            SampleProvider.chatCompletions.isAvailable,
            "ChatCompletions remains a placeholder until M223")
    }

    func testMLXModelMappingIsExhaustive() {
        XCTAssertEqual(
            SampleProvider.mlxGemma4E4B.mlxModel, .gemma4E4B)
        XCTAssertEqual(
            SampleProvider.mlxGemma4E2B.mlxModel, .gemma4E2B)
        XCTAssertEqual(
            SampleProvider.mlxGemma3_4B.mlxModel, .gemma3_4B)
        XCTAssertEqual(
            SampleProvider.mlxLlama3_2_3B.mlxModel, .llama3_2_3B)
        XCTAssertEqual(
            SampleProvider.mlxQwen2_5_3B.mlxModel, .qwen2_5_3B)
        XCTAssertEqual(
            SampleProvider.mlxLlama3_2_1B.mlxModel, .llama3_2_1B)
        XCTAssertEqual(
            SampleProvider.mlxQwen2_5_1_5B.mlxModel, .qwen2_5_1_5B)
        XCTAssertNil(SampleProvider.appleFoundation.mlxModel)
        XCTAssertNil(SampleProvider.chatCompletions.mlxModel)
        // The picker→model mapping is injective AND total over QinaoMLXModel (every model is reachable).
        let mapped = SampleProvider.allCases.compactMap(\.mlxModel)
        XCTAssertEqual(Set(mapped).count, mapped.count, "MLX picker→model mapping must be injective")
        XCTAssertEqual(Set(mapped), Set(QinaoMLXModel.allCases), "every QinaoMLXModel must have a picker case")
    }
}
