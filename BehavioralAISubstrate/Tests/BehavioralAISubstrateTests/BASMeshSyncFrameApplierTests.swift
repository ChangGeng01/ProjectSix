// MARK: - BASMeshSyncFrameApplierTests — chapter 三百三六 / M823 (residual #5)
//
// Tests for the dry-run diff helper that closes the in-repo
// portion of v9 §8 non-promise #5 (cross-instance mesh sync
// transport)。
//
// Doctrine pins verified:
//   - 6-case SlotConflict classifier exhaustive
//   - diff() returns empty for empty registry + empty frame
//   - diff() detects identical / priorityDiffers / enabledDiffers
//     / priorityAndEnabledDiffer / remoteHasUnknownHead /
//     localOnly conflict types
//   - dryRunMerge with each of 4 doctrines produces correct
//     applied/skipped/conflict counts
//   - reasonCodes follow `mesh-sync:` prefix doctrine
//   - sovereign-review doctrine bumps sovereignReviewCount

import XCTest
@testable import BASRuntimeCore

final class BASMeshSyncFrameApplierTests: XCTestCase {

    // MARK: - Helpers

    private func makeStubHead(
        headID: String,
        layerID: BASMotherboardLayer14
    ) -> BASRulesBasedLayerMLHead {
        BASRulesBasedLayerMLHead(
            headID: headID,
            layerIDPin: layerID,
            rulesLogic: { _ in
                BASLayerInferenceOutput(
                    layerID: layerID,
                    confidence: .high)
            })
    }

    private func makeRemoteFrame(
        slotsByLayer: [String: [BASLayerMLHeadSlot]],
        instanceID: String = "remote-instance-1"
    ) -> BASMeshSyncFrame {
        BASMeshSyncFrame(
            instanceID: instanceID,
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000),
            slotsByLayer: slotsByLayer,
            signature: nil)
    }

    private func makeSlot(
        headID: String,
        layerID: BASMotherboardLayer14,
        priority: Int = 10,
        enabled: Bool = true,
        kind: BASLayerMLHeadKind = .rules
    ) -> BASLayerMLHeadSlot {
        BASLayerMLHeadSlot(
            layerID: layerID,
            headID: headID,
            kind: kind,
            priority: priority,
            enabled: enabled)
    }

    // MARK: - SlotConflict exhaustive

    func testSlotConflictHas6Cases() {
        XCTAssertEqual(
            BASMeshSyncFrameApplier.SlotConflict.allCases
                .count,
            6)
    }

    // MARK: - Empty inputs

    func testDiffEmptyRegistryAndEmptyFrame() async {
        let registry = BASLayerMLHeadRegistry()
        let frame = makeRemoteFrame(slotsByLayer: [:])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertTrue(diffs.isEmpty)
    }

    // MARK: - Conflict classification

    func testDiffIdenticalSlots() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 10, enabled: true)
            ]
        ])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].conflict, .identical)
        XCTAssertEqual(diffs[0].headID, "h1")
    }

    func testDiffPriorityDiffers() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 20, enabled: true)
            ]
        ])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].conflict, .priorityDiffers)
    }

    func testDiffEnabledDiffers() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10,
            enabled: true)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 10, enabled: false)
            ]
        ])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(diffs[0].conflict, .enabledDiffers)
    }

    func testDiffBothDiffer() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10,
            enabled: true)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 30, enabled: false)
            ]
        ])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(
            diffs[0].conflict, .priorityAndEnabledDiffer)
    }

    func testDiffRemoteHasUnknownHead() async throws {
        let registry = BASLayerMLHeadRegistry()
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "remote-only-head",
                    layerID: .l4)
            ]
        ])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(
            diffs[0].conflict, .remoteHasUnknownHead)
        XCTAssertNil(diffs[0].localSlot)
        XCTAssertNotNil(diffs[0].remoteSlot)
    }

    func testDiffLocalOnly() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "local-only-head",
            layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [:])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].conflict, .localOnly)
        XCTAssertNotNil(diffs[0].localSlot)
        XCTAssertNil(diffs[0].remoteSlot)
    }

    // MARK: - Doctrine application

    func testDryRunNoOpDoctrineSkipsAllConflicts()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 99, enabled: true)
            ]
        ])
        let report = await BASMeshSyncFrameApplier.dryRunMerge(
            local: registry, remote: frame, doctrine: .noOp)
        XCTAssertEqual(report.appliedCount, 0)
        XCTAssertEqual(report.skippedCount, 1)
        XCTAssertEqual(report.conflictCount, 1)
        XCTAssertEqual(report.sovereignReviewCount, 0)
    }

    func testDryRunPreferRemoteAppliesConflicts() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 99, enabled: true)
            ]
        ])
        let report = await BASMeshSyncFrameApplier.dryRunMerge(
            local: registry, remote: frame,
            doctrine: .preferRemote)
        XCTAssertEqual(report.appliedCount, 1)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.conflictCount, 1)
    }

    func testDryRunPreferLocalSkipsConflicts() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 99, enabled: true)
            ]
        ])
        let report = await BASMeshSyncFrameApplier.dryRunMerge(
            local: registry, remote: frame,
            doctrine: .preferLocal)
        XCTAssertEqual(report.appliedCount, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testDryRunSovereignReviewBumpsCount() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = makeStubHead(headID: "h1", layerID: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 10)
        let frame = makeRemoteFrame(slotsByLayer: [
            BASMotherboardLayer14.l4.rawValue: [
                makeSlot(headID: "h1", layerID: .l4,
                    priority: 99, enabled: false)
            ]
        ])
        let report = await BASMeshSyncFrameApplier.dryRunMerge(
            local: registry, remote: frame,
            doctrine: .sovereignReview)
        XCTAssertEqual(report.sovereignReviewCount, 1)
        XCTAssertTrue(report.reasonCodes.contains(where: {
            $0.contains("sovereign-review:h1")
        }))
    }

    // MARK: - Reason code prefix doctrine

    func testReasonCodesUseSyncPrefix() async throws {
        let registry = BASLayerMLHeadRegistry()
        let frame = makeRemoteFrame(slotsByLayer: [:],
            instanceID: "test-inst")
        let report = await BASMeshSyncFrameApplier.dryRunMerge(
            local: registry, remote: frame,
            doctrine: .preferRemote)
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-sync:doctrine:prefer-remote"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-sync:remote-instance:test-inst"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-sync:diff-count:0"))
    }

    // MARK: - Stable ordering

    func testDiffStableLexicographicOrdering() async throws {
        let registry = BASLayerMLHeadRegistry()
        for headID in ["zzz", "aaa", "mmm"] {
            let head = makeStubHead(
                headID: headID, layerID: .l4)
            try await registry.register(
                head: head, layerID: .l4, priority: 10)
        }
        let frame = makeRemoteFrame(slotsByLayer: [:])
        let diffs = await BASMeshSyncFrameApplier.diff(
            local: registry, remote: frame)
        XCTAssertEqual(
            diffs.map { $0.headID },
            ["aaa", "mmm", "zzz"],
            "Stable lexicographic ordering required for " +
            "deterministic audit emission")
    }
}
