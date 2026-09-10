import XCTest
@testable import BASOrchestration

/// M54 — L7 mirror-blade main-chain wiring.
///
/// The M23 per-signal decomposition observation primitives (shape
/// covered by `BASDecompositionObservationTests`) were originally
/// emitted only by hand-crafted test helpers; the coordinator never
/// produced a bundle at all. These tests pin the main-chain behavior:
///
///   1. `BASDecompositionObservationBundle.derive(from:turnID:
///      sessionID:emittedAt:)` emits a bundle whose contents
///      deterministically mirror the decompose frame's records
///      (same frame → same bundle byte-for-byte).
///   2. Each of the six signal kinds (.factShard / .unknown /
///      .contradiction / .pressure / .manipulation / .mirrorDraft) is
///      emitted iff the frame carries structural evidence for it.
///      An empty frame produces zero observations.
///   3. Signal payloads (salience / confidence / content) are computed
///      from the frame's records — no magic constants smuggled in.
///   4. `BASDecomposeFrame.withDerivedDecompositionObservationBundle
///      (...)` returns a copy with the bundle attached and leaves
///      every other field untouched.
///   5. The bundle feeds the M32 `.mirrorBlade` coverage projection.
///   6. Budget stays clamped in [0, 1] even when all six signal kinds
///      are emitted simultaneously.
///   7. Legacy pre-M54 frames (persisted without the new key) decode
///      with `decompositionObservationBundle == nil`.
final class BASDecompositionObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a decompose frame with only the records that callers
    /// explicitly populate — no auto-derived defaults. This lets each
    /// test isolate exactly which signal kinds should be emitted.
    private func frame(
        factShards: [BASFactShard] = [],
        unknownRecords: [BASUnknownRecord] = [],
        contradictionRecords: [BASContradictionRecord] = [],
        pressureVectors: [BASPressureVector] = [],
        manipulationPatterns: [BASManipulationPattern] = [],
        mirrorDraft: BASMirrorDraft? = nil
    ) -> BASDecomposeFrame {
        // Passing the typed records AND empty string arrays bypasses
        // the auto-derivation that `BASDecomposeFrame.init(...)` runs
        // when a legacy string field is empty. This way tests can
        // control the record arrays exactly.
        BASDecomposeFrame(
            facts: factShards.map(\.text),
            unknowns: unknownRecords.map(\.summary),
            contradictions: contradictionRecords.map(\.summary),
            pressureSignals: pressureVectors.map { $0.kind.rawValue },
            manipulationSignals: manipulationPatterns.map {
                $0.kind.rawValue
            },
            mirrorText: mirrorDraft?.summary ?? "",
            factShards: factShards,
            unknownRecords: unknownRecords,
            contradictionRecords: contradictionRecords,
            pressureVectors: pressureVectors,
            manipulationPatterns: manipulationPatterns,
            mirrorDraft: mirrorDraft)
    }

    private func factShard(
        id: String = "f1",
        text: String = "fact",
        certainty: Double = 0.8
    ) -> BASFactShard {
        BASFactShard(
            shardID: id,
            text: text,
            status: .reported,
            sourceKind: .systemInference,
            certainty: certainty)
    }

    private func unknown(
        id: String = "u1",
        blocking: Bool = true
    ) -> BASUnknownRecord {
        BASUnknownRecord(
            unknownID: id,
            kind: .missingFact,
            summary: "u-\(id)",
            sourceKind: .systemInference,
            blocking: blocking)
    }

    private func contradiction(
        id: String = "c1",
        severity: Double = 0.7,
        unresolved: Bool = true
    ) -> BASContradictionRecord {
        BASContradictionRecord(
            nodeID: id,
            kind: .textual,
            summary: "c-\(id)",
            severity: severity,
            unresolved: unresolved)
    }

    private func pressure(
        id: String = "p1",
        strength: Double = 0.6,
        authenticity: Double = 0.5
    ) -> BASPressureVector {
        BASPressureVector(
            vectorID: id,
            kind: .time,
            direction: .compressing,
            strength: strength,
            authenticity: authenticity,
            sourceRef: "src")
    }

    private func manipulation(
        id: String = "m1",
        confidence: Double = 0.7
    ) -> BASManipulationPattern {
        BASManipulationPattern(
            patternID: id,
            kind: .coerciveUrgency,
            summary: "m-\(id)",
            confidence: confidence)
    }

    private func mirrorDraft(
        mode: BASMirrorMode = .soft,
        summary: String = "mirror",
        calibrationPoints: [String] = [],
        toneGuard: String = "calibration_only"
    ) -> BASMirrorDraft {
        BASMirrorDraft(
            draftID: "d1",
            mode: mode,
            summary: summary,
            calibrationPoints: calibrationPoints,
            toneGuard: toneGuard)
    }

    // MARK: - 1. Emission

    func testDeriveEmitsZeroObservationsOnTrulyEmptyFrame() {
        // A frame with no records at all must produce an empty bundle
        // — this is the "light turn" invariant M23 promises.
        let f = BASDecomposeFrame()
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: fixedDate)

        XCTAssertTrue(bundle.observations.isEmpty)
        XCTAssertEqual(bundle.turnID, "t-1")
        XCTAssertEqual(bundle.sessionID, "s-1")
        XCTAssertEqual(bundle.emittedAt, fixedDate)
    }

    func testDeriveEmitsFactShardSignalOnlyWhenShardsPresent() {
        let f = frame(factShards: [factShard()])
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, [.factShard])
    }

    func testDeriveEmitsUnknownSignalOnlyWhenRecordsPresent() {
        let f = frame(unknownRecords: [unknown()])
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, [.unknown])
    }

    func testDeriveEmitsContradictionSignalOnlyWhenRecordsPresent() {
        let f = frame(contradictionRecords: [contradiction()])
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, [.contradiction])
    }

    func testDeriveEmitsPressureSignalOnlyWhenVectorsPresent() {
        let f = frame(pressureVectors: [pressure()])
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, [.pressure])
    }

    func testDeriveEmitsManipulationSignalOnlyWhenPatternsPresent() {
        let f = frame(manipulationPatterns: [manipulation()])
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, [.manipulation])
    }

    func testDeriveEmitsMirrorDraftSignalOnlyWhenDraftPresent() {
        let f = frame(mirrorDraft: mirrorDraft())
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, [.mirrorDraft])
    }

    func testDeriveEmitsAllSixSignalsWhenFrameIsFull() {
        let f = frame(
            factShards: [factShard()],
            unknownRecords: [unknown()],
            contradictionRecords: [contradiction()],
            pressureVectors: [pressure()],
            manipulationPatterns: [manipulation()],
            mirrorDraft: mirrorDraft())
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let kinds = Set(bundle.observations.map { $0.kind })
        XCTAssertEqual(kinds, Set(BASDecompositionSignalKind.allCases))
    }

    // MARK: - 2. Determinism

    func testDeriveIsDeterministicForSameFrame() {
        let f = frame(
            factShards: [factShard(), factShard(id: "f2")],
            contradictionRecords: [contradiction()],
            mirrorDraft: mirrorDraft())
        let a = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let b = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(a, b)
    }

    // MARK: - 3. Payload fidelity

    func testFactShardSalienceScalesWithCountAndConfidenceIsMean()
        throws
    {
        let f = frame(factShards: [
            factShard(id: "a", certainty: 0.2),
            factShard(id: "b", certainty: 0.8)
        ])
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let fs = try XCTUnwrap(
            bundle.dominantObservation(of: .factShard))
        // 2 * 0.15 = 0.3
        XCTAssertEqual(fs.salience, 0.3, accuracy: 1e-9)
        // (0.2 + 0.8) / 2 = 0.5
        XCTAssertEqual(fs.confidence, 0.5, accuracy: 1e-9)
    }

    func testFactShardSalienceSaturatesAtOne() throws {
        // 10 * 0.15 = 1.5 — must clamp to 1.0.
        let shards = (0..<10).map {
            factShard(id: "f-\($0)", certainty: 0.9)
        }
        let f = frame(factShards: shards)
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let fs = try XCTUnwrap(
            bundle.dominantObservation(of: .factShard))
        XCTAssertEqual(fs.salience, 1.0, accuracy: 1e-9)
    }

    func testUnknownConfidenceIsFractionBlocking() throws {
        let records = [
            unknown(id: "u1", blocking: true),
            unknown(id: "u2", blocking: false),
            unknown(id: "u3", blocking: true),
            unknown(id: "u4", blocking: false)
        ]
        let f = frame(unknownRecords: records)
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let u = try XCTUnwrap(
            bundle.dominantObservation(of: .unknown))
        // 4 * 0.25 = 1.0
        XCTAssertEqual(u.salience, 1.0, accuracy: 1e-9)
        // 2 blocking / 4 total = 0.5
        XCTAssertEqual(u.confidence, 0.5, accuracy: 1e-9)
    }

    func testContradictionSalienceIsMaxSeverity() throws {
        let records = [
            contradiction(id: "c1", severity: 0.3, unresolved: true),
            contradiction(id: "c2", severity: 0.9, unresolved: false),
            contradiction(id: "c3", severity: 0.6, unresolved: true)
        ]
        let f = frame(contradictionRecords: records)
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let c = try XCTUnwrap(
            bundle.dominantObservation(of: .contradiction))
        XCTAssertEqual(c.salience, 0.9, accuracy: 1e-9)
        // 2 unresolved / 3 total = 0.6666...
        XCTAssertEqual(
            c.confidence,
            2.0 / 3.0,
            accuracy: 1e-9)
    }

    func testPressureSalienceIsMaxStrengthAndConfidenceIsMeanAuth()
        throws
    {
        let vectors = [
            pressure(id: "p1", strength: 0.2, authenticity: 0.4),
            pressure(id: "p2", strength: 0.7, authenticity: 0.8)
        ]
        let f = frame(pressureVectors: vectors)
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let p = try XCTUnwrap(
            bundle.dominantObservation(of: .pressure))
        XCTAssertEqual(p.salience, 0.7, accuracy: 1e-9)
        // (0.4 + 0.8) / 2 = 0.6
        XCTAssertEqual(p.confidence, 0.6, accuracy: 1e-9)
    }

    func testManipulationSalienceIsMaxPatternConfidence() throws {
        let patterns = [
            manipulation(id: "m1", confidence: 0.3),
            manipulation(id: "m2", confidence: 0.85),
            manipulation(id: "m3", confidence: 0.5)
        ]
        let f = frame(manipulationPatterns: patterns)
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let m = try XCTUnwrap(
            bundle.dominantObservation(of: .manipulation))
        XCTAssertEqual(m.salience, 0.85, accuracy: 1e-9)
        // 3 * 0.33 = 0.99
        XCTAssertEqual(m.confidence, 0.99, accuracy: 1e-9)
    }

    func testManipulationConfidenceSaturatesAtOne() throws {
        // 4+ patterns → count*0.33 >= 1.32, clamps to 1.0.
        let patterns = (0..<4).map {
            manipulation(id: "m-\($0)", confidence: 0.5)
        }
        let f = frame(manipulationPatterns: patterns)
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let m = try XCTUnwrap(
            bundle.dominantObservation(of: .manipulation))
        XCTAssertEqual(m.confidence, 1.0, accuracy: 1e-9)
    }

    func testMirrorDraftSalienceTracksMode() throws {
        let modes: [(BASMirrorMode, Double)] = [
            (.silent, 0.3),
            (.soft, 0.6),
            (.hard, 0.8)
        ]
        for (mode, expected) in modes {
            let f = frame(mirrorDraft: mirrorDraft(mode: mode))
            let bundle = BASDecompositionObservationBundle.derive(
                from: f,
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)
            let d = try XCTUnwrap(
                bundle.dominantObservation(of: .mirrorDraft))
            XCTAssertEqual(
                d.salience,
                expected,
                accuracy: 1e-9,
                "mode \(mode) should have salience \(expected)")
        }
    }

    func testMirrorDraftConfidenceReflectsCalibrationPoints() throws {
        let noCalibration = frame(
            mirrorDraft: mirrorDraft(calibrationPoints: []))
        let withCalibration = frame(
            mirrorDraft: mirrorDraft(
                calibrationPoints: ["point-1", "point-2"]))

        let noBundle = BASDecompositionObservationBundle.derive(
            from: noCalibration,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let withBundle = BASDecompositionObservationBundle.derive(
            from: withCalibration,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let d1 = try XCTUnwrap(
            noBundle.dominantObservation(of: .mirrorDraft))
        let d2 = try XCTUnwrap(
            withBundle.dominantObservation(of: .mirrorDraft))
        XCTAssertEqual(d1.confidence, 0.5, accuracy: 1e-9)
        XCTAssertEqual(d2.confidence, 0.8, accuracy: 1e-9)
    }

    // MARK: - 4. Withhelper contract

    func testWithDerivedBundleAttachesBundleOnCopy() {
        let f = frame(factShards: [factShard()])
        let enriched = f.withDerivedDecompositionObservationBundle(
            turnID: "t-2",
            sessionID: "s-2",
            emittedAt: fixedDate)

        XCTAssertNil(f.decompositionObservationBundle)
        XCTAssertNotNil(enriched.decompositionObservationBundle)
        XCTAssertEqual(
            enriched.decompositionObservationBundle?.turnID, "t-2")
        XCTAssertEqual(
            enriched.decompositionObservationBundle?.sessionID, "s-2")
    }

    func testWithDerivedBundlePreservesEveryOtherField() {
        let f = frame(
            factShards: [factShard(certainty: 0.7)],
            unknownRecords: [unknown(blocking: true)],
            contradictionRecords: [contradiction(severity: 0.8)],
            pressureVectors: [pressure(strength: 0.5)],
            manipulationPatterns: [manipulation(confidence: 0.6)],
            mirrorDraft: mirrorDraft(mode: .hard))

        let enriched = f.withDerivedDecompositionObservationBundle(
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(enriched.factShards, f.factShards)
        XCTAssertEqual(enriched.unknownRecords, f.unknownRecords)
        XCTAssertEqual(
            enriched.contradictionRecords, f.contradictionRecords)
        XCTAssertEqual(enriched.pressureVectors, f.pressureVectors)
        XCTAssertEqual(
            enriched.manipulationPatterns, f.manipulationPatterns)
        XCTAssertEqual(enriched.mirrorDraft, f.mirrorDraft)
        XCTAssertEqual(enriched.canonicalFrame, f.canonicalFrame)
        XCTAssertEqual(enriched.facts, f.facts)
        XCTAssertEqual(enriched.schemaVersion, f.schemaVersion)
    }

    // MARK: - 5. M32 coverage projection integration

    func testBundleFeedsM32MirrorBladeCoverageProjection() {
        let f = frame(
            factShards: [factShard()],
            contradictionRecords: [contradiction()],
            mirrorDraft: mirrorDraft())
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "turn-xyz",
            sessionID: "session-xyz",
            emittedAt: fixedDate)

        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.layer, .mirrorBlade)
        XCTAssertEqual(summary.turnID, "turn-xyz")
        XCTAssertEqual(summary.sessionID, "session-xyz")
        // factShard + contradiction + mirrorDraft = 3 distinct kinds.
        XCTAssertEqual(summary.distinctSubjectCount, 3)
        XCTAssertTrue(summary.hasCoreSignalCoverage)
    }

    func testCoreCoverageRequiresFactContradictionAndMirror() {
        // Mirror + facts but no contradiction → fails core coverage.
        let f = frame(
            factShards: [factShard()],
            mirrorDraft: mirrorDraft())
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertFalse(bundle.coverageSummary.hasCoreSignalCoverage)
    }

    // MARK: - 6. Budget clamping

    func testBundleBudgetStaysClampedAcrossAllSixSignals() {
        let f = frame(
            factShards: [factShard()],
            unknownRecords: [unknown()],
            contradictionRecords: [contradiction()],
            pressureVectors: [pressure()],
            manipulationPatterns: [manipulation()],
            mirrorDraft: mirrorDraft())
        let bundle = BASDecompositionObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        // Raw sum = 0.10 + 0.15 + 0.25 + 0.20 + 0.30 + 0.35 = 1.35
        // Must clamp to 1.0.
        let cost = BASDecompositionObservationBudget
            .totalCost(for: bundle)
        XCTAssertEqual(cost, 1.0, accuracy: 1e-9)
    }

    // MARK: - 7. Backwards compatibility

    func testDecomposeFrameNilBundleRoundTripsThroughCodable() throws {
        let f = frame()
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(
            BASDecomposeFrame.self, from: data)
        XCTAssertNil(decoded.decompositionObservationBundle)
    }

    func testDecomposeFrameWithBundleRoundTripsThroughCodable()
        throws
    {
        let enriched = frame(
            factShards: [factShard()],
            contradictionRecords: [contradiction()],
            mirrorDraft: mirrorDraft())
            .withDerivedDecompositionObservationBundle(
                turnID: "rt",
                sessionID: "rt-s",
                emittedAt: fixedDate)

        let data = try JSONEncoder().encode(enriched)
        let decoded = try JSONDecoder().decode(
            BASDecomposeFrame.self, from: data)

        XCTAssertNotNil(decoded.decompositionObservationBundle)
        XCTAssertEqual(
            decoded.decompositionObservationBundle?.turnID, "rt")
        XCTAssertEqual(
            decoded.decompositionObservationBundle?.observations.count,
            enriched.decompositionObservationBundle?
                .observations.count)
    }

    func testLegacyJSONWithoutBundleFieldDecodesWithNilBundle()
        throws
    {
        // Simulates a persisted pre-M54 frame that lacks the new key.
        let legacy = """
        {
          "schemaVersion": "1.1.0",
          "facts": [],
          "goals": [],
          "emotions": [],
          "unknowns": [],
          "contradictions": [],
          "pressureSignals": [],
          "manipulationSignals": [],
          "mirrorText": "",
          "factShards": [],
          "claimShards": [],
          "unknownRecords": [],
          "contradictionRecords": [],
          "pressureVectors": [],
          "manipulationPatterns": [],
          "boundaryTouches": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(
            BASDecomposeFrame.self, from: legacy)
        XCTAssertNil(decoded.decompositionObservationBundle)
        XCTAssertEqual(decoded.schemaVersion, "1.1.0")
    }
}
