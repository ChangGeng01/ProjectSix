// MARK: - BASPermitEscalationDecisionsBundleTests
// chapter 四百九十五 / M1359 — typed decisions-bundle tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy

final class BASPermitEscalationDecisionsBundleTests:
    XCTestCase
{

    // MARK: - Fixture helpers

    private func makePermit(
        mode: BASActionPermitMode
    ) -> BASActionPermit {
        return BASActionPermit(
            mode: mode, reasonCodes: [])
    }

    private func makeBundle(
        abyssalMode: BASActionPermitMode = .answer,
        abyssalReasons: [String] = [],
        ceilingMode: BASActionPermitMode = .answer,
        ceilingReasons: [String] = [],
        kunlunMode: BASActionPermitMode = .answer,
        kunlunReasons: [String] = [],
        cthulhuAssertionMode: BASActionPermitMode = .answer,
        cthulhuAssertionReasons: [String] = [],
        cthulhuEscalationMode: BASActionPermitMode = .answer,
        cthulhuEscalationReasons: [String] = []
    ) -> BASPermitEscalationDecisionsBundle {
        return BASPermitEscalationDecisionsBundle(
            abyssal: BASAbyssalPermitEscalationDecision(
                permit: makePermit(mode: abyssalMode),
                reasonCodes: abyssalReasons,
                suppressedByHumanAnchor: false,
                triggered: !abyssalReasons.isEmpty),
            assertionCeiling: BASAssertionCeilingDecision(
                permit: makePermit(mode: ceilingMode),
                reasonCodes: ceilingReasons,
                capped: !ceilingReasons.isEmpty),
            kunlun: BASKunlunPermitEscalationDecision(
                permit: makePermit(mode: kunlunMode),
                reasonCodes: kunlunReasons,
                suppressedByHumanAnchor: false,
                triggered: !kunlunReasons.isEmpty),
            cthulhuAssertion:
                BASCthulhuAssertionCeilingDecision(
                    permit: makePermit(
                        mode: cthulhuAssertionMode),
                    reasonCodes: cthulhuAssertionReasons,
                    capped: !cthulhuAssertionReasons.isEmpty,
                    firedFog: false,
                    firedRetentionLoop: false),
            cthulhuEscalation:
                BASCthulhuPermitEscalationDecision(
                    permit: makePermit(
                        mode: cthulhuEscalationMode),
                    reasonCodes: cthulhuEscalationReasons,
                    firedNonEuclidean: false,
                    firedCosmicCold: false))
    }

    // MARK: - 1) finalPermit delegates to cthulhuEscalation

    func testFinalPermitDelegatesToCthulhuEscalation() {
        let bundle = makeBundle(
            cthulhuEscalationMode: .localOnly)
        XCTAssertEqual(bundle.finalPermit.mode, .localOnly)
    }

    // MARK: - 2) pipelineObservation builds 5 steps

    func testPipelineObservationBuilds5Steps() {
        let bundle = makeBundle(
            abyssalMode: .delay,
            abyssalReasons: ["abyssal-fired"],
            ceilingMode: .delay,
            kunlunMode: .draftOnly,
            kunlunReasons: ["kunlun-axis"],
            cthulhuAssertionMode: .draftOnly,
            cthulhuEscalationMode: .localOnly,
            cthulhuEscalationReasons:
                ["cthulhu-pressure"])
        let observation = bundle.pipelineObservation(
            initialPermitMode: .answer)
        XCTAssertEqual(observation.steps.count, 5)
        XCTAssertEqual(observation.finalPermitMode,
                       .localOnly)
        XCTAssertEqual(observation.escalatedStepCount, 3)
        XCTAssertEqual(observation.aggregateReasonCodes,
                       ["abyssal-fired", "kunlun-axis",
                        "cthulhu-pressure"])
    }

    // MARK: - 3) Pipeline observation step names match contract

    func testPipelineObservationStepNamesMatchContract() {
        let observation = makeBundle()
            .pipelineObservation(initialPermitMode: .answer)
        XCTAssertEqual(observation.steps[0].stepName,
                       "abyssal")
        XCTAssertEqual(observation.steps[1].stepName,
                       "assertion-ceiling")
        XCTAssertEqual(observation.steps[2].stepName,
                       "kunlun")
        XCTAssertEqual(observation.steps[3].stepName,
                       "cthulhu-assertion")
        XCTAssertEqual(observation.steps[4].stepName,
                       "cthulhu-escalation")
    }

    // MARK: - 4) Equatable

    func testEquatableTwoBundlesWithSameDataAreEqual() {
        let b1 = makeBundle(abyssalMode: .delay)
        let b2 = makeBundle(abyssalMode: .delay)
        XCTAssertEqual(b1, b2)
    }

    func testEquatableDifferentModesAreNotEqual() {
        let b1 = makeBundle(abyssalMode: .delay)
        let b2 = makeBundle(abyssalMode: .answer)
        XCTAssertNotEqual(b1, b2)
    }

    // MARK: - 5) Sendable

    func testSendable() async {
        let bundle = makeBundle(
            cthulhuEscalationMode: .localOnly)
        let task = Task {
            bundle.finalPermit.mode
        }
        let mode = await task.value
        XCTAssertEqual(mode, .localOnly)
    }
}
