import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASWorldPrior

/// M287 — Cthulhu-inspiration white paper schema parity tests.
///
/// Pins, per object:
///
///  1. Every white-paper field exists on the Swift type with the
///     matching name (camelCase mirror of snake_case).
///  2. Codable round-trip preserves every field byte-stable under
///     `.sortedKeys` JSON.
///  3. `currentSchemaVersion` matches the per-instance
///     `schemaVersion` field.
///  4. Every enum's raw values match the white paper's stable
///     identifiers.
///  5. Helper functions (Abyssal Pressure Budget / Human Anchor
///     Protocol / Anomaly Watch Protocol / Old Seal Sealing
///     Protocol) produce expected outputs.
final class BASAbyssalProtocolTests: XCTestCase {

    // MARK: - Round-trip helpers

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - 1. BASAbyssalPressure

    func testAbyssalPressureRoundTripsAllFields() throws {
        let pressure = BASAbyssalPressure(
            pressureID: "p-1",
            unknownLoad: 0.7,
            consequenceRadius: 0.5,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.8,
            manipulationIndex: 0.9,
            narrativePollution: 0.3,
            recommendedModes: [.compare, .delay, .sovereignEscalate],
            sovereignEscalationHint: "elevated:manipulation-index"
        )
        let restored = try roundTrip(pressure)
        XCTAssertEqual(restored, pressure)
        XCTAssertEqual(restored.pressureID, "p-1")
        XCTAssertEqual(restored.unknownLoad, 0.7, accuracy: 1e-9)
        XCTAssertEqual(restored.consequenceRadius, 0.5, accuracy: 1e-9)
        XCTAssertEqual(restored.evidenceDebt, 0.6, accuracy: 1e-9)
        XCTAssertEqual(restored.ontologyDistortion, 0.8, accuracy: 1e-9)
        XCTAssertEqual(restored.manipulationIndex, 0.9, accuracy: 1e-9)
        XCTAssertEqual(restored.narrativePollution, 0.3, accuracy: 1e-9)
        XCTAssertEqual(restored.recommendedModes,
                       [.compare, .delay, .sovereignEscalate])
        XCTAssertEqual(restored.sovereignEscalationHint,
                       "elevated:manipulation-index")
    }

