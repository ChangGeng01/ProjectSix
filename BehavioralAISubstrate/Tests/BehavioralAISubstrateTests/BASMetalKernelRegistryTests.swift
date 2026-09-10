// MARK: - BASMetalKernelRegistryTests — chapter 四百三十一 / M1098

import XCTest
@testable import BASMetalSubstrate

final class BASMetalKernelRegistryTests: XCTestCase {

    // MARK: - Empty registry

    func testEmptyRegistryHasZeroKernels() async {
        let registry = BASMetalKernelRegistry()
        let count = await registry.kernelCount
        XCTAssertEqual(count, 0)
        let keys = await registry.registeredKeys
        XCTAssertTrue(keys.isEmpty)
    }

    // MARK: - Registration

    func testRegisterAddsKernel() async {
        let registry = BASMetalKernelRegistry()
        let kernel = RegistryStubKernel(
            key: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .cpuBytes))
        let previous = await registry.register(kernel)
        XCTAssertNil(previous, "first registration: no prior")
        let count = await registry.kernelCount
        XCTAssertEqual(count, 1)
    }

    func testRegisterReplacesByKey() async {
        let registry = BASMetalKernelRegistry()
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .cpuBytes)
        let k1 = RegistryStubKernel(key: key, marker: "v1")
        let k2 = RegistryStubKernel(key: key, marker: "v2")
        await registry.register(k1)
        let previous = await registry.register(k2)
        let prevAsStub = previous as? RegistryStubKernel
        XCTAssertEqual(prevAsStub?.marker, "v1",
            "second registration must return v1 as previous")
        let count = await registry.kernelCount
        XCTAssertEqual(count, 1, "still one slot for the key")
        let lookup = await registry.kernel(for: key)
        let lookupAsStub = lookup as? RegistryStubKernel
        XCTAssertEqual(
            lookupAsStub?.marker, "v2",
            "lookup must return the latest registration")
    }

    func testUnregisterRemovesKernel() async {
        let registry = BASMetalKernelRegistry()
        let key = BASKernelKey(
            operation: .softmax,
            dataType: .float32,
            backingKind: .cpuBytes)
        await registry.register(RegistryStubKernel(key: key))
        let removed = await registry.unregister(key: key)
        XCTAssertNotNil(removed)
        let count = await registry.kernelCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Lookup

    func testLookupReturnsNilForUnregisteredKey() async {
        let registry = BASMetalKernelRegistry()
        let lookup = await registry.kernel(
            for: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .cpuBytes))
        XCTAssertNil(lookup)
    }

    func testKernelsForOperationFiltersAndSorts() async {
        let registry = BASMetalKernelRegistry()
        // Register matMul × {float32, float16} × {cpu, mlx}
        await registry.register(
            RegistryStubKernel(
                key: BASKernelKey(
                    operation: .matMul,
                    dataType: .float32,
                    backingKind: .cpuBytes)))
        await registry.register(
            RegistryStubKernel(
                key: BASKernelKey(
                    operation: .matMul,
                    dataType: .float16,
                    backingKind: .mlxArray)))
        await registry.register(
            RegistryStubKernel(
                key: BASKernelKey(
                    operation: .softmax,
                    dataType: .float32,
                    backingKind: .cpuBytes)))
        let matMulKernels = await registry.kernels(
            forOperation: .matMul)
        XCTAssertEqual(matMulKernels.count, 2)
        // Sorted by wireFormIdentifier
        XCTAssertEqual(
            matMulKernels[0].key.wireFormIdentifier,
            "mat-mul|float16|mlx-array")
        XCTAssertEqual(
            matMulKernels[1].key.wireFormIdentifier,
            "mat-mul|float32|cpu-bytes")
    }

    // MARK: - Dispatch facade

    func testDispatchRoutesToRegisteredKernel() async throws {
        let registry = BASMetalKernelRegistry()
        let key = BASKernelKey(
            operation: .rmsNorm,
            dataType: .float32,
            backingKind: .cpuBytes)
        await registry.register(
            RegistryStubKernel(key: key))
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [Data(count: 16)])
        let result = try await registry.dispatch(
            key: key, inputs: inputs)
        XCTAssertEqual(result.routedKey, key)
        XCTAssertEqual(
            result.outputs.payloads, inputs.payloads)
    }

    func testDispatchThrowsLookupErrorForMissingKey() async {
        let registry = BASMetalKernelRegistry()
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .cpuBytes)
        do {
            _ = try await registry.dispatch(
                key: key, inputs: .empty)
            XCTFail("expected throw")
        } catch let err as BASKernelLookupError {
            XCTAssertEqual(
                err,
                .noKernelRegistered(key: key))
        } catch {
            XCTFail("expected BASKernelLookupError")
        }
    }

    // MARK: - Determinism

    func testRegisteredKeysOrderingIsDeterministic() async {
        let registry = BASMetalKernelRegistry()
        // Register in NON-sorted order
        await registry.register(
            RegistryStubKernel(
                key: BASKernelKey(
                    operation: .softmax,
                    dataType: .float32,
                    backingKind: .cpuBytes)))
        await registry.register(
            RegistryStubKernel(
                key: BASKernelKey(
                    operation: .matMul,
                    dataType: .float32,
                    backingKind: .cpuBytes)))
        await registry.register(
            RegistryStubKernel(
                key: BASKernelKey(
                    operation: .layerNorm,
                    dataType: .float16,
                    backingKind: .mlxArray)))
        let keys = await registry.registeredKeys
        // Sorted by wireFormIdentifier
        XCTAssertEqual(keys.map { $0.wireFormIdentifier }, [
            "layer-norm|float16|mlx-array",
            "mat-mul|float32|cpu-bytes",
            "softmax|float32|cpu-bytes"
        ])
    }
}

// MARK: - Test stub kernel

/// Stub identity kernel for registry dispatch tests。 Carries
/// a `marker` so registration-replacement tests can verify
/// which version is currently registered。
struct RegistryStubKernel: BASMetalKernel {
    let key: BASKernelKey
    let marker: String
    init(key: BASKernelKey, marker: String = "default") {
        self.key = key
        self.marker = marker
    }
    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 0)
    }
}
