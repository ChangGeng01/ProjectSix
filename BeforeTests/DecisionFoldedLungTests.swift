import XCTest
import BASHostKit
// M86 — BASOrchestration is @_exported from BASHostKit.
@testable import Before

final class DecisionFoldedLungTests: XCTestCase {
    func testSovereignBridgeMapsToolCutAndRollbackToDeterministicLungActions() {
        let anchor = makeAnchor(breathMode: .guard)

        let result = DecisionFoldedLungSovereignBridge.apply(
            commands: [
                BASSovereignActuationCommand(
                    commandID: "tool-cut-1",
                    kind: .toolCut,
                    reasonCodes: ["risk.high"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_000)
                ),
                BASSovereignActuationCommand(
                    commandID: "rollback-1",
                    kind: .rollback,
                    reasonCodes: ["runtime.rollback"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_001),
                    forcedMode: .guard
                )
            ],
            anchor: anchor
        )

        XCTAssertEqual(result.actuationKinds, [.toolCut, .rollback])
        XCTAssertEqual(result.invalidatedResumeFrameIDs, ["resume-1"])
        XCTAssertEqual(result.invalidatedCacheRefs, ["cache-safe", "tool-intent:sess-1"])
        XCTAssertEqual(result.resultingBreathMode, .guard)
        XCTAssertTrue(result.preservedReadOnlyRecovery)
        XCTAssertTrue(result.summary.contains("toolCut"))
        XCTAssertTrue(result.summary.contains("rollback"))
    }

    func testSovereignBridgeMapsMemoryFreezeQuarantineAndDeadStopToSafetyReceipts() {
        let anchor = makeAnchor(breathMode: .structured)

        let result = DecisionFoldedLungSovereignBridge.apply(
            commands: [
                BASSovereignActuationCommand(
                    commandID: "memory-freeze-1",
                    kind: .memoryFreeze,
                    reasonCodes: ["runtime.write_freeze"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_010)
                ),
                BASSovereignActuationCommand(
                    commandID: "quarantine-1",
                    kind: .quarantine,
                    reasonCodes: ["runtime.quarantine"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_011)
                ),
                BASSovereignActuationCommand(
                    commandID: "dead-stop-1",
                    kind: .deadStop,
                    reasonCodes: ["runtime.dead_stop"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_012)
                )
            ],
            anchor: anchor
        )

        XCTAssertEqual(result.actuationKinds, [.memoryFreeze, .quarantine, .deadStop])
        XCTAssertEqual(result.invalidatedResumeFrameIDs, ["resume-1"])
        XCTAssertEqual(result.invalidatedCacheRefs, ["cache-safe", "memory-write:sess-1"])
        XCTAssertEqual(result.invalidatedFoldRefs, ["fold-1"])
        XCTAssertEqual(result.quarantinedFoldRefs, ["fold-1"])
        XCTAssertEqual(result.resultingBreathMode, .lockdown)
        XCTAssertTrue(result.preservedReadOnlyRecovery)
        XCTAssertTrue(result.summary.contains("memoryFreeze"))
        XCTAssertTrue(result.summary.contains("quarantine"))
        XCTAssertTrue(result.summary.contains("deadStop"))
        XCTAssertTrue(result.summary.contains("readonly recovery"))
    }

    func testSovereignBridgeThrottleDegradesDeepExchangeWithoutBreakingAnchor() {
        let anchor = makeAnchor(breathMode: .deepExchange)

        let result = DecisionFoldedLungSovereignBridge.apply(
            commands: [
                BASSovereignActuationCommand(
                    commandID: "throttle-1",
                    kind: .throttle,
                    reasonCodes: ["thermal.throttle"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_020)
                )
            ],
            anchor: anchor
        )

        XCTAssertEqual(result.actuationKinds, [.throttle])
        XCTAssertEqual(result.invalidatedResumeFrameIDs, [])
        XCTAssertEqual(result.invalidatedCacheRefs, [])
        XCTAssertEqual(result.invalidatedFoldRefs, [])
        XCTAssertEqual(result.quarantinedFoldRefs, [])
        XCTAssertEqual(result.resultingBreathMode, .structured)
        XCTAssertFalse(result.preservedReadOnlyRecovery)
        XCTAssertTrue(result.summary.contains("mode structured"))
    }

