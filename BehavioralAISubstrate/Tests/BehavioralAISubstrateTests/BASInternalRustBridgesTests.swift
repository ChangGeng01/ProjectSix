// MARK: - BASInternalRustBridgesTests
// post-chapter 七百七十三 / post-XCFramework-rebuild
//
// Cross-language verification for the 5 internal-crate Swift
// bridges activated via @_silgen_name declarations in
// BASInternalRustBridges.swift。

import XCTest
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)

final class BASInternalRustBridgesTests: XCTestCase {

    // MARK: - bas-lease-life bridge

    func testLeaseLifeAbiVersionPinned() {
        XCTAssertEqual(BASLeaseLifeBridge.abiVersion, 1)
        XCTAssertEqual(
            BASLeaseLifeBridge.liveAbiVersion(),
            BASLeaseLifeBridge.abiVersion,
            "Swift pin must match live Rust version")
    }

    func testLeaseLifeLungStateDecayAtOneTau() {
        // At idle = tau, factor = exp(-1)
        let result = BASLeaseLifeBridge.lungStateDecay(
            prevPressure: 1.0,
            idleSeconds: 180.0,
            timeConstantSeconds: 180.0)
        XCTAssertEqual(result, exp(-1.0), accuracy: 1e-6)
    }

    func testLeaseLifeLungStateDecayZeroIdleNoOp() {
        let result = BASLeaseLifeBridge.lungStateDecay(
            prevPressure: 0.5, idleSeconds: 0,
            timeConstantSeconds: 180)
        XCTAssertEqual(result, 0.5)
    }

    func testLeaseLifeRecordTurnEngageOneSecond() {
        // Engage = run mode 3, load 0.05/s × 1s = 0.05
        let result = BASLeaseLifeBridge.lungStateRecordTurn(
            prevPressure: 0, idleSeconds: 0,
            timeConstantSeconds: 180,
            runMode: 3, durationSeconds: 1.0)
        XCTAssertEqual(result, 0.05, accuracy: 1e-9)
    }

    func testLeaseLifeBreathValidatePermissive() {
        // Light @ Nominal → 0 (ok)
        XCTAssertEqual(
            BASLeaseLifeBridge.breathValidate(
                classByte: 1, guardLevelByte: 0),
            0)
    }

    func testLeaseLifeBreathValidateEmergencyRejects() {
        // Any @ Emergency → 1 (rejected)
        XCTAssertEqual(
            BASLeaseLifeBridge.breathValidate(
                classByte: 1, guardLevelByte: 3),
            1)
    }

    func testLeaseLifeBreathValidateInvalidByteReturnsMinus1() {
        XCTAssertEqual(
            BASLeaseLifeBridge.breathValidate(
                classByte: 99, guardLevelByte: 0),
            -1)
    }

    func testLeaseLifeShouldCancelEmergencyCancelsAll() {
        for classByte: UInt8 in 0...3 {
            XCTAssertEqual(
                BASLeaseLifeBridge.breathShouldCancelOnReconcile(
                    classByte: classByte, newGuardLevelByte: 3),
                1, "Emergency should cancel class \(classByte)")
        }
    }

    func testLeaseLifeShouldCancelWatchKeepsAll() {
        for classByte: UInt8 in 0...3 {
            XCTAssertEqual(
                BASLeaseLifeBridge.breathShouldCancelOnReconcile(
                    classByte: classByte, newGuardLevelByte: 1),
                0, "Watch should keep class \(classByte)")
        }
    }

    // MARK: - bas-mirror-blade bridge

    func testMirrorBladeAbiVersionPinned() {
        XCTAssertEqual(BASMirrorBladeBridge.abiVersion, 1)
        XCTAssertEqual(
            BASMirrorBladeBridge.liveAbiVersion(),
            BASMirrorBladeBridge.abiVersion)
    }

