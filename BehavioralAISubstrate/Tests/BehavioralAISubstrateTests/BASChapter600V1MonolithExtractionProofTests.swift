// MARK: - BASChapter600V1MonolithExtractionProofTests
// chapter 六百 / M1778 — PROOF tests for the M1777
//                       V1 monolith extraction (audit-
//                       projection helpers moved to
//                       sibling extension file)
//
// ## Coverage (6 PROOF tests)
//
// Verifies the 4 public layerReconciliation* constants
// are still reachable through BASEBrainRuntimeCoordinator
// at their original paths (cross-package contract
// preserved) + that the 13-layer expectation set still
// has the correct values (no drift introduced by the
// extraction)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism preserved
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1777 → M1778

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter600V1MonolithExtractionProofTests:
    XCTestCase
{
    // MARK: - Public constants still reachable

    func testLayerReconciliationExpectedLayersStillExposed() {
        // Cross-package contract:Qinao SDK callers
        // depend on this 13-element list at the
        // original symbol path。 Pure-move extraction
        // must preserve this path。
        let layers =
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayers
        XCTAssertEqual(layers.count, 13)
        XCTAssertEqual(layers.first, .leaseLife)
        XCTAssertEqual(layers.last, .evolutionFurnace)
    }

    func testLayerReconciliationExpectedLayerIDsStillExposed() {
        let ids =
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayerIDs
        XCTAssertEqual(ids.count, 13)
        XCTAssertTrue(
            ids.contains(BASCognitiveLayer.leaseLife
                .rawValue))
        XCTAssertTrue(
            ids.contains(BASCognitiveLayer
                .evolutionFurnace.rawValue))
    }

    func testFullCoverageExpectedLayerIDsStillExposed() {
        // L1..L13 + L14 sovereign = 14 IDs。
        let ids =
            BASEBrainRuntimeCoordinator
                .fullCoverageExpectedLayerIDs
        XCTAssertEqual(ids.count, 14)
        XCTAssertTrue(
            ids.contains(BASCognitiveLayer.sovereign
                .rawValue))
    }

    func testLayerReconciliationBudgetCeilingStillExposed() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .layerReconciliationBudgetCeiling,
            1.0,
            accuracy: 1e-9)
    }

    // MARK: - Constant value drift check

    func testExpectedLayersOrderIsStable() {
        // Anti-drift PROOF — the L1..L13 ordering must
        // be stable for `reconciliation.observed:
        // <L1+L2+...+L13>` emission stability per
        // chapter 三百九二 replay-determinism doctrine。
        let layers =
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayers
        let expected: [BASCognitiveLayer] = [
            .leaseLife,         // L1
            .neuralOrgan,       // L2
            .thoughtFold,       // L3
            .worldPrior,        // L4
            .hostConstitution,  // L5
            .presenceEye,       // L6
            .mirrorBlade,       // L7
            .hippocampalWell,   // L8
            .dreamLoop,         // L9
            .triSelfTribunal,   // L10
            .riskClimate,       // L11
            .gentleHand,        // L12
            .evolutionFurnace,  // L13
        ]
        XCTAssertEqual(layers, expected)
    }

    // MARK: - LayerIDs derivation invariant

    func testLayerIDsDerivedFromLayers() {
        // Anti-drift PROOF — the string-typed view must
        // be a 1:1 mapping from the layer enum's
        // rawValue。
        let layers =
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayers
        let ids =
            BASEBrainRuntimeCoordinator
                .layerReconciliationExpectedLayerIDs
        XCTAssertEqual(
            ids,
            layers.map(\.rawValue))
    }
}
