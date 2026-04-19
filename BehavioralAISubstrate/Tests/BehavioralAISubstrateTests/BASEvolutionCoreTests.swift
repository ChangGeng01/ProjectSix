import XCTest
@testable import BASMemory

final class BASEvolutionCoreTests: XCTestCase {
    func testLineageSummaryBackfillsSchemaVersionWhenDecodingLegacyPayload() throws {
        let legacyJSON = """
        {
          "recordedAt": 1715000000,
          "sessionID": "legacy-session",
          "taskType": "decision",
          "riskLevel": "high",
          "permitMode": "delay",
          "hostGatePercent": 78,
          "thoughtFoldChecksum": "fold-legacy",
          "updateTicketSummaries": ["legacy ticket"],
          "guardrailFindings": ["legacy guardrail"],
          "recommendedKillSwitches": ["disableHighRiskAutoAction"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let summary = try decoder.decode(BASEvolutionLineageSummary.self, from: legacyJSON)

        XCTAssertEqual(summary.schemaVersion, BASEvolutionLineageSummary.currentSchemaVersion)
        XCTAssertEqual(summary.activeKillSwitches, [])
        XCTAssertEqual(summary.recommendedKillSwitches, ["disableHighRiskAutoAction"])
    }

    func testCheckpointPlannerDeduplicatesEquivalentLatestState() {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let input = BASEvolutionCheckpointInput(
            modeName: " primary ",
            sourceID: "launch",
            fingerprint: "fp-1",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable
        )
        let latest = BASEvolutionCheckpointStoredFields(
            id: "latest",
            createdAt: now,
            fingerprint: "fp-1",
            previousCheckpointID: nil,
            modeName: "primary",
            sourceID: "launch",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: ["noop"],
            approvalState: .automatic,
            rollbackReady: true
        )

        XCTAssertTrue(BASEvolutionCheckpointPlanner.shouldDeduplicate(latest: latest, input: input))
    }

    func testCheckpointPlannerBuildsReviewCheckpointAndRetainsNewestFreshEntries() {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let previous = BASEvolutionCheckpointStoredFields(
            id: "older",
            createdAt: now.addingTimeInterval(-60),
            fingerprint: "fp-0",
            previousCheckpointID: nil,
            modeName: "reflective",
            sourceID: "scene_active",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: ["older"],
            approvalState: .automatic,
            rollbackReady: true
        )
        let input = BASEvolutionCheckpointInput(
            modeName: "reflective",
            sourceID: "scene_active",
            fingerprint: "fp-1",
            identityRole: .reflectiveWitness,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .drifting
        )

        let planned = BASEvolutionCheckpointPlanner.checkpointFields(
            id: "newer",
            createdAt: now,
            latest: previous,
            input: input
        )

        XCTAssertEqual(planned.previousCheckpointID, "older")
        XCTAssertEqual(planned.approvalState, .reviewSuggested)
        XCTAssertTrue(planned.diffSummary.contains(where: { $0.contains("Role shifted") }))
        XCTAssertTrue(planned.diffSummary.contains(where: { $0.contains("Boundary mode tightened") }))
        XCTAssertTrue(planned.diffSummary.contains(where: { $0.contains("Calibration state moved to drifting") }))

        let stale = BASEvolutionCheckpointStoredFields(
            id: "stale",
            createdAt: now.addingTimeInterval(-(BASEvolutionCheckpointPlanner.defaultRetentionInterval + 1)),
            fingerprint: "stale",
            previousCheckpointID: nil,
            modeName: "primary",
            sourceID: "launch",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: [],
            approvalState: .automatic,
            rollbackReady: true
        )

        let retained = BASEvolutionCheckpointPlanner.retainedCheckpointIDs(
            in: [stale, previous, planned],
            now: now,
            maxEntries: 2
        )

        XCTAssertEqual(retained, Set(["older", "newer"]))

        let state = BASEvolutionCheckpointPlanner.currentState(from: [stale, previous, planned])
        XCTAssertEqual(state.checkpointCount, 3)
        XCTAssertEqual(state.pendingReviewCount, 1)
        XCTAssertEqual(state.latestCheckpoint?.id, "newer")
    }

    func testCheckpointPlannerCarriesLineageSummaryIntoCurrentState() {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let lineage = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "session-1",
            taskType: "decision",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 78,
            thoughtFoldChecksum: "fold-123",
            updateTicketSummaries: ["review tonight state"],
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["high-risk direct answer downgraded"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"]
        )
        let input = BASEvolutionCheckpointInput(
            modeName: "reflective",
            sourceID: "scene_active",
            fingerprint: "fp-2",
            identityRole: .reflectiveWitness,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .stable,
            lineageSummary: lineage
        )

        let planned = BASEvolutionCheckpointPlanner.checkpointFields(
            id: "lineage",
            createdAt: now,
            latest: nil,
            input: input
        )
        let state = BASEvolutionCheckpointPlanner.currentState(from: [planned])

        XCTAssertEqual(planned.lineageSummary, lineage)
        XCTAssertEqual(state.latestCheckpoint?.lineageSummary, lineage)
    }

    func testLineageSummaryRoundTripsExtendedCheckpointFabricFacts() throws {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let summary = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "session-fabric",
            runMode: .guard,
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 84,
            thoughtFoldChecksum: "fold-fabric",
            updateTicketSummaries: ["Hold before promote"],
            reviewDirectiveLine: "Review host drift",
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["protective boundary held"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"],
            neuralMorphID: "morph.guard",
            activeOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
            headGuarantees: ["permit", "rollback"],
            frontierWidth: 3,
            bindingCount: 2,
            projectionLeadCandidateID: "cand-2",
            projectionCandidateCount: 2,
            projectionForecastCount: 2,
            projectionCritiqueCount: 1,
            degradedReasonCodes: ["thermal_guard"],
            contextSummary: BASEvolutionLineageSummary.ContextSummary(
                emotionalLoadPercent: 82,
                timePressurePercent: 74,
                relationPattern: "self",
                ambiguityPercent: 63,
                consequencePercent: 81,
                manipulationHintCount: 1
            ),
            cognitionSummary: BASEvolutionLineageSummary.CognitionSummary(
                factCount: 4,
                goalCount: 2,
                unknownCount: 1,
                contradictionCount: 0,
                memoryAtomCount: 3,
                candidateCount: 2,
                forecastCount: 2,
                critiqueCount: 1,
                stopReasonID: "candidate_stable"
            ),
            adjudicationSummary: BASEvolutionLineageSummary.AdjudicationSummary(
                triScoreCount: 3,
                vetoCount: 1,
                gsiPercent: 68,
                alternativeActionCount: 2,
                emergencyBrakeLevelID: "cooldown"
            ),
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                morphGraphID: "morph.guard",
                hotColdMapID: "hotcold.guard",
                precisionProfileID: "precision.guard",
                lungStateRef: "lung.guard",
                breathSchedulerID: "scheduler.guard",
                breathMode: "guard",
                breathPhase: "exchange",
                thermalPressure: 77,
                cachePressure: 41,
                restoreReadinessPercent: 84,
                resumeID: "resume.guard",
                sourceFoldID: "fold-fabric",
                resumeDepth: 2,
                requiredOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                consistencyChecks: ["fold_checksum", "risk_permit", "host_gate"],
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: "anchor.guard",
                safeSnapshotRef: "snapshot.guard",
                foldRefs: ["fold-fabric"],
                hostVersionRef: "host.v4",
                cacheStateRef: "cache.guard",
                integrityHash: "integrity.guard",
                sovereignActuationKinds: [.rollback, .memoryFreeze],
                invalidatedResumeFrameIDs: ["resume.guard"],
                invalidatedCacheRefs: ["cache.guard", "memory-write:session-fabric"],
                invalidatedFoldRefs: ["fold-fabric"],
                quarantinedFoldRefs: [],
                resultingBreathMode: "guard",
                preservedReadOnlyRecovery: true,
                sovereignBridgeSummary: "Sovereign bridge • rollback, memoryFreeze • mode guard",
                morphActiveOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                morphExecutionOrder: ["stubCore", "riskSpine", "permitKnot"],
                morphPrecisionRecords: [
                    .init(organID: "stubCore", tierID: "full"),
                    .init(organID: "riskSpine", tierID: "protected"),
                    .init(organID: "permitKnot", tierID: "protected")
                ],
                morphDeviceRouteMap: [
                    "stubCore": "coreNPU",
                    "riskSpine": "coreNPU",
                    "permitKnot": "scoutCPU"
                ],
                morphThermalProfile: ["thermal.hot", "cache.41"],
                morphSovereignConstraints: ["rollback", "memoryFreeze"],
                hotOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                warmOrganIDs: ["memoryCodecRidge", "hostModulationMesh"],
                coldOrganIDs: ["scoutStrip", "simuRing", "criticBlade"],
                hotColdPreloadPolicy: "guard_preload",
                hotColdEvictionPolicy: "protective_retain",
                schedulerCadenceTag: "guard_resume",
                schedulerCheckpointCadence: "anchor_each_turn",
                schedulerMicroSleepWindowMs: 180,
                schedulerBackgroundMaintenanceWindowMs: 45,
                schedulerAllowsBackgroundMaintenance: true,
                schedulerAllowsMicroSleep: true,
                schedulerResumeBudgetClass: "rollback_hot",
                schedulerReasonCodes: ["risk_guard", "restore_ready"],
                precisionOrganPrecisionRecords: [
                    .init(organID: "stubCore", tierID: "full"),
                    .init(organID: "riskSpine", tierID: "protected"),
                    .init(organID: "permitKnot", tierID: "protected")
                ],
                precisionLockedOrganIDs: ["riskSpine", "permitKnot", "stubCore"],
                precisionDegradationOrder: ["full", "protected", "balanced", "minimal"],
                precisionGuardSafeFloorID: "protected"
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let encoded = try encoder.encode(summary)
        let decoded = try decoder.decode(BASEvolutionLineageSummary.self, from: encoded)

        XCTAssertEqual(decoded.neuralMorphID, "morph.guard")
        XCTAssertEqual(decoded.activeOrganIDs, ["stubCore", "riskSpine", "permitKnot"])
        XCTAssertEqual(decoded.headGuarantees, ["permit", "rollback"])
        XCTAssertEqual(decoded.frontierWidth, 3)
        XCTAssertEqual(decoded.bindingCount, 2)
        XCTAssertEqual(decoded.projectionLeadCandidateID, "cand-2")
        XCTAssertEqual(decoded.projectionCandidateCount, 2)
        XCTAssertEqual(decoded.projectionForecastCount, 2)
        XCTAssertEqual(decoded.projectionCritiqueCount, 1)
        XCTAssertEqual(decoded.degradedReasonCodes, ["thermal_guard"])
        XCTAssertEqual(decoded.contextSummary?.relationPattern, "self")
        XCTAssertEqual(decoded.contextSummary?.manipulationHintCount, 1)
        XCTAssertEqual(decoded.cognitionSummary?.factCount, 4)
        XCTAssertEqual(decoded.cognitionSummary?.stopReasonID, "candidate_stable")
        XCTAssertEqual(decoded.adjudicationSummary?.vetoCount, 1)
        XCTAssertEqual(decoded.adjudicationSummary?.emergencyBrakeLevelID, "cooldown")
        XCTAssertEqual(decoded.foldedLungSummary?.breathMode, "guard")
        XCTAssertEqual(decoded.foldedLungSummary?.rollbackAnchorID, "anchor.guard")
        XCTAssertEqual(decoded.foldedLungSummary?.invalidatedCacheRefs, ["cache.guard", "memory-write:session-fabric"])
        XCTAssertEqual(decoded.foldedLungSummary?.preservedReadOnlyRecovery, true)
        XCTAssertEqual(decoded.foldedLungSummary?.morphExecutionOrder, ["stubCore", "riskSpine", "permitKnot"])
        XCTAssertEqual(decoded.foldedLungSummary?.morphDeviceRouteMap["permitKnot"], "scoutCPU")
        XCTAssertEqual(decoded.foldedLungSummary?.hotColdMapID, "hotcold.guard")
        XCTAssertEqual(decoded.foldedLungSummary?.hotOrganIDs, ["stubCore", "riskSpine", "permitKnot"])
        XCTAssertEqual(decoded.foldedLungSummary?.hotColdPreloadPolicy, "guard_preload")
        XCTAssertEqual(decoded.foldedLungSummary?.breathSchedulerID, "scheduler.guard")
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerCadenceTag, "guard_resume")
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerCheckpointCadence, "anchor_each_turn")
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerMicroSleepWindowMs, 180)
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerBackgroundMaintenanceWindowMs, 45)
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerAllowsBackgroundMaintenance, true)
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerAllowsMicroSleep, true)
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerResumeBudgetClass, "rollback_hot")
        XCTAssertEqual(decoded.foldedLungSummary?.schedulerReasonCodes, ["risk_guard", "restore_ready"])
        XCTAssertEqual(decoded.foldedLungSummary?.precisionGuardSafeFloorID, "protected")
    }
}
