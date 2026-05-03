import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

/// M444 (chapter 一百十七) — drift-detector + parity-lock tests
/// for the Cthulhu layer projection helpers across L1+L3+L4+L7+L8.
final class BASCthulhuLayerProjectionsTests: XCTestCase {

    // MARK: - L1 — BASAbyssalRunMode mapping

    /// Pin the full case-mapping table from BASEBrainRunMode (10
    /// cases) → BASAbyssalRunMode (6 cases).
    func testAbyssalRunModeMappingTable() {
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .dormant),
            .tideSurface)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .pulse),
            .tideSurface)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .sentinel),
            .nearShore)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .engage),
            .deepDive)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .reflect),
            .deepDive)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .deepLoop),
            .stormGuard)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .`guard`),
            .stormGuard)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .recovery),
            .sealedHarbor)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .quarantine),
            .sealedHarbor)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssalRunMode.derive(from: .lockdown),
            .sunkenSeal)
    }

    /// Anti-drift: every BASEBrainRunMode case must map to some
    /// BASAbyssalRunMode (total function).
    func testAbyssalRunModeMappingIsTotal() {
        for runMode in BASEBrainRunMode.allCases {
            // If derive is total, it returns without crashing.
            // We just call it; success = no crash.
            _ = BASCthulhuLayerProjections.AbyssalRunMode.derive(
                from: runMode)
        }
    }

    // MARK: - L1 — BASAbyssBudget projection

    func testAbyssBudgetDerivesFromBudgetFrame() {
        let frame = makeBudgetFrame(
            maxLoops: 6,
            thermalGuardLevel: .nominal,
            maintenanceClass: .standard,
            leaseID: "lease-1")
        let abyss = BASCthulhuLayerProjections.AbyssBudget.derive(
            from: frame, turnID: "turn-x")
        XCTAssertEqual(abyss.budgetID, "abyss-budget:turn-x")
        XCTAssertEqual(abyss.deepDiveQuota, 0.5, accuracy: 0.001)
        XCTAssertEqual(abyss.anomalyTolerance, 1.0, accuracy: 0.001)
        XCTAssertEqual(abyss.safeSurfaceFloor, 0.66, accuracy: 0.001)
        XCTAssertEqual(abyss.sovereignReserve, 1.0)
    }

    func testAbyssBudgetClampsAtSaturationCeiling() {
        let frame = makeBudgetFrame(
            maxLoops: 100,
            thermalGuardLevel: .emergency,
            maintenanceClass: .none,
            leaseID: nil)
        let abyss = BASCthulhuLayerProjections.AbyssBudget.derive(
            from: frame, turnID: "saturated")
        XCTAssertEqual(abyss.deepDiveQuota, 1.0,
                       "maxLoops 100 should saturate to 1.0")
        XCTAssertEqual(abyss.anomalyTolerance, 0.0)
        XCTAssertEqual(abyss.safeSurfaceFloor, 0.0)
        XCTAssertEqual(abyss.sovereignReserve, 0.0,
                       "no leaseID = no sovereign reserve")
    }

    // MARK: - L3 — BASAbyssFoldLayer mapping

    func testAbyssFoldLayerMapping() {
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssFoldLayer.derive(
                from: .minimal),
            .surfaceFold)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssFoldLayer.derive(
                from: .balanced),
            .midFold)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssFoldLayer.derive(
                from: .protected),
            .deepFold)
        XCTAssertEqual(
            BASCthulhuLayerProjections.AbyssFoldLayer.derive(
                from: .full),
            .abyssalFold)
    }

    /// Anti-drift: every precision profile case must map.
    func testAbyssFoldLayerMappingIsTotal() {
        for profile in BASRuntimePrecisionProfile.allCases {
            _ = BASCthulhuLayerProjections.AbyssFoldLayer.derive(
                from: profile)
        }
    }

    // MARK: - L3 — BASFoldRecoveryState mapping

    func testFoldRecoveryStateMapping() {
        XCTAssertEqual(
            BASCthulhuLayerProjections.FoldRecoveryState.derive(
                from: .quarantine),
            .sealBound)
        XCTAssertEqual(
            BASCthulhuLayerProjections.FoldRecoveryState.derive(
                from: .lockdown),
            .purged)
        XCTAssertEqual(
            BASCthulhuLayerProjections.FoldRecoveryState.derive(
                from: .recovery),
            .abyssFold)
        XCTAssertEqual(
            BASCthulhuLayerProjections.FoldRecoveryState.derive(
                from: .engage),
            .abyssFold,
            "non-special run modes default to .abyssFold")
    }

    // MARK: - L8 — BASMemoryTemperatureLayer mapping

    func testMemoryTemperatureLayerMapping() {
        XCTAssertEqual(
            BASCthulhuLayerProjections.MemoryTemperatureLayer
                .derive(from: .dormant),
            .tideSurfaceMemory)
        XCTAssertEqual(
            BASCthulhuLayerProjections.MemoryTemperatureLayer
                .derive(from: .engage),
            .midLayerMemory)
        XCTAssertEqual(
            BASCthulhuLayerProjections.MemoryTemperatureLayer
                .derive(from: .deepLoop),
            .deepWellMemory)
        XCTAssertEqual(
            BASCthulhuLayerProjections.MemoryTemperatureLayer
                .derive(from: .quarantine),
            .abyssalMemory)
        XCTAssertEqual(
            BASCthulhuLayerProjections.MemoryTemperatureLayer
                .derive(from: .lockdown),
            .oldSealMemory)
    }

    // MARK: - L4 — BASCosmicScaleView projection

    func testCosmicScaleViewDerivation() {
        let frame = makeBudgetFrame(
            maxLoops: 10,
            thermalGuardLevel: .nominal,
            maintenanceClass: .none,
            leaseID: nil,
            maxCandidates: 12,
            retrievalDepth: 7)
        let view = BASCthulhuLayerProjections.CosmicScaleView.derive(
            from: frame, turnID: "t1", observedSubjectRef: "subject-1")
        XCTAssertEqual(view.scaleID, "cosmic-scale:t1")
        XCTAssertEqual(view.observedSubjectRef, "subject-1")
        XCTAssertEqual(view.temporalHorizon, .temporalDeep)
        XCTAssertEqual(view.spatialHorizon, .spatialCosmic)
        XCTAssertEqual(view.agenticHorizonScale, 1.0, accuracy: 0.001)
        XCTAssertTrue(view.consequenceDilutionWarning,
                      "high horizons should trigger dilution warning")
    }

    func testCosmicScaleViewDilutionWarningThreshold() {
        // Low horizons → no dilution warning.
        let frame = makeBudgetFrame(
            maxLoops: 1,
            thermalGuardLevel: .nominal,
            maintenanceClass: .none,
            leaseID: nil,
            maxCandidates: 1,
            retrievalDepth: 1)
        let view = BASCthulhuLayerProjections.CosmicScaleView.derive(
            from: frame, turnID: "low", observedSubjectRef: "x")
        XCTAssertEqual(view.temporalHorizon, .temporalShort)
        XCTAssertEqual(view.spatialHorizon, .spatialLocal)
        XCTAssertFalse(view.consequenceDilutionWarning)
    }

    // MARK: - L4 — BASTemporalDepthMap projection

    func testTemporalDepthMapDerivation() {
        let frame = makeBudgetFrame(
            maxLoops: 5,
            thermalGuardLevel: .nominal,
            maintenanceClass: .none,
            leaseID: nil,
            retrievalDepth: 4)
        let map = BASCthulhuLayerProjections.TemporalDepthMap.derive(
            from: frame, turnID: "td")
        XCTAssertEqual(map.mapID, "temporal-depth:td")
        XCTAssertEqual(map.sedimentLayers.count, 4)
        XCTAssertEqual(map.observationWindow, "depth:4")
        XCTAssertEqual(map.timelineRefs, [])
        XCTAssertEqual(map.nonSimultaneityMarks, [])
    }

    // MARK: - L4 — BASOntologyFog projection

    func testOntologyFogProjectionFromAssertionCeiling() {
        let fog = BASCthulhuLayerProjections.OntologyFog.derive(
            unknownRefs: ["unknown-1", "unknown-2"],
            assertionCeilingRawValue: "none",
            turnID: "fog-1")
        XCTAssertEqual(fog.partialGraspQuality, .unnameable)
        XCTAssertEqual(fog.unnameableMarks.count, 2)
        XCTAssertEqual(fog.fogRegions, ["unknown-1", "unknown-2"])
    }

    func testOntologyFogProjectionForUnrestricted() {
        let fog = BASCthulhuLayerProjections.OntologyFog.derive(
            unknownRefs: ["unknown-3"],
            assertionCeilingRawValue: "unrestricted",
            turnID: "fog-2")
        XCTAssertEqual(fog.partialGraspQuality, .partialGrasp)
        XCTAssertTrue(fog.unnameableMarks.isEmpty,
                      "partial grasp should not yet emit unnameable marks")
    }

    // MARK: - L7 — BASOntologyShiftMark projection

    func testOntologyShiftMarkAxesProjection() {
        let distortion = BASNarrativeDistortion(
            distortionID: "d-1",
            realityDenial: 0.9,
            historyRewrite: 0.1,
            forcedClosure: 0.6,
            roleInversion: 0.05,
            urgencyMask: 0.8,
            confidence: 0.7)
        let mark = BASCthulhuLayerProjections.OntologyShiftMark.derive(
            from: distortion, turnID: "shift-1",
            targetSubjectRef: "subject-x")
        XCTAssertEqual(mark.markID, "ontology-shift:shift-1")
        // realityDenial > 0.5 → causality
        // forcedClosure > 0.5 → intent
        // urgencyMask > 0.5 → relation
        XCTAssertTrue(mark.observedShiftAxes.contains(.causality))
        XCTAssertTrue(mark.observedShiftAxes.contains(.intent))
        XCTAssertTrue(mark.observedShiftAxes.contains(.relation))
        XCTAssertFalse(mark.observedShiftAxes.contains(.narrative))
        XCTAssertFalse(mark.observedShiftAxes.contains(.power))
        XCTAssertEqual(mark.shiftConfidence, 0.7, accuracy: 0.01)
    }

    func testOntologyShiftMarkEmptyAxesWhenAllBelowThreshold() {
        let distortion = BASNarrativeDistortion(
            distortionID: "d-2",
            realityDenial: 0.1,
            historyRewrite: 0.1,
            forcedClosure: 0.1,
            roleInversion: 0.1,
            urgencyMask: 0.1,
            confidence: 0.5)
        let mark = BASCthulhuLayerProjections.OntologyShiftMark.derive(
            from: distortion, turnID: "shift-low",
            targetSubjectRef: "subject-y")
        XCTAssertTrue(mark.observedShiftAxes.isEmpty)
    }

    // MARK: - clamp01 helper

    func testClamp01() {
        XCTAssertEqual(BASCthulhuLayerProjections.clamp01(-0.5), 0.0)
        XCTAssertEqual(BASCthulhuLayerProjections.clamp01(0.5), 0.5)
        XCTAssertEqual(BASCthulhuLayerProjections.clamp01(1.5), 1.0)
    }

    // MARK: - Anti-magic-number doctrine pins

    func testNamedConstantsAreStable() {
        XCTAssertEqual(
            BASCthulhuLayerProjections.maxLoopsSaturationCeiling, 12)
        XCTAssertEqual(
            BASCthulhuLayerProjections.retrievalDepthSaturationCeiling, 8)
        XCTAssertEqual(
            BASCthulhuLayerProjections.maxCandidatesSaturationCeiling, 12)
        XCTAssertEqual(
            BASCthulhuLayerProjections.cosmicDilutionThreshold, 0.66,
            accuracy: 0.001)
        XCTAssertEqual(
            BASCthulhuLayerProjections.ontologyShiftAxisThreshold, 0.5,
            accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeBudgetFrame(
        maxLoops: Int,
        thermalGuardLevel: BASThermalGuardLevel,
        maintenanceClass: BASMaintenanceClass,
        leaseID: String?,
        maxCandidates: Int = 4,
        retrievalDepth: Int = 4
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: maxLoops,
            maxCandidates: maxCandidates,
            maxDecodeTokens: 256,
            retrievalDepth: retrievalDepth,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: true,
            leaseID: leaseID,
            leaseExpiresAt: nil,
            maintenanceClass: maintenanceClass)
    }
}
