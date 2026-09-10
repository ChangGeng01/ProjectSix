import XCTest
import CryptoKit
import Darwin
@testable import BASAppleAdapters
#if canImport(CoreAI)
import CoreAI
#endif

final class BASStateLakeArtifactDecoderTests: XCTestCase {
    func testStrictIntegerMetadataRejectsBooleansFractionsNegativesAndOverflow() throws {
        let payload = Data([0x00, 0x3c])
        let malformed: [[String: Any]] = [
            header(promptLen: true, tensors: [tensorRecord()]),
            header(promptLen: 0.5, tensors: [tensorRecord()]),
            header(promptLen: -1, tensors: [tensorRecord()]),
            header(tensors: [tensorRecord(shape: [true])]),
            header(tensors: [tensorRecord(shape: [1.5])]),
            header(tensors: [tensorRecord(start: true)]),
            header(tensors: [tensorRecord(start: 0.5)]),
            header(tensors: [tensorRecord(start: -1)]),
            header(tensors: [tensorRecord(nbytes: true)]),
            header(tensors: [tensorRecord(nbytes: 1.5)]),
            header(tensors: [tensorRecord(nbytes: -1)]),
        ]

        for object in malformed {
            let fixture = try Fixture(header: object, payload: payload)
            assertHeaderError { try decode(fixture) }
        }

        let checksum = sha256(payload)
        let overflowingInteger = """
        {"format":"statelake-device/1","binding_key":"binding","prompt_len":9223372036854775808,
         "checksum":"\(checksum)","tensors":[]}
        """
        let overflowFixture = try Fixture(headerData: Data(overflowingInteger.utf8), payload: payload)
        assertHeaderError { try decode(overflowFixture, stateOrder: []) }
    }

    func testShapeValidationRejectsEmptyZeroExcessiveRankAndOverflow() throws {
        let payload = Data([0x00, 0x3c])
        let cases: [([Any], BASStateLakeReadLimits)] = [
            ([], .standard),
            ([0], .standard),
            ([-1], .standard),
            ([1, 1, 1], limits(maxRank: 2)),
            ([Int.max, 2], .standard),
        ]

        for (shape, readLimits) in cases {
            let fixture = try Fixture(header: header(tensors: [tensorRecord(shape: shape)]), payload: payload)
            assertHeaderError { try decode(fixture, limits: readLimits) }
        }

        let encodedByteOverflow = try Fixture(
            header: header(tensors: [tensorRecord(shape: [Int.max], nbytes: Int.max)]),
            payload: payload
        )
        assertHeaderError { try decode(encodedByteOverflow) }

        let decodedByteOverflow = try Fixture(
            header: header(
                tensors: [tensorRecord(dtype: "int8", shape: [Int.max], nbytes: Int.max)]
            ),
            payload: payload
        )
        assertHeaderError { try decode(decodedByteOverflow) }
    }

    func testRangesAndByteRelationshipsRejectBadStartEndTruncationAndMismatch() throws {
        let payload = Data([0x00, 0x3c])
        let badRecords = [
            tensorRecord(start: 3),
            tensorRecord(start: 1, nbytes: 2),
            tensorRecord(shape: [2], nbytes: 2),
            tensorRecord(dtype: "int8", shape: [1], nbytes: 2),
        ]

        for badRecord in badRecords {
            let fixture = try Fixture(header: header(tensors: [badRecord]), payload: payload)
            assertHeaderError { try decode(fixture) }
        }
    }

    func testUnsupportedFormatDTypeDuplicateNamesAndUnrequestedInvalidRecordAreRejected() throws {
        let payload = Data([0x00, 0x3c, 0x00, 0x40])
        let fixtures = try [
            Fixture(header: header(format: "statelake-device/2", tensors: [tensorRecord()]), payload: payload),
            Fixture(header: header(tensors: [tensorRecord(name: "")]), payload: payload),
            Fixture(header: header(tensors: [tensorRecord(dtype: "float32")]), payload: payload),
            Fixture(header: header(tensors: [tensorRecord(), tensorRecord(start: 2)]), payload: payload),
            Fixture(
                header: header(tensors: [tensorRecord(), tensorRecord(name: "ignored", dtype: "float32", start: 2)]),
                payload: payload
            ),
        ]

        var missingScale = tensorRecord()
        missingScale.removeValue(forKey: "scale")

        for fixture in fixtures {
            assertHeaderError { try decode(fixture) }
        }
        let missingScaleFixture = try Fixture(header: header(tensors: [missingScale]), payload: payload)
        assertHeaderError { try decode(missingScaleFixture) }
    }

