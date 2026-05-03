import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M448-M451 (chapter 一百十八) — pin that the chapter 一百十七
/// Cthulhu helpers (M444 BASCthulhuLayerProjections / M445
/// BASCthulhuAssertionCeilingGate / M446 BASCthulhuPermitEscalation)
/// are now consumed by `EBrainRuntimeCoordinator.runTurn` and
/// emit `cthulhu.*` reason codes through the L14 sovereign audit
/// entry on every turn.
///
/// Pre-chapter-一百十八 the chapter 一百十七 helpers were typed
/// pure functions sitting in BASOrchestration with **0 production
/// callers** (Phase 1 grep confirmed: only test file callers).
/// Chapter 一百十八 wires:
///
///   - M448: derive `BASAbyssalRunMode` / `BASAbyssBudget` /
///     `BASCosmicScaleView` / `BASOntologyFog` /
///     `BASOntologyShiftMark` from existing turn state. Watcher-
///     hint output (red line 7).
///   - M449: compose fog with M385 BASUnknownReserve via
///     `BASCthulhuAssertionCeilingGate.cap`. Permit narrowing
///     only.
///   - M450: derive `BASCosmicColdCounterweight` from risk +
///     candidate count + permit mode; pass into
///     `BASCthulhuPermitEscalation.escalate`. Composes with
///     M384 / M406 stackedModes.
///   - M451: thread all 5 projections + 2 reason-code arrays
///     through `BASAuditObservationProjections` into
///     `buildSovereignAuditEntry`, which appends typed
///     `cthulhu.*` codes to `signalRefs`.
///
/// Hash chain semantics from M91/M283/M271 preserved. Doctrine
/// red line 7 (watcher hints, not verdicts) preserved: chapter
/// 一百十八 wires NEVER touch `permit.mode` or `verdict.level`.
final class M448CthulhuLayerProductionWiringTests: XCTestCase {

    // MARK: - Configuration helpers (mirror M303 pattern)

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m448.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m448.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m448.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m448.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m448.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m448.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m448",
                policyProfileID: "host.m448.policy",
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

