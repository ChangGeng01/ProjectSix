// MARK: - BASStateLakeArtifactDecoder
//
// Bounded, framework-free validation and byte decoding for the retained
// statelake-device/1 experiment. The public CoreAI reader below materializes
// NDArrays only after this layer has validated every record.

import Foundation
import Crypto
import Darwin

internal struct BASStateLakeReadLimits: Equatable, Sendable {
    // These are reader policy, not fields in statelake-device/1. Decimal
    // literals avoid unchecked arithmetic while constructing the limits.
    static let standard = BASStateLakeReadLimits(
        maxHeaderBytes: 1_048_576,              // 1 MiB
        maxPayloadBytes: 67_108_864,            // 64 MiB
        maxDecodedFloat16Bytes: 134_217_728,    // 128 MiB
        maxRecordCount: 1_024,
        maxRank: 16
    )

    let maxHeaderBytes: Int
    let maxPayloadBytes: Int
    let maxDecodedFloat16Bytes: Int
    let maxRecordCount: Int
    let maxRank: Int
}

internal enum BASStateLakeDecodeError: Swift.Error, Equatable {
    case header(String)
    case bindingKey(String)
    case checksum(String)
    case missing(String)
}

internal struct BASStateLakeDecodedArtifact: Equatable {
    struct Tensor: Equatable {
        let name: String
        let shape: [Int]
        let scalars: [Float16]
    }

    let tensors: [Tensor]
    let promptLen: Int
}

internal enum BASStateLakeArtifactDecoder {
    private static let format = "statelake-device/1"
    private static let readChunkBytes = 16_384

