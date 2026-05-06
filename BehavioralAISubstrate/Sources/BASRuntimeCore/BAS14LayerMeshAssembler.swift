// MARK: - BAS14LayerMeshAssembler — chapter 三百一七 / M804
//
// Phase Epsilon 第四刀:end-to-end 14-layer mesh assembly helper。
// Combines `BAS14LayerMeshMap.canonical` (chapter 三百一三 typed
// inventory) + `BASRulesBasedLayerMLHead` (chapter 三百一一
// rules-tier wrapper) + `BASLayerMLHeadRegistry` (chapter 三百一〇)
// into one-line full mesh population for hosts that want the
// canonical 41-slot mesh shape ready-made。
//
// ## Why now
//
// chapter 三百一三 (M800) shipped the canonical 41-slot map。
// chapter 三百一一 (M798) shipped the rules-tier wrapper。
// chapter 三百一〇 (M797) shipped the registry actor。
// chapter 三百一二 (M799) shipped the cascade runner。
// chapter 三百一六 (M803) shipped the reference layer actor。
//
// All foundation pieces exist。This chapter ships the **assembly**
// that combines them — hosts call one method to get a fully
// populated registry matching the canonical mesh shape:
//
//     let registry = try await BAS14LayerMeshAssembler
//         .assembleCanonicalRulesPlaceholder()
//
// Result: registry has 41 rules-tier placeholder heads at canonical
// priority + role mapping。Hosts can immediately drive cascade
// inference on any of the 12 model-layer slots without writing
// 41 separate registration calls。
//
// **0 behavior change**:purely additive helper。Hosts that don't
// call this assembler keep their own mesh population logic。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — assembler builds rules-tier
//     placeholders, no production decision path changes
//   - 红线 7 watcher hint only — placeholders return rules-class
//     hints
//   - 单提交口 (L11/L14) 不变 — assembler doesn't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE assembly
//     entry point for canonical mesh population
//   - chapter 一百八十五 anti-magic-number: priority comes from
//     BAS14LayerMeshMap canonical tier constants
//   - chapter 三百一三 BAS14LayerMeshMap: assembler reads
//     `.canonical` as authoritative slot inventory
//   - chapter 三百一一 BASRulesBasedLayerMLHeadFactory: each
//     placeholder is a `.makeAlwaysFallthrough` head emitting
//     `rules-fallthrough:<headID>` reason code (forces cascade
//     descent — placeholder doesn't pretend to be authoritative)
//   - chapter 三百一〇 BASLayerMLHeadRegistry: assembler registers
//     into a fresh registry actor, returns it ready for use

import Foundation

// MARK: - Assembly result record

/// Typed result of canonical mesh assembly。
public struct BAS14LayerMeshAssemblyReport: Sendable {
    public let registeredHeadCount: Int
    public let perLayerCounts: [BASMotherboardLayer14: Int]
    public let totalCanonicalSlots: Int

    public init(
        registeredHeadCount: Int,
        perLayerCounts: [BASMotherboardLayer14: Int],
        totalCanonicalSlots: Int
    ) {
        self.registeredHeadCount = registeredHeadCount
        self.perLayerCounts = perLayerCounts
        self.totalCanonicalSlots = totalCanonicalSlots
    }

    /// Assembly succeeded if every canonical slot got a head
    /// registered。
    public var isComplete: Bool {
        registeredHeadCount == totalCanonicalSlots
    }
}

// MARK: - Assembler namespace

/// Namespace for end-to-end mesh assembly helpers。
public enum BAS14LayerMeshAssembler {

    /// Assemble a fresh `BASLayerMLHeadRegistry` populated with
    /// rules-tier placeholder heads matching the canonical 41-slot
    /// inventory from `BAS14LayerMeshMap.canonical`。
    ///
    /// Each placeholder is a `BASRulesBasedLayerMLHead` constructed
    /// via `BASRulesBasedLayerMLHeadFactory.makeAlwaysFallthrough`
    /// so it returns `.unknown` confidence — forces cascade
    /// descent, doesn't pretend to be authoritative。Hosts replace
    /// individual placeholder heads with real CoreML/MLX/AFM
    /// adapters as those become available (priority 10/20/30 in
    /// the same slot supersedes the priority-0 rules placeholder
    /// when registered)。
    ///
    /// - Returns: tuple of (populated registry, assembly report)
    /// - Throws: BASLayerMLHeadRegistrationError on failure
    ///   (shouldn't fire — canonical map has no duplicate IDs)
    public static func assembleCanonicalRulesPlaceholder()
        async throws
        -> (registry: BASLayerMLHeadRegistry,
            report: BAS14LayerMeshAssemblyReport)
    {
        let registry = BASLayerMLHeadRegistry()
        var perLayerCounts:
            [BASMotherboardLayer14: Int] = [:]

        for slot in BAS14LayerMeshMap.canonical {
            // Build canonical headID from slot.layerID + slot.headRole
            let headID = "rules.\(slot.layerID.rawValue)." +
                slot.headRole
            let head = BASRulesBasedLayerMLHeadFactory
                .makeAlwaysFallthrough(
                    headID: headID,
                    layerIDPin: slot.layerID)
            try await registry.register(
                head: head,
                layerID: slot.layerID,
                priority: slot.priority)
            perLayerCounts[slot.layerID, default: 0] += 1
        }

        let registeredCount = await registry.totalHeadCount
        let report = BAS14LayerMeshAssemblyReport(
            registeredHeadCount: registeredCount,
            perLayerCounts: perLayerCounts,
            totalCanonicalSlots:
                BAS14LayerMeshMap.totalSlotCount)
        return (registry, report)
    }

    /// Construct typed audit reason codes for an assembly report。
    public static func reasonCodes(
        for report: BAS14LayerMeshAssemblyReport
    ) -> [String] {
        var codes: [String] = [
            "mesh-assembly:registered:\(report.registeredHeadCount)",
            "mesh-assembly:canonical-total:" +
            "\(report.totalCanonicalSlots)",
            "mesh-assembly:complete:\(report.isComplete)"
        ]
        for layer in BASMotherboardLayer14.allCases {
            let count = report.perLayerCounts[layer] ?? 0
            codes.append(
                "mesh-assembly:layer-\(layer.rawValue):\(count)")
        }
        return codes
    }
}
