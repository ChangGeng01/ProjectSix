import XCTest
@testable import BASOrchestration

/// Tests for M64 — L2 神经器官层 main-chain load-bearing observation
/// derivation. Mirrors M55 / M56 / M57 / M58 / M59 / M60 / M61 /
/// M62 / M63 coverage: shape classification, per-subject signal
/// iteration, shape precedence, determinism, thought-frame helper,
/// content encoding, budget, Codable, ledger, helpers.
final class BASNeuralOrganObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let turnID = "t-n64"
    private let sessionID = "s-n64"
    private let at = Date(timeIntervalSince1970: 1_700_000_000)

    private func map(
        morph: BASNeuralMorph = .engage,
        activeOrgans: [BASNeuralOrgan] = [.coreCortex, .scoutStrip],
        precisionMap: [BASNeuralOrganPrecision] = [],
        routingPolicy: BASNeuralRoutingPolicy =
            .conversationalBalance,
        leaseRef: String? = nil,
        sovereignConstraints: [String] = [],
        headGuarantees: [String] = []
    ) -> BASNeuralOrganMap {
        BASNeuralOrganMap(
            morph: morph,
            activeOrgans: activeOrgans,
            precisionMap: precisionMap,
            routingPolicy: routingPolicy,
            leaseRef: leaseRef,
            sovereignConstraints: sovereignConstraints,
            headGuarantees: headGuarantees
        )
    }

    private func precision(
        _ organ: BASNeuralOrgan,
        _ tier: BASNeuralPrecisionTier
    ) -> BASNeuralOrganPrecision {
        BASNeuralOrganPrecision(organ: organ, tier: tier)
    }

    private func derive(
        _ m: BASNeuralOrganMap?
    ) -> BASNeuralOrganObservationBundle {
        BASNeuralOrganObservationBundle.derive(
            fromOrganMap: m,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: at
        )
    }

    // MARK: - Path 1: nil map

    func testNilMapProducesEmptyBundle() {
        let bundle = derive(nil)
        XCTAssertEqual(bundle.turnID, turnID)
        XCTAssertEqual(bundle.sessionID, sessionID)
        XCTAssertEqual(bundle.emittedAt, at)
        XCTAssertTrue(bundle.observations.isEmpty)
        XCTAssertFalse(bundle.hasMapSealed)
        XCTAssertFalse(bundle.hasAnyOrganSignal)
        XCTAssertFalse(bundle.hasAnyPrecisionSignal)
        XCTAssertFalse(bundle.hasRoutingPolicy)
        XCTAssertFalse(bundle.hasAnySovereignConstraint)
        XCTAssertFalse(bundle.hasAnyHeadGuarantee)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
    }

    // MARK: - Path 2: minimal map (just morph + routing + organs)

    func testMinimalMapEmitsBaselineAndRouting() {
        let bundle = derive(map(
            morph: .engage,
            activeOrgans: [.coreCortex],
            routingPolicy: .conversationalBalance
        ))
        XCTAssertTrue(bundle.hasMapSealed)
        XCTAssertTrue(bundle.hasAnyOrganSignal)
        XCTAssertFalse(bundle.hasAnyPrecisionSignal)
        XCTAssertTrue(bundle.hasRoutingPolicy)
        XCTAssertFalse(bundle.hasAnySovereignConstraint)
        XCTAssertFalse(bundle.hasAnyHeadGuarantee)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
    }

    // MARK: - Path 3: baseline subject + salience

    func testBaselineSubjectIsMorphRawValue() {
        let bundle = derive(map(
            morph: .compare,
            activeOrgans: [.coreCortex]
        ))
        let baseline = bundle.observations(of: .organMapSealed)
        XCTAssertEqual(baseline.count, 1)
        XCTAssertEqual(baseline.first?.subjectID, "compare")
    }

    // MARK: - Path 4: per-organ iteration in array order

    func testOrganActiveIteratesInArrayOrder() {
        let organs: [BASNeuralOrgan] = [
            .scoutStrip,
            .coreCortex,
            .simuRing,
            .criticBlade
        ]
        let bundle = derive(map(activeOrgans: organs))
        let actives = bundle.observations(of: .organActive)
        XCTAssertEqual(actives.count, 4)
        XCTAssertEqual(
            actives.map(\.subjectID),
            organs.map(\.rawValue))
    }

    // MARK: - Path 5: precision iteration in array order

    func testPrecisionSetIteratesInArrayOrder() {
        let plan = [
            precision(.coreCortex, .full),
            precision(.scoutStrip, .balanced),
            precision(.riskSpine, .protected)
        ]
        let bundle = derive(map(precisionMap: plan))
        let precisions = bundle.observations(of: .precisionSet)
        XCTAssertEqual(precisions.count, 3)
        XCTAssertEqual(
            precisions.map(\.subjectID),
            ["coreCortex", "scoutStrip", "riskSpine"])
        // Salience scales with tier — full > protected > balanced >
        // minimal.
        XCTAssertEqual(precisions[0].salience, 0.75, accuracy: 0.001)
        XCTAssertEqual(precisions[1].salience, 0.45, accuracy: 0.001)
        XCTAssertEqual(precisions[2].salience, 0.65, accuracy: 0.001)
    }

    func testPrecisionSalienceForMinimalTier() throws {
        let plan = [precision(.stubCore, .minimal)]
        let bundle = derive(map(precisionMap: plan))
        let minimal = try XCTUnwrap(
            bundle.observations(of: .precisionSet).first)
        XCTAssertEqual(minimal.salience, 0.30, accuracy: 0.001)
    }

    // MARK: - Path 6: routing policy always fires with map

    func testRoutingPolicyAlwaysEmittedWhenMapPresent() {
        let bundle = derive(map(
            routingPolicy: .quarantineIsolation
        ))
        let route = bundle.observations(of: .routingPolicyApplied)
        XCTAssertEqual(route.count, 1)
        XCTAssertEqual(route.first?.subjectID, "quarantineIsolation")
    }

    // MARK: - Path 7: sovereign constraints (skip empty/whitespace)

    func testSovereignConstraintsIterateAndSkipEmpty() {
        let bundle = derive(map(
            sovereignConstraints: [
                "morph_locked",
                "   ",
                "",
                "no_network",
                "  with_trim  "
            ]
        ))
        let constraints = bundle
            .observations(of: .sovereignConstraintActive)
        XCTAssertEqual(constraints.count, 3)
        XCTAssertEqual(
            constraints.map(\.subjectID),
            ["morph_locked", "no_network", "with_trim"])
    }

    // MARK: - Path 8: head guarantees (skip empty/whitespace)

    func testHeadGuaranteesIterateAndSkipEmpty() {
        let bundle = derive(map(
            headGuarantees: [
                "no_unauthorized_writes",
                "  ",
                "",
                "permit_required"
            ]
        ))
        let guarantees = bundle
            .observations(of: .headGuaranteeActive)
        XCTAssertEqual(guarantees.count, 2)
        XCTAssertEqual(
            guarantees.map(\.subjectID),
            ["no_unauthorized_writes", "permit_required"])
    }

    // MARK: - Path 9: shape precedence (quarantine > everything)

    func testShapeQuarantineOverridesAllOthers() {
        let bundle = derive(map(morph: .quarantine))
        XCTAssertTrue(bundle.observations
            .allSatisfy { $0.shape == .quarantined })
    }

    // MARK: - Path 10: shape precedence — rollbackRebuild > stub

    func testShapeRebuildingBeatsStub() {
        let bundle = derive(map(morph: .rollbackRebuild))
        XCTAssertTrue(bundle.observations
            .allSatisfy { $0.shape == .rebuilding })
    }

    // MARK: - Path 11: shape — stub

    func testShapeStubOnly() {
        let bundle = derive(map(morph: .stub))
        XCTAssertTrue(bundle.observations
            .allSatisfy { $0.shape == .stubOnly })
    }

    // MARK: - Path 12: shape — guard

    func testShapeGuarded() {
        let bundle = derive(map(morph: .guard))
        XCTAssertTrue(bundle.observations
            .allSatisfy { $0.shape == .guarded })
    }

    // MARK: - Path 13: shape — quiet (normal forward morphs)

    func testShapeQuietForForwardMorphs() {
        for morph: BASNeuralMorph in [
            .scout, .engage, .compare, .deepLoop
        ] {
            let bundle = derive(map(morph: morph))
            XCTAssertTrue(
                bundle.observations
                    .allSatisfy { $0.shape == .quiet },
                "morph \(morph.rawValue) should map to .quiet")
        }
    }

    // MARK: - Path 14: determinism

    func testDeterministicOnRepeatedInput() {
        let m = map(
            morph: .engage,
            activeOrgans: [.coreCortex, .scoutStrip],
            precisionMap: [precision(.coreCortex, .full)],
            sovereignConstraints: ["morph_locked"],
            headGuarantees: ["permit_required"])
        let a = derive(m)
        let b = derive(m)
        XCTAssertEqual(a, b)
    }

    // MARK: - Path 15: thought-frame helper (with + nil)

    func testWithDerivedPopulatesFieldFromFrameOrganMap() {
        let frame = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d",
            organMap: map(
                activeOrgans: [.coreCortex, .scoutStrip]
            ),
            stabilityScore: 0.5
        )
        let enriched = frame
            .withDerivedNeuralOrganObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: at)
        XCTAssertNotNil(enriched.neuralOrganObservationBundle)
        XCTAssertEqual(
            enriched.neuralOrganObservationBundle?
                .observations(of: .organActive).count,
            2)
        XCTAssertEqual(frame.stepIndex, enriched.stepIndex)
        XCTAssertEqual(
            frame.decomposeRef, enriched.decomposeRef)
        XCTAssertEqual(
            frame.stabilityScore, enriched.stabilityScore)
    }

    func testWithDerivedOnNilOrganMapProducesEmptyBundle() {
        let frame = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d",
            stabilityScore: 0.5)
        XCTAssertNil(frame.organMap)
        let enriched = frame
            .withDerivedNeuralOrganObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: at)
        XCTAssertNotNil(enriched.neuralOrganObservationBundle)
        XCTAssertTrue(enriched.neuralOrganObservationBundle?
            .observations.isEmpty ?? false)
    }

    // MARK: - Path 16: content encoding

    func testBaselineContentEncodesCounts() {
        let bundle = derive(map(
            morph: .compare,
            activeOrgans: [.coreCortex, .scoutStrip],
            precisionMap: [precision(.coreCortex, .full)],
            sovereignConstraints: ["locked"],
            headGuarantees: ["permit_required"]
        ))
        let base = bundle.observations(of: .organMapSealed).first
        XCTAssertNotNil(base)
        let c = base!.content
        XCTAssertTrue(c.contains("l2.organmap.sealed"))
        XCTAssertTrue(c.contains("morph:compare"))
        XCTAssertTrue(c.contains("organs:2"))
        XCTAssertTrue(c.contains("precisions:1"))
        XCTAssertTrue(c.contains("constraints:1"))
        XCTAssertTrue(c.contains("guarantees:1"))
    }

    func testOrganActiveContentCarriesMorph() {
        let bundle = derive(map(
            morph: .engage,
            activeOrgans: [.coreCortex]
        ))
        let organ = bundle.observations(of: .organActive).first
        XCTAssertNotNil(organ)
        let c = organ!.content
        XCTAssertTrue(c.contains("l2.organ.active:coreCortex"))
        XCTAssertTrue(c.contains("morph:engage"))
    }

    func testPrecisionContentCarriesTier() {
        let bundle = derive(map(
            precisionMap: [precision(.riskSpine, .protected)]
        ))
        let p = bundle.observations(of: .precisionSet).first
        XCTAssertNotNil(p)
        let c = p!.content
        XCTAssertTrue(c.contains("l2.precision.set:riskSpine"))
        XCTAssertTrue(c.contains("tier:protected"))
    }

    func testRoutingContentCarriesMorph() {
        let bundle = derive(map(
            morph: .compare,
            routingPolicy: .comparativeFanout
        ))
        let r = bundle.observations(of: .routingPolicyApplied).first
        XCTAssertNotNil(r)
        let c = r!.content
        XCTAssertTrue(c.contains(
            "l2.routing.applied:comparativeFanout"))
        XCTAssertTrue(c.contains("morph:compare"))
    }

    func testConstraintContentCarriesMorph() {
        let bundle = derive(map(
            morph: .`guard`,
            sovereignConstraints: ["no_tools"]
        ))
        let cobs = bundle
            .observations(of: .sovereignConstraintActive).first
        XCTAssertNotNil(cobs)
        let c = cobs!.content
        XCTAssertTrue(c.contains("l2.sovereign.constraint:no_tools"))
        XCTAssertTrue(c.contains("morph:guard"))
    }

    func testGuaranteeContentCarriesMorph() {
        let bundle = derive(map(
            morph: .engage,
            headGuarantees: ["permit_required"]
        ))
        let g = bundle
            .observations(of: .headGuaranteeActive).first
        XCTAssertNotNil(g)
        let c = g!.content
        XCTAssertTrue(c.contains(
            "l2.head.guarantee:permit_required"))
        XCTAssertTrue(c.contains("morph:engage"))
    }

    // MARK: - Path 17: emission order

    func testEmissionOrderBaselineOrgansPrecisionRoutingConstraintsGuarantees() {
        let bundle = derive(map(
            morph: .engage,
            activeOrgans: [.coreCortex, .scoutStrip],
            precisionMap: [precision(.coreCortex, .full)],
            routingPolicy: .conversationalBalance,
            sovereignConstraints: ["locked"],
            headGuarantees: ["permit_required"]
        ))
        let kinds = bundle.observations.map(\.kind)
        XCTAssertEqual(kinds, [
            .organMapSealed,
            .organActive,
            .organActive,
            .precisionSet,
            .routingPolicyApplied,
            .sovereignConstraintActive,
            .headGuaranteeActive
        ])
    }

    // MARK: - Path 18: budget sum + clamp

    func testBudgetTotalSumsAcrossKinds() {
        let bundle = derive(map(
            morph: .engage,
            activeOrgans: [.coreCortex, .scoutStrip],
            precisionMap: [precision(.coreCortex, .full)],
            sovereignConstraints: ["x"],
            headGuarantees: ["y"]
        ))
        let total = BASNeuralOrganSignalBudget.totalCost(
            for: bundle)
        // baseline 0.05 + 2 × 0.04 + 1 × 0.04 + 1 × 0.04 +
        //   1 × 0.12 + 1 × 0.10 = 0.43
        XCTAssertEqual(total, 0.43, accuracy: 0.001)
    }

    func testBudgetClampedAtOne() {
        let organs: [BASNeuralOrgan] = Array(repeating: .coreCortex,
            count: 30)
        let constraints = (0..<30).map { "c\($0)" }
        let bundle = derive(map(
            activeOrgans: organs,
            sovereignConstraints: constraints
        ))
        let total = BASNeuralOrganSignalBudget.totalCost(
            for: bundle)
        XCTAssertLessThanOrEqual(total, 1.0)
        XCTAssertGreaterThan(total, 0.9)
    }

    func testBudgetPerKindCost() {
        XCTAssertEqual(
            BASNeuralOrganSignalBudget.cost(for: .organMapSealed),
            0.05,
            accuracy: 0.001)
        XCTAssertEqual(
            BASNeuralOrganSignalBudget.cost(for: .organActive),
            0.04,
            accuracy: 0.001)
        XCTAssertEqual(
            BASNeuralOrganSignalBudget.cost(for: .precisionSet),
            0.04,
            accuracy: 0.001)
        XCTAssertEqual(
            BASNeuralOrganSignalBudget.cost(
                for: .routingPolicyApplied),
            0.04,
            accuracy: 0.001)
        XCTAssertEqual(
            BASNeuralOrganSignalBudget.cost(
                for: .sovereignConstraintActive),
            0.12,
            accuracy: 0.001)
        XCTAssertEqual(
            BASNeuralOrganSignalBudget.cost(
                for: .headGuaranteeActive),
            0.10,
            accuracy: 0.001)
    }

    // MARK: - Path 19: Codable round-trip (bundle)

    func testCodableRoundTripBundle() throws {
        let bundle = derive(map(
            morph: .engage,
            activeOrgans: [.coreCortex, .scoutStrip],
            precisionMap: [precision(.coreCortex, .full)],
            sovereignConstraints: ["locked"],
            headGuarantees: ["permit_required"]
        ))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        let decoded = try decoder.decode(
            BASNeuralOrganObservationBundle.self, from: data)
        XCTAssertEqual(bundle, decoded)
    }

    // MARK: - Path 20: Codable round-trip (frame-embedded)

    func testCodableRoundTripFrame() throws {
        let frame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "d",
            organMap: map(
                morph: .engage,
                activeOrgans: [.coreCortex]
            ),
            stabilityScore: 0.3
        ).withDerivedNeuralOrganObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: at)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(frame)
        let decoded = try decoder.decode(
            BASThoughtFrame.self, from: data)
        XCTAssertEqual(
            frame.neuralOrganObservationBundle,
            decoded.neuralOrganObservationBundle)
    }

    // MARK: - Path 21: Ledger record + filters

    func testLedgerRecordsAndFilters() async {
        let ledger = BASNeuralOrganObservationLedger(
            capacity: 4)
        let b1 = BASNeuralOrganObservationBundle(
            turnID: "t1",
            sessionID: "sA",
            observations: [],
            emittedAt: at)
        let b2 = BASNeuralOrganObservationBundle(
            turnID: "t2",
            sessionID: "sB",
            observations: [],
            emittedAt: at)
        let b3 = BASNeuralOrganObservationBundle(
            turnID: "t3",
            sessionID: "sA",
            observations: [],
            emittedAt: at)
        await ledger.record(b1)
        await ledger.record(b2)
        await ledger.record(b3)
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 3)
        let sA = await ledger.bundles(forSession: "sA")
        XCTAssertEqual(sA.count, 2)
        let byTurn = await ledger.bundle(forTurn: "t2")
        XCTAssertEqual(byTurn?.sessionID, "sB")
        let count = await ledger.count()
        XCTAssertEqual(count, 3)
        await ledger.clear()
        let empty = await ledger.snapshot()
        XCTAssertEqual(empty.count, 0)
    }

    func testLedgerRingBufferEvictsOldest() async {
        let ledger = BASNeuralOrganObservationLedger(
            capacity: 2)
        for i in 0..<5 {
            let b = BASNeuralOrganObservationBundle(
                turnID: "t\(i)",
                sessionID: "s",
                observations: [],
                emittedAt: at)
            await ledger.record(b)
        }
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 2)
        XCTAssertEqual(snap.map(\.turnID), ["t3", "t4"])
    }

    // MARK: - Path 22: helper — observations(forShape:)

    func testObservationsForShapeFiltersCorrectly() {
        let bundle = derive(map(morph: .guard,
            activeOrgans: [.coreCortex]))
        let guarded = bundle.observations(forShape: .guarded)
        XCTAssertEqual(guarded.count, bundle.observations.count)
        let quiet = bundle.observations(forShape: .quiet)
        XCTAssertTrue(quiet.isEmpty)
    }

    // MARK: - Path 23: helper — observations(forSubject:)

    func testObservationsForSubjectFiltersCorrectly() {
        let bundle = derive(map(
            morph: .engage,
            activeOrgans: [.coreCortex, .scoutStrip],
            precisionMap: [precision(.coreCortex, .full)]
        ))
        let forCortex = bundle
            .observations(forSubject: "coreCortex")
        // one .organActive + one .precisionSet = 2
        XCTAssertEqual(forCortex.count, 2)
        let kinds = Set(forCortex.map(\.kind))
        XCTAssertTrue(kinds.contains(.organActive))
        XCTAssertTrue(kinds.contains(.precisionSet))
    }

    // MARK: - Path 24: helper — subjectIDs preserves first-seen order

    func testSubjectIDsFirstSeenOrderPreserved() {
        let bundle = derive(map(
            morph: .compare,
            activeOrgans: [.scoutStrip, .coreCortex, .simuRing],
            precisionMap: [
                precision(.coreCortex, .full),
                precision(.scoutStrip, .balanced)
            ],
            routingPolicy: .comparativeFanout,
            sovereignConstraints: ["locked"],
            headGuarantees: ["permit_required"]
        ))
        let subjects = bundle.subjectIDs
        // Expected first-seen order: morph (compare), then organs,
        // then precisions (already-seen cortex/scout skip), then
        // routing policy, then constraint, then guarantee.
        XCTAssertEqual(subjects[0], "compare")
        XCTAssertEqual(subjects[1], "scoutStrip")
        XCTAssertEqual(subjects[2], "coreCortex")
        XCTAssertEqual(subjects[3], "simuRing")
        XCTAssertEqual(subjects[4], "comparativeFanout")
        XCTAssertEqual(subjects[5], "locked")
        XCTAssertEqual(subjects[6], "permit_required")
    }

    // MARK: - Path 25: empty activeOrgans + empty precisionMap

    func testEmptyOrgansAndPrecisionEmitsOnlyBaselineAndRouting() {
        let bundle = derive(map(
            activeOrgans: [],
            precisionMap: []
        ))
        XCTAssertTrue(bundle.hasMapSealed)
        XCTAssertTrue(bundle.hasRoutingPolicy)
        XCTAssertFalse(bundle.hasAnyOrganSignal)
        XCTAssertFalse(bundle.hasAnyPrecisionSignal)
        XCTAssertEqual(bundle.observations.count, 2)
    }

    // MARK: - Path 26: routing policy variants

    func testRoutingPolicyVariantsSurfaceSubjectID() {
        for policy: BASNeuralRoutingPolicy in [
            .scoutProbe,
            .conversationalBalance,
            .comparativeFanout,
            .deepLoopConvergence,
            .protectiveThrottle,
            .quarantineIsolation,
            .rollbackRecovery,
            .stubOnly
        ] {
            let bundle = derive(map(routingPolicy: policy))
            let r = bundle
                .observations(of: .routingPolicyApplied).first
            XCTAssertEqual(r?.subjectID, policy.rawValue)
        }
    }
}
