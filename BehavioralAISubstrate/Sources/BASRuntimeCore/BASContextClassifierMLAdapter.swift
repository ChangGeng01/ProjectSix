// MARK: - BASContextClassifierMLAdapter
// chapter 七百三十七 / M2251 — Phase B-3 — Swift CoreML
//                              adapter for the first REAL
//                              ML head in the 14-layer
//                              电子脑。
//
// ## What this is
//
// The FIRST real-inference adapter shipped to the
// substrate。 Loads `BASContextClassifier.mlmodel`
// (chapter 七百三十六 Phase B-2 artifact) from Bundle
// .module and exposes a typed `classify(text:)` async
// API。
//
// ## Why it matters
//
// Before this chapter, the substrate had ZERO real ML
// adapters (BAS14LayerMeshAssembler:118 admits "today's
// substrate has ZERO real .mlpackage adapters"). Phase B-3
// closes that fiction with ONE real adapter。 Phase B-4
// will wire this adapter into BASPlaceholderContext
// Service's replacement, so the cognitive cascade gets
// real taskType inference from real ML。
//
// ## Pipeline
//
//   text input
//     → BASContextClassifierInputEncoder.encode (Swift)
//     → bag-of-256-buckets Float32 vector
//     → MLModel.prediction (CoreML runtime)
//     → 7 logits Float32 vector
//     → argmax → BASContextTaskType
//
// The Swift encoder MUST produce byte-identical bucket
// indices to the Python encoder used at training time。
// SHA256-prefix algorithm is the parity contract — same
// uint32 from first 4 bytes of SHA256 % 256。
//
// ## Honest scope acknowledgments
//
// **Phase B-1 trained on 105 examples (15 per class).**
// The model overfits the training set (100% train acc)
// and is unlikely to generalize well。 Phase B-2 will
// expand the corpus + add proper train/val/test split。
//
// **Phase B-3 ships the ADAPTER**, not a high-accuracy
// classifier。 The integration test verifies:
//   1. Model loads from Bundle.module successfully
//   2. classify(text:) returns a non-nil BASContextTaskType
//   3. Determinism: same input → same output
//   4. The 7 known training examples classify correctly
//      (memorization sanity check)
//
// **What it does NOT yet verify**:
//   - Generalization to unseen inputs (deferred to B-2
//     with held-out test set)
//   - Latency under load (deferred to B-4 benchmark)
//   - ANE acceleration vs CPU (deferred to perf chapter)

import Foundation
import CryptoKit

#if canImport(CoreML)
import CoreML
#endif

// MARK: - Input encoder (Swift mirror of Python train.py
// hash_bucket function)

/// Deterministic text → bag-of-N-buckets encoder。 Must
/// produce byte-identical bucket indices to the Python
/// trainer's `hash_bucket` function — SHA256 first-4-bytes
/// as big-endian uint32 % numBuckets。
///
/// Parity-tested against Python output via
/// `BASContextClassifierInputEncoderParityTests` in
/// Phase B-3 (this chapter)。
public enum BASContextClassifierInputEncoder {

    /// Number of hash buckets in the bag-of-tokens encoder。
    /// Must match train.py `NUM_BUCKETS`。
    public static let numBuckets: Int = 256

    /// Tokenize:lowercase + whitespace split mirroring
    /// Python `text.lower().split()` semantics — splits
    /// on ANY whitespace (space,tab,newline,multiple
    /// consecutive whitespace) and drops empty tokens。
    ///
    /// Earlier this method used `split(separator: " ")`
    /// which only split on the ASCII space character —
    /// inputs containing tabs or newlines produced
    /// different token sequences than the Python trainer,
    /// silently breaking inference parity for any text
    /// with non-space whitespace。 Fixed via
    /// `whereSeparator: { $0.isWhitespace }` to match
    /// Python's `str.split()`。
    public static func tokenize(_ text: String) -> [String] {
        return text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Hash a token to a bucket index。 SHA256-prefix
    /// algorithm matches Python `hash_bucket(token,
    /// num_buckets)`。
    public static func hashBucket(
        _ token: String,
        numBuckets: Int = BASContextClassifierInputEncoder
            .numBuckets
    ) -> Int {
        let digest = SHA256.hash(
            data: Data(token.utf8))
        // Take first 4 bytes as big-endian UInt32
        var iter = digest.makeIterator()
        let b0 = UInt32(iter.next()!) << 24
        let b1 = UInt32(iter.next()!) << 16
        let b2 = UInt32(iter.next()!) << 8
        let b3 = UInt32(iter.next()!)
        let combined = b0 | b1 | b2 | b3
        return Int(combined % UInt32(numBuckets))
    }

    /// Encode text → bag-of-buckets Float32 array。
    /// L2-normalized to match Python encoder。
    public static func encode(_ text: String) -> [Float] {
        var vec = Array(
            repeating: Float(0.0),
            count: numBuckets)
        for tok in tokenize(text) {
            vec[hashBucket(tok)] += 1.0
        }
        var sumSq: Float = 0
        for v in vec { sumSq += v * v }
        let norm = sumSq.squareRoot()
        if norm > 0 {
            for i in vec.indices { vec[i] /= norm }
        }
        return vec
    }
}

// MARK: - Adapter errors

public enum BASContextClassifierMLAdapterError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// Bundle.module did not contain the .mlmodel resource。
    case modelResourceMissing
    /// MLModel(contentsOf:) failed to load the resource。
    case modelLoadFailed(message: String)
    /// CoreML compilation failed。
    case modelCompilationFailed(message: String)
    /// CoreML prediction failed at runtime。
    case predictionFailed(message: String)
    /// Output tensor shape didn't match expected 1×7。
    case unexpectedOutputShape(message: String)
    /// CoreML framework not available on this build host
    /// (e.g. Linux during cross-compile inspection)。
    case coreMLUnavailableOnPlatform
}