    func testSovereignBridgeGuardShiftRaisesBreathModeWithoutInvalidatingRecovery() {
        let anchor = makeAnchor(breathMode: .light)

        let result = DecisionFoldedLungSovereignBridge.apply(
            commands: [
                BASSovereignActuationCommand(
                    commandID: "guard-shift-1",
                    kind: .guardShift,
                    reasonCodes: ["risk.high"],
                    issuedAt: Date(timeIntervalSince1970: 1_776_000_030)
                )
            ],
            anchor: anchor
        )

        XCTAssertEqual(result.actuationKinds, [.guardShift])
        XCTAssertEqual(result.invalidatedResumeFrameIDs, [])
        XCTAssertEqual(result.invalidatedCacheRefs, [])
        XCTAssertEqual(result.invalidatedFoldRefs, [])
        XCTAssertEqual(result.quarantinedFoldRefs, [])
        XCTAssertEqual(result.resultingBreathMode, .guard)
        XCTAssertFalse(result.preservedReadOnlyRecovery)
    }

    func testSnapshotFromAnchorDerivesMorphGraphAndPrecisionProfileFromPersistedLungState() throws {
        let anchor = DecisionSessionCheckpointEBrainAnchor(
            sessionID: "sess-1",
            thoughtFoldChecksum: "fold-1",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 61,
            reviewDirectiveLine: "Review persisted runtime policy",
            lungState: BASLungState(
                breathMode: .guard,
                breathPhase: .resume,
                thermalPressure: 68,
                cachePressure: 44,
                restoreReadiness: 0.89,
                rollbackAnchorRef: "anchor-safe"
            ),
            breathScheduler: BASBreathSchedulerFrame(
                schedulerID: "scheduler-safe",
                cadenceTag: "guard_resume",
                checkpointCadence: "anchor_each_turn",
                microSleepWindowMs: 180,
                backgroundMaintenanceWindowMs: 0,
                allowsBackgroundMaintenance: false,
                allowsMicroSleep: true,
                resumeBudgetClass: "rollback_hot",
                schedulerReasonCodes: ["risk_guard", "restore_ready"]
            ),
            resumeFrame: BASResumeFrame(
                resumeID: "resume-1",
                sourceFoldID: "fold-1",
                resumeDepth: 1,
                requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                consistencyChecks: ["fold_checksum", "risk_permit"],
                fallbackMode: .rollbackAnchor
            ),
            rollbackAnchor: BASRollbackAnchor(
                anchorID: "anchor-safe",
                safeSnapshotRef: "snapshot-safe",
                foldRefs: ["fold-1"],
                hostVersionRef: "host.v1",
                cacheStateRef: "cache-safe",
                integrityHash: "hash-safe"
            )
        )

        let snapshot = try XCTUnwrap(DecisionFoldedLungCoordinator.snapshot(from: anchor))

        XCTAssertEqual(snapshot.morphGraph.graphID, "morph.sess-1.fold-1")
        XCTAssertEqual(
            snapshot.morphGraph.activeOrgans,
            [BASNeuralOrgan.riskSpine, .permitKnot, .stubCore]
        )
        XCTAssertEqual(snapshot.morphGraph.executionOrder, ["riskSpine", "permitKnot", "stubCore"])
        XCTAssertEqual(snapshot.morphGraph.deviceRouteMap["riskSpine"], "checkpoint")
        XCTAssertEqual(snapshot.morphGraph.thermalProfile, ["checkpoint-recovery"])
        XCTAssertEqual(
            snapshot.hotColdMap.hotOrgans,
            [BASNeuralOrgan.stubCore, .riskSpine, .permitKnot]
        )
        XCTAssertEqual(
            snapshot.hotColdMap.warmOrgans,
            [BASNeuralOrgan.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        )
        XCTAssertTrue(snapshot.hotColdMap.coldOrgans.contains(BASNeuralOrgan.simuRing))
        XCTAssertEqual(snapshot.hotColdMap.preloadPolicy, "guard_preload")
        XCTAssertEqual(snapshot.hotColdMap.evictionPolicy, "protective_retain")
        XCTAssertTrue(snapshot.hotColdLine.contains("Hot pack"))
        XCTAssertEqual(snapshot.organPackages.count, 12)
        XCTAssertEqual(
            snapshot.organPackageLine,
            "Organ packages 12 • hot 3 • warm 3 • cold 6 • protected 3 • recovery 2"
        )
        XCTAssertTrue(snapshot.layerStackLine.contains("L3 compression runtime"))
        XCTAssertTrue(snapshot.layerStackLine.contains("anchor anchor-safe"))
        XCTAssertNil(snapshot.sovereignBridgeResult)
        XCTAssertNil(snapshot.sovereignBridgeLine)
        XCTAssertTrue(snapshot.sovereignBridgeDetailLines.isEmpty)
        XCTAssertEqual(snapshot.precisionProfile.organPrecisions, [
            BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
            BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected),
            BASNeuralOrganPrecision(organ: .stubCore, tier: .full)
        ])
        XCTAssertEqual(
            snapshot.precisionProfile.lockedPrecisions,
            [BASNeuralOrgan.riskSpine, .permitKnot, .stubCore]
        )
        XCTAssertEqual(snapshot.precisionProfile.guardSafeFloor, BASNeuralPrecisionTier.protected)
        XCTAssertEqual(snapshot.resumeFrame.resumeID, "resume-1")
        XCTAssertEqual(snapshot.breathScheduler.schedulerID, "scheduler-safe")
        XCTAssertEqual(snapshot.breathScheduler.cadenceTag, "guard_resume")
        XCTAssertEqual(snapshot.breathScheduler.checkpointCadence, "anchor_each_turn")
        XCTAssertEqual(snapshot.breathScheduler.microSleepWindowMs, 180)
        XCTAssertEqual(snapshot.breathScheduler.resumeBudgetClass, "rollback_hot")
        XCTAssertTrue(snapshot.schedulerLine.contains("guard_resume"))
        XCTAssertEqual(snapshot.integrityWeave.purityState, "verified")
        XCTAssertEqual(snapshot.integrityWeave.requiredChecks, ["fold_checksum", "host_gate", "rollback_anchor"])
        XCTAssertEqual(snapshot.integrityWeave.completedChecks, ["fold_checksum", "host_gate", "rollback_anchor"])
        XCTAssertTrue(snapshot.integrityWeave.failedChecks.isEmpty)
        XCTAssertTrue(snapshot.integrityWeave.contaminationRefs.isEmpty)
        XCTAssertEqual(snapshot.integrityWeave.trustedSnapshotRef, "snapshot-safe")
        XCTAssertEqual(snapshot.integrityWeave.verificationHash, "hash-safe")
        XCTAssertTrue(snapshot.integrityWeaveLine.contains("Integrity weave verified"))
        XCTAssertEqual(snapshot.rollbackAnchor.anchorID, "anchor-safe")
        XCTAssertTrue(snapshot.rollbackLine.contains("anchor-safe"))
        XCTAssertEqual(snapshot.thermalExchange.exchangeID, "thermal.sess-1.fold-1")
        XCTAssertEqual(snapshot.thermalExchange.exchangeMode, "balanced_exchange")
        XCTAssertEqual(snapshot.thermalExchange.predictedThermalBand, "warm")
        XCTAssertEqual(snapshot.thermalExchange.coolingActions, ["delay_cold_organs"])
        XCTAssertEqual(snapshot.thermalExchange.suppressedOrgans, [BASNeuralOrgan.criticBlade])
        XCTAssertTrue(snapshot.thermalExchange.rerouteTargets.isEmpty)
        XCTAssertTrue(snapshot.thermalExchange.precisionDowngradePlan.isEmpty)
        XCTAssertEqual(
            snapshot.thermalExchange.exchangeReasonCodes,
            ["mode.guard", "thermal.warm", "guard.watch", "band.warm"]
        )
        XCTAssertTrue(snapshot.thermalExchangeLine.contains("balanced_exchange"))
    }

