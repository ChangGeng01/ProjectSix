// MARK: - BASCognitiveBrainWarmPilotsTests
// 主线 全面 提升: brain.warmMetalKernel() +
// brain.warmPilots() tests。 Pins the new pilot-warmup
// surface that promotes Metal from "accessor only" to
// "brain-side consumer"。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASCognitiveBrainWarmPilotsTests: XCTestCase {

    // MARK: - warmMetalKernel — no loader

    func testWarmMetalKernelNoLoaderReturnsFalse()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let ok = await brain.warmMetalKernel()
        XCTAssertFalse(ok,
            "No metal loader wired → warmMetalKernel" +
            " returns false (nothing to warm)")
    }

    // MARK: - warmMetalKernel — V2 loader compiles library

    func testWarmMetalKernelV2CompilesLibrary()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let memoizedBefore = await loader
            .hasMemoizedLibrary
        XCTAssertFalse(memoizedBefore,
            "Loader has not compiled before first warm")
        let ok = await brain.warmMetalKernel()
        XCTAssertTrue(ok,
            "V2 loader on Apple silicon must succeed" +
            " on warmMetalKernel — the SSMScan.metal" +
            " kernel ships in bundle resources")
        let memoizedAfter = await loader
            .hasMemoizedLibrary
        XCTAssertTrue(memoizedAfter,
            "After warmMetalKernel,loader must have" +
            " a memoized MTLLibrary")
    }

    func testWarmMetalKernelV1ReturnsFalse() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let ok = await brain.warmMetalKernel()
        XCTAssertFalse(ok,
            "V1 loader throws on .library() — warm" +
            " returns false")
    }

    // MARK: - warmMetalKernel is idempotent

    func testWarmMetalKernelIsIdempotent() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let first = await brain.warmMetalKernel()
        let second = await brain.warmMetalKernel()
        let third = await brain.warmMetalKernel()
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertTrue(third,
            "Repeat warms must all succeed (memoized)")
    }

    // MARK: - warmPilots composed helper

    func testWarmPilotsBareBrain() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.warmPilots()
        XCTAssertFalse(result.metalAttempted,
            "No Metal loader wired → metalAttempted false")
        XCTAssertFalse(result.metalSucceeded)
        XCTAssertTrue(result.allSucceeded,
            "All-not-attempted counts as allSucceeded" +
            " (nothing to fail)")
    }

    func testWarmPilotsWithMetalV2() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let result = await brain.warmPilots()
        XCTAssertTrue(result.metalAttempted)
        XCTAssertTrue(result.metalSucceeded)
        XCTAssertTrue(result.allSucceeded)
    }

    func testWarmPilotsWithMetalV1FailsGracefully()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let result = await brain.warmPilots()
        XCTAssertTrue(result.metalAttempted)
        XCTAssertFalse(result.metalSucceeded)
        XCTAssertFalse(result.allSucceeded,
            "Metal attempted but failed → allSucceeded" +
            " false")
    }

    // MARK: - Codable round-trip

    func testWarmupResultCodableRoundTrip() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let original = await brain.warmPilots()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainPilotWarmupResult.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Warm amortizes first-turn cost

    func testWarmMetalAmortizesFirstAccessLatency()
        async throws
    {
        // After warmMetalKernel(),subsequent loader
        // access should be fast (memoized return)。
        // This test characterizes the amortization
        // (no strict assert because mach timing
        // varies)。
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let warmStart = Date()
        _ = await brain.warmMetalKernel()
        let warmElapsed = Date()
            .timeIntervalSince(warmStart)
        let postWarmStart = Date()
        _ = await brain.warmMetalKernel()  // memoized
        let postWarmElapsed = Date()
            .timeIntervalSince(postWarmStart)
        print("[Metal warm] first=\(warmElapsed)s" +
            " memoized=\(postWarmElapsed)s")
        XCTAssertLessThan(postWarmElapsed, 0.1,
            "Memoized warm must be << first warm。" +
            " Got memoized=\(postWarmElapsed)s")
    }
}
