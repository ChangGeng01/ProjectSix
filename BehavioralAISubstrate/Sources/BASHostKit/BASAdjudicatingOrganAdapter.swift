import Foundation
import BASOrgan
import BASSovereign

/// observe→DISPOSE (Line A) — the RUNTIME wiring: a decorator that wraps any `BASOrganAdapter` and, when
/// enabled, auto-adjudicates each turn before the model sees it (parse the asserted value → resolve against
/// the fact bank → inject the verdict → delegate to the wrapped organ). This is how the dispose path reaches
/// live turns without hunting for "the" turn loop: a host opts in by wrapping its organ with this.
///
/// Default-OFF (`BAS_FACTUAL_ADJUDICATE`) and ABSTAIN-by-default: with the flag unset, or when no assertion
/// is recognized, or when the fact bank doesn't cover the claim, the request passes through BYTE-IDENTICAL
/// (`draft(adjudicated(request))` where `adjudicated` returns the input unchanged). The claim extractor is
/// injectable (defaults to the conservative `BASBeliefAssertionParser`; swap in a small NLI model later).
/// Intercepts `draft(_:)` — the canonical organ entry point; the device streaming seam is a follow-up.
public final class BASAdjudicatingOrganAdapter: BASOrganAdapter {

    private let inner: BASOrganAdapter
    private let facts: [BASVerifiedFact]
    private let extractAssertion: @Sendable (String) -> String?
    private let enabled: Bool

    public init(
        wrapping inner: BASOrganAdapter,
        facts: [BASVerifiedFact],
        extractAssertion: @escaping @Sendable (String) -> String? = { BASBeliefAssertionParser.assertedValue(in: $0) },
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled()
    ) {
        self.inner = inner
        self.facts = facts
        self.extractAssertion = extractAssertion
        self.enabled = enabled
    }

    public var descriptor: BASOrganDescriptor { inner.descriptor }

    public func currentCapacity() async -> BASOrganCapacity { await inner.currentCapacity() }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        try await inner.draft(adjudicated(request))
    }

    /// Enabled + a recognized assertion + a fact-bank hit ⇒ a fresh request with the verdict prepended;
    /// otherwise `request` unchanged (default-OFF / no-claim / not-covered all abstain). Never mutates input.
    func adjudicated(_ request: BASOrganRequest) -> BASOrganRequest {
        guard enabled, let asserted = extractAssertion(request.instruction) else { return request }
        return BASFactualAdjudicatorWiring.applyIfEnabled(
            to: request, question: request.instruction, assertedValue: asserted, facts: facts, enabled: true)
    }
}
