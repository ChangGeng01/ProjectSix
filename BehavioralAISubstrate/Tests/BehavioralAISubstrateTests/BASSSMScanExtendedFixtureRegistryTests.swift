// MARK: - BASSSMScanExtendedFixtureRegistryTests
// chapter 六百八十 / M2097 第一刀 — anti-drift + cross-
//                                  validation PROOF tests
//                                  for the extended fixture
//                                  registry。

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanExtendedFixtureRegistryTests:
    XCTestCase
{
    typealias R = BASSSMScanExtendedFixtureRegistry
    typealias CPU = BASSSMScanCPUReference

    private func skipUnlessMetal() throws {
        try XCTSkipUnless(
            MTLCreateSystemDefaultDevice() != nil,
            "Metal not available on this platform")
    }

    // MARK: - Registry size

    func testFixtureCountIsSix() {
        XCTAssertEqual(R.fixtureCount, 6)
    }

    func testAllSixExtendedFixturesPresent() {
        let expected = [
            "large_scale_b2l8d4",
            "large_scale_b4l16d8",
            "all_zero_input",
            "extreme_positive_delta",
            "strong_decay_a",
            "zero_a_constant_state"
        ]
        for name in expected {
            XCTAssertNotNil(
                R.fixture(named: name),
                "extended fixture '\(name)' missing")
        }
    }

    func testLookupReturnsNilForUnknown() {
        XCTAssertNil(R.fixture(named: "nonexistent"))
    }

    // MARK: - Generated inputs match shape

    func testEveryFixtureGeneratesCorrectShapeInputs() {
        for fixture in R.allFixtures {
            let inputs = fixture.generateInputs()
            let bld = fixture.shape.elementCount
            let d = Int(fixture.shape.D)

            XCTAssertEqual(
                inputs.x.count, bld,
                "fixture '\(fixture.name)' x count")
            XCTAssertEqual(
                inputs.delta.count, bld,
                "fixture '\(fixture.name)' delta count")
            XCTAssertEqual(
                inputs.A.count, d,
                "fixture '\(fixture.name)' A count")
            XCTAssertEqual(
                inputs.B.count, bld,
                "fixture '\(fixture.name)' B count")
            XCTAssertEqual(
                inputs.C.count, bld,
                "fixture '\(fixture.name)' C count")
        }
    }

    // MARK: - Input determinism

    func testGeneratedInputsAreDeterministic() {
        for fixture in R.allFixtures {
            let in1 = fixture.generateInputs()
            let in2 = fixture.generateInputs()
            XCTAssertEqual(in1.x, in2.x)
            XCTAssertEqual(in1.delta, in2.delta)
            XCTAssertEqual(in1.A, in2.A)
            XCTAssertEqual(in1.B, in2.B)
            XCTAssertEqual(in1.C, in2.C)
        }
    }

    // MARK: - All-zero fixture special case

    func testAllZeroFixtureProducesZeroCPU() throws {
        let fixture = R.allZeroInput
        let inputs = fixture.generateInputs()
        let yCPU = try CPU.scan(
            x: inputs.x, delta: inputs.delta,
            A: inputs.A, B: inputs.B, C: inputs.C,
            shape: fixture.shape)
        for v in yCPU {
            XCTAssertEqual(v, 0.0)
        }
    }

    func testAllZeroFixtureProducesZeroGPU() async throws {
        try skipUnlessMetal()
        try await crossValidateFixtureOnGPU(R.allZeroInput)
    }

    // MARK: - Cross-validation:CPU vs GPU on extended fixtures

    func testLargeScaleB2L8D4CrossValidates() async throws {
        try skipUnlessMetal()
        try await crossValidateFixtureOnGPU(
            R.largeScaleB2L8D4)
    }

    func testLargeScaleB4L16D8CrossValidates() async throws {
        try skipUnlessMetal()
        try await crossValidateFixtureOnGPU(
            R.largeScaleB4L16D8)
    }

    func testExtremePositiveDeltaCrossValidates() async throws {
        try skipUnlessMetal()
        try await crossValidateFixtureOnGPU(
            R.extremePositiveDelta)
    }

    func testStrongDecayACrossValidates() async throws {
        try skipUnlessMetal()
        try await crossValidateFixtureOnGPU(
            R.strongDecayA)
    }

    func testZeroAConstantStateCrossValidates() async throws {
        try skipUnlessMetal()
        try await crossValidateFixtureOnGPU(
            R.zeroAConstantState)
    }

    // MARK: - Codable round-trip

    func testFixtureCodableRoundTrip() throws {
        let original = R.largeScaleB2L8D4
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSSMScanExtendedFixture.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Helper:cross-validate fixture on GPU

    private func crossValidateFixtureOnGPU(
        _ fixture: BASSSMScanExtendedFixture
    ) async throws {
        let kernel = try BASMetalSSMScanKernel()
        let inputs = fixture.generateInputs()

        // CPU expected
        let yCPU = try CPU.scan(
            x: inputs.x, delta: inputs.delta,
            A: inputs.A, B: inputs.B, C: inputs.C,
            shape: fixture.shape)

        // GPU actual
        let bld = fixture.shape.elementCount
        let d = Int(fixture.shape.D)
        let descBLD = BASTensorDescriptor.contiguous(
            shape: [
                Int(fixture.shape.B),
                Int(fixture.shape.L),
                Int(fixture.shape.D)
            ],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [d],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-d")
        let kernelInputs = BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD, descBLD, descBLD
            ],
            payloads: [
                floatsToData(inputs.x),
                floatsToData(inputs.delta),
                floatsToData(inputs.A),
                floatsToData(inputs.B),
                floatsToData(inputs.C)
            ])
        let outputs = try await kernel.evaluate(
            inputs: kernelInputs)
        let yGPU = bytesToFloats(outputs.payloads[0])

        // MAE assertion
        XCTAssertEqual(yCPU.count, yGPU.count)
        XCTAssertEqual(yCPU.count, bld)
        guard yCPU.count == yGPU.count else { return }
        var totalAbsError: Float = 0.0
        for i in 0..<yCPU.count {
            totalAbsError += abs(yCPU[i] - yGPU[i])
        }
        let mae = totalAbsError / Float(yCPU.count)
        XCTAssertLessThanOrEqual(
            mae, 1e-5,
            "MAE \(mae) on extended fixture " +
            "'\(fixture.name)' exceeds 1e-5 tolerance")
    }

    private func floatsToData(_ floats: [Float]) -> Data {
        return floats.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
    }

    private func bytesToFloats(_ data: Data) -> [Float] {
        let count = data.count / 4
        return data.withUnsafeBytes { raw -> [Float] in
            let ptr = raw.bindMemory(to: Float.self)
            return Array(ptr[0..<count])
        }
    }
}
