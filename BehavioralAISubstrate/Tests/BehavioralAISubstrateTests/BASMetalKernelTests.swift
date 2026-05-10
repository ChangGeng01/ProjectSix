// MARK: - BASMetalKernelTests — chapter 四百三十一 / M1098

import XCTest
@testable import BASMetalSubstrate

final class BASMetalKernelTests: XCTestCase {

    // MARK: - BASKernelInputs invariants

    func testEmptyInputs() {
        let inputs = BASKernelInputs.empty
        XCTAssertEqual(inputs.descriptors.count, 0)
        XCTAssertEqual(inputs.payloads.count, 0)
    }

    func testInputsWithMatchingPayloads() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [4],
            dataType: .uint8,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [Data([1, 2, 3, 4])])
        XCTAssertEqual(inputs.descriptors.count, 1)
        XCTAssertEqual(inputs.payloads.count, 1)
        XCTAssertEqual(inputs.payloads[0].count, 4)
    }

    // MARK: - BASKernelOutputs invariants

    func testOutputsCarryExecutionTime() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [2],
            dataType: .uint8,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let outputs = BASKernelOutputs(
            descriptors: [descriptor],
            payloads: [Data([7, 7])],
            executionNanos: 1_500_000)
        XCTAssertEqual(outputs.executionNanos, 1_500_000)
        XCTAssertEqual(outputs.payloads[0], Data([7, 7]))
    }

    // MARK: - Kernel error enum

    func testKernelErrorEquality() {
        XCTAssertEqual(
            BASKernelError.shapeMismatch(reason: "x"),
            BASKernelError.shapeMismatch(reason: "x"))
        XCTAssertEqual(
            BASKernelError.dataTypeMismatch(
                expected: .float32, actual: .float16),
            BASKernelError.dataTypeMismatch(
                expected: .float32, actual: .float16))
        XCTAssertNotEqual(
            BASKernelError.notImplemented(
                operation: .matMul),
            BASKernelError.notImplemented(
                operation: .softmax))
    }

    // MARK: - Conformance via test stub

    func testStubKernelConformsAndDispatches() async throws {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let kernel = StubIdentityKernel(
            key: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .cpuBytes))
        XCTAssertEqual(kernel.operation, .matMul)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [Data(count: 16)])
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.payloads, inputs.payloads,
            "identity stub must echo inputs unchanged")
        XCTAssertEqual(outputs.executionNanos, 0)
    }

    // MARK: - notImplemented stub throws

    func testNotImplementedKernelThrows() async {
        let kernel = StubNotImplementedKernel(
            key: BASKernelKey(
                operation: .ssmScan,
                dataType: .float32,
                backingKind: .cpuBytes))
        do {
            _ = try await kernel.evaluate(
                inputs: .empty)
            XCTFail("expected throw")
        } catch let err as BASKernelError {
            XCTAssertEqual(
                err,
                .notImplemented(operation: .ssmScan))
        } catch {
            XCTFail(
                "expected BASKernelError, got \(error)")
        }
    }
}

// MARK: - Test stub kernels

/// Identity kernel — returns inputs unchanged。 Used for
/// registry + dispatch facade tests。
struct StubIdentityKernel: BASMetalKernel {
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

/// Stub that always throws `.notImplemented`。 Used for
/// the placeholder-registration test path。
struct StubNotImplementedKernel: BASMetalKernel {
    let key: BASKernelKey
    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        throw BASKernelError
            .notImplemented(operation: key.operation)
    }
}