// MARK: - Adapter

#if canImport(CoreML)

/// Loads BASContextClassifier.mlmodel + exposes a typed
/// `classify(text:)` API returning the predicted
/// BASContextTaskType。
///
/// **Architecture note (Phase B-4)**: This is a
/// `final class @unchecked Sendable` instead of an actor
/// because `BASContextServicing.analyzeContext(...)` is
/// SYNCHRONOUS (not async),which forces the underlying
/// model-call to be synchronous too。 Apple documents
/// `MLModel.prediction(from:)` as thread-safe + the model
/// is immutable after init,so concurrent calls from
/// multiple cognitive-OS coordinators are safe。
///
/// **Caching note (this commit)**: A bounded LRU cache
/// keyed by input text avoids re-running CoreML inference
/// for repeated identical inputs。 Real apps that classify
/// the same user input multiple times (replay,A/B test,
/// retry) benefit measurably。 Cache size is bounded to
/// avoid unbounded memory growth on adversarial inputs。
public final class BASContextClassifierMLAdapter: @unchecked Sendable {

    /// 7 labels in the same order as Python label_index.json
    /// (matches the .mlmodel output dimension)。
    public static let labels: [String] = [
        "chat",
        "task",
        "choice",
        "conflict",
        "highPressure",
        "manipulationRisk",
        "highConsequence"
    ]

    private let model: MLModel

    /// Bounded LRU cache。 Default size 256 inputs。
    /// Concurrent access is guarded by `cacheLock`。
    private struct CachedResult: Sendable {
        let label: String
        let confidence: Double
        let logits: [Float]
    }
    private let cacheLock = NSLock()
    // `nonisolated(unsafe)` because the class is
    // `@unchecked Sendable` — we serialize via cacheLock。
    private nonisolated(unsafe) var cache:
        [String: CachedResult] = [:]
    private nonisolated(unsafe) var cacheOrder:
        [String] = []
    private nonisolated(unsafe) var _cacheHitCount: Int = 0
    private nonisolated(unsafe) var _cacheMissCount: Int = 0

    /// Bounded cache capacity。 Default 256 entries (~few
    /// KB memory)。
    public let cacheCapacity: Int

