// MARK: - BASMetalKernelLibraryLoaderTests
// chapter 七百四 / M2181 第三刀 — 22 anti-drift PROOF
//                                  tests for the
//                                  chapter 七百四 Metal
//                                  pilot (SSMScan.metal
//                                  .process() resource +
//                                  BASMetalKernelLibrary
//                                  Loader actor)。
//
// ## Coverage matrix (22 tests)
//
// **Resource bundling (SPM `.process(...)` contract)**
//   1. Bundle.module sees SSMScan.metal at all
//   2. ssmScanResourceURL is non-nil + has .metal ext
//   3. isSsmScanResourceBundled returns true
//   4. ssmScanResourceName pin == "SSMScan"
//   5. ssmScanResourceExtension pin == "metal"
//   6. expectedBundle pin == Bundle.module
//   7. ssmScan resource source contains "kernel" keyword
//      (smoke test:we loaded the actual shader)
//
// **Actor init + flag honoring**
//   8. init(useMetalKernelV2: false) — isUsingV2 false
//   9. init(useMetalKernelV2: true)  — isUsingV2 true
//  10. init() default — isUsingV2 false (V1 path)
//
// **V1 path correctness**
//  11. V1 loader.library() throws metalUnavailableOnPlatform
//      (V1 callers must NOT accidentally pull a V2 library)
//  12. V1 loader.hasMemoizedLibrary false even after
//      throw (no spurious cache fill on the V1 path)
//
// **V2 path correctness (GPU-gated)**
//  13. V2 loader.library() compiles successfully on
//      Apple platforms with GPU (XCTSkipIf otherwise)
//  14. V2 loader.hasMemoizedLibrary true after first
//      successful library() call (memoization works)
//  15. V2 loader.library() second call returns identical
//      reference (lazy + memoized contract)
//
// **Error case typing**
//  16. .metalUnavailableOnPlatform Codable round-trip
//  17. .mtlDeviceUnavailable Codable round-trip
//  18. .resourceURLMissing(resourceName:) preserves
//      associated value through Codable
//  19. .resourceReadFailed(message:) preserves message
//  20. .metalCompilationFailed(message:) preserves message
//
// **Flag-aware factory**
//  21. make(flags:) default-off → V1 loader
//  22. make(flags:) explicit-on → V2 loader

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore
#if canImport(Metal)
import Metal
#endif

final class BASMetalKernelLibraryLoaderTests: XCTestCase {

    // MARK: - Resource bundling

    func testBundleModuleSeesSSMScanMetalResource() {
        XCTAssertNotNil(
            BASMetalKernelLibraryLoader.ssmScanResourceURL,
            "Bundle.module must include SSMScan.metal" +
            " via SPM .process() — if this fails the" +
            " M2179 Package.swift change was reverted。")
    }

    func testSsmScanResourceURLHasMetalExtension() {
        guard let url = BASMetalKernelLibraryLoader
            .ssmScanResourceURL
        else { return XCTFail("resource URL nil") }
        XCTAssertEqual(url.pathExtension, "metal")
    }

    func testIsSsmScanResourceBundledReturnsTrue() {
        XCTAssertTrue(
            BASMetalKernelLibraryLoader
                .isSsmScanResourceBundled)
    }

    func testSsmScanResourceNamePin() {
        XCTAssertEqual(
            BASMetalKernelLibraryLoader.ssmScanResourceName,
            "SSMScan")
    }

    func testSsmScanResourceExtensionPin() {
        XCTAssertEqual(
            BASMetalKernelLibraryLoader
                .ssmScanResourceExtension,
            "metal")
    }

    func testExpectedBundleEqualsBundleModule() {
        XCTAssertEqual(
            BASMetalKernelLibraryLoader.expectedBundle,
            Bundle.module)
    }

    func testSsmScanSourceContainsKernelKeyword() throws {
        guard let url = BASMetalKernelLibraryLoader
            .ssmScanResourceURL
        else { return XCTFail("resource URL nil") }
        let source = try String(contentsOf: url,
                                encoding: .utf8)
        // SSMScan.metal defines a `kernel void`
        // function。 If the bundled resource is the
        // actual shader this substring must appear。
        XCTAssertTrue(source.contains("kernel"),
            "Loaded SSMScan.metal source should" +
            " contain the `kernel` keyword from the" +
            " Metal Shading Language。")
    }

    // MARK: - Actor init + flag honoring

