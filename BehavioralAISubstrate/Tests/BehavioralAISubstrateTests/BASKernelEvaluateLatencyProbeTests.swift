// MARK: - BASKernelEvaluateLatencyProbeTests
// chapter 四百九十八 / M1371 — typed kernel latency probe tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

/// Test-only stub kernel that emits inputs verbatim
/// (identity)。 Used to verify the probe's pass-through
/// + typed latency observation without depending on real
/// Metal hardware。
private actor IdentityKernelStub: BASMetalKernel {
    nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .cpuBytes)

    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 0)
    }
}

final class BASKernelEvaluateLatencyProbeTests:
    XCTestCase
{

    // MARK: - 1) Probe forwards inputs verbatim

    func testProbeForwardsInputsVerbatim() async throws {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelStub())
        let descriptor = BASTensorDescriptor(
            shape: [4],
            strides: [1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "probe-test")
        let payload = Data(count: descriptor.byteCount)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        let result = try await probe.evaluateAndObserve(
            inputs: inputs)
        XCTAssertEqual(result.outputs.descriptors,
                       [descriptor])
        XCTAssertEqual(result.outputs.payloads,
                       [payload])
    }

    // MARK: - 2) Probe emits typed latency observation

    func testProbeEmitsTypedLatencyResult() async throws {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelStub())
        let descriptor = BASTensorDescriptor(
            shape: [16, 16],
            strides: [16, 1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "latency-probe")
        let payload = Data(count: descriptor.byteCount)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        let result = try await probe.evaluateAndObserve(
            inputs: inputs)
        XCTAssertTrue(result.latency.success)
        XCTAssertEqual(result.latency.body.operation,
                       .matMul)
        XCTAssertEqual(result.latency.body.dataType,
                       .float32)
        XCTAssertEqual(result.latency.body.inputShapes,
                       [[16, 16]])
        // wasCacheHit is always false for the probe
        XCTAssertFalse(result.latency.body.wasCacheHit)
    }

    // MARK: - 3) Probe records non-zero buildNanos

    func testProbeRecordsNonZeroLatency() async throws {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelStub())
        let descriptor = BASTensorDescriptor(
            shape: [2],
            strides: [1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "nanos-test")
        let payload = Data(count: descriptor.byteCount)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        let result = try await probe.evaluateAndObserve(
            inputs: inputs)
        // Even identity stub takes some nanoseconds
        XCTAssertGreaterThan(
            result.latency.body.buildNanos, 0,
            "probe must record non-zero wall-clock" +
            " latency for any kernel call")
    }

    // MARK: - 4) Probe pass-through accessors

    func testProbeKeyAndOperationPassThrough() {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelStub())
        XCTAssertEqual(probe.operation, .matMul)
        XCTAssertEqual(probe.key.operation, .matMul)
        XCTAssertEqual(probe.key.dataType, .float32)
        XCTAssertEqual(probe.key.backingKind, .cpuBytes)
    }

    // MARK: - 5) Probe is Sendable

    func testProbeIsSendable() async throws {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelStub())
        let captured = probe
        let task = Task {
            captured.operation
        }
        let op = await task.value
        XCTAssertEqual(op, .matMul)
    }

    // MARK: - 6) Multiple inputs reflected in shapes

    func testMultipleInputsReflectedInShapes() async throws {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelStub())
        let descA = BASTensorDescriptor(
            shape: [4, 8],
            strides: [8, 1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "A")
        let descB = BASTensorDescriptor(
            shape: [8, 16],
            strides: [16, 1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "B")
        let inputs = BASKernelInputs(
            descriptors: [descA, descB],
            payloads: [
                Data(count: descA.byteCount),
                Data(count: descB.byteCount),
            ])
        let result = try await probe.evaluateAndObserve(
            inputs: inputs)
        XCTAssertEqual(result.latency.body.inputShapes,
                       [[4, 8], [8, 16]])
    }
}
