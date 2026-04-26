import Foundation
import SwiftUI
import QinaoLoop
import QinaoAppleFoundation
import QinaoMLX

/// Closure type used by `SampleSession` to lazily build an
/// endpoint for a chosen provider. Default implementation
/// (`SampleSession.defaultEndpointBuilder`) calls into the real
/// Qinao factories (`makeAppleFoundationEndpoint` /
/// `makeMLXEndpoint`); tests inject a closure that returns a
/// deterministic mock so behaviour assertions don't depend on
/// network or model availability.
public typealias SampleEndpointBuilder = @MainActor @Sendable (
    SampleProvider,
    @MainActor @Sendable @escaping (Progress) -> Void
) async throws -> any QinaoOrganEndpoint

/// Cached endpoints + UI state for the SwiftUI demo. Lifted into
/// the `QinaoSample` library (M228) so test targets can construct
/// it directly with a mocked `SampleEndpointBuilder` instead of
/// driving the executable target.
@MainActor
public final class SampleSession: ObservableObject {
    @Published public var status: String = "ready"
    @Published public var loadingMessage: String = ""
    @Published public var loadingProgress: Double = 0
    @Published public var isLoading: Bool = false

    private var cachedAppleEndpoint: (any QinaoOrganEndpoint)?
    private var cachedMLX: (
        model: QinaoMLXModel,
        endpoint: any QinaoOrganEndpoint
    )?

    private let endpointBuilder: SampleEndpointBuilder

    /// Initialise with the default real-Qinao endpoint builder.
    /// Production hosts call this; tests use the
    /// `init(endpointBuilder:)` overload to inject a mock.
    public init() {
        self.endpointBuilder = SampleSession.defaultEndpointBuilder
    }

    /// Initialise with a custom endpoint builder. Tests pass a
    /// closure that returns a deterministic stub endpoint so the
    /// session's caching + state-transition behavior can be
    /// exercised without network or MLX model loading.
    public init(endpointBuilder: @escaping SampleEndpointBuilder) {
        self.endpointBuilder = endpointBuilder
    }

    /// Lazily build (or fetch from cache) the endpoint for the
    /// selected provider. Throws if the provider is not yet wired.
    public func endpoint(
        for provider: SampleProvider
    ) async throws -> any QinaoOrganEndpoint {
        switch provider {
        case .appleFoundation:
            if let cached = cachedAppleEndpoint { return cached }
            let endpoint = try await endpointBuilder(
                provider, { _ in })
            cachedAppleEndpoint = endpoint
            return endpoint

        case .mlxGemma3_4B,
             .mlxGemma3nE4B,
             .mlxGemma3nE2B:
            guard let model = provider.mlxModel else {
                throw SampleError.providerNotWired(provider.rawValue)
            }
            if let cached = cachedMLX, cached.model == model {
                return cached.endpoint
            }
            isLoading = true
            loadingMessage = "Downloading \(model.displayName)…"
            loadingProgress = 0
            defer {
                isLoading = false
                loadingMessage = ""
                loadingProgress = 0
            }
            let endpoint = try await endpointBuilder(
                provider,
                { [weak self] progress in
                    self?.loadingProgress = progress.fractionCompleted
                })
            cachedMLX = (model, endpoint)
            return endpoint

        case .chatCompletions:
            throw SampleError.providerNotWired(provider.rawValue)
        }
    }

    /// Production endpoint builder. Routes to the real Qinao
    /// factories based on provider identity. Public for tests that
    /// want to wrap the production path with extra instrumentation.
    @MainActor @Sendable
    public static func defaultEndpointBuilder(
        provider: SampleProvider,
        progressHandler: @MainActor @Sendable @escaping (Progress) -> Void
    ) async throws -> any QinaoOrganEndpoint {
        switch provider {
        case .appleFoundation:
            return await QinaoLoop
                .makeAppleFoundationEndpoint()

        case .mlxGemma3_4B,
             .mlxGemma3nE4B,
             .mlxGemma3nE2B:
            guard let model = provider.mlxModel else {
                throw SampleError.providerNotWired(provider.rawValue)
            }
            // Wrap the @MainActor handler so it can be hopped onto
            // the main actor from the QinaoLoop's progress callback.
            return try await QinaoLoop.makeMLXEndpoint(
                model: model,
                progressHandler: { progress in
                    Task { @MainActor in
                        progressHandler(progress)
                    }
                })

        case .chatCompletions:
            throw SampleError.providerNotWired(provider.rawValue)
        }
    }
}