    func testSnapshotFromAnchorPrefersPersistedOrganPackagesAndOrganDeltaPlan() throws {
        let persistedPackages = [
            BASOrganPackage(
                packageID: "package.stubcore.hot",
                organType: .stubCore,
                sizeMB: 18,
                precisionOptions: [.full, .protected],
                loadTimeMs: 10,
                thermalCost: 8,
                sovereignClass: "protected_core"
            ),
            BASOrganPackage(
                packageID: "package.memorycodecridge.warm",
                organType: .memoryCodecRidge,
                sizeMB: 14,
                precisionOptions: [.balanced, .minimal],
                loadTimeMs: 18,
                thermalCost: 9,
                sovereignClass: "checkpoint_recovery"
            )
        ]
        let persistedPlan = BASOrganDeltaPlan(
            planID: "plan-persisted",
            deltaMode: "rollback_retain",
            activatePackageIDs: ["package.stubcore.hot"],
            preloadPackageIDs: ["package.memorycodecridge.warm"],
            evictPackageIDs: [],
            retainPackageIDs: ["package.stubcore.hot", "package.memorycodecridge.warm"],
            rollbackSafeRetainedPackageIDs: ["package.stubcore.hot", "package.memorycodecridge.warm"],
            triggeredActuationKinds: [.rollback],
            reasonCodes: ["runtime.rollback"]
        )
        let anchor = DecisionSessionCheckpointEBrainAnchor(
            sessionID: "sess-persisted",
            thoughtFoldChecksum: "fold-persisted",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 72,
            reviewDirectiveLine: "Review persisted packages",
            lungState: BASLungState(
                breathMode: .guard,
                breathPhase: .resume,
                thermalPressure: 65,
                cachePressure: 41,
                restoreReadiness: 0.88,
                rollbackAnchorRef: "anchor-persisted"
            ),
            organPackages: persistedPackages,
            organDeltaPlan: persistedPlan,
            resumeFrame: BASResumeFrame(
                resumeID: "resume-persisted",
                sourceFoldID: "fold-persisted",
                resumeDepth: 1,
                requiredOrgans: [.stubCore, .memoryCodecRidge],
                consistencyChecks: ["fold_checksum"],
                fallbackMode: .rollbackAnchor
            ),
            rollbackAnchor: BASRollbackAnchor(
                anchorID: "anchor-persisted",
                safeSnapshotRef: "snapshot-persisted",
                foldRefs: ["fold-persisted"],
                hostVersionRef: "host.v2",
                cacheStateRef: "cache-persisted",
                integrityHash: "hash-persisted"
            )
        )

        let snapshot = try XCTUnwrap(DecisionFoldedLungCoordinator.snapshot(from: anchor))

        XCTAssertEqual(snapshot.organPackages, persistedPackages)
        XCTAssertEqual(snapshot.organDeltaPlan, persistedPlan)
        XCTAssertEqual(
            snapshot.organPackageLine,
            "Organ packages 2 • hot 1 • warm 1 • cold 0 • protected 1 • recovery 1"
        )
        XCTAssertEqual(snapshot.organDeltaLine, persistedPlan.decisionOrganDeltaLine)
    }

