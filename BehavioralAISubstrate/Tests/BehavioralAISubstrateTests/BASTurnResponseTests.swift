import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

/// Context-IR step 2 — the TurnRecord / TurnResponse split.
///
/// The 53-field BASEBrainTurnResult serves four consumers with different needs (host UI reads
/// ~8 fields, SDK bridge projects 18, audit consumes nearly all, replay needs all). Step 2
/// names the two roles: `BASTurnRecord` (the accretion record — audit/replay) and
/// `BASTurnResponse` (the slim host-facing contract), with ONE projection point
/// (`record.response`). The record keeps its surface; hosts that only act/display consume the
/// response and stop coupling to the other 45 fields.
final class BASTurnResponseTests: XCTestCase {

    /// The projection is THE seam — every response field mirrors its record field.
    func testResponseProjectsTheHostFacingFields() {
        var record = BASEBrainTurnResultBoxingTests.fixtureTurnResult()
        record.layerTimingsMs = ["tail": 1.5]
        let response = record.response

        XCTAssertEqual(response.renderedOutput, record.renderedOutput)
        XCTAssertEqual(response.actionPermit, record.actionPermit)
        XCTAssertEqual(response.riskCard, record.riskCard)
        XCTAssertEqual(response.thoughtFold, record.thoughtFold)
        XCTAssertEqual(response.updateTickets, record.updateTickets)
        XCTAssertEqual(response.sovereignAuditEntry, record.sovereignAuditEntry)
        XCTAssertEqual(response.hostGateValue, record.hostGateValue)
    }

    /// The record's role is NAMED without breaking anything: BASTurnRecord is the same type.
    func testTurnRecordNamesTheAccretionRole() {
        let record: BASTurnRecord = BASEBrainTurnResultBoxingTests.fixtureTurnResult()
        XCTAssertEqual(record.response.hostGateValue, 0.84)
    }

    /// Session results expose the response so production hosts never touch the record.
    /// The seam is one optional-chain line; this pins its existence and its projection
    /// semantics (nil record ⇒ nil response) without constructing a full session result.
    func testSessionResultExposesTurnResponse() throws {
        // semantics: the seam is exactly `eBrainTurn?.response`
        let record: BASEBrainTurnResult? = BASEBrainTurnResultBoxingTests.fixtureTurnResult()
        XCTAssertEqual(record?.response.actionPermit.mode, record?.actionPermit.mode)
        XCTAssertNil((nil as BASEBrainTurnResult?)?.response)
        // wiring: BASHostSessionResult carries the accessor (compile-checked via key path)
        let seam: KeyPath<BASHostSessionResult, BASTurnResponse?> = \.turnResponse
        XCTAssertNotNil(seam)
    }

    /// Anti-hallway pin: the response must STAY slim — a growing response recreates the
    /// 53-field problem one seam over. Raising this cap requires a caller census first.
    func testResponseSurfaceStaysSlim() throws {
        #if os(macOS)
        let src = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/BASHostKit/EBrainTurnResponse.swift"),
            encoding: .utf8)
        let stored = src.split(separator: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("public let ")
        }.count
        XCTAssertLessThanOrEqual(stored, 10,
            "BASTurnResponse grew to \(stored) stored fields (cap 10) — census the host callers "
            + "before widening the host contract")
        XCTAssertGreaterThan(stored, 0, "expected the response fields in EBrainTurnResponse.swift")
        #else
        throw XCTSkip("source lint is host-only")
        #endif
    }
}
