// MARK: - BASTurnRuntimePlanDispatchProbeTests
// chapter 四百三十二 / M1101

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASTurnRuntimePlanDispatchProbeTests:
    XCTestCase
{

    // MARK: - unwired() factory

    func testUnwiredDefaults() {
        let probe = BASTurnRuntimePlanDispatchProbe.unwired()
        XCTAssertEqual(probe.runtimeMode, .v1ByteEqual)
        XCTAssertEqual(probe.kernelRegistryCount, 0)
        XCTAssertEqual(
            probe.aneAcceleratorPriority, .gpuOnly)
        XCTAssertEqual(probe.aneSupportedOpCount, 0)
    }

    // MARK: - Direct init

    func testDirectInitPersistsAllFields() {
        let probe = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .nativeV2,
            kernelRegistryCount: 3,
            aneAcceleratorPriority: .aneFirst,
            aneSupportedOpCount: 7)
        XCTAssertEqual(probe.runtimeMode, .nativeV2)
        XCTAssertEqual(probe.kernelRegistryCount, 3)
        XCTAssertEqual(
            probe.aneAcceleratorPriority, .aneFirst)
        XCTAssertEqual(probe.aneSupportedOpCount, 7)
    }

    // MARK: - Codable byte-stable JSON

    func testPayloadJsonByteStable() {
        let probe = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .nativeV2,
            kernelRegistryCount: 3,
            aneAcceleratorPriority: .aneFirst,
            aneSupportedOpCount: 7)
        let json1 = probe.payloadJson()
        let json2 = probe.payloadJson()
        XCTAssertEqual(json1, json2,
            "sortedKeys JSON must be byte-stable across" +
            " encode calls (chapter 三百九二)")
    }

    func testPayloadJsonIsSortedKeys() {
        let probe = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .nativeV2,
            kernelRegistryCount: 3,
            aneAcceleratorPriority: .aneFirst,
            aneSupportedOpCount: 7)
        let json = probe.payloadJson()
        // Keys come in alphabetical order:
        // aneAcceleratorPriority, aneSupportedOpCount,
        // kernelRegistryCount, runtimeMode
        XCTAssertTrue(json.hasPrefix(
            #"{"aneAcceleratorPriority":"#),
            "sortedKeys must put 'aneAcceleratorPriority'" +
            " first;got \(json)")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .stressSweepDual,
            kernelRegistryCount: 5,
            aneAcceleratorPriority: .gpuOnly,
            aneSupportedOpCount: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASTurnRuntimePlanDispatchProbe.self,
                from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equality + hashability

    func testEqualProbesAreEqual() {
        let p1 = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .nativeV2,
            kernelRegistryCount: 3,
            aneAcceleratorPriority: .aneFirst,
            aneSupportedOpCount: 7)
        let p2 = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .nativeV2,
            kernelRegistryCount: 3,
            aneAcceleratorPriority: .aneFirst,
            aneSupportedOpCount: 7)
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.hashValue, p2.hashValue)
    }

    func testDifferentRuntimeModeNotEqual() {
        let p1 = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .v1ByteEqual,
            kernelRegistryCount: 0,
            aneAcceleratorPriority: .gpuOnly,
            aneSupportedOpCount: 0)
        let p2 = BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .nativeV2,
            kernelRegistryCount: 0,
            aneAcceleratorPriority: .gpuOnly,
            aneSupportedOpCount: 0)
        XCTAssertNotEqual(p1, p2)
    }
}