    func testInvalidAndOverflowingInt8ScalesAndNonfiniteFP16AreRejected() throws {
        let invalidScales: [Any] = [
            true,
            0.0,
            -0.5,
            Double.leastNonzeroMagnitude,
            Double.greatestFiniteMagnitude,
        ]
        for scale in invalidScales {
            let fixture = try Fixture(
                header: header(tensors: [tensorRecord(scale: scale, dtype: "int8", nbytes: 1)]),
                payload: Data([0x7f])
            )
            assertHeaderError { try decode(fixture) }
        }

        let infinity = try Fixture(
            header: header(tensors: [tensorRecord()]),
            payload: Data([0x00, 0x7c])
        )
        assertHeaderError { try decode(infinity) }
    }

    func testMissingRequestedStateHasItsOwnErrorCategory() throws {
        let fixture = try Fixture(header: header(tensors: [tensorRecord()]), payload: Data([0x00, 0x3c]))
        XCTAssertThrowsError(try decode(fixture, stateOrder: ["absent"])) { error in
            guard case .missing = error as? BASStateLakeDecodeError else {
                return XCTFail("expected missing error, got \(error)")
            }
        }
    }

    func testBindingAndChecksumKeepTheirErrorCategories() throws {
        let fixture = try Fixture(header: header(tensors: [tensorRecord()]), payload: Data([0x00, 0x3c]))
        XCTAssertThrowsError(
            try BASStateLakeArtifactDecoder.load(
                fixture.directory,
                expectedBindingKey: "wrong",
                stateOrder: ["state"]
            )
        ) { error in
            guard case .bindingKey = error as? BASStateLakeDecodeError else {
                return XCTFail("expected bindingKey error, got \(error)")
            }
        }

        try Data([0xff, 0x3c]).write(to: fixture.payloadURL)
        XCTAssertThrowsError(try decode(fixture)) { error in
            guard case .checksum = error as? BASStateLakeDecodeError else {
                return XCTFail("expected checksum error, got \(error)")
            }
        }
    }

    func testEveryLimitAcceptsExactBoundaryAndRejectsOnePast() throws {
        let one = try Fixture(header: header(tensors: [tensorRecord()]), payload: Data([0x00, 0x3c]))

        XCTAssertNoThrow(try decode(one, limits: limits(maxHeaderBytes: one.headerData.count)))
        assertHeaderError { try decode(one, limits: limits(maxHeaderBytes: one.headerData.count - 1)) }

        XCTAssertNoThrow(try decode(one, limits: limits(maxPayloadBytes: 2)))
        assertHeaderError { try decode(one, limits: limits(maxPayloadBytes: 1)) }

        XCTAssertNoThrow(try decode(one, limits: limits(maxDecodedFloat16Bytes: 2)))
        assertHeaderError { try decode(one, limits: limits(maxDecodedFloat16Bytes: 1)) }

        let two = try Fixture(
            header: header(tensors: [tensorRecord(name: "a"), tensorRecord(name: "b", start: 2)]),
            payload: Data([0x00, 0x3c, 0x00, 0x40])
        )
        XCTAssertNoThrow(try decode(two, stateOrder: ["a"], limits: limits(maxRecordCount: 2)))
        assertHeaderError { try decode(two, stateOrder: ["a"], limits: limits(maxRecordCount: 1)) }
        XCTAssertNoThrow(
            try decode(two, stateOrder: ["a"], limits: limits(maxDecodedFloat16Bytes: 4))
        )
        assertHeaderError {
            try decode(two, stateOrder: ["a"], limits: limits(maxDecodedFloat16Bytes: 3))
        }

        let rankTwo = try Fixture(
            header: header(tensors: [tensorRecord(shape: [1, 1])]),
            payload: Data([0x00, 0x3c])
        )
        XCTAssertNoThrow(try decode(rankTwo, limits: limits(maxRank: 2)))
        assertHeaderError { try decode(rankTwo, limits: limits(maxRank: 1)) }
    }

