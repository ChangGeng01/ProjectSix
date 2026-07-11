// MARK: - BASKernelRegistryDispatchExecutorTests
// chapter 四百七十四 / M1273
//
// Closes the "MPSGraph kernels shipped but no production
// caller" gap by proving the dispatch path through
// BASMetalKernelRegistry routes correctly through 5 typed
// outcomes:
//   - dispatched (happy path)
//   - fallback-no-key (assignment had nil kernel key)
//   - fallback-no-kernel (key present but registry empty)
//   - fallback-no-inputs (input builder returned nil)
//   - fallback-kernel-error (kernel threw)

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

/// Sendable actor-bound capture for outcomes — sidesteps
/// Swift 6 strict-concurrency `var` capture restrictions
/// inside `@Sendable` closures。
private actor OutcomeBox {
    private(set) var outcomes:
        [BASKernelRegistryDispatchOutcome] = []
    private(set) var fallbackCount: Int = 0

    func append(_ o: BASKernelRegistryDispatchOutcome) {
        outcomes.append(o)
    }
    func bumpFallback() { fallbackCount += 1 }
    var last:
        BASKernelRegistryDispatchOutcome? { outcomes.last }
    var count: Int { outcomes.count }
}

@Sendable
private func makeStubRequest() -> BASEBrainTurnRequest {
    BASEBrainTurnRequest(
        userInput: "stub",
        deviceState: BASDeviceState(
            batteryLevel: 0.5,
            thermalLevel: .nominal,
            memoryFreeMB: 1024,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.1,
            gpuLoad: 0.0,
            npuAvailable: false,
            latencyBudgetMs: 100),
        hostID: "test.host",
        recordedAt: Date(timeIntervalSince1970: 1000))
}

