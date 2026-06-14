import Foundation
import BASRuntimeCore

/// M255 — `BASOrganAdapter` that wraps two underlying adapters and
/// routes requests between them based on a configurable strategy.
///
/// ## Why this exists
///
/// Production hosts often want to compose providers:
///
/// - **Apple Foundation Models + MLX-LoRA** — prefer Apple's
///   on-device LM where available (Apple Intelligence on
///   iOS 18.1+ / macOS 26+); fall back to MLX-LoRA on older OS
///   or non-Apple-Intelligence devices. Same `BASOrganAdapter`
///   contract either way.
/// - **Local + Remote** — prefer on-device for privacy, fall
///   back to a remote chat-completions provider when the local
///   model can't satisfy the request (e.g. exceeds maxInputTokens).
/// - **Two on-device** — `MLXOrganAdapter` with M247 LoRA as
///   primary, deterministic adapter as secondary for hermetic
///   tests.
///
/// The router is itself a `BASOrganAdapter` (and `Sendable`) so
/// it composes with the rest of the substrate transparently:
/// `BASOrganRegistry`, `BASEBrainRuntimeCoordinator`, and host
/// runtimes don't need to know they're talking to a router.
///
/// ## Strategies
///
/// - `.primaryWithFallback` (default): try `primary` first; on
///   `BASOrganError.providerUnavailable` or `pressureRefusal`,
///   fall through to `secondary`. Any other error propagates
///   directly. Inputs that violate either adapter (unsupportedRole,
///   inputTooLong, deadlineExpired) hit the original error
///   surface unchanged.
/// - `.primaryOnly`: never invoke `secondary`. Used when hosts
///   want to A/B compare two routers without rewiring downstream.
/// - `.secondaryOnly`: never invoke `primary`. Same reason.
///
/// ## Why two errors trigger fallback (not all)
///
/// `providerUnavailable` and `pressureRefusal` are infrastructure
/// signals — "this provider can't run the request right now."
/// Falling back is correct: the secondary provider might be able
/// to. The other three (`unsupportedRole`, `inputTooLong`,
/// `deadlineExpired`) are caller-input violations or hard limits
/// that the secondary would also reject. Falling back on those
/// would mask the real error from the caller.
///
/// ## Capacity & descriptor
///
/// - `descriptor.providerID`: synthesized as
///   `"routing.\(primary.providerID)+\(secondary.providerID)"`
/// - `descriptor.supportedRoles`: intersection of both adapters'
///   supported roles — a routed request must be servable by
///   *both* (so fallback works for any role we accept)
/// - `descriptor.supportsStreaming`: AND of both
///   (router itself doesn't conform to BASStreamingOrganAdapter
///   today; that's M255-followup if needed)
/// - `descriptor.runsOnDevice`: AND of both
/// - `descriptor.maxInputTokens` / `maxOutputTokens`: min of both
///   (so any input we accept fits both providers' limits)
/// - `currentCapacity()`: returns the primary's capacity when
///   primary is healthy; otherwise the secondary's. Reasoning:
///   the metric callers consult is "how much can we send right
///   now", and the router's effective answer is whichever
///   provider is about to handle the next request.
public actor BASRoutingOrganAdapter: BASOrganAdapter {

    public enum Strategy:
        Sendable, Equatable, Hashable, Codable
    {
        /// Try primary; on infrastructure failure (provider
        /// unavailable / pressure refusal) fall through to
        /// secondary. Any other error propagates.
        case primaryWithFallback
        /// Always use primary. Secondary is held but never
        /// invoked. Useful for A/B comparison without rewiring.
        case primaryOnly
        /// Always use secondary. Primary is held but never
        /// invoked. Mirror of `.primaryOnly`.
        case secondaryOnly
    }

    public let primary: any BASOrganAdapter
    public let secondary: any BASOrganAdapter
    public var strategy: Strategy

    public nonisolated let descriptor: BASOrganDescriptor

    /// - Parameters:
    ///   - primary: preferred provider (tried first under
    ///     `.primaryWithFallback`, exclusive under
    ///     `.primaryOnly`)
    ///   - secondary: fallback provider (tried after `primary`'s
    ///     infra error under `.primaryWithFallback`, exclusive
    ///     under `.secondaryOnly`)
    ///   - strategy: routing policy. Defaults to
    ///     `.primaryWithFallback`.
    ///   - providerID: optional override for the synthetic
    ///     descriptor's `providerID`. Defaults to
    ///     `"routing.\(primary.providerID)+\(secondary.providerID)"`.
    ///   - providerName: optional override for `providerName`.
    public init(
        primary: any BASOrganAdapter,
        secondary: any BASOrganAdapter,
        strategy: Strategy = .primaryWithFallback,
        providerID: String? = nil,
        providerName: String? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.strategy = strategy

        let pid = providerID
            ?? "routing.\(primary.descriptor.providerID)+" +
                "\(secondary.descriptor.providerID)"
        let pname = providerName
            ?? "Routing(\(primary.descriptor.providerName)" +
               " + \(secondary.descriptor.providerName))"
        self.descriptor = BASOrganDescriptor(
            providerID: pid,
            providerName: pname,
            supportsStreaming:
                primary.descriptor.supportsStreaming
                && secondary.descriptor.supportsStreaming,
            maxInputTokens: min(
                primary.descriptor.maxInputTokens,
                secondary.descriptor.maxInputTokens),
            maxOutputTokens: min(
                primary.descriptor.maxOutputTokens,
                secondary.descriptor.maxOutputTokens),
            runsOnDevice:
                primary.descriptor.runsOnDevice
                && secondary.descriptor.runsOnDevice,
            supportedRoles:
                primary.descriptor.supportedRoles
                .intersection(
                    secondary.descriptor.supportedRoles))
    }

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        // Role check up-front — caller violation should fail fast
        // and identically regardless of which provider would
        // have handled the request.
        guard descriptor.supportedRoles.contains(request.role)
        else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        switch strategy {
        case .primaryOnly:
            return try await primary.draft(request)
        case .secondaryOnly:
            return try await secondary.draft(request)
        case .primaryWithFallback:
            do {
                return try await primary.draft(request)
            } catch BASOrganError.providerUnavailable {
                return try await secondary.draft(request)
            } catch BASOrganError.pressureRefusal {
                return try await secondary.draft(request)
            }
            // Other errors (unsupportedRole, inputTooLong,
            // deadlineExpired) propagate — they're caller-input
            // violations and hard limits that secondary wouldn't
            // accept either.
        }
    }

    /// P1 wrapper propagation: identical routing, threading the host's `electAccelerated` to whichever provider
    /// handles the request (so a wrapped MLX provider's prompt-lookup lane can fire). Byte-equal to the 1-arg
    /// form for providers without an accelerated lane.
    public func draft(
        _ request: BASOrganRequest,
        electAccelerated: Bool
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        switch strategy {
        case .primaryOnly:
            return try await primary.draft(request, electAccelerated: electAccelerated)
        case .secondaryOnly:
            return try await secondary.draft(request, electAccelerated: electAccelerated)
        case .primaryWithFallback:
            do {
                return try await primary.draft(request, electAccelerated: electAccelerated)
            } catch BASOrganError.providerUnavailable {
                return try await secondary.draft(request, electAccelerated: electAccelerated)
            } catch BASOrganError.pressureRefusal {
                return try await secondary.draft(request, electAccelerated: electAccelerated)
            }
        }
    }

    public func currentCapacity() async -> BASOrganCapacity {
        switch strategy {
        case .primaryOnly:
            return await primary.currentCapacity()
        case .secondaryOnly:
            return await secondary.currentCapacity()
        case .primaryWithFallback:
            // Report primary's capacity when primary is healthy
            // (under no infra pressure). When primary signals
            // underPressure we'd fall through on actual draft;
            // expose the fallback's capacity to give callers an
            // honest answer about what they can send next.
            let primaryCap = await primary.currentCapacity()
            if !primaryCap.underPressure {
                return primaryCap
            }
            return await secondary.currentCapacity()
        }
    }
}
