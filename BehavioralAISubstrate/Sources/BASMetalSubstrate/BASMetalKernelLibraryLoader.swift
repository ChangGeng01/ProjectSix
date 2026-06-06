// MARK: - BASMetalKernelLibraryLoader
// chapter 七百四 / M2180 第二刀 — Metal pilot:actor that
//                                 loads the SSMScan.metal
//                                 resource from
//                                 Bundle.module and
//                                 compiles it to an
//                                 MTLLibrary lazily on
//                                 first request。
//
// ## Why this exists
//
// MULTI-LANGUAGE AUGMENTATION ARC chapter 七百四 ships
// the Metal pilot — proving that SPM can host a `.metal`
// shader source as a `.process()` resource AND that
// substrate code can load + compile it at runtime via
// the standard `MTLLibrary.makeLibrary(source:options:)`
// path (NOT requiring an Xcode-style `.air` /
// `.metallib` precompile step)。
//
// SSMScan.metal exists since chapter 六百七十七 / M2089
// as a reference shader the Phase M selective-scan
// implementation can compare against。 chapter 699 /
// M2163 silenced the persistent SPM "unhandled file"
// warning by excluding it from the build。 chapter 七百四
// 第一刀 (M2179) re-enables it via `.process()`;THIS
// commit (第二刀) loads + compiles it。
//
// ## ADR-014 OPT-IN preserved
//
// Opt-in via `BASLanguageAugmentationFeatureFlags
// .metalKernelV2Enabled` (default FALSE)。 V1 kernel
// selection (BASMPSGraphSSMScanKernelStub +
// BASSSMScanCPUReference) UNCHANGED for default callers。
// Loader exposes a `library()` async accessor that
// returns the compiled MTLLibrary only when the flag
// is on at construction time。
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 — loader is observation only
//     (loads + compiles + returns reference,never
//     mutates host runtime)。
//   - 红线 7 — no permit / watcher gate touched。
//   - chapter 一百八十五 anti-magic-number — typed
//     loader error cases,resource name pinned。
//
// ## Platform gating
//
// `#if canImport(Metal)` guard:on watchOS (no Metal
// framework) the entire actor compiles to a thin stub
// that throws `.metalUnavailableOnPlatform`。 Apple
// platforms with Metal get the real loader。

import Foundation
import BASRuntimeCore
#if canImport(Metal)
import Metal
#endif

/// Typed loader errors。
public enum BASMetalKernelLibraryLoaderError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// Compilation host does not have the Metal framework
    /// (watchOS,Linux build hosts)。 Loader returns
    /// this case immediately on `library()`。
    case metalUnavailableOnPlatform

    /// `MTLCreateSystemDefaultDevice()` returned nil —
    /// the host has the Metal framework but no GPU is
    /// present (extremely rare on Apple Silicon;more
    /// likely on a CI runner without GPU access)。
    case mtlDeviceUnavailable

    /// `Bundle.module.url(forResource:withExtension:)`
    /// returned nil。 The .metal resource is missing
    /// from the build product — usually means the
    /// Package.swift `.process(...)` declaration was
    /// removed by a future commit。 Loader test pins
    /// this case to catch that regression。
    case resourceURLMissing(resourceName: String)

    /// `String(contentsOf:)` failed to read the .metal
    /// file (filesystem error)。
    case resourceReadFailed(message: String)

    /// `MTLLibrary.makeLibrary(source:options:)` threw
    /// (shader compile error)。
    case metalCompilationFailed(message: String)

    /// Stable telemetry-friendly identifier for the error
    /// case discriminator,independent of associated value
    /// data。 See chapter 七百二十 / M2219 for the cross-
    /// pilot caseIdentifier contract。
    public var caseIdentifier: String {
        switch self {
        case .metalUnavailableOnPlatform:
            return "metalUnavailableOnPlatform"
        case .mtlDeviceUnavailable:
            return "mtlDeviceUnavailable"
        case .resourceURLMissing:
            return "resourceURLMissing"
        case .resourceReadFailed:
            return "resourceReadFailed"
        case .metalCompilationFailed:
            return "metalCompilationFailed"
        }
    }
}

