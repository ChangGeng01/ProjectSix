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
/// - **Local + Remote** — select either provider explicitly. A
///   configured remote secondary is held but is never an automatic
///   fallback for a failed local request.
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
/// - `.primaryOnly` (default): never invoke `secondary`. Used when hosts
///   want to A/B compare two routers without rewiring downstream.
/// - `.secondaryOnly`: never invoke `primary`. Same reason.
/// - `.primaryWithFallback`: try `primary` first; on
///   `BASOrganError.providerUnavailable` or `pressureRefusal`,
///   fall through only when the configured secondary also declares
///   on-device execution. Any other error propagates directly.
///
/// ## Why two errors trigger fallback (not all)
///
/// `providerUnavailable` and `pressureRefusal` are routing signals,
/// but they do not prove generation never started. They permit a
/// configured fallback only to another on-device provider. Other
/// errors, including cancellation, propagate without a second call.
///
/// ## Capacity & descriptor
///
/// - `descriptor.providerID`: synthesized as
///   `"routing.\(primary.providerID)+\(secondary.providerID)"`
/// - execution capabilities describe only providers reachable under
///   the configured strategy; eligible local fallback uses the
///   conservative intersection/min/AND of both descriptors
/// - `currentCapacity()`: returns the primary's capacity when
///   primary is healthy or fallback is ineligible; otherwise it
///   returns the eligible local secondary's capacity
public actor BASRoutingOrganAdapter: BASOrganAdapter {

    public enum Strategy:
        Sendable, Equatable, Hashable, Codable
    {
        /// Try primary; on provider unavailability or pressure
        /// refusal, fall through only when the secondary declares
        /// `runsOnDevice == true`. Any other error propagates.
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
    public let strategy: Strategy

    /// One construction-time decision shared by descriptor synthesis,
    /// every draft overload, and capacity reporting.
    private let automaticSecondaryIsEligible: Bool

    public nonisolated let descriptor: BASOrganDescriptor

    /// - Parameters:
    ///   - primary: preferred provider (tried first under
    ///     `.primaryWithFallback`, exclusive under
    ///     `.primaryOnly`)
    ///   - secondary: fallback provider (tried after `primary`'s
    ///     infra error under `.primaryWithFallback`, exclusive
    ///     under `.secondaryOnly`)
    ///   - strategy: routing policy. Defaults to `.primaryOnly`.
    ///   - providerID: optional override for the synthetic
    ///     descriptor's `providerID`. Defaults to
    ///     `"routing.\(primary.providerID)+\(secondary.providerID)"`.
    ///   - providerName: optional override for `providerName`.
    public init(
        primary: any BASOrganAdapter,
        secondary: any BASOrganAdapter,
        strategy: Strategy = .primaryOnly,
        providerID: String? = nil,
        providerName: String? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.strategy = strategy

        let p = primary.descriptor
        let s = secondary.descriptor
        let eligible = strategy == .primaryWithFallback
            && s.runsOnDevice
        self.automaticSecondaryIsEligible = eligible

        let pid = providerID
            ?? "routing.\(p.providerID)+\(s.providerID)"
        let pname = providerName
            ?? "Routing(\(p.providerName) + \(s.providerName))"

        let executionDescriptors: (BASOrganDescriptor, BASOrganDescriptor?)
        switch strategy {
        case .primaryOnly:
            executionDescriptors = (p, nil)
        case .secondaryOnly:
            executionDescriptors = (s, nil)
        case .primaryWithFallback where eligible:
            executionDescriptors = (p, s)
        case .primaryWithFallback:
            executionDescriptors = (p, nil)
        }
        let selected = executionDescriptors.0
        let fallback = executionDescriptors.1
        self.descriptor = BASOrganDescriptor(
            providerID: pid,
            providerName: pname,
            supportsStreaming:
                fallback.map {
                    selected.supportsStreaming
                        && $0.supportsStreaming
                } ?? selected.supportsStreaming,
            maxInputTokens: fallback.map {
                min(selected.maxInputTokens, $0.maxInputTokens)
            } ?? selected.maxInputTokens,
            maxOutputTokens: fallback.map {
                min(selected.maxOutputTokens, $0.maxOutputTokens)
            } ?? selected.maxOutputTokens,
            runsOnDevice:
                fallback.map {
                    selected.runsOnDevice && $0.runsOnDevice
                } ?? selected.runsOnDevice,
            supportedRoles:
                fallback.map {
                    selected.supportedRoles.intersection(
                        $0.supportedRoles)
                } ?? selected.supportedRoles)
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
            } catch let failure as BASOrganError {
                guard allowsAutomaticSecondary(after: failure) else {
                    throw failure
                }
                return try await secondary.draft(request)
            }
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
            } catch let failure as BASOrganError {
                guard allowsAutomaticSecondary(after: failure) else {
                    throw failure
                }
                return try await secondary.draft(
                    request,
                    electAccelerated: electAccelerated)
            }
        }
    }

    /// S5: PURPOSE-based routing — forwards the turn's purpose to whichever provider handles it (so a wrapped MLX
    /// provider's planner picks the lane). Mirrors the elect form above; byte-equal for providers without a lane.
    public func draft(
        _ request: BASOrganRequest,
        purpose: BASDecodeLanePolicy.Purpose
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        switch strategy {
        case .primaryOnly:
            return try await primary.draft(request, purpose: purpose)
        case .secondaryOnly:
            return try await secondary.draft(request, purpose: purpose)
        case .primaryWithFallback:
            do {
                return try await primary.draft(request, purpose: purpose)
            } catch let failure as BASOrganError {
                guard allowsAutomaticSecondary(after: failure) else {
                    throw failure
                }
                return try await secondary.draft(
                    request,
                    purpose: purpose)
            }
        }
    }

    private func allowsAutomaticSecondary(
        after failure: BASOrganError
    ) -> Bool {
        guard automaticSecondaryIsEligible else { return false }
        switch failure {
        case .providerUnavailable, .pressureRefusal:
            return true
        default:
            return false
        }
    }

    public func currentCapacity() async -> BASOrganCapacity {
        switch strategy {
        case .primaryOnly:
            return await primary.currentCapacity()
        case .secondaryOnly:
            return await secondary.currentCapacity()
        case .primaryWithFallback:
            let primaryCap = await primary.currentCapacity()
            guard primaryCap.underPressure,
                  automaticSecondaryIsEligible
            else {
                return primaryCap
            }
            return await secondary.currentCapacity()
        }
    }
}
