#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

/// B2-aggressive — TREE-structured prompt-lookup speculative decode. Verifies a whole candidate tree in ONE
/// target forward (custom tree attention mask + per-depth RoPE, via the vendor patch) and accepts the longest
/// root-to-leaf path that is the target's greedy argmax — more tokens per forward than the linear
/// `BASPromptLookupDecoder`, still TOKEN-identical to single-model greedy (every emitted token is the target's
/// own argmax). Model-free, no draft model, no prefill cost. Cache strategy: trim-all + replay the accepted path
/// (the tree nodes are written at scattered physical slots; there is no gather primitive).
///
/// Falls back to the linear decoder if the model is not `BASTreeDecodable`. Greedy lane only (temp 0).
public struct BASTreeSpecDecoder {

    public struct Result: Sendable {
        public let tokens: [Int]
        public let rounds: Int
        public let proposedNodes: Int      // total tree nodes proposed
        public let acceptedTokens: Int     // total accepted (beyond the per-round floor of 1)
        public let maxPathLen: Int         // deepest accepted path in any round
    }

    enum DecodeError: Error { case nonTrimmableCache }

    public static func generate(
        input: LMInput,
        model: any LanguageModel,
        parameters: GenerateParameters,
        drafter: any BASUniversalDraftSource,
        eosTokenIds: Set<Int>,
        maxBranch: Int = 2,
        maxNodes: Int = 8,
        maskDType: DType = .float16
    ) throws -> Result {
        // Local mutable binding so a STATEFUL source (e.g. the cross-turn `BASCrossTurnDrafter`) can advance its
        // index across rounds via the `mutating` `proposeTree`/`propose`; the stateless `BASPromptLookupDrafter`
        // is unaffected. (Mirrors BASPromptLookupDecoder. Tree-verify is still gated OFF — measure-only.)
        var drafter = drafter
        guard let treeModel = model as? BASTreeDecodable else {
            // Fail-open: no tree support → linear prompt-lookup (token-identical, just less aggressive).
            let r = try BASPromptLookupDecoder.generate(
                input: input, model: model, parameters: parameters, drafter: drafter, eosTokenIds: eosTokenIds)
            return Result(tokens: r.tokens, rounds: r.rounds, proposedNodes: r.proposed,
                          acceptedTokens: r.accepted, maxPathLen: 0)
        }

        let cache = model.newCache(parameters: parameters)
        // ADR-039: mirror BASPromptLookupDecoder's UNCONDITIONALLY-trimmable guard. canTrimPromptCache only checks
        // offset==0 at construction; a RotatingKVCache (maxKVSize != nil) flips isTrimmable→false once it fills past
        // maxCacheSize, after which the tree's trim-all+replay rewind silently under-trims and desyncs the cache
        // from the committed prefix — breaking token-identity. Reject it up front (fail-closed), same as the linear
        // lane, so this path stays safe under any future drafter-seam widening / warm-cache injection. (audit hardening)
        guard cache.allSatisfy({ !($0 is RotatingKVCache) }), canTrimPromptCache(cache) else {
            throw DecodeError.nonTrimmableCache
        }
        let sampler = parameters.sampler()
        let maxTokens = parameters.maxTokens

        var rolling = input.text.tokens.asArray(Int.self)
        var out = [Int]()
        var rounds = 0, proposedNodes = 0, acceptedTokens = 0, maxPathLen = 0

        // ---- Prefill: prime the cache + take the first token. ----
        var y: Int
        switch try model.prepare(input, cache: cache, windowSize: parameters.prefillStepSize) {
        case .tokens(let toks):
            let r = treeModel.treeForward(toks.tokens[.newAxis], cache: cache, tree: nil)
            let token = sampler.sample(logits: r[0..., -1, 0...])
            eval(token)
            y = token.item(Int.self)
            if eosTokenIds.contains(y) { return Result(tokens: out, rounds: 0, proposedNodes: 0, acceptedTokens: 0, maxPathLen: 0) }
            rolling.append(y); out.append(y)
        case .logits(let result):
            let token = sampler.sample(logits: result.logits[0..., -1, 0...])
            eval(token)
            y = token.item(Int.self)
            if eosTokenIds.contains(y) { return Result(tokens: out, rounds: 0, proposedNodes: 0, acceptedTokens: 0, maxPathLen: 0) }
            rolling.append(y); out.append(y)
        }

        // ---- Tree speculative rounds. ----
        while maxTokens.map({ out.count < $0 }) ?? true {
            let remaining = maxTokens.map { $0 - out.count } ?? maxNodes
            guard remaining > 0 else { break }
            let tree = drafter.proposeTree(over: rolling, maxBranch: maxBranch, maxNodes: Swift.min(maxNodes, Swift.max(1, remaining)))
            rounds += 1

            if tree.nodes.isEmpty {
                // No candidates → one plain greedy step (token-identical, the per-round floor).
                let r = treeModel.treeForward(MLXArray([Int32(y)])[.newAxis], cache: cache, tree: nil)
                let token = sampler.sample(logits: r[0..., -1, 0...]); eval(token)
                let t = token.item(Int.self)
                if eosTokenIds.contains(t) { break }
                out.append(t); rolling.append(t); y = t
                if let m = maxTokens, out.count >= m { break }
                continue
            }

            let f = tree.flatten(seed: y)
            let s = f.tokens.count
            proposedNodes += s - 1
            guard let cacheOffset = (cache.first?.offset) else { break }
            let mask = BASTreeAttentionMask.mlxMask(
                ancestorSets: f.ancestorSets, cacheOffset: cacheOffset, dtype: maskDType)
            let treeFwd = LlamaTreeForward(mask: .array(mask), ropeSegments: f.ropeSegments)

            let verify = MLXArray(f.tokens.map { Int32($0) })[.newAxis]   // [1, S]
            let logits = treeModel.treeForward(verify, cache: cache, tree: treeFwd)   // [1, S, vocab]
            let g = sampler.sample(logits: logits[0..., 0..., 0...].squeezed(axis: 0))  // [S]
            eval(g)
            let gv = g.asArray(Int.self)

            // children[i] = flat indices of i's children.
            var children = [[Int]](repeating: [], count: s)
            for (k, node) in tree.nodes.enumerated() { children[node.parent].append(k + 1) }

            // Walk the longest root-to-leaf path where each node's token == the parent position's argmax.
            var emitted: [Int] = []
            var stop = false
            func tryEmit(_ t: Int) -> Bool {   // returns false → stop (EOS / maxTokens)
                if eosTokenIds.contains(t) { stop = true; return false }
                emitted.append(t)
                if let m = maxTokens, out.count + emitted.count >= m { stop = true; return false }
                return true
            }
            _ = tryEmit(gv[0])               // the real next token (floor ≥ 1)
            var cur = 0
            while !stop {
                let required = gv[cur]
                guard let nxt = children[cur].first(where: { f.tokens[$0] == required }) else { break }
                if !tryEmit(gv[nxt]) { break }   // gv[nxt] = the next real token (computed in the same forward)
                cur = nxt
            }
            let pathLen = emitted.count - 1   // accepted draft nodes beyond the floor token
            acceptedTokens += pathLen
            maxPathLen = Swift.max(maxPathLen, pathLen)

            // Cache: drop the entire tree (keep y), then replay the committed path (minus the bonus seed) so its
            // K/V is written at canonical contiguous positions.
            _ = trimPromptCache(cache, numTokens: s - 1)
            out.append(contentsOf: emitted)
            rolling.append(contentsOf: emitted)
            let replay = Array(emitted.dropLast())   // all committed except the next seed
            if !replay.isEmpty {
                _ = treeModel.treeForward(MLXArray(replay.map { Int32($0) })[.newAxis], cache: cache, tree: nil)
            }
            y = emitted.last ?? y
            if stop { break }
        }
        return Result(tokens: out, rounds: rounds, proposedNodes: proposedNodes,
                      acceptedTokens: acceptedTokens, maxPathLen: maxPathLen)
    }
}
#endif
