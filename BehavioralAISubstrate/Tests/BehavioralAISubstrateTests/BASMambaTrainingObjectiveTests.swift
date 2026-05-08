// MARK: - BASMambaTrainingObjectiveTests — chapter 四百 / M922

import XCTest
@testable import BASRuntimeCore

final class BASMambaTrainingObjectiveTests: XCTestCase {

    func testObjectivesPinned() {
        XCTAssertEqual(
            BASMambaTrainingObjective.allCases.count, 5)
    }

    func testRawValuesPinned() {
        XCTAssertEqual(
            BASMambaTrainingObjective.nextEventKind.rawValue,
            "nextEventKind")
        XCTAssertEqual(
            BASMambaTrainingObjective.nextRiskBand.rawValue,
            "nextRiskBand")
        XCTAssertEqual(
            BASMambaTrainingObjective
                .permitVerdictNextStep.rawValue,
            "permitVerdictNextStep")
        XCTAssertEqual(
            BASMambaTrainingObjective
                .nextEventEmbedding.rawValue,
            "nextEventEmbedding")
        XCTAssertEqual(
            BASMambaTrainingObjective
                .cycleClosingTrigger.rawValue,
            "cycleClosingTrigger")
    }

    func testNextEventKindShape() {
        let s = BASMambaTrainingObjectiveSchema.shape(
            for: .nextEventKind)
        XCTAssertEqual(s.lossClass, .crossEntropy)
        XCTAssertEqual(s.outputDim, 12)
        XCTAssertTrue(s.labelsAvailableInCurrentExport)
    }

    func testNextRiskBandShape() {
        let s = BASMambaTrainingObjectiveSchema.shape(
            for: .nextRiskBand)
        XCTAssertEqual(s.lossClass, .crossEntropy)
        XCTAssertEqual(s.outputDim, 4)
        XCTAssertTrue(s.labelsAvailableInCurrentExport)
    }

    func testPermitVerdictShapeUnavailableInM903() {
        let s = BASMambaTrainingObjectiveSchema.shape(
            for: .permitVerdictNextStep)
        XCTAssertEqual(s.lossClass, .crossEntropy)
        XCTAssertEqual(s.outputDim, 3)
        XCTAssertFalse(s.labelsAvailableInCurrentExport,
            "Permit verdicts not in current M903 export")
    }

    func testEmbeddingShapeUsesMSE() {
        let s = BASMambaTrainingObjectiveSchema.shape(
            for: .nextEventEmbedding)
        XCTAssertEqual(s.lossClass, .meanSquaredError)
        XCTAssertEqual(s.outputDim, 64)
    }

    func testCycleClosingShapeUsesBinary() {
        let s = BASMambaTrainingObjectiveSchema.shape(
            for: .cycleClosingTrigger)
        XCTAssertEqual(s.lossClass, .binaryCrossEntropy)
        XCTAssertEqual(s.outputDim, 2)
        XCTAssertFalse(s.labelsAvailableInCurrentExport,
            "Cycle-closing labels not in M903 export")
    }

    func testAvailableObjectivesTodayExcludesUnavailable() {
        let available = BASMambaTrainingObjectiveSchema
            .availableObjectivesToday()
        XCTAssertTrue(
            available.contains(.nextEventKind))
        XCTAssertTrue(
            available.contains(.nextRiskBand))
        XCTAssertTrue(
            available.contains(.nextEventEmbedding))
        XCTAssertFalse(
            available.contains(.permitVerdictNextStep),
            "permitVerdictNextStep needs future M-number to " +
            "extend M903 export with verdict labels")
        XCTAssertFalse(
            available.contains(.cycleClosingTrigger),
            "cycleClosingTrigger needs future M-number to " +
            "extend M903 export with cycle-detection labels")
    }
}
