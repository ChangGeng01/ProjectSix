// MARK: - BASPermitEscalationPipelineObservationTests
// chapter 四百九十五 / M1357 — typed pipeline observation tests

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASPermitEscalationPipelineObservationTests:
    XCTestCase
{

    // MARK: - 1) Empty pipeline preserves initial mode

    func testEmptyPipelineFinalModeMatchesInitial() {
        let pipeline =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .answer,
                steps: [])
        XCTAssertEqual(pipeline.finalPermitMode, .answer)
        XCTAssertEqual(pipeline.escalatedStepCount, 0)
        XCTAssertTrue(pipeline.aggregateReasonCodes.isEmpty)
    }

    // MARK: - 2) Single step escalation propagates

    func testSingleStepEscalationPropagatesFinalMode() {
        let step = BASPermitEscalationStepObservation(
            stepName: "abyssal",
            inputPermitMode: .answer,
            outputPermitMode: .delay,
            reasonCodes: ["abyssal-high-pressure"])
        let pipeline =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .answer,
                steps: [step])
        XCTAssertEqual(pipeline.finalPermitMode, .delay)
        XCTAssertEqual(pipeline.escalatedStepCount, 1)
        XCTAssertEqual(pipeline.aggregateReasonCodes,
                       ["abyssal-high-pressure"])
        XCTAssertTrue(step.escalated)
    }

    // MARK: - 3) Multi-step pipeline composes

    func testMultiStepPipelineComposes() {
        let steps = [
            BASPermitEscalationStepObservation(
                stepName: "abyssal",
                inputPermitMode: .answer,
                outputPermitMode: .delay,
                reasonCodes: ["abyssal-trigger"]),
            BASPermitEscalationStepObservation(
                stepName: "assertion-ceiling",
                inputPermitMode: .delay,
                outputPermitMode: .delay,
                reasonCodes: []),
            BASPermitEscalationStepObservation(
                stepName: "kunlun",
                inputPermitMode: .delay,
                outputPermitMode: .draftOnly,
                reasonCodes: ["axis-deviation"]),
        ]
        let pipeline =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .answer,
                steps: steps)
        XCTAssertEqual(pipeline.finalPermitMode,
                       .draftOnly)
        XCTAssertEqual(pipeline.escalatedStepCount, 2)
        XCTAssertEqual(pipeline.aggregateReasonCodes,
                       ["abyssal-trigger",
                        "axis-deviation"])
    }

    // MARK: - 4) Step `escalated` flag derives from
    //             mode inequality

    func testStepEscalatedDerives() {
        let unchanged = BASPermitEscalationStepObservation(
            stepName: "no-op",
            inputPermitMode: .answer,
            outputPermitMode: .answer,
            reasonCodes: [])
        XCTAssertFalse(unchanged.escalated)

        let escalated = BASPermitEscalationStepObservation(
            stepName: "escalate",
            inputPermitMode: .answer,
            outputPermitMode: .block,
            reasonCodes: ["block-due-to-block"])
        XCTAssertTrue(escalated.escalated)
    }

    // MARK: - 5) Codable round-trip

    func testCodableRoundTrip() throws {
        let original =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .mirror,
                steps: [
                    BASPermitEscalationStepObservation(
                        stepName: "abyssal",
                        inputPermitMode: .mirror,
                        outputPermitMode: .delay,
                        reasonCodes: ["c1"]),
                    BASPermitEscalationStepObservation(
                        stepName: "kunlun",
                        inputPermitMode: .delay,
                        outputPermitMode: .draftOnly,
                        reasonCodes: ["c2"]),
                ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASPermitEscalationPipelineObservation.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 6) Hashable

    func testHashable() {
        let p1 =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .answer,
                steps: [])
        let p2 =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .answer,
                steps: [])
        XCTAssertEqual(p1.hashValue, p2.hashValue)
        var seen: Set<BASPermitEscalationPipelineObservation>
            = []
        seen.insert(p1)
        seen.insert(p2)
        XCTAssertEqual(seen.count, 1)
    }

    // MARK: - 7a) Builder threads input mode through chain

    func testBuilderThreadsInputModeThroughChain() {
        let observation =
            BASPermitEscalationPipelineObservation.build(
                initialPermitMode: .answer,
                chain: [
                    (stepName: "abyssal",
                     outputPermitMode: .delay,
                     reasonCodes: ["c1"]),
                    (stepName: "assertion-ceiling",
                     outputPermitMode: .delay,
                     reasonCodes: []),
                    (stepName: "kunlun",
                     outputPermitMode: .draftOnly,
                     reasonCodes: ["c2"]),
                ])
        XCTAssertEqual(observation.steps[0].inputPermitMode,
                       .answer)
        XCTAssertEqual(observation.steps[0].outputPermitMode,
                       .delay)
        XCTAssertEqual(observation.steps[1].inputPermitMode,
                       .delay)
        XCTAssertEqual(observation.steps[2].inputPermitMode,
                       .delay)
        XCTAssertEqual(observation.steps[2].outputPermitMode,
                       .draftOnly)
        XCTAssertEqual(observation.finalPermitMode,
                       .draftOnly)
        XCTAssertEqual(observation.escalatedStepCount, 2)
    }

    // MARK: - 7b) Builder with empty chain preserves initial

    func testBuilderWithEmptyChainPreservesInitial() {
        let observation =
            BASPermitEscalationPipelineObservation.build(
                initialPermitMode: .mirror,
                chain: [])
        XCTAssertEqual(observation.initialPermitMode,
                       .mirror)
        XCTAssertEqual(observation.finalPermitMode,
                       .mirror)
        XCTAssertTrue(observation.steps.isEmpty)
    }

    // MARK: - 7c) Builder full 5-step pipeline shape
    //             (proxy for the future fold executor's
    //              actual call)

    func testBuilderFullFiveStepEscalationPipelineShape() {
        let observation =
            BASPermitEscalationPipelineObservation.build(
                initialPermitMode: .answer,
                chain: [
                    (stepName: "abyssal",
                     outputPermitMode: .delay,
                     reasonCodes:
                        ["abyssal-aggregate-magnitude"]),
                    (stepName: "assertion-ceiling",
                     outputPermitMode: .delay,
                     reasonCodes: []),
                    (stepName: "kunlun",
                     outputPermitMode: .draftOnly,
                     reasonCodes:
                        ["kunlun-axis-deviation"]),
                    (stepName: "cthulhu-assertion",
                     outputPermitMode: .draftOnly,
                     reasonCodes: []),
                    (stepName: "cthulhu-escalation",
                     outputPermitMode: .localOnly,
                     reasonCodes:
                        ["cthulhu-non-euclidean"]),
                ])
        XCTAssertEqual(observation.steps.count, 5)
        XCTAssertEqual(observation.finalPermitMode,
                       .localOnly)
        XCTAssertEqual(observation.escalatedStepCount, 3)
        XCTAssertEqual(observation.aggregateReasonCodes,
                       ["abyssal-aggregate-magnitude",
                        "kunlun-axis-deviation",
                        "cthulhu-non-euclidean"])
    }

    // MARK: - 8) Reason codes preserve step ordering

    func testReasonCodesPreserveStepOrdering() {
        let pipeline =
            BASPermitEscalationPipelineObservation(
                initialPermitMode: .answer,
                steps: [
                    BASPermitEscalationStepObservation(
                        stepName: "s1",
                        inputPermitMode: .answer,
                        outputPermitMode: .answer,
                        reasonCodes: ["z", "a"]),
                    BASPermitEscalationStepObservation(
                        stepName: "s2",
                        inputPermitMode: .answer,
                        outputPermitMode: .answer,
                        reasonCodes: ["b", "y"]),
                ])
        // Step1 codes come BEFORE step2 codes;within a
        // step codes are kept verbatim (no sort)。
        XCTAssertEqual(pipeline.aggregateReasonCodes,
                       ["z", "a", "b", "y"])
    }
}
