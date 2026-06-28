import Foundation
import Tokenizers
import BASSovereign   // BASFactualBeliefAdjudicator.GroundTruth for the reconcile contract

#if canImport(CoreAI)
import CoreAI
#endif

/// observe→DISPOSE (Line A), VERIFY — CoreAI NLI entailment verifier (device-only). Premise = the verified
/// reference fact; hypothesis = the user's claim. Closes the open synonym/numeric/paraphrase tail the
/// deterministic alias table can't. RoBERTa BPE tokenization (swift-transformers) over the converted
/// `nli.aimodel` (GATE1 host-validated 7/7). It is meant to be used CONSERVATIVELY as a GASLIGHT-REDUCER:
/// only flip a deterministic `.contradicts` to `.agrees` on HIGH-confidence `.entailment` — NEVER add a
/// contradiction (NLI ~73-77% BAcc, so it must not become a new false-`.contradicts` source).
public enum BASNLIEntailment: String, Sendable, Equatable, Codable {
    case entailment, contradiction, neutral
}

public enum BASCoreAINLIVerifierError: Error { case badOutput }

/// The CONSERVATIVE gaslight-reducer contract (pure, host-testable). NLI may ONLY rescue a deterministic
/// `.contradicts` → `.agrees` on HIGH-confidence `.entailment` (a synonym/paraphrase the alias table missed).
/// It can NEVER add a contradiction or override an `.agrees` / `.abstain` — so a mislabeling NLI (~73-77%
/// BAcc) can only REDUCE gaslight, never create it. Low-confidence ⇒ keep the deterministic decision
/// (the GATE2 miss was conf 0.61, which this gates out).
public enum BASNLIReconcile {
    public static func apply(
        alias: BASFactualBeliefAdjudicator.GroundTruth,
        nli: (label: BASNLIEntailment, confidence: Float)?,
        entailmentThreshold: Float = 0.9
    ) -> BASFactualBeliefAdjudicator.GroundTruth {
        guard alias == .contradicts,
              let nli = nli, nli.label == .entailment, nli.confidence >= entailmentThreshold
        else { return alias }
        return .agrees
    }
}

#if canImport(CoreAI)
@available(iOS 27, macOS 27, *)
public actor BASCoreAINLIVerifier {

    private let runner: BASCoreAIModelRunner
    private let tokenizer: Tokenizer
    private let seqLen: Int
    // RoBERTa / distilroberta special-token ids: <s>=0, <pad>=1, </s>=2
    private let bos = 0, pad = 1, eos = 2
    // cross-encoder/nli-distilroberta-base id2label: 0=contradiction, 1=entailment, 2=neutral
    private static let labels: [BASNLIEntailment] = [.contradiction, .entailment, .neutral]

    public init(aimodelURL: URL, tokenizerFolder: URL, seqLen: Int = 128) async throws {
        self.runner = try await BASCoreAIModelRunner(assetURL: aimodelURL)
        self.tokenizer = try await AutoTokenizer.from(modelFolder: tokenizerFolder)
        self.seqLen = seqLen
    }

    public func classify(premise: String, hypothesis: String) async throws -> (label: BASNLIEntailment, confidence: Float) {
        let p = tokenizer.encode(text: premise, addSpecialTokens: false)
        let h = tokenizer.encode(text: hypothesis, addSpecialTokens: false)
        var ids = [bos] + p + [eos, eos] + h + [eos]            // RoBERTa pair: <s> P </s></s> H </s>
        if ids.count > seqLen {
            // truncate the PREMISE, keep the FULL hypothesis + separators (prefix-truncation dropped the
            // hypothesis → corrupted the cross-encoder → could affirm a wrong user; audit #2 2026-06-28).
            let pKeep = max(0, p.count - (ids.count - seqLen))
            ids = [bos] + Array(p.prefix(pKeep)) + [eos, eos] + h + [eos]
            if ids.count > seqLen { ids = Array(ids.prefix(seqLen)) }   // last resort (hypothesis alone > window)
        }
        var mask = [Int](repeating: 1, count: ids.count)
        while ids.count < seqLen { ids.append(pad); mask.append(0) }

        let out = try await runner.runInt32(
            inputs: ["input_ids": ids.map { Int32($0) }, "attention_mask": mask.map { Int32($0) }],
            shapes: ["input_ids": [1, seqLen], "attention_mask": [1, seqLen]])
        guard let logits = out["logits"] ?? out.values.first, logits.count >= 3 else { throw BASCoreAINLIVerifierError.badOutput }

        let argmax = logits.indices.max(by: { logits[$0] < logits[$1] }) ?? 0
        let mx = logits.max() ?? 0
        let exps = logits.map { Foundation.exp($0 - mx) }
        let sum = exps.reduce(0, +)
        let conf = sum > 0 ? exps[argmax] / sum : 0
        return (Self.labels[min(argmax, Self.labels.count - 1)], conf)
    }
}
#endif
