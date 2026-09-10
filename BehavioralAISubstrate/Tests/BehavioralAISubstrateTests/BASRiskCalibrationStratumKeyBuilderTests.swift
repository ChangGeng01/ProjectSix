import XCTest
@testable import BASPolicy

/// chapter 二百七十二 / M759 — stratum-key builder coverage +
/// L11 production-wire integration test.
///
/// Closes the production-wire gap I named in self-assessment:
/// without a canonical key-builder shared by aggregator + L11
/// gate consumers, byte-equal keys couldn't be guaranteed across
/// the deploy boundary. This suite verifies:
///
///   1. Canonical format (`"<key>=<value>|..."` sorted alpha)
///   2. Empty / whitespace values resolve to `_unknown` sentinel
///   3. Cross-language parity: Swift key matches Python
///      aggregator output for the same input
///   4. Deterministic regardless of dict insertion order
///   5. **Integration test**: bundle deploy → key-builder
///      produces canonical key → gate.effectiveMediumThreshold
///      returns base + delta (not just base) — proves the chain
///      actually wires
final class BASRiskCalibrationStratumKeyBuilderTests:
    XCTestCase
{
    // MARK: - 1. Canonical format

    func testCanonicalFormat() {
        let key = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "tone": "angry",
                "stake": "high",
                "confidant": "public"
            ])
        XCTAssertEqual(
            key, "confidant=public|stake=high|tone=angry")
    }

    // MARK: - 2. Sorted alphabetically (deterministic)

    func testKeysSortedAlphabetically() {
        // Different dictionary insertion orders produce
        // identical output.
        let k1 = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "z-key": "z",
                "a-key": "a",
                "m-key": "m"
            ])
        let k2 = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "m-key": "m",
                "a-key": "a",
                "z-key": "z"
            ])
        XCTAssertEqual(k1, k2)
        XCTAssertEqual(k1, "a-key=a|m-key=m|z-key=z")
    }

    // MARK: - 3. Empty value → _unknown sentinel

    func testEmptyValueResolvesToUnknownSentinel() {
        let key = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "tone": "",
                "stake": "high"
            ])
        XCTAssertEqual(
            key, "stake=high|tone=_unknown")
    }

    // MARK: - 4. Whitespace-only value → _unknown sentinel

    func testWhitespaceValueResolvesToUnknownSentinel() {
        let key = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "tone": "   ",
                "stake": "high"
            ])
        XCTAssertEqual(
            key, "stake=high|tone=_unknown")
    }

    // MARK: - 5. Trimmed value (whitespace stripped)

    func testValueTrimmedOnEdges() {
        let key = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "tone": "  angry  ",
                "stake": "high"
            ])
        XCTAssertEqual(
            key, "stake=high|tone=angry")
    }

    // MARK: - 6. canonicalThreeDimensionKey convenience

    func testCanonicalThreeDimensionKey() {
        let key = BASRiskCalibrationStratumKeyBuilder
            .canonicalThreeDimensionKey(
                tone: "angry",
                stake: "high",
                confidant: "public")
        XCTAssertEqual(
            key, "confidant=public|stake=high|tone=angry")
    }

    // MARK: - 7. Cross-language parity vs Python aggregator

    /// chapter 二百六十二 aggregator (Python) emits stratum keys
    /// in the canonical `"<key>=<value>|..."` sorted-alpha format.
    /// This test pins byte-equal output for the same input across
    /// languages — drift here = silent gate-lookup misses.
    func testCrossLanguageParityWithPythonAggregator() {
        // The Python aggregator's stratum key format (verified
        // by chapter 二百六十二 smoke test):
        //
        //   sig = {"tone": "angry", "stake": "high",
        //          "confidant": "public"}
        //   stratum_key = "|".join(
        //       f"{k}={key_dict[k]}" for k in sorted(key_dict))
        //
        // → "confidant=public|stake=high|tone=angry"
        //
        // Swift builder MUST produce the same output for the
        // same input.
        let pythonOutput =
            "confidant=public|stake=high|tone=angry"
        let swiftKey = BASRiskCalibrationStratumKeyBuilder.key(
            from: [
                "tone": "angry",
                "stake": "high",
                "confidant": "public"
            ])
        XCTAssertEqual(
            swiftKey, pythonOutput,
            "Swift key MUST be byte-equal to Python aggregator " +
            "output. Drift here = silent gate-lookup miss.")
    }

    // MARK: - 8. _unknown sentinel matches Python format

    /// Python aggregator emits `_unknown` for missing dimension
    /// values. Swift builder MUST use the same sentinel so
    /// cross-language keys collide on missing data (operators
    /// see one "_unknown" stratum aggregated rather than per-
    /// row leakage).
    func testUnknownSentinelMatchesPython() {
        XCTAssertEqual(
            BASRiskCalibrationStratumKeyBuilder
                .missingValueSentinel,
            "_unknown")
    }

    // MARK: - 9. INTEGRATION TEST: bundle deploy → effective
    //              threshold change

    /// **THE PRODUCTION-WIRE PROOF**.
    ///
    /// This test demonstrates the full chain:
    ///   1. Operator authors a `BASRiskCalibrationBundle` with
    ///      a per-stratum delta keyed via the canonical builder.
    ///   2. Host deploys the bundle via `gate.replace(_:)`.
    ///   3. Per-turn L11 host code constructs the same stratum
    ///      key using the canonical builder.
    ///   4. `gate.effectiveMediumThreshold(...)` returns
    ///      base + delta — NOT just base.
    ///
    /// Without the key builder, step 1 + step 3 keys could drift,
    /// silently breaking the lookup. This test pins them
    /// byte-equal.
    func testIntegrationBundleDeployChangesEffectiveThreshold()
        async throws
    {
        // Step 1: operator authors bundle with canonical key
        let stratumKey = BASRiskCalibrationStratumKeyBuilder
            .canonicalThreeDimensionKey(
                tone: "angry",
                stake: "high",
                confidant: "public")
        let bundle = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:test",
            strataDeltas: [
                BASRiskCalibrationStratumDelta(
                    stratumKey: stratumKey,
                    mediumThresholdDelta: -0.10,
                    highThresholdDelta: 0.05,
                    extremeThresholdDelta: 0,
                    evidenceRowCount: 500,
                    reasonCodes: ["test"])
            ],
            sovereignWarrantRef: "warrant:test")

        // Step 2: host deploys via gate.replace
        let gate = BASRiskCalibrationGate()
        let outcome = try await gate.replace(bundle)
        XCTAssertEqual(outcome.newBundleVersion, "v1.0.0")
        XCTAssertEqual(outcome.strataChanged, 1)

        // Step 3: per-turn host code constructs the SAME
        // stratum key using the SAME canonical builder
        let perTurnKey = BASRiskCalibrationStratumKeyBuilder
            .canonicalThreeDimensionKey(
                tone: "angry",
                stake: "high",
                confidant: "public")
        XCTAssertEqual(
            perTurnKey, stratumKey,
            "key builder must produce identical output for " +
            "identical input — both sides")

        // Step 4: gate returns base + delta (proving the chain
        // is wired, not just typed)
        let baseMedium = 0.50
        let baseHigh = 0.70
        let baseExtreme = 0.85
        let effectiveMedium = await gate
            .effectiveMediumThreshold(
                forStratumKey: perTurnKey,
                base: baseMedium)
        let effectiveHigh = await gate
            .effectiveHighThreshold(
                forStratumKey: perTurnKey,
                base: baseHigh)
        let effectiveExtreme = await gate
            .effectiveExtremeThreshold(
                forStratumKey: perTurnKey,
                base: baseExtreme)

        // Medium: 0.50 + (-0.10) = 0.40
        XCTAssertEqual(effectiveMedium, 0.40, accuracy: 0.001)
        // High: 0.70 + 0.05 = 0.75
        XCTAssertEqual(effectiveHigh, 0.75, accuracy: 0.001)
        // Extreme: 0.85 + 0 = 0.85 (no change)
        XCTAssertEqual(effectiveExtreme, 0.85, accuracy: 0.001)

        // Negative case: a stratum NOT in the bundle returns
        // the base threshold unchanged (proves the gate's
        // graceful-fallback path).
        let unknownStratumKey = BASRiskCalibrationStratumKeyBuilder
            .canonicalThreeDimensionKey(
                tone: "calm",
                stake: "low",
                confidant: "self")
        let baseEffective = await gate
            .effectiveMediumThreshold(
                forStratumKey: unknownStratumKey,
                base: baseMedium)
        XCTAssertEqual(
            baseEffective, baseMedium, accuracy: 0.001,
            "stratum NOT in bundle returns base unchanged")
    }

    // MARK: - 10. INTEGRATION: cross-deploy version monotonicity

    /// Demonstrates that a v2 bundle with a different stratum
    /// key replaces v1 cleanly + the new key's delta is
    /// applied while v1's stratum key falls back to base.
    func testIntegrationCrossDeployVersionReplacement()
        async throws
    {
        let gate = BASRiskCalibrationGate()

        // Deploy v1 with angry/high stratum delta
        let key1 = BASRiskCalibrationStratumKeyBuilder
            .canonicalThreeDimensionKey(
                tone: "angry",
                stake: "high",
                confidant: "public")
        let v1 = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            aggregateProvenanceRef: "agg:v1",
            strataDeltas: [
                BASRiskCalibrationStratumDelta(
                    stratumKey: key1,
                    mediumThresholdDelta: -0.10)
            ],
            sovereignWarrantRef: "warrant:v1")
        _ = try await gate.replace(v1)

        // Verify v1 effect
        let v1Effective = await gate
            .effectiveMediumThreshold(
                forStratumKey: key1, base: 0.5)
        XCTAssertEqual(v1Effective, 0.4, accuracy: 0.001)

        // Deploy v2 with DIFFERENT stratum (calm/low/self)
        let key2 = BASRiskCalibrationStratumKeyBuilder
            .canonicalThreeDimensionKey(
                tone: "calm",
                stake: "low",
                confidant: "self")
        let v2 = BASRiskCalibrationBundle(
            bundleVersion: "v1.1.0",
            aggregateProvenanceRef: "agg:v2",
            strataDeltas: [
                BASRiskCalibrationStratumDelta(
                    stratumKey: key2,
                    mediumThresholdDelta: 0.15)
            ],
            sovereignWarrantRef: "warrant:v2",
            supersedesBundleVersion: "v1.0.0")
        _ = try await gate.replace(v2)

        // After v2 deploy: v1 stratum key returns base
        // (delta not in v2)
        let v1KeyAfterV2 = await gate
            .effectiveMediumThreshold(
                forStratumKey: key1, base: 0.5)
        XCTAssertEqual(
            v1KeyAfterV2, 0.5, accuracy: 0.001,
            "v1 stratum's delta no longer applies after v2 " +
            "deploy")

        // v2 stratum key returns base + delta
        let v2KeyEffective = await gate
            .effectiveMediumThreshold(
                forStratumKey: key2, base: 0.5)
        XCTAssertEqual(
            v2KeyEffective, 0.65, accuracy: 0.001,
            "v2 stratum's delta now applies")
    }
}
