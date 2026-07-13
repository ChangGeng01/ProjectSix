// MARK: - BASPromptLookupCarryForwardTests — P1-b GDN carry-forward lane behavior gate
//
// The predicate-level guard test (BASSpecDecoderCacheGuardTests) proved FALSE-GREEN under
// reversal: reverting the router to the old hard-throw left the predicates intact, so the
// tooth stayed green while the behavior regressed. This file bites the BEHAVIOR: it drives
// BASPromptLookupDecoder.generate end-to-end against a stub HYBRID model (ArraysCache GDN
// layer + trimmable attention layer — the Qwen3.5 cache shape) whose next-token function
// deliberately DEPENDS on the cache state (attention offset + GDN slot sum). Consequences:
//   • the old hard-throw router → generate throws nonTrimmableCache → RED (routing pinned);
//   • any snapshot/restore/trim arithmetic bug in the carry-forward loop shifts the state
//     the predictions read → the spec stream diverges from the plain-greedy gold → RED.
// Runs on macOS under the beta toolchain (MLX CPU/Metal arrays available; no model assets).

#if canImport(MLXLLM)
import XCTest
import MLX
import MLXNN
import MLXLMCommon
@testable import BASMLXAdapter

/// Stub hybrid model: vocab 16. Prediction after fed token t = (t + attn.offset + gdnSum) mod 16,
/// where attn.offset is the attention cache's committed length AT ENTRY of the forward and gdnSum
/// is the integer in the GDN slot (incremented by the fed width each forward — recurrent state).
/// Both runs (plain gold vs carry-forward spec) share this arithmetic, so byte-identity holds IFF
/// the carry-forward rollback restores the state exactly.
private final class StubHybridModel: Module, LanguageModel {

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] { weights }

    func newCache(parameters: GenerateParameters?) -> [KVCache] {
        [MambaCache(), KVCacheSimple()]
    }

    private func step(_ tokens: [Int], cache: [KVCache]) -> MLXArray {
        let gdn = cache.compactMap { $0 as? ArraysCache }.first!
        let attn = cache.first { !($0 is ArraysCache) }!
        let offsetAtEntry = attn.offset
        let gdnSum = gdn.state.isEmpty ? 0 : Int(gdn[0]!.asArray(Float.self)[0])
        let T = tokens.count
        // CAUSAL-CONSISTENT logits [1, T, 16]: row j depends only on its own token and the
        // stream-prefix length BEFORE it (committed offset + j) plus the GDN state accumulated
        // over that same prefix (gdnSum + j) — identical whether the prefix was fed batched or
        // one token at a time, exactly the property the decode loop relies on in a real model.
        // A rollback bug shifts offsetAtEntry/gdnSum for later rounds → visible byte divergence.
        var rows = [Float]()
        for (j, t) in tokens.enumerated() {
            var row = [Float](repeating: 0, count: 16)
            row[(t + offsetAtEntry + j + gdnSum + j) % 16] = 1
            rows += row
        }
        // advance state: attention grows by T, GDN slot accumulates 1/token (recurrent)
        _ = attn.update(
            keys: MLXArray.zeros([1, 1, T, 1]), values: MLXArray.zeros([1, 1, T, 1]))
        gdn[0] = MLXArray([Float(gdnSum + T)])
        gdn[1] = MLXArray([Float(0)])
        return MLXArray(rows).reshaped([1, T, 16])
    }

    func prepare(_ input: LMInput, cache: [KVCache], windowSize: Int?) throws -> PrepareResult {
        let logits = step(input.text.tokens.asArray(Int.self), cache: cache)
        return .logits(LMOutput(logits: logits))
    }

    func callAsFunction(
        _ input: LMInput.Text, cache: [KVCache]?, state: LMOutput.State?
    ) -> LMOutput {
        LMOutput(logits: step(input.tokens.asArray(Int.self), cache: cache!))
    }
}

final class BASPromptLookupCarryForwardTests: XCTestCase {

    private let prompt = [1, 3, 1, 3, 1, 3]   // repetitive → the n-gram drafter proposes
    private let maxTokens = 24

    /// Plain-greedy gold: same stub arithmetic, one token per forward, no speculation.
    private func plainGold() -> [Int] {
        let model = StubHybridModel()
        let cache = model.newCache(parameters: nil)
        var out = [Int]()
        var logits = try! { () -> MLXArray in
            switch try model.prepare(
                LMInput(text: .init(tokens: MLXArray(prompt.map { Int32($0) }))),
                cache: cache, windowSize: nil) {
            case .logits(let r): return r.logits
            case .tokens: fatalError("stub always returns logits")
            }
        }()
        while out.count < maxTokens {
            let t = logits[0..., -1, 0...].argMax(axis: -1).item(Int.self)
            out.append(t)
            logits = model(.init(tokens: MLXArray([Int32(t)])), cache: cache, state: nil).logits
        }
        return out
    }

    /// The P1-b behavior pin: the hybrid composition must ROUTE (not throw) and the spec stream
    /// must be byte-identical to plain greedy. Reversal: the old hard-throw router reds the
    /// no-throw assert; a rollback-arithmetic bug reds the byte-identity assert.
    func testCarryForwardRoutesAndIsByteIdenticalOnHybridCache() throws {
        let model = StubHybridModel()
        var params = GenerateParameters()
        params.temperature = 0
        params.maxTokens = maxTokens
        let result: BASPromptLookupDecoder.Result
        do {
            result = try BASPromptLookupDecoder.generate(
                input: LMInput(text: .init(tokens: MLXArray(prompt.map { Int32($0) }))),
                model: model, parameters: params,
                drafter: BASPromptLookupDrafter(numDraftTokens: 4),
                eosTokenIds: [], adaptiveK: true)
        } catch {
            XCTFail("hybrid (ArraysCache+trimmable) must route to carry-forward, not throw: \(error)")
            return
        }
        XCTAssertEqual(result.tokens, plainGold(),
            "carry-forward spec must be byte-identical to plain greedy on the state-dependent stub "
            + "(a snapshot/restore/trim arithmetic bug shifts the state the predictions read)")
        XCTAssertGreaterThan(result.rounds, 0)
    }

    /// The reject path specifically: a drafter that proposes WRONG tokens every round forces a
    /// restore every round; byte-identity then holds only if restore+carry-forward is exact.
    func testAllRejectPathStaysByteIdentical() throws {
        struct WrongDrafter: BASUniversalDraftSource {
            var sourceID: String { "test.wrong-drafter" }
            var numDraftTokens: Int { 3 }
            mutating func propose(over tokens: [Int]) -> [Int] {
                let last = tokens.last ?? 0
                return [(last + 7) % 16, (last + 11) % 16, (last + 13) % 16]
            }
            mutating func proposeTree(over tokens: [Int], maxBranch: Int, maxNodes: Int) -> BASDraftTree {
                BASDraftTree(nodes: [])   // tree lane unused by the carry-forward loop
            }
        }
        let model = StubHybridModel()
        var params = GenerateParameters()
        params.temperature = 0
        params.maxTokens = maxTokens
        let result = try BASPromptLookupDecoder.generate(
            input: LMInput(text: .init(tokens: MLXArray(prompt.map { Int32($0) }))),
            model: model, parameters: params,
            drafter: WrongDrafter(), eosTokenIds: [], adaptiveK: false)
        XCTAssertEqual(result.tokens, plainGold(),
            "every-round rejects exercise restore+pending carry-forward; divergence = rollback bug")
        XCTAssertEqual(result.accepted, 0, "the wrong-drafter must never be accepted")
    }
}
#endif
