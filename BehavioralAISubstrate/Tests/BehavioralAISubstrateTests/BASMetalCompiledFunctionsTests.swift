// MARK: - BASMetalCompiledFunctionsTests
// 主线 解构 重构 Round 3: Metal pilot now exposes
// compiledFunctionNames + compiledFunctionCount from the
// loaded MTLLibrary。 Hosts use these to verify the
// SSMScan.metal compile produced the expected kernel
// symbols。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASMetalCompiledFunctionsTests: XCTestCase {

    // MARK: - V1 path

    func testV1LoaderReportsNoFunctions() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let names = await loader.compiledFunctionNames()
        let count = await loader.compiledFunctionCount
        XCTAssertEqual(names.count, 0)
        XCTAssertEqual(count, 0)
    }

    // MARK: - V2 path before warmup

    func testV2LoaderBeforeWarmupReportsNoFunctions()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let names = await loader.compiledFunctionNames()
        let count = await loader.compiledFunctionCount
        XCTAssertEqual(names.count, 0,
            "Before library() compile, no functions" +
            " visible")
        XCTAssertEqual(count, 0)
    }

    // MARK: - V2 path after warmup

    func testV2LoaderAfterWarmupExposesFunctionNames()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let ok = await brain.warmMetalKernel()
        XCTAssertTrue(ok,
            "Metal kernel warmup must succeed on Apple" +
            " silicon for this test to be meaningful")
        let names = await loader.compiledFunctionNames()
        let count = await loader.compiledFunctionCount
        XCTAssertGreaterThan(names.count, 0,
            "SSMScan.metal must expose at least one" +
            " function symbol — got names: \(names)")
        XCTAssertEqual(count, names.count)
    }

    func testV2LoaderExposesExpectedSSMScanFunction()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        _ = await brain.warmMetalKernel()
        let names = await loader.compiledFunctionNames()
        // SSMScan.metal exposes at least one kernel
        // function。 Don't pin the exact name list
        // (kernel might evolve);assert names exist
        // and one of them references "ssm" or "scan"
        // — the kernel's domain。
        XCTAssertFalse(names.isEmpty,
            "Names list must be non-empty after compile")
        let hasScanRelated = names.contains { name in
            let lower = name.lowercased()
            return lower.contains("ssm")
                || lower.contains("scan")
        }
        XCTAssertTrue(hasScanRelated,
            "At least one compiled function must reference" +
            " ssm/scan (the kernel's domain)。 Got: \(names)")
    }

    // MARK: - Idempotent reads

    func testCompiledFunctionNamesIsIdempotent()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        _ = await brain.warmMetalKernel()
        let first = await loader.compiledFunctionNames()
        let second = await loader.compiledFunctionNames()
        let third = await loader.compiledFunctionNames()
        XCTAssertEqual(first, second,
            "Reading twice produces identical results")
        XCTAssertEqual(second, third)
    }
}
