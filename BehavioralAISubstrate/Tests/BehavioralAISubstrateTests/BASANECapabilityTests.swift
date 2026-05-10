// MARK: - BASANECapabilityTests — chapter 四百三十一 / M1097

import XCTest
@testable import BASMetalSubstrate

final class BASANECapabilityTests: XCTestCase {

    // MARK: - Accelerator priority enum

    func testAcceleratorPriorityRawValues() {
        XCTAssertEqual(
            BASAcceleratorPriority.aneFirst.rawValue,
            "ane-first")
        XCTAssertEqual(
            BASAcceleratorPriority.gpuOnly.rawValue,
            "gpu-only")
        XCTAssertEqual(
            BASAcceleratorPriority.cpuOnly.rawValue,
            "cpu-only")
        XCTAssertEqual(
            BASAcceleratorPriority.allCases.count, 3)
    }

    // MARK: - Thermal snapshot enum

    func testThermalSnapshotRawValues() {
        XCTAssertEqual(
            BASCapabilityThermalSnapshot.nominal.rawValue,
            "nominal")
        XCTAssertEqual(
            BASCapabilityThermalSnapshot.fair.rawValue,
            "fair")
        XCTAssertEqual(
            BASCapabilityThermalSnapshot.serious.rawValue,
            "serious")
        XCTAssertEqual(
            BASCapabilityThermalSnapshot.critical.rawValue,
            "critical")
        XCTAssertEqual(
            BASCapabilityThermalSnapshot.unknown.rawValue,
            "unknown")
        XCTAssertEqual(
            BASCapabilityThermalSnapshot.allCases.count, 5)
    }

    func testThermalSnapshotCurrentReturnsKnownState() {
        let state = BASCapabilityThermalSnapshot.current()
        XCTAssertTrue(
            BASCapabilityThermalSnapshot.allCases
                .contains(state),
            "current() must return one of the 5 enumerated" +
            " states")
    }

    // MARK: - Conservative defaults

    func testConservativeDefaultIsGPUOnlyWithEmptyOps() {
        let cap = BASANECapability.conservative(
            thermalSnapshot: .nominal)
        XCTAssertEqual(cap.acceleratorPriority, .gpuOnly)
        XCTAssertTrue(cap.supportedOps.isEmpty)
        XCTAssertEqual(cap.maxBatchSize, 1)
        XCTAssertEqual(cap.thermalSnapshot, .nominal)
    }

    func testCPUOnlyFallbackIsCPUOnly() {
        let cap = BASANECapability.cpuOnlyFallback(
            thermalSnapshot: .critical)
        XCTAssertEqual(cap.acceleratorPriority, .cpuOnly)
        XCTAssertEqual(cap.thermalSnapshot, .critical)
    }

    // MARK: - Reference Apple Silicon snapshot

    func testNominalAppleSiliconSupports7Ops() {
        let cap = BASANECapability.nominalAppleSilicon()
        XCTAssertEqual(
            cap.acceleratorPriority, .aneFirst)
        XCTAssertEqual(
            cap.supportedOps.count, 7,
            "M1097 reference snapshot ships 7 ops " +
            "(ssmScan reserved for future Mamba work)")
        XCTAssertTrue(
            cap.supportedOps.contains(.matMul))
        XCTAssertTrue(
            cap.supportedOps.contains(.attention))
        XCTAssertTrue(
            cap.supportedOps.contains(.rotaryEmbedding))
        XCTAssertFalse(
            cap.supportedOps.contains(.ssmScan),
            "ssmScan must be reserved for future Mamba" +
            " SSM training pipeline")
    }

    // MARK: - Codable round-trip (chapter 三百九二)

    func testCapabilityCodableRoundTrip() throws {
        let original = BASANECapability.nominalAppleSilicon()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(BASANECapability.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testCodableSortedKeysByteStable() throws {
        let cap = BASANECapability.nominalAppleSilicon()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded1 = try encoder.encode(cap)
        let encoded2 = try encoder.encode(cap)
        XCTAssertEqual(encoded1, encoded2,
            "sortedKeys must produce byte-stable JSON " +
            "(chapter 三百九二)")
    }

    // MARK: - Equality + hashability for cache keys

    func testEqualCapabilitiesHashEqual() {
        let c1 = BASANECapability.conservative(
            thermalSnapshot: .nominal)
        let c2 = BASANECapability.conservative(
            thermalSnapshot: .nominal)
        XCTAssertEqual(c1, c2)
        XCTAssertEqual(c1.hashValue, c2.hashValue)
    }
}
