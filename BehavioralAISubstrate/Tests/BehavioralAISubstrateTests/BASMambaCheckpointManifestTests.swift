// MARK: - BASMambaCheckpointManifestTests — chapter 四百 / M926

import XCTest
@testable import BASRuntimeCore

final class BASMambaCheckpointManifestTests: XCTestCase {

    private func makeManifest(
        checkpointID: String = "ckpt-1",
        weightsPath: String = "model.safetensors",
        epochNumber: Int = 0,
        metrics: [BASMambaCheckpointMetric] = []
    ) -> BASMambaCheckpointManifest {
        BASMambaCheckpointManifest(
            checkpointID: checkpointID,
            architectureSpec:
                BASMambaModelArchitectureSpec.preset(
                    for: .small),
            objective: .nextEventKind,
            corpusTag: "10h-iphone-stress",
            weightsPath: weightsPath,
            status: .completed,
            epochNumber: epochNumber,
            metrics: metrics,
            emittedAtMs: 1_700_000_000_000)
    }

    func testSchemaVersionPinned() {
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.schemaVersion,
            "M926.1.0.0")
    }

    func testCanonicalMetricNamesPinned() {
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema
                .canonicalMetricNames.count, 5)
        XCTAssertTrue(
            BASMambaCheckpointManifestSchema
                .canonicalMetricNames.contains("trainLoss"))
        XCTAssertTrue(
            BASMambaCheckpointManifestSchema
                .canonicalMetricNames.contains("valLoss"))
        XCTAssertTrue(
            BASMambaCheckpointManifestSchema
                .canonicalMetricNames.contains("perplexity"))
    }

    func testStatusEnumAllCases() {
        XCTAssertEqual(
            BASMambaCheckpointStatus.allCases.count, 3)
    }

    // MARK: - Validation

    func testValidatorAcceptsWellFormed() {
        let manifest = makeManifest()
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.validate(
                manifest: manifest),
            .valid)
    }

    func testValidatorRejectsMismatchedSchemaVersion() {
        let manifest = BASMambaCheckpointManifest(
            schemaVersion: "stale.1.0.0",
            checkpointID: "ckpt-1",
            architectureSpec:
                BASMambaModelArchitectureSpec.preset(
                    for: .small),
            objective: .nextEventKind,
            corpusTag: "tag",
            weightsPath: "w",
            status: .completed,
            epochNumber: 0,
            emittedAtMs: 1)
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.validate(
                manifest: manifest),
            .invalid(reason: .mismatchedSchemaVersion))
    }

    func testValidatorRejectsEmptyCheckpointID() {
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.validate(
                manifest: makeManifest(
                    checkpointID: "  ")),
            .invalid(reason: .emptyCheckpointID))
    }

    func testValidatorRejectsEmptyWeightsPath() {
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.validate(
                manifest: makeManifest(weightsPath: "")),
            .invalid(reason: .emptyWeightsPath))
    }

    func testValidatorRejectsNegativeEpoch() {
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.validate(
                manifest: makeManifest(epochNumber: -1)),
            .invalid(reason: .negativeEpochNumber))
    }

    func testValidatorRejectsDuplicateMetricNames() {
        let metrics = [
            BASMambaCheckpointMetric(
                metricName: "valLoss",
                value: 1.5, sampleCount: 100),
            BASMambaCheckpointMetric(
                metricName: "valLoss",
                value: 2.0, sampleCount: 100)
        ]
        XCTAssertEqual(
            BASMambaCheckpointManifestSchema.validate(
                manifest: makeManifest(metrics: metrics)),
            .invalid(reason: .duplicateMetricName))
    }

    // MARK: - Metric lookup

    func testMetricLookupByName() {
        let metrics = [
            BASMambaCheckpointMetric(
                metricName: "valLoss",
                value: 1.234, sampleCount: 1000),
            BASMambaCheckpointMetric(
                metricName: "accuracy",
                value: 0.95, sampleCount: 1000)
        ]
        let manifest = makeManifest(metrics: metrics)
        XCTAssertEqual(
            manifest.metric(named: "valLoss")?.value,
            1.234)
        XCTAssertEqual(
            manifest.metric(named: "accuracy")?.value,
            0.95)
        XCTAssertNil(
            manifest.metric(named: "missingMetric"))
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let manifest = makeManifest(
            metrics: [
                BASMambaCheckpointMetric(
                    metricName: "valLoss",
                    value: 1.5, sampleCount: 100),
                BASMambaCheckpointMetric(
                    metricName: "perplexity",
                    value: 4.5, sampleCount: 100)
            ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(manifest)
        let decoded = try decoder.decode(
            BASMambaCheckpointManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }
}
