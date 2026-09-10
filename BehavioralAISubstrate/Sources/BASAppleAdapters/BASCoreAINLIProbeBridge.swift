import Foundation

#if canImport(CoreAI)
import CoreAI

/// observe→DISPOSE (Line A), Phase 2 — the device edge that hands the CoreAI NLI verifier to the production
/// adjudicator as a host-agnostic `BASNLIEntailmentProbe`. Device-ONLY (`#if canImport(CoreAI)`): on a host
/// build without CoreAI this file is empty, so the host path stays alias-only with zero NLI weight.
///
/// The edge (SDK endpoint / device app) constructs the verifier once from a staged `nli.aimodel` + tokenizer,
/// then wires it in one call:
/// ```swift
/// let verifier = try await BASCoreAINLIVerifier(aimodelURL: model, tokenizerFolder: tok)
/// let organ = BASLLMNeuralCoreService.adjudicating(adapter, nliProbe: .some(.coreAI(verifier)))
/// ```
/// FAIL-SOFT: any classify error ⇒ `nil` ⇒ no rescue (the deterministic alias verdict stands; the turn is
/// never broken). The mapping mirrors `BASNLIReconcile.apply` exactly — only a `.entailment` label counts as
/// `entails`, and the adapter's `nliThreshold` gates the confidence — so the conservative gaslight-reducer
/// contract is preserved end-to-end.
@available(iOS 27, macOS 27, *)
public extension BASCoreAINLIVerifier {

    /// Wrap this verifier as the probe the semantic adjudicator consumes (structurally identical to
    /// BASHostKit's `BASNLIEntailmentProbe` alias). `entails` is true only on an `.entailment` label;
    /// `confidence` is that prediction's softmax probability (the adapter compares it to `nliThreshold`,
    /// default 0.9). A classify failure returns `nil` (no rescue).
    ///
    /// charter audit 2026-07-12 T4: was `BASLLMNeuralCoreService.coreAINLIProbe(_:)` in BASHostKit —
    /// moved here (extension on the ADAPTER's own type, dependency-direction-clean) as part of the
    /// LLM-outside cut. Zero in-repo callers existed; the edge wires it as before:
    /// `adjudicating(adapter, nliProbe: verifier.asEntailmentProbe(), embeddingProvider: ...)`.
    func asEntailmentProbe()
        -> @Sendable (_ premise: String, _ hypothesis: String) async -> (entails: Bool, confidence: Float)?
    {
        { premise, hypothesis in
            guard let r = try? await self.classify(premise: premise, hypothesis: hypothesis) else { return nil }
            return (entails: r.label == .entailment, confidence: r.confidence)
        }
    }
}
#endif
