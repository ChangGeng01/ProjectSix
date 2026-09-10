// MARK: - BASChapter724BinaryEventLogCodecTests
// chapter 七百二十四 第二刀 / M2292
//
// Swift-side anti-drift suite for the binary event log codec
// primitive (BASEventLogBinaryCodec)。 Production wiring into
// BASSQLiteEventLogStorage is deferred per chapter 七百二十四
// 第五刀 honest scope — this knife ships the codec primitive
// only。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter724BinaryEventLogCodecTests: XCTestCase {

    private func sample(
        payload: String? = nil,
        prov: String? = nil
    ) -> BASBinaryEventLogEntry {
        return BASBinaryEventLogEntry(
            entryID: "entry-\(UUID().uuidString)",
            kind: .sovereignVerdict,
            sessionRef: "session-A",
            turnRef: "turn-1",
            timestampMs: 1_700_000_000_000,
            payloadJson: payload,
            provenanceSummary: prov)
    }

    func testEncodeProducesV2SchemaByte() throws {
        #if os(iOS) || os(macOS)
        let bytes = try BASEventLogBinaryCodec.encode(sample())
        XCTAssertEqual(
            bytes.first,
            BASEventLogBinaryCodec.schemaVersionBinaryV2)
        #endif
    }

    func testRoundTripWithFullPayload() throws {
        #if os(iOS) || os(macOS)
        let entry = sample(
            payload: #"{"verdict":"allow"}"#,
            prov: "test-source")
        let bytes = try BASEventLogBinaryCodec.encode(entry)
        let back = try BASEventLogBinaryCodec.decode(bytes)
        XCTAssertEqual(entry, back)
        #endif
    }

    // audit runtimecore-b #7: decode must work on a non-zero-based Data SLICE, not just a 0-based
    // Data — `buf[pos]` indexes by Data's own indices, so a slice would read the wrong bytes.
    func testDecodeHandlesNonZeroBasedSlice() throws {
        #if os(iOS) || os(macOS)
        let entry = sample(payload: #"{"v":1}"#, prov: "p")
        let bytes = try BASEventLogBinaryCodec.encode(entry)
        // Build a slice whose startIndex != 0 by prepending a byte and dropping it.
        var padded = Data([0xFF])
        padded.append(bytes)
        let slice = padded[padded.index(after: padded.startIndex)...]
        XCTAssertNotEqual(slice.startIndex, 0, "the slice must be non-zero-based to exercise the fix")
        let back = try BASEventLogBinaryCodec.decode(slice)
        XCTAssertEqual(entry, back, "a non-zero-based slice must decode identically to the 0-based Data")
        #endif
    }

    func testRoundTripWithNonePayloadAndProvenance() throws {
        #if os(iOS) || os(macOS)
        let entry = sample(payload: nil, prov: nil)
        let bytes = try BASEventLogBinaryCodec.encode(entry)
        let back = try BASEventLogBinaryCodec.decode(bytes)
        XCTAssertEqual(entry, back)
        XCTAssertNil(back.payloadJson)
        XCTAssertNil(back.provenanceSummary)
        #endif
    }

    func testRoundTripPreservesAllKindDiscriminants() throws {
        #if os(iOS) || os(macOS)
        let allKinds: [BASBinaryEventLogKind] = [
            .internalSignal, .hostInput, .sovereignVerdict,
            .permitChange, .observationBundle,
            .provenanceMark, .replayMark,
        ]
        for kind in allKinds {
            let entry = BASBinaryEventLogEntry(
                entryID: "id",
                kind: kind,
                sessionRef: "s",
                turnRef: "t",
                timestampMs: 0)
            let bytes = try BASEventLogBinaryCodec.encode(entry)
            let back = try BASEventLogBinaryCodec.decode(bytes)
            XCTAssertEqual(back.kind, kind)
        }
        #endif
    }

    func testRoundTripWithUnicodePayload() throws {
        #if os(iOS) || os(macOS)
        let entry = sample(
            payload: "中文 emoji 🎉 mixed",
            prov: "café résumé")
        let bytes = try BASEventLogBinaryCodec.encode(entry)
        let back = try BASEventLogBinaryCodec.decode(bytes)
        XCTAssertEqual(entry, back)
        #endif
    }

    func testEncodingIsDeterministic() throws {
        #if os(iOS) || os(macOS)
        let entry = sample(payload: "deterministic")
        let b1 = try BASEventLogBinaryCodec.encode(entry)
        let b2 = try BASEventLogBinaryCodec.encode(entry)
        let b3 = try BASEventLogBinaryCodec.encode(entry)
        XCTAssertEqual(b1, b2)
        XCTAssertEqual(b2, b3)
        #endif
    }

    func testDecodeRejectsTruncatedBuffer() throws {
        #if os(iOS) || os(macOS)
        let bytes = try BASEventLogBinaryCodec.encode(
            sample(payload: "some payload"))
        let truncated = bytes.subdata(
            in: 0..<(bytes.count - 4))
        do {
            _ = try BASEventLogBinaryCodec.decode(truncated)
            XCTFail("expected truncation error")
        } catch let err as BASEventLogBinaryCodecError {
            XCTAssertEqual(
                err, .decodeFailedTruncatedBuffer)
        }
        #endif
    }

    func testDecodeRejectsInvalidSchemaVersion() throws {
        #if os(iOS) || os(macOS)
        var bytes = try BASEventLogBinaryCodec.encode(sample())
        bytes[0] = 9 // not v1 or v2
        do {
            _ = try BASEventLogBinaryCodec.decode(bytes)
            XCTFail("expected schema-version rejection")
        } catch let err as BASEventLogBinaryCodecError {
            XCTAssertEqual(
                err,
                .decodeFailedInvalidSchemaVersion(9))
        }
        #endif
    }

    func testDecodeRejectsInvalidKindDiscriminant() throws {
        #if os(iOS) || os(macOS)
        var bytes = try BASEventLogBinaryCodec.encode(sample())
        bytes[1] = 99 // not a valid kind
        do {
            _ = try BASEventLogBinaryCodec.decode(bytes)
            XCTFail("expected kind rejection")
        } catch let err as BASEventLogBinaryCodecError {
            XCTAssertEqual(
                err,
                .decodeFailedInvalidKindDiscriminant(99))
        }
        #endif
    }

    func testBinaryIsSmallerThanJSONForTypicalEntry() throws {
        #if os(iOS) || os(macOS)
        // Honest measurement: binary should beat JSON for the
        // typical small-payload case (most fields short)。
        let entry = sample(
            payload: #"{"verdict":"allow"}"#,
            prov: "test-source")
        let binary = try BASEventLogBinaryCodec.encode(entry)
        // Compare against a representative JSON encoding
        let json: [String: Any] = [
            "entryID":            entry.entryID,
            "kind":               "sovereign-verdict",
            "sessionRef":         entry.sessionRef,
            "turnRef":            entry.turnRef,
            "timestampMs":        entry.timestampMs,
            "payloadJson":        entry.payloadJson!,
            "provenanceSummary":  entry.provenanceSummary!,
        ]
        let jsonData = try JSONSerialization
            .data(withJSONObject: json,
                  options: [.sortedKeys])
        XCTAssertLessThan(
            binary.count, jsonData.count,
            "binary \(binary.count) vs JSON \(jsonData.count)")
        print("  binary: \(binary.count) bytes")
        print("  JSON:   \(jsonData.count) bytes")
        print(String(format: "  ratio:  %.2f×",
            Double(jsonData.count) / Double(binary.count)))
        #endif
    }
}
