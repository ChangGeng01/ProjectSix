// MARK: - BASMeshSyncFrameTests — chapter 三百一八 / M805
//
// Phase Epsilon 第五刀 测试覆盖:cross-instance mesh sync frame
// + doctrine + merge report。Pins the typed contract without
// committing to a transport layer。

import XCTest
@testable import BASRuntimeCore

final class BASMeshSyncFrameTests: XCTestCase {

    private let referenceDate = Date(
        timeIntervalSince1970: 1_700_000_000)

    // MARK: - Doctrine enum

    func testDoctrineCardinality() {
        XCTAssertEqual(
            BASMeshSyncFrameDoctrine.allCases.count, 4)
    }

    func testDoctrineRawValueStability() {
        XCTAssertEqual(
            BASMeshSyncFrameDoctrine.noOp.rawValue, "no-op")
        XCTAssertEqual(
            BASMeshSyncFrameDoctrine.preferRemote.rawValue,
            "prefer-remote")
        XCTAssertEqual(
            BASMeshSyncFrameDoctrine.preferLocal.rawValue,
            "prefer-local")
        XCTAssertEqual(
            BASMeshSyncFrameDoctrine.sovereignReview.rawValue,
            "sovereign-review")
    }

    func testDoctrineCodableRoundTrip() throws {
        for doctrine in BASMeshSyncFrameDoctrine.allCases {
            let data = try JSONEncoder().encode(doctrine)
            let decoded = try JSONDecoder().decode(
                BASMeshSyncFrameDoctrine.self, from: data)
            XCTAssertEqual(decoded, doctrine)
        }
    }

    // MARK: - Sync frame defaults

    func testSyncFrameDefaultSchemaVersion() {
        let frame = BASMeshSyncFrame(
            instanceID: "device-1",
            emittedAt: referenceDate)
        XCTAssertEqual(frame.schemaVersion, "1.0.0")
        XCTAssertEqual(frame.totalSlotCount, 0)
        XCTAssertNil(frame.signature)
    }

    func testSyncFrameTrimsStrings() {
        let frame = BASMeshSyncFrame(
            instanceID: "  device-1  \n",
            emittedAt: referenceDate,
            signature: "  sig  ")
        XCTAssertEqual(frame.instanceID, "device-1")
        XCTAssertEqual(frame.signature, "sig")
    }

    // MARK: - Sync frame queries

    func testSyncFrameTotalSlotCount() {
        let slots = [
            BASLayerMLHeadSlot(
                layerID: .l4,
                headID: "h1",
                kind: .rules,
                priority: 0),
            BASLayerMLHeadSlot(
                layerID: .l11,
                headID: "h2",
                kind: .coremlOnDevice,
                priority: 10)
        ]
        let frame = BASMeshSyncFrame(
            instanceID: "test",
            emittedAt: referenceDate,
            slotsByLayer: [
                "l4": [slots[0]],
                "l11": [slots[1]]
            ])
        XCTAssertEqual(frame.totalSlotCount, 2)
    }

    func testSyncFrameSlotsForLayer() {
        let slot = BASLayerMLHeadSlot(
            layerID: .l9,
            headID: "h-l9",
            kind: .rules,
            priority: 0)
        let frame = BASMeshSyncFrame(
            instanceID: "test",
            emittedAt: referenceDate,
            slotsByLayer: ["l9": [slot]])
        XCTAssertEqual(
            frame.slots(forLayer: .l9), [slot])
        XCTAssertEqual(
            frame.slots(forLayer: .l4), [],
            "missing layer returns empty array")
    }

    // MARK: - Sync frame Codable round-trip

