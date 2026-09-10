// MARK: - BASInspectionFrameTests
// chapter 五百七 / M1406 — 1st Tier C primitive tests

import XCTest
@testable import BASRuntimeCore

private struct SampleInspectionBody:
    Equatable, Hashable, Codable, Sendable
{
    let observation: String
    let severityScore: Double
}

final class BASInspectionFrameTests: XCTestCase {

    // MARK: - 1) Construction holds all fields

    func testConstructionHoldsAllFields() {
        let body = SampleInspectionBody(
            observation: "test obs",
            severityScore: 0.5)
        let frame = BASInspectionFrame(
            inspectionID: "INS-1",
            schemaVersion: "1.0.0",
            inspectorRefs: ["alice", "bob"],
            inspectedRefs: ["payload-x"],
            inspectionPolicy: "policy-a",
            inspectedAtMs: 1_700_000_000_000,
            body: body,
            diagnostics: ["minor-flag"])
        XCTAssertEqual(frame.inspectionID, "INS-1")
        XCTAssertEqual(frame.schemaVersion, "1.0.0")
        XCTAssertEqual(frame.inspectorRefs,
                       ["alice", "bob"])
        XCTAssertEqual(frame.inspectedRefs,
                       ["payload-x"])
        XCTAssertEqual(frame.inspectionPolicy,
                       "policy-a")
        XCTAssertEqual(frame.inspectedAtMs,
                       1_700_000_000_000)
        XCTAssertEqual(frame.body, body)
        XCTAssertEqual(frame.diagnostics,
                       ["minor-flag"])
    }

    // MARK: - 2) Empty diagnostics → passed = true

    func testPassedWhenDiagnosticsEmpty() {
        let body = SampleInspectionBody(
            observation: "ok",
            severityScore: 0.0)
        let frame = BASInspectionFrame(
            inspectionID: "INS-2",
            schemaVersion: "1.0.0",
            inspectorRefs: ["alice"],
            inspectedRefs: ["x"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        XCTAssertTrue(frame.passed)
    }

    // MARK: - 3) Non-empty diagnostics → passed = false

    func testPassedFalseWhenDiagnosticsPresent() {
        let body = SampleInspectionBody(
            observation: "issue",
            severityScore: 0.9)
        let frame = BASInspectionFrame(
            inspectionID: "INS-3",
            schemaVersion: "1.0.0",
            inspectorRefs: ["alice"],
            inspectedRefs: ["x"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body,
            diagnostics: ["critical-fail"])
        XCTAssertFalse(frame.passed)
    }

    // MARK: - 4) distinctInspectorCount dedups

    func testDistinctInspectorCountDedups() {
        let body = SampleInspectionBody(
            observation: "o", severityScore: 0)
        let frame = BASInspectionFrame(
            inspectionID: "INS-4",
            schemaVersion: "1.0.0",
            inspectorRefs: [
                "alice", "alice", "bob", "alice"
            ],
            inspectedRefs: ["x"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        XCTAssertEqual(frame.distinctInspectorCount, 2,
            "4 raw refs but only 2 distinct (alice, bob)")
    }

    // MARK: - 5) distinctInspectedCount dedups

    func testDistinctInspectedCountDedups() {
        let body = SampleInspectionBody(
            observation: "o", severityScore: 0)
        let frame = BASInspectionFrame(
            inspectionID: "INS-5",
            schemaVersion: "1.0.0",
            inspectorRefs: ["alice"],
            inspectedRefs: ["x", "y", "x", "z", "y"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        XCTAssertEqual(frame.distinctInspectedCount, 3)
    }

    // MARK: - 6) Codable round-trip preserves all fields

    func testCodableRoundTrip() throws {
        let body = SampleInspectionBody(
            observation: "test",
            severityScore: 0.75)
        let original = BASInspectionFrame(
            inspectionID: "INS-6",
            schemaVersion: "1.0.0",
            inspectorRefs: ["alice", "bob"],
            inspectedRefs: ["x", "y"],
            inspectionPolicy: "policy-z",
            inspectedAtMs: 1_700_000_000_000,
            body: body,
            diagnostics: ["d1", "d2"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASInspectionFrame<SampleInspectionBody>.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 7) Equatable identity

    func testEquatableIdentity() {
        let body = SampleInspectionBody(
            observation: "o", severityScore: 0)
        let f1 = BASInspectionFrame(
            inspectionID: "ID",
            schemaVersion: "1.0.0",
            inspectorRefs: ["a"],
            inspectedRefs: ["b"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        let f2 = BASInspectionFrame(
            inspectionID: "ID",
            schemaVersion: "1.0.0",
            inspectorRefs: ["a"],
            inspectedRefs: ["b"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        XCTAssertEqual(f1, f2)
    }

    // MARK: - 8) Hashable

    func testHashable() {
        let body = SampleInspectionBody(
            observation: "o", severityScore: 0)
        let f1 = BASInspectionFrame(
            inspectionID: "ID",
            schemaVersion: "1.0.0",
            inspectorRefs: ["a"],
            inspectedRefs: ["b"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        let f2 = BASInspectionFrame(
            inspectionID: "ID",
            schemaVersion: "1.0.0",
            inspectorRefs: ["a"],
            inspectedRefs: ["b"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        XCTAssertEqual(f1.hashValue, f2.hashValue)
        var seen = Set<
            BASInspectionFrame<SampleInspectionBody>>()
        seen.insert(f1)
        seen.insert(f2)
        XCTAssertEqual(seen.count, 1)
    }

    // MARK: - 9) Sendable across actor boundary

    func testSendable() async {
        let body = SampleInspectionBody(
            observation: "o", severityScore: 0)
        let frame = BASInspectionFrame(
            inspectionID: "ID",
            schemaVersion: "1.0.0",
            inspectorRefs: ["a"],
            inspectedRefs: ["b"],
            inspectionPolicy: "p",
            inspectedAtMs: 0,
            body: body)
        let captured = frame
        let task = Task {
            captured.passed
        }
        let result = await task.value
        XCTAssertTrue(result)
    }
}
