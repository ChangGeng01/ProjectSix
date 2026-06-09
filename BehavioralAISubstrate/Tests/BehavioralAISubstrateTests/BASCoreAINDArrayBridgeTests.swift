import XCTest
@testable import BASAppleAdapters

/// C1 — the PURE half of the Core AI `NDArray` marshaling boundary. These run under the DEFAULT toolchain
/// (Xcode 26.5, `canImport(CoreAI)` false) — the shape/stride/count math is framework-free, so it carries real
/// run coverage today. The gated `makeNDArray` / `floats(from:)` are compile-certified under Xcode 27 and
/// run-certified on iOS 27 (exercised by the device/sim probe, not here).
final class BASCoreAINDArrayBridgeTests: XCTestCase {

    // MARK: - elementCount

    func testElementCountIsProductOfDimensions() {
        XCTAssertEqual(BASCoreAINDArrayBridge.elementCount(of: [2, 3, 4]), 24)
        XCTAssertEqual(BASCoreAINDArrayBridge.elementCount(of: [1, 256]), 256, "classifier input shape")
        XCTAssertEqual(BASCoreAINDArrayBridge.elementCount(of: [1, 7]), 7, "classifier logits shape")
        XCTAssertEqual(BASCoreAINDArrayBridge.elementCount(of: [7]), 7)
    }

    func testElementCountOfEmptyShapeIsEmptyProductOne() {
        // The empty product is 1 (rank-0 scalar). `validate` rejects empty shapes for the ranked contract,
        // but `elementCount` stays mathematically correct.
        XCTAssertEqual(BASCoreAINDArrayBridge.elementCount(of: []), 1)
    }

    // MARK: - rowMajorStrides

    func testRowMajorStridesAreCContiguous() {
        XCTAssertEqual(BASCoreAINDArrayBridge.rowMajorStrides(for: [2, 3, 4]), [12, 4, 1])
        XCTAssertEqual(BASCoreAINDArrayBridge.rowMajorStrides(for: [1, 256]), [256, 1])
        XCTAssertEqual(BASCoreAINDArrayBridge.rowMajorStrides(for: [5]), [1], "last dim is always contiguous")
    }

    func testRowMajorStridesOfEmptyShapeIsEmpty() {
        XCTAssertEqual(BASCoreAINDArrayBridge.rowMajorStrides(for: []), [])
    }

    func testRowMajorStridesIsDeterministic() {
        let shape = [3, 1, 9, 2]
        XCTAssertEqual(
            BASCoreAINDArrayBridge.rowMajorStrides(for: shape),
            BASCoreAINDArrayBridge.rowMajorStrides(for: shape),
            "pure — same shape ⇒ same strides")
        // Last stride 1; each earlier = product of all later dims: [9*2, ...] → [18, 18, 2, 1].
        XCTAssertEqual(BASCoreAINDArrayBridge.rowMajorStrides(for: shape), [18, 18, 2, 1])
    }

    // MARK: - validate (the fail-fast boundary guard)

    func testValidateAcceptsMatchingScalarCount() {
        XCTAssertNoThrow(try BASCoreAINDArrayBridge.validate(scalarCount: 256, shape: [1, 256]))
        XCTAssertNoThrow(try BASCoreAINDArrayBridge.validate(scalarCount: 7, shape: [1, 7]))
        XCTAssertNoThrow(try BASCoreAINDArrayBridge.validate(scalarCount: 6, shape: [2, 3]))
    }

    func testValidateRejectsCountMismatch() {
        XCTAssertThrowsError(
            try BASCoreAINDArrayBridge.validate(scalarCount: 5, shape: [1, 7])
        ) { error in
            XCTAssertEqual(
                error as? BASCoreAINDArrayBridgeError,
                .scalarCountMismatch(shapeProduct: 7, scalarCount: 5, shape: [1, 7]))
        }
    }

    func testValidateRejectsEmptyShape() {
        XCTAssertThrowsError(
            try BASCoreAINDArrayBridge.validate(scalarCount: 1, shape: [])
        ) { error in
            XCTAssertEqual(error as? BASCoreAINDArrayBridgeError, .emptyShape)
        }
    }

    func testValidateRejectsOverflowingShapeProduct() {
        // A pathological shape whose product overflows Int must throw .shapeProductOverflow — NOT wrap to a
        // small number that could falsely match a tiny buffer (checked multiplication at the boundary).
        XCTAssertThrowsError(
            try BASCoreAINDArrayBridge.validate(scalarCount: 2, shape: [Int.max, 2])
        ) { error in
            XCTAssertEqual(
                error as? BASCoreAINDArrayBridgeError, .shapeProductOverflow(shape: [Int.max, 2]))
        }
    }

    func testValidateRejectsNonPositiveDimension() {
        XCTAssertThrowsError(
            try BASCoreAINDArrayBridge.validate(scalarCount: 0, shape: [0])
        ) { error in
            XCTAssertEqual(error as? BASCoreAINDArrayBridgeError, .nonPositiveDimension(shape: [0]))
        }
        XCTAssertThrowsError(
            try BASCoreAINDArrayBridge.validate(scalarCount: 6, shape: [2, -3])
        ) { error in
            XCTAssertEqual(error as? BASCoreAINDArrayBridgeError, .nonPositiveDimension(shape: [2, -3]))
        }
    }

    // MARK: - The contract that ties the classifier input encoder to the bridge

    func testClassifierInputVectorMatchesItsDeclaredShape() {
        // The CoreML incumbent feeds a 256-bucket bag → Core AI must accept the SAME flat vector at shape
        // [1, 256]. This pins that the bridge's validation agrees with the model's input contract.
        let bag = Array(repeating: Float(0), count: 256)
        XCTAssertNoThrow(try BASCoreAINDArrayBridge.validate(scalarCount: bag.count, shape: [1, 256]))
    }
}
