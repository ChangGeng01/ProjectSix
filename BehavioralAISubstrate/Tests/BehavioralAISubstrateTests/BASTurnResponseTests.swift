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
        let storedLines = src.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            // stored bindings only — computed properties carry `{` on the declaration line
            .filter { ($0.hasPrefix("public let ") || $0.hasPrefix("public var "))
                && !$0.contains("{") }
        // audit hardening: (1) the contract is immutable — no public var stored props;
        // (2) no one-line multi-bindings or tuple types (commas forbidden in a binding);
        // (3) no aggregate smuggling of the record back through one fat field.
        XCTAssertTrue(storedLines.allSatisfy { $0.hasPrefix("public let ") },
            "BASTurnResponse must be immutable — public var stored property found")
        XCTAssertTrue(storedLines.allSatisfy { !$0.contains(",") },
            "multi-binding / tuple-typed response field found — one named field per line")
        XCTAssertFalse(src.contains(": BASEBrainTurnResult") || src.contains(": BASTurnRecord"),
            "the response must not carry the RECORD as a field — that recreates the coupling")
        XCTAssertLessThanOrEqual(storedLines.count, 10,
            "BASTurnResponse grew to \(storedLines.count) stored fields (cap 10) — census the "
            + "host callers before widening the host contract")
        XCTAssertGreaterThan(storedLines.count, 0,
            "expected the response fields in EBrainTurnResponse.swift")
        #else
        throw XCTSkip("source lint is host-only")
        #endif
    }
}

// MARK: - record-adoption boundary lint (audit-confirmed HIGH: one adopter vs 14 raw reads)

/// The consumer boundary, mechanically enforced: host-surface code that reads the raw
/// 53-field record (`eBrainTurn` beyond the `turnResponse` seam) must DECLARE itself an
/// audit-class consumer with a marker line:
///
///     // BASTurnRecord-consumer: audit-class — <why this file needs the record>
///
/// ACT/SHOW consumers (production host behavior) use `turnResponse` and need no marker.
/// QinaoSampleHost is the documented demo-exception module (same status as in
/// check_mlx_redaction) and is exempt wholesale.
extension BASTurnResponseTests {
    static let recordConsumerMarker = "BASTurnRecord-consumer: audit-class"

    func testHostRecordReadersDeclareAuditClass() throws {
        #if os(macOS)
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var scanDirs: [URL] = [repoRoot.appendingPathComponent("SampleHost")]
        let sdkSources = repoRoot.appendingPathComponent("QinaoRuntimeSDK/Sources")
        if let mods = try? FileManager.default.contentsOfDirectory(atPath: sdkSources.path) {
            for m in mods where m != "QinaoSampleHost" {
                scanDirs.append(sdkSources.appendingPathComponent(m))
            }
        }
        guard FileManager.default.fileExists(atPath: scanDirs[0].path) else {
            throw XCTSkip("host surfaces not present at \(repoRoot.path) — host-only lint")
        }
        var offenders: [String] = []
        for dir in scanDirs {
            guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
            else { continue }
            for case let url as URL in e where url.pathExtension == "swift" {
                // SampleHost's own Tests exercise both surfaces deliberately
                if url.path.contains("/Tests/") { continue }
                guard let src = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let rawReads = src.split(separator: "\n").contains { line in
                    line.contains("eBrainTurn") && !line.contains("turnResponse")
                        && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                }
                if rawReads && !src.contains(Self.recordConsumerMarker) {
                    offenders.append(url.lastPathComponent)
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "host-surface files read the raw record without declaring audit-class — ACT/SHOW "
            + "consumers must use turnResponse; INSPECT/AUDIT consumers must carry the marker "
            + "'// \(Self.recordConsumerMarker) — <why>':\n" + offenders.sorted().joined(separator: "\n"))
        #else
        throw XCTSkip("host-surface lint is host-only")
        #endif
    }
}
