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
        // M584 chapter 一百五十七 — std-based formula:
        // std = sqrt(0.0125) ≈ 0.1118; stability = 1 - 2*std ≈ 0.78
        XCTAssertEqual(
            score.stabilityIndex, 0.776, accuracy: 0.01)
    }

    /// M584 chapter 一百五十七 — defect #21 regression guard:
    /// pre-fix formula `1 - (p75 - p25)` (IQR-based) collapsed to
    /// 1.0 when >50% of scores cluster at one value. Empirical case:
    /// 154/46 bimodal split → mean 0.59 (visible variation) but
    /// stabilityIndex 1.0 (false-ceiling). Post-fix std-based
    /// formula catches the variation.
    func testAxisStabilityBimodalNotFalseCeiling() {
        // 154 alignments at centerScore 0.6667 + 46 at 0.3333
        var alignments: [BASAxisAlignment] = []
        for i in 0..<154 {
            alignments.append(
                BASAxisAlignment(alignmentID: "high\(i)",
                    targetRef: "t", axisRef: "x",
                    centerScore: 0.6667,
                    deviationCodes: [], correctionHint: "",
                    requiresGate: false))
        }
        for i in 0..<46 {
            alignments.append(
                BASAxisAlignment(alignmentID: "low\(i)",
                    targetRef: "t", axisRef: "x",
                    centerScore: 0.3333,
                    deviationCodes: [], correctionHint: "",
                    requiresGate: true))
        }
        let score = BASDoctrineMetricsCompute.axisStability(
            metricID: "test-bimodal", from: alignments)
        // Mean ≈ 0.59 (visible variation)
        XCTAssertEqual(
            score.centerScoreMean, 0.5900, accuracy: 0.01)
        // std ≈ 0.140; stability = 1 - 2*0.14 ≈ 0.72.
        // Pre-fix: this would have been 1.0 (false-ceiling).
        XCTAssertLessThan(score.stabilityIndex, 0.85)
        XCTAssertGreaterThan(score.stabilityIndex, 0.65)
    }

    /// M584 chapter 一百五十七 — homogeneous distribution still
    /// gives stability 1.0 (std=0).
    func testAxisStabilityHomogeneousIsStable() {
        let alignments = (0..<10).map { i in
            BASAxisAlignment(alignmentID: "a\(i)",
                targetRef: "t", axisRef: "x",
                centerScore: 0.5,
                deviationCodes: [], correctionHint: "",
                requiresGate: false)
        }
        let score = BASDoctrineMetricsCompute.axisStability(
            metricID: "test-homo", from: alignments)
        XCTAssertEqual(score.stabilityIndex, 1.0)
    }

    /// M587 chapter 一百五十九 — Issue 5 (deep review LOW): single-
    /// element input regression guard. n=1 → variance=0 → std=0 →
    /// stability=1.0.
    func testAxisStabilitySingleElement() {
        let alignments = [
            BASAxisAlignment(alignmentID: "solo", targetRef: "t",
                axisRef: "x", centerScore: 0.42,
                deviationCodes: [], correctionHint: "",
                requiresGate: false)
        ]
        let score = BASDoctrineMetricsCompute.axisStability(
            metricID: "test-single", from: alignments)
        XCTAssertEqual(score.stabilityIndex, 1.0)
        XCTAssertEqual(
            score.centerScoreMean, 0.42, accuracy: 0.001)
    }

    /// M587 chapter 一百五十九 — Issue 5 boundary scores [0.0, 1.0]
    /// guard against NaN propagation. mean = 0.5; variance = 0.25;
    /// std = 0.5; stability = 1 - 1.0 = 0.0 (max variation).
    func testAxisStabilityMaxVariation() {
        let alignments = [
            BASAxisAlignment(alignmentID: "low", targetRef: "t",
                axisRef: "x", centerScore: 0.0,
                deviationCodes: [], correctionHint: "",
                requiresGate: false),
            BASAxisAlignment(alignmentID: "hi", targetRef: "t",
                axisRef: "x", centerScore: 1.0,
                deviationCodes: [], correctionHint: "",
                requiresGate: false),
        ]
        let score = BASDoctrineMetricsCompute.axisStability(
            metricID: "test-max", from: alignments)
        // std for {0, 1} = 0.5; 1 - 2*0.5 = 0.0
        XCTAssertEqual(score.stabilityIndex, 0.0)
        // No NaN/Inf in any field
        XCTAssertFalse(score.stabilityIndex.isNaN)
        XCTAssertFalse(score.centerScoreMean.isNaN)
    }

    /// M587 chapter 一百五十九 — Issue 3 disclosure pin: partial
    /// provenance traces (has roots+audit but no steps) are
    /// neither full nor missingRoots. completenessRatio
    /// correctly downgrades but breakdown fields don't surface
    /// the partial bucket.
    func testOriginCompletenessPartialProvenanceNotFullNorMissing() {
        let partial = BASRiverOriginTrace(
            traceID: "partial",
            rootSourceRefs: ["root1"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],  // EMPTY — partial
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["audit1"],
            deletionDependents: [],
            lineageCutRefs: [])
        let score = BASDoctrineMetricsCompute
            .originTraceCompleteness(
                metricID: "test-partial", from: [partial])
        // Has roots → not in missingRoots bucket
        XCTAssertEqual(score.tracesWithMissingRoots, 0)
        // Missing steps → not in full bucket either
        XCTAssertEqual(score.tracesWithFullProvenance, 0)
        // Partial bucket invariant: full + missingRoots != n
        XCTAssertNotEqual(
            score.tracesWithFullProvenance
            + score.tracesWithMissingRoots,
            score.derivedObjectCount)
        // completenessRatio correctly downgrades (0/1 = 0)
        XCTAssertEqual(score.completenessRatio, 0.0)
    }

    /// M587 chapter 一百五十九 — Issue 4 defensive: substrate's
    /// `abyssal.escalation:` is only emitted when `pressure.
    /// sovereignEscalationHint != nil` — substrate cannot emit
    /// `:none` or `:false` for this key. Pin behavior in case
    /// substrate emission contract changes.
    func testDetectorAbyssalEscalationOnlyOnRealHint() {
        // Substrate-shape: abyssal.escalation:<hint-value-string>
        let realHints = [
            "abyssal.escalation:sovereign-review",
            "abyssal.escalation:slow-down",
            "abyssal.escalation:pause-decision",
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(in: realHints),
            3)
        // If substrate ever emitted `:none` (it doesn't currently),
        // the bare-prefix pattern would still fire. Document this
        // future-fragility:
        let speculative = ["abyssal.escalation:none"]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(
                in: speculative),
            1,
            "Bare-prefix matches all values; substrate's "
            + "current contract makes this safe but future "
            + "emission shape changes need pattern audit.")
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
        // M581 chapter 一百五十六 — defect #18 fix:
        // resolved = passed + denied + remanded = 4 / total 5 = 0.8
        // (.remanded is doctrine-correct gate decision per Kunlun
        // §4.3 / RL5; only .pending counts as unfaithful)
        XCTAssertEqual(score.fidelityRatio, 0.8, accuracy: 0.001)
    }

    /// M581 chapter 一百五十六 — defect #18 regression guard:
    /// 200/200 `.remanded` substrate emission (sovereign verdict
    /// is `.toolCut`/`.memoryFreeze`/`.quarantine`) must give
    /// fidelity 1.0, not 0.0. Pre-fix: `(passed+denied)/total = 0`.
    /// Post-fix: `(passed+denied+remanded)/total = 1.0`.
    func testGateFidelityAllRemandedIsFaithful() {
        let gates = (0..<10).map {
            makeGate(id: "g\($0)", state: .remanded)
        }
        let score = BASDoctrineMetricsCompute.gateFidelity(
            metricID: "test-remanded", from: gates)
        XCTAssertEqual(score.gateRemandedForSecondCheck, 10)
        XCTAssertEqual(score.fidelityRatio, 1.0)
    }

    /// M581 chapter 一百五十六 — only `.pending` is unfaithful.
    func testGateFidelityAllPendingIsUnfaithful() {
        let gates = (0..<10).map {
            makeGate(id: "g\($0)", state: .pending)
        }
        let score = BASDoctrineMetricsCompute.gateFidelity(
            metricID: "test-pending", from: gates)
        XCTAssertEqual(score.fidelityRatio, 0.0)
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
        // M587 chapter 一百五十九 — Issue 2 (deep review fix):
        // crossConflicts no longer counted in harmony numerator.
        // Pre-fix: 5/100 = 0.05 → 0.95.
        // Post-fix: 3/100 = 0.03 → 0.97 (cross-conflict reported
        // separately as additive metadata).
        let score = BASDoctrineMetricsCompute.doctrineHarmony(
            metricID: "test",
            cthulhuHits: 2, kunlunHits: 1,
            crossConflicts: 2, sampleCount: 100)
        XCTAssertEqual(score.cthulhuRedLineHits, 2)
        XCTAssertEqual(score.kunlunRedLineHits, 1)
        XCTAssertEqual(score.crossDoctrineConflicts, 2)
        XCTAssertEqual(score.sampleCount, 100)
        // Pre-M587: 0.95 ((cth+kun+conflicts)/sample = 5/100)
        // Post-M587: 0.97 ((cth+kun)/sample = 3/100)
        XCTAssertEqual(
            score.harmonyScore, 0.97, accuracy: 0.001)
    }

    /// M587 chapter 一百五十九 — Issue 2 regression guard:
    /// cross-conflict no longer double-deducts harmony when same
    /// pattern triggers both hit and conflict.
    func testDoctrineHarmonyCrossConflictNotDoubleCount() {
        // Anchor reserved (cthulhu hit) + axis-says-no-gate.
        // Pre-fix: counted in cthulhu (1) AND in conflicts (1) →
        // 2/100 deducted (0.98).
        // Post-fix: only cthulhu hit (1) deducted; conflict reported
        // separately → 1/100 deducted (0.99).
        let score = BASDoctrineMetricsCompute.doctrineHarmony(
            metricID: "test-no-double",
            cthulhuHits: 1, kunlunHits: 0,
            crossConflicts: 1, sampleCount: 100)
        XCTAssertEqual(
            score.harmonyScore, 0.99, accuracy: 0.001)
        // Cross-conflict still reported (additive metadata).
        XCTAssertEqual(score.crossDoctrineConflicts, 1)
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
        // Chapter 一百五十四 final calibration: threshold 1.5
        // (empirically derived from substrate's real emission
        // distribution: delay ~1.05, block ~1.85; threshold 1.5
        // cleanly discriminates).
        let signals = [
            // Preserved (sum 0.4 < 1.5)
            makeAnchor(id: "a1",
                agency: 0.1, alienation: 0.1,
                dignity: 0.1, overwhelm: 0.1),
            // Preserved (sum 1.05 < 1.5) — typical substrate delay path
            makeAnchor(id: "a2",
                agency: 0.25, alienation: 0.35,
                dignity: 0.15, overwhelm: 0.3),
            // Eroded (sum 1.85 >= 1.5) — typical substrate block path
            makeAnchor(id: "a3",
                agency: 0.75, alienation: 0.15,
                dignity: 0.45, overwhelm: 0.5),
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

    func testHumanAnchorRetentionInclusiveThreshold() {
        // Defect #13b: sum exactly at threshold should erode (>=)
        let signals = [
            makeAnchor(id: "boundary",
                agency: 0.5, alienation: 0.5,
                dignity: 0.5, overwhelm: 0.0)  // sum exactly 1.5
        ]
        let score = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "test", from: signals)
        XCTAssertEqual(score.anchorErodedCount, 1,
            "sum exactly at threshold (1.5) should erode")
        XCTAssertEqual(score.retentionRatio, 0.0)
    }

    func testHumanAnchorRetentionThresholdConfigurable() {
        // Same signals, stricter threshold (0.5) classifies more
        // anchors as eroded — proves threshold is configurable
        let signals = [
            makeAnchor(id: "a1",
                agency: 0.2, alienation: 0.2,
                dignity: 0.2, overwhelm: 0.2),  // sum 0.8 > 0.5
        ]
        let score = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "test", from: signals,
                erosionThreshold: 0.5)
        XCTAssertEqual(score.anchorErodedCount, 1)
        XCTAssertEqual(score.retentionRatio, 0.0)
    }

    func testHumanAnchorRetentionWithSubstrateBaseline() {
        // Chapter 一百五十四 final calibration verification at
        // threshold 1.5:
        // - delay path: substrate emits ~1.05 sum → preserved
        // - block path: substrate emits ~1.85 sum → eroded
        let delay_routine = makeAnchor(id: "delay-routine",
            agency: 0.25, alienation: 0.35,
            dignity: 0.15, overwhelm: 0.3)  // sum 1.05 < 1.5
        let block_typical = makeAnchor(id: "block-typical",
            agency: 0.75, alienation: 0.15,
            dignity: 0.45, overwhelm: 0.5)  // sum 1.85 >= 1.5
        let score = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "test",
                from: [delay_routine, block_typical])
        XCTAssertEqual(score.anchorPreservedAcrossTurns, 1,
            "delay path preserved at threshold 1.5")
        XCTAssertEqual(score.anchorErodedCount, 1,
            "block path eroded at threshold 1.5")
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
        // Chapter 一百五十四 final calibration: 1.5 (empirically
        // derived from substrate's real emission distribution —
        // delay path sums ~1.05, block path sums ~1.85; threshold
        // 1.5 cleanly discriminates).
        // Iteration history:
        //   1.0 (chapter 一百五十一 default) → all eroded (too low)
        //   2.0 (first attempt)              → all preserved (too high)
        //   1.5 (final, empirical)           → 154/200 preserved, 46/200 eroded
        XCTAssertEqual(
            BASDoctrineMetricsCompute
                .humanAnchorErosionThreshold,
            1.5)
    }

    // MARK: - 15. BASDoctrineRedLineDetector (M580 chapter 一百五十五)

    /// Pattern lists are non-empty + immutable across builds.
    func testRedLineDetectorPatternsPinned() {
        XCTAssertFalse(
            BASDoctrineRedLineDetector
                .cthulhuConcernPatterns.isEmpty)
        XCTAssertFalse(
            BASDoctrineRedLineDetector
                .kunlunConcernPatterns.isEmpty)
        // Sentinel: anchor-stress + dominant distortion are
        // load-bearing patterns the bench depends on. Pin them so
        // accidental removal fails this test.
        XCTAssertTrue(
            BASDoctrineRedLineDetector
                .cthulhuConcernPatterns
                .contains("humanAnchor.tone:reserved"))
        XCTAssertTrue(
            BASDoctrineRedLineDetector
                .cthulhuConcernPatterns
                .contains("cthulhu.distortionMap.dominant:true"))
    }

    /// Empirical calibration M580 — patterns that fired 200/200 in
    /// chapter 一百五十五 calibration run (routine substrate state,
    /// NOT red-line violations) must NOT be in the detector list.
    /// Regression guard so future commits don't re-add them.
    func testRoutineStateNotInRedLines() {
        // 200/200 fire rate — kunlun axis simply decided gate is
        // needed. Not a doctrine violation.
        XCTAssertFalse(
            BASDoctrineRedLineDetector
                .kunlunConcernPatterns
                .contains("kunlun.axis.requires-gate:true"))
        // 200/200 fire rate — substrate's normal sovereign-zone
        // state. Not a doctrine violation.
        XCTAssertFalse(
            BASDoctrineRedLineDetector
                .cthulhuConcernPatterns
                .contains("forbidden.allHeld:true"))
    }

    /// Detector counts each ref once even when multiple patterns
    /// could match. Guards against double-count regression.
    func testDetectorCountsEachRefOnce() {
        // Construct a ref that prefix-matches only ONE pattern.
        let refs = ["cthulhu.distortionMap.dominant:true:scope=L4"]
        let cthulhu = BASDoctrineRedLineDetector
            .cthulhuHits(in: refs)
        XCTAssertEqual(cthulhu, 1)
    }

    func testDetectorEmptyInputZero() {
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(in: []),
            0)
        XCTAssertEqual(
            BASDoctrineRedLineDetector.kunlunHits(in: []),
            0)
        XCTAssertEqual(
            BASDoctrineRedLineDetector
                .crossDoctrineConflicts(in: []),
            0)
    }

    func testDetectorCthulhuHitsOnly() {
        let refs = [
            "humanAnchor.tone:reserved",
            "cthulhu.distortionMap.dominant:true",
            "abyssal.escalation:high",
            "permit.mode:answer",       // not a red line
            "kunlun.axis.center:0.7",   // not a red line
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(in: refs),
            3)
        XCTAssertEqual(
            BASDoctrineRedLineDetector.kunlunHits(in: refs),
            0)
    }

    func testDetectorKunlunHitsOnly() {
        // M582 (chapter 一百五十七) — pattern fix:
        // dignityHonored is a count (Int), not Bool. Red-line
        // is `:0` (no return paths honored dignity).
        let refs = [
            "kunlun.return.dignityHonored:0",
            "kunlun.river.cut:true",
            "kunlun.tianmen.denial-well-formed:false",
            "permit.mode:delay",                // not a red line
            "humanAnchor.tone:warm",            // not a red line
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.kunlunHits(in: refs),
            3)
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(in: refs),
            0)
    }

    /// M582 chapter 一百五十七 — defect #20 regression guard:
    /// `:0` is the red-line pattern (no return paths honored
    /// dignity); positive counts (e.g. `:1`, `:5`) are NOT red lines.
    func testDetectorDignityHonoredNonZeroNotRedLine() {
        let refs = [
            "kunlun.return.dignityHonored:1",
            "kunlun.return.dignityHonored:5",
            "kunlun.return.dignityHonored:10",
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.kunlunHits(in: refs),
            0)
    }

    /// M582 chapter 一百五十七 — defect #20 regression guard:
    /// substrate emits `cthulhu.cosmic.dilution:warning` (constant
    /// string), not `:true`. Pre-fix detector pattern `:true` would
    /// never match.
    func testDetectorCosmicDilutionWarning() {
        let refs = [
            "cthulhu.cosmic.dilution:warning",  // substrate emit
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(in: refs),
            1)
        // Pre-fix pattern `:true` doesn't fire (substrate doesn't
        // emit this string).
        let preFixRefs = [
            "cthulhu.cosmic.dilution:true",
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector.cthulhuHits(in: preFixRefs),
            0)
    }

    /// Cross-conflict: anchor reserved (Cthulhu hint = stress) but
    /// Kunlun decided no gate needed → 1 conflict.
    func testCrossConflictDetected() {
        let refs = [
            "humanAnchor.tone:reserved",
            "kunlun.axis.requires-gate:false",
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector
                .crossDoctrineConflicts(in: refs),
            1)
    }

    /// Cross-conflict NOT detected when both signals agree
    /// (anchor reserved + gate required).
    func testCrossConflictNotDetectedWhenConsistent() {
        let refs = [
            "humanAnchor.tone:reserved",
            "kunlun.axis.requires-gate:true",
        ]
        XCTAssertEqual(
            BASDoctrineRedLineDetector
                .crossDoctrineConflicts(in: refs),
            0)
    }

    /// **M590 chapter 一百六十二 — Issue E (deep review iter 5)**:
    /// renamed test to reflect that it pins a STATIC FIXTURE, not
    /// the bench's empirical output (which has shifted with each
    /// chapter's detector calibration). Pre-rename docstring
    /// implied "empirical match" but bench output diverges from
    /// fixture as detector evolves. Static fixture math:
    /// (46+0)/200 = 0.23 → harmony 0.77.
    func testHarmonyStaticFixture46Cthulhu0Kunlun() {
        let cthulhuHits = 46
        let kunlunHits = 0
        let crossConflicts = 0
        let sampleCount = 200
        let harmony = BASDoctrineMetricsCompute
            .doctrineHarmony(
                metricID: "static-fixture-test",
                cthulhuHits: cthulhuHits,
                kunlunHits: kunlunHits,
                crossConflicts: crossConflicts,
                sampleCount: sampleCount)
        XCTAssertEqual(
            harmony.harmonyScore, 0.77, accuracy: 0.001)
    }

    /// **M590 chapter 一百六十二 — chapter 160 empirical lock**:
    /// pins per-emission harmony for the post-M588 detector
    /// catalog (5 Cthulhu + 8 Kunlun patterns). Bench shows 48
    /// turns × 2 patterns = 96 deductions / 200 → harmony 0.52.
    /// This is the per-EMISSION reading.
    func testHarmonyChapter160PerEmissionLock() {
        let harmony = BASDoctrineMetricsCompute
            .doctrineHarmony(
                metricID: "chapter-160-per-emission",
                cthulhuHits: 48,
                kunlunHits: 48,
                crossConflicts: 0,
                sampleCount: 200)
        // (48+48)/200 = 0.48 → 1 - 0.48 = 0.52
        XCTAssertEqual(
            harmony.harmonyScore, 0.52, accuracy: 0.001)
    }

    /// **M590 chapter 一百六十二 — per-turn harmony**:
    /// when 48 turns each emit cthulhu + kunlun red-lines,
    /// per-turn dedup counts 48 deductions / 200 → harmony 0.76.
    /// More semantically aligned with doctrine intent
    /// ("fraction of turns without red lines").
    func testHarmonyPerTurnDedup() {
        let harmony = BASDoctrineMetricsCompute
            .doctrineHarmonyPerTurn(
                metricID: "per-turn-test",
                turnsWithAnyRedLine: 48,
                sampleCount: 200)
        // 48/200 = 0.24 → 1 - 0.24 = 0.76
        XCTAssertEqual(
            harmony.harmonyScore, 0.76, accuracy: 0.001)
        // Per-turn helper carries count in cthulhuRedLineHits
        XCTAssertEqual(harmony.cthulhuRedLineHits, 48)
        XCTAssertEqual(harmony.kunlunRedLineHits, 0)
    }

    /// Per-turn harmony empty-input → 0.0 (anti-recursion + safe
    /// empty default).
    func testHarmonyPerTurnEmpty() {
        let harmony = BASDoctrineMetricsCompute
            .doctrineHarmonyPerTurn(
                metricID: "empty-test",
                turnsWithAnyRedLine: 0,
                sampleCount: 0)
        XCTAssertEqual(harmony.harmonyScore, 0.0)
    }

    /// Per-turn harmony saturation: turnsWithAnyRedLine > sample
    /// (defensive — shouldn't happen but tests bound).
    func testHarmonyPerTurnSaturation() {
        let harmony = BASDoctrineMetricsCompute
            .doctrineHarmonyPerTurn(
                metricID: "saturation-test",
                turnsWithAnyRedLine: 200,
                sampleCount: 100)
        XCTAssertEqual(harmony.harmonyScore, 0.0)
    }

    // MARK: - 16. M591 chapter 一百六十三 — Adversarial reality-report tests

    /// **M591 chapter 一百六十三**: chapter 162 disclosed that 3 of 6
    /// metrics (gate fidelity, origin completeness, sanctum leak)
    /// are "reality reports" — constant by substrate construction
    /// in the current bench. Adversarial tests below verify the
    /// COMPUTE HELPERS produce non-constant output for non-constant
    /// input, proving formulas are sound (the constants are due to
    /// substrate exercise, not metric defect).

    /// Adversarial: gate fidelity falls below 1.0 when ANY pending.
    func testGateFidelityVariesWithPending() {
        let gates = [
            makeGate(id: "g1", state: .passed),
            makeGate(id: "g2", state: .pending),  // unfaithful
            makeGate(id: "g3", state: .denied),
            makeGate(id: "g4", state: .pending),  // unfaithful
        ]
        let score = BASDoctrineMetricsCompute.gateFidelity(
            metricID: "test-adversarial-pending",
            from: gates)
        // resolved = 2 / total 4 = 0.5 → fidelity < 1.0
        XCTAssertEqual(score.fidelityRatio, 0.5)
        XCTAssertLessThan(score.fidelityRatio, 1.0)
    }

    /// Adversarial: origin trace completeness falls below 1.0 when
    /// ANY trace is missing roots.
    func testOriginCompletenessVariesWithMissingRoots() {
        let full = BASRiverOriginTrace(
            traceID: "f", rootSourceRefs: ["r"],
            tributaryRefs: [], derivedObjectRefs: [],
            transformationSteps: ["s"],
            consentRefs: [], permitRefs: [],
            auditRefs: ["a"],
            deletionDependents: [], lineageCutRefs: [])
        let missing = BASRiverOriginTrace(
            traceID: "m", rootSourceRefs: [],  // missing roots
            tributaryRefs: [], derivedObjectRefs: [],
            transformationSteps: ["s"],
            consentRefs: [], permitRefs: [],
            auditRefs: ["a"],
            deletionDependents: [], lineageCutRefs: [])
        let score = BASDoctrineMetricsCompute
            .originTraceCompleteness(
                metricID: "test-adversarial-orphan",
                from: [full, missing])
        // 1 of 2 full → 0.5
        XCTAssertEqual(score.completenessRatio, 0.5)
        XCTAssertEqual(score.tracesWithMissingRoots, 1)
        XCTAssertLessThan(score.completenessRatio, 1.0)
    }

    /// Adversarial: sanctum leak rate rises above 0.0 when
    /// unauthorized retrieval attempts succeed.
    func testSanctumLeakRateVariesWithUnauthorizedSuccess() {
        let entries = [
            BASYaochiSanctumEntry(
                entryID: "s1", memoryRef: "m",
                hostRef: "h", sanctumClass: .sensitive,
                accessPolicy: .sealed, revealConditions: [],
                coolingPeriod: 0,
                humanAnchorRequired: true,
                lastRevealedAt: ""),
        ]
        let score = BASDoctrineMetricsCompute.sanctumLeakRate(
            metricID: "test-adversarial-leak",
            from: entries,
            unauthorizedAttempts: 10,
            unauthorizedBlocked: 7)
        // 3 leaked / 10 = 0.3 leak rate
        XCTAssertEqual(score.leakRate, 0.3, accuracy: 0.001)
        XCTAssertGreaterThan(score.leakRate, 0.0)
    }

    /// Adversarial: zero leakRate is correctly reported when ALL
    /// unauthorized attempts are blocked (substrate doing its job).
    /// Distinguishes "metric measures perfect protection" from
    /// "metric has no input" (chapter 159 disclosure).
    func testSanctumLeakRateZeroWithFullBlocking() {
        let entries = [
            BASYaochiSanctumEntry(
                entryID: "s1", memoryRef: "m",
                hostRef: "h", sanctumClass: .sensitive,
                accessPolicy: .sealed, revealConditions: [],
                coolingPeriod: 0, humanAnchorRequired: true,
                lastRevealedAt: ""),
        ]
        let score = BASDoctrineMetricsCompute.sanctumLeakRate(
            metricID: "test-perfect-protection",
            from: entries,
            unauthorizedAttempts: 50,
            unauthorizedBlocked: 50)
        // 0 leaked / 50 = 0.0; meaningful (not vacuous 0/0)
        XCTAssertEqual(score.leakRate, 0.0)
        XCTAssertEqual(score.unauthorizedRetrievalAttempts, 50)
        XCTAssertEqual(score.unauthorizedRetrievalsBlocked, 50)
    }

    // MARK: - 17. M591 — BASDoctrinePercentileSummary

    /// Empty input → all zeros + threshold counts all 0.
    func testPercentileSummaryEmpty() {
        let s = BASDoctrinePercentileSummary.compute(
            [], thresholds: [1.0, 1.5, 2.0])
        XCTAssertEqual(s.sampleCount, 0)
        XCTAssertEqual(s.min, 0)
        XCTAssertEqual(s.max, 0)
        XCTAssertEqual(s.p25, 0)
        XCTAssertEqual(s.median, 0)
        XCTAssertEqual(s.thresholdCounts, [0, 0, 0])
    }

    /// Single element → all percentiles equal the element value.
    func testPercentileSummarySingleElement() {
        let s = BASDoctrinePercentileSummary.compute(
            [0.42], thresholds: [0.0, 1.0])
        XCTAssertEqual(s.sampleCount, 1)
        XCTAssertEqual(s.min, 0.42)
        XCTAssertEqual(s.max, 0.42)
        XCTAssertEqual(s.p25, 0.42)
        XCTAssertEqual(s.median, 0.42)
        XCTAssertEqual(s.p75, 0.42)
        XCTAssertEqual(s.p99, 0.42)
        XCTAssertEqual(s.thresholdCounts, [1, 0])
    }

    /// 200 elements bimodal {1.05 (154x), 1.85 (46x)} — chapter
    /// 一百五十四 calibration empirical sample. Pin percentiles
    /// AND threshold counts.
    func testPercentileSummaryChapter154Bimodal() {
        var samples: [Double] = []
        samples.append(contentsOf:
            Array(repeating: 1.05, count: 154))
        samples.append(contentsOf:
            Array(repeating: 1.85, count: 46))
        let s = BASDoctrinePercentileSummary.compute(
            samples, thresholds: [1.0, 1.5, 2.0])
        XCTAssertEqual(s.sampleCount, 200)
        XCTAssertEqual(s.min, 1.05)
        XCTAssertEqual(s.max, 1.85)
        // p25 (index Int(199*0.25)=49 → 1.05)
        XCTAssertEqual(s.p25, 1.05)
        // p75 (index Int(199*0.75)=149 → 1.05; 1.85 starts at 154)
        XCTAssertEqual(s.p75, 1.05)
        // p99 (index Int(199*0.99)=197 → 1.85)
        XCTAssertEqual(s.p99, 1.85)
        // ≥1.0: 200, ≥1.5: 46, ≥2.0: 0
        XCTAssertEqual(s.thresholdCounts, [200, 46, 0])
    }

    /// Codable round-trip preserves all fields.
    func testPercentileSummaryCodable() throws {
        let original = BASDoctrinePercentileSummary(
            sampleCount: 10,
            min: 0.1, p25: 0.3, median: 0.5,
            p75: 0.7, p99: 0.95, max: 1.0,
            thresholdCounts: [10, 5, 1])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASDoctrinePercentileSummary.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    /// Custom thresholds.
    func testPercentileSummaryCustomThresholds() {
        let s = BASDoctrinePercentileSummary.compute(
            [0.1, 0.2, 0.5, 0.8, 0.95],
            thresholds: [0.5, 0.9])
        XCTAssertEqual(s.thresholdCounts, [3, 1])
    }

    // MARK: - 18. M594 chapter 一百六十五 — Anti-magic-number constant pinning

    /// Pin percentile fraction constants to standard 25/50/75/99
    /// values. Regression guard against accidental drift.
    func testPercentileFractionConstants() {
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.percentileP25Fraction,
            0.25)
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.percentileP50Fraction,
            0.50)
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.percentileP75Fraction,
            0.75)
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.percentileP99Fraction,
            0.99)
    }

    /// Pin std-formula multiplier to 2.0.
    /// Derivation: max std for [0,1]-bounded var = 0.5
    /// (Bernoulli p=0.5). 2 × max std = 1.0 maps to stability=0.0.
    /// So multiplier = 1 / theoreticalMaxStd = 2.0.
    func testStdFormulaMultiplierPinned() {
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.stdFormulaMultiplier,
            2.0)
        // Derivation check: Bernoulli at p=0.5 produces std = 0.5
        // → stability = 1 - 2 * 0.5 = 0.0 (matches max-variation
        // semantic).
        let bernoulli: [Double] = [0.0, 1.0]
        let mean = 0.5
        let variance = bernoulli.map {
            pow($0 - mean, 2)
        }.reduce(0, +) / Double(bernoulli.count)
        let std = variance.squareRoot()
        XCTAssertEqual(std, 0.5, accuracy: 0.001)
        let stability = max(0, min(1, 1
            - BASDoctrineMetricsThreshold.stdFormulaMultiplier
            * std))
        XCTAssertEqual(stability, 0.0, accuracy: 0.001)
    }

    /// Pin anchor risk-sum thresholds.
    /// Chapter 一百五十四 calibration: substrate emits anchor risk
    /// sums in two clusters at ~1.05 and ~1.85; threshold 1.5
    /// (= humanAnchorErosionThreshold) cleanly discriminates.
    func testAnchorRiskSumThresholdsPinned() {
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.anchorRiskSumThresholds,
            [1.0, 1.5, 2.0])
        // Cross-reference: middle threshold matches
        // humanAnchorErosionThreshold (chapter 154 calibration).
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.anchorRiskSumThresholds[1],
            BASDoctrineMetricsCompute.humanAnchorErosionThreshold)
    }

    /// Pin multi-run variance interpretation thresholds.
    /// Chapter 一百六十四 empirical reading: ≤ 0.05 = stable;
    /// > 0.10 = N-dependent.
    func testVarianceInterpretationThresholdsPinned() {
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.stableSpreadThreshold,
            0.05)
        XCTAssertEqual(
            BASDoctrineMetricsThreshold.nDependentSpreadThreshold,
            0.10)
        // Sanity: stable threshold < N-dependent threshold.
        XCTAssertLessThan(
            BASDoctrineMetricsThreshold.stableSpreadThreshold,
            BASDoctrineMetricsThreshold
                .nDependentSpreadThreshold)
    }

    /// Pin: doctrineHarmonyPerTurn formula uses count/sample
    /// directly (no magic multipliers).
    func testHarmonyPerTurnFormulaSimple() {
        // 50/100 sample → 0.5 harmony (1 - 50/100)
        let h = BASDoctrineMetricsCompute
            .doctrineHarmonyPerTurn(
                metricID: "formula-pin",
                turnsWithAnyRedLine: 50,
                sampleCount: 100)
        XCTAssertEqual(h.harmonyScore, 0.5, accuracy: 0.001)
    }
}