    static func load(
        _ directory: URL,
        expectedBindingKey: String,
        stateOrder: [String],
        limits: BASStateLakeReadLimits = .standard
    ) throws -> BASStateLakeDecodedArtifact {
        try validate(limits: limits)

        let headerData = try readBoundedRegularFile(
            directory.appendingPathComponent("header.json"),
            maximumBytes: limits.maxHeaderBytes,
            role: "header.json"
        )
        let header: Header
        do {
            header = try JSONDecoder().decode(Header.self, from: headerData)
        } catch {
            throw BASStateLakeDecodeError.header("malformed header.json: \(error)")
        }

        guard header.format == format else {
            throw BASStateLakeDecodeError.header("unsupported StateLake format \(header.format)")
        }
        guard header.promptLen >= 0 else {
            throw BASStateLakeDecodeError.header("prompt_len must be nonnegative")
        }
        guard header.bindingKey == expectedBindingKey else {
            throw BASStateLakeDecodeError.bindingKey(
                "artifact \(header.bindingKey.prefix(12)) != expected \(expectedBindingKey.prefix(12)) — refusing stale state"
            )
        }
        guard header.tensors.count <= limits.maxRecordCount else {
            throw BASStateLakeDecodeError.header("tensor record count exceeds reader limit")
        }

        var names = Set<String>()
        var validated: [ValidatedRecord] = []
        validated.reserveCapacity(header.tensors.count)
        var aggregateDecodedBytes = 0

        for record in header.tensors {
            guard !record.name.isEmpty else {
                throw BASStateLakeDecodeError.header("tensor name must be nonempty")
            }
            guard names.insert(record.name).inserted else {
                throw BASStateLakeDecodeError.header("duplicate tensor name \(record.name)")
            }
            guard !record.shape.isEmpty, record.shape.count <= limits.maxRank else {
                throw BASStateLakeDecodeError.header("invalid rank for tensor \(record.name)")
            }
            guard record.start >= 0, record.nbytes >= 0 else {
                throw BASStateLakeDecodeError.header("negative byte range for tensor \(record.name)")
            }

            var scalarCount = 1
            for dimension in record.shape {
                guard dimension > 0 else {
                    throw BASStateLakeDecodeError.header("nonpositive shape extent for tensor \(record.name)")
                }
                let (next, overflowed) = scalarCount.multipliedReportingOverflow(by: dimension)
                guard !overflowed else {
                    throw BASStateLakeDecodeError.header("shape product overflow for tensor \(record.name)")
                }
                scalarCount = next
            }

            let dtype: DType
            switch record.dtype {
            case "int8":
                guard record.scale.isFinite, record.scale > 0 else {
                    throw BASStateLakeDecodeError.header("invalid int8 scale for tensor \(record.name)")
                }
                let scale = Float(record.scale)
                guard scale.isFinite, scale > 0 else {
                    throw BASStateLakeDecodeError.header("int8 scale is not representable for tensor \(record.name)")
                }
                dtype = .int8(scale: scale)
            case "fp16":
                dtype = .fp16
            default:
                throw BASStateLakeDecodeError.header("unsupported dtype \(record.dtype) for tensor \(record.name)")
            }

            let (expectedByteCount, byteCountOverflowed) = scalarCount.multipliedReportingOverflow(
                by: dtype.encodedBytesPerScalar
            )
            guard !byteCountOverflowed, expectedByteCount == record.nbytes else {
                throw BASStateLakeDecodeError.header("byte count does not match shape for tensor \(record.name)")
            }

            let (decodedBytes, decodedBytesOverflowed) = scalarCount.multipliedReportingOverflow(
                by: MemoryLayout<Float16>.stride
            )
            guard !decodedBytesOverflowed else {
                throw BASStateLakeDecodeError.header("decoded byte count overflow for tensor \(record.name)")
            }
            let (nextAggregate, aggregateOverflowed) = aggregateDecodedBytes.addingReportingOverflow(decodedBytes)
            guard !aggregateOverflowed, nextAggregate <= limits.maxDecodedFloat16Bytes else {
                throw BASStateLakeDecodeError.header("decoded Float16 allocation exceeds reader limit")
            }
            aggregateDecodedBytes = nextAggregate

            validated.append(
                ValidatedRecord(
                    name: record.name,
                    shape: record.shape,
                    dtype: dtype,
                    start: record.start,
                    nbytes: record.nbytes,
                    scalarCount: scalarCount
                )
            )
        }

        let payload = try readBoundedRegularFile(
            directory.appendingPathComponent("payload.bin"),
            maximumBytes: limits.maxPayloadBytes,
            role: "payload.bin"
        )
        let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        guard checksum == header.checksum else {
            throw BASStateLakeDecodeError.checksum("payload sha256 mismatch — corrupt .statelake")
        }

        for record in validated {
            guard record.start <= payload.count,
                  record.nbytes <= payload.count - record.start else {
                throw BASStateLakeDecodeError.header("tensor \(record.name) byte range is outside payload")
            }
        }

        for requestedName in Set(stateOrder) where !names.contains(requestedName) {
            throw BASStateLakeDecodeError.missing("tensor \(requestedName) absent from .statelake")
        }

        // Inspect every numeric value before allocating any decoded Float16
        // tensor. This includes records not requested by stateOrder.
        for record in validated {
            try validateNumericValues(record, in: payload)
        }

        var decodedTensors: [BASStateLakeDecodedArtifact.Tensor] = []
        decodedTensors.reserveCapacity(validated.count)
        for record in validated {
            decodedTensors.append(
                BASStateLakeDecodedArtifact.Tensor(
                    name: record.name,
                    shape: record.shape,
                    scalars: decode(record, from: payload)
                )
            )
        }
        return BASStateLakeDecodedArtifact(tensors: decodedTensors, promptLen: header.promptLen)
    }

    private static func validate(limits: BASStateLakeReadLimits) throws {
        guard limits.maxHeaderBytes >= 0,
              limits.maxPayloadBytes >= 0,
              limits.maxDecodedFloat16Bytes >= 0,
              limits.maxRecordCount >= 0,
              limits.maxRank >= 1 else {
            throw BASStateLakeDecodeError.header("invalid StateLake reader limits")
        }
    }

