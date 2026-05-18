// MARK: - BASMLLoopServiceTests
// REAL tests for the L3 loop service candidate generation
// from L2 decompose signals。 Fourth active ML-touched
// layer in the cognitive cascade。
//
// Before this commit: BASPlaceholderLoopService produced
// ONE trivial candidate with neutral 0.5 values
// regardless of input。
//
// After this commit: BASMLLoopService produces 1-3
// candidates derived from L2 decompose signals。 Each
// candidate's expectedBenefit / cost / reversibility /
// confidence reflects the input's signal profile。
//
// These tests pin the candidate-generation rules + the
// score-derivation function。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASOrchestration

final class BASMLLoopServiceTests: XCTestCase {

    private func emptyDecompose() -> BASDecomposeFrame {
        return BASDecomposeFrame()
    }

    private func decomposeWith(
        emotions: [String] = [],
        pressureSignals: [String] = [],
        manipulationSignals: [String] = [],
        unknowns: [String] = []
    ) -> BASDecomposeFrame {
        return BASDecomposeFrame(
            emotions: emotions,
            unknowns: unknowns,
            pressureSignals: pressureSignals,
            manipulationSignals: manipulationSignals)
    }

    private func emptyMemoryBundle() -> BASMemoryBundle {
        return BASMemoryBundle(
            atoms: [],
            retrievalTags: [],
            activeHostVersion: nil)
    }

