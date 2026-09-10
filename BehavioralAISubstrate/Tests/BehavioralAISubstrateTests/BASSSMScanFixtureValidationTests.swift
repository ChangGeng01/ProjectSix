// MARK: - BASSSMScanFixtureValidationTests
// chapter 六百七十九 / M2095 第三刀 — fixture-driven PROOF
//                                    tests asserting CPU +
//                                    GPU outputs match the
//                                    analytic-canonical
//                                    expected_y values
//                                    within tolerance for
//                                    every fixture in the
//                                    registry。
//
// This is the SECOND oracle for SSM scan correctness。 The
// FIRST oracle (chapter 678 / M2091 cross-validation)
// proved CPU↔GPU agreement on random fixtures。 This SECOND
// oracle proves CPU + GPU both match analytic-canonical
// math values for hand-derived fixtures。 Triangulation
// achieves stronger correctness proof than either alone。

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanFixtureValidationTests: XCTestCase {

    typealias R = BASSSMScanFixtureRegistry
    typealias CPU = BASSSMScanCPUReference

    private func skipUnlessMetal() throws {
        try XCTSkipUnless(
            MTLCreateSystemDefaultDevice() != nil,
            "Metal not available on this platform")
    }

    // MARK: - CPU reference fixture validation (no skip)

    /// Runs every fixture through CPU reference + asserts
    /// MAE ≤ tolerance vs analytic-canonical expectedY。
    /// This is CPU correctness PROOF against the math。
    func testCPUReferenceMatchesAllFixtures() throws {
        for fixture in R.allFixtures {
            let yCPU = try CPU.scan(
                x: fixture.x,
                delta: fixture.delta,
                A: fixture.A,
                B: fixture.B,
                C: fixture.C,
                shape: fixture.shape)
            assertMAEWithinTolerance(
                actual: yCPU,
                expected: fixture.expectedY,
                tolerance: fixture.tolerance,
                fixtureName: fixture.name,
                source: "CPU")
        }
    }

    // MARK: - GPU kernel fixture validation (Metal required)

    /// Runs every fixture through GPU kernel + asserts
    /// MAE ≤ tolerance vs analytic-canonical expectedY。
    /// This is GPU correctness PROOF against the math。
    func testGPUKernelMatchesAllFixtures() async throws {
        try skipUnlessMetal()

        let kernel = try BASMetalSSMScanKernel()
        for fixture in R.allFixtures {
            let descBLD =
                BASTensorDescriptor.contiguous(
                    shape: [
                        Int(fixture.shape.B),
                        Int(fixture.shape.L),
                        Int(fixture.shape.D)
                    ],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: "ssm-scan-bld")
            let descD = BASTensorDescriptor.contiguous(
                shape: [Int(fixture.shape.D)],
                dataType: .float32,
                backingKind: .metalBuffer,
                rankTag: "ssm-scan-d")
            let inputs = BASKernelInputs(
                descriptors: [
                    descBLD, descBLD, descD,
                    descBLD, descBLD
                ],
                payloads: [
                    floatsToData(fixture.x),
                    floatsToData(fixture.delta),
                    floatsToData(fixture.A),
                    floatsToData(fixture.B),
                    floatsToData(fixture.C)
                ])
            let outputs = try await kernel.evaluate(
                inputs: inputs)
            let yGPU = bytesToFloats(outputs.payloads[0])
            assertMAEWithinTolerance(
                actual: yGPU,
                expected: fixture.expectedY,
                tolerance: fixture.tolerance,
                fixtureName: fixture.name,
                source: "GPU")
        }
    }

    // MARK: - Per-fixture explicit tests (easier diagnosis)

    func testFixture01OnCPU() throws {
        try runCPUFixture(R.fixture01ZeroDeltaZeroOutput)
    }

    func testFixture02OnCPU() throws {
        try runCPUFixture(R.fixture02IdentityUnitStep)
    }

    func testFixture03OnCPU() throws {
        try runCPUFixture(R.fixture03TwoStepDecay)
    }

    func testFixture04OnCPU() throws {
        try runCPUFixture(R.fixture04ThreeStepAccumulation)
    }

    func testFixture05OnCPU() throws {
        try runCPUFixture(R.fixture05TwoChannelIndependence)
    }

    func testFixture06OnCPU() throws {
        try runCPUFixture(R.fixture06TwoBatchIndependence)
    }

    func testFixture01OnGPU() async throws {
        try skipUnlessMetal()
        try await runGPUFixture(R.fixture01ZeroDeltaZeroOutput)
    }

    func testFixture02OnGPU() async throws {
        try skipUnlessMetal()
        try await runGPUFixture(R.fixture02IdentityUnitStep)
    }

    func testFixture03OnGPU() async throws {
        try skipUnlessMetal()
        try await runGPUFixture(R.fixture03TwoStepDecay)
    }

    func testFixture04OnGPU() async throws {
        try skipUnlessMetal()
        try await runGPUFixture(R.fixture04ThreeStepAccumulation)
    }

    func testFixture05OnGPU() async throws {
        try skipUnlessMetal()
        try await runGPUFixture(R.fixture05TwoChannelIndependence)
    }

    func testFixture06OnGPU() async throws {
        try skipUnlessMetal()
        try await runGPUFixture(R.fixture06TwoBatchIndependence)
    }

    // MARK: - Helpers

    private func runCPUFixture(
        _ fixture: BASSSMScanFixture
    ) throws {
        let yCPU = try CPU.scan(
            x: fixture.x,
            delta: fixture.delta,
            A: fixture.A,
            B: fixture.B,
            C: fixture.C,
            shape: fixture.shape)
        assertMAEWithinTolerance(
            actual: yCPU,
            expected: fixture.expectedY,
            tolerance: fixture.tolerance,
            fixtureName: fixture.name,
            source: "CPU")
    }

    private func runGPUFixture(
        _ fixture: BASSSMScanFixture
    ) async throws {
        let kernel = try BASMetalSSMScanKernel()
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
            shape: [Int(fixture.shape.D)],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-d")
        let inputs = BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD,
                descBLD, descBLD
            ],
            payloads: [
                floatsToData(fixture.x),
                floatsToData(fixture.delta),
                floatsToData(fixture.A),
                floatsToData(fixture.B),
                floatsToData(fixture.C)
            ])
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        let yGPU = bytesToFloats(outputs.payloads[0])
        assertMAEWithinTolerance(
            actual: yGPU,
            expected: fixture.expectedY,
            tolerance: fixture.tolerance,
            fixtureName: fixture.name,
            source: "GPU")
    }

    private func assertMAEWithinTolerance(
        actual: [Float],
        expected: [Float],
        tolerance: Float,
        fixtureName: String,
        source: String,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            actual.count, expected.count,
            "\(source) output element-count mismatch " +
            "on fixture '\(fixtureName)'",
            line: line)
        guard actual.count == expected.count else { return }
        var totalAbsError: Float = 0.0
        var maxAbsError: Float = 0.0
        for i in 0..<actual.count {
            let e = abs(actual[i] - expected[i])
            totalAbsError += e
            maxAbsError = max(maxAbsError, e)
        }
        let mae = totalAbsError / Float(actual.count)
        XCTAssertLessThanOrEqual(
            mae, tolerance,
            "\(source) MAE \(mae) exceeds tolerance " +
            "\(tolerance) on fixture '\(fixtureName)'。 " +
            "maxAbs=\(maxAbsError)。 " +
            "actual=\(actual) expected=\(expected)",
            line: line)
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
