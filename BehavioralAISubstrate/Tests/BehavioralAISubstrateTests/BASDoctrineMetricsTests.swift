import XCTest
@testable import BASOrchestration

/// M576 (chapter 一百五十一) — pin BASDoctrineMetrics 6 typed schemas
/// + 6 pure-function compute helpers per master plan v1.0 §13.2.
final class BASDoctrineMetricsTests: XCTestCase {

    // MARK: - 1. Schema versions pinned across all 6 types

    func testSchemaVersionsPinned() {
        XCTAssertEqual(
            BASAxisStabilityScore.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASGateFidelityScore.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASOriginTraceCompleteness.currentSchemaVersion,
            "1.0.0")
        XCTAssertEqual(
            BASSanctumLeakRate.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASDoctrineHarmonyScore.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASHumanAnchorRetention.currentSchemaVersion, "1.0.0")
        // Threshold constant
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.schemaVersion, "1.0.0")
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.emptyInputScore, 0.0)
    }

    // MARK: - 2. AxisStabilityScore — Codable round-trip + clamping

    func testAxisStabilityCodableRoundTrip() throws {
        let score = BASAxisStabilityScore(
            metricID: "axis-stab-1",
            alignmentRefs: ["a1", "a2"],
            alignmentReadings: 2,
            centerScoreMean: 0.85,
            centerScoreP25: 0.8,
            centerScoreP75: 0.9,
            deviationCount: 0,
            stabilityIndex: 0.9)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(
            BASAxisStabilityScore.self, from: data)
        XCTAssertEqual(decoded, score)
    }

    func testAxisStabilityClamping() {
        let score = BASAxisStabilityScore(
            metricID: "axis-clamp",
            alignmentRefs: ["", " ok ", ""],  // empty/trim filter
            alignmentReadings: -5,
            centerScoreMean: 1.5,            // → clamp 1.0
            centerScoreP25: -0.3,            // → clamp 0.0
            centerScoreP75: 0.9,
            deviationCount: -1,              // → clamp 0
            stabilityIndex: 2.0)             // → clamp 1.0
        XCTAssertEqual(score.alignmentRefs, ["ok"])
        XCTAssertEqual(score.alignmentReadings, 0)
        XCTAssertEqual(score.centerScoreMean, 1.0)
        XCTAssertEqual(score.centerScoreP25, 0.0)
        XCTAssertEqual(score.deviationCount, 0)
        XCTAssertEqual(score.stabilityIndex, 1.0)
    }

    // MARK: - 3. AxisStability compute — empty + happy

    func testAxisStabilityEmptyInput() {
        let score = BASDoctrineMetricsCompute.axisStability(
            metricID: "test", from: [])
        XCTAssertEqual(score.alignmentReadings, 0)
        XCTAssertEqual(score.stabilityIndex, 0.0)
        XCTAssertEqual(score.centerScoreMean, 0.0)
    }

    func testAxisStabilityHappyPath() {
        let alignments = [
            BASAxisAlignment(alignmentID: "a1", targetRef: "t1",
                axisRef: "x", centerScore: 0.8,
                deviationCodes: [], correctionHint: "",
                requiresGate: false),
            BASAxisAlignment(alignmentID: "a2", targetRef: "t2",
                axisRef: "x", centerScore: 0.9,
                deviationCodes: ["dev1"], correctionHint: "fix",
                requiresGate: false),
            BASAxisAlignment(alignmentID: "a3", targetRef: "t3",
                axisRef: "x", centerScore: 1.0,
                deviationCodes: [], correctionHint: "",
                requiresGate: false),
            BASAxisAlignment(alignmentID: "a4", targetRef: "t4",
                axisRef: "x", centerScore: 0.7,
                deviationCodes: ["dev2"], correctionHint: "",
                requiresGate: true),
        ]
        let score = BASDoctrineMetricsCompute.axisStability(
            metricID: "test", from: alignments)
        XCTAssertEqual(score.alignmentReadings, 4)
        XCTAssertEqual(score.deviationCount, 2)
        // sorted = [0.7, 0.8, 0.9, 1.0]; mean = 0.85
        XCTAssertEqual(
            score.centerScoreMean, 0.85, accuracy: 0.01)
        XCTAssertGreaterThan(score.stabilityIndex, 0.0)
        XCTAssertLessThanOrEqual(score.stabilityIndex, 1.0)
    }

    // MARK: - 4. GateFidelityScore — Codable + clamping

    func testGateFidelityCodableRoundTrip() throws {
        let score = BASGateFidelityScore(
            metricID: "gate-1",
            gateRefs: ["g1"],
            totalGateRequests: 10,
            gatePassed: 7,
            gateDenied: 2,
            gateRemandedForSecondCheck: 1,
            fidelityRatio: 0.9)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(
            BASGateFidelityScore.self, from: data)
        XCTAssertEqual(decoded, score)
    }

    // MARK: - 5. GateFidelity compute — empty + happy

    func testGateFidelityEmptyInput() {
        let score = BASDoctrineMetricsCompute.gateFidelity(
            metricID: "test", from: [])
        XCTAssertEqual(score.totalGateRequests, 0)
        XCTAssertEqual(score.fidelityRatio, 0.0)
    }

    func testGateFidelityHappyPath() {
        let gates = [
            makeGate(id: "g1", state: .passed),
            makeGate(id: "g2", state: .passed),
            makeGate(id: "g3", state: .denied),
            makeGate(id: "g4", state: .remanded),
            makeGate(id: "g5", state: .pending),
        ]
        let score = BASDoctrineMetricsCompute.gateFidelity(
            metricID: "test", from: gates)
        XCTAssertEqual(score.totalGateRequests, 5)
        XCTAssertEqual(score.gatePassed, 2)
        XCTAssertEqual(score.gateDenied, 1)
        XCTAssertEqual(score.gateRemandedForSecondCheck, 1)
        // resolved = passed + denied = 3 / total 5 = 0.6
        XCTAssertEqual(score.fidelityRatio, 0.6, accuracy: 0.001)
    }

    private func makeGate(
        id: String, state: BASKunlunGateState
    ) -> BASHeavenGatePermit {
        BASHeavenGatePermit(
            gateID: id,
            sourceRef: "src",
            targetDomain: "test",
            gateClass: .cognitive,
            requiredSeals: [],
            actionPermitRef: "permit",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: state,
            returnPathRef: "")
    }

    // MARK: - 6. OriginTraceCompleteness — Codable + clamping

    func testOriginTraceCompletenessCodableRoundTrip() throws {
        let score = BASOriginTraceCompleteness(
            metricID: "origin-1",
            traceRefs: ["t1", "t2"],
            derivedObjectCount: 2,
            tracesWithFullProvenance: 1,
            tracesWithMissingRoots: 1,
            completenessRatio: 0.5)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(
            BASOriginTraceCompleteness.self, from: data)
        XCTAssertEqual(decoded, score)
    }

    // MARK: - 7. OriginTraceCompleteness compute — empty + happy

    func testOriginTraceCompletenessEmpty() {
        let score = BASDoctrineMetricsCompute
            .originTraceCompleteness(
                metricID: "test", from: [])
        XCTAssertEqual(score.derivedObjectCount, 0)
        XCTAssertEqual(score.completenessRatio, 0.0)
    }

    func testOriginTraceCompletenessHappy() {
        let traces = [
            makeTrace(id: "t1",
                roots: ["r1"], audits: ["a1"], steps: ["s1"]),
            makeTrace(id: "t2",
                roots: [], audits: ["a2"], steps: ["s2"]),
            makeTrace(id: "t3",
                roots: ["r3"], audits: ["a3"], steps: ["s3"]),
        ]
        let score = BASDoctrineMetricsCompute
            .originTraceCompleteness(
                metricID: "test", from: traces)
        XCTAssertEqual(score.derivedObjectCount, 3)
        XCTAssertEqual(score.tracesWithFullProvenance, 2)
        XCTAssertEqual(score.tracesWithMissingRoots, 1)
        XCTAssertEqual(
            score.completenessRatio, 2.0/3.0, accuracy: 0.01)
    }

    private func makeTrace(
        id: String, roots: [String], audits: [String],
        steps: [String]
    ) -> BASRiverOriginTrace {
        BASRiverOriginTrace(
            traceID: id,
            rootSourceRefs: roots,
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: steps,
            consentRefs: [],
            permitRefs: [],
            auditRefs: audits,
            deletionDependents: [],
            lineageCutRefs: [])
    }

    // MARK: - 8. SanctumLeakRate — Codable + clamping

    func testSanctumLeakRateCodableRoundTrip() throws {
        let score = BASSanctumLeakRate(
            metricID: "sanctum-1",
            sanctumRefs: ["s1"],
            sanctumEntriesObserved: 10,
            unauthorizedRetrievalAttempts: 5,
            unauthorizedRetrievalsBlocked: 4,
            leakRate: 0.2)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(
            BASSanctumLeakRate.self, from: data)
        XCTAssertEqual(decoded, score)
    }

    // MARK: - 9. SanctumLeakRate compute — empty + happy

    func testSanctumLeakRateEmpty() {
        let score = BASDoctrineMetricsCompute.sanctumLeakRate(
            metricID: "test", from: [],
            unauthorizedAttempts: 0, unauthorizedBlocked: 0)
        XCTAssertEqual(score.leakRate, 0.0)
    }

    func testSanctumLeakRateHappy() {
        let entries = [
            makeSanctum(id: "s1"),
            makeSanctum(id: "s2"),
            makeSanctum(id: "s3"),
        ]
        let score = BASDoctrineMetricsCompute.sanctumLeakRate(
            metricID: "test", from: entries,
            unauthorizedAttempts: 10, unauthorizedBlocked: 7)
        XCTAssertEqual(score.sanctumEntriesObserved, 3)
        XCTAssertEqual(score.unauthorizedRetrievalAttempts, 10)
        XCTAssertEqual(score.unauthorizedRetrievalsBlocked, 7)
        // leaked = 10 - 7 = 3 / 10 = 0.3
        XCTAssertEqual(score.leakRate, 0.3, accuracy: 0.001)
    }

    func testSanctumLeakRateBlockedExceedsAttempts() {
        // Defensive: blocked > attempts → blocked clamped to attempts
        let entries = [makeSanctum(id: "s1")]
        let score = BASDoctrineMetricsCompute.sanctumLeakRate(
            metricID: "test", from: entries,
            unauthorizedAttempts: 5, unauthorizedBlocked: 100)
        XCTAssertEqual(
            score.unauthorizedRetrievalsBlocked, 5)
        XCTAssertEqual(score.leakRate, 0.0)
    }

    private func makeSanctum(id: String) -> BASYaochiSanctumEntry {
        BASYaochiSanctumEntry(
            entryID: id,
            memoryRef: "mem-\(id)",
            hostRef: "host",
            sanctumClass: .sensitive,
            accessPolicy: .sealed,
            revealConditions: [],
            coolingPeriod: 0,
            humanAnchorRequired: true,
            lastRevealedAt: "")
    }

    // MARK: - 10. DoctrineHarmonyScore — Codable + clamping

    func testDoctrineHarmonyCodableRoundTrip() throws {
        let score = BASDoctrineHarmonyScore(
            metricID: "harmony-1",
            cthulhuRedLineHits: 2,
            kunlunRedLineHits: 1,
            crossDoctrineConflicts: 0,
            sampleCount: 100,
            harmonyScore: 0.97)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(
            BASDoctrineHarmonyScore.self, from: data)
        XCTAssertEqual(decoded, score)
    }

    // MARK: - 11. DoctrineHarmony compute — empty + happy

    func testDoctrineHarmonyEmpty() {
        let score = BASDoctrineMetricsCompute.doctrineHarmony(
            metricID: "test",
            cthulhuHits: 0, kunlunHits: 0,
            crossConflicts: 0, sampleCount: 0)
        XCTAssertEqual(score.harmonyScore, 0.0)
    }

    func testDoctrineHarmonyHappy() {
        // 3 hits + 2 conflicts in sample of 100 = 5/100 = 0.05
        // harmony = 1 - 0.05 = 0.95
        let score = BASDoctrineMetricsCompute.doctrineHarmony(
            metricID: "test",
            cthulhuHits: 2, kunlunHits: 1,
            crossConflicts: 2, sampleCount: 100)
        XCTAssertEqual(score.cthulhuRedLineHits, 2)
        XCTAssertEqual(score.kunlunRedLineHits, 1)
        XCTAssertEqual(score.crossDoctrineConflicts, 2)
        XCTAssertEqual(score.sampleCount, 100)
        XCTAssertEqual(
            score.harmonyScore, 0.95, accuracy: 0.001)
    }

    func testDoctrineHarmonySaturation() {
        // hits > sample → harmony floored at 0
        let score = BASDoctrineMetricsCompute.doctrineHarmony(
            metricID: "test",
            cthulhuHits: 100, kunlunHits: 100,
            crossConflicts: 100, sampleCount: 10)
        XCTAssertEqual(score.harmonyScore, 0.0)
    }

    // MARK: - 12. HumanAnchorRetention — Codable + clamping

    func testHumanAnchorCodableRoundTrip() throws {
        let score = BASHumanAnchorRetention(
            metricID: "anchor-1",
            anchorRefs: ["a1"],
            anchorSignalsObserved: 10,
            anchorPreservedAcrossTurns: 8,
            anchorErodedCount: 2,
            retentionRatio: 0.8)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(
            BASHumanAnchorRetention.self, from: data)
        XCTAssertEqual(decoded, score)
    }

    // MARK: - 13. HumanAnchorRetention compute — empty + happy

    func testHumanAnchorRetentionEmpty() {
        let score = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "test", from: [])
        XCTAssertEqual(score.retentionRatio, 0.0)
    }

    func testHumanAnchorRetentionHappy() {
        let signals = [
            // Preserved (low total risk: 0.1+0.1+0.1+0.1 = 0.4 < 1.0)
            makeAnchor(id: "a1",
                agency: 0.1, alienation: 0.1,
                dignity: 0.1, overwhelm: 0.1),
            // Preserved (medium total: 0.2+0.2+0.2+0.2 = 0.8 < 1.0)
            makeAnchor(id: "a2",
                agency: 0.2, alienation: 0.2,
                dignity: 0.2, overwhelm: 0.2),
            // Eroded (sum 1.6 > 1.0)
            makeAnchor(id: "a3",
                agency: 0.4, alienation: 0.4,
                dignity: 0.4, overwhelm: 0.4),
        ]
        let score = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "test", from: signals)
        XCTAssertEqual(score.anchorSignalsObserved, 3)
        XCTAssertEqual(score.anchorPreservedAcrossTurns, 2)
        XCTAssertEqual(score.anchorErodedCount, 1)
        XCTAssertEqual(
            score.retentionRatio, 2.0/3.0, accuracy: 0.01)
    }

    func testHumanAnchorRetentionThresholdConfigurable() {
        // Same signals, stricter threshold (0.5) classifies more
        // anchors as eroded
        let signals = [
            makeAnchor(id: "a1",
                agency: 0.2, alienation: 0.2,
                dignity: 0.2, overwhelm: 0.2),  // sum 0.8
        ]
        let score = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "test", from: signals,
                erosionThreshold: 0.5)
        XCTAssertEqual(score.anchorErodedCount, 1)
        XCTAssertEqual(score.retentionRatio, 0.0)
    }

    private func makeAnchor(
        id: String, agency: Double, alienation: Double,
        dignity: Double, overwhelm: Double
    ) -> BASHumanAnchorSignal {
        BASHumanAnchorSignal(
            anchorID: id,
            hostSummaryRef: "host",
            agencyRisk: agency,
            alienationRisk: alienation,
            dignityRisk: dignity,
            overwhelmRisk: overwhelm,
            recommendedSurfaceTone: .warm,
            requiredAgencyReservation: "")
    }

    // MARK: - 14. Anti-magic-number doctrine: erosion threshold named

    func testErosionThresholdNamed() {
        XCTAssertEqual(
            BASDoctrineMetricsCompute
                .humanAnchorErosionThreshold,
            1.0)
    }
}
