import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M126 — surface retry policy + thermal/maintenance-aware surface
/// decision derivation.
///
/// M125 hard-coded 60s for every delay-path audit severity; M126
/// introduces `SurfaceRetryPolicy` (5 severity-specific base
/// seconds + thermal multiplier) and feeds routed-budget thermal +
/// maintenance state into the derivation so:
///
///   * delay-packet retry windows are severity-differentiated
///   * hotter devices stretch the retry window transparently
///   * pass-path disclosure escalates on thermal throttle or
///     deferred maintenance (not just coverage advisory)
///   * reasonCodes carry the device-side context explicitly
///
/// Pins:
///   1. Default policy produces 30/60/120/180/300s for each of
///      the 5 delay-producing severities.
///   2. Thermal multipliers compose correctly with the base.
///   3. Caller-supplied custom policy is honored.
///   4. `.pass` + hot thermal → disclosure escalates to `.reasoned`.
///   5. `.pass` + deferred maintenance → disclosure escalates.
///   6. reasonCodes include "thermal:<level>" and
///      "maintenance:<class>" when routedBudget is present.
final class QinaoRuntimeSurfaceRetryPolicyTests: XCTestCase {

    private func budget(
        thermal: BASThermalGuardLevel = .nominal,
        maintenance: BASMaintenanceClass = .light
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3, maxCandidates: 3,
            maxDecodeTokens: 512,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: thermal,
            maintenanceAllowed: false,
            leaseID: "lease.m126",
            leaseExpiresAt: Date().addingTimeInterval(60),
            maintenanceClass: maintenance,
            wakeIntentID: "wake.m126",
            allowedHeads: ["answer"],
            policyBundleVersion: "pb.v1",
            policyDecisionIDs: [])
    }

    // MARK: - 1. Default policy baseline

    func testDefaultPolicyProducesMonotonicBaseSeconds() {
        let p = QinaoRuntime.SurfaceRetryPolicy.default
        XCTAssertEqual(p.baseSeconds(for: .throttle), 30)
        XCTAssertEqual(p.baseSeconds(for: .shadowLock), 60)
        XCTAssertEqual(p.baseSeconds(for: .toolCut), 120)
        XCTAssertEqual(p.baseSeconds(for: .memoryFreeze), 180)
        XCTAssertEqual(p.baseSeconds(for: .quarantine), 300)
        XCTAssertNil(p.baseSeconds(for: .pass))
        XCTAssertNil(p.baseSeconds(for: .rollback))
        XCTAssertNil(p.baseSeconds(for: .deadStop))
    }

    // MARK: - 2. Thermal multipliers compose

    func testThermalMultiplierStretchesEffectiveSeconds() {
        let p = QinaoRuntime.SurfaceRetryPolicy.default
        XCTAssertEqual(
            p.effectiveSeconds(
                for: .throttle, thermalLevel: .nominal), 30)
        XCTAssertEqual(
            p.effectiveSeconds(
                for: .throttle, thermalLevel: .watch),
            Int((30.0 * 1.25).rounded()))      // 38
        XCTAssertEqual(
            p.effectiveSeconds(
                for: .throttle, thermalLevel: .throttle),
            Int((30.0 * 1.5).rounded()))       // 45
        XCTAssertEqual(
            p.effectiveSeconds(
                for: .throttle, thermalLevel: .emergency),
            Int((30.0 * 2.0).rounded()))       // 60
    }

    // MARK: - 3. Custom policy honored

    func testCustomPolicyOverridesDefaults() {
        let p = QinaoRuntime.SurfaceRetryPolicy(
            throttleSeconds: 15,
            shadowLockSeconds: 45,
            toolCutSeconds: 90,
            memoryFreezeSeconds: 120,
            quarantineSeconds: 240)
        let decision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .throttle,
            coverageSeverity: .clean,
            auditRef: "ref.custom",
            routedBudget: budget(thermal: .nominal),
            retryPolicy: p)
        if case .deferToLater(let secs) = decision.substitute {
            XCTAssertEqual(secs, 15,
                "custom throttle-seconds honored")
        } else {
            XCTFail("expected deferToLater substitute")
        }
    }

    // MARK: - 4. Hot thermal escalates pass disclosure

    func testPassWithThrottleThermalEscalatesDisclosure() {
        let clean = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.pass",
            routedBudget: budget(thermal: .nominal),
            retryPolicy: .default)
        XCTAssertEqual(clean.disclosure, .minimal)

        let hot = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.pass",
            routedBudget: budget(thermal: .throttle),
            retryPolicy: .default)
        XCTAssertEqual(
            hot.disclosure, .reasoned,
            ".throttle thermal escalates minimal → reasoned")

        let critical = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.pass",
            routedBudget: budget(thermal: .emergency),
            retryPolicy: .default)
        XCTAssertEqual(
            critical.disclosure, .reasoned,
            ".emergency thermal escalates minimal → reasoned")
    }

    // MARK: - 5. Deferred maintenance escalates pass disclosure

    func testPassWithDeferredMaintenanceEscalatesDisclosure() {
        let decision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.pass",
            routedBudget: budget(
                thermal: .nominal,
                maintenance: .deferred),
            retryPolicy: .default)
        XCTAssertEqual(
            decision.disclosure, .reasoned,
            ".deferred maintenance escalates disclosure")
    }

    // MARK: - 6. Reason codes carry thermal + maintenance

    func testReasonCodesIncludeDeviceContext() {
        let decision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .throttle,
            coverageSeverity: .clean,
            auditRef: "ref.codes",
            routedBudget: budget(
                thermal: .throttle,
                maintenance: .deferred),
            retryPolicy: .default)
        XCTAssertTrue(
            decision.reasonCodes.contains("thermal:throttle"),
            "reasonCodes must carry thermal:<level>")
        XCTAssertTrue(
            decision.reasonCodes.contains("maintenance:deferred"),
            "reasonCodes must carry maintenance:<class>")
        XCTAssertTrue(
            decision.reasonCodes.contains("audit.severity:throttle"),
            "reasonCodes must still include audit.severity")
    }

    // MARK: - 7. No routedBudget → no device-side reason codes

    func testNoRoutedBudgetMeansNoDeviceCodes() {
        let decision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.nobudget",
            routedBudget: nil,
            retryPolicy: .default)
        XCTAssertFalse(
            decision.reasonCodes.contains {
                $0.hasPrefix("thermal:")
                    || $0.hasPrefix("maintenance:")
            },
            "no routedBudget → no device-side context codes")
    }
}
