import Foundation
import BASOrgan
import BASSovereign

/// observe→DISPOSE (Line A) — the FRONTIER runtime wiring: a decorator that drives a live turn through the
/// full semantic pipeline (extract → SEMANTIC retrieve via `BASEmbeddingFactBank` → alias-aware verify →
/// verdict-instruction → wrapped organ). This is the async counterpart of `BASAdjudicatingOrganAdapter`
/// (which uses the sync substring `BASFactBank`); it swaps in the embedding bank so paraphrased questions
/// resolve instead of silently abstaining.
///
/// Default-OFF (`BAS_FACTUAL_ADJUDICATE`) + abstain-by-default: flag unset, no recognized assertion, or the
/// bank's cosine below its threshold ⇒ the request passes through to the inner organ UNCHANGED. The verdict
/// rides in the user-turn instruction (never `systemInstructions`); never mutates input; never touches the
/// sovereign byte-parity verdict.
public final class BASSemanticAdjudicatingOrganAdapter: BASOrganAdapter {

    private let inner: BASOrganAdapter
    private let bank: BASEmbeddingFactBank
    private let extractAssertion: @Sendable (String) -> String?
    private let enabled: Bool

    public init(
        wrapping inner: BASOrganAdapter,
        bank: BASEmbeddingFactBank,
        extractAssertion: @escaping @Sendable (String) -> String? = { BASBeliefAssertionParser.assertedValue(in: $0) },
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled()
    ) {
        self.inner = inner
        self.bank = bank
        self.extractAssertion = extractAssertion
        self.enabled = enabled
    }

    public var descriptor: BASOrganDescriptor { inner.descriptor }

    public func currentCapacity() async -> BASOrganCapacity { await inner.currentCapacity() }

    /// Pre-embed the bank (idempotent) so the first live turn doesn't pay the load cost. Optional.
    public func warmUp() async { await bank.load() }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        try await inner.draft(await adjudicated(request))
    }

    /// Enabled + recognized assertion + semantic bank hit ⇒ a fresh request with the verdict prepended;
    /// otherwise `request` unchanged (default-OFF / no-claim / below-threshold all abstain).
    func adjudicated(_ request: BASOrganRequest) async -> BASOrganRequest {
        guard enabled, let asserted = extractAssertion(request.instruction) else { return request }
        guard let resolved = await bank.resolve(question: request.instruction, assertedValue: asserted) else {
            return request
        }
        return BASFactualAdjudicatorWiring.applyIfEnabled(
            to: request, groundTruth: resolved.groundTruth, reference: resolved.reference, enabled: true)
    }
}
