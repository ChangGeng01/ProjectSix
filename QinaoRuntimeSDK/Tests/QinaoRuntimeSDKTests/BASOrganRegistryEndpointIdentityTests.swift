import Foundation
import XCTest
import BASOrgan
@testable import QinaoLoop

final class BASOrganRegistryEndpointIdentityTests: XCTestCase {
    private actor InvocationSpy: BASStreamingOrganAdapter {
        nonisolated let descriptor: BASOrganDescriptor
        private var eagerRequests: [BASOrganRequest] = []
        private var streamRequests: [BASOrganRequest] = []
        private let cancelRequests: Bool

        init(
            providerID: String,
            roles: Set<BASOrganRole> = [.scout, .core],
            certificationTier: BASCertificationTier? = nil,
            cancelRequests: Bool = false
        ) {
            self.cancelRequests = cancelRequests
            descriptor = BASOrganDescriptor(
                providerID: providerID,
                providerName: "Invocation Spy \(providerID)",
                supportsStreaming: true,
                maxInputTokens: 4096,
                maxOutputTokens: 4096,
                runsOnDevice: true,
                supportedRoles: roles,
                providerKind: .deterministic,
                certificationTier: certificationTier)
        }

        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            eagerRequests.append(request)
            if cancelRequests { throw CancellationError() }
            return BASOrganDraft(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                body: "\(descriptor.providerID)-eager",
                inputTokensEstimated: 1,
                outputTokensEstimated: 1,
                producedAt: Date(timeIntervalSince1970: 1_700_000_000),
                traceID: "\(descriptor.providerID)-eager-trace")
        }

        nonisolated func streamDraft(
            _ request: BASOrganRequest
        ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
            AsyncThrowingStream { continuation in
                Task {
                    let shouldCancel = await self.recordStream(request)
                    if shouldCancel {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    continuation.yield(BASOrganDraftChunk(
                        requestID: request.requestID,
                        providerID: descriptor.providerID,
                        role: request.role,
                        bodyDelta: "\(descriptor.providerID)-stream",
                        cumulativeBody: "\(descriptor.providerID)-stream",
                        producedAt: Date(timeIntervalSince1970: 1_700_000_000)))
                    continuation.finish()
                }
            }
        }

        func currentCapacity() async -> BASOrganCapacity { .unlimited }

        private func recordStream(_ request: BASOrganRequest) -> Bool {
            streamRequests.append(request)
            return cancelRequests
        }

        func requests() -> (eager: [BASOrganRequest], stream: [BASOrganRequest]) {
            (eagerRequests, streamRequests)
        }
    }

    private struct EagerOnlyAdapter: BASOrganAdapter {
        let spy: InvocationSpy
        var descriptor: BASOrganDescriptor { spy.descriptor }

        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            try await spy.draft(request)
        }

