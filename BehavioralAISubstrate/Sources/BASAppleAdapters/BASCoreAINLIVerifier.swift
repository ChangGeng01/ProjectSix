import Foundation
import Tokenizers

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
        if ids.count > seqLen { ids = Array(ids.prefix(seqLen - 1)) + [eos] }
        var mask = [Int](repeating: 1, count: ids.count)
        while ids.count < seqLen { ids.append(pad); mask.append(0) }

        let out = try await runner.runInt32(
            inputs: ["input_ids": ids.map { Int32($0) }, "attention_mask": mask.map { Int32($0) }],
            shapes: ["input_ids": [1, seqLen], "attention_mask": [1, seqLen]])
        guard let logits = out.values.first, logits.count >= 3 else { throw BASCoreAINLIVerifierError.badOutput }

        let argmax = logits.indices.max(by: { logits[$0] < logits[$1] }) ?? 0
        let mx = logits.max() ?? 0
        let exps = logits.map { Foundation.exp($0 - mx) }
        let sum = exps.reduce(0, +)
        let conf = sum > 0 ? exps[argmax] / sum : 0
        return (Self.labels[min(argmax, Self.labels.count - 1)], conf)
    }
}
#endif
