// MARK: - BASTurnRuntimeAuditEnvelopeTests — chapter 四百四 / M963

import Foundation
import XCTest
@testable import BASHostKit

final class BASTurnRuntimeAuditEnvelopeTests: XCTestCase {

    // MARK: - Phase enum

    func testPhaseHasTwoCases() {
        XCTAssertEqual(
            BASTurnRuntimeAuditEnvelope.Phase
                .allCases.count, 2)
    }

    func testStartPhaseRawValue() {
        XCTAssertEqual(
            BASTurnRuntimeAuditEnvelope.Phase.start.rawValue,
            "start")
    }

    func testCompletePhaseRawValue() {
        XCTAssertEqual(
            BASTurnRuntimeAuditEnvelope.Phase
                .complete.rawValue,
            "complete")
    }

    // MARK: - Convenience constructors

    func testStartFactoryProducesStartEnvelope() {
        let env = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t",
            sessionID: "s",
            timestampMs: 1000)
        XCTAssertEqual(env.phase, .start)
        XCTAssertEqual(env.sequenceNumber, 0)
        XCTAssertNil(env.payloadJson)
    }

    func testCompleteFactoryProducesCompleteEnvelope() {
        let env = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t",
            sessionID: "s",
            timestampMs: 2000,
            payloadJson: "{\"verdict\":\"x\"}")
        XCTAssertEqual(env.phase, .complete)
        XCTAssertEqual(env.sequenceNumber, 1)
        XCTAssertEqual(
            env.payloadJson, "{\"verdict\":\"x\"}")
    }

    // MARK: - eventID suggestion

    func testEventIDSuggestionFormat() {
        let env = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t",
            sessionID: "session-A",
            timestampMs: 1_700_000_000_000,
            sequenceNumber: 0)
        XCTAssertEqual(
            env.eventIDSuggestion,
            "turn-start-session-A-1700000000000-0")
    }

    func testEventIDSuggestionByteStableForSameInput() {
        let env1 = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "s", timestampMs: 100)
        let env2 = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "s", timestampMs: 100)
        XCTAssertEqual(
            env1.eventIDSuggestion,
            env2.eventIDSuggestion,
            "M963:M892 byte-stable eventID for same input")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let env = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "s",
            timestampMs: 100,
            payloadJson: "{}")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(env)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeAuditEnvelope.self, from: data)
        XCTAssertEqual(decoded, env)
    }

    func testEncodedJSONByteStable() throws {
        let env1 = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "s", timestampMs: 0)
        let env2 = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "s", timestampMs: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(env1)
        let d2 = try encoder.encode(env2)
        XCTAssertEqual(d1, d2)
    }

    // MARK: - Equality + identity

    func testTwoEnvelopesWithSameFieldsAreEqual() {
        let e1 = BASTurnRuntimeAuditEnvelope(
            phase: .start, turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        let e2 = BASTurnRuntimeAuditEnvelope(
            phase: .start, turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        XCTAssertEqual(e1, e2)
    }
}
