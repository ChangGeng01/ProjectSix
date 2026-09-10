// MARK: - BASCoreMLConversionContractTests — chapter 四百 / M918

import XCTest
@testable import BASRuntimeCore

final class BASCoreMLConversionContractTests: XCTestCase {

    // MARK: - Helpers

    private func makeValidRequest(
        kind: BASCoreMLModelKind = .chenglu,
        tokenizerConfigPath: String? = nil
    ) -> BASCoreMLConversionRequest {
        let input = BASCoreMLConversionInput(
            mlxWeightsPath: "weights.mlx",
            tokenizerConfigPath: tokenizerConfigPath,
            modelKind: kind,
            sourceVersionTag: "v1")
        let output = BASCoreMLConversionOutput(
            mlpackagePath: "model.mlpackage",
            targetComputeUnit: .all,
            inputDimensions: ["x": [1, 32]],
            outputDimensions: ["y": [1, 8]],
            precision: .float16)
        let parity = BASCoreMLConversionParitySpec(
            testCasePath: "parity.jsonl",
            testCaseCount: 100)
        return BASCoreMLConversionRequest(
            input: input,
            output: output,
            parity: parity,
            requestedAtMs: 1_700_000_000_000)
    }

    // MARK: - Contract version pin

    func testContractVersionPinned() {
        XCTAssertEqual(
            BASCoreMLConversionContract.contractVersion,
            "M918.1.0.0")
    }

    func testToleranceDefaultsPinned() {
        XCTAssertEqual(
            BASCoreMLConversionContract
                .defaultMaxAbsErrorTolerance,
            1e-3)
        XCTAssertEqual(
            BASCoreMLConversionContract
                .defaultMeanAbsErrorTolerance,
            1e-4)
    }

    // MARK: - Enum contracts

    func testModelKindRawValuesPinned() {
        XCTAssertEqual(
            BASCoreMLModelKind.chenglu.rawValue, "chenglu")
        XCTAssertEqual(
            BASCoreMLModelKind.mamba.rawValue, "mamba")
        XCTAssertEqual(
            BASCoreMLModelKind.userStateReducer.rawValue,
            "userStateReducer")
        XCTAssertEqual(
            BASCoreMLModelKind.knowledgeGraphExtractor
                .rawValue,
            "knowledgeGraphExtractor")
    }

    func testComputeUnitRawValuesPinned() {
        XCTAssertEqual(
            BASCoreMLComputeUnit.all.rawValue, "all")
        XCTAssertEqual(
            BASCoreMLComputeUnit.cpuOnly.rawValue, "cpuOnly")
        XCTAssertEqual(
            BASCoreMLComputeUnit.cpuAndGPU.rawValue,
            "cpuAndGPU")
        XCTAssertEqual(
            BASCoreMLComputeUnit.cpuAndNeuralEngine.rawValue,
            "cpuAndNeuralEngine")
    }

    // MARK: - Validator

    func testValidatorAcceptsWellFormedRequest() {
        let request = makeValidRequest()
        let result = BASCoreMLConversionContract.validate(
            request: request)
        XCTAssertEqual(result, .valid)
    }

    func testValidatorRejectsMismatchedContractVersion() {
        let stale = BASCoreMLConversionRequest(
            contractVersion: "M999.bogus",
            input: makeValidRequest().input,
            output: makeValidRequest().output,
            parity: makeValidRequest().parity,
            requestedAtMs: 1)
        let result = BASCoreMLConversionContract.validate(
            request: stale)
        XCTAssertEqual(result,
            .invalid(reason: .mismatchedContractVersion))
    }

    func testValidatorRejectsMambaWithoutTokenizer() {
        let request = makeValidRequest(
            kind: .mamba,
            tokenizerConfigPath: nil)
        let result = BASCoreMLConversionContract.validate(
            request: request)
        XCTAssertEqual(result,
            .invalid(reason: .missingTokenizerForLMKind))
    }

    func testValidatorAcceptsMambaWithTokenizer() {
        let request = makeValidRequest(
            kind: .mamba,
            tokenizerConfigPath: "tokenizer.json")
        let result = BASCoreMLConversionContract.validate(
            request: request)
        XCTAssertEqual(result, .valid)
    }

    func testValidatorRejectsEmptyMLXWeightsPath() {
        let base = makeValidRequest()
        let badInput = BASCoreMLConversionInput(
            mlxWeightsPath: "",
            modelKind: base.input.modelKind)
        let request = BASCoreMLConversionRequest(
            input: badInput,
            output: base.output,
            parity: base.parity,
            requestedAtMs: 1)
        let result = BASCoreMLConversionContract.validate(
            request: request)
        XCTAssertEqual(result,
            .invalid(reason: .emptyMLXWeightsPath))
    }

    func testValidatorRejectsNonPositiveDimensions() {
        let base = makeValidRequest()
        let badOutput = BASCoreMLConversionOutput(
            mlpackagePath: base.output.mlpackagePath,
            targetComputeUnit: base.output
                .targetComputeUnit,
            inputDimensions: ["x": [1, 0, 32]],
            // ^^^ contains 0 → invalid
            outputDimensions: base.output.outputDimensions,
            precision: base.output.precision)
        let request = BASCoreMLConversionRequest(
            input: base.input,
            output: badOutput,
            parity: base.parity,
            requestedAtMs: 1)
        let result = BASCoreMLConversionContract.validate(
            request: request)
        XCTAssertEqual(result,
            .invalid(reason: .nonPositiveDimension))
    }

    // MARK: - Result computation

    func testComputeResultParityPasses() {
        let request = makeValidRequest()
        let result = BASCoreMLConversionContract
            .computeResult(
                request: request,
                observedMaxAbsError: 1e-4,
                observedMeanAbsError: 1e-5,
                durationMs: 30_000)

        XCTAssertTrue(result.conversionSucceeded)
        XCTAssertTrue(result.parityPassed,
            "1e-4 < 1e-3 tolerance, 1e-5 < 1e-4 → pass")
        XCTAssertEqual(result.modelKind, .chenglu)
    }

    func testComputeResultParityFailsOnExceededMaxAbs() {
        let request = makeValidRequest()
        let result = BASCoreMLConversionContract
            .computeResult(
                request: request,
                observedMaxAbsError: 1e-2,  // > 1e-3
                observedMeanAbsError: 1e-5,
                durationMs: 30_000)

        XCTAssertFalse(result.parityPassed,
            "1e-2 > 1e-3 tolerance → fail")
    }

    func testComputeResultParityFailsOnExceededMeanAbs() {
        let request = makeValidRequest()
        let result = BASCoreMLConversionContract
            .computeResult(
                request: request,
                observedMaxAbsError: 1e-4,
                observedMeanAbsError: 1e-3,  // > 1e-4
                durationMs: 30_000)

        XCTAssertFalse(result.parityPassed,
            "1e-3 > 1e-4 tolerance → fail")
    }

    // MARK: - Codable round-trip

    func testRequestCodableRoundTrip() throws {
        let request = makeValidRequest(
            kind: .mamba,
            tokenizerConfigPath: "tok.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(
            BASCoreMLConversionRequest.self,
            from: data)
        XCTAssertEqual(decoded, request)
    }

    func testParityTestCaseCodableRoundTrip() throws {
        let testCase = BASCoreMLParityTestCase(
            testCaseID: "tc-1",
            inputs: ["x": [0.1, 0.2, 0.3]],
            expectedOutputs: ["y": [0.05, 0.95]])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(testCase)
        let decoded = try decoder.decode(
            BASCoreMLParityTestCase.self, from: data)
        XCTAssertEqual(decoded, testCase)
    }
}
