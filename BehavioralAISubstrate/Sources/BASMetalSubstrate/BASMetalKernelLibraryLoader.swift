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
        guard let url = Self.expectedBundle.url(
            forResource: Self.ssmScanResourceName,
            withExtension: Self.ssmScanResourceExtension)
        else {
            throw BASMetalKernelLibraryLoaderError
                .resourceURLMissing(
                    resourceName: Self.ssmScanResourceName)
        }
        let source: String
        do {
            source = try String(contentsOf: url,
                                encoding: .utf8)
        } catch {
            throw BASMetalKernelLibraryLoaderError
                .resourceReadFailed(
                    message: String(describing: error))
        }
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