    func testSnapshotFromAnchorEnrichesPackageLevelSovereignReceipts() throws {
        let anchor = DecisionSessionCheckpointEBrainAnchor(
            sessionID: "sess-1",
            thoughtFoldChecksum: "fold-1",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 61,
            reviewDirectiveLine: "Review protective path: delay",
            lungState: BASLungState(
                breathMode: .guard,
                breathPhase: .resume,
                thermalPressure: 68,
                cachePressure: 44,
                restoreReadiness: 0.89,
                rollbackAnchorRef: "anchor-safe"
            ),
            breathScheduler: BASBreathSchedulerFrame(
                schedulerID: "scheduler-safe",
                cadenceTag: "checkpoint_resume",
                checkpointCadence: "anchor_on_restore",
                microSleepWindowMs: 120,
                backgroundMaintenanceWindowMs: 0,
                allowsBackgroundMaintenance: false,
                allowsMicroSleep: true,
                resumeBudgetClass: "guarded_hot",
                schedulerReasonCodes: ["persisted_anchor"]
            ),
            resumeFrame: BASResumeFrame(
                resumeID: "resume-1",
                sourceFoldID: "fold-1",
                resumeDepth: 1,
                requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                consistencyChecks: ["fold_checksum", "risk_permit"],
                fallbackMode: .rollbackAnchor
            ),
            rollbackAnchor: BASRollbackAnchor(
                anchorID: "anchor-safe",
                safeSnapshotRef: "snapshot-safe",
                foldRefs: ["fold-1"],
                hostVersionRef: "host.v1",
                cacheStateRef: "cache-safe",
                integrityHash: "hash-safe"
            ),
            sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult(
                actuationKinds: [.toolCut, .rollback],
                invalidatedResumeFrameIDs: ["resume-1"],
                invalidatedCacheRefs: ["cache-safe", "tool-intent:sess-1"],
                invalidatedFoldRefs: ["fold-1"],
                quarantinedFoldRefs: [],
                resultingBreathMode: .guard,
                preservedReadOnlyRecovery: true,
                summary: "rollback -> snapshot-safe • guard breath"
            )
        )

        let snapshot = try XCTUnwrap(DecisionFoldedLungCoordinator.snapshot(from: anchor))
        let sovereignBridgeResult = try XCTUnwrap(snapshot.sovereignBridgeResult)

        XCTAssertEqual(sovereignBridgeResult.invalidatedPackageIDs, ["package.toolintentmesh.warm"])
        XCTAssertEqual(
            sovereignBridgeResult.rollbackRetainedPackageIDs,
            [
                "package.stubcore.hot",
                "package.riskspine.hot",
                "package.permitknot.hot",
                "package.memorycodecridge.warm",
                "package.consistencylattice.cold"
            ]
        )
        XCTAssertTrue(
            snapshot.sovereignBridgeDetailLines.contains(
                "Sovereign invalidated package package.toolintentmesh.warm"
            )
        )
        XCTAssertTrue(
            snapshot.sovereignBridgeDetailLines.contains(
                "Sovereign rollback retain package.stubcore.hot, package.riskspine.hot, package.permitknot.hot, package.memorycodecridge.warm, package.consistencylattice.cold"
            )
        )
    }

