import Foundation

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters

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
public extension BASLLMNeuralCoreService {

    /// Wrap a `BASCoreAINLIVerifier` as the probe the semantic adjudicator consumes. `entails` is true only on
    /// an `.entailment` label; `confidence` is that prediction's softmax probability (the adapter compares it
    /// to `nliThreshold`, default 0.9). A classify failure returns `nil` (no rescue).
    static func coreAINLIProbe(_ verifier: BASCoreAINLIVerifier) -> BASNLIEntailmentProbe {
        { premise, hypothesis in
            guard let r = try? await verifier.classify(premise: premise, hypothesis: hypothesis) else { return nil }
            return (entails: r.label == .entailment, confidence: r.confidence)
        }
    }
}
#endif