    /// Number of cache hits since construction。 Used by
    /// tests + telemetry。 Reads under lock for thread
    /// safety。
    public var cacheHitCount: Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return _cacheHitCount
    }

    /// Number of cache misses since construction。
    public var cacheMissCount: Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return _cacheMissCount
    }

    // MARK: - Construction

    /// Load the .mlmodel from Bundle.module。 Compiles
    /// + caches at construction time so prediction calls
    /// are fast。
    public init(cacheCapacity: Int = 256) throws {
        self.cacheCapacity = max(0, cacheCapacity)
        guard let url = Bundle.module.url(
            forResource: "BASContextClassifier",
            withExtension: "mlmodel")
        else {
            throw BASContextClassifierMLAdapterError
                .modelResourceMissing
        }
        do {
            // .mlmodel must be compiled to .mlmodelc at
            // runtime (Xcode would pre-compile in app
            // builds, but SPM Resources ship raw .mlmodel)
            let compiledURL = try MLModel.compileModel(
                at: url)
            self.model = try MLModel(
                contentsOf: compiledURL)
        } catch {
            throw BASContextClassifierMLAdapterError
                .modelLoadFailed(
                    message: "\(error)")
        }
    }

    // MARK: - Inference

    /// Classify a text input。 Returns:
    ///   - label: predicted class name (one of 7)
    ///   - confidence: softmax probability of the predicted
    ///     class, in [0, 1]
    ///   - logits: raw logits vector for advanced callers
    ///
    /// `confidence` is computed as softmax(logits)[argmax]。
    /// A confidence of ~1/7 ≈ 0.14 means the model is
    /// guessing uniformly;a confidence of >0.9 means the
    /// model is highly certain。 Consumers like
    /// BASMLContextService use this to derive
    /// `ambiguityScore = 1 - confidence`。
    public func classify(
        text: String
    ) throws -> (label: String, confidence: Double, logits: [Float]) {
        // 0. Cache lookup (LRU)
        if cacheCapacity > 0 {
            cacheLock.lock()
            if let cached = cache[text] {
                _cacheHitCount += 1
                // Move to recently-used end
                if let idx = cacheOrder.firstIndex(
                    of: text)
                {
                    cacheOrder.remove(at: idx)
                    cacheOrder.append(text)
                }
                cacheLock.unlock()
                return (cached.label, cached.confidence,
                        cached.logits)
            }
            _cacheMissCount += 1
            cacheLock.unlock()
        }

        // 1. Encode text → bag-of-buckets
        let bag = BASContextClassifierInputEncoder.encode(
            text)
        // 2. Build MLMultiArray input (1×256 Float32)
        guard let input = try? MLMultiArray(
            shape: [1, NSNumber(
                value: BASContextClassifierInputEncoder
                    .numBuckets)],
            dataType: .float32)
        else {
            throw BASContextClassifierMLAdapterError
                .predictionFailed(
                    message: "MLMultiArray allocation failed")
        }
        for (i, v) in bag.enumerated() {
            input[i] = NSNumber(value: v)
        }
        // 3. Build prediction input dict
        let provider = try MLDictionaryFeatureProvider(
            dictionary: ["bag_of_buckets": input])
        // 4. Predict
        let output: MLFeatureProvider
        do {
            output = try model.prediction(from: provider)
        } catch {
            throw BASContextClassifierMLAdapterError
                .predictionFailed(
                    message: "\(error)")
        }
        // 5. Extract logits
        // The output feature name depends on coremltools
        // conversion;we read the FIRST multiarray output。
        let outputFeatureNames = output.featureNames
        guard let firstName = outputFeatureNames.first,
              let logitsArray = output.featureValue(
                for: firstName)?.multiArrayValue
        else {
            throw BASContextClassifierMLAdapterError
                .unexpectedOutputShape(
                    message: "no multiArray output found")
        }
        // 6. Convert to [Float] + argmax
        var logits = [Float]()
        logits.reserveCapacity(logitsArray.count)
        for i in 0..<logitsArray.count {
            logits.append(logitsArray[i].floatValue)
        }
        guard logits.count ==
            BASContextClassifierMLAdapter.labels.count
        else {
            throw BASContextClassifierMLAdapterError
                .unexpectedOutputShape(
                    message: "got \(logits.count) logits," +
                        " expected " +
                        "\(BASContextClassifierMLAdapter.labels.count)")
        }
        let argmax = logits.indices.max(by: {
            logits[$0] < logits[$1]
        }) ?? 0
        // Softmax for confidence score。 Numerical-stable
        // form:subtract max before exp。
        let maxLogit = logits.max() ?? 0
        var expSum: Double = 0
        var expArgmax: Double = 0
        for (i, l) in logits.enumerated() {
            let e = exp(Double(l - maxLogit))
            expSum += e
            if i == argmax { expArgmax = e }
        }
        let confidence = expSum > 0
            ? expArgmax / expSum : 1.0 / Double(logits.count)
        let label =
            BASContextClassifierMLAdapter.labels[argmax]

        // Cache write (LRU eviction if at capacity)
        if cacheCapacity > 0 {
            cacheLock.lock()
            cache[text] = CachedResult(
                label: label,
                confidence: confidence,
                logits: logits)
            cacheOrder.append(text)
            while cacheOrder.count > cacheCapacity {
                let evict = cacheOrder.removeFirst()
                cache.removeValue(forKey: evict)
            }
            cacheLock.unlock()
        }

        return (label, confidence, logits)
    }
}

#else

/// Stub for platforms without CoreML (Linux build hosts)。
/// All methods throw `.coreMLUnavailableOnPlatform`。
public final class BASContextClassifierMLAdapter: @unchecked Sendable {
    public static let labels: [String] = [
        "chat",
        "task",
        "choice",
        "conflict",
        "highPressure",
        "manipulationRisk",
        "highConsequence"
    ]

    public let cacheCapacity: Int
    public var cacheHitCount: Int { 0 }
    public var cacheMissCount: Int { 0 }

    public init(cacheCapacity: Int = 256) throws {
        self.cacheCapacity = cacheCapacity
        throw BASContextClassifierMLAdapterError
            .coreMLUnavailableOnPlatform
    }

    public func classify(
        text: String
    ) throws -> (label: String, confidence: Double, logits: [Float]) {
        throw BASContextClassifierMLAdapterError
            .coreMLUnavailableOnPlatform
    }
}

#endif