    func testActorInitFalseHasV1Flag() {
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let exp = expectation(description: "v1 flag")
        Task {
            let v2 = await actor.isUsingV2
            XCTAssertFalse(v2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testActorInitTrueHasV2Flag() {
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let exp = expectation(description: "v2 flag")
        Task {
            let v2 = await actor.isUsingV2
            XCTAssertTrue(v2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testActorDefaultInitIsV1() {
        let actor = BASMetalKernelLibraryLoader()
        let exp = expectation(description: "default")
        Task {
            let v2 = await actor.isUsingV2
            XCTAssertFalse(v2,
                "Default init must be V1 (chapter 477" +
                " ADR-014 OPT-IN preservation)。")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    // MARK: - V1 path correctness

    func testV1LoaderLibraryThrowsMetalUnavailableOnPlatform() {
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let exp = expectation(description: "v1 throws")
        Task {
            do {
                _ = try await actor.library()
                XCTFail(
                    "V1 path must throw to prevent" +
                    " accidental V2 library use。")
            } catch let err as
                BASMetalKernelLibraryLoaderError
            {
                XCTAssertEqual(err,
                    .metalUnavailableOnPlatform,
                    "V1 path throws the same case as" +
                    " a watchOS / non-Metal host — by" +
                    " contract,both mean 'caller must" +
                    " not consume V2 library here'。")
            } catch {
                XCTFail("Wrong error type:\(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testV1LoaderHasMemoizedFalseAfterThrow() {
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let exp = expectation(description: "no memo")
        Task {
            _ = try? await actor.library()
            let memoed = await actor.hasMemoizedLibrary
            XCTAssertFalse(memoed,
                "V1 throw must NOT pollute the memoize" +
                " slot — future V2 retries on the same" +
                " actor would silently observe stale" +
                " state。")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    // MARK: - V2 path correctness (GPU-gated)

    func testV2LoaderLibraryCompilesSuccessfully() throws {
        #if !canImport(Metal)
        throw XCTSkip("Metal unavailable on this host")
        #else
        if MTLCreateSystemDefaultDevice() == nil {
            throw XCTSkip("No GPU available on this host")
        }
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let exp = expectation(description: "v2 compiles")
        Task {
            do {
                _ = try await actor.library()
            } catch {
                XCTFail(
                    "V2 path should compile SSMScan" +
                    ".metal successfully on a GPU-" +
                    "enabled Apple host:\(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        #endif
    }

    func testV2LoaderMemoizationFlagSetAfterFirstCall() throws {
        #if !canImport(Metal)
        throw XCTSkip("Metal unavailable on this host")
        #else
        if MTLCreateSystemDefaultDevice() == nil {
            throw XCTSkip("No GPU available on this host")
        }
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let exp = expectation(description: "memoized")
        Task {
            _ = try? await actor.library()
            let memoed = await actor.hasMemoizedLibrary
            XCTAssertTrue(memoed,
                "First successful library() call must" +
                " set the memoize flag。")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        #endif
    }

    func testV2LoaderSecondCallReturnsIdenticalReference() throws {
        #if !canImport(Metal)
        throw XCTSkip("Metal unavailable on this host")
        #else
        if MTLCreateSystemDefaultDevice() == nil {
            throw XCTSkip("No GPU available on this host")
        }
        let actor = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let exp = expectation(description: "stable ref")
        Task {
            do {
                let a = try await actor.library()
                let b = try await actor.library()
                XCTAssertTrue(a === b,
                    "Memoization contract:second call" +
                    " must return the SAME MTLLibrary" +
                    " reference (not a fresh compile)。")
            } catch {
                XCTFail("Compile failed:\(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        #endif
    }

    // MARK: - Error case typing

    func testErrorMetalUnavailableCodableRoundTrip() throws {
        let original = BASMetalKernelLibraryLoaderError
            .metalUnavailableOnPlatform
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMetalKernelLibraryLoaderError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorMtlDeviceUnavailableCodableRoundTrip() throws {
        let original = BASMetalKernelLibraryLoaderError
            .mtlDeviceUnavailable
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMetalKernelLibraryLoaderError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorResourceURLMissingPreservesName() throws {
        let original = BASMetalKernelLibraryLoaderError
            .resourceURLMissing(
                resourceName: "PhantomShader")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMetalKernelLibraryLoaderError.self,
            from: data)
        XCTAssertEqual(decoded, original)
        if case .resourceURLMissing(let name) = decoded {
            XCTAssertEqual(name, "PhantomShader")
        } else {
            XCTFail("Wrong case")
        }
    }

    func testErrorResourceReadFailedPreservesMessage() throws {
        let original = BASMetalKernelLibraryLoaderError
            .resourceReadFailed(
                message: "EIO simulated")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMetalKernelLibraryLoaderError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorMetalCompilationFailedPreservesMessage() throws {
        let original = BASMetalKernelLibraryLoaderError
            .metalCompilationFailed(
                message: "syntax error at line 1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMetalKernelLibraryLoaderError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Flag-aware factory

    func testMakeFactoryDefaultChoosesV2AtChapter712() {
        // M2203 chapter 七百十二 — metalKernelV2Enabled
        // flipped default-true。 Factory now picks V2。
        let exp = expectation(description: "make default")
        Task {
            let flags = BASLanguageAugmentationFeatureFlags()
            let defaultValue = await flags.isEnabled(
                .metalKernelV2Enabled)
            XCTAssertTrue(defaultValue,
                "M2203 wire-in:metalKernelV2Enabled" +
                " now defaults TRUE")
            let actor = await BASMetalKernelLibraryLoader
                .make(flags: flags)
            let v2 = await actor.isUsingV2
            XCTAssertTrue(v2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testMakeFactoryExplicitlyOnChoosesV2() {
        let exp = expectation(description: "make on")
        Task {
            let flags = BASLanguageAugmentationFeatureFlags()
            await flags.setFlag(
                .metalKernelV2Enabled, to: true)
            let actor = await BASMetalKernelLibraryLoader
                .make(flags: flags)
            let v2 = await actor.isUsingV2
            XCTAssertTrue(v2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}
