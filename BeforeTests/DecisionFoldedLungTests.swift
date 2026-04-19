import XCTest
import BASHostKit
import BASOrchestration
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
        XCTAssertEqual(snapshot.morphGraph.activeOrgans, [.riskSpine, .permitKnot, .stubCore])
        XCTAssertEqual(snapshot.morphGraph.executionOrder, ["riskSpine", "permitKnot", "stubCore"])
        XCTAssertEqual(snapshot.morphGraph.deviceRouteMap["riskSpine"], "checkpoint")
        XCTAssertEqual(snapshot.morphGraph.thermalProfile, ["checkpoint-recovery"])
        XCTAssertEqual(snapshot.hotColdMap.hotOrgans, [.stubCore, .riskSpine, .permitKnot])
        XCTAssertEqual(
            snapshot.hotColdMap.warmOrgans,
            [.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        )
        XCTAssertTrue(snapshot.hotColdMap.coldOrgans.contains(.simuRing))
        XCTAssertEqual(snapshot.hotColdMap.preloadPolicy, "guard_preload")
        XCTAssertEqual(snapshot.hotColdMap.evictionPolicy, "protective_retain")
        XCTAssertTrue(snapshot.hotColdLine.contains("Hot pack"))
        XCTAssertEqual(snapshot.precisionProfile.organPrecisions, [
            BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
            BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected),
            BASNeuralOrganPrecision(organ: .stubCore, tier: .full)
        ])
        XCTAssertEqual(snapshot.precisionProfile.lockedPrecisions, [.riskSpine, .permitKnot, .stubCore])
        XCTAssertEqual(snapshot.precisionProfile.guardSafeFloor, .protected)
        XCTAssertEqual(snapshot.resumeFrame.resumeID, "resume-1")
        XCTAssertEqual(snapshot.breathScheduler.schedulerID, "scheduler-safe")
        XCTAssertEqual(snapshot.breathScheduler.cadenceTag, "guard_resume")
        XCTAssertEqual(snapshot.breathScheduler.checkpointCadence, "anchor_each_turn")
        XCTAssertEqual(snapshot.breathScheduler.microSleepWindowMs, 180)
        XCTAssertEqual(snapshot.breathScheduler.resumeBudgetClass, "rollback_hot")
        XCTAssertTrue(snapshot.schedulerLine.contains("guard_resume"))
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
