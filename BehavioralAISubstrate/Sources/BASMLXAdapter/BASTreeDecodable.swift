#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

/// B2-aggressive — the BAS-side bridge that lets the tree decoder call the patched `treeForward` through an
/// `any LanguageModel`. `LlamaModel` (the Llama-3.2 target) already has the matching method from the vendor
/// patch (`Docs/patches/spec-decode-tree-mask.diff`), so conformance is automatic. A model that is NOT
/// `BASTreeDecodable` simply falls back to linear `BASPromptLookupDecoder` (tree-spec is opt-in, fail-open).
public protocol BASTreeDecodable {
    /// One forward over a flattened draft tree: custom attention mask + per-depth RoPE → logits `[1, S, vocab]`.
    func treeForward(_ inputs: MLXArray, cache: [KVCache]?, tree: LlamaTreeForward?) -> MLXArray
}

extension LlamaModel: BASTreeDecodable {}
#endif
