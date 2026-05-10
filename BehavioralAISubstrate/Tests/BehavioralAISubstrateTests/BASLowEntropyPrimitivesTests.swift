// MARK: - BASLowEntropyPrimitivesTests — chapter 四百二十九 / M1088 + M1089

import XCTest
@testable import BASRuntimeCore

final class BASLowEntropyPrimitivesTests: XCTestCase {

    // MARK: - BASResult<Body>

    func testResultDirectInit() {
        let r = BASResult<String>(
            success: true,
            body: "ok",
            diagnostics: [])
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.body, "ok")
        XCTAssertTrue(r.diagnostics.isEmpty)
    }

    func testResultDefaultDiagnosticsEmpty() {
        let r = BASResult<Int>(
            success: false,
            body: 0)
        XCTAssertFalse(r.success)
        XCTAssertTrue(r.diagnostics.isEmpty)
    }

    func testResultCarriesDiagnosticsOnFailure() {
        let r = BASResult<String>(
            success: false,
            body: "",
            diagnostics: [
                "input.empty",
                "schema.missing-field"
            ])
        XCTAssertEqual(r.diagnostics.count, 2)
    }

    func testResultCodableRoundTrip() throws {
        let r = BASResult<Int>(
            success: true,
            body: 42,
            diagnostics: ["warn-x"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(r)
        let decoded = try JSONDecoder()
            .decode(
                BASResult<Int>.self, from: data)
        XCTAssertEqual(decoded, r)
    }

    func testResultEqualityAndHashing() {
        let r1 = BASResult<String>(
            success: true, body: "x")
        let r2 = BASResult<String>(
            success: true, body: "x")
        XCTAssertEqual(r1, r2)
        XCTAssertEqual(r1.hashValue, r2.hashValue)
    }

    // MARK: - BASFrameEnvelope<Body>

    func testFrameEnvelopeDirectInit() {
        let header = BASFrameEnvelopeHeader(
            schemaVersion: "1.0.0",
            correlationID: "turn-1",
            producer: "host.test",
            emittedAtMs: 100)
        let env = BASFrameEnvelope<String>(
            header: header,
            body: "payload")
        XCTAssertEqual(
            env.header.schemaVersion, "1.0.0")
        XCTAssertEqual(env.body, "payload")
    }

    func testFrameEnvelopeCodableRoundTrip() throws {
        let header = BASFrameEnvelopeHeader(
            schemaVersion: "2.0.0",
            correlationID: "c1",
            producer: "p",
            emittedAtMs: 100)
        let env = BASFrameEnvelope<Int>(
            header: header, body: 7)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(env)
        let decoded = try JSONDecoder()
            .decode(
                BASFrameEnvelope<Int>.self, from: data)
        XCTAssertEqual(decoded, env)
    }

    // MARK: - BASPermit<Decision>

    func testPermitDirectInit() {
        let p = BASPermit<String>(
            decision: "allow",
            reasonCodes: ["risk.low"],
            reviewerID: "policy.gate")
        XCTAssertEqual(p.decision, "allow")
        XCTAssertEqual(
            p.reasonCodes, ["risk.low"])
        XCTAssertEqual(
            p.reviewerID, "policy.gate")
    }

    func testPermitCodableRoundTrip() throws {
        let p = BASPermit<Bool>(
            decision: true,
            reasonCodes: ["a", "b"],
            reviewerID: "rev-1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(p)
        let decoded = try JSONDecoder()
            .decode(
                BASPermit<Bool>.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    // MARK: - BASCard<Kind, Body>

    func testCardDirectInit() {
        let c = BASCard<String, Int>(
            kind: "risk",
            body: 5,
            headline: "Headline",
            presentation: "rich-text")
        XCTAssertEqual(c.kind, "risk")
        XCTAssertEqual(c.body, 5)
        XCTAssertEqual(c.headline, "Headline")
        XCTAssertEqual(
            c.presentation, "rich-text")
    }

    func testCardCodableRoundTrip() throws {
        let c = BASCard<String, String>(
            kind: "merged-choice",
            body: "answer",
            headline: "Answer",
            presentation: "compact")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(c)
        let decoded = try JSONDecoder()
            .decode(
                BASCard<String, String>.self,
                from: data)
        XCTAssertEqual(decoded, c)
    }

    // MARK: - Byte-stable JSON across encodes (chapter 三百九二)

    func testFrameEnvelopeByteStable() throws {
        let header = BASFrameEnvelopeHeader(
            schemaVersion: "1.0.0",
            correlationID: "c",
            producer: "p",
            emittedAtMs: 100)
        let env = BASFrameEnvelope<Int>(
            header: header, body: 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(env)
        let d2 = try encoder.encode(env)
        XCTAssertEqual(d1, d2,
            "sortedKeys must produce byte-stable JSON " +
            "for the generic envelope (chapter 三百九二)")
    }
}

// MARK: - Test conformer for BASObservationItem +
// BASObservationDerivable

private struct StubObservationItem:
    BASObservationItem
{
    let observationID: String
    let derivedAtMs: Int64
    let sourceID: String
    let payloadValue: Int
}

private struct StubObservationDerivable:
    BASObservationDerivable
{
    func derive(
        from input: Int,
        atMs: Int64
    ) -> StubObservationItem {
        return StubObservationItem(
            observationID: "obs-\(input)",
            derivedAtMs: atMs,
            sourceID: "stub-src",
            payloadValue: input)
    }
}

final class BASObservationItemProtocolTests: XCTestCase {

    // MARK: - Conformance compiles

    func testStubObservationItemConforms() {
        let item = StubObservationItem(
            observationID: "obs-1",
            derivedAtMs: 100,
            sourceID: "src-1",
            payloadValue: 7)
        let asProto: any BASObservationItem = item
        XCTAssertEqual(
            asProto.observationID, "obs-1")
        XCTAssertEqual(asProto.derivedAtMs, 100)
        XCTAssertEqual(asProto.sourceID, "src-1")
    }

    // MARK: - Derive contract

    func testDerivePropagatesAtMs() {
        let derivable = StubObservationDerivable()
        let observation = derivable.derive(
            from: 42, atMs: 12345)
        XCTAssertEqual(
            observation.derivedAtMs, 12345,
            "derive(from:atMs:) must stamp returned " +
            "observation with the provided timestamp")
        XCTAssertEqual(observation.payloadValue, 42)
    }

    func testDeriveIsDeterministic() {
        let d1 = StubObservationDerivable()
        let d2 = StubObservationDerivable()
        let o1 = d1.derive(from: 5, atMs: 100)
        let o2 = d2.derive(from: 5, atMs: 100)
        XCTAssertEqual(o1, o2,
            "BASObservationDerivable.derive must be a" +
            " pure function (chapter 三百九二)")
    }

    func testDeriveAtCurrentTimeStampsTimestamp() {
        let derivable = StubObservationDerivable()
        let before = Int64(
            Date().timeIntervalSince1970 * 1000)
        let observation = derivable
            .deriveAtCurrentTime(from: 99)
        let after = Int64(
            Date().timeIntervalSince1970 * 1000)
        XCTAssertGreaterThanOrEqual(
            observation.derivedAtMs, before)
        XCTAssertLessThanOrEqual(
            observation.derivedAtMs, after + 1)
    }

    // MARK: - Codable round-trip via protocol

    func testObservationCodableRoundTrip() throws {
        let item = StubObservationItem(
            observationID: "obs-7",
            derivedAtMs: 200,
            sourceID: "src",
            payloadValue: 7)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(item)
        let decoded = try JSONDecoder()
            .decode(
                StubObservationItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }
}