    func testMirrorBladeClassifyCleanYieldsFactShard() {
        let bits = BASMirrorBladeBridge.classify(
            emotionalLoad: 0, timePressure: 0,
            consequenceLevel: 0, ambiguityScore: 0,
            manipulationProbability: 0,
            relationTense: false, mirrorDraftRequested: false)
        XCTAssertEqual(bits, 1, "FactShard bit only")
    }

    func testMirrorBladeClassifyManipulationLightsBit4() {
        let bits = BASMirrorBladeBridge.classify(
            emotionalLoad: 0, timePressure: 0,
            consequenceLevel: 0, ambiguityScore: 0,
            manipulationProbability: 0.9,
            relationTense: false, mirrorDraftRequested: false)
        XCTAssertEqual(bits, 1 << 4)
    }

    func testMirrorBladeClassifyTenseRelationLightsBit2() {
        let bits = BASMirrorBladeBridge.classify(
            emotionalLoad: 0, timePressure: 0,
            consequenceLevel: 0, ambiguityScore: 0,
            manipulationProbability: 0,
            relationTense: true, mirrorDraftRequested: false)
        XCTAssertEqual(bits, 1 << 2)
    }

    // MARK: - bas-presence-eye bridge

    func testPresenceEyeAbiVersionPinned() {
        XCTAssertEqual(BASPresenceEyeBridge.abiVersion, 1)
        XCTAssertEqual(
            BASPresenceEyeBridge.liveAbiVersion(),
            BASPresenceEyeBridge.abiVersion)
    }

    func testPresenceEyeFuseCleanYieldsZero() {
        let r = BASPresenceEyeBridge.fuse(
            taskSalience: 0, taskConfidence: 0,
            riskSalience: 0, riskConfidence: 0,
            manipulationSalience: 0, manipulationConfidence: 0,
            environmentSalience: 0, environmentConfidence: 0,
            bodyRhythmSalience: 0, bodyRhythmConfidence: 0)
        XCTAssertEqual(r, 0)
    }

    func testPresenceEyeFuseFullSignalYieldsOne() {
        let r = BASPresenceEyeBridge.fuse(
            taskSalience: 1, taskConfidence: 1,
            riskSalience: 1, riskConfidence: 1,
            manipulationSalience: 1, manipulationConfidence: 1,
            environmentSalience: 1, environmentConfidence: 1,
            bodyRhythmSalience: 1, bodyRhythmConfidence: 1)
        XCTAssertEqual(r, 1.0, accuracy: 1e-9)
    }

    func testPresenceEyeFuseManipulationDominatesEnvironment() {
        // weights: manip=2.0, env=0.5
        // scores: manip=0.8 (×1.0), env=0.2 (×1.0)
        // weighted: 0.8*2.0 + 0.2*0.5 = 1.7
        // weight_total: 2.5
        // result: 1.7 / 2.5 = 0.68
        let r = BASPresenceEyeBridge.fuse(
            taskSalience: 0, taskConfidence: 0,
            riskSalience: 0, riskConfidence: 0,
            manipulationSalience: 0.8, manipulationConfidence: 1.0,
            environmentSalience: 0.2, environmentConfidence: 1.0,
            bodyRhythmSalience: 0, bodyRhythmConfidence: 0)
        XCTAssertEqual(r, 0.68, accuracy: 1e-9)
    }

    // MARK: - bas-host-constitution bridge

    func testHostConstitutionAbiVersionPinned() {
        XCTAssertEqual(BASHostConstitutionBridge.abiVersion, 1)
        XCTAssertEqual(
            BASHostConstitutionBridge.liveAbiVersion(),
            BASHostConstitutionBridge.abiVersion)
    }

    func testHostConstitutionResolveFieldEqualSucceeds() {
        // IdentityTags=0 + equal=true + no rollback → 0 (Success)
        let r = BASHostConstitutionBridge.resolveField(
            fieldKindByte: 0,
            valuesEqual: true,
            leftRolledBack: false,
            rightRolledBack: false)
        XCTAssertEqual(r, 0)
    }

