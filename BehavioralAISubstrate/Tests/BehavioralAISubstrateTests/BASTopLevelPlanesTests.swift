import XCTest
@testable import BASOrchestration

/// M441 (chapter 一百十六) — drift-detector + parity-lock tests
/// for the three top-level architecture planes.
///
/// Test matrix:
///   - Cardinality: 3 planes (Sovereign / State / Compute)
///   - Schema version pinning (`1.0.0` for chapter 一百十六)
///   - White-paper ref non-empty + cites `§3.x`
///   - Layer refs: every entry within `1...14`
///   - Layer refs disjoint between Sovereign + Compute (no
///     plane should claim ownership of L1 since L1 is a kernel)
///   - Each plane's `canonicalAssignedTypes` non-empty + sorted
///     within reason (drift if a contributor adds a duplicate)
///   - Round-trip Codable
final class BASTopLevelPlanesTests: XCTestCase {

    // MARK: - Cardinality

    func testThreePlanesExist() {
        // Smoke check: the three plane types compile + init.
        _ = BASSovereignPlane()
        _ = BASStatePlane()
        _ = BASComputePlane()
    }

    // MARK: - Schema version pinning

    func testSovereignPlaneSchemaVersion() {
        XCTAssertEqual(BASSovereignPlane.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASSovereignPlane().schemaVersion, "1.0.0")
    }

    func testStatePlaneSchemaVersion() {
        XCTAssertEqual(BASStatePlane.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASStatePlane().schemaVersion, "1.0.0")
    }

    func testComputePlaneSchemaVersion() {
        XCTAssertEqual(BASComputePlane.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(BASComputePlane().schemaVersion, "1.0.0")
    }

    // MARK: - White-paper ref discipline

    func testEveryPlaneCitesSection3() {
        XCTAssertTrue(BASSovereignPlane.whitePaperRef.contains("§3."))
        XCTAssertTrue(BASStatePlane.whitePaperRef.contains("§3."))
        XCTAssertTrue(BASComputePlane.whitePaperRef.contains("§3."))
    }

    func testWhitePaperRefsAreDistinct() {
        let refs: Set<String> = [
            BASSovereignPlane.whitePaperRef,
            BASStatePlane.whitePaperRef,
            BASComputePlane.whitePaperRef,
        ]
        XCTAssertEqual(refs.count, 3,
                       "Each plane must cite a distinct §3.x section")
    }

    // MARK: - Layer refs invariants

    func testEveryLayerRefIsInRange1To14() {
        let validRange = 1...14
        for layer in BASSovereignPlane.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer),
                          "Sovereign Plane layer \(layer) outside 1...14")
        }
        for layer in BASStatePlane.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer),
                          "State Plane layer \(layer) outside 1...14")
        }
        for layer in BASComputePlane.canonicalLayerRefs {
            XCTAssertTrue(validRange.contains(layer),
                          "Compute Plane layer \(layer) outside 1...14")
        }
    }

    /// Doctrine pin: L1 belongs to a kernel (Lease & Life), not
    /// to any plane. The three planes split L2-L14 only.
    func testNoPlaneClaimsL1() {
        XCTAssertFalse(BASSovereignPlane.canonicalLayerRefs.contains(1))
        XCTAssertFalse(BASStatePlane.canonicalLayerRefs.contains(1))
        XCTAssertFalse(BASComputePlane.canonicalLayerRefs.contains(1))
    }

    /// Sovereign + Compute layer refs disjoint (verdict ≠ model
    /// generation).
    func testSovereignAndComputeLayersDisjoint() {
        let sovereign = Set(BASSovereignPlane.canonicalLayerRefs)
        let compute = Set(BASComputePlane.canonicalLayerRefs)
        XCTAssertTrue(sovereign.isDisjoint(with: compute),
                      "Sovereign Plane (L\(sovereign)) and Compute " +
                      "Plane (L\(compute)) must not share layers")
    }

    // MARK: - Canonical types invariants

    func testEveryPlaneListsAtLeastOneCanonicalType() {
        XCTAssertFalse(BASSovereignPlane.canonicalAssignedTypes.isEmpty)
        XCTAssertFalse(BASStatePlane.canonicalAssignedTypes.isEmpty)
        XCTAssertFalse(BASComputePlane.canonicalAssignedTypes.isEmpty)
    }

    func testCanonicalAssignedTypesUseBASPrefix() {
        // Every typed substrate type starts with `BAS`. Drift
        // detector — if a contributor pastes a Qinao name into
        // the list it fails here.
        let allLists = [
            BASSovereignPlane.canonicalAssignedTypes,
            BASStatePlane.canonicalAssignedTypes,
            BASComputePlane.canonicalAssignedTypes,
        ]
        for list in allLists {
            for typeName in list {
                XCTAssertTrue(typeName.hasPrefix("BAS"),
                              "type \(typeName) must use BAS prefix")
            }
        }
    }

    func testCanonicalAssignedTypesAreUniqueWithinEachPlane() {
        for typeNames in [
            BASSovereignPlane.canonicalAssignedTypes,
            BASStatePlane.canonicalAssignedTypes,
            BASComputePlane.canonicalAssignedTypes,
        ] {
            let unique = Set(typeNames)
            XCTAssertEqual(typeNames.count, unique.count,
                           "duplicate type in plane: \(typeNames)")
        }
    }

    // MARK: - Round-trip Codable

    func testSovereignPlaneRoundTrip() throws {
        let plane = BASSovereignPlane()
        let data = try JSONEncoder().encode(plane)
        let decoded = try JSONDecoder().decode(BASSovereignPlane.self, from: data)
        XCTAssertEqual(plane, decoded)
    }

    func testStatePlaneRoundTrip() throws {
        let plane = BASStatePlane()
        let data = try JSONEncoder().encode(plane)
        let decoded = try JSONDecoder().decode(BASStatePlane.self, from: data)
        XCTAssertEqual(plane, decoded)
    }

    func testComputePlaneRoundTrip() throws {
        let plane = BASComputePlane()
        let data = try JSONEncoder().encode(plane)
        let decoded = try JSONDecoder().decode(BASComputePlane.self, from: data)
        XCTAssertEqual(plane, decoded)
    }
}
