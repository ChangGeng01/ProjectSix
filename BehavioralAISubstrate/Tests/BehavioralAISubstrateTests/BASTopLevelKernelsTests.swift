import XCTest
@testable import BASOrchestration

/// M442 (chapter 一百十六) — drift-detector + parity-lock tests
/// for the four top-level kernels.
///
/// Test matrix:
///   - Cardinality: 4 kernels (LeaseLife / NeuralOrgan /
///     StateEvolutionGraph / SovereignMicrokernel)
///   - Schema version pinning
///   - White-paper refs cite `§3.x`
///   - Layer refs: every entry within `1...14`
///   - Lease & Life Kernel claims L1 (the only kernel that does)
///   - Sovereign Microkernel claims L14 (the only kernel that does)
///   - Neural Organ + State & Evolution Graph kernels do NOT
///     claim L1 or L14
///   - Round-trip Codable
final class BASTopLevelKernelsTests: XCTestCase {

    // MARK: - Cardinality

    func testFourKernelsExist() {
        _ = BASLeaseLifeKernel()
        _ = BASNeuralOrganRuntime()
        _ = BASStateEvolutionGraphKernel()
        _ = BASSovereignMicrokernel()
    }

    // MARK: - Schema version pinning

    func testKernelSchemaVersions() {
        XCTAssertEqual(BASLeaseLifeKernel.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASNeuralOrganRuntime.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASStateEvolutionGraphKernel.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASSovereignMicrokernel.currentSchemaVersion, "1.0.0")

        XCTAssertEqual(BASLeaseLifeKernel().schemaVersion, "1.0.0")
        XCTAssertEqual(BASNeuralOrganRuntime().schemaVersion, "1.0.0")
        XCTAssertEqual(BASStateEvolutionGraphKernel().schemaVersion, "1.0.0")
        XCTAssertEqual(BASSovereignMicrokernel().schemaVersion, "1.0.0")
    }

    // MARK: - White-paper refs

    func testEveryKernelCitesSection3() {
        XCTAssertTrue(BASLeaseLifeKernel.whitePaperRef.contains("§3."))
        XCTAssertTrue(BASNeuralOrganRuntime.whitePaperRef.contains("§3."))
        XCTAssertTrue(BASStateEvolutionGraphKernel.whitePaperRef.contains("§3."))
        XCTAssertTrue(BASSovereignMicrokernel.whitePaperRef.contains("§3."))
    }

    func testWhitePaperRefsAreDistinct() {
        let refs: Set<String> = [
            BASLeaseLifeKernel.whitePaperRef,
            BASNeuralOrganRuntime.whitePaperRef,
            BASStateEvolutionGraphKernel.whitePaperRef,
            BASSovereignMicrokernel.whitePaperRef,
        ]
        XCTAssertEqual(refs.count, 4,
                       "Each kernel must cite a distinct §3.x section")
    }

    // MARK: - Layer refs

