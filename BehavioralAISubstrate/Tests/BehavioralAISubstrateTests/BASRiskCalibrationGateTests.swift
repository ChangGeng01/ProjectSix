import XCTest
@testable import BASPolicy

/// chapter 二百六十四 / M747 — `BASRiskCalibrationGate`
/// deploy-time gate coverage.
///
/// 附录 V Stage 4 Step 4 of 5. The gate holds the active bundle,
/// validates replacements, and provides effective thresholds for
/// L11 callers. This suite verifies:
///
///   1. Initial state is `.baseline`.
///   2. Replace succeeds with a well-formed monotonic-version
///      bundle (and emits typed audit codes).
///   3. Replace rejects malformed bundles.
///   4. Replace rejects non-monotonic versions.
///   5. Replace enforces supersedes-chain consistency.
///   6. Effective threshold returns base when no delta.
///   7. Effective threshold applies delta when present.
///   8. Effective threshold clamped to [0, 1].
///   9. `hasDelta` is correct.
///  10. Cross-stratum lookup returns the right delta.
final class BASRiskCalibrationGateTests: XCTestCase {

    // MARK: - Fixtures

    private func makeBundle(
        version: String,
        supersedes: String? = nil,
        deltas: [BASRiskCalibrationStratumDelta] = []
    ) -> BASRiskCalibrationBundle {
        BASRiskCalibrationBundle(
            bundleVersion: version,
            aggregateProvenanceRef: "agg:\(version)",
            strataDeltas: deltas,
            sovereignWarrantRef: "warrant:\(version)",
            supersedesBundleVersion: supersedes,
            summary: "test bundle \(version)")
    }

    private func makeStratumDelta(
        key: String,
        medium: Double = 0,
        high: Double = 0,
        extreme: Double = 0
    ) -> BASRiskCalibrationStratumDelta {
        BASRiskCalibrationStratumDelta(
            stratumKey: key,
            mediumThresholdDelta: medium,
            highThresholdDelta: high,
            extremeThresholdDelta: extreme,
            evidenceRowCount: 100)
    }

    // MARK: - 1. Initial state is baseline

    func testInitialStateIsBaseline() async throws {
        let gate = BASRiskCalibrationGate()
        let v = await gate.currentBundleVersion
        XCTAssertEqual(
            v, BASRiskCalibrationBundle.baselineVersion)
    }

    // MARK: - 2. Replace succeeds with well-formed bundle

    func testReplaceSucceedsWithWellFormedBundle()
        async throws
    {
        let gate = BASRiskCalibrationGate()
        let bundle = makeBundle(
            version: "v1.0.0",
            deltas: [
                makeStratumDelta(
                    key: "tone=angry|stake=high",
                    medium: 0.05),
                makeStratumDelta(
                    key: "tone=calm|stake=low",
                    medium: 0)
            ])
        let outcome = try await gate.replace(bundle)
        XCTAssertEqual(
            outcome.priorBundleVersion,
            BASRiskCalibrationBundle.baselineVersion)
        XCTAssertEqual(outcome.newBundleVersion, "v1.0.0")
        XCTAssertEqual(outcome.strataChanged, 1)  // calm has 0
        XCTAssertEqual(outcome.totalEvidenceRowCount, 200)
        // Audit codes typed
        XCTAssertTrue(
            outcome.auditReasonCodes.contains(where: {
                $0.contains("bundle-replaced:from-v0.0.0-baseline:to-v1.0.0")
            }))
        XCTAssertTrue(
            outcome.auditReasonCodes.contains(
                "risk-calibration:strata-changed:1"))
        XCTAssertTrue(
            outcome.auditReasonCodes.contains(
                "risk-calibration:evidence-rows:200"))
    }

    // MARK: - 3. Replace rejects malformed bundle

