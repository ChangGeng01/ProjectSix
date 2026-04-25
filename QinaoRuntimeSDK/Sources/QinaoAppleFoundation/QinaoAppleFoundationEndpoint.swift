import Foundation
import BASOrgan
import BASAppleAdapters
import QinaoLoop

/// M180 — public factory for the most common Qinao + Apple
/// FoundationModels host configuration.
///
/// ## Why this exists
///
/// Pre-M180 a host that wanted to drive `QinaoLoop.generateCandidates`
/// with Apple's on-device LLM had to write ~25 lines of glue:
///
/// 1. Construct `BASOrganRegistry` (substrate type)
/// 2. Register `AppleFoundationOrganAdapter()` (substrate type)
/// 3. Implement a custom `QinaoOrganEndpoint` conformance that
///    walks the registry, translates `QinaoLoop.OrganRole` ↔
///    `BASOrganRole`, calls `adapter.draft(...)`, and translates
///    the resulting `BASOrganDraft` back into a `QinaoLoop.OrganResponse`
///
/// `BASOrganRegistryEndpoint` already does all of step 3 inside
/// QinaoLoop, but it's `package`-scoped (so substrate type names
/// don't leak into the public API). Hosts couldn't use it directly.
/// Result: every host with the same need duplicated the same wrapper.
///
/// `QinaoAppleFoundation` is a thin separate library that lifts the
/// wrapper to a one-call factory. The factory's signature is
/// substrate-free (`async -> any QinaoOrganEndpoint`); BAS types
/// appear only inside the function body, so the redaction scanner
/// stays clean.
///
/// ## Why a separate library
///
/// Hosts that don't want Apple-specific code don't import this
/// target — `QinaoLoop` keeps its production graph free of
/// `BASAppleAdapters` (and transitively `FoundationModels`).
/// Hosts wanting Apple LLM add one line:
///
/// ```swift
/// import QinaoAppleFoundation
/// let endpoint = await QinaoLoop.makeAppleFoundationEndpoint()
/// let loop = QinaoLoop(organEndpoint: endpoint)
/// ```
///
/// ## Behavior under unavailability
///
/// On macOS 26+ / iOS 26+ / visionOS 26+ with Apple Intelligence
/// reachable: real `LanguageModelSession.respond(to:)` drives every
/// `produceBody(...)` call.
///
/// On older OS / hardware / Apple Intelligence disabled:
/// `AppleFoundationOrganAdapter.draft(_:)` throws
/// `BASOrganError.providerUnavailable`. The endpoint translates this
/// to `QinaoLoop.LoopError.organUnavailable(reason:)` so callers can
/// surface a typed refusal.
///
/// Pass `includeDeterministicFallback: true` to register a
/// `BASOrganDeterministicAdapter` first; the registry's "prefer
/// most-recent on-device" rule still picks Apple FM when available
/// but silently falls back to the deterministic adapter on an
/// unavailable Apple FM. Useful for offline development and
/// integration tests that need an organ but don't want a real LLM.
public extension QinaoLoop {

    /// One-call factory wiring Apple FoundationModels behind a
    /// `QinaoOrganEndpoint`. See file-level doc for full behavior.
    ///
    /// - Parameter includeDeterministicFallback: when `true`,
    ///   registers `BASOrganDeterministicAdapter` first so an
    ///   unavailable Apple FM falls through to a deterministic stub
    ///   instead of throwing. Default `false` (production hosts
    ///   should surface unavailability rather than silently degrade
    ///   to a stub).
    /// - Returns: an opaque endpoint hosts pass to
    ///   `QinaoLoop.init(organEndpoint:)`.
    static func makeAppleFoundationEndpoint(
        includeDeterministicFallback: Bool = false
    ) async -> any QinaoOrganEndpoint {
        let registry = BASOrganRegistry()
        if includeDeterministicFallback {
            await registry.register(BASOrganDeterministicAdapter())
        }
        await registry.register(AppleFoundationOrganAdapter())
        return BASOrganRegistryEndpoint(registry: registry)
    }
}