/// Loader actor。
///
/// Construction is cheap (no I/O,no compile);
/// `library()` performs the actual work lazily on first
/// call and memoizes the result for subsequent calls。
/// Each loader instance memoizes independently — sharing
/// across the substrate is achieved by sharing the actor
/// reference,not by static caching。
public actor BASMetalKernelLibraryLoader {

    /// Resource name (no extension)。 Pinned at the
    /// chapter 七百四 contract — bumping requires
    /// updating `BASMetalKernelLibraryLoaderTests`。
    public static let ssmScanResourceName: String = "SSMScan"

    /// Resource extension。
    public static let ssmScanResourceExtension: String = "metal"

    /// Resource bundle pin。 Tests assert this matches
    /// `Bundle.module` so a future SPM change that moves
    /// the bundle resolution can be detected。
    public static let expectedBundle: Bundle = Bundle.module

    /// Snapshot of the flag at construction time
    /// (sampled-once semantics matching M2173 / M2176
    /// pattern)。
    private let useMetalKernelV2: Bool

    #if canImport(Metal)
    /// Memoized MTLLibrary after first successful load。
    /// nil until first `library()` call;non-nil after
    /// (or never set if the V1 path stays selected)。
    private var memoized: MTLLibrary?
    #endif

    public init(useMetalKernelV2: Bool = false) {
        self.useMetalKernelV2 = useMetalKernelV2
        #if canImport(Metal)
        self.memoized = nil
        #endif
    }

    /// Whether this loader was constructed in V2 mode。
    public var isUsingV2: Bool { useMetalKernelV2 }

    /// Lazy compile + memoize。 Throws when:
    ///   - V2 path requested but Metal unavailable
    ///     (`.metalUnavailableOnPlatform`)
    ///   - V2 path requested but resource missing
    ///   - V2 path requested but compile fails
    ///
    /// V1 path callers should NOT invoke this — they
    /// continue using the V1 kernel registry。
    #if canImport(Metal)
    public func library() throws -> MTLLibrary {
        guard useMetalKernelV2 else {
            throw BASMetalKernelLibraryLoaderError
                .metalUnavailableOnPlatform
        }
        if let memoized {
            return memoized
        }
        guard let device = MTLCreateSystemDefaultDevice()
        else {
            throw BASMetalKernelLibraryLoaderError
                .mtlDeviceUnavailable
        }
        // chapter 七百七 第一刀 — load ALL .metal resources
        // from the bundle and concatenate into one source。
        // Previously only SSMScan.metal was loaded;the
        // additional kernel files (BASLayerNormKernel,
        // BASActivationKernels, BASSoftmaxKernels, BASConv
        // Kernels, BASReduceKernels, BASFlashAttention) all
        // need to be visible to the linker for makeFunction
        // to find their symbols。
        let metalNames = [
            Self.ssmScanResourceName,
            "BASLayerNormKernel",
            "BASActivationKernels",
            "BASSoftmaxKernels",
            "BASConvKernels",
            "BASReduceKernels",
            "BASFlashAttention",
        ]
        var combinedSource = ""
        for name in metalNames {
            guard let url = Self.expectedBundle.url(
                forResource: name,
                withExtension:
                    Self.ssmScanResourceExtension)
            else {
                // Missing file is fatal only for the very
                // first (SSMScan); newer kernel files can
                // be optionally absent during partial
                // backports / cherry-picks。
                if name == Self.ssmScanResourceName {
                    throw BASMetalKernelLibraryLoaderError
                        .resourceURLMissing(
                            resourceName: name)
                }
                continue
            }
            do {
                let body = try String(
                    contentsOf: url, encoding: .utf8)
                combinedSource +=
                    "\n// === \(name).metal ===\n"
                combinedSource += body
            } catch {
                throw BASMetalKernelLibraryLoaderError
                    .resourceReadFailed(
                        message:
                            "reading \(name).metal: " +
                            String(describing: error))
            }
        }
        let source = combinedSource
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(
                source: source, options: nil)
        } catch {
            throw BASMetalKernelLibraryLoaderError
                .metalCompilationFailed(
                    message: String(describing: error))
        }
        memoized = library
        return library
    }
    #else
    /// Stub on non-Metal platforms (watchOS,Linux build
    /// hosts)。 Always throws — guarantees runtime
    /// dispatch can branch on the error case rather
    /// than silently falling back。
    public func library() throws -> Never {
        throw BASMetalKernelLibraryLoaderError
            .metalUnavailableOnPlatform
    }
    #endif

    /// Whether the loader has memoized a compiled library。
    /// Tests use this to assert lazy-load semantics
    /// (first `library()` call sets it,subsequent calls
    /// return the cached reference)。
    public var hasMemoizedLibrary: Bool {
        #if canImport(Metal)
        return memoized != nil
        #else
        return false
        #endif
    }

    /// 主线 解构 重构 Round 3 — enumerate function names
    /// from the compiled MTLLibrary。 Pushes the enumeration
    /// into the Metal-side library introspection (the
    /// MTLLibrary owns the function table — that's where
    /// the names live)。 Returns an empty array when:
    ///   - V1 path (loader not in V2 mode)
    ///   - V2 path but library not yet compiled (call
    ///     `library()` first to trigger compile)
    ///   - V2 path but compile failed
    ///
    /// Hosts use this for observability / verification:
    /// "did the SSMScan.metal compile expose the expected
    /// kernel symbol?" The expected name is
    /// `ssm_scan_float32` (the actual `kernel void`
    /// declaration in SSMScan.metal) — tests can pin that
    /// expectation。
    public func compiledFunctionNames() -> [String] {
        #if canImport(Metal)
        guard let lib = memoized else { return [] }
        return lib.functionNames
        #else
        return []
        #endif
    }

    /// 主线 解构 重构 Round 3 — convenience: count of
    /// compiled functions in the memoized library。
    /// Returns 0 until the first successful `library()`
    /// call。 Useful for the brain.healthSnapshot Metal
    /// surface。
    public var compiledFunctionCount: Int {
        #if canImport(Metal)
        return memoized?.functionNames.count ?? 0
        #else
        return 0
        #endif
    }

    /// 主线 继续 开发 — actually run the compiled kernel
    /// on a tiny known-input dispatch, returning a typed
    /// self-test result。 Moves the Metal pilot from
    /// "compile + memoize only" to "compile + memoize +
    /// PROVE EXECUTION on every warmup that opts in"。
    ///
    /// Uses a (B=1, L=1, D=1) input shape so the dispatch
    /// is sub-millisecond on Apple silicon。 The result
    /// is computed against an inline-pinned expected
    /// value derived from the same SSM recurrence:
    ///
    ///   A_d = -0.5, delta_t = 1.0, x_t = 1.0,
    ///   B_t = 1.0, C_t = 1.0
    ///   A_bar = exp(delta_t * A_d) = exp(-0.5)
    ///   B_bar = delta_t * B_t = 1.0
    ///   h_1   = A_bar * 0.0 + B_bar * x_t = 1.0
    ///   y_1   = C_t * h_1 = 1.0
    ///
    /// V1 path / non-Apple host returns `.skipped`。
    /// Compile failure returns `.failed`。 Math mismatch
    /// > 1e-5 returns `.failed`。 Success returns
    /// `.passed` with measuredOutput == 1.0 (within
    /// tolerance)。
    public func runKernelSelfTest() async
        -> BASMetalKernelSelfTestResult
    {
        #if canImport(Metal)
        guard useMetalKernelV2 else {
            return BASMetalKernelSelfTestResult(
                status: .skipped,
                reason: "V1 path — kernel not compiled",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        // Memoized compile (re-uses existing library
        // if already compiled)。
        let lib: MTLLibrary
        do {
            lib = try library()
        } catch {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason: "library() threw: \(error)",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        guard let function = lib.makeFunction(
            name: "ssm_scan_float32")
        else {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason:
                    "ssm_scan_float32 function not found",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        let pipeline: MTLComputePipelineState
        do {
            pipeline = try await lib.device
                .makeComputePipelineState(
                    function: function)
        } catch {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason:
                    "pipeline creation threw: \(error)",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        guard let queue =
            lib.device.makeCommandQueue()
        else {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason: "makeCommandQueue returned nil",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        // Tiny (B=1, L=1, D=1) inputs。 Math:
        //   A_bar = exp(1.0 * -0.5) = ~0.6065
        //   B_bar = 1.0 * 1.0 = 1.0
        //   h_1   = 0 + 1.0 * 1.0 = 1.0
        //   y_1   = 1.0 * 1.0 = 1.0
        let x: [Float] = [1.0]
        let delta: [Float] = [1.0]
        let A: [Float] = [-0.5]
        let B: [Float] = [1.0]
        let C: [Float] = [1.0]
        var y: [Float] = [0.0]
        var shapeValues: [UInt32] = [1, 1, 1]
        let dev = lib.device
        guard let xBuf = dev.makeBuffer(
            bytes: x, length: MemoryLayout<Float>.stride,
            options: []),
            let dBuf = dev.makeBuffer(
                bytes: delta, length: MemoryLayout<Float>.stride,
                options: []),
            let aBuf = dev.makeBuffer(
                bytes: A, length: MemoryLayout<Float>.stride,
                options: []),
            let bBuf = dev.makeBuffer(
                bytes: B, length: MemoryLayout<Float>.stride,
                options: []),
            let cBuf = dev.makeBuffer(
                bytes: C, length: MemoryLayout<Float>.stride,
                options: []),
            let yBuf = dev.makeBuffer(
                bytes: &y, length: MemoryLayout<Float>.stride,
                options: []),
            let sBuf = dev.makeBuffer(
                bytes: &shapeValues,
                length: MemoryLayout<BASSSMScanShape>.size,
                options: []),
            let cmd = queue.makeCommandBuffer(),
            let enc = cmd.makeComputeCommandEncoder()
        else {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason: "buffer / encoder allocation" +
                    " failed",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(xBuf, offset: 0, index: 0)
        enc.setBuffer(dBuf, offset: 0, index: 1)
        enc.setBuffer(aBuf, offset: 0, index: 2)
        enc.setBuffer(bBuf, offset: 0, index: 3)
        enc.setBuffer(cBuf, offset: 0, index: 4)
        enc.setBuffer(yBuf, offset: 0, index: 5)
        enc.setBuffer(sBuf, offset: 0, index: 6)
        enc.dispatchThreads(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(
                width: 1, height: 1, depth: 1))
        enc.endEncoding()
        // Bridge addCompletedHandler to async without
        // crossing actor boundaries with MTLCommandBuffer
        // (not Sendable)。 Resume by THROWING on a GPU fault
        // (non-nil commandBuffer.error) so a faulted self-
        // test reports `.failed` instead of reading the pre-
        // zeroed buffer and (since expected is 1.0) failing
        // with a misleading "math mismatch" reason。 Success
        // path resumes normally with the output unchanged。
        do {
            try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<Void, Error>) in
                cmd.addCompletedHandler { buffer in
                    if let err = buffer.error {
                        cont.resume(throwing:
                            BASMetalKernelLibraryLoaderError
                                .metalCompilationFailed(
                                    message:
                                        "self-test command" +
                                        " buffer error: " +
                                        err.localizedDescription))
                    } else {
                        cont.resume()
                    }
                }
                cmd.commit()
            }
        } catch {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason:
                    "command buffer faulted: \(error)",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        let outPtr = yBuf.contents().bindMemory(
            to: Float.self, capacity: 1)
        let measured = outPtr[0]
        let expected: Float = 1.0
        let absErr = abs(measured - expected)
        if absErr > 1e-5 {
            return BASMetalKernelSelfTestResult(
                status: .failed,
                reason:
                    "math mismatch:|y - 1.0| = \(absErr)",
                measuredOutput: measured,
                expectedOutput: expected)
        }
        return BASMetalKernelSelfTestResult(
            status: .passed,
            reason:
                "y_1 within 1e-5 of expected 1.0",
            measuredOutput: measured,
            expectedOutput: expected)
        #else
        return BASMetalKernelSelfTestResult(
            status: .skipped,
            reason: "canImport(Metal) is false",
            measuredOutput: 0,
            expectedOutput: 1.0)
        #endif
    }
}

/// 主线 继续 开发 — typed Codable result of
/// `BASMetalKernelLibraryLoader.runKernelSelfTest()`。
/// Hosts can inspect status + measured/expected outputs
/// without parsing free-text。
public struct BASMetalKernelSelfTestResult: Codable,
    Equatable, Sendable, Hashable
{
    public enum Status: String, Codable, Sendable,
        Hashable
    {
        /// V1 path / non-Apple host / Metal unavailable。
        /// Not a failure — just not applicable。
        case skipped
        /// GPU dispatched, output within 1e-5 of
        /// expected value。
        case passed
        /// Compile or dispatch threw,or output diverged。
        case failed
    }

    public let status: Status

    /// Human-readable reason — useful in audit logs。
    public let reason: String

    /// What the GPU returned。 0 on skipped。
    public let measuredOutput: Float

    /// What the math says the answer should be。
    public let expectedOutput: Float

    public init(
        status: Status,
        reason: String,
        measuredOutput: Float,
        expectedOutput: Float
    ) {
        self.status = status
        self.reason = reason
        self.measuredOutput = measuredOutput
        self.expectedOutput = expectedOutput
    }

    /// Absolute error |measured - expected|。 0 on
    /// skipped (no measurement taken)。
    public var absoluteError: Float {
        return abs(measuredOutput - expectedOutput)
    }
}

// MARK: - Flag-aware factory

extension BASMetalKernelLibraryLoader {

    /// Async factory consulting
    /// `BASLanguageAugmentationFeatureFlags
    /// .metalKernelV2Enabled` to choose path。
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async -> BASMetalKernelLibraryLoader {
        let useV2 = await flags.isEnabled(
            .metalKernelV2Enabled)
        return BASMetalKernelLibraryLoader(
            useMetalKernelV2: useV2)
    }

    /// M2205 chapter 七百十三 第一刀 — host adoption
    /// convenience。 Returns the V2 path because
    /// chapter 七百十二 production wire-in flipped
    /// `metalKernelV2Enabled` to default-true。
    public static func makeWithDefaults() async -> BASMetalKernelLibraryLoader {
        let flags = BASLanguageAugmentationFeatureFlags()
        return await make(flags: flags)
    }
}

// MARK: - Resource availability introspection

extension BASMetalKernelLibraryLoader {

    /// Sync introspection:does `Bundle.module` see the
    /// SSMScan.metal resource at all? Useful for tests
    /// that don't care about the loader's V2 path but
    /// want to assert the SPM `.process(...)` declaration
    /// took effect。
    public static var ssmScanResourceURL: URL? {
        return expectedBundle.url(
            forResource: ssmScanResourceName,
            withExtension: ssmScanResourceExtension)
    }

    /// Whether the SSMScan.metal resource is bundled。
    /// Returns false on non-Apple build hosts where the
    /// resource may not be staged。
    public static var isSsmScanResourceBundled: Bool {
        return ssmScanResourceURL != nil
    }
}
