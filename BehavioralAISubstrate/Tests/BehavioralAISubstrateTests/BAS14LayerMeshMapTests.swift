// MARK: - BAS14LayerMeshMapTests — chapter 三百一三 / M800
//
// Phase Delta 第四刀 测试覆盖:14-layer × ML head canonical mesh
// map。Pins doctrine encoding from chapter 一百七十七 vision into
// stable test fixtures。

import XCTest
@testable import BASRuntimeCore

final class BAS14LayerMeshMapTests: XCTestCase {

    // MARK: - Slot record

    func testSlotDefaultSchemaVersion() {
        let slot = BAS14LayerMeshSlot(
            layerID: .l4,
            headRole: "test",
            expectedKind: .rules,
            priority: 0,
            description: "test slot")
        XCTAssertEqual(slot.schemaVersion, "1.0.0")
    }

    func testSlotTrimsStrings() {
        let slot = BAS14LayerMeshSlot(
            layerID: .l4,
            headRole: "  trimmed  \n",
            expectedKind: .rules,
            priority: 0,
            description: "  desc  ")
        XCTAssertEqual(slot.headRole, "trimmed")
        XCTAssertEqual(slot.description, "desc")
    }

    func testSlotCodableRoundTrip() throws {
        let slot = BAS14LayerMeshSlot(
            layerID: .l11,
            headRole: "rt",
            expectedKind: .coremlOnDevice,
            priority: 10,
            description: "round-trip test")
        let data = try JSONEncoder().encode(slot)
        let decoded = try JSONDecoder().decode(
            BAS14LayerMeshSlot.self, from: data)
        XCTAssertEqual(decoded, slot)
    }

    // MARK: - Priority constants

    func testCascadingTierPriorityConstants() {
        // chapter 一百七十七 cascading inference doctrine:
        // rules → coreml → mlx → AFM → external,
        // priority 0/10/20/30/40
        XCTAssertEqual(
            BAS14LayerMeshMap.rulesTierPriority, 0)
        XCTAssertEqual(
            BAS14LayerMeshMap.coremlOnDeviceTierPriority, 10)
        XCTAssertEqual(
            BAS14LayerMeshMap.mlxLocalTierPriority, 20)
        XCTAssertEqual(
            BAS14LayerMeshMap.appleFoundationModelTierPriority,
            30)
        XCTAssertEqual(
            BAS14LayerMeshMap.externalProviderTierPriority, 40)
    }

    func testPriorityConstantsAreMonotonicallyIncreasing() {
        let priorities = [
            BAS14LayerMeshMap.rulesTierPriority,
            BAS14LayerMeshMap.coremlOnDeviceTierPriority,
            BAS14LayerMeshMap.mlxLocalTierPriority,
            BAS14LayerMeshMap.appleFoundationModelTierPriority,
            BAS14LayerMeshMap.externalProviderTierPriority
        ]
        for i in 1..<priorities.count {
            XCTAssertLessThan(
                priorities[i - 1], priorities[i],
                "tier priorities must be strictly increasing " +
                "(chapter 一百七十七 cascade doctrine)")
        }
    }

    // MARK: - Canonical map shape

    func testCanonicalMapNonEmpty() {
        XCTAssertGreaterThan(
            BAS14LayerMeshMap.canonical.count, 0,
            "canonical map must contain slot definitions")
    }

    func testCanonicalMapMatches41TotalSlotsApproximate() {
        // chapter 一百七十七 vision describes "~50 heads" — the
        // exact count from this concrete L1-L14 enumeration is
        // 41 (3+3+3+3+3+4+3+3+4+4+3+5). L2/L3 have 0 model-layer
        // heads (runtime concerns).
        // Per-layer breakdown:
        //   L1=3 / L4=3 / L5=3 / L6=3 / L7=3 / L8=4 / L9=3
        //   L10=3 / L11=4 / L12=4 / L13=3 / L14=5
        // This test pins the count so future map edits are
        // explicit + reviewed.
        XCTAssertEqual(
            BAS14LayerMeshMap.totalSlotCount, 41,
            "canonical map slot count is 41 — concrete " +
            "L1-L14 enumeration approximating chapter 一百七十七 " +
            "vision \"~50 heads\". Updating this count requires " +
            "explicit doctrine review (rationale in commit log).")
    }

    func testCanonicalMapCoversMeaningfulLayers() {
        // L1, L4-L14 should have slots. L2 + L3 are runtime
        // concerns (model + breathing) — no model-layer heads.
        let l1 = BAS14LayerMeshMap.slots(forLayer: .l1)
        XCTAssertEqual(l1.count, 3,
            "L1 wake: 3 heads (wake-policy / thermal-budget / " +
            "compute-cost-predictor)")
        let l4 = BAS14LayerMeshMap.slots(forLayer: .l4)
        XCTAssertEqual(l4.count, 3,
            "L4 horizon: 3 heads (topic / question-type / " +
            "tool-need)")
        let l11 = BAS14LayerMeshMap.slots(forLayer: .l11)
        XCTAssertEqual(l11.count, 4,
            "L11 risk: 4 heads (risk-scorer / " +
            "critical-risk / domain-risk / safety-action)")
        let l14 = BAS14LayerMeshMap.slots(forLayer: .l14)
        XCTAssertEqual(l14.count, 5,
            "L14 sovereign: 5 heads (overconfidence / " +
            "sycophancy / evidence / goal-alignment / " +
            "meta-calibration)")
    }