    func testEveryLayerRefIsInRange1To14() {
        let validRange = 1...14
        for layer in BASLeaseLifeKernel.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer))
        }
        for layer in BASNeuralOrganRuntime.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer))
        }
        for layer in BASStateEvolutionGraphKernel.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer))
        }
        for layer in BASSovereignMicrokernel.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer))
        }
    }

    /// Doctrine pin: only Lease & Life owns L1.
    func testOnlyLeaseLifeKernelClaimsL1() {
        XCTAssertEqual(BASLeaseLifeKernel.canonicalLayerRefs, [1])
        XCTAssertFalse(BASNeuralOrganRuntime.canonicalLayerRefs.contains(1))
        XCTAssertFalse(BASStateEvolutionGraphKernel.canonicalLayerRefs.contains(1))
        XCTAssertFalse(BASSovereignMicrokernel.canonicalLayerRefs.contains(1))
    }

    /// Doctrine pin: only Sovereign Microkernel owns L14.
    func testOnlySovereignMicrokernelClaimsL14() {
        XCTAssertEqual(BASSovereignMicrokernel.canonicalLayerRefs, [14])
        XCTAssertFalse(BASLeaseLifeKernel.canonicalLayerRefs.contains(14))
        XCTAssertFalse(BASNeuralOrganRuntime.canonicalLayerRefs.contains(14))
        XCTAssertFalse(BASStateEvolutionGraphKernel.canonicalLayerRefs.contains(14))
    }

    /// Doctrine pin: Neural Organ owns L2 + L3 (the dual-brain
    /// scout/core layers). No other kernel claims them.
    func testNeuralOrganOwnsL2AndL3() {
        XCTAssertTrue(BASNeuralOrganRuntime.canonicalLayerRefs.contains(2))
        XCTAssertTrue(BASNeuralOrganRuntime.canonicalLayerRefs.contains(3))
        XCTAssertFalse(BASLeaseLifeKernel.canonicalLayerRefs.contains(2))
        XCTAssertFalse(BASStateEvolutionGraphKernel.canonicalLayerRefs.contains(2))
        XCTAssertFalse(BASSovereignMicrokernel.canonicalLayerRefs.contains(2))
    }

    // MARK: - Canonical types invariants

    func testEveryKernelListsAtLeastOneCanonicalType() {
        XCTAssertFalse(BASLeaseLifeKernel.canonicalAssignedTypes.isEmpty)
        XCTAssertFalse(BASNeuralOrganRuntime.canonicalAssignedTypes.isEmpty)
        XCTAssertFalse(BASStateEvolutionGraphKernel.canonicalAssignedTypes.isEmpty)
        XCTAssertFalse(BASSovereignMicrokernel.canonicalAssignedTypes.isEmpty)
    }

    func testCanonicalAssignedTypesUseBASPrefix() {
        let allLists = [
            BASLeaseLifeKernel.canonicalAssignedTypes,
            BASNeuralOrganRuntime.canonicalAssignedTypes,
            BASStateEvolutionGraphKernel.canonicalAssignedTypes,
            BASSovereignMicrokernel.canonicalAssignedTypes,
        ]
        for list in allLists {
            for typeName in list {
                XCTAssertTrue(typeName.hasPrefix("BAS"),
                              "type \(typeName) must use BAS prefix")
            }
        }
    }

    func testCanonicalAssignedTypesAreUniqueWithinEachKernel() {
        for typeNames in [
            BASLeaseLifeKernel.canonicalAssignedTypes,
            BASNeuralOrganRuntime.canonicalAssignedTypes,
            BASStateEvolutionGraphKernel.canonicalAssignedTypes,
            BASSovereignMicrokernel.canonicalAssignedTypes,
        ] {
            let unique = Set(typeNames)
            XCTAssertEqual(typeNames.count, unique.count,
                           "duplicate type in kernel: \(typeNames)")
        }
    }

    // MARK: - Round-trip Codable

    func testLeaseLifeKernelRoundTrip() throws {
        let k = BASLeaseLifeKernel()
        let data = try JSONEncoder().encode(k)
        let decoded = try JSONDecoder().decode(BASLeaseLifeKernel.self, from: data)
        XCTAssertEqual(k, decoded)
    }

    func testNeuralOrganRuntimeRoundTrip() throws {
        let k = BASNeuralOrganRuntime()
        let data = try JSONEncoder().encode(k)
        let decoded = try JSONDecoder().decode(BASNeuralOrganRuntime.self, from: data)
        XCTAssertEqual(k, decoded)
    }

    func testStateEvolutionGraphKernelRoundTrip() throws {
        let k = BASStateEvolutionGraphKernel()
        let data = try JSONEncoder().encode(k)
        let decoded = try JSONDecoder().decode(BASStateEvolutionGraphKernel.self, from: data)
        XCTAssertEqual(k, decoded)
    }

    func testSovereignMicrokernelRoundTrip() throws {
        let k = BASSovereignMicrokernel()
        let data = try JSONEncoder().encode(k)
        let decoded = try JSONDecoder().decode(BASSovereignMicrokernel.self, from: data)
        XCTAssertEqual(k, decoded)
    }
}