    private func neutralBudget() -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: .guard,
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 180,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false)
    }

    // MARK: - Always produces primary candidate

    func testAlwaysProducesPrimaryCandidate() {
        let service = BASMLLoopService()
        let candidates = service.proposePaths(
            decomposeFrame: emptyDecompose(),
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        XCTAssertGreaterThanOrEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].candidateID,
            BASMLLoopService.Candidates.primaryID)
    }

    // MARK: - Calm input produces only primary

    func testCalmInputProducesOneCandidate() {
        let service = BASMLLoopService()
        let candidates = service.proposePaths(
            decomposeFrame: emptyDecompose(),
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        XCTAssertEqual(candidates.count, 1,
            "Calm decompose (empty arrays) must produce" +
            " exactly 1 candidate (primary)")
    }

    // MARK: - Pressure adds cautious

    func testPressureSignalAddsCautiousCandidate() {
        let service = BASMLLoopService()
        let frame = decomposeWith(
            pressureSignals: [
                BASMLDecomposeService.Signals
                    .urgencyDetected
            ])
        let candidates = service.proposePaths(
            decomposeFrame: frame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.contains { $0
            .candidateID == BASMLLoopService.Candidates
            .cautiousID })
    }

    // MARK: - Manipulation adds both cautious AND decline

    func testManipulationSignalAddsDeclineCandidate() {
        let service = BASMLLoopService()
        let frame = decomposeWith(
            manipulationSignals: [
                BASMLDecomposeService.Signals
                    .manipulationDetected
            ])
        let candidates = service.proposePaths(
            decomposeFrame: frame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        // primary + cautious (because manipulation is in
        // shouldOfferCautious gate) + decline = 3
        XCTAssertEqual(candidates.count, 3)
        XCTAssertTrue(candidates.contains { $0
            .candidateID == BASMLLoopService.Candidates
            .declineID })
    }

    // MARK: - Score derivation

    func testManipulationLowersConfidenceAndRaisesCost() {
        let service = BASMLLoopService()
        let calmFrame = emptyDecompose()
        let manipulationFrame = decomposeWith(
            manipulationSignals: [
                BASMLDecomposeService.Signals
                    .manipulationDetected
            ])
        let calmPrimary = service.proposePaths(
            decomposeFrame: calmFrame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())[0]
        let manipPrimary = service.proposePaths(
            decomposeFrame: manipulationFrame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())[0]
        XCTAssertLessThan(manipPrimary.confidence,
            calmPrimary.confidence,
            "Manipulation signal must lower primary" +
            " candidate's confidence")
        XCTAssertGreaterThan(manipPrimary.expectedCost,
            calmPrimary.expectedCost,
            "Manipulation signal must raise primary" +
            " candidate's expectedCost")
    }

    func testHighStakesLowersReversibility() {
        let service = BASMLLoopService()
        let calmFrame = emptyDecompose()
        let stakesFrame = decomposeWith(
            pressureSignals: [
                BASMLDecomposeService.Signals.highStakes
            ])
        let calmPrimary = service.proposePaths(
            decomposeFrame: calmFrame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())[0]
        let stakesPrimary = service.proposePaths(
            decomposeFrame: stakesFrame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())[0]
        XCTAssertLessThan(stakesPrimary.reversibility,
            calmPrimary.reversibility,
            "High-stakes signal must lower reversibility")
    }

    func testUnknownsLowerConfidence() {
        let service = BASMLLoopService()
        let calmFrame = emptyDecompose()
        let unknownsFrame = decomposeWith(
            unknowns: [
                BASMLDecomposeService.Signals
                    .lowConfidenceClassification,
                "additional_unknown_signal",
            ])
        let calmPrimary = service.proposePaths(
            decomposeFrame: calmFrame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())[0]
        let unknownsPrimary = service.proposePaths(
            decomposeFrame: unknownsFrame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())[0]
        XCTAssertLessThan(unknownsPrimary.confidence,
            calmPrimary.confidence)
    }

    // MARK: - Forecasts

    func testForecastUncertaintyScalesWithSignalCount() {
        let service = BASMLLoopService()
        let calm = emptyDecompose()
        let many = decomposeWith(
            emotions: [BASMLDecomposeService.Signals
                .elevatedArousal],
            pressureSignals: [
                BASMLDecomposeService.Signals
                    .urgencyDetected,
                BASMLDecomposeService.Signals.highStakes,
            ],
            unknowns: [BASMLDecomposeService.Signals
                .lowConfidenceClassification])
        let calmCands = service.proposePaths(
            decomposeFrame: calm,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        let manyCands = service.proposePaths(
            decomposeFrame: many,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        let calmForecasts = service.forecast(
            candidates: calmCands,
            decomposeFrame: calm,
            memoryBundle: emptyMemoryBundle())
        let manyForecasts = service.forecast(
            candidates: manyCands,
            decomposeFrame: many,
            memoryBundle: emptyMemoryBundle())
        XCTAssertGreaterThan(
            manyForecasts[0].uncertainty,
            calmForecasts[0].uncertainty,
            "More signals → higher forecast uncertainty")
    }

    // MARK: - Critique always produces at least one item

    func testCritiqueProducesEvidenceGap() {
        let service = BASMLLoopService()
        let candidates = service.proposePaths(
            decomposeFrame: emptyDecompose(),
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        let critiques = service.critique(
            candidates: candidates,
            forecasts: [],
            hostContext: BASHostProfile(
                hostID: "test"))
        XCTAssertFalse(critiques.isEmpty,
            "Critique must produce at least one item" +
            " per candidate")
        XCTAssertTrue(critiques.contains { $0
            .critiqueType == .evidenceGap })
    }

    // MARK: - iterate end-to-end

    func testIterateAssemblesThoughtFrame() {
        let service = BASMLLoopService()
        let frame = decomposeWith(
            manipulationSignals: [
                BASMLDecomposeService.Signals
                    .manipulationDetected
            ])
        let thought = service.iterate(
            decomposeFrame: frame,
            memoryBundle: emptyMemoryBundle(),
            budget: neutralBudget())
        XCTAssertEqual(thought.candidates.count, 3,
            "Manipulation frame should produce 3" +
            " candidates")
        XCTAssertEqual(thought.forecasts.count, 3,
            "One forecast per candidate")
        XCTAssertFalse(thought.critiques.isEmpty)
        XCTAssertGreaterThan(thought.stabilityScore, 0)
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeProducesAtLeastOneCandidateForManipulation()
        async throws
    {
        // The loop service generates 3 candidates for
        // manipulation;the coordinator's
        // materializePublicProjection may collapse to a
        // smaller set。 The invariant is "at least one
        // candidate appears in the cascade output"。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        XCTAssertGreaterThanOrEqual(
            result.thoughtFrame.candidates.count, 1,
            "Manipulation input must produce >=1" +
            " candidate in the cascade。 Got" +
            " \(result.thoughtFrame.candidates.count)")
        // Identifier should match one of the BASMLLoop
        // Service candidates (primary / cautious /
        // decline)。
        let ids = result.thoughtFrame.candidates.map {
            $0.candidateID }
        let validIDs = [
            BASMLLoopService.Candidates.primaryID,
            BASMLLoopService.Candidates.cautiousID,
            BASMLLoopService.Candidates.declineID,
        ]
        for id in ids {
            XCTAssertTrue(validIDs.contains(id),
                "Candidate ID '\(id)' is not one of the" +
                " BASMLLoopService typed candidates")
        }
    }

    func testBrainCascadeProducesCandidateForCalmInput()
        async throws
    {
        // Calm chat must produce at least one candidate
        // (primary)。 Coordinator may add/replace it
        // with projected candidates。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello how are you today")
        XCTAssertGreaterThanOrEqual(
            result.thoughtFrame.candidates.count, 1,
            "Calm chat must produce >=1 candidate。" +
            " Got \(result.thoughtFrame.candidates.count)")
    }
}