final class BASKernelRegistryDispatchExecutorTests:
    XCTestCase
{

    // MARK: - Test fixtures

    /// Tiny test kernel that echoes its first input back
    /// as output。 Used to prove the dispatched path fires
    /// + returns a real BASKernelDispatchResult。
    private struct EchoKernel: BASMetalKernel {
        let key: BASKernelKey

        func evaluate(
            inputs: BASKernelInputs
        ) async throws -> BASKernelOutputs {
            return BASKernelOutputs(
                descriptors: inputs.descriptors,
                payloads: inputs.payloads,
                executionNanos: 0)
        }
    }

    /// Kernel that always throws for testing the
    /// fallback-kernel-error path。
    private struct ThrowingKernel: BASMetalKernel {
        let key: BASKernelKey

        func evaluate(
            inputs: BASKernelInputs
        ) async throws -> BASKernelOutputs {
            throw BASKernelError.shapeMismatch(
                reason: "intentional test failure")
        }
    }

    /// Build a sample BASKernelKey for testing。
    private func makeKey() -> BASKernelKey {
        return BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .cpuBytes)
    }

    /// Build an assignment carrying the given kernel key
    /// (or nil for the no-key path)。
    private func makeAssignment(
        key: BASKernelKey?
    ) -> BASStageAcceleratorAssignment {
        return BASStageAcceleratorAssignment(
            selectedBackingKind: .cpuBytes,
            selectedKernelKey: key,
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale: key == nil
                ? .cpuNoKernelRegistered
                : .aneSupported)
    }

    // MARK: - Outcome: dispatched

    func testDispatchedOutcomeWhenKeyMatchesRegistry()
        async throws
    {
        let registry = BASMetalKernelRegistry()
        let key = makeKey()
        await registry.register(EchoKernel(key: key))
        let assignment = makeAssignment(key: key)
        let box = OutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    return BASKernelInputs.empty
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome)
                },
                fallback: { _, _, _ in
                    XCTFail(
                        "fallback must not fire on" +
                        " dispatched path")
                    return ()
                })
        let result = await routed(
            .stageA, assignment, makeStubRequest())
        let last = await box.last
        XCTAssertEqual(
            last, .dispatched,
            "outcome handler must fire .dispatched")
        XCTAssertTrue(
            result is BASKernelDispatchResult,
            "dispatched path must return a real" +
            " BASKernelDispatchResult typed value")
    }

    // MARK: - Outcome: fallback-no-key

    func testFallbackNoKeyOutcomeWhenAssignmentLacksKey()
        async
    {
        let registry = BASMetalKernelRegistry()
        let assignment = makeAssignment(key: nil)
        let box = OutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    XCTFail(
                        "input builder must not fire" +
                        " when assignment has no key")
                    return nil
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome)
                },
                fallback: { _, _, _ in
                    await box.bumpFallback()
                    return "fallback-result"
                })
        let result = await routed(
            .stageA, assignment, makeStubRequest())
        let last = await box.last
        let fallbackCount = await box.fallbackCount
        XCTAssertEqual(
            last, .fallbackNoKey,
            "outcome handler must fire .fallbackNoKey")
        XCTAssertEqual(fallbackCount, 1,
            "fallback closure must execute exactly once")
        XCTAssertEqual(
            result as? String, "fallback-result",
            "fallback's typed return value must flow" +
            " through")
    }

    // MARK: - Outcome: fallback-no-kernel

    func testFallbackNoKernelOutcomeWhenRegistryEmpty()
        async
    {
        let registry = BASMetalKernelRegistry()
        let key = makeKey()
        let assignment = makeAssignment(key: key)
        let box = OutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    XCTFail(
                        "input builder must not fire" +
                        " when kernel not registered")
                    return nil
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome)
                },
                fallback: { _, _, _ in
                    await box.bumpFallback()
                    return ()
                })
        _ = await routed(
            .stageA, assignment, makeStubRequest())
        let last = await box.last
        let count = await box.fallbackCount
        XCTAssertEqual(last, .fallbackNoKernel)
        XCTAssertEqual(count, 1)
    }

    // MARK: - Outcome: fallback-no-inputs

    func testFallbackNoInputsOutcomeWhenBuilderReturnsNil()
        async
    {
        let registry = BASMetalKernelRegistry()
        let key = makeKey()
        await registry.register(EchoKernel(key: key))
        let assignment = makeAssignment(key: key)
        let box = OutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    return nil
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome)
                },
                fallback: { _, _, _ in
                    await box.bumpFallback()
                    return ()
                })
        _ = await routed(
            .stageA, assignment, makeStubRequest())
        let last = await box.last
        let count = await box.fallbackCount
        XCTAssertEqual(last, .fallbackNoInputs)
        XCTAssertEqual(count, 1)
    }

    // MARK: - Outcome: fallback-kernel-error

    func testFallbackKernelErrorOutcomeWhenKernelThrows()
        async
    {
        let registry = BASMetalKernelRegistry()
        let key = makeKey()
        await registry.register(ThrowingKernel(key: key))
        let assignment = makeAssignment(key: key)
        let box = OutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    return BASKernelInputs.empty
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome)
                },
                fallback: { _, _, _ in
                    await box.bumpFallback()
                    return ()
                })
        _ = await routed(
            .stageA, assignment, makeStubRequest())
        let last = await box.last
        let count = await box.fallbackCount
        XCTAssertEqual(last, .fallbackKernelError)
        XCTAssertEqual(count, 1)
    }

    // MARK: - Determinism — same inputs route same path

    func testSameInputsRouteSamePath() async throws {
        // chapter 三百九二 replay-determinism — repeat
        // dispatch with same registry + same assignment
        // must produce identical outcome sequence。
        let registry = BASMetalKernelRegistry()
        let key = makeKey()
        await registry.register(EchoKernel(key: key))
        let assignment = makeAssignment(key: key)
        let box = OutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    return BASKernelInputs.empty
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome)
                },
                fallback: { _, _, _ in () })
        for _ in 0..<5 {
            _ = await routed(
                .stageA, assignment, makeStubRequest())
        }
        let outcomes = await box.outcomes
        XCTAssertEqual(
            outcomes,
            Array(repeating: .dispatched, count: 5),
            "5 repeat dispatches must all return same" +
            " outcome (chapter 三百九二)")
    }

    // MARK: - Outcome enum coverage

    func testOutcomeEnumHasFiveCases() {
        XCTAssertEqual(
            BASKernelRegistryDispatchOutcome.allCases
                .count, 5)
    }
}
