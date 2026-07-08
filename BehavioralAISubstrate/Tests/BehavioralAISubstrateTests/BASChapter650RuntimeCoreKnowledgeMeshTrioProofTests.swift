// MARK: - BASChapter650RuntimeCoreKnowledgeMeshTrioProofTests
// chapter 六百五十 / M1978 — PROOF tests for the M1977
//                            BASRuntimeCore knowledge-
//                            mesh trio Codable extension
//                            (1st post-hexa-#6 gap-fill,
//                            ROUND-NUMBER chapter 650)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASRuntimeCore knowledge-mesh trio gap-fill — 3
// types covering knowledge-graph + mesh-sync + mesh-
// assembler subsystems:
//
//   BASRuntimeCore (top-level / nested-in-actor):
//     - BASKnowledgeGraphError (3-case top-level enum)
//     - BASMeshSyncFrameApplier.SlotDiff (5-field
//       nested-in-actor struct)
//     - BAS14LayerMeshAssemblyReport (3-field top-level
//       struct,demonstrates Dict<Codable-key, V>
//       composition)
//
// FIRST post-hexa-#6 gap-fill chapter。 4th BASRuntime
// Core touch overall。 Returns to multi-module coverage
// after entirely-BASSovereign hexa #6 cycle。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 649 hexa #6 catalog seal precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1977 → M1978

import XCTest
@testable import BASRuntimeCore

final class BASChapter650RuntimeCoreKnowledgeMeshTrioProofTests:
    XCTestCase
{

    func testBASKnowledgeGraphErrorConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, representative case)
        assertCodableRoundTrips(BASKnowledgeGraphError.nodeNotFound(""))
    }

    func testBASMeshSyncFrameApplierSlotDiffConformsToCodable() {
        // #18: real round-trip
        let value = BASMeshSyncFrameApplier.SlotDiff(
            conflict: .identical,
            headID: "",
            layerID: .l1,
            localSlot: nil,
            remoteSlot: nil)
        assertCodableRoundTrips(value)
    }

    func testBAS14LayerMeshAssemblyReportConformsToCodable() {
        // #18: real round-trip
        let value = BAS14LayerMeshAssemblyReport(
            registeredHeadCount: 0,
            perLayerCounts: [:],
            totalCanonicalSlots: 0)
        assertCodableRoundTrips(value)
    }
}