    func testReplaceRejectsMalformedBundle() async throws {
        let gate = BASRiskCalibrationGate()
        let malformed = BASRiskCalibrationBundle(
            bundleVersion: "",
            aggregateProvenanceRef: "agg",
            sovereignWarrantRef: "warrant")
        do {
            _ = try await gate.replace(malformed)
            XCTFail("expected malformedBundle error")
        } catch BASRiskCalibrationGate.ReplaceError
            .malformedBundle(let reason) {
            XCTAssertTrue(
                reason.contains("isWellFormed"),
                "expected reason to mention isWellFormed; got \(reason)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        // Gate's bundle unchanged
        let v = await gate.currentBundleVersion
        XCTAssertEqual(
            v, BASRiskCalibrationBundle.baselineVersion)
    }

    // MARK: - 4. Replace rejects non-monotonic version

    func testReplaceRejectsNonMonotonicVersion() async throws {
        let gate = BASRiskCalibrationGate()
        // First replace v2.0.0
        let v2 = makeBundle(version: "v2.0.0")
        _ = try await gate.replace(v2)
        // Now try to replace with v1.0.0 (older)
        let v1 = makeBundle(
            version: "v1.0.0",
            supersedes: "v2.0.0")
        do {
            _ = try await gate.replace(v1)
            XCTFail("expected nonMonotonicVersion error")
        } catch BASRiskCalibrationGate.ReplaceError
            .nonMonotonicVersion(let cur, let prop) {
            XCTAssertEqual(cur, "v2.0.0")
            XCTAssertEqual(prop, "v1.0.0")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        // Gate's bundle still v2.0.0
        let v = await gate.currentBundleVersion
        XCTAssertEqual(v, "v2.0.0")
    }

    // MARK: - 4b. audit policy-obs-misc LOW-1: v9 → v10 is monotonic (numeric, not lexical)

    func testReplaceAcceptsMultiDigitVersionBump() async throws {
        let gate = BASRiskCalibrationGate()
        _ = try await gate.replace(makeBundle(version: "v9.0.0"))
        // v10 > v9 numerically; the old raw String `>` rejected it ("v10" < "v9" lexically).
        let v10 = makeBundle(version: "v10.0.0", supersedes: "v9.0.0")
        let outcome = try await gate.replace(v10)
        XCTAssertNotNil(outcome)
        let cur = await gate.currentBundleVersion
        XCTAssertEqual(cur, "v10.0.0", "a legitimate v9→v10 upgrade must be accepted as monotonic")
    }

    // MARK: - 5. Replace enforces supersedes-chain consistency

    func testReplaceEnforcesSupersedesChain() async throws {
        let gate = BASRiskCalibrationGate()
        // Replace v1.0.0 from baseline (no supersedes is OK since
        // current is baseline).
        let v1 = makeBundle(version: "v1.0.0")
        _ = try await gate.replace(v1)

        // Now try v2.0.0 claiming to supersede v0.5.0 (mismatch).
        let v2WrongSupersedes = makeBundle(
            version: "v2.0.0",
            supersedes: "v0.5.0")
        do {
            _ = try await gate.replace(v2WrongSupersedes)
            XCTFail("expected supersedesMismatch")
        } catch BASRiskCalibrationGate.ReplaceError
            .supersedesMismatch(let cur, let prop) {
            XCTAssertEqual(cur, "v1.0.0")
            XCTAssertEqual(prop, "v0.5.0")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // Now replace v2.0.0 with correct supersedes.
        let v2Correct = makeBundle(
            version: "v2.0.0",
            supersedes: "v1.0.0")
        let outcome = try await gate.replace(v2Correct)
        XCTAssertEqual(outcome.newBundleVersion, "v2.0.0")
    }

    // MARK: - 6. Replace from baseline rejects nil-supersedes
    //              when current is non-baseline

    func testReplaceRequiresSupersedesWhenNonBaseline()
        async throws
    {
        let gate = BASRiskCalibrationGate()
        let v1 = makeBundle(version: "v1.0.0")
        _ = try await gate.replace(v1)

        // Try v2.0.0 with NO supersedes — should fail since
        // current is not baseline.
        let v2NoSupersedes = makeBundle(version: "v2.0.0")
        do {
            _ = try await gate.replace(v2NoSupersedes)
            XCTFail("expected supersedesMismatch")
        } catch BASRiskCalibrationGate.ReplaceError
            .supersedesMismatch(let cur, let prop) {
            XCTAssertEqual(cur, "v1.0.0")
            XCTAssertEqual(prop, "(nil)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 7. Effective threshold returns base when no delta

    func testEffectiveThresholdReturnsBaseWhenNoDelta()
        async throws
    {
        let gate = BASRiskCalibrationGate()
        let result = await gate.effectiveMediumThreshold(
            forStratumKey: "tone=missing",
            base: 0.5)
        XCTAssertEqual(result, 0.5)
    }

    // MARK: - 8. Effective threshold applies delta

    func testEffectiveThresholdAppliesDelta() async throws {
        let gate = BASRiskCalibrationGate()
        let bundle = makeBundle(
            version: "v1.0.0",
            deltas: [
                makeStratumDelta(
                    key: "tone=angry",
                    medium: 0.10,
                    high: -0.05,
                    extreme: 0.15)
            ])
        _ = try await gate.replace(bundle)
        let medium = await gate.effectiveMediumThreshold(
            forStratumKey: "tone=angry", base: 0.5)
        let high = await gate.effectiveHighThreshold(
            forStratumKey: "tone=angry", base: 0.7)
        let extreme = await gate.effectiveExtremeThreshold(
            forStratumKey: "tone=angry", base: 0.85)
        XCTAssertEqual(medium, 0.6, accuracy: 0.0001)
        XCTAssertEqual(high, 0.65, accuracy: 0.0001)
        XCTAssertEqual(extreme, 1.0, accuracy: 0.0001)  // clamp
    }

    // MARK: - 9. Effective threshold clamped to [0, 1]

    func testEffectiveThresholdClampedToZeroToOne() async throws {
        let gate = BASRiskCalibrationGate()
        let bundle = makeBundle(
            version: "v1.0.0",
            deltas: [
                makeStratumDelta(
                    key: "tone=test",
                    medium: 0.25,
                    high: -0.25,
                    extreme: 0.25)
            ])
        _ = try await gate.replace(bundle)
        // base=0.9 + delta=0.25 → 1.15 → clamps to 1.0
        let high = await gate.effectiveMediumThreshold(
            forStratumKey: "tone=test", base: 0.9)
        XCTAssertEqual(high, 1.0)
        // base=0.1 + delta=-0.25 → -0.15 → clamps to 0.0
        let low = await gate.effectiveHighThreshold(
            forStratumKey: "tone=test", base: 0.1)
        XCTAssertEqual(low, 0.0)
    }

    // MARK: - 10. hasDelta correct

    func testHasDeltaCorrect() async throws {
        let gate = BASRiskCalibrationGate()
        let bundle = makeBundle(
            version: "v1.0.0",
            deltas: [
                makeStratumDelta(key: "tone=A", medium: 0.05),
                makeStratumDelta(key: "tone=B")
            ])
        _ = try await gate.replace(bundle)
        let hasA = await gate.hasDelta(forStratumKey: "tone=A")
        let hasB = await gate.hasDelta(forStratumKey: "tone=B")
        let hasC = await gate.hasDelta(forStratumKey: "tone=C")
        XCTAssertTrue(hasA)
        XCTAssertTrue(hasB)  // present even if all-zero delta
        XCTAssertFalse(hasC)
    }

    // MARK: - 11. Cross-stratum lookup

    func testCrossStratumLookupReturnsRightDelta() async throws {
        let gate = BASRiskCalibrationGate()
        let bundle = makeBundle(
            version: "v1.0.0",
            deltas: [
                makeStratumDelta(
                    key: "tone=angry|stake=high",
                    medium: 0.05),
                makeStratumDelta(
                    key: "tone=calm|stake=low",
                    medium: -0.05)
            ])
        _ = try await gate.replace(bundle)
        let angry = await gate.effectiveMediumThreshold(
            forStratumKey: "tone=angry|stake=high", base: 0.5)
        let calm = await gate.effectiveMediumThreshold(
            forStratumKey: "tone=calm|stake=low", base: 0.5)
        let unknown = await gate.effectiveMediumThreshold(
            forStratumKey: "tone=unknown|stake=mid", base: 0.5)
        XCTAssertEqual(angry, 0.55, accuracy: 0.0001)
        XCTAssertEqual(calm, 0.45, accuracy: 0.0001)
        XCTAssertEqual(unknown, 0.5)
    }

    // MARK: - 12. Replace from baseline allows nil-supersedes

    func testReplaceFromBaselineAllowsNilSupersedes() async throws {
        let gate = BASRiskCalibrationGate()  // baseline
        let v1 = makeBundle(version: "v1.0.0")  // no supersedes
        let outcome = try await gate.replace(v1)
        XCTAssertEqual(outcome.newBundleVersion, "v1.0.0")
    }

    // MARK: - 13. Replace from existing init bundle works

    func testReplaceWithExplicitInitialBundle() async throws {
        let initial = makeBundle(version: "v1.0.0")
        let gate = BASRiskCalibrationGate(initial: initial)
        let v = await gate.currentBundleVersion
        XCTAssertEqual(v, "v1.0.0")

        let v2 = makeBundle(
            version: "v2.0.0",
            supersedes: "v1.0.0")
        _ = try await gate.replace(v2)
        let after = await gate.currentBundleVersion
        XCTAssertEqual(after, "v2.0.0")
    }
}