    private func makeAnchor(
        breathMode: BASBreathMode
    ) -> DecisionSessionCheckpointEBrainAnchor {
        DecisionSessionCheckpointEBrainAnchor(
            sessionID: "sess-1",
            thoughtFoldChecksum: "fold-1",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 61,
            reviewDirectiveLine: "Review protective path: delay",
            lungState: BASLungState(
                breathMode: breathMode,
                breathPhase: .resume,
                thermalPressure: 68,
                cachePressure: 44,
                restoreReadiness: 0.89,
                rollbackAnchorRef: "anchor-safe"
            ),
            breathScheduler: BASBreathSchedulerFrame(
                schedulerID: "scheduler-safe",
                cadenceTag: "checkpoint_resume",
                checkpointCadence: "anchor_on_restore",
                microSleepWindowMs: 120,
                backgroundMaintenanceWindowMs: 0,
                allowsBackgroundMaintenance: false,
                allowsMicroSleep: true,
                resumeBudgetClass: "guarded_hot",
                schedulerReasonCodes: ["persisted_anchor"]
            ),
            resumeFrame: BASResumeFrame(
                resumeID: "resume-1",
                sourceFoldID: "fold-1",
                resumeDepth: 1,
                requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                consistencyChecks: ["fold_checksum", "risk_permit"],
                fallbackMode: .rollbackAnchor
            ),
            rollbackAnchor: BASRollbackAnchor(
                anchorID: "anchor-safe",
                safeSnapshotRef: "snapshot-safe",
                foldRefs: ["fold-1"],
                hostVersionRef: "host.v1",
                cacheStateRef: "cache-safe",
                integrityHash: "hash-safe"
            )
        )
    }
}
