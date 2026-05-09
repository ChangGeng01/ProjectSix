// MARK: - BASEventLogEntryTurnEnvelopeTests
// chapter 四百六 v2 / M995

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASEventLogEntryTurnEnvelopeTests: XCTestCase {

    // MARK: - Init factory

    func testInitFromTurnEnvelopePopulatesFields() {
        let env = BASTurnRuntimeAuditEnvelope.start(
            turnID: "turn-1",
            sessionID: "sess-A",
            timestampMs: 1_700_000_000_000,
            sequenceNumber: 0)
        let entry = BASEventLogEntry(
            turnEnvelope: env,
            eventID: "evt-1",
            source: "test")
        XCTAssertEqual(entry.eventID, "evt-1")
        XCTAssertEqual(entry.timestampMs, env.timestampMs)
        XCTAssertEqual(entry.kind, .substrateAudit)
        XCTAssertEqual(entry.sessionID, env.sessionID)
        XCTAssertEqual(entry.source, "test")
        XCTAssertEqual(entry.turnRef, env.turnID)
        XCTAssertEqual(entry.actions, ["turn-start"])
        XCTAssertNil(entry.payloadJson,
            "start envelope has nil payloadJson by default")
    }

    func testInitFromCompleteEnvelopePopulatesPayload() {
        let env = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t",
            sessionID: "s",
            timestampMs: 0,
            sequenceNumber: 1,
            payloadJson: "{\"k\":\"v\"}")
        let entry = BASEventLogEntry(
            turnEnvelope: env,
            eventID: "e")
        XCTAssertEqual(entry.actions, ["turn-complete"])
        XCTAssertEqual(entry.payloadJson, "{\"k\":\"v\"}")
    }

    func testInitDefaultSourceIsTurnRuntimeEngine() {
        let env = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        let entry = BASEventLogEntry(
            turnEnvelope: env, eventID: "e")
        XCTAssertEqual(entry.source, "turn-runtime-engine",
            "M995:default source pinned for V2 actor emission")
    }

    // MARK: - Storage append helper

    func testAppendTurnEnvelopeWritesToLog() async {
        let log = BASInMemoryEventLogStorage()
        let env = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "sess-1",
            timestampMs: 100, sequenceNumber: 0,
            payloadJson: "{}")
        await log.appendTurnEnvelope(
            env, eventID: "evt-x")
        let entries = await log.events(forSession: "sess-1")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.eventID, "evt-x")
        XCTAssertEqual(entries.first?.actions,
            ["turn-complete"])
    }

    func testAppendTurnEnvelopePairWritesTwoEntries() async {
        let log = BASInMemoryEventLogStorage()
        let start = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "p",
            timestampMs: 0, sequenceNumber: 0)
        let complete = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "p",
            timestampMs: 1, sequenceNumber: 1)
        await log.appendTurnEnvelope(
            start, eventID: "e0")
        await log.appendTurnEnvelope(
            complete, eventID: "e1")
        let entries = await log.events(forSession: "p")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].actions, ["turn-start"])
        XCTAssertEqual(entries[1].actions, ["turn-complete"])
    }
}