    func testHostConstitutionResolveFieldRollbackBlocks() {
        let r = BASHostConstitutionBridge.resolveField(
            fieldKindByte: 0,
            valuesEqual: true,
            leftRolledBack: true,
            rightRolledBack: false)
        XCTAssertEqual(r, 2) // RollbackBlocked
    }

    func testHostConstitutionResolveFieldMemoryPermsConflict() {
        // MemoryPermissions=5 + values diff → 1 (ConflictEscalated)
        let r = BASHostConstitutionBridge.resolveField(
            fieldKindByte: 5,
            valuesEqual: false,
            leftRolledBack: false,
            rightRolledBack: false)
        XCTAssertEqual(r, 1)
    }

    func testHostConstitutionDefaultStrategyIdentityTagsIsUnion() {
        // IdentityTags=0 → Union strategy=2
        XCTAssertEqual(
            BASHostConstitutionBridge.defaultStrategy(
                fieldKindByte: 0),
            2)
    }

    func testHostConstitutionDefaultStrategyMemoryPermsIsFailOnConflict() {
        // MemoryPermissions=5 → FailOnConflict=5
        XCTAssertEqual(
            BASHostConstitutionBridge.defaultStrategy(
                fieldKindByte: 5),
            5)
    }

    func testHostConstitutionClassifyDeletionCleanAllowed() {
        // Cascade=0 + no flags → 0 (Allowed)
        let r = BASHostConstitutionBridge.classifyDeletion(
            deletionTypeByte: 0,
            isRollbackAnchor: false,
            isVaultGenesis: false,
            targetsImmutableField: false)
        XCTAssertEqual(r, 0)
    }

    func testHostConstitutionClassifyDeletionRollbackAnchorBlocksCascade() {
        let r = BASHostConstitutionBridge.classifyDeletion(
            deletionTypeByte: 0, // Cascade
            isRollbackAnchor: true,
            isVaultGenesis: false,
            targetsImmutableField: false)
        XCTAssertEqual(r, 1) // BlockedByRollbackAnchor
    }

    // MARK: - bas-world-prior bridge

    func testWorldPriorAbiVersionPinned() {
        XCTAssertEqual(BASWorldPriorBridge.abiVersion, 1)
        XCTAssertEqual(
            BASWorldPriorBridge.liveAbiVersion(),
            BASWorldPriorBridge.abiVersion)
    }

    func testWorldPriorPropagateEvidenceEmptyYieldsAnecdotal() {
        XCTAssertEqual(
            BASWorldPriorBridge.propagateEvidence(levels: []),
            0) // Anecdotal
    }

    func testWorldPriorPropagateEvidenceWeakestWins() {
        // Mechanistic=3, Anecdotal=0, PeerReviewed=2 → min is 0
        XCTAssertEqual(
            BASWorldPriorBridge.propagateEvidence(
                levels: [3, 0, 2]),
            0)
    }

    func testWorldPriorPropagateEvidenceInvalidByte() {
        // 99 is out of range → -1
        XCTAssertEqual(
            BASWorldPriorBridge.propagateEvidence(
                levels: [0, 99, 2]),
            -1)
    }

    func testWorldPriorAggregateLatencyMean() {
        XCTAssertEqual(
            BASWorldPriorBridge.aggregateLatency(
                latencies: [100, 200, 300]),
            200)
    }

    func testWorldPriorAggregateLatencyEmpty() {
        XCTAssertEqual(
            BASWorldPriorBridge.aggregateLatency(latencies: []),
            0)
    }

    func testWorldPriorWorstReversibilityIrreversibleDominates() {
        // Easy=3, Irreversible=0, Medium=2 → 0 (Irreversible)
        XCTAssertEqual(
            BASWorldPriorBridge.worstReversibility(
                values: [3, 0, 2]),
            0)
    }

    func testWorldPriorWorstReversibilityEmptyYieldsEasy() {
        XCTAssertEqual(
            BASWorldPriorBridge.worstReversibility(values: []),
            3) // Easy
    }
}

#endif  // os(iOS) || os(macOS)