    func testSyncFrameCodableRoundTrip() throws {
        let slot = BASLayerMLHeadSlot(
            layerID: .l4,
            headID: "rt",
            kind: .coremlOnDevice,
            priority: 10)
        let original = BASMeshSyncFrame(
            instanceID: "rt-instance",
            emittedAt: referenceDate,
            slotsByLayer: ["l4": [slot]],
            signature: "signature-rt")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMeshSyncFrame.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Snapshot from live registry

    func testSnapshotFromEmptyRegistry() async {
        let registry = BASLayerMLHeadRegistry()
        let frame = await BASMeshSyncFrame.snapshot(
            registry: registry,
            instanceID: "empty",
            emittedAt: referenceDate)
        XCTAssertEqual(frame.totalSlotCount, 0)
        XCTAssertTrue(frame.slotsByLayer.isEmpty)
    }

    func testSnapshotFromCanonicalRegistry() async throws {
        let (registry, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let frame = await BASMeshSyncFrame.snapshot(
            registry: registry,
            instanceID: "canonical-test",
            emittedAt: referenceDate)
        XCTAssertEqual(
            frame.totalSlotCount, 41,
            "canonical mesh assembly snapshot must contain " +
            "all 41 canonical slots")
        XCTAssertEqual(
            frame.slots(forLayer: .l14).count, 5,
            "L14 slot count must round-trip through snapshot")
    }

    func testSnapshotInstanceIDRoundTrips() async {
        let registry = BASLayerMLHeadRegistry()
        let frame = await BASMeshSyncFrame.snapshot(
            registry: registry,
            instanceID: "device-abc-123",
            emittedAt: referenceDate)
        XCTAssertEqual(frame.instanceID, "device-abc-123")
    }

    // MARK: - Merge report

    func testMergeReportDefaults() {
        let report = BASMeshSyncFrameMergeReport(
            doctrineApplied: .noOp)
        XCTAssertEqual(report.appliedCount, 0)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.conflictCount, 0)
        XCTAssertEqual(report.sovereignReviewCount, 0)
        XCTAssertEqual(report.reasonCodes, [])
    }

    func testMergeReportClampsNegativesToZero() {
        let report = BASMeshSyncFrameMergeReport(
            doctrineApplied: .preferRemote,
            appliedCount: -5,
            skippedCount: -1,
            conflictCount: -2,
            sovereignReviewCount: -10)
        XCTAssertEqual(report.appliedCount, 0)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.conflictCount, 0)
        XCTAssertEqual(report.sovereignReviewCount, 0)
    }

    func testMergeReportFiltersEmptyReasonCodes() {
        let report = BASMeshSyncFrameMergeReport(
            doctrineApplied: .preferLocal,
            reasonCodes: ["valid", "  ", "", " also-valid "])
        XCTAssertEqual(
            report.reasonCodes, ["valid", "also-valid"])
    }

    func testMergeReportCodableRoundTrip() throws {
        let original = BASMeshSyncFrameMergeReport(
            doctrineApplied: .sovereignReview,
            appliedCount: 5,
            skippedCount: 2,
            conflictCount: 1,
            sovereignReviewCount: 1,
            reasonCodes: ["mesh-sync:test"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMeshSyncFrameMergeReport.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Merge report reason code emission

    func testMergeReportMakeReasonCodesShape() {
        let codes = BASMeshSyncFrameMergeReport.makeReasonCodes(
            doctrine: .preferRemote,
            applied: 41,
            skipped: 0,
            conflicts: 0,
            sovereignReview: 0,
            remoteInstanceID: "device-2")
        XCTAssertEqual(codes.count, 5)
        XCTAssertTrue(
            codes.contains("mesh-sync:doctrine:prefer-remote"))
        XCTAssertTrue(
            codes.contains("mesh-sync:remote-instance:device-2"))
        XCTAssertTrue(codes.contains("mesh-sync:applied:41"))
        XCTAssertTrue(codes.contains("mesh-sync:skipped:0"))
        XCTAssertTrue(codes.contains("mesh-sync:conflicts:0"))
    }

    func testMergeReportSovereignReviewEmitsExtraCode() {
        let codes = BASMeshSyncFrameMergeReport.makeReasonCodes(
            doctrine: .sovereignReview,
            applied: 30,
            skipped: 5,
            conflicts: 6,
            sovereignReview: 6,
            remoteInstanceID: "device-3")
        XCTAssertTrue(
            codes.contains(
                "mesh-sync:sovereign-review:6"),
            ".sovereignReview doctrine + > 0 review-flagged " +
            "slots → emit extra audit code for L14 trail")
    }

    func testMergeReportZeroSovereignReviewOmitsExtraCode() {
        let codes = BASMeshSyncFrameMergeReport.makeReasonCodes(
            doctrine: .sovereignReview,
            applied: 41,
            skipped: 0,
            conflicts: 0,
            sovereignReview: 0,
            remoteInstanceID: "device-3")
        XCTAssertFalse(
            codes.contains { $0.hasPrefix(
                "mesh-sync:sovereign-review:") },
            "sovereignReview == 0 → don't emit redundant zero code")
    }
}
