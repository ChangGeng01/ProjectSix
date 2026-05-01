import XCTest
@testable import BASRuntimeCore

/// 六十二.6 — restraint surface tests.
final class BASMotherboardRestraintSurfaceTests: XCTestCase {

    func test_fiveRestraintSurfaces() {
        XCTAssertEqual(
            BASMotherboardRestraintSurface.allCases.count, 5)
    }

    func test_allSurfacesFallbackFromPermitGate() {
        for surface in
            BASMotherboardRestraintSurface.allCases
        {
            XCTAssertEqual(
                surface.fallbackFrom, .permitGate)
        }
    }

    func test_implementingFilesPinned() {
        XCTAssertEqual(
            BASMotherboardRestraintSurface.compare
                .implementingFile,
            "QinaoComparePanel.swift")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.draftOnly
                .implementingFile,
            "QinaoDraftShell.swift")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.localOnly
                .implementingFile,
            "QinaoLocalOnlySheet.swift")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.delay
                .implementingFile,
            "QinaoDelayPacket.swift")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.silentStub
                .implementingFile,
            "QinaoSilentStub.swift")
    }

    func test_rawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardRestraintSurface.compare.rawValue,
            "compare")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.draftOnly
                .rawValue,
            "draftOnly")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.localOnly
                .rawValue,
            "localOnly")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.delay.rawValue,
            "delay")
        XCTAssertEqual(
            BASMotherboardRestraintSurface.silentStub
                .rawValue,
            "silentStub")
    }

    func test_codableRoundTrip() throws {
        for surface in
            BASMotherboardRestraintSurface.allCases
        {
            let data = try JSONEncoder().encode(surface)
            let decoded = try JSONDecoder().decode(
                BASMotherboardRestraintSurface.self,
                from: data)
            XCTAssertEqual(decoded, surface)
        }
    }
}
