// MARK: - BASNeuralHeadShadowRecorderTests — 全面进化 T3.3 Stage-1
//
// Contract gate for the (rules-input → rules-output) shadow recorder:
//   1. The row's boolean features MIRROR `BASMLLoopService
//      .deriveScoreDeltas`'s exact predicates on a REAL driven turn。
//   2. The row's outputs equal the turn's rules outputs verbatim。
//   3. Determinism — same turn result ⇒ byte-identical JSONL line。
//   4. JSONL append + round-trip decode。
// The recorder is a PURE READER of completed turn results (zero
// runtime wiring) — these tests are the entire behavioral surface。

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration

final class BASNeuralHeadShadowRecorderTests: XCTestCase {

    private func driveOneTurn() throws -> BASEBrainTurnResult {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "I feel pressured to send this risky reply " +
                    "right now — should I?",
                title: "t33-stage1-capture",
                riskLevel: .high))
        return try XCTUnwrap(result.eBrainTurn)
    }

    func testRowMirrorsRulesInputsAndOutputsFromALiveTurn() throws {
        let turn = try driveOneTurn()
        let row = BASNeuralHeadShadowRow(
            from: turn, sessionID: "s1", turnID: "t1")

        // 1) Boolean features == the exact deriveScoreDeltas predicates。
        let frame = turn.decomposeFrame
        XCTAssertEqual(row.hasPressure, !frame.pressureSignals.isEmpty)
        XCTAssertEqual(row.hasEmotion, !frame.emotions.isEmpty)
        XCTAssertEqual(
            row.hasManipulation,
            frame.manipulationSignals.contains(
                BASMLDecomposeService.Signals.manipulationDetected))
        XCTAssertEqual(
            row.hasHighStakes,
            frame.pressureSignals.contains(
                BASMLDecomposeService.Signals.highStakes))
        XCTAssertEqual(row.unknownCount, frame.unknowns.count)
        XCTAssertEqual(
            row.pressureSignalCount, frame.pressureSignals.count)

        // 2) Outputs verbatim。
        XCTAssertEqual(row.candidates.count,
                       turn.thoughtFrame.candidates.count)
        XCTAssertFalse(row.candidates.isEmpty,
            "a driven turn always carries candidates")
        XCTAssertEqual(row.triScores.count, turn.triScores.count)
        for (rowScore, live) in zip(row.triScores, turn.triScores) {
            XCTAssertEqual(rowScore.candidateID, live.candidateID)
            XCTAssertEqual(rowScore.mergedScore, live.mergedScore)
            XCTAssertEqual(rowScore.veto, live.veto)
        }
        XCTAssertEqual(row.chosenCandidateID,
                       turn.mergedChoice.candidateID)
        XCTAssertEqual(row.vetoApplied, turn.mergedChoice.vetoApplied)
        XCTAssertEqual(row.stopReason,
                       turn.thoughtFrame.stopReason?.rawValue)
    }

    func testJSONLLineIsDeterministic() throws {
        let turn = try driveOneTurn()
        let a = try BASNeuralHeadShadowRecorder.jsonlLine(
            for: turn, sessionID: "s", turnID: "t")
        let b = try BASNeuralHeadShadowRecorder.jsonlLine(
            for: turn, sessionID: "s", turnID: "t")
        XCTAssertEqual(a, b, "sortedKeys + pure projection ⇒ stable line")
        XCTAssertFalse(a.contains("\n"), "single line per row")
    }

    func testAppendWritesDecodableJSONL() throws {
        let turn = try driveOneTurn()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("t33-stage1-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("capture.jsonl")

        try BASNeuralHeadShadowRecorder.append(
            results: [(turn, "s1", "t1")], to: file)
        try BASNeuralHeadShadowRecorder.append(
            results: [(turn, "s1", "t2")], to: file)  // append path

        let lines = try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        let decoded = try lines.map {
            try JSONDecoder().decode(
                BASNeuralHeadShadowRow.self, from: Data($0.utf8))
        }
        XCTAssertEqual(decoded[0].turnID, "t1")
        XCTAssertEqual(decoded[1].turnID, "t2")
        XCTAssertEqual(decoded[0].chosenCandidateID,
                       decoded[1].chosenCandidateID,
            "same turn projected twice ⇒ identical content fields")
    }

    func testNilIdentifiersAreOmittedFromTheWire() throws {
        let turn = try driveOneTurn()
        let line = try BASNeuralHeadShadowRecorder.jsonlLine(for: turn)
        XCTAssertFalse(line.contains("\"sessionID\""))
        XCTAssertFalse(line.contains("\"turnID\""))
    }
}
