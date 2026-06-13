#if canImport(CoreML)
import Foundation
import CoreML

/// B2 hybrid — a stateful Core ML LLM draft (the ANE half of the ANE-draft ∥ MLX-verify speculative hybrid).
///
/// Wraps the converted `LlamaDraft1B_int8.mlpackage` (`Tools/llama_draft_to_coreml.py`): per-layer `MLState`
/// KV caches written by a ONE-HOT positional write, driven by host-supplied RoPE cos/sin + a causal additive
/// bias (the exact contract the converter traced). This class owns the draft's KV frontier (`draftPos`) and the
/// propose / commit primitives the decoder composes; it makes NO accept/emit decision (that is the TARGET's job,
/// in `BASCoreMLDraftDecoder`, so byte-identity is the target's argmax by construction — this draft only proposes).
///
/// `@unchecked Sendable` because it is ONLY ever driven on the adapter's serialized executor (the actor +
/// `SerialAccessContainer`) — never concurrently, despite the mutable `draftPos`/`MLState` (same soundness
/// argument as `DraftModelBox`). This lets the caller hand it to the actor method + into `perform(nonSendable:)`
/// without a box.
@available(iOS 18.0, macOS 15.0, *)
public final class BASCoreMLDraftSession: @unchecked Sendable {

    public enum DraftError: Error {
        case modelLoad(String)
        case ropeTable(String)
        case windowOverflow(pos: Int, maxSeq: Int)
        case predict(String)
    }

    private let model: MLModel
    private var state: MLState
    private let maxSeq: Int
    private let headDim: Int
    private let neg: Float          // additive-mask "−inf" — MUST match the traced graph (−1e4, not −inf)

    // RoPE tables [maxSeq * headDim] row-major float32 (emitted by Tools/emit_rope_tables.py — exact llama3 scaling).
    private let cosTable: [Float]
    private let sinTable: [Float]

    // Pre-allocated input buffers, reused + updated in O(K) per step (NOT reallocated + NSNumber-boxed each
    // forward — that per-step host overhead was ~1024 boxings/step and dominated the draft cost). Direct memory.
    private let inputID: MLMultiArray
    private let cosArr: MLMultiArray
    private let sinArr: MLMultiArray
    private let ohArr: MLMultiArray
    private let biasArr: MLMultiArray
    private let provider: MLDictionaryFeatureProvider
    private var prevOneHotPos: Int = -1   // the slot currently holding the 1 in write_onehot
    private var biasBoundary: Int = -1    // highest position currently set to 0 in attn_bias (0..boundary attended)

    /// Number of COMMITTED tokens; the next committed slot. The KV at physical slots `0..<draftPos` holds the
    /// committed sequence's K/V; the last committed token's K/V is at slot `draftPos - 1`.
    public private(set) var draftPos: Int = 0

    public init(
        modelURL: URL,
        ropeCosURL: URL,
        ropeSinURL: URL,
        maxSeq: Int = 512,
        headDim: Int = 64,
        negInfinity: Float = -1e4,
        computeUnits: MLComputeUnits = .all
    ) throws {
        self.maxSeq = maxSeq
        self.headDim = headDim
        self.neg = negInfinity
        let cfg = MLModelConfiguration()
        cfg.computeUnits = computeUnits
        do {
            let compiled = modelURL.pathExtension == "mlmodelc"
                ? modelURL : try MLModel.compileModel(at: modelURL)
            self.model = try MLModel(contentsOf: compiled, configuration: cfg)
        } catch { throw DraftError.modelLoad("\(error)") }
        self.state = model.makeState()
        self.cosTable = try Self.loadTable(ropeCosURL, count: maxSeq * headDim)
        self.sinTable = try Self.loadTable(ropeSinURL, count: maxSeq * headDim)
        // Allocate the reusable input buffers once. attn_bias starts fully masked (−inf); write_onehot all zero.
        self.inputID = try MLMultiArray(shape: [1, 1], dataType: .int32)
        self.cosArr = try MLMultiArray(shape: [NSNumber(value: headDim)], dataType: .float32)
        self.sinArr = try MLMultiArray(shape: [NSNumber(value: headDim)], dataType: .float32)
        self.ohArr = try MLMultiArray(shape: [NSNumber(value: maxSeq)], dataType: .float32)
        self.biasArr = try MLMultiArray(shape: [NSNumber(value: maxSeq)], dataType: .float32)
        self.provider = try MLDictionaryFeatureProvider(dictionary: [
            "input_id": inputID, "rope_cos": cosArr, "rope_sin": sinArr,
            "write_onehot": ohArr, "attn_bias": biasArr,
        ])
        let oh = ohArr.dataPointer.assumingMemoryBound(to: Float.self)
        let bias = biasArr.dataPointer.assumingMemoryBound(to: Float.self)
        for j in 0..<maxSeq { oh[j] = 0; bias[j] = negInfinity }
    }

