import XCTest
@testable import BASPolicy

/// chapter 二百六十五 / M755 — per-stratum sub-model schema +
/// registry coverage.
final class BASRiskCalibrationStratumSubModelTests: XCTestCase {

    // MARK: - Fixtures

    private func makeRef(
        stratumKey: String = "tone=angry|stake=high",
        modelVersion: String = "v0.1",
        supersedes: String? = nil,
        metric: Double = 0.85
    ) -> BASRiskCalibrationStratumSubModelRef {
        BASRiskCalibrationStratumSubModelRef(
            stratumKey: stratumKey,
            modelArtifactRef:
                "mlpackage:risk-stratum-\(stratumKey).mlpackage",
            modelVersion: modelVersion,
            trainedFromProvenanceRef: "agg:rollup-2026-04",
            evidenceRowCount: 1000,
            evaluationMetric: metric,
            approvedByWarrantRef: "warrant:\(modelVersion)",
            supersedesModelVersion: supersedes,
            summary: "test ref")
    }

    // MARK: - 1. Schema version pinned

    func testSchemaVersionPinned() {
        XCTAssertEqual(
            BASRiskCalibrationStratumSubModelRef
                .currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. evaluationMetric clamped to [0, 1]

    func testEvaluationMetricClamps() {
        let high = makeRef(metric: 5.0)
        XCTAssertEqual(high.evaluationMetric, 1.0)
        let low = makeRef(metric: -3.0)
        XCTAssertEqual(low.evaluationMetric, 0.0)
        let nan = makeRef(metric: .nan)
        XCTAssertEqual(nan.evaluationMetric, 0.0)
    }

    // MARK: - 3. evidenceRowCount clamped non-negative

    func testEvidenceRowCountClampsNonNegative() {
        let ref = BASRiskCalibrationStratumSubModelRef(
            stratumKey: "tone=angry",
            modelArtifactRef: "mlpackage:test.mlpackage",
            modelVersion: "v0.1",
            trainedFromProvenanceRef: "agg:test",
            evidenceRowCount: -100,
            evaluationMetric: 0.8,
            approvedByWarrantRef: "warrant:test")
        XCTAssertEqual(ref.evidenceRowCount, 0)
    }

    // MARK: - 4. isWellFormed enforces required fields + metric

    func testIsWellFormed() {
        let good = makeRef()
        XCTAssertTrue(good.isWellFormed)

        let lowMetric = makeRef(metric: 0.40)  // below 0.50
        XCTAssertFalse(lowMetric.isWellFormed)

        let emptyArtifact = BASRiskCalibrationStratumSubModelRef(
            stratumKey: "tone=angry",
            modelArtifactRef: "",
            modelVersion: "v0.1",
            trainedFromProvenanceRef: "agg:test",
            evidenceRowCount: 100,
            evaluationMetric: 0.8,
            approvedByWarrantRef: "warrant:test")
        XCTAssertFalse(emptyArtifact.isWellFormed)
    }

    // MARK: - 5. Codable round-trip preserves all fields

    func testCodableRoundTripPreservesFields() throws {
        let original = makeRef()
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASRiskCalibrationStratumSubModelRef.self,
            from: data)
        XCTAssertEqual(restored, original)
    }

    // MARK: - 6. Registry empty initial state

    func testRegistryEmptyInitial() async {
        let registry = BASRiskCalibrationSubModelRegistry()
        let count = await registry.count
        let keys = await registry.registeredStratumKeys
        XCTAssertEqual(count, 0)
        XCTAssertEqual(keys, [])
    }

    // MARK: - 7. Register first ref succeeds

    func testRegisterFirstRefSucceeds() async throws {
        let registry = BASRiskCalibrationSubModelRegistry()
        let ref = makeRef()
        let outcome = try await registry.register(ref)
        XCTAssertNil(outcome.priorModelVersion)
        XCTAssertEqual(outcome.newModelVersion, "v0.1")
        XCTAssertEqual(
            outcome.stratumKey,
            "tone=angry|stake=high")
        // Audit codes typed
        XCTAssertTrue(
            outcome.auditReasonCodes.contains(where: {
                $0.contains(
                    "submodel-registry:registered:")
                && $0.contains("version-v0.1")
            }))
    }

    // MARK: - 8. Register malformed ref throws

    func testRegisterMalformedRefThrows() async {
        let registry = BASRiskCalibrationSubModelRegistry()
        let bad = makeRef(metric: 0.40)  // below threshold
        do {
            _ = try await registry.register(bad)
            XCTFail("expected malformedRef")
        } catch BASRiskCalibrationSubModelRegistry
            .RegistryError.malformedRef {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 9. Register non-monotonic version throws

    func testRegisterNonMonotonicVersionThrows() async throws {
        let registry = BASRiskCalibrationSubModelRegistry()
        // Register v0.2 first
        let v2 = makeRef(modelVersion: "v0.2")
        _ = try await registry.register(v2)
        // Try to register v0.1 (older)
        let v1 = makeRef(
            modelVersion: "v0.1",
            supersedes: "v0.2")
        do {
            _ = try await registry.register(v1)
            XCTFail("expected nonMonotonicModelVersion")
        } catch BASRiskCalibrationSubModelRegistry
            .RegistryError.nonMonotonicModelVersion(
                let cur, let prop, let key) {
            XCTAssertEqual(cur, "v0.2")
            XCTAssertEqual(prop, "v0.1")
            XCTAssertEqual(key, "tone=angry|stake=high")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 10. Register with supersedes-mismatch throws

    func testRegisterSupersedesMismatch() async throws {
        let registry = BASRiskCalibrationSubModelRegistry()
        let v1 = makeRef(modelVersion: "v0.1")
        _ = try await registry.register(v1)
        // Try v0.2 claiming to supersede v0.5 (mismatch)
        let v2Wrong = makeRef(
            modelVersion: "v0.2",
            supersedes: "v0.5")
        do {
            _ = try await registry.register(v2Wrong)
            XCTFail("expected supersedesMismatch")
        } catch BASRiskCalibrationSubModelRegistry
            .RegistryError.supersedesMismatch(
                let cur, let prop, _) {
            XCTAssertEqual(cur, "v0.1")
            XCTAssertEqual(prop, "v0.5")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 11. Register with no supersedes when prior exists
    //              throws

    func testRegisterRequiresSupersedesWhenPriorExists()
        async throws
    {
        let registry = BASRiskCalibrationSubModelRegistry()
        let v1 = makeRef(modelVersion: "v0.1")
        _ = try await registry.register(v1)
        // Try v0.2 with NO supersedes
        let v2 = makeRef(modelVersion: "v0.2")
        do {
            _ = try await registry.register(v2)
            XCTFail("expected supersedesMismatch")
        } catch BASRiskCalibrationSubModelRegistry
            .RegistryError.supersedesMismatch(
                let cur, let prop, _) {
            XCTAssertEqual(cur, "v0.1")
            XCTAssertEqual(prop, "(nil)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 12. Multiple strata coexist

    func testMultipleStrataCoexist() async throws {
        let registry = BASRiskCalibrationSubModelRegistry()
        let angry = makeRef(
            stratumKey: "tone=angry|stake=high")
        let calm = makeRef(
            stratumKey: "tone=calm|stake=low")
        _ = try await registry.register(angry)
        _ = try await registry.register(calm)
        let count = await registry.count
        XCTAssertEqual(count, 2)
        let keys = await registry.registeredStratumKeys
        XCTAssertEqual(keys.count, 2)
    }

    // MARK: - 13. ref(forStratumKey:) lookup

    func testRefLookup() async throws {
        let registry = BASRiskCalibrationSubModelRegistry()
        let ref = makeRef()
        _ = try await registry.register(ref)
        let fetched = await registry.ref(
            forStratumKey: "tone=angry|stake=high")
        XCTAssertEqual(fetched, ref)
        let missing = await registry.ref(
            forStratumKey: "tone=missing")
        XCTAssertNil(missing)
    }

    // MARK: - 14. Successful update emits supersedes audit code

    func testSuccessfulUpdateEmitsSupersedesAuditCode() async
        throws
    {
        let registry = BASRiskCalibrationSubModelRegistry()
        let v1 = makeRef(modelVersion: "v0.1")
        _ = try await registry.register(v1)
        let v2 = makeRef(
            modelVersion: "v0.2", supersedes: "v0.1")
        let outcome = try await registry.register(v2)
        XCTAssertEqual(outcome.priorModelVersion, "v0.1")
        XCTAssertTrue(
            outcome.auditReasonCodes.contains(
                "submodel-registry:supersedes:v0.1"))
    }
}
