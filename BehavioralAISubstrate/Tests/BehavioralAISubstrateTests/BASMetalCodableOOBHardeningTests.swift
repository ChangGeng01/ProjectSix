import XCTest
@testable import BASMetalSubstrate

/// audit M-l / metal #3 — the kernel input/output bundles enforce `descriptor.byteCount ==
/// payload.count` in their memberwise `init` (via `precondition`), and `BASTensorDescriptor`'s doc
/// contract requires shape entries > 0 — but synthesized `Codable` decoding BYPASSED both. A crafted
/// bundle whose descriptor claims more bytes than its payload holds would decode fine, then a kernel
/// (e.g. matMul) copies `byteCount` bytes out of the shorter payload → heap out-of-bounds read.
///
/// These are pure-Swift decode-boundary tests — NO GPU. They prove the custom `init(from:)`
/// validators reject crafted input (throw `DecodingError`) while valid bundles still round-trip.
final class BASMetalCodableOOBHardeningTests: XCTestCase {

    private func desc(_ shape: [Int]) -> BASTensorDescriptor {
        // strides count must equal shape count; the values don't affect byteCount (shape-only).
        BASTensorDescriptor(
            shape: shape, strides: shape.map { _ in 4 },
            dataType: .float32, backingKind: .metalBuffer, rankTag: "rank-\(shape.count)")
    }

    // MARK: - BASKernelInputs: byteCount vs payload mismatch is rejected on decode

    func testKernelInputsDecodeRejectsByteCountMismatch() throws {
        // Valid bundle: shape [4,4] float32 = 64 bytes, payload = 64 bytes.
        let good = BASKernelInputs(descriptors: [desc([4, 4])], payloads: [Data(count: 64)])
        let json = try JSONEncoder().encode(good)
        // Round-trip of a VALID bundle must still work (no false positive).
        XCTAssertNoThrow(try JSONDecoder().decode(BASKernelInputs.self, from: json))

        // Craft the OOB vector: keep the 64-byte descriptor, shrink the payload to 4 bytes.
        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        obj["payloads"] = [Data(count: 4).base64EncodedString()]
        let tampered = try JSONSerialization.data(withJSONObject: obj)

        XCTAssertThrowsError(try JSONDecoder().decode(BASKernelInputs.self, from: tampered)) { err in
            guard case DecodingError.dataCorrupted = err else {
                return XCTFail("expected DecodingError.dataCorrupted, got \(err)")
            }
        }
    }

    func testKernelOutputsDecodeRejectsByteCountMismatch() throws {
        let good = BASKernelOutputs(descriptors: [desc([2, 2])], payloads: [Data(count: 16)], executionNanos: 7)
        let json = try JSONEncoder().encode(good)
        XCTAssertNoThrow(try JSONDecoder().decode(BASKernelOutputs.self, from: json))

        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        obj["payloads"] = [Data(count: 2).base64EncodedString()]   // 16-byte descriptor, 2-byte payload
        let tampered = try JSONSerialization.data(withJSONObject: obj)
        XCTAssertThrowsError(try JSONDecoder().decode(BASKernelOutputs.self, from: tampered)) { err in
            guard case DecodingError.dataCorrupted = err else {
                return XCTFail("expected DecodingError.dataCorrupted, got \(err)")
            }
        }
    }

    // MARK: - BASTensorDescriptor: non-positive / mismatched-stride shapes rejected on decode

    func testDescriptorDecodeRejectsNonPositiveShape() throws {
        for badShape in [[0, 4], [-1, 4], [4, 0]] {
            let obj: [String: Any] = [
                "shape": badShape, "strides": [16, 4],
                "dataType": "float32", "backingKind": "metal-buffer", "rankTag": "rank-2"]
            let data = try JSONSerialization.data(withJSONObject: obj)
            XCTAssertThrowsError(try JSONDecoder().decode(BASTensorDescriptor.self, from: data),
                "shape \(badShape) must be rejected") { err in
                guard case DecodingError.dataCorrupted = err else {
                    return XCTFail("expected dataCorrupted for shape \(badShape), got \(err)")
                }
            }
        }
    }

    func testDescriptorDecodeRejectsStrideCountMismatch() throws {
        let obj: [String: Any] = [
            "shape": [4, 4], "strides": [16],   // strides.count (1) != shape.count (2)
            "dataType": "float32", "backingKind": "metal-buffer", "rankTag": "rank-2"]
        let data = try JSONSerialization.data(withJSONObject: obj)
        XCTAssertThrowsError(try JSONDecoder().decode(BASTensorDescriptor.self, from: data)) { err in
            guard case DecodingError.dataCorrupted = err else {
                return XCTFail("expected dataCorrupted, got \(err)")
            }
        }
    }

    func testValidDescriptorAndScalarStillRoundTrip() throws {
        // A normal rank-2 tensor and a rank-0 scalar (empty shape) must both decode cleanly.
        for d in [desc([4, 4]), BASTensorDescriptor(shape: [], strides: [], dataType: .float32, backingKind: .cpuBytes, rankTag: "scalar")] {
            let json = try JSONEncoder().encode(d)
            let back = try JSONDecoder().decode(BASTensorDescriptor.self, from: json)
            XCTAssertEqual(back, d)
        }
    }
}