        func currentCapacity() async -> BASOrganCapacity { .unlimited }
    }

    func testPublicFactoryPreservesEagerAndStreamingIdentity() async throws {
        let spy = InvocationSpy(providerID: "host.selected")
        let endpoint = await QinaoLoop.makeOrganEndpoint(
            selectedProviderID: "host.selected", adapter: spy)
        let response = try await endpoint.produceBody(
            prompt: "input", context: ["context"], role: .scout, sessionID: "s")
        XCTAssertEqual(response.providerID, "host.selected")
        XCTAssertEqual(response.body, "host.selected-eager")
        XCTAssertEqual(response.traceID, "host.selected-eager-trace")

        let streaming = try XCTUnwrap(endpoint as? any QinaoStreamingOrganEndpoint)
        var chunks: [QinaoLoop.OrganResponseChunk] = []
        for try await chunk in streaming.streamBody(
            prompt: "stream", context: ["stream-context"], role: .core, sessionID: "s")
        {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks.map(\.providerID), ["host.selected"])
        XCTAssertEqual(chunks.map(\.cumulativeBody), ["host.selected-stream"])

        let calls = await spy.requests()
        XCTAssertEqual(calls.eager.count, 1)
        XCTAssertEqual(calls.stream.count, 1)
        XCTAssertEqual(calls.eager[0].instruction, "input")
        XCTAssertEqual(calls.eager[0].context, ["context"])
        XCTAssertEqual(calls.eager[0].preset, .scout)
        XCTAssertEqual(calls.stream[0].preset, .core)
    }

    func testPublicFactoryUnknownIdentityNeverInvokesAdapter() async throws {
        let spy = InvocationSpy(providerID: "host.selected")
        let endpoint = await QinaoLoop.makeOrganEndpoint(
            selectedProviderID: "missing", adapter: spy)

        do {
            _ = try await endpoint.produceBody(
                prompt: "eager", context: [], role: .core, sessionID: "s")
            XCTFail("missing identity must refuse eager invocation")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unknown-provider:missing")
        }

        let streaming = try XCTUnwrap(endpoint as? any QinaoStreamingOrganEndpoint)
        do {
            for try await _ in streaming.streamBody(
                prompt: "stream", context: [], role: .core, sessionID: "s") {}
            XCTFail("missing identity must refuse streaming invocation")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unknown-provider:missing")
        }

        let calls = await spy.requests()
        XCTAssertTrue(calls.eager.isEmpty)
        XCTAssertTrue(calls.stream.isEmpty)
    }

    func testPublicFactoryUnsupportedRoleRefusesBeforeCall() async throws {
        let spy = InvocationSpy(providerID: "host.selected", roles: [.scout])
        let endpoint = await QinaoLoop.makeOrganEndpoint(
            selectedProviderID: "host.selected", adapter: spy)

        do {
            _ = try await endpoint.produceBody(
                prompt: "eager", context: [], role: .core, sessionID: "s")
            XCTFail("unsupported role must refuse")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unsupported-role:core")
        }

        let calls = await spy.requests()
        XCTAssertTrue(calls.eager.isEmpty)
        XCTAssertTrue(calls.stream.isEmpty)
    }

    func testPublicFactoryPreservesGreedyAndRoutedPresets() async throws {
        let spy = InvocationSpy(providerID: "host.selected")
        let endpoint = await QinaoLoop.makeOrganEndpoint(
            selectedProviderID: "host.selected",
            adapter: spy,
            preset: .greedyDeterministic)

        _ = try await endpoint.produceBody(
            prompt: "greedy", context: ["greedy-context"], role: .core, sessionID: "s")
        let routed = try XCTUnwrap(endpoint as? any QinaoBudgetAwareOrganEndpoint)
        _ = try await routed.produceBody(
            prompt: "routed",
            context: ["routed-context"],
            sessionID: "s",
            decision: .init(
                role: .core,
                temperature: 0.25,
                maxOutputTokens: 77,
                deterministic: false,
                reasonCodes: ["test-route"]))

        let calls = await spy.requests()
        XCTAssertEqual(calls.eager.count, 2)
        XCTAssertEqual(calls.eager[0].instruction, "greedy")
        XCTAssertEqual(calls.eager[0].context, ["greedy-context"])
        XCTAssertEqual(calls.eager[0].preset, .greedyDeterministic)
        XCTAssertEqual(calls.eager[1].instruction, "routed")
        XCTAssertEqual(calls.eager[1].context, ["routed-context"])
        XCTAssertEqual(calls.eager[1].preset.name, "qinao.m77.core.routed")
        XCTAssertEqual(calls.eager[1].preset.temperature, 0.25)
        XCTAssertEqual(calls.eager[1].preset.maxOutputTokens, 77)
        XCTAssertFalse(calls.eager[1].preset.deterministic)
    }

    func testPublicFactoryPreservesCancellationError() async throws {
        let spy = InvocationSpy(providerID: "host.selected", cancelRequests: true)
        let endpoint = await QinaoLoop.makeOrganEndpoint(
            selectedProviderID: "host.selected", adapter: spy)

        do {
            _ = try await endpoint.produceBody(
                prompt: "eager", context: [], role: .core, sessionID: "s")
            XCTFail("cancellation must propagate from eager invocation")
        } catch is CancellationError {
        }

        let streaming = try XCTUnwrap(endpoint as? any QinaoStreamingOrganEndpoint)
        var chunks: [QinaoLoop.OrganResponseChunk] = []
        do {
            for try await chunk in streaming.streamBody(
                prompt: "stream", context: [], role: .core, sessionID: "s")
            {
                chunks.append(chunk)
            }
            XCTFail("cancellation must propagate from streaming invocation")
        } catch is CancellationError {
        }

        XCTAssertTrue(chunks.isEmpty)
        let calls = await spy.requests()
        XCTAssertEqual(calls.eager.count, 1)
        XCTAssertEqual(calls.stream.count, 1)
    }

    func testPublicFactoryDoesNotInventStreamingSupport() async throws {
        let spy = InvocationSpy(providerID: "host.selected")
        let endpoint = await QinaoLoop.makeOrganEndpoint(
            selectedProviderID: "host.selected",
            adapter: EagerOnlyAdapter(spy: spy))
        let streaming = try XCTUnwrap(endpoint as? any QinaoStreamingOrganEndpoint)

        do {
            for try await _ in streaming.streamBody(
                prompt: "stream", context: [], role: .core, sessionID: "s") {}
            XCTFail("eager-only adapter must not synthesize streaming")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "endpoint-not-streaming")
        }

        let calls = await spy.requests()
        XCTAssertTrue(calls.eager.isEmpty)
        XCTAssertTrue(calls.stream.isEmpty)
    }

    func testBoundProviderHandlesLegacyRoutedAndStreamingInBothOrders()
        async throws
    {
        for reverse in [false, true] {
            let registry = BASOrganRegistry()
            let a = InvocationSpy(providerID: "provider-a")
            let b = InvocationSpy(providerID: "provider-b")
            let adapters: [any BASOrganAdapter] = reverse ? [b, a] : [a, b]
            for adapter in adapters { await registry.register(adapter) }
            let endpoint = BASOrganRegistryEndpoint(
                registry: registry,
                providerID: "provider-a",
                nextRequestID: { "request-fixed" })

            let legacy = try await endpoint.produceBody(
                prompt: "legacy",
                context: ["legacy-context"],
                role: .scout,
                sessionID: "session")
            XCTAssertEqual(legacy.providerID, "provider-a")
            XCTAssertEqual(legacy.body, "provider-a-eager")

            let routed = try await endpoint.produceBody(
                prompt: "routed",
                context: ["routed-context"],
                sessionID: "session",
                decision: .init(
                    role: .core,
                    temperature: 0.25,
                    maxOutputTokens: 77,
                    deterministic: false,
                    reasonCodes: ["test-route"]))
            XCTAssertEqual(routed.providerID, "provider-a")
            XCTAssertEqual(routed.body, "provider-a-eager")

            var chunks: [QinaoLoop.OrganResponseChunk] = []
            for try await chunk in endpoint.streamBody(
                prompt: "stream",
                context: ["stream-context"],
                role: .core,
                sessionID: "session")
            {
                chunks.append(chunk)
            }
            XCTAssertEqual(chunks.map(\.providerID), ["provider-a"])
            XCTAssertEqual(chunks.map(\.cumulativeBody), ["provider-a-stream"])

            let aRequests = await a.requests()
            let bRequests = await b.requests()
            XCTAssertEqual(aRequests.eager.count, 2)
            XCTAssertEqual(aRequests.stream.count, 1)
            XCTAssertTrue(bRequests.eager.isEmpty)
            XCTAssertTrue(bRequests.stream.isEmpty)
            XCTAssertEqual(aRequests.eager[0].requestID, "request-fixed")
            XCTAssertEqual(aRequests.eager[0].role, .scout)
            XCTAssertEqual(aRequests.eager[0].preset, .scout)
            XCTAssertEqual(aRequests.eager[0].instruction, "legacy")
            XCTAssertEqual(aRequests.eager[0].context, ["legacy-context"])
            XCTAssertEqual(aRequests.eager[1].requestID, "request-fixed")
            XCTAssertEqual(aRequests.eager[1].role, .core)
            XCTAssertEqual(aRequests.eager[1].preset.name, "qinao.m77.core.routed")
            XCTAssertEqual(aRequests.eager[1].preset.temperature, 0.25)
            XCTAssertEqual(aRequests.eager[1].preset.maxOutputTokens, 77)
            XCTAssertFalse(aRequests.eager[1].preset.deterministic)
            XCTAssertEqual(aRequests.stream[0].requestID, "request-fixed")
            XCTAssertEqual(aRequests.stream[0].role, .core)
            XCTAssertEqual(aRequests.stream[0].preset, .core)
            XCTAssertEqual(aRequests.stream[0].instruction, "stream")
            XCTAssertEqual(aRequests.stream[0].context, ["stream-context"])
        }
    }

    func testLaterCertifiedProviderRegistrationDoesNotChangeBinding()
        async throws
    {
        let registry = BASOrganRegistry()
        let a = InvocationSpy(providerID: "provider-a")
        let b = InvocationSpy(
            providerID: "provider-b",
            certificationTier: .certified)
        await registry.register(a)
        let endpoint = BASOrganRegistryEndpoint(
            registry: registry,
            providerID: "provider-a",
            nextRequestID: { "request" })
        await registry.register(b)

        let response = try await endpoint.produceBody(
            prompt: "p", context: [], role: .core, sessionID: "s")
        XCTAssertEqual(response.providerID, "provider-a")
        let aRequests = await a.requests()
        let bRequests = await b.requests()
        XCTAssertEqual(aRequests.eager.count, 1)
        XCTAssertTrue(bRequests.eager.isEmpty)
    }

    func testMissingBoundProviderNeverFallsBackToRegisteredProvider()
        async throws
    {
        let registry = BASOrganRegistry()
        let a = InvocationSpy(providerID: "provider-a")
        let b = InvocationSpy(providerID: "provider-b")
        await registry.register(a)
        await registry.register(b)
        let endpoint = BASOrganRegistryEndpoint(
            registry: registry,
            providerID: "provider-a")
        try await registry.unregister(providerID: "provider-a")

        do {
            _ = try await endpoint.produceBody(
                prompt: "p", context: [], role: .core, sessionID: "s")
            XCTFail("missing A must not invoke B")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unknown-provider:provider-a")
        }
        do {
            for try await _ in endpoint.streamBody(
                prompt: "p", context: [], role: .core, sessionID: "s") {}
            XCTFail("missing A must not stream from B")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unknown-provider:provider-a")
        }
        let aRequests = await a.requests()
        let bRequests = await b.requests()
        XCTAssertTrue(aRequests.eager.isEmpty)
        XCTAssertTrue(aRequests.stream.isEmpty)
        XCTAssertTrue(bRequests.eager.isEmpty)
        XCTAssertTrue(bRequests.stream.isEmpty)
    }

    func testUnsupportedBoundProviderRoleRefusesBeforeInvocation()
        async throws
    {
        let registry = BASOrganRegistry()
        let a = InvocationSpy(providerID: "provider-a", roles: [.scout])
        let b = InvocationSpy(providerID: "provider-b")
        await registry.register(a)
        await registry.register(b)
        let endpoint = BASOrganRegistryEndpoint(
            registry: registry,
            providerID: "provider-a")

        do {
            _ = try await endpoint.produceBody(
                prompt: "p", context: [], role: .core, sessionID: "s")
            XCTFail("unsupported role must refuse")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unsupported-role:core")
        }
        do {
            for try await _ in endpoint.streamBody(
                prompt: "p", context: [], role: .core, sessionID: "s") {}
            XCTFail("unsupported role must refuse streaming")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unsupported-role:core")
        }
        let aRequests = await a.requests()
        let bRequests = await b.requests()
        XCTAssertTrue(aRequests.eager.isEmpty)
        XCTAssertTrue(aRequests.stream.isEmpty)
        XCTAssertTrue(bRequests.eager.isEmpty)
        XCTAssertTrue(bRequests.stream.isEmpty)
    }

    func testOverrideIdentityMismatchRefusesBeforeInvocation()
        async throws
    {
        let b = InvocationSpy(providerID: "provider-b")
        let endpoint = BASOrganRegistryEndpoint(
            providerID: "provider-a",
            adapterOverride: { _ in b })

        do {
            _ = try await endpoint.produceBody(
                prompt: "p", context: [], role: .scout, sessionID: "s")
            XCTFail("mismatched fixture must refuse")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "provider-identity-mismatch")
        }
        do {
            for try await _ in endpoint.streamBody(
                prompt: "p", context: [], role: .scout, sessionID: "s") {}
            XCTFail("mismatched fixture must refuse streaming")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "provider-identity-mismatch")
        }
        let bRequests = await b.requests()
        XCTAssertTrue(bRequests.eager.isEmpty)
        XCTAssertTrue(bRequests.stream.isEmpty)
    }
}
