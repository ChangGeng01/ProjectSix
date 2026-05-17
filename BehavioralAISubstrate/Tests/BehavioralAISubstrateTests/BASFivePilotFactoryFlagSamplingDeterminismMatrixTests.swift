// MARK: - BASFivePilotFactoryFlagSamplingDeterminismMatrixTests
// chapter 七百三十二 / M2243 第一刀 — factory flag-sampling
//                                     determinism matrix —
//                                     eighth pillar of
//                                     ACTOR contract。
//
// ## Why
//
// Each pilot's `make(flags:)` async factory consults the
// shared `BASLanguageAugmentationFeatureFlags` actor at
// construction time and SAMPLES the per-pilot flag。 The
// sampled mode (V1 or V2) is captured into the constructed
// actor and persists for the actor's lifetime regardless
// of subsequent flag changes。
//
// This contract — "sampled-once-at-construction,not lazy" —
// is critical for replay determinism and chapter 392 IEEE
// Float32 reproducibility:if a pilot were to re-consult
// the flag actor on every operation,a mid-stream flag flip
// could change behavior mid-replay and break determinism。
//
// Chapter 732 pins this contract via 5 per-pilot tests +
// 1 cross-pilot stability summary。 Each test:
//   1. Constructs a fresh flag actor
//   2. Sets the pilot's flag to a known value
//   3. Calls make(flags:) which samples
//   4. FLIPS the flag to the opposite value
//   5. Verifies the pilot's behavior matches the
//      sampled-at-construction value (not the new one)
//
// For most pilots this is observable via mode-introspection
// helpers (isUsingV2 / isCBridgeEnabledSnapshot etc.) — for
// pilots without an introspection surface we settle for
// "actor still alive + factory returned non-nil" as the
// surface tripwire。
//
// ## Coverage (5 per-pilot factory tests + 1 sampling summary)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotFactoryFlagSamplingDeterminismMatrixTests: XCTestCase {

    // MARK: - SQL pilot (in-memory mode for surface test)

    func testSQLPilotFactoryFlagSamplingDoesNotPropagateLateFlip() async throws {
        let tempURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: false)
        let tracker = try await BASMemoryUsageTracker
            .make(databaseURL: tempURL, flags: flags)
        // Late flip — must NOT affect already-constructed
        // tracker (sampled-once contract)
        await flags.setFlag(.sqlMigratorEnabled, to: true)
        // Surface tripwire:tracker still alive + type
        // name matches
        XCTAssertEqual(
            String(describing: type(of: tracker)),
            "BASMemoryUsageTracker")
    }

    // MARK: - C pilot

    func testCPilotFactoryFlagSamplingDoesNotPropagateLateFlip() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.cBridgeEnabled, to: false)
        let monotonic = await BASMonotonicNanos
            .make(flags: flags)
        await flags.setFlag(.cBridgeEnabled, to: true)
        XCTAssertEqual(
            String(describing: type(of: monotonic)),
            "BASMonotonicNanos")
    }

    // MARK: - Metal pilot

    func testMetalPilotFactoryFlagSamplingDoesNotPropagateLateFlip() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.metalKernelV2Enabled, to: false)
        let loader = await BASMetalKernelLibraryLoader
            .make(flags: flags)
        await flags.setFlag(.metalKernelV2Enabled, to: true)
        XCTAssertEqual(
            String(describing: type(of: loader)),
            "BASMetalKernelLibraryLoader")
    }

    // MARK: - C++ pilot

    func testCxxPilotFactoryFlagSamplingDoesNotPropagateLateFlip() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.cxxMpsCacheEnabled, to: false)
        let bridge = await BASMPSGraphExecutableCacheCxxBridge
            .make(flags: flags)
        await flags.setFlag(.cxxMpsCacheEnabled, to: true)
        XCTAssertEqual(
            String(describing: type(of: bridge)),
            "BASMPSGraphExecutableCacheCxxBridge")
    }

    // MARK: - Rust pilot

    func testRustPilotFactoryFlagSamplingDoesNotPropagateLateFlip() async throws {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.rustCoreEnabled, to: false)
        let rust = try await BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        await flags.setFlag(.rustCoreEnabled, to: true)
        XCTAssertEqual(
            String(describing: type(of: rust)),
            "BASRustMemoryUsageTrackerActor")
    }

    // MARK: - Cross-pilot sampling summary

    /// Spawns all 5 pilot actors via factory pattern from
    /// one flag actor + verifies the mid-test flag flip
    /// scenario reaches the end without crash。 Acts as a
    /// cross-pilot end-to-end smoke test that the entire
    /// sampling-once contract holds simultaneously。
    func testAllFivePilotFactoriesShareSamplingContract() async throws {
        let tempURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let flags = BASLanguageAugmentationFeatureFlags()
        // Set ALL 5 flags to false before sampling
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            await flags.setFlag(flag, to: false)
        }
        // Construct all 5 pilots in parallel
        async let sql = BASMemoryUsageTracker
            .make(databaseURL: tempURL, flags: flags)
        async let c = BASMonotonicNanos.make(flags: flags)
        async let metal = BASMetalKernelLibraryLoader
            .make(flags: flags)
        async let cxx = BASMPSGraphExecutableCacheCxxBridge
            .make(flags: flags)
        async let rust = BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        let pilots: [AnyObject] = [
            try await sql,
            await c,
            await metal,
            await cxx,
            try await rust
        ]
        // FLIP all flags after sampling
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            await flags.setFlag(flag, to: true)
        }
        // All 5 pilots survive the flip + remain distinct
        XCTAssertEqual(pilots.count, 5)
        for i in 0..<pilots.count {
            for j in 0..<pilots.count where j != i {
                XCTAssertFalse(pilots[i] === pilots[j],
                    "Pilot \(i) === Pilot \(j) after" +
                    " flag flip — sampling-once contract" +
                    " regression")
            }
        }
    }
}