    func testInvalidLimitsFailBeforeReadingFiles() {
        let nonexistent = URL(fileURLWithPath: "/this/task17/path/does/not/exist")
        assertHeaderError {
            _ = try BASStateLakeArtifactDecoder.load(
                nonexistent,
                expectedBindingKey: "binding",
                stateOrder: [],
                limits: limits(maxHeaderBytes: -1)
            )
        }
    }

    func testNonRegularFIFOIsRejectedWithoutWaitingForAWriter() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BASStateLakeFIFO-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(mkfifo(directory.appendingPathComponent("header.json").path, S_IRUSR | S_IWUSR), 0)

        assertHeaderError {
            _ = try BASStateLakeArtifactDecoder.load(
                directory,
                expectedBindingKey: "binding",
                stateOrder: []
            )
        }
    }

    func testMixedInt8AndOddOffsetFP16DecodePreservesValuesAndArtifactBytes() throws {
        let payload = Data([0xfe, 0x00, 0x3e, 0x00, 0xc0])
        let fixture = try Fixture(
            header: header(
                promptLen: 3,
                tensors: [
                    tensorRecord(name: "quant", scale: 0.5, dtype: "int8", shape: [1], start: 0, nbytes: 1),
                    tensorRecord(name: "exact", shape: [2], start: 1, nbytes: 4),
                ]
            ),
            payload: payload
        )

        let decoded = try decode(fixture, stateOrder: ["exact", "quant", "exact"])
        XCTAssertEqual(decoded.promptLen, 3)
        XCTAssertEqual(decoded.tensors.map(\.name), ["quant", "exact"])
        XCTAssertEqual(decoded.tensors[0].scalars, [Float16(-1)])
        XCTAssertEqual(decoded.tensors[1].scalars, [Float16(1.5), Float16(-2)])
        XCTAssertEqual(try Data(contentsOf: fixture.payloadURL), payload)
    }

    func testInt8DecodePreservesRetainedFloat32RoundingOrder() throws {
        // The existing reader narrows the writer's JSON scale to Float32
        // before multiplication. Multiplying as Double changes this exact
        // Float16 result by one bit (0x006e -> 0x006f).
        let scale = Double(Float(bitPattern: 0x3391_d07f))
        let fixture = try Fixture(
            header: header(tensors: [tensorRecord(scale: scale, dtype: "int8", nbytes: 1)]),
            payload: Data([97])
        )

        let decoded = try decode(fixture)
        XCTAssertEqual(decoded.tensors[0].scalars[0].bitPattern, 0x006e)
    }

    private func decode(
        _ fixture: Fixture,
        stateOrder: [String] = ["state"],
        limits: BASStateLakeReadLimits = .standard
    ) throws -> BASStateLakeDecodedArtifact {
        try BASStateLakeArtifactDecoder.load(
            fixture.directory,
            expectedBindingKey: "binding",
            stateOrder: stateOrder,
            limits: limits
        )
    }

    private func assertHeaderError(
        _ operation: () throws -> Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            guard case .header = error as? BASStateLakeDecodeError else {
                return XCTFail("expected header error, got \(error)", file: file, line: line)
            }
        }
    }
}

#if canImport(CoreAI)

final class BASStateLakeReaderTests: XCTestCase {
    @available(iOS 27, macOS 27, *)
    func testPublicLoadRejectsUnsupportedDType() throws {
        let fixture = try Fixture(
            header: header(tensors: [tensorRecord(dtype: "not-a-dtype")]),
            payload: Data([0x00, 0x3c])
        )

        XCTAssertThrowsError(
            try BASStateLakeReader.load(
                fixture.directory,
                expectedBindingKey: "binding",
                stateOrder: ["state"]
            )
        )
    }

    @available(iOS 27, macOS 27, *)
    func testPublicLoadBuildsTinyNDArraysInRequestedOrderWithoutChangingBytes() throws {
        let payload = Data([0xfe, 0x00, 0x3e, 0x00, 0xc0])
        let fixture = try Fixture(
            header: header(
                promptLen: 3,
                tensors: [
                    tensorRecord(name: "quant", scale: 0.5, dtype: "int8", shape: [1], start: 0, nbytes: 1),
                    tensorRecord(name: "exact", shape: [2], start: 1, nbytes: 4),
                ]
            ),
            payload: payload
        )

        let loaded = try BASStateLakeReader.load(
            fixture.directory,
            expectedBindingKey: "binding",
            stateOrder: ["exact", "quant", "exact"]
        )

        XCTAssertEqual(loaded.promptLen, 3)
        XCTAssertEqual(loaded.states.count, 3)
        XCTAssertEqual(float16Scalars(loaded.states[0], count: 2), [Float16(1.5), Float16(-2)])
        XCTAssertEqual(float16Scalars(loaded.states[1], count: 1), [Float16(-1)])
        XCTAssertEqual(float16Scalars(loaded.states[2], count: 2), [Float16(1.5), Float16(-2)])
        XCTAssertEqual(try Data(contentsOf: fixture.payloadURL), payload)
    }