    func testL2L3HaveZeroModelLayerHeads() {
        // L2 (neural organ) + L3 (folded lung) are runtime
        // infrastructure layers — chapter 一百七十七 vision
        // describes them as "shared encoder + multi-head
        // pattern" + "compression / breathing" — not separate
        // ML heads at this enumeration level.
        let l2 = BAS14LayerMeshMap.slots(forLayer: .l2)
        let l3 = BAS14LayerMeshMap.slots(forLayer: .l3)
        XCTAssertTrue(l2.isEmpty,
            "L2 neural organ: no separate head slots; uses " +
            "shared encoder + heads pattern")
        XCTAssertTrue(l3.isEmpty,
            "L3 folded lung: compression/breathing is runtime " +
            "concern, not ML head")
    }

    // MARK: - Per-slot invariants

    func testAllSlotsHaveUniqueRoleWithinLayer() {
        // Within one layer, headRole must be unique (no
        // duplicate role names). Different layers can share
        // role names (e.g. "scorer" can appear in multiple
        // layers).
        for layer in BASMotherboardLayer14.allCases {
            let slots = BAS14LayerMeshMap.slots(forLayer: layer)
            let uniqueRoles = Set(slots.map(\.headRole))
            XCTAssertEqual(
                uniqueRoles.count, slots.count,
                "duplicate role found within layer \(layer)")
        }
    }

    func testAllSlotsHaveNonEmptyHeadRole() {
        for slot in BAS14LayerMeshMap.canonical {
            XCTAssertFalse(
                slot.headRole.isEmpty,
                "slot at \(slot.layerID) has empty headRole")
        }
    }

    func testAllSlotsHaveNonEmptyDescription() {
        for slot in BAS14LayerMeshMap.canonical {
            XCTAssertFalse(
                slot.description.isEmpty,
                "slot \(slot.layerID).\(slot.headRole) has " +
                "empty description")
        }
    }

    func testAllSlotPrioritiesAreCanonicalTierValues() {
        // Every slot's priority must match one of the 5 canonical
        // tier priorities (0/10/20/30/40). No magic priorities
        // outside this set.
        let canonicalPriorities: Set<Int> = [
            BAS14LayerMeshMap.rulesTierPriority,
            BAS14LayerMeshMap.coremlOnDeviceTierPriority,
            BAS14LayerMeshMap.mlxLocalTierPriority,
            BAS14LayerMeshMap.appleFoundationModelTierPriority,
            BAS14LayerMeshMap.externalProviderTierPriority
        ]
        for slot in BAS14LayerMeshMap.canonical {
            XCTAssertTrue(
                canonicalPriorities.contains(slot.priority),
                "slot \(slot.layerID).\(slot.headRole) has " +
                "non-canonical priority \(slot.priority); " +
                "must be one of \(canonicalPriorities) per " +
                "chapter 一百七十七 cascade doctrine")
        }
    }

    func testAllSlotPrioritiesMatchExpectedKindTier() {
        // priority should match the expectedKind:
        // rules=0, coreml=10, mlx=20, AFM=30, external=40
        for slot in BAS14LayerMeshMap.canonical {
            let expectedPriority: Int
            switch slot.expectedKind {
            case .rules:
                expectedPriority =
                    BAS14LayerMeshMap.rulesTierPriority
            case .coremlOnDevice:
                expectedPriority =
                    BAS14LayerMeshMap.coremlOnDeviceTierPriority
            case .mlxLocal:
                expectedPriority =
                    BAS14LayerMeshMap.mlxLocalTierPriority
            case .appleFoundationModel:
                expectedPriority =
                    BAS14LayerMeshMap
                        .appleFoundationModelTierPriority
            case .externalProvider:
                expectedPriority =
                    BAS14LayerMeshMap.externalProviderTierPriority
            }
            XCTAssertEqual(
                slot.priority, expectedPriority,
                "slot \(slot.layerID).\(slot.headRole) " +
                "kind=\(slot.expectedKind.rawValue) but " +
                "priority=\(slot.priority); expected " +
                "priority=\(expectedPriority) per cascade doctrine")
        }
    }

    // MARK: - Specific role pins (regression-pin)

    func testL14HasMetaCalibrationHead() {
        let l14 = BAS14LayerMeshMap.slots(forLayer: .l14)
        let metaCal = l14.first { $0.headRole == "meta-calibration-head" }
        XCTAssertNotNil(metaCal,
            "chapter 一百七十七 vision § L14 explicitly names " +
            "meta-calibration-head as the keystone of meta-" +
            "calibration / 反迎合 layer")
    }

    func testL11HasCriticalRiskDetectorAtRulesTier() {
        let l11 = BAS14LayerMeshMap.slots(forLayer: .l11)
        let criticalRisk = l11.first {
            $0.headRole == "critical-risk-detector"
        }
        XCTAssertEqual(
            criticalRisk?.expectedKind, .rules,
            "critical-risk-detector must be RULES tier (chapter " +
            "一百七十七 doctrine: critical risks need " +
            "deterministic detection, not ML uncertainty)")
        XCTAssertEqual(
            criticalRisk?.priority,
            BAS14LayerMeshMap.rulesTierPriority,
            "critical-risk-detector at priority 0 (tried " +
            "first / sub-millisecond)")
    }

    func testL8HasFourMemoryHeads() {
        let l8 = BAS14LayerMeshMap.slots(forLayer: .l8)
        XCTAssertEqual(l8.count, 4,
            "L8 memory: 4 heads per chapter 一百七十七 vision " +
            "(importance / type / sensitivity / retrieval-rerank)")
        let roles = Set(l8.map(\.headRole))
        XCTAssertTrue(roles.contains("importance-scorer"))
        XCTAssertTrue(roles.contains("type-classifier"))
        XCTAssertTrue(roles.contains("sensitivity-scorer"))
        XCTAssertTrue(roles.contains("retrieval-reranker"))
    }
}