    private static func validateNumericValues(_ record: ValidatedRecord, in payload: Data) throws {
        switch record.dtype {
        case .int8(let scale):
            for index in 0..<record.scalarCount {
                let quantized = Int8(bitPattern: byte(in: payload, at: record.start + index))
                let value = Float(quantized) * scale
                guard value.isFinite, abs(value) <= Float(Float16.greatestFiniteMagnitude) else {
                    throw BASStateLakeDecodeError.header(
                        "int8 dequantization is not representable as Float16 for tensor \(record.name)"
                    )
                }
            }
        case .fp16:
            for index in 0..<record.scalarCount {
                let value = fp16(in: payload, at: record.start + index * 2)
                guard value.isFinite else {
                    throw BASStateLakeDecodeError.header("nonfinite fp16 value for tensor \(record.name)")
                }
            }
        }
    }

    private static func decode(_ record: ValidatedRecord, from payload: Data) -> [Float16] {
        var scalars: [Float16] = []
        scalars.reserveCapacity(record.scalarCount)
        switch record.dtype {
        case .int8(let scale):
            for index in 0..<record.scalarCount {
                let quantized = Int8(bitPattern: byte(in: payload, at: record.start + index))
                scalars.append(Float16(Float(quantized) * scale))
            }
        case .fp16:
            for index in 0..<record.scalarCount {
                scalars.append(fp16(in: payload, at: record.start + index * 2))
            }
        }
        return scalars
    }

    private static func byte(in data: Data, at offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }

    private static func fp16(in data: Data, at offset: Int) -> Float16 {
        let low = UInt16(byte(in: data, at: offset))
        let high = UInt16(byte(in: data, at: offset + 1))
        return Float16(bitPattern: low | (high << 8))
    }

    private static func readBoundedRegularFile(
        _ url: URL,
        maximumBytes: Int,
        role: String
    ) throws -> Data {
        let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return Darwin.open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        }
        guard descriptor >= 0 else {
            throw BASStateLakeDecodeError.header("cannot open \(role): errno \(errno)")
        }
        defer { _ = Darwin.close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0 else {
            throw BASStateLakeDecodeError.header("cannot inspect \(role): errno \(errno)")
        }
        guard (before.st_mode & S_IFMT) == S_IFREG else {
            throw BASStateLakeDecodeError.header("\(role) is not a regular file")
        }
        guard before.st_size >= 0, UInt64(before.st_size) <= UInt64(maximumBytes) else {
            throw BASStateLakeDecodeError.header("\(role) exceeds reader byte limit")
        }

        var result = Data()
        result.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: readChunkBytes)
        while true {
            let remaining = maximumBytes - result.count
            let requestedCount = remaining == 0 ? 1 : min(readChunkBytes, remaining)
            let count = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(descriptor, rawBuffer.baseAddress, requestedCount)
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw BASStateLakeDecodeError.header("cannot read \(role): errno \(errno)")
            }
            guard count <= remaining else {
                throw BASStateLakeDecodeError.header("\(role) exceeds reader byte limit")
            }
            result.append(contentsOf: buffer.prefix(count))
        }

        var after = stat()
        guard fstat(descriptor, &after) == 0 else {
            throw BASStateLakeDecodeError.header("cannot re-inspect \(role): errno \(errno)")
        }
        guard before.st_dev == after.st_dev,
              before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else {
            throw BASStateLakeDecodeError.header("\(role) changed while it was being read")
        }
        return result
    }
}

private extension BASStateLakeArtifactDecoder {
    struct Header: Decodable {
        let format: String
        let bindingKey: String
        let promptLen: Int
        let checksum: String
        let tensors: [TensorRecord]

        enum CodingKeys: String, CodingKey {
            case format
            case bindingKey = "binding_key"
            case promptLen = "prompt_len"
            case checksum
            case tensors
        }
    }

    struct TensorRecord: Decodable {
        let name: String
        let shape: [Int]
        let scale: Double
        let dtype: String
        let start: Int
        let nbytes: Int
    }

    enum DType {
        case int8(scale: Float)
        case fp16

        var encodedBytesPerScalar: Int {
            switch self {
            case .int8: 1
            case .fp16: 2
            }
        }
    }

    struct ValidatedRecord {
        let name: String
        let shape: [Int]
        let dtype: DType
        let start: Int
        let nbytes: Int
        let scalarCount: Int
    }
}