    private static func loadTable(_ url: URL, count: Int) throws -> [Float] {
        guard let data = try? Data(contentsOf: url), data.count == count * MemoryLayout<Float>.size else {
            throw DraftError.ropeTable("expected \(count) f32 at \(url.lastPathComponent), got \(((try? Data(contentsOf: url))?.count ?? -1))")
        }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    // MARK: - One forward (writes K/V at `pos`, returns the argmax of the next-token logits)

    /// Feed `token` at absolute position `pos`: writes the token's K/V into the cache slot `pos` (one-hot write)
    /// and returns the model's argmax over the output logits (the draft's prediction of the NEXT token).
    @discardableResult
    public func step(token: Int, pos: Int) throws -> Int {
        guard pos < maxSeq else { throw DraftError.windowOverflow(pos: pos, maxSeq: maxSeq) }
        // Update the reused buffers IN PLACE, O(headDim + |Δpos|) — never reallocate / NSNumber-box per step.
        inputID.dataPointer.assumingMemoryBound(to: Int32.self)[0] = Int32(token)
        let cosP = cosArr.dataPointer.assumingMemoryBound(to: Float.self)
        let sinP = sinArr.dataPointer.assumingMemoryBound(to: Float.self)
        let base = pos * headDim
        cosTable.withUnsafeBufferPointer { cosP.update(from: $0.baseAddress! + base, count: headDim) }
        sinTable.withUnsafeBufferPointer { sinP.update(from: $0.baseAddress! + base, count: headDim) }
        // write_onehot: move the single 1 from its old slot to `pos`.
        let ohP = ohArr.dataPointer.assumingMemoryBound(to: Float.self)
        if prevOneHotPos >= 0 { ohP[prevOneHotPos] = 0 }
        ohP[pos] = 1
        prevOneHotPos = pos
        // attn_bias step function: 0 for 0..pos, −inf above. Only patch the delta from the previous boundary.
        let biasP = biasArr.dataPointer.assumingMemoryBound(to: Float.self)
        if pos > biasBoundary {
            for j in (biasBoundary + 1)...pos { biasP[j] = 0 }
        } else if pos < biasBoundary {
            for j in (pos + 1)...biasBoundary { biasP[j] = neg }
        }
        biasBoundary = pos
        let out: MLFeatureProvider
        do { out = try model.prediction(from: provider, using: state) }
        catch { throw DraftError.predict("\(error)") }
        guard let logits = out.featureValue(for: "logits")?.multiArrayValue else {
            throw DraftError.predict("no logits output")
        }
        return Self.argmax(logits)
    }

    private static func argmax(_ a: MLMultiArray) -> Int {
        let n = a.count
        var best = 0
        var bestV = -Float.greatestFiniteMagnitude
        a.withUnsafeBytes { raw in
            switch a.dataType {
            case .float32:
                let p = raw.bindMemory(to: Float.self)
                for i in 0..<n where p[i] > bestV { bestV = p[i]; best = i }
            case .float16:
                // read as UInt16 → Float via the runtime's Float16 if available
                let p = raw.bindMemory(to: UInt16.self)
                for i in 0..<n {
                    let v = Float(Float16(bitPattern: p[i]))
                    if v > bestV { bestV = v; best = i }
                }
            default:
                for i in 0..<n {
                    let v = a[i].floatValue
                    if v > bestV { bestV = v; best = i }
                }
            }
        }
        return best
    }

    // MARK: - Primitives the decoder composes

    /// Fresh KV + frontier for a new generation (reuse the loaded model across workloads without reloading).
    /// Also resets the incremental input buffers: clear write_onehot, re-mask attn_bias fully.
    public func reset() {
        state = model.makeState()
        draftPos = 0
        let ohP = ohArr.dataPointer.assumingMemoryBound(to: Float.self)
        let biasP = biasArr.dataPointer.assumingMemoryBound(to: Float.self)
        if prevOneHotPos >= 0 { ohP[prevOneHotPos] = 0 }
        if biasBoundary >= 0 { for j in 0...biasBoundary { biasP[j] = neg } }
        prevOneHotPos = -1
        biasBoundary = -1
    }

    /// Sync the draft KV to a committed prefix: feed each token at its position. Sets `draftPos = tokens.count`.
    /// Call once before the speculative loop with [prompt tokens..., first emitted token].
    public func prefill(_ tokens: [Int]) throws {
        guard tokens.count <= maxSeq else { throw DraftError.windowOverflow(pos: tokens.count, maxSeq: maxSeq) }
        for (i, t) in tokens.enumerated() { _ = try step(token: t, pos: i) }
        draftPos = tokens.count
    }

    /// Propose K continuation tokens from the committed frontier. Feeds `seed` (the last committed token, whose
    /// K/V is at `draftPos-1`) then each proposal — K+1 forwards so EVERY proposal's K/V is written at its slot
    /// (`draftPos..draftPos+K-1`), which removes the all-accepted edge case in `commit`. Does NOT advance
    /// `draftPos` (nothing is committed yet). Returns `[d_0 … d_{K-1}]`.
    public func propose(seed: Int, k: Int) throws -> [Int] {
        guard k > 0 else { return [] }
        guard draftPos - 1 + k < maxSeq else { throw DraftError.windowOverflow(pos: draftPos - 1 + k, maxSeq: maxSeq) }
        var proposals: [Int] = []
        var input = seed
        var pos = draftPos - 1
        // Step 0 re-feeds the seed at its own slot (identical K/V) to predict d_0; steps 1..K feed d_{i-1} to
        // write its K/V AND predict d_i. We keep d_0..d_{K-1}; the (K+1)-th output is discarded.
        for i in 0...k {
            let out = try step(token: input, pos: pos)
            if i < k { proposals.append(out) }
            input = out
            pos += 1
        }
        return proposals
    }

    /// Commit the accepted prefix length `acc` plus the target's correction token `correction`. The accepted
    /// proposals already have correct K/V (written during `propose`); only the correction needs a forward (its
    /// K/V was never written). Advances `draftPos` by `acc + 1`.
    public func commit(acc: Int, correction: Int) throws {
        let cPos = draftPos + acc
        guard cPos < maxSeq else { throw DraftError.windowOverflow(pos: cPos, maxSeq: maxSeq) }
        _ = try step(token: correction, pos: cPos)   // write the correction's K/V at its slot
        draftPos += acc + 1
    }

    /// Remaining window before the hard MAX_SEQ cap (the decoder stops speculating near the boundary).
    public func remainingWindow() -> Int { maxSeq - draftPos }

    /// The hard KV-window cap (MAX_SEQ from the converter). The decoder must keep all positions `< maxSeqCount`.
    public var maxSeqCount: Int { maxSeq }
}
#endif