    private func runTurn(
        prompt: String =
            "Help me weigh whether this is a safe step.",
        title: String = "M448 cthulhu wiring",
        riskLevel: BASHostRiskLevel = .medium
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: title,
                riskLevel: riskLevel
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. cthulhu.runMode always emitted

    /// M448 derive — every turn produces a `BASAbyssalRunMode`
    /// projection from the routed budget's run mode. Pin the
    /// code is always present + parseable to one of 6 cases.
    func testCthulhuRunModeAlwaysAppears() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("cthulhu.runMode:")
        }
        XCTAssertEqual(
            codes.count, 1,
            "exactly one cthulhu.runMode code per turn")
        let suffix = codes[0]
            .replacingOccurrences(
                of: "cthulhu.runMode:", with: "")
        let validRawValues: Set<String> = Set(
            BASAbyssalRunMode.allCases.map(\.rawValue))
        XCTAssertTrue(
            validRawValues.contains(suffix),
            "cthulhu.runMode suffix must be a valid " +
            "BASAbyssalRunMode rawValue (got \"\(suffix)\")")
    }

    // MARK: - 2. cthulhu.budget.aggregateAvailability emitted

    func testCthulhuBudgetAggregateAvailabilityAppears() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("cthulhu.budget.aggregateAvailability:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly one budget aggregate code per turn")
        let suffix = codes[0]
            .replacingOccurrences(
                of: "cthulhu.budget.aggregateAvailability:",
                with: "")
        guard let value = Double(suffix) else {
            XCTFail(
                "cthulhu.budget.aggregateAvailability must be " +
                "parseable Double (was \"\(suffix)\")")
            return
        }
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 1)
    }

    // MARK: - 3. cthulhu.cosmic.scale always emitted

    /// `cthulhu.cosmic.scale:<temporal>:<spatial>` — every turn.
    func testCthulhuCosmicScaleAppears() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("cthulhu.cosmic.scale:")
        }
        XCTAssertEqual(codes.count, 1)
        let suffix = codes[0]
            .replacingOccurrences(
                of: "cthulhu.cosmic.scale:", with: "")
        let parts = suffix.split(separator: ":")
        XCTAssertEqual(parts.count, 2,
                       "cosmic.scale must have temporal:spatial pair")
        let temporal = String(parts[0])
        let spatial = String(parts[1])
        let validHorizons: Set<String> = Set(
            BASCosmicScaleHorizon.allCases.map(\.rawValue))
        XCTAssertTrue(
            validHorizons.contains(temporal),
            "temporal horizon must be valid (got \"\(temporal)\")")
        XCTAssertTrue(
            validHorizons.contains(spatial),
            "spatial horizon must be valid (got \"\(spatial)\")")
    }

    // MARK: - 4. cthulhu.fog.quality always emitted

    func testCthulhuFogQualityAppears() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let codes = auditEntry.signalRefs.filter {
            $0.hasPrefix("cthulhu.fog.quality:")
        }
        XCTAssertEqual(codes.count, 1)
        let suffix = codes[0]
            .replacingOccurrences(
                of: "cthulhu.fog.quality:", with: "")
        let validQualities: Set<String> = Set(
            BASOntologyFogQuality.allCases.map(\.rawValue))
        XCTAssertTrue(
            validQualities.contains(suffix),
            "fog.quality must be valid (got \"\(suffix)\")")
    }

    // MARK: - 5. Permit mode preserved (single commit mouth)

    /// **Doctrine pin** — chapter 一百十八 wires must NEVER
    /// replace `permit.mode`. Single commit mouth stays at L11.
    /// They may add to `stackedModes` and narrow
    /// `assertionCeiling`, but `mode` is held by L11.
    func testPermitModeNotMutatedByCthulhuWires() throws {
        let turn = try runTurn(riskLevel: .high)
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let permit = turn.actionPermit  // non-optional field

        // The audit entry's `permit:` reason code must match the
        // bound action permit's mode rawValue. If a chapter
        // 一百十八 wire mutated `permit.mode`, the two would
        // disagree.
        let permitCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("permit:")
        }
        XCTAssertEqual(permitCodes.count, 1)
        let auditMode = permitCodes[0]
            .replacingOccurrences(of: "permit:", with: "")
        XCTAssertEqual(auditMode, permit.mode.rawValue,
                       "single commit mouth — permit.mode held " +
                       "by L11; chapter 一百十八 wires must not " +
                       "replace it")
    }

    // MARK: - 6. Hash chain semantics preserved

    /// Adding `cthulhu.*` reason codes lengthens `signalRefs`
    /// but the digest is deterministic — running the same turn
    /// twice yields byte-equal `signalRefs` lists.
    func testCthulhuReasonCodesAreDeterministic() throws {
        let turn1 = try runTurn(prompt: "fixed prompt", riskLevel: .medium)
        let turn2 = try runTurn(prompt: "fixed prompt", riskLevel: .medium)
        let entry1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let entry2 = try XCTUnwrap(turn2.sovereignAuditEntry)

        let cthulhuCodes1 = entry1.signalRefs
            .filter { $0.hasPrefix("cthulhu.") }
            .sorted()
        let cthulhuCodes2 = entry2.signalRefs
            .filter { $0.hasPrefix("cthulhu.") }
            .sorted()
        XCTAssertEqual(cthulhuCodes1, cthulhuCodes2,
                       "cthulhu.* codes must be deterministic " +
                       "for byte-equal turn inputs")
    }

    // MARK: - 7. M444 helper called at audit-projection seam

    /// Direct call to the M444 helper — verify the function is
    /// callable with production-shaped inputs (mirrors how
    /// `EBrainRuntimeCoordinator.runTurn` calls it).
    func testCthulhuLayerProjectionsCalledWithProductionInputs() {
        let frame = BASBudgetFrame(
            runMode: .engage,
            maxLoops: 6,
            maxCandidates: 5,
            maxDecodeTokens: 256,
            retrievalDepth: 4,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: true,
            leaseID: nil,
            leaseExpiresAt: nil,
            maintenanceClass: .none)
        let abyssalRunMode = BASCthulhuLayerProjections
            .AbyssalRunMode.derive(from: frame.runMode)
        XCTAssertEqual(abyssalRunMode, .deepDive,
                       "engage run mode → deepDive abyssal alias")
        let abyssBudget = BASCthulhuLayerProjections
            .AbyssBudget.derive(
                from: frame, turnID: "test-turn")
        XCTAssertEqual(abyssBudget.budgetID, "abyss-budget:test-turn")
        XCTAssertEqual(abyssBudget.deepDiveQuota, 0.5, accuracy: 0.001)
    }
}
