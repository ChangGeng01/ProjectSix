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
///
/// ## Parity with `BASSemanticAdjudicatingOrganAdapter` (the shared substrate)
///
/// This SYNC variant resolves against the in-memory substring `BASFactBank` — NO MiniLM, NO embedding — so it
/// is the LIGHTER, lower-power adjudicator (a host that wants the dispose path without the per-turn embed
/// cost wraps with this instead of the semantic one). It now reuses the SAME reusable infrastructure as the
/// semantic adapter: `BASStreamingOrganAdapter` conformance (verdict reaches `streamDraft`), the accelerated
/// draft overloads (transparent decode lane), the `BASAdjudicationGate` neuromodulation tier, and the
/// `BASAdjudicationObserver` OBSERVE lane. Default `.always` gate + `nil` observer ⇒ byte-equal with the
/// pre-parity behavior; the sovereign byte-parity verdict is never touched.
public final class BASAdjudicatingOrganAdapter: BASOrganAdapter {

    private let inner: BASOrganAdapter
    private let facts: [BASVerifiedFact]
    private let extractAssertion: @Sendable (String) -> String?
    private let enabled: Bool
    /// NEUROMODULATION gate — engage/skip the fact lookup per turn. Default `.always` ⇒ byte-equal.
    private let gate: BASAdjudicationGate
    /// OBSERVE lane — per-turn outcome record. Default `nil` ⇒ byte-equal no-op.
    private let observer: BASAdjudicationObserver?

    public init(
        wrapping inner: BASOrganAdapter,
        facts: [BASVerifiedFact],
        extractAssertion: @escaping @Sendable (String) -> String? = { BASBeliefAssertionParser.assertedValue(in: $0) },
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled(),
        gate: BASAdjudicationGate = .always,
        observer: BASAdjudicationObserver? = nil
    ) {
        self.inner = inner
        self.facts = facts
        self.extractAssertion = extractAssertion
        self.enabled = enabled
        self.gate = gate
        self.observer = observer
    }

    public var descriptor: BASOrganDescriptor { inner.descriptor }

    public func currentCapacity() async -> BASOrganCapacity { await inner.currentCapacity() }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        try await inner.draft(await adjudicated(request))
    }

    /// Accelerated overloads stay transparent — adjudicate first, then delegate to the inner's own lane so the
    /// verdict rides into whichever decode lane the inner picks (mirrors the semantic adapter).
    public func draft(
        _ request: BASOrganRequest, electAccelerated: Bool
    ) async throws -> BASOrganDraft {
        try await inner.draft(await adjudicated(request), electAccelerated: electAccelerated)
    }

    public func draft(
        _ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose
    ) async throws -> BASOrganDraft {
        try await inner.draft(await adjudicated(request), purpose: purpose)
    }

    /// Enabled + gate engages + recognized assertion + fact-bank hit ⇒ a fresh request with the verdict
    /// prepended; otherwise `request` unchanged (default-OFF / gate-skip / no-claim / not-covered all abstain).
    /// The gate is consulted FIRST (avoided compute); the OBSERVE lane records the per-turn outcome. Never
    /// mutates input.
    func adjudicated(_ request: BASOrganRequest) async -> BASOrganRequest {
        guard enabled else { return request }
        guard await gate.shouldEngage(request) else {
            await observe(request, .gateSkipped); return request
        }
        guard let asserted = extractAssertion(request.instruction) else {
            await observe(request, .noAssertion); return request
        }
        guard let resolved = BASFactBank.resolve(
            question: request.instruction, assertedValue: asserted, facts: facts) else {
            await observe(request, .belowThreshold); return request   // parsed but not covered ⇒ abstain
        }
        await observe(request, .injected)
        return BASFactualAdjudicatorWiring.applyIfEnabled(
            to: request, groundTruth: resolved.groundTruth, reference: resolved.reference, enabled: true)
    }

    private func observe(_ request: BASOrganRequest, _ outcome: BASAdjudicationObservationRecord.Outcome) async {
        await observer?(BASAdjudicationObservationRecord(
            requestID: request.requestID, role: request.role, outcome: outcome))
    }
}

// MARK: - Streaming parity (mirrors BASSemanticAdjudicatingOrganAdapter)

/// The chat loop probes the resolved adapter `as? BASStreamingOrganAdapter`; conforming here closes the same
/// streaming bypass for the sync variant. Verdict prepended BEFORE the inner `streamDraft`; FAIL-OPEN to the
/// inner's `draft(_:)` (one chunk) when the inner does not itself stream. Default-OFF / abstain ⇒ pure
/// pass-through (byte-equal).
extension BASAdjudicatingOrganAdapter: BASStreamingOrganAdapter {

    public func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let adjudicatedRequest = await self.adjudicated(request)
                    if let streamingInner = self.inner as? BASStreamingOrganAdapter {
                        for try await chunk in streamingInner.streamDraft(adjudicatedRequest) {
                            continuation.yield(chunk)
                        }
                    } else {
                        let draft = try await self.inner.draft(adjudicatedRequest)
                        continuation.yield(BASOrganDraftChunk(
                            requestID: draft.requestID,
                            providerID: draft.providerID,
                            role: draft.role,
                            bodyDelta: draft.body,
                            cumulativeBody: draft.body,
                            producedAt: draft.producedAt))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
