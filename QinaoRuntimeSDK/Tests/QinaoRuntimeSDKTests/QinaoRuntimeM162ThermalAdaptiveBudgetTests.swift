import XCTest
import BASRuntimeCore
@testable import QinaoRuntime

/// M162 — `BudgetThermalAdapter` shrinks the four numeric
/// work-volume fields of `BASBudgetFrame` when the device is hot.
///
/// Pre-M162 `prepareBudgetForTurn(_:)` only plumbed the live
/// thermal guard level into the routed frame; the planned numeric
/// fields (`maxLoops`, `maxCandidates`, `maxDecodeTokens`,
/// `retrievalDepth`) reached the loop unchanged. M162 generalizes
/// the M126 `SurfaceRetryPolicy.thermalMultiplier(for:)` idea —
/// "stretch retry windows when hot" — into a symmetric "shrink
/// work volume when hot" curve. Defaults: 1.0 / 0.75 / 0.5 / 0.25
/// for `.nominal` / `.watch` / `.throttle` / `.emergency`.
///
/// Pins:
///   1. `.default` and `.identity` static multipliers
///   2. `.nominal` is byte-identity (short-circuit)
///   3. `.watch` compresses by 0.75× with banker rounding
///   4. `.throttle` compresses by 0.5×
///   5. `.emergency` compresses by 0.25× and respects
///      BASBudgetFrame's structural floor (maxCandidates ≥ 1)
///   6. Compression preserves every non-numeric field byte-equal
///   7. Custom multipliers honored (configurability)
///   8. `prepareBudgetForTurn` end-to-end: hot planned + no
///      lifecycle compresses on the planned level
///   9. `prepareBudgetForTurn` end-to-end: live lifecycle reading
///      drives compression even when planned thermal differed
///  10. `.identity` adapter opts out of compression at any level
final class QinaoRuntimeM162ThermalAdaptiveBudgetTests:
    XCTestCase
{
    // MARK: - Helpers

    /// A fully-populated planned budget. All four numeric fields
    /// chosen so the multipliers produce non-trivial compressed
    /// values (no accidental round-trips).
    private func plannedBudget(
        thermalGuardLevel: BASThermalGuardLevel = .nominal
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 8,
            maxCandidates: 8,
            maxDecodeTokens: 1024,
            retrievalDepth: 16,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: true,
            leaseID: "lease.m162",
            leaseExpiresAt: Date(
                timeIntervalSince1970: 1_700_000_500),
            maintenanceClass: .light,
            wakeIntentID: "wake.m162",
            allowedHeads: ["scout", "core"],
            policyBundleVersion: "policy.v1",
            policyDecisionIDs: ["p1", "p2"])
    }

    // MARK: - 1. Static multipliers

    func testDefaultMultipliersMatchSpec() {
        let adapter = QinaoRuntime.BudgetThermalAdapter.default
        XCTAssertEqual(adapter.multiplier(for: .nominal), 1.0)
        XCTAssertEqual(adapter.multiplier(for: .watch), 0.75)
        XCTAssertEqual(adapter.multiplier(for: .throttle), 0.5)
        XCTAssertEqual(adapter.multiplier(for: .emergency), 0.25)
    }

    func testIdentityMultipliersAllOne() {
        let adapter = QinaoRuntime.BudgetThermalAdapter.identity
        XCTAssertEqual(adapter.multiplier(for: .nominal), 1.0)
        XCTAssertEqual(adapter.multiplier(for: .watch), 1.0)
        XCTAssertEqual(adapter.multiplier(for: .throttle), 1.0)
        XCTAssertEqual(adapter.multiplier(for: .emergency), 1.0)
    }

    // MARK: - 2. Nominal is byte-identity (short circuit)

    func testCompressNominalIsByteIdentity() throws {
        let frame = plannedBudget(thermalGuardLevel: .nominal)
        let compressed = QinaoRuntime.BudgetThermalAdapter
            .default.compress(frame)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(
            try encoder.encode(frame),
            try encoder.encode(compressed),
            "nominal level → multiplier 1.0 → byte-identity")
    }

    // MARK: - 3. Watch compresses 0.75×

    func testCompressWatchScalesByThreeQuarters() {
        let frame = plannedBudget(thermalGuardLevel: .watch)
        let c = QinaoRuntime.BudgetThermalAdapter.default
            .compress(frame)
        // 8 × 0.75 = 6.0 → 6.
        XCTAssertEqual(c.maxLoops, 6)
        XCTAssertEqual(c.maxCandidates, 6)
        // 1024 × 0.75 = 768.0 → 768.
        XCTAssertEqual(c.maxDecodeTokens, 768)
        // 16 × 0.75 = 12.0 → 12.
        XCTAssertEqual(c.retrievalDepth, 12)
    }

    // MARK: - 4. Throttle compresses 0.5×

    func testCompressThrottleHalves() {
        let frame = plannedBudget(thermalGuardLevel: .throttle)
        let c = QinaoRuntime.BudgetThermalAdapter.default
            .compress(frame)
        XCTAssertEqual(c.maxLoops, 4)
        XCTAssertEqual(c.maxCandidates, 4)
        XCTAssertEqual(c.maxDecodeTokens, 512)
        XCTAssertEqual(c.retrievalDepth, 8)
    }

    // MARK: - 5. Emergency compresses 0.25×

    func testCompressEmergencyQuarters() {
        let frame = plannedBudget(thermalGuardLevel: .emergency)
        let c = QinaoRuntime.BudgetThermalAdapter.default
            .compress(frame)
        XCTAssertEqual(c.maxLoops, 2)
        XCTAssertEqual(c.maxCandidates, 2)
        XCTAssertEqual(c.maxDecodeTokens, 256)
        XCTAssertEqual(c.retrievalDepth, 4)
    }

    /// Extreme case: planned `maxCandidates = 1` at `.emergency`
    /// → scaled to `Int((1 × 0.25).rounded())` = 0 → BASBudgetFrame
    /// init clamps to ≥ 1. Defense-in-depth — the runtime always
    /// has at least one candidate slot to render an answer with.
    func testCompressRespectsBASBudgetFrameFloor() {
        let frame = BASBudgetFrame(
            runMode: .engage,
            maxLoops: 1,
            maxCandidates: 1,
            maxDecodeTokens: 1,
            retrievalDepth: 1,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .emergency,
            maintenanceAllowed: false)
        let c = QinaoRuntime.BudgetThermalAdapter.default
            .compress(frame)
        // 1 × 0.25 = 0.25 → 0; maxCandidates clamped to 1 by
        // BASBudgetFrame init's structural floor.
        XCTAssertEqual(c.maxLoops, 0)
        XCTAssertEqual(c.maxCandidates, 1)
        XCTAssertEqual(c.maxDecodeTokens, 0)
        XCTAssertEqual(c.retrievalDepth, 0)
    }

    // MARK: - 6. Non-numeric fields preserved byte-equal

    func testCompressPreservesNonNumericFieldsByteForByte() {
        let frame = plannedBudget(thermalGuardLevel: .throttle)
        let c = QinaoRuntime.BudgetThermalAdapter.default
            .compress(frame)
        XCTAssertEqual(c.schemaVersion, frame.schemaVersion)
        XCTAssertEqual(c.runMode, frame.runMode)
        XCTAssertEqual(
            c.precisionProfile, frame.precisionProfile)
        XCTAssertEqual(c.deviceRoute, frame.deviceRoute)
        XCTAssertEqual(
            c.thermalGuardLevel, frame.thermalGuardLevel)
        XCTAssertEqual(
            c.maintenanceAllowed, frame.maintenanceAllowed)
        XCTAssertEqual(c.leaseID, frame.leaseID)
        XCTAssertEqual(c.leaseExpiresAt, frame.leaseExpiresAt)
        XCTAssertEqual(
            c.maintenanceClass, frame.maintenanceClass)
        XCTAssertEqual(c.wakeIntentID, frame.wakeIntentID)
        XCTAssertEqual(c.allowedHeads, frame.allowedHeads)
        XCTAssertEqual(
            c.policyBundleVersion, frame.policyBundleVersion)
        XCTAssertEqual(
            c.policyDecisionIDs, frame.policyDecisionIDs)
    }

    // MARK: - 7. Custom multipliers honored

    func testCustomAdapterUsesProvidedMultipliers() {
        let custom = QinaoRuntime.BudgetThermalAdapter(
            nominal: 1.0, watch: 0.5, throttle: 0.1, emergency: 0.0)
        let frame = plannedBudget(thermalGuardLevel: .throttle)
        let c = custom.compress(frame)
        // 8 × 0.1 = 0.8 → banker-rounds to 1.
        XCTAssertEqual(c.maxLoops, 1)
        XCTAssertEqual(c.maxCandidates, 1)
        // 1024 × 0.1 = 102.4 → 102.
        XCTAssertEqual(c.maxDecodeTokens, 102)
        // 16 × 0.1 = 1.6 → 2.
        XCTAssertEqual(c.retrievalDepth, 2)
    }

    /// Negative multiplier → clamped to 0 at init time.
    func testNegativeMultiplierClampsToZero() {
        let adapter = QinaoRuntime.BudgetThermalAdapter(
            nominal: -1.0, watch: -0.5,
            throttle: -10.0, emergency: -100.0)
        XCTAssertEqual(adapter.nominalMultiplier, 0.0)
        XCTAssertEqual(adapter.watchMultiplier, 0.0)
        XCTAssertEqual(adapter.throttleMultiplier, 0.0)
        XCTAssertEqual(adapter.emergencyMultiplier, 0.0)
    }

    // MARK: - 8. Source frame is never mutated

    func testCompressDoesNotMutateInput() {
        let frame = plannedBudget(thermalGuardLevel: .emergency)
        _ = QinaoRuntime.BudgetThermalAdapter.default
            .compress(frame)
        // BASBudgetFrame is a value type; the input must remain
        // at its planned values.
        XCTAssertEqual(frame.maxLoops, 8)
        XCTAssertEqual(frame.maxCandidates, 8)
        XCTAssertEqual(frame.maxDecodeTokens, 1024)
        XCTAssertEqual(frame.retrievalDepth, 16)
    }

    // MARK: - 9. End-to-end via prepareBudgetForTurn

    func testPrepareBudgetCompressesUnderHotPlanWithoutLifecycle()
        async {
        let fx = await QinaoTestFixture.make()
        let planned = plannedBudget(
            thermalGuardLevel: .throttle)
        let routed = await fx.runtime.prepareBudgetForTurn(
            planned)
        // No lifecycle attached → planned thermal drives the
        // adapter directly. .throttle = 0.5× compression.
        XCTAssertEqual(routed.thermalGuardLevel, .throttle)
        XCTAssertEqual(routed.maxLoops, 4)
        XCTAssertEqual(routed.maxCandidates, 4)
        XCTAssertEqual(routed.maxDecodeTokens, 512)
        XCTAssertEqual(routed.retrievalDepth, 8)
    }

    func testPrepareBudgetWithIdentityAdapterIsHotPassthrough()
        async {
        let fx = await QinaoTestFixture.make()
        let planned = plannedBudget(
            thermalGuardLevel: .emergency)
        let routed = await fx.runtime.prepareBudgetForTurn(
            planned, thermalAdapter: .identity)
        // .identity at .emergency must NOT compress.
        XCTAssertEqual(routed.thermalGuardLevel, .emergency)
        XCTAssertEqual(routed.maxLoops, 8)
        XCTAssertEqual(routed.maxCandidates, 8)
        XCTAssertEqual(routed.maxDecodeTokens, 1024)
        XCTAssertEqual(routed.retrievalDepth, 16)
    }
}
