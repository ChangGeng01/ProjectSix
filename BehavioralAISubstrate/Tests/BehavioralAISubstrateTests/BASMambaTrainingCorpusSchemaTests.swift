// MARK: - BASMambaTrainingCorpusSchemaTests — chapter 四百 / M917

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASMambaTrainingCorpusSchemaTests: XCTestCase {

    // MARK: - Schema version pin

    func testSchemaVersionIsPinned() {
        XCTAssertEqual(
            BASMambaTrainingCorpusSchema.schemaVersion,
            "M917.1.0.0",
            "Schema version is the canonical pin Python " +
            "trainer asserts on load。Bumping requires " +
            "updating this test + downstream parsers。")
    }

    // MARK: - Feature spec defaults

    func testFeatureSpecDefaultsArePinned() {
        let spec = BASMambaTrainingFeatureSpec()
        XCTAssertEqual(spec.inputDim, 32)
        XCTAssertEqual(spec.sequenceLength, 512)
        XCTAssertEqual(spec.windowStride, 256)
        XCTAssertEqual(
            spec.truncationStrategy, .slidingWindow)
        XCTAssertFalse(spec.maskInternalSignals)
    }

    func testFeatureSpecCodableRoundTrip() throws {
        let spec = BASMambaTrainingFeatureSpec(
            inputDim: 64,
            sequenceLength: 1024,
            truncationStrategy: .dropTail,
            windowStride: 512,
            maskInternalSignals: true)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(spec)
        let decoded = try decoder.decode(
            BASMambaTrainingFeatureSpec.self,
            from: data)
        XCTAssertEqual(decoded, spec)
    }

    func testTruncationStrategyAllCases() {
        XCTAssertEqual(
            BASMambaTrainingFeatureSpec
                .TruncationStrategy.allCases.count, 3)
    }

    // MARK: - Manifest

    func testManifestRoundTrip() throws {
        let manifest = BASMambaTrainingCorpusManifest(
            featureSpec: BASMambaTrainingFeatureSpec(),
            shardPaths: ["shard-0.jsonl", "shard-1.jsonl"],
            totalRowCount: 2_000_000,
            emittedAtMs: 1_700_000_000_000,
            corpusTag: "10h-iphone-stress-2026-05-08")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(manifest)
        let decoded = try decoder.decode(
            BASMambaTrainingCorpusManifest.self,
            from: data)
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(
            decoded.schemaVersion,
            BASMambaTrainingCorpusSchema.schemaVersion)
    }

    // MARK: - Validator

    private func makeDatum(
        eventID: String = "ev-1",
        sessionID: String = "session-1",
        timestampMs: Int64 = 1_700_000_000_000,
        stateBeforeID: String? = nil,
        stateAfterID: String? = nil,
        stateBefore: BASUserState? = nil,
        stateAfter: BASUserState? = nil
    ) -> BASTrainingDatum {
        let event = BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 1,
            stateBeforeID: stateBeforeID,
            stateAfterID: stateAfterID,
            actions: ["test"])
        return BASTrainingDatum(
            event: event,
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            exportedAtMs: 1_700_000_000_000)
    }

    func testValidatorAcceptsValidDatum() {
        let result = BASMambaTrainingValidator.validate(
            datum: makeDatum())
        XCTAssertEqual(result, .valid)
    }

    func testValidatorRejectsEmptyEventID() {
        let result = BASMambaTrainingValidator.validate(
            datum: makeDatum(eventID: ""))
        XCTAssertEqual(result,
            .invalid(reason: .missingRequiredEventField))
    }

    func testValidatorRejectsWhitespaceOnlyEventID() {
        let result = BASMambaTrainingValidator.validate(
            datum: makeDatum(eventID: "   "))
        XCTAssertEqual(result,
            .invalid(reason: .missingRequiredEventField))
    }

    func testValidatorRejectsEmptySessionID() {
        let result = BASMambaTrainingValidator.validate(
            datum: makeDatum(sessionID: ""))
        XCTAssertEqual(result,
            .invalid(reason: .emptySessionID))
    }

    func testValidatorRejectsNonPositiveTimestamp() {
        let result1 = BASMambaTrainingValidator.validate(
            datum: makeDatum(timestampMs: 0))
        XCTAssertEqual(result1,
            .invalid(reason: .nonPositiveTimestamp))

        let result2 = BASMambaTrainingValidator.validate(
            datum: makeDatum(timestampMs: -100))
        XCTAssertEqual(result2,
            .invalid(reason: .nonPositiveTimestamp))
    }

    func testCorpusValidatorAggregatesFailures() {
        let corpus = [
            makeDatum(),  // valid
            makeDatum(),  // valid
            makeDatum(eventID: ""),  // missing eventID
            makeDatum(sessionID: ""),  // empty session
            makeDatum(timestampMs: 0),  // bad timestamp
            makeDatum(timestampMs: -1)  // bad timestamp
        ]
        let result = BASMambaTrainingValidator.validate(
            corpus: corpus)

        XCTAssertEqual(result.valid, 2)
        XCTAssertEqual(
            result.failures[.missingRequiredEventField], 1)
        XCTAssertEqual(
            result.failures[.emptySessionID], 1)
        XCTAssertEqual(
            result.failures[.nonPositiveTimestamp], 2)
    }
}
