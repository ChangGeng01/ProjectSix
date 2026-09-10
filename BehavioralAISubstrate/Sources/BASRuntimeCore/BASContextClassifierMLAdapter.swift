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
// **Corpus state (current):** trained on 233 hand-labeled
// examples spanning 8 languages (English, Chinese,
// Japanese, Spanish, French, German, Russian, Arabic)。
// Held-out accuracy: 13/14 = 92.9% on 14-example held-out
// set。 Manipulation held-out: 2/2。 Six hard manipulation
// invariants enforced across non-English languages
// (Chinese, Spanish, French, Arabic, Russian, Japanese
// password phishing all reach verdict=.block)。 The
// model is a tiny 2-layer MLP (~18K params) — sufficient
// for the current Phase-B classification surface but
// future Phase C/D may want a real transformer encoder。
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
// charter adjudication (2026-07-12): this CoreML micro-head (18K params, pinned weights)
// deliberately lives in the deterministic core — it is substrate-owned cognition machinery
// (no generation, no provider routing, boots with the brain), NOT an LLM and NOT part of
// the model-adapter ring. The model-agnostic charter's LLM-outside rule is enforced at
// BASAppleAdapters/FoundationModels/MLX level (BASModelBoundaryPinTests); this file is the
// documented, operator-overrulable exception for in-core neural code.
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

    /// Load the model from Bundle.module。
    ///
    /// chapter 一千零二十五.5 / M3899 — dual lookup path:
    /// - SPM `swift test` ships raw `.mlmodel` (Resources rule),so
    ///   the adapter compiles at runtime via `MLModel.compileModel`。
    /// - Xcode iOS app builds pre-compile `.mlmodel` → `.mlmodelc`
    ///   at build time AND strip the raw source,so only the
    ///   compiled artifact survives in the .app bundle。
    /// Pre-1025.5 only checked `.mlmodel` → app-target init threw
    /// `modelResourceMissing`,blocking `BASCognitiveBrain.
    /// makeWithDefaults()` from any iOS app process。
    /// Discovered by ch 1025.5 in-app endurance runner attempting
    /// brain.process() per prompt。 Substrate fix prefers
    /// pre-compiled `.mlmodelc` (Xcode path) and falls back to raw
    /// `.mlmodel` + runtime compile (SPM path)。
    public convenience init(cacheCapacity: Int = 256) throws {
        try self.init(cacheCapacity: cacheCapacity, computeUnits: nil)
    }

    /// T1.2 (ANE measurement) — ADDITIVE designated init with an optional compute-units override. `nil` (every
    /// existing caller) loads exactly as before (CoreML default units) — byte-identical. A non-nil value lets
    /// the ANE utilization probe A/B `.cpuOnly` vs `.all` on the SAME model artifact. Observation-only surface;
    /// no production path passes a value.
    public init(
        cacheCapacity: Int = 256,
        computeUnits: MLComputeUnits?
    ) throws {
        self.cacheCapacity = max(0, cacheCapacity)
        self.model = try Self.loadModelSelfHealing(computeUnits: computeUnits)
    }

    private static func instantiate(_ url: URL, computeUnits: MLComputeUnits?) throws -> MLModel {
        if let computeUnits {
            let config = MLModelConfiguration()
            config.computeUnits = computeUnits
            return try MLModel(contentsOf: url, configuration: config)
        }
        return try MLModel(contentsOf: url)
    }

    /// Load the compiled model, SELF-HEALING a poisoned runtime-compile cache。 The cache entry
    /// (`.cachesDirectory/…`) could have been evicted by the OS between selection and load, or
    /// corrupted post-install — either would throw here。 On load failure we invalidate the CACHE
    /// entry (never a bundled resource) and recompile ONCE from the raw source before giving up,
    /// so a transient fault cannot permanently brick every SPM-path brain construction。
    private static func loadModelSelfHealing(
        computeUnits: MLComputeUnits?
    ) throws -> MLModel {
        let compiledURL = try compiledModelURL()
        do {
            return try instantiate(compiledURL, computeUnits: computeUnits)
        } catch {
            guard let fresh = recompiledModelURLBypassingCache(poisoned: compiledURL),
                  fresh != compiledURL
            else {
                throw BASContextClassifierMLAdapterError.modelLoadFailed(message: "\(error)")
            }
            do {
                return try instantiate(fresh, computeUnits: computeUnits)
            } catch {
                throw BASContextClassifierMLAdapterError.modelLoadFailed(message: "\(error)")
            }
        }
    }

    /// Purge a poisoned cache entry (ONLY if it lives under `.cachesDirectory` — never a bundled
    /// resource) and recompile fresh from the raw source。 Returns nil when there is no raw source
    /// (the Xcode fast-path bundle ships only `.mlmodelc`), so a genuinely-bad bundle surfaces the
    /// original error rather than being silently masked。
    private static func recompiledModelURLBypassingCache(poisoned: URL) -> URL? {
        guard let rawURL = Bundle.module.url(
            forResource: "BASContextClassifier", withExtension: "mlmodel") else { return nil }
        if let cachesRoot = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first,
           poisoned.path.hasPrefix(cachesRoot.path) {
            try? FileManager.default.removeItem(at: poisoned)   // drop the poisoned CACHE entry only
        }
        return try? cachedCompiledModelURL(rawURL: rawURL)      // recompile + re-cache
    }

    /// T1.2 — the COMPILED model artifact URL (the same dual-lookup the init uses: prefer the pre-compiled
    /// `.mlmodelc` from the Xcode app bundle; fall back to raw `.mlmodel` + runtime compile on the SPM path).
    /// Public so the ANE utilization probe can hand the artifact to `MLComputePlan` — observation-only.
    public static func compiledModelURL() throws -> URL {
        // Prefer pre-compiled .mlmodelc(Xcode iOS app bundle path)
        if let compiledURL = Bundle.module.url(
            forResource: "BASContextClassifier",
            withExtension: "mlmodelc") {
            return compiledURL
        }
        // Fall back to raw .mlmodel + runtime compile
        // (SPM `swift test` path,Resources ship raw)
        guard let rawURL = Bundle.module.url(
            forResource: "BASContextClassifier",
            withExtension: "mlmodel")
        else {
            throw BASContextClassifierMLAdapterError
                .modelResourceMissing
        }
        // chapter 一千零X (mega-audit 2026-07-08) — CACHE the runtime compile。
        //
        // Pre-fix this called `MLModel.compileModel(at:)` on EVERY invocation, each producing a
        // fresh `.mlmodelc` bundle in NSTemporaryDirectory() that was never deleted。 Latent for
        // years (any SPM-path brain construction leaked one), it fired repeatedly once the
        // BASJournalCLI "The Ledger" workload began constructing a brain per `add` — one leaked
        // bundle per invocation。 Now: compile ONCE into a stable caches dir keyed by the raw
        // model's CONTENT HASH, and reuse it thereafter — eliminating both the accumulation and
        // the per-construct recompile cost。 A changed model ⇒ different hash ⇒ recompile (no
        // staleness)。 The compile lands in the cache only via an atomic rename of a fully-compiled
        // temp, so a concurrent process or a crash never leaves a partial cache。
        return try cachedCompiledModelURL(rawURL: rawURL)
    }

    /// Content-hash-keyed stable cache for the SPM-path runtime compile (see `compiledModelURL`).
    /// Best-effort: on any caches-dir / hashing / install problem it degrades to a direct compile
    /// (correct, just uncached this run) rather than failing brain construction.
    /// Internal (not private) so the leak-regression test can drive it against the raw source model
    /// directly — in dev/CI bundles the raw `.mlmodel` is stripped, so the ambient path can't be
    /// exercised, but the caching CONTRACT (stable URL, no per-call accumulation) can be.
    static func cachedCompiledModelURL(rawURL: URL) throws -> URL {
        let fm = FileManager.default
        // Key on the raw model's content so a rebuilt/changed model recompiles (staleness safety).
        // The .mlmodel source is a single small file (~68 KB) — hashing it is cheap。
        guard let rawData = try? Data(contentsOf: rawURL),
              let cachesRoot = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            return try compileRawModel(rawURL)   // can't key/site the cache — compile directly
        }
        let key = SHA256.hash(data: rawData)
            .prefix(8).map { String(format: "%02x", $0) }.joined()
        let cacheDir = cachesRoot
            .appendingPathComponent("BASContextClassifier", isDirectory: true)
        let cachedURL = cacheDir
            .appendingPathComponent("BASContextClassifier-\(key).mlmodelc", isDirectory: true)

        if isCompiledModelPresent(cachedURL) { return cachedURL }

        let compiled = try compileRawModel(rawURL)   // fresh temp .mlmodelc
        do {
            try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            // A VALID cache is already present (another process won the race) — use it。
            if isCompiledModelPresent(cachedURL) {
                try? fm.removeItem(at: compiled)
                return cachedURL
            }
            // A stale/corrupt bundle may still OCCUPY cachedURL (a non-valid dir — e.g. one missing
            // coremldata.bin)。 moveItem won't overwrite an existing path, so clear the occupant
            // first, then install。 (Concurrent installers racing here all write the SAME compiled
            // bytes, so the converged cache is always valid — worst case is a little redundant work.)
            try? fm.removeItem(at: cachedURL)
            try fm.moveItem(at: compiled, to: cachedURL)   // atomic rename (same volume)
            // A fresh key was installed ⇒ the model version may have changed; drop retired siblings.
            pruneStaleSiblings(cacheDir: cacheDir, keep: cachedURL.lastPathComponent)
            return cachedURL
        } catch {
            // Install failed (race / cross-volume / perms)。 Prefer the now-present cache; else use
            // the freshly-compiled temp in place (still a valid model — just uncached this run)。
            if isCompiledModelPresent(cachedURL) {
                try? fm.removeItem(at: compiled)
                return cachedURL
            }
            return compiled
        }
    }

    private static func compileRawModel(_ rawURL: URL) throws -> URL {
        do {
            return try MLModel.compileModel(at: rawURL)
        } catch {
            throw BASContextClassifierMLAdapterError
                .modelLoadFailed(message: "\(error)")
        }
    }

    /// A compiled `.mlmodelc` is a directory bundle。 Treat the cache as present only if it is a
    /// directory that contains its core member `coremldata.bin` — NOT merely non-empty。 A
    /// structurally-broken bundle (OS-truncated, partially corrupted, or written by an
    /// older/buggy build) would otherwise pass a non-empty check, be returned, then fail to load —
    /// and because the key is the raw model's content hash, the SAME poisoned entry would be
    /// re-selected forever。 Requiring `coremldata.bin` makes a partial bundle count as ABSENT so
    /// it is recompiled at selection time (belt to the load-time self-heal in `loadModelSelfHealing`)。
    private static func isCompiledModelPresent(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else { return false }
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("coremldata.bin").path)
    }

    /// Best-effort prune of stale sibling caches — one dead `.mlmodelc` accrues per RETIRED model
    /// version otherwise (a slow, bounded leak)。 Keeps only the live-key bundle。 Never throws。
    private static func pruneStaleSiblings(cacheDir: URL, keep liveName: String) {
        let fm = FileManager.default
        guard let siblings = try? fm.contentsOfDirectory(atPath: cacheDir.path) else { return }
        for name in siblings
        where name != liveName
            && name.hasPrefix("BASContextClassifier-")
            && name.hasSuffix(".mlmodelc") {
            try? fm.removeItem(at: cacheDir.appendingPathComponent(name))
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
            // ch1044 audit fix (concurrency): dedup before append. Two concurrent
            // misses for the SAME `text` could each append it to cacheOrder while
            // `cache` holds one entry → cacheOrder.count > cache.count → premature
            // eviction of a live entry + unbounded cacheOrder growth. Removing any
            // existing index first keeps the invariant cacheOrder.count == cache.count
            // (and doubles as a correct LRU "touch"). Byte-equal single-threaded.
            if let existing = cacheOrder.firstIndex(of: text) {
                cacheOrder.remove(at: existing)
            }
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
