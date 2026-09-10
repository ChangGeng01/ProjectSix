// MARK: - BASTurnRuntimeAuditEnvelopeActionTagTests
// chapter 四百六 v2 / M994

import Foundation
import XCTest
@testable import BASHostKit

final class BASTurnRuntimeAuditEnvelopeActionTagTests:
    XCTestCase
{

    // MARK: - Anti-magic-number constant pinned

    func testActionTagPrefixPinned() {
        XCTAssertEqual(
            BASTurnRuntimeAuditEnvelope
                .eventLogActionTagPrefix,
            "turn-",
            "M994:action tag prefix pinned to grep-stable string")
    }

    // MARK: - Action tag derivation per phase

    func testStartEnvelopeActionTag() {
        let env = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        XCTAssertEqual(env.eventLogActionTag, "turn-start")
    }

    func testCompleteEnvelopeActionTag() {
        let env = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 1)
        XCTAssertEqual(env.eventLogActionTag, "turn-complete")
    }

    // MARK: - Tag composition

    func testTagComposesPrefixWithPhaseRawValue() {
        for phase in BASTurnRuntimeAuditEnvelope.Phase
            .allCases
        {
            let env = BASTurnRuntimeAuditEnvelope(
                phase: phase,
                turnID: "t",
                sessionID: "s",
                timestampMs: 0,
                sequenceNumber: 0)
            XCTAssertEqual(
                env.eventLogActionTag,
                BASTurnRuntimeAuditEnvelope
                    .eventLogActionTagPrefix + phase.rawValue,
                "M994:action tag = prefix + phase.rawValue")
        }
    }

    // MARK: - Replay determinism

    func testActionTagByteStableForSameInput() {
        let e1 = BASTurnRuntimeAuditEnvelope.start(
            turnID: "x", sessionID: "y",
            timestampMs: 0, sequenceNumber: 0)
        let e2 = BASTurnRuntimeAuditEnvelope.start(
            turnID: "x", sessionID: "y",
            timestampMs: 0, sequenceNumber: 0)
        XCTAssertEqual(
            e1.eventLogActionTag,
            e2.eventLogActionTag,
            "M994:action tag byte-stable")
    }
}