    func testAbyssalPressureSchemaVersionPinned() {
        XCTAssertEqual(BASAbyssalPressure.currentSchemaVersion, "1.0.0")
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 0,
            consequenceRadius: 0,
            evidenceDebt: 0,
            ontologyDistortion: 0,
            manipulationIndex: 0,
            narrativePollution: 0,
            recommendedModes: []
        )
        XCTAssertEqual(p.schemaVersion,
                       BASAbyssalPressure.currentSchemaVersion)
    }

    func testAbyssalPressureClampsRangesToZeroOne() {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: -0.5,
            consequenceRadius: 1.5,
            evidenceDebt: 2,
            ontologyDistortion: -1,
            manipulationIndex: 5,
            narrativePollution: -10,
            recommendedModes: []
        )
        XCTAssertEqual(p.unknownLoad, 0)
        XCTAssertEqual(p.consequenceRadius, 1)
        XCTAssertEqual(p.evidenceDebt, 1)
        XCTAssertEqual(p.ontologyDistortion, 0)
        XCTAssertEqual(p.manipulationIndex, 1)
        XCTAssertEqual(p.narrativePollution, 0)
    }

    func testAbyssalPressureModeRawValuesMatchWhitePaper() {
        XCTAssertEqual(BASAbyssalPressureMode.compare.rawValue,
                       "compare")
        XCTAssertEqual(BASAbyssalPressureMode.delay.rawValue,
                       "delay")
        XCTAssertEqual(BASAbyssalPressureMode.guardianBranch.rawValue,
                       "guardian-branch")
        XCTAssertEqual(BASAbyssalPressureMode.sovereignEscalate.rawValue,
                       "sovereign-escalate")
        XCTAssertEqual(BASAbyssalPressureMode.localDraft.rawValue,
                       "local-draft")
        XCTAssertEqual(BASAbyssalPressureMode.humanAnchorCheck.rawValue,
                       "human-anchor-check")
    }

    func testAbyssalPressureAggregateMagnitudeIsMean() {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 0.6,
            consequenceRadius: 0.6,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.6,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: []
        )
        XCTAssertEqual(p.aggregateMagnitude, 0.6, accuracy: 1e-9)
    }

    // MARK: - 2. BASAbyssalPressureBudget helper

    func testAbyssalPressureBudgetRecommendsAllModesForMaxPressure() {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 1,
            consequenceRadius: 1,
            evidenceDebt: 1,
            ontologyDistortion: 1,
            manipulationIndex: 1,
            narrativePollution: 1,
            recommendedModes: []
        )
        let modes = BASAbyssalPressureBudget.recommendedModes(
            for: p)
        XCTAssertEqual(modes,
                       [.compare,
                        .delay,
                        .guardianBranch,
                        .sovereignEscalate,
                        .localDraft,
                        .humanAnchorCheck])
    }

    func testAbyssalPressureBudgetRecommendsNoModesForLowPressure() {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 0.1,
            consequenceRadius: 0.1,
            evidenceDebt: 0.1,
            ontologyDistortion: 0.1,
            manipulationIndex: 0.1,
            narrativePollution: 0.1,
            recommendedModes: []
        )
        XCTAssertEqual(
            BASAbyssalPressureBudget.recommendedModes(for: p),
            [])
    }

    func testAbyssalPressureBudgetEscalationHintBuilds() {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 0.9,
            consequenceRadius: 0.4,
            evidenceDebt: 0.85,
            ontologyDistortion: 0.4,
            manipulationIndex: 0.9,
            narrativePollution: 0.4,
            recommendedModes: []
        )
        let hint = BASAbyssalPressureBudget.sovereignEscalationHint(
            for: p)
        XCTAssertNotNil(hint)
        XCTAssertTrue(hint?.hasPrefix("elevated:") == true)
        XCTAssertTrue(hint?.contains("unknown-load") == true)
        XCTAssertTrue(hint?.contains("evidence-debt") == true)
        XCTAssertTrue(hint?.contains("manipulation-index") == true)
    }

    func testAbyssalPressureBudgetEscalationHintNilWhenLow() {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 0,
            consequenceRadius: 0,
            evidenceDebt: 0,
            ontologyDistortion: 0,
            manipulationIndex: 0,
            narrativePollution: 0,
            recommendedModes: []
        )
        XCTAssertNil(
            BASAbyssalPressureBudget.sovereignEscalationHint(for: p))
    }

    // MARK: - 3. BASHumanAnchorSignal

    func testHumanAnchorSignalRoundTripsAllFields() throws {
        let signal = BASHumanAnchorSignal(
            anchorID: "anchor-1",
            hostSummaryRef: "host-v3",
            agencyRisk: 0.4,
            alienationRisk: 0.5,
            dignityRisk: 0.6,
            overwhelmRisk: 0.3,
            recommendedSurfaceTone: .warm,
            requiredAgencyReservation: "present-options"
        )
        let restored = try roundTrip(signal)
        XCTAssertEqual(restored, signal)
        XCTAssertEqual(restored.recommendedSurfaceTone, .warm)
        XCTAssertEqual(restored.requiredAgencyReservation,
                       "present-options")
    }

    func testHumanAnchorToneRawValuesMatchWhitePaper() {
        XCTAssertEqual(BASHumanAnchorTone.plain.rawValue, "plain")
        XCTAssertEqual(BASHumanAnchorTone.steady.rawValue, "steady")
        XCTAssertEqual(BASHumanAnchorTone.warm.rawValue, "warm")
        XCTAssertEqual(BASHumanAnchorTone.reserved.rawValue,
                       "reserved")
    }

    // MARK: - 4. BASHumanAnchorProtocol helper

    func testHumanAnchorProtocolRecommendsReservedAtHighRisk() {
        let tone = BASHumanAnchorProtocol.recommendedTone(
            agencyRisk: 0.9,
            alienationRisk: 0.1,
            dignityRisk: 0.1,
            overwhelmRisk: 0.1)
        XCTAssertEqual(tone, .reserved)
    }

    func testHumanAnchorProtocolRecommendsWarmAtDignityRisk() {
        let tone = BASHumanAnchorProtocol.recommendedTone(
            agencyRisk: 0.1,
            alienationRisk: 0.1,
            dignityRisk: 0.6,
            overwhelmRisk: 0.1)
        XCTAssertEqual(tone, .warm)
    }

    func testHumanAnchorProtocolRecommendsSteadyAtOverwhelmRisk() {
        let tone = BASHumanAnchorProtocol.recommendedTone(
            agencyRisk: 0.1,
            alienationRisk: 0.1,
            dignityRisk: 0.1,
            overwhelmRisk: 0.6)
        XCTAssertEqual(tone, .steady)
    }

    func testHumanAnchorProtocolRecommendsPlainWhenLowRisks() {
        let tone = BASHumanAnchorProtocol.recommendedTone(
            agencyRisk: 0,
            alienationRisk: 0,
            dignityRisk: 0,
            overwhelmRisk: 0)
        XCTAssertEqual(tone, .plain)
    }

    func testHumanAnchorProtocolBuildsFullySpecifiedSignal() {
        let signal = BASHumanAnchorProtocol.signal(
            anchorID: "a",
            hostSummaryRef: "host-v1",
            agencyRisk: 0.1,
            alienationRisk: 0.6,
            dignityRisk: 0.1,
            overwhelmRisk: 0.1,
            requiredAgencyReservation: "defer-to-host"
        )
        XCTAssertEqual(signal.recommendedSurfaceTone, .warm)
        XCTAssertEqual(signal.requiredAgencyReservation, "defer-to-host")
    }

    // MARK: - 5. BASAnomalyTrace + BASNarrativeDistortion

    func testAnomalyTraceRoundTripsAllFields() throws {
        let p = BASAbyssalPressure(
            pressureID: "p",
            unknownLoad: 0.5,
            consequenceRadius: 0.5,
            evidenceDebt: 0.5,
            ontologyDistortion: 0.5,
            manipulationIndex: 0.5,
            narrativePollution: 0.5,
            recommendedModes: []
        )
        let trace = BASAnomalyTrace(
            traceID: "t",
            anomalyTypes: [.realityDenial, .forcedClosure],
            pressureVector: p,
            relationShift: "observer→subject",
            sourceRefs: ["obs-1", "obs-2"],
            confidence: 0.8
        )
        let restored = try roundTrip(trace)
        XCTAssertEqual(restored, trace)
    }

    func testAnomalyTypeRawValuesMatchWhitePaper() {
        let map: [BASAnomalyType: String] = [
            .narrativeDistortion: "narrative-distortion",
            .realityDenial: "reality-denial",
            .relationDislocation: "relation-dislocation",
            .powerDislocation: "power-dislocation",
            .falseUrgency: "false-urgency",
            .falseGoodwill: "false-goodwill",
            .anomalousCalm: "anomalous-calm",
            .forcedClosure: "forced-closure"
        ]
        for (kind, expected) in map {
            XCTAssertEqual(kind.rawValue, expected,
                           "expected \(kind) → \(expected)")
        }
    }

    func testNarrativeDistortionRoundTripsAllFields() throws {
        let nd = BASNarrativeDistortion(
            distortionID: "nd-1",
            realityDenial: 0.4,
            historyRewrite: 0.5,
            forcedClosure: 0.6,
            roleInversion: 0.7,
            urgencyMask: 0.8,
            confidence: 0.9
        )
        let restored = try roundTrip(nd)
        XCTAssertEqual(restored, nd)
    }

    func testAnomalyWatchProtocolDerivesAllTypesAtMaxDistortion() {
        let nd = BASNarrativeDistortion(
            distortionID: "nd",
            realityDenial: 1,
            historyRewrite: 1,
            forcedClosure: 1,
            roleInversion: 1,
            urgencyMask: 1,
            confidence: 0.9
        )
        let trace = BASAnomalyWatchProtocol.trace(
            traceID: "t",
            distortion: nd,
            relationShift: "",
            sourceRefs: ["obs-1"]
        )
        XCTAssertEqual(
            Set(trace.anomalyTypes),
            Set([
                .realityDenial,
                .narrativeDistortion,
                .forcedClosure,
                .relationDislocation,
                .falseUrgency
            ])
        )
        XCTAssertEqual(trace.confidence, 0.9, accuracy: 1e-9)
    }

    func testAnomalyWatchProtocolEmitsNoTypesForFlatDistortion() {
        let nd = BASNarrativeDistortion(
            distortionID: "nd",
            realityDenial: 0,
            historyRewrite: 0,
            forcedClosure: 0,
            roleInversion: 0,
            urgencyMask: 0,
            confidence: 0.7
        )
        let trace = BASAnomalyWatchProtocol.trace(
            traceID: "t",
            distortion: nd,
            relationShift: "",
            sourceRefs: []
        )
        XCTAssertEqual(trace.anomalyTypes, [])
    }

    // MARK: - 6. BASAbyssalBranch

    func testAbyssalBranchRoundTripsAllFields() throws {
        let branch = BASAbyssalBranch(
            branchID: "b-1",
            sourceCandidateRef: "cand-1",
            triggerReasons: ["unknown>0.8", "ontology-distortion"],
            unknownLoad: 0.85,
            manipulationLoad: 0.6,
            ontologyDistortion: 0.7,
            protectivePathRefs: ["alt-1"],
            requiredClosureConditions: ["sovereign-review-passed"]
        )
        let restored = try roundTrip(branch)
        XCTAssertEqual(restored, branch)
    }

    // MARK: - 7. BASUnknownReserve

    func testUnknownReserveRoundTripsAllFields() throws {
        let r = BASUnknownReserve(
            reserveID: "r-1",
            unknownRefs: ["u-1", "u-2"],
            whyUnresolved: "insufficient evidence",
            forbiddenInferences: ["causal-chain-extension"],
            evidenceNeeded: ["primary-source"],
            assertionCeiling: .qualified
        )
        let restored = try roundTrip(r)
        XCTAssertEqual(restored, r)
        XCTAssertTrue(restored.isOpen)
    }

    func testUnknownReserveAssertionCeilingRawValuesMatchWhitePaper() {
        let map: [BASUnknownAssertionCeiling: String] = [
            .none: "none",
            .metaOnly: "meta-only",
            .qualified: "qualified",
            .provisional: "provisional",
            .unrestricted: "unrestricted"
        ]
        for (kind, expected) in map {
            XCTAssertEqual(kind.rawValue, expected)
        }
    }

    func testUnknownReserveIsClosedWhenUnrestrictedOrEmpty() {
        let r1 = BASUnknownReserve(
            reserveID: "r",
            unknownRefs: ["u-1"],
            whyUnresolved: "",
            forbiddenInferences: [],
            evidenceNeeded: [],
            assertionCeiling: .unrestricted
        )
        XCTAssertFalse(r1.isOpen)
        let r2 = BASUnknownReserve(
            reserveID: "r",
            unknownRefs: [],
            whyUnresolved: "",
            forbiddenInferences: [],
            evidenceNeeded: [],
            assertionCeiling: .none
        )
        XCTAssertFalse(r2.isOpen)
    }

    // MARK: - 8. BASSealEnvelope + BASOldSealSealingProtocol

    func testSealEnvelopeRoundTripsAllFields() throws {
        let s = BASSealEnvelope(
            sealID: "s-1",
            targetRefs: ["mem-1", "mem-2"],
            sealReason: "high-sensitivity",
            accessPolicy: .sovereignOnly,
            revealConditions: ["sovereign-verdict-pass"],
            lineageCutRefs: ["cut-1"],
            auditRef: "audit-42"
        )
        let restored = try roundTrip(s)
        XCTAssertEqual(restored, s)
        XCTAssertTrue(restored.blocksOrdinaryRetrieval)
    }

    func testSealAccessPolicyRawValuesMatchWhitePaper() {
        let map: [BASSealAccessPolicy: String] = [
            .forbidden: "forbidden",
            .sovereignOnly: "sovereign-only",
            .hostExplicit: "host-explicit",
            .auditedAccess: "audited-access",
            .passive: "passive"
        ]
        for (kind, expected) in map {
            XCTAssertEqual(kind.rawValue, expected)
        }
    }

    func testOldSealSealingProtocolDetectsSealedTarget() {
        let seals = [
            BASSealEnvelope(
                sealID: "s-1",
                targetRefs: ["mem-1"],
                sealReason: "",
                accessPolicy: .sovereignOnly,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            ),
            BASSealEnvelope(
                sealID: "s-2",
                targetRefs: ["mem-2"],
                sealReason: "",
                accessPolicy: .passive,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            )
        ]
        XCTAssertTrue(
            BASOldSealSealingProtocol.isSealed(
                targetRef: "mem-1", in: seals))
        // mem-2 is `passive` — does not block ordinary retrieval.
        XCTAssertFalse(
            BASOldSealSealingProtocol.isSealed(
                targetRef: "mem-2", in: seals))
        XCTAssertFalse(
            BASOldSealSealingProtocol.isSealed(
                targetRef: "mem-3", in: seals))
    }

    func testOldSealSealingProtocolReturnsStrictestPolicy() {
        let seals = [
            BASSealEnvelope(
                sealID: "s-1",
                targetRefs: ["mem-1"],
                sealReason: "",
                accessPolicy: .auditedAccess,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            ),
            BASSealEnvelope(
                sealID: "s-2",
                targetRefs: ["mem-1"],
                sealReason: "",
                accessPolicy: .forbidden,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            ),
            BASSealEnvelope(
                sealID: "s-3",
                targetRefs: ["mem-1"],
                sealReason: "",
                accessPolicy: .hostExplicit,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            )
        ]
        XCTAssertEqual(
            BASOldSealSealingProtocol.strictestPolicy(
                for: "mem-1", in: seals),
            .forbidden)
        XCTAssertEqual(
            BASOldSealSealingProtocol.strictestPolicy(
                for: "no-such", in: seals),
            .passive)
    }

    func testOldSealSealingProtocolReturnsAllSealsForTarget() {
        let seals = [
            BASSealEnvelope(
                sealID: "s-1",
                targetRefs: ["mem-1"],
                sealReason: "",
                accessPolicy: .auditedAccess,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            ),
            BASSealEnvelope(
                sealID: "s-2",
                targetRefs: ["mem-1", "mem-2"],
                sealReason: "",
                accessPolicy: .passive,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: "a"
            )
        ]
        let covering = BASOldSealSealingProtocol.sealsCovering(
            targetRef: "mem-1", in: seals)
        XCTAssertEqual(covering.count, 2)
        XCTAssertEqual(covering.map(\.sealID), ["s-1", "s-2"])
    }

    // MARK: - 9. BASForbiddenKnowledgeCandidate

    func testForbiddenKnowledgeCandidateRoundTripsAllFields() throws {
        let c = BASForbiddenKnowledgeCandidate(
            candidateID: "c-1",
            sourceRefs: ["src-1"],
            riskReasons: ["manipulation>0.7"],
            contaminationRefs: ["lin-1"],
            coolingPeriod: 86_400,
            shadowTrialPolicy: .restricted,
            sovereignReviewState: .pending,
            rollbackPlanRef: "plan-1"
        )
        let restored = try roundTrip(c)
        XCTAssertEqual(restored, c)
        XCTAssertFalse(restored.allowsReconsideration)
    }

    func testForbiddenKnowledgeCandidateAllowsReconsiderationOnlyWhenCleared() {
        for state: BASSovereignReviewState in [
            .notReferred, .cleared, .pending, .held, .rejected
        ] {
            let c = BASForbiddenKnowledgeCandidate(
                candidateID: "c",
                sourceRefs: [],
                riskReasons: [],
                contaminationRefs: [],
                coolingPeriod: 0,
                shadowTrialPolicy: .standard,
                sovereignReviewState: state
            )
            switch state {
            case .cleared, .notReferred:
                XCTAssertTrue(c.allowsReconsideration,
                              "state=\(state) should permit")
            case .pending, .held, .rejected:
                XCTAssertFalse(c.allowsReconsideration,
                               "state=\(state) should block")
            }
        }
    }

    func testShadowTrialPolicyRawValuesMatchWhitePaper() {
        let map: [BASShadowTrialPolicy: String] = [
            .none: "none",
            .manualOnly: "manual-only",
            .restricted: "restricted",
            .standard: "standard",
            .escalated: "escalated"
        ]
        for (kind, expected) in map {
            XCTAssertEqual(kind.rawValue, expected)
        }
    }

    func testSovereignReviewStateRawValuesMatchWhitePaper() {
        let map: [BASSovereignReviewState: String] = [
            .notReferred: "not-referred",
            .pending: "pending",
            .held: "held",
            .cleared: "cleared",
            .rejected: "rejected"
        ]
        for (kind, expected) in map {
            XCTAssertEqual(kind.rawValue, expected)
        }
    }

    func testForbiddenKnowledgeCoolingPeriodIsNonNegative() {
        let c = BASForbiddenKnowledgeCandidate(
            candidateID: "c",
            sourceRefs: [],
            riskReasons: [],
            contaminationRefs: [],
            coolingPeriod: -10,
            shadowTrialPolicy: .standard,
            sovereignReviewState: .notReferred
        )
        XCTAssertEqual(c.coolingPeriod, 0)
    }
}
