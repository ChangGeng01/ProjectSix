import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// M500-M510 (chapter 一百二十八) — pin the chapter 99 deferred
/// Kunlun L4 wires (BASKunlunAscentView + BASKunlunFarWestReserve)
/// + L12 doctrine-specific surface aliases (5 Kunlun + 4 Cthulhu)
/// now flow through `EBrainRuntimeCoordinator.runTurn` audit
/// emission.
final class M500KunlunL4LeftoverSurfaceAliasWiringTests:
    XCTestCase
{
    private func makeRuntimePolicyLineage()
        -> BASRuntimePolicyLineage
    {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m500.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m500.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m500.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m500.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m500.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning()
        -> BASEBrainRuntimeSynthesisPolicy
    {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m500.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m500",
                policyProfileID: "host.m500.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(),
                hostRhythmProfile: .generic
            )
        )
    }

    private func runTurn() throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Test the chapter 一百二十八 audit emission.",
                title: "M500 L4 + surface alias wiring",
                riskLevel: .medium))
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. M500 kunlun.l4.ascent always fires

    func testKunlunL4AscentAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.l4.ascent:")
        }
        XCTAssertEqual(codes.count, 1,
            "exactly 1 kunlun.l4.ascent per turn")
        let suffix = codes[0].replacingOccurrences(
            of: "kunlun.l4.ascent:", with: "")
        XCTAssertTrue(
            suffix == "wellformed" || suffix == "partial",
            "ascent view status must be wellformed or partial; got \(suffix)")
    }

    /// **§5.4 不急着登顶 doctrine pin** — derive helper synthesizes
    /// both ascentConditions AND returnPaths so isWellFormed
    /// is honored by construction.
    func testKunlunL4AscentIsWellFormedByConstruction() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        XCTAssertTrue(
            entry.signalRefs.contains("kunlun.l4.ascent:wellformed"),
            "derive helper must produce wellformed ascent view per §5.4 doctrine")
    }

    // MARK: - 2. M501 kunlun.l4.far-west conditional emission

    func testKunlunL4FarWestCodesPairTogether() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let distanceCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.l4.far-west.distance:")
        }
        let refCountCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.l4.far-west.refCount:")
        }
        // Both fire together when unknownRefs non-empty,
        // otherwise both elide.
        XCTAssertEqual(
            distanceCodes.count, refCountCodes.count,
            "distance + refCount codes must fire together (or both elide)")
        if !distanceCodes.isEmpty {
            let distanceSuffix = distanceCodes[0]
                .replacingOccurrences(
                    of: "kunlun.l4.far-west.distance:",
                    with: "")
            let validBands: Set<String> = [
                "adjacent", "visible", "far-reach",
                "beyond-horizon", "sealed-unknown",
            ]
            XCTAssertTrue(
                validBands.contains(distanceSuffix),
                "distance band must be one of 5 stable values; got \(distanceSuffix)")
            let refCountSuffix = refCountCodes[0]
                .replacingOccurrences(
                    of: "kunlun.l4.far-west.refCount:",
                    with: "")
            XCTAssertNotNil(Int(refCountSuffix),
                "refCount must be parseable Int")
        }
    }

    // MARK: - 3. M502 BASCthulhuSurfaceAlias enum cardinality

    func testCthulhuSurfaceAliasCardinality() {
        XCTAssertEqual(
            BASCthulhuSurfaceAlias.allCases.count, 4,
            "Cthulhu has exactly 4 surface aliases per §5.12")
        let rawValues = Set(
            BASCthulhuSurfaceAlias.allCases.map(\.rawValue))
        XCTAssertEqual(
            rawValues,
            ["lighthouse-compare", "tide-delay-packet",
             "seal-notice", "lantern-boundary-script"],
            "Cthulhu raw values must be stable kebab-case")
    }

    // MARK: - 4. M502 BASKunlunSurfaceAlias enum cardinality

    func testKunlunSurfaceAliasCardinality() {
        XCTAssertEqual(
            BASKunlunSurfaceAlias.allCases.count, 5,
            "Kunlun has exactly 5 surface aliases per §5.12")
        let rawValues = Set(
            BASKunlunSurfaceAlias.allCases.map(\.rawValue))
        XCTAssertEqual(
            rawValues,
            ["axis-compare-panel", "jade-draft-shell",
             "tianmen-second-check", "yaochi-seal-notice",
             "return-path-card"],
            "Kunlun raw values must be stable kebab-case")
    }

    // MARK: - 5. Cthulhu surface alias derive table

    func testCthulhuSurfaceAliasDeriveTable() {
        XCTAssertEqual(
            BASCthulhuSurfaceAlias.derive(from: .comparePanel),
            .lighthouseCompare)
        XCTAssertEqual(
            BASCthulhuSurfaceAlias.derive(from: .delayPacket),
            .tideDelayPacket)
        XCTAssertEqual(
            BASCthulhuSurfaceAlias.derive(from: .silentStub),
            .sealNotice)
        XCTAssertEqual(
            BASCthulhuSurfaceAlias.derive(from: .boundaryScript),
            .lanternBoundaryScript)
        // Cthulhu has no draftShell alias per §5.12
        XCTAssertNil(
            BASCthulhuSurfaceAlias.derive(from: .draftShell),
            "Cthulhu doctrine has no draftShell alias")
    }

    // MARK: - 6. Kunlun surface alias derive table

    func testKunlunSurfaceAliasDeriveTable() {
        XCTAssertEqual(
            BASKunlunSurfaceAlias.derive(from: .comparePanel),
            .axisComparePanel)
        XCTAssertEqual(
            BASKunlunSurfaceAlias.derive(from: .draftShell),
            .jadeDraftShell)
        XCTAssertEqual(
            BASKunlunSurfaceAlias.derive(from: .delayPacket),
            .tianmenSecondCheck)
        XCTAssertEqual(
            BASKunlunSurfaceAlias.derive(from: .boundaryScript),
            .yaochiSealNotice)
        XCTAssertEqual(
            BASKunlunSurfaceAlias.derive(from: .silentStub),
            .returnPathCard)
    }

    // MARK: - 7. Surface mode from permit table

    func testSurfaceModeFromPermitTable() {
        XCTAssertEqual(
            BASSurfaceModeFromPermit.derive(from: .compare),
            .comparePanel)
        XCTAssertEqual(
            BASSurfaceModeFromPermit.derive(from: .delay),
            .delayPacket)
        XCTAssertEqual(
            BASSurfaceModeFromPermit.derive(from: .block),
            .boundaryScript)
        XCTAssertEqual(
            BASSurfaceModeFromPermit.derive(from: .replace),
            .silentStub)
        XCTAssertEqual(
            BASSurfaceModeFromPermit.derive(from: .draftOnly),
            .draftShell)
        XCTAssertEqual(
            BASSurfaceModeFromPermit.derive(from: .mirror),
            .draftShell)
        // Modes with no L12 surface counterpart return nil
        XCTAssertNil(
            BASSurfaceModeFromPermit.derive(from: .answer))
        XCTAssertNil(
            BASSurfaceModeFromPermit.derive(from: .escalate))
        XCTAssertNil(
            BASSurfaceModeFromPermit.derive(from: .localOnly))
    }

    // MARK: - 8. Surface alias paired emission

    func testSurfaceAliasCodesPairTogether() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let cthulhuCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.surface.alias:")
        }
        let kunlunCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.surface.alias:")
        }
        // When permit mode has L12 surface, Kunlun emits 1-to-1;
        // Cthulhu may emit 0 or 1 (no draftShell alias).
        // When permit mode has no L12 surface (e.g. .answer),
        // both elide.
        // Invariant: when Cthulhu emits, Kunlun also emits.
        if !cthulhuCodes.isEmpty {
            XCTAssertFalse(
                kunlunCodes.isEmpty,
                "When Cthulhu surface alias emits, Kunlun must also emit")
        }
        // Both ≤ 1 per turn.
        XCTAssertLessThanOrEqual(cthulhuCodes.count, 1,
            "at most 1 cthulhu.surface.alias per turn")
        XCTAssertLessThanOrEqual(kunlunCodes.count, 1,
            "at most 1 kunlun.surface.alias per turn")
    }

    // MARK: - 9. Single commit mouth pin

    func testPermitModeNotMutatedByChapter128Wires() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let permit = turn.actionPermit
        let permitCodes = entry.signalRefs.filter {
            $0.hasPrefix("permit:")
        }
        XCTAssertEqual(permitCodes.count, 1)
        let auditMode = permitCodes[0]
            .replacingOccurrences(of: "permit:", with: "")
        XCTAssertEqual(auditMode, permit.mode.rawValue,
            "single commit mouth — chapter 一百二十八 wires don't replace permit.mode")
    }

    // MARK: - 10. M511 fix-pin (deep-review finding #1)

    /// **Doctrine pin** — `BASKunlunFarWestReserve.isHonoring
    /// Doctrine` MUST hold for every emitted reserve. Pre-M511 the
    /// `.qualified` ceiling mapped `namingStatus` to `.provisional`
    /// which violated the schema invariant
    /// (`namingStatus ∈ {.unattempted, .refused}` OR
    /// `distanceBand == .sealedUnknown`). M511 fixes the mapping
    /// to `.unattempted`. This test pins the invariant by directly
    /// invoking the derive helper for every BASUnknownAssertion
    /// Ceiling case + asserting isHonoringDoctrine.
    func testFarWestReserveAlwaysHonorsDoctrine() throws {
        let allCeilings: [BASUnknownAssertionCeiling] = [
            .unrestricted, .provisional, .qualified,
            .metaOnly, .none,
        ]
        for ceiling in allCeilings {
            let reserve = try XCTUnwrap(
                BASKunlunLayerProjections
                    .FarWestReserve.derive(
                        unknownRefs: ["unknown-1"],
                        assertionCeiling: ceiling,
                        riskLevel: .medium,
                        turnID: "test-\(ceiling.rawValue)"),
                "reserve must be non-nil with non-empty unknownRefs (ceiling=\(ceiling.rawValue))")
            XCTAssertTrue(
                reserve.isHonoringDoctrine,
                "FarWestReserve must honor §5.4 doctrine for ceiling=\(ceiling.rawValue) (chapter 一百二十八 M511 fix)")
        }
    }

    // MARK: - 11. M511 fix-pin (deep-review finding #5)

    /// **§5.12 asymmetric pin** — when Kunlun emits
    /// `jadeDraftShell`, Cthulhu MUST emit nothing (Cthulhu
    /// doctrine has no draftShell alias per whitepaper §5.12).
    /// This pin catches drift in the inverse direction (someone
    /// adding a draftShell case to Cthulhu but forgetting Kunlun
    /// would still pass the existing pair-together test).
    func testCthulhuDraftShellAsymmetricEmission() {
        let kunlunForDraftShell = BASKunlunSurfaceAlias.derive(
            from: .draftShell)
        XCTAssertEqual(
            kunlunForDraftShell, .jadeDraftShell,
            "Kunlun must alias .draftShell → .jadeDraftShell")
        let cthulhuForDraftShell = BASCthulhuSurfaceAlias.derive(
            from: .draftShell)
        XCTAssertNil(
            cthulhuForDraftShell,
            "Cthulhu doctrine has no draftShell alias per §5.12 — \\(cthulhu.draftShell) MUST be nil")
    }

    // MARK: - 12. Determinism

    func testChapter128CodesAreDeterministic() throws {
        let turn1 = try runTurn()
        let turn2 = try runTurn()
        let e1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let e2 = try XCTUnwrap(turn2.sovereignAuditEntry)
        let codes1 = e1.signalRefs
            .filter { $0.hasPrefix("kunlun.l4.")
                || $0.hasPrefix("cthulhu.surface.alias")
                || $0.hasPrefix("kunlun.surface.alias") }
            .sorted()
        let codes2 = e2.signalRefs
            .filter { $0.hasPrefix("kunlun.l4.")
                || $0.hasPrefix("cthulhu.surface.alias")
                || $0.hasPrefix("kunlun.surface.alias") }
            .sorted()
        XCTAssertEqual(codes1, codes2,
            "chapter 一百二十八 codes deterministic across turns")
    }
}
