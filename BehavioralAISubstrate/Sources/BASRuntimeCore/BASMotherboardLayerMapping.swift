import Foundation

// 六十二.1 — typed L1-L14 ↔ motherboard home mapping.
//
// ## Why this exists
//
// Manifesto v3 第五节 names which kernel / bus / vault each
// L1-L14 layer "lives in". 五十五 ship 了 6 个粗骨架 enum
// (Kernel/Bus/Vault) but **每层挂在哪儿** 只在文档里，没在
// 代码里 typed-pinned。Audit code wanting to grep "L9 lives
// on which bus" had no typed answer.
//
// 六十二.1 ships the typed map: each layer has a primary
// kernel, optional primary bus, optional primary vault.
//
// ## Doctrine (from manifesto v3 第五节)
//
// L1-L3 → Lease & Life Kernel + Neural Organ Runtime + Snapshot Ark
// L4-L5 → World Prior Vault + Host Constitution Vault + State Graph Kernel
// L6-L13 → SituationBus / CognitiveFrameBus / MemoryBus /
//          FrontierBus / RiskPermitBus / VersionAuditBus
// L14 → Sovereign Microkernel + Snapshot Ark + Capability tokens
//       + Append-only audit ledger
//
// ## Properties
//
// - **Pure typed reference.** No I/O, no runtime contract.
// - **Total mapping.** Every L1-L14 layer has a primaryKernel
//   (non-optional). Bus and vault are optional because some
//   layers don't directly bind to one.
// - **Snapshot Ark cross-cutting.** L1, L2, L3, L14 all
//   reference it (Doctrine 五.内核一 + 内核二 + 内核三 + L14
//   manifest). Tests pin this.

public enum BASMotherboardLayer14:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    case l1, l2, l3, l4, l5, l6, l7
    case l8, l9, l10, l11, l12, l13, l14
}

public extension BASCognitiveLayer {
    /// Total compatibility projection to the legacy compact layer
    /// taxonomy. Semantic authority remains with this type.
    var motherboardLayer14: BASMotherboardLayer14 {
        switch self {
        case .leaseLife: return .l1
        case .neuralOrgan: return .l2
        case .thoughtFold: return .l3
        case .worldPrior: return .l4
        case .hostConstitution: return .l5
        case .presenceEye: return .l6
        case .mirrorBlade: return .l7
        case .hippocampalWell: return .l8
        case .dreamLoop: return .l9
        case .triSelfTribunal: return .l10
        case .riskClimate: return .l11
        case .gentleHand: return .l12
        case .evolutionFurnace: return .l13
        case .sovereign: return .l14
        }
    }
}

public extension BASMotherboardLayer14 {
    /// Total compatibility projection back to the canonical semantic
    /// layer owner.
    var semanticLayerID: BASSemanticLayerID {
        switch self {
        case .l1: return .leaseLife
        case .l2: return .neuralOrgan
        case .l3: return .thoughtFold
        case .l4: return .worldPrior
        case .l5: return .hostConstitution
        case .l6: return .presenceEye
        case .l7: return .mirrorBlade
        case .l8: return .hippocampalWell
        case .l9: return .dreamLoop
        case .l10: return .triSelfTribunal
        case .l11: return .riskClimate
        case .l12: return .gentleHand
        case .l13: return .evolutionFurnace
        case .l14: return .sovereign
        }
    }

    /// Each layer has exactly one home kernel. From doctrine
    /// 第五节: L1-L3 split between leaseAndLife and
    /// neuralOrganRuntime; L4-L13 in stateAndEvolutionGraph;
    /// L14 in sovereignMicrokernel.
    var primaryKernel: BASMotherboardKernel {
        switch self {
        case .l1:
            return .leaseAndLife
        case .l2, .l3:
            return .neuralOrganRuntime
        case .l4, .l5, .l6, .l7, .l8,
             .l9, .l10, .l11, .l12, .l13:
            return .stateAndEvolutionGraph
        case .l14:
            return .sovereignMicrokernel
        }
    }

    /// Each layer has at most one primary bus it speaks
    /// through. Some layers (L2/L3/L12) don't directly own a
    /// bus — they consume what others emit.
    var primaryBus: BASMotherboardBus? {
        switch self {
        case .l1: return .lease
        case .l2, .l3: return nil
        case .l4, .l5: return .worldHost
        case .l6: return .situation
        case .l7, .l10: return .cognitiveFrame
        case .l8: return .memory
        case .l9: return .frontier
        case .l11: return .riskPermit
        case .l12: return nil
        case .l13, .l14: return .versionAudit
        }
    }

    /// Each layer has at most one primary vault. L1-L3 + L14
    /// reference snapshot ark; L4 → world prior vault; L5 →
    /// host constitution vault; L6-L13 don't bind a vault
    /// directly.
    var primaryVault: BASMotherboardVault? {
        switch self {
        case .l1, .l2, .l3: return .snapshotArk
        case .l4: return .worldPriorVault
        case .l5: return .hostConstitutionVault
        case .l6, .l7, .l8, .l9,
             .l10, .l11, .l12, .l13: return nil
        case .l14: return .snapshotArk
        }
    }
}

public extension BASMotherboardKernel {
    /// Inverse: which layers home in this kernel.
    var hostedLayers: [BASMotherboardLayer14] {
        BASMotherboardLayer14.allCases.filter {
            $0.primaryKernel == self
        }
    }
}

public extension BASMotherboardBus {
    /// Inverse: which layers speak through this bus.
    var speakingLayers: [BASMotherboardLayer14] {
        BASMotherboardLayer14.allCases.filter {
            $0.primaryBus == self
        }
    }
}

public extension BASMotherboardVault {
    /// Inverse: which layers reference this vault.
    var referencingLayers: [BASMotherboardLayer14] {
        BASMotherboardLayer14.allCases.filter {
            $0.primaryVault == self
        }
    }
}