    @available(iOS 27, macOS 27, *)
    func testPublicLoadPreservesBindingChecksumAndMissingErrorCategories() throws {
        let fixture = try Fixture(
            header: header(tensors: [tensorRecord()]),
            payload: Data([0x00, 0x3c])
        )

        XCTAssertThrowsError(
            try BASStateLakeReader.load(
                fixture.directory,
                expectedBindingKey: "wrong",
                stateOrder: ["state"]
            )
        ) { error in
            guard case .bindingKey = error as? BASStateLakeReader.Error else {
                return XCTFail("expected public bindingKey error, got \(error)")
            }
        }

        try Data([0xff, 0x3c]).write(to: fixture.payloadURL)
        XCTAssertThrowsError(
            try BASStateLakeReader.load(
                fixture.directory,
                expectedBindingKey: "binding",
                stateOrder: ["state"]
            )
        ) { error in
            guard case .checksum = error as? BASStateLakeReader.Error else {
                return XCTFail("expected public checksum error, got \(error)")
            }
        }

        try Data([0x00, 0x3c]).write(to: fixture.payloadURL)
        XCTAssertThrowsError(
            try BASStateLakeReader.load(
                fixture.directory,
                expectedBindingKey: "binding",
                stateOrder: ["absent"]
            )
        ) { error in
            guard case .missing = error as? BASStateLakeReader.Error else {
                return XCTFail("expected public missing error, got \(error)")
            }
        }
    }

    @available(iOS 27, macOS 27, *)
    private func float16Scalars(_ array: NDArray, count: Int) -> [Float16] {
        var result: [Float16] = []
        result.reserveCapacity(count)
        array.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
            for index in 0..<count {
                result.append(pointer[index])
            }
        }
        return result
    }
}

#endif

private final class Fixture {
    let directory: URL
    let headerData: Data
    var payloadURL: URL { directory.appendingPathComponent("payload.bin") }

    convenience init(header: [String: Any], payload: Data) throws {
        var boundHeader = header
        boundHeader["checksum"] = sha256(payload)
        try self.init(headerData: JSONSerialization.data(withJSONObject: boundHeader), payload: payload)
    }

    init(headerData: Data, payload: Data) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BASStateLakeReaderTests-\(UUID().uuidString)", isDirectory: true)
        self.headerData = headerData
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try headerData.write(to: directory.appendingPathComponent("header.json"))
        try payload.write(to: payloadURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

private func header(
    format: String = "statelake-device/1",
    promptLen: Any = 0,
    tensors: [[String: Any]]
) -> [String: Any] {
    [
        "format": format,
        "binding_key": "binding",
        "prompt_len": promptLen,
        "checksum": "",
        "tensors": tensors,
    ]
}

private func tensorRecord(
    name: String = "state",
    scale: Any = 1.0,
    dtype: String = "fp16",
    shape: [Any] = [1],
    start: Any = 0,
    nbytes: Any = 2
) -> [String: Any] {
    [
        "name": name,
        "scale": scale,
        "dtype": dtype,
        "shape": shape,
        "start": start,
        "nbytes": nbytes,
    ]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func limits(
    maxHeaderBytes: Int = 1 << 20,
    maxPayloadBytes: Int = 1 << 20,
    maxDecodedFloat16Bytes: Int = 1 << 20,
    maxRecordCount: Int = 1_024,
    maxRank: Int = 16
) -> BASStateLakeReadLimits {
    BASStateLakeReadLimits(
        maxHeaderBytes: maxHeaderBytes,
        maxPayloadBytes: maxPayloadBytes,
        maxDecodedFloat16Bytes: maxDecodedFloat16Bytes,
        maxRecordCount: maxRecordCount,
        maxRank: maxRank
    )
}
