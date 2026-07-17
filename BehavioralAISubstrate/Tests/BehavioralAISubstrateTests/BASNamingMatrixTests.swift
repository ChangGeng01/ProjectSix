// MARK: - BASNamingMatrixTests — chapter 四百三 / M959

import XCTest
@testable import BASRuntimeCore

final class BASNamingMatrixTests: XCTestCase {

    // MARK: - 14-layer enum

    func testMotherboardLayerCount() {
        XCTAssertEqual(
            BASMotherboardLayer.allCases.count, 14)
    }

    func testEachLayerHasGrepStableRawValue() {
        for layer in BASMotherboardLayer.allCases {
            XCTAssertTrue(
                layer.rawValue.hasPrefix("l"),
                "M959:layer raw value must start with 'l'")
        }
    }

    func testLegacyLayerEnumsAreTotalProjectionsOfCognitiveLayer() {
        let expected: [(
            semantic: BASCognitiveLayer,
            motherboard14: BASMotherboardLayer14,
            naming: BASMotherboardLayer
        )] = [
            (.leaseLife, .l1, .l1WickLifeKernel),
            (.neuralOrgan, .l2, .l2BrainTissue),
            (.thoughtFold, .l3, .l3FoldedLung),
            (.worldPrior, .l4, .l4WorldPrior),
            (.hostConstitution, .l5, .l5HostConstitution),
            (.presenceEye, .l6, .l6SituationField),
            (.mirrorBlade, .l7, .l7MirrorBlade),
            (.hippocampalWell, .l8, .l8HippocampalMemory),
            (.dreamLoop, .l9, .l9KunlunAxis),
            (.triSelfTribunal, .l10, .l10TriSelfTribunal),
            (.riskClimate, .l11, .l11RiskPlane),
            (.gentleHand, .l12, .l12SoftHand),
            (.evolutionFurnace, .l13, .l13Evolution),
            (.sovereign, .l14, .l14SovereignAudit),
        ]

        XCTAssertEqual(expected.count, BASCognitiveLayer.allCases.count)
        for row in expected {
            XCTAssertEqual(row.semantic.motherboardLayer14, row.motherboard14)
            XCTAssertEqual(row.motherboard14.semanticLayerID, row.semantic)
            XCTAssertEqual(row.semantic.motherboardLayer, row.naming)
            XCTAssertEqual(row.naming.semanticLayerID, row.semantic)
        }
    }

    // MARK: - Vision section bounds

    func testVisionSectionInRangeIsAccepted() {
        XCTAssertNotNil(BASVisionSection(number: 1))
        XCTAssertNotNil(BASVisionSection(number: 13))
    }

    func testVisionSectionOutOfRangeIsRejected() {
        XCTAssertNil(BASVisionSection(number: 0))
        XCTAssertNil(BASVisionSection(number: 14))
        XCTAssertNil(BASVisionSection(number: -1))
    }

    func testVisionSectionLabel() {
        let v = BASVisionSection(number: 7)!
        XCTAssertEqual(v.label, "§7")
    }

    // MARK: - Chapter-M ref

    func testChapterMRefIsCodable() throws {
        let ref = BASChapterMRef(
            chapter: 402, mNumber: 941)
        let encoded = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(
            BASChapterMRef.self, from: encoded)
        XCTAssertEqual(decoded, ref)
    }

    // MARK: - Matrix queries

    func testMatrixVersionPin() {
        XCTAssertEqual(
            BASNamingMatrix.matrixVersion, "M959")
    }

    func testMatrixHasEntries() {
        XCTAssertFalse(BASNamingMatrix.entries.isEmpty)
    }

    func testEveryRoadmapGapHasAtLeastOneEntry() {
        for gap in BASCognitiveOSGap.allCases {
            let matched = BASNamingMatrix.entries(for: gap)
            XCTAssertFalse(matched.isEmpty,
                "M959:every G-gap should have a matrix entry: \(gap.rawValue)")
        }
    }

    func testL10TribunalEntriesIncludeTriSelf() {
        let entries = BASNamingMatrix.entries(
            for: .l10TriSelfTribunal)
        XCTAssertTrue(
            entries.contains {
                $0.conceptName == "tri-self-tribunal"
            })
    }

    func testL8HippocampalMemoryEntriesIncludeEventLog() {
        let entries = BASNamingMatrix.entries(
            for: .l8HippocampalMemory)
        XCTAssertTrue(
            entries.contains {
                $0.conceptName == "event-sourced-event-log"
            })
    }

    func testEntryByConceptName() {
        let entry = BASNamingMatrix.entry(
            named: "event-sourced-event-log")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.layer, .l8HippocampalMemory)
        XCTAssertEqual(
            entry?.roadmapGap, .g1EventLog)
        XCTAssertEqual(
            entry?.chapterMRef?.mNumber, 841)
    }

    func testVisionSectionLookupReturnsKunlunPlusAbyssal() {
        let entries = BASNamingMatrix.entries(
            forVisionSection: 5)
        let names = entries.map { $0.conceptName }
        XCTAssertTrue(names.contains("kunlun-axis"))
        XCTAssertTrue(
            names.contains("abyssal-permit-escalation"))
    }

    // MARK: - Codable round-trip

    func testEntryCodableRoundTrip() throws {
        let entry = BASNamingMatrixEntry(
            conceptName: "test",
            layer: .l11RiskPlane,
            visionSection: BASVisionSection(number: 5),
            roadmapGap: .g7ActiveVerifier,
            chapterMRef: BASChapterMRef(
                chapter: 100, mNumber: 500))
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(
            BASNamingMatrixEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }
}
