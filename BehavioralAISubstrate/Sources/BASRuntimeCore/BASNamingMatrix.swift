// MARK: - BASNamingMatrix — chapter 四百三 / M959 — 系统熵 reduction
//
// Phase 2 entropy 第七刀:typed registry bridging the 4
// classification schemes the substrate uses concurrently:
//
//   1. **14-layer motherboard** (L1-L14): architectural layer
//      labels (e.g. L11 = risk plane,L14 = sovereign verdict)
//   2. **vision §1-§13**: white-paper section refs (target
//      spec sections that drove implementation)
//   3. **G1-G13 roadmap gaps**: chapter 三百五三 / M840 cognitive
//      OS roadmap (already a typed enum: `BASCognitiveOSGap`)
//   4. **chapter-M numbers**: implementation checkpoints
//      (chapter 三百五三 / M840,chapter 四百一 / M928,etc.)
//
// Per the chapter 四百三 entropy audit:
//
//   > Naming entropy: very high. The codebase simultaneously
//   > uses L-layer refs / §-section refs / M-number refs /
//   > chapter (Chinese+Arabic) refs. No single 'definition
//   > source' exists. Phase 2 should mint a naming directory。
//
// `BASNamingMatrix` is the typed source-of-truth bridging the
// 4 schemes。Hosts + tests + audit emission can query the
// matrix instead of inferring cross-scheme refs from comments。
//
// ## Why this exists (system entropy framing)
//
// Concrete naming-drift examples the audit caught:
//
//   - `kunlunAxis` (M406 doctrine) is also `L9 world-anchor`
//     (L-layer terminology)。No bridge between them。
//   - `abyssalPermitEscalation` (M384 doctrine) has no
//     L-layer equivalent name;only via white-paper §5
//     reference。
//   - `triSelfService` / `triSelfScore` (L10 tribunal)
//     documented in §11 but not indexed。
//
// `BASNamingMatrix` ships:
//
//   - `BASMotherboardLayer` typed enum (L1-L14)
//   - `BASNamingMatrix.entries` static registry mapping each
//     concept to its 4-scheme tuple
//   - `BASNamingMatrix.lookup(layer:)` etc. typed queries
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — registry is observation-only
//   - chapter 一百八十五 anti-magic-number — cross-scheme refs
//     pinned as typed constants,not free-form strings
//   - chapter 二百一一 single-source-of-truth — ONE matrix
//     replaces ad-hoc cross-scheme refs in commit messages
//   - ADR-014 OPT-IN — purely additive
//   - 系统熵 reduction — naming entropy: HIGH → contained

import Foundation

// MARK: - 14-layer motherboard

/// Typed enum naming the 14 cognitive OS motherboard layers
/// per the chapter-spanning architecture diagram。Raw values
/// pinned for grep stability。
public enum BASMotherboardLayer:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable,
    CaseIterable
{
    /// L1 灯芯层 — wick life kernel (thermal / breath /
    /// device routing root)
    case l1WickLifeKernel = "l1-wick-life-kernel"
    /// L2 神经组织层 — brain tissue (organ map + neural
    /// substrates)
    case l2BrainTissue = "l2-brain-tissue"
    /// L3 折叠肺 — folded lung (memory evolution + respiration)
    case l3FoldedLung = "l3-folded-lung"
    /// L4 世界先验 — world prior (background beliefs /
    /// boundaries)
    case l4WorldPrior = "l4-world-prior"
    /// L5 宿纹层 — host constitution (host vault + version
    /// tree)
    case l5HostConstitution = "l5-host-constitution"
    /// L6 处境界 — situation field (context / utterance /
    /// presence)
    case l6SituationField = "l6-situation-field"
    /// L7 镜锋层 — mirror blade (decompose / mirror /
    /// contradictions)
    case l7MirrorBlade = "l7-mirror-blade"
    /// L8 海马层 — hippocampal memory (atom storage +
    /// retrieval)
    case l8HippocampalMemory = "l8-hippocampal-memory"
    /// L9 昆仑轴 — kunlun axis (world anchor / tribunal
    /// boundary)
    case l9KunlunAxis = "l9-kunlun-axis"
    /// L10 三我审议 — tri-self tribunal (arbitration / merge
    /// choice)
    case l10TriSelfTribunal = "l10-tri-self-tribunal"
    /// L11 风险平面 — risk plane (risk card / permit gate)
    case l11RiskPlane = "l11-risk-plane"
    /// L12 软掌层 — soft hand (render / output staging)
    case l12SoftHand = "l12-soft-hand"
    /// L13 演化层 — evolution (update tickets / lifecycle)
    case l13Evolution = "l13-evolution"
    /// L14 主权审计 — sovereign audit (verdict / warrant /
    /// commit token)
    case l14SovereignAudit = "l14-sovereign-audit"
}

public extension BASCognitiveLayer {
    /// Total compatibility projection to the legacy descriptive
    /// naming-matrix taxonomy. Semantic authority remains here.
    var motherboardLayer: BASMotherboardLayer {
        switch self {
        case .leaseLife: return .l1WickLifeKernel
        case .neuralOrgan: return .l2BrainTissue
        case .thoughtFold: return .l3FoldedLung
        case .worldPrior: return .l4WorldPrior
        case .hostConstitution: return .l5HostConstitution
        case .presenceEye: return .l6SituationField
        case .mirrorBlade: return .l7MirrorBlade
        case .hippocampalWell: return .l8HippocampalMemory
        case .dreamLoop: return .l9KunlunAxis
        case .triSelfTribunal: return .l10TriSelfTribunal
        case .riskClimate: return .l11RiskPlane
        case .gentleHand: return .l12SoftHand
        case .evolutionFurnace: return .l13Evolution
        case .sovereign: return .l14SovereignAudit
        }
    }
}

public extension BASMotherboardLayer {
    /// Total compatibility projection back to the canonical semantic
    /// layer owner.
    var semanticLayerID: BASSemanticLayerID {
        switch self {
        case .l1WickLifeKernel: return .leaseLife
        case .l2BrainTissue: return .neuralOrgan
        case .l3FoldedLung: return .thoughtFold
        case .l4WorldPrior: return .worldPrior
        case .l5HostConstitution: return .hostConstitution
        case .l6SituationField: return .presenceEye
        case .l7MirrorBlade: return .mirrorBlade
        case .l8HippocampalMemory: return .hippocampalWell
        case .l9KunlunAxis: return .dreamLoop
        case .l10TriSelfTribunal: return .triSelfTribunal
        case .l11RiskPlane: return .riskClimate
        case .l12SoftHand: return .gentleHand
        case .l13Evolution: return .evolutionFurnace
        case .l14SovereignAudit: return .sovereign
        }
    }
}

// MARK: - Vision section ref

/// Typed white-paper section ref。Range 1-13 covers the §1-§13
/// vision concepts (target spec sections)。
public struct BASVisionSection:
    Codable, Equatable, Hashable, Sendable
{
    public let number: Int  // 1-13

    public init?(number: Int) {
        guard number >= 1 && number <= 13 else { return nil }
        self.number = number
    }

    public var label: String {
        "§\(number)"
    }
}

// MARK: - Chapter-M ref

/// Typed (chapter, M-number) ref。Both fields pinned as
/// chapter-纪元 stable IDs。
public struct BASChapterMRef:
    Codable, Equatable, Hashable, Sendable
{
    /// Chapter number (Arabic; the substrate uses Chinese
    /// numerals in source comments — `chapter 四百二` — but
    /// stores the Arabic equivalent here for typed comparison)。
    public let chapter: Int
    /// M-number (M941, M953, etc.)
    public let mNumber: Int

    public init(chapter: Int, mNumber: Int) {
        self.chapter = chapter
        self.mNumber = mNumber
    }
}

// MARK: - Naming matrix entry

/// One row in the naming matrix。Maps a concept to its peers
/// across all 4 classification schemes。At least one of the
/// 4 fields is non-nil。
public struct BASNamingMatrixEntry:
    Codable, Equatable, Hashable, Sendable
{
    public let conceptName: String
    public let layer: BASMotherboardLayer?
    public let visionSection: BASVisionSection?
    public let roadmapGap: BASCognitiveOSGap?
    public let chapterMRef: BASChapterMRef?

    public init(
        conceptName: String,
        layer: BASMotherboardLayer? = nil,
        visionSection: BASVisionSection? = nil,
        roadmapGap: BASCognitiveOSGap? = nil,
        chapterMRef: BASChapterMRef? = nil
    ) {
        self.conceptName = conceptName
        self.layer = layer
        self.visionSection = visionSection
        self.roadmapGap = roadmapGap
        self.chapterMRef = chapterMRef
    }
}

// MARK: - Matrix namespace

/// Typed registry bridging the 4 classification schemes。
/// Source-of-truth for cross-scheme concept refs。chapter
/// 四百三 / M959 entropy reduction。
public enum BASNamingMatrix {

    /// Doctrine version。Bumped when entries are added/changed
    /// per chapter 八十七 raw value stability。
    public static let matrixVersion: String = "M959"

    /// Pinned registry of concepts and their cross-scheme
    /// peers。Add new entries via PR;every entry is a typed
    /// constant (chapter 一百八十五 anti-magic-number)。
    public static let entries: [BASNamingMatrixEntry] = [
        BASNamingMatrixEntry(
            conceptName: "event-sourced-event-log",
            layer: .l8HippocampalMemory,
            visionSection: BASVisionSection(number: 8),
            roadmapGap: .g1EventLog,
            chapterMRef: BASChapterMRef(
                chapter: 354, mNumber: 841)),
        BASNamingMatrixEntry(
            conceptName: "user-state-reducer",
            layer: .l8HippocampalMemory,
            roadmapGap: .g2UserState,
            chapterMRef: BASChapterMRef(
                chapter: 355, mNumber: 842)),
        BASNamingMatrixEntry(
            conceptName: "constitution-gate",
            layer: .l5HostConstitution,
            roadmapGap: .g3ConstitutionGate),
        BASNamingMatrixEntry(
            conceptName: "vector-rag",
            layer: .l8HippocampalMemory,
            roadmapGap: .g4VectorRAG),
        BASNamingMatrixEntry(
            conceptName: "layer-factories",
            roadmapGap: .g5LayerFactories),
        BASNamingMatrixEntry(
            conceptName: "afm-tool-calling",
            roadmapGap: .g6AFMToolCalling),
        BASNamingMatrixEntry(
            conceptName: "active-verifier",
            layer: .l10TriSelfTribunal,
            roadmapGap: .g7ActiveVerifier),
        BASNamingMatrixEntry(
            conceptName: "mamba-ssm",
            roadmapGap: .g8MambaSSM),
        BASNamingMatrixEntry(
            conceptName: "knowledge-graph",
            roadmapGap: .g9KnowledgeGraph),
        BASNamingMatrixEntry(
            conceptName: "layer-actors",
            roadmapGap: .g10LayerActors),
        BASNamingMatrixEntry(
            conceptName: "mlx-coreml",
            roadmapGap: .g11MLXCoreML),
        BASNamingMatrixEntry(
            conceptName: "auto-eval",
            roadmapGap: .g12AutoEval),
        BASNamingMatrixEntry(
            conceptName: "mamba-frontier",
            roadmapGap: .g13MambaFrontier),
        // Layer-only concepts (no current G-gap)
        BASNamingMatrixEntry(
            conceptName: "world-prior",
            layer: .l4WorldPrior,
            visionSection: BASVisionSection(number: 4)),
        BASNamingMatrixEntry(
            conceptName: "kunlun-axis",
            layer: .l9KunlunAxis,
            visionSection: BASVisionSection(number: 5),
            chapterMRef: BASChapterMRef(
                chapter: 0, mNumber: 406)),
        BASNamingMatrixEntry(
            conceptName: "abyssal-permit-escalation",
            layer: .l11RiskPlane,
            visionSection: BASVisionSection(number: 5),
            chapterMRef: BASChapterMRef(
                chapter: 0, mNumber: 384)),
        BASNamingMatrixEntry(
            conceptName: "tri-self-tribunal",
            layer: .l10TriSelfTribunal,
            visionSection: BASVisionSection(number: 11)),
        BASNamingMatrixEntry(
            conceptName: "memory-event-sourced-unification",
            layer: .l8HippocampalMemory,
            chapterMRef: BASChapterMRef(
                chapter: 402, mNumber: 941)),
        BASNamingMatrixEntry(
            conceptName: "frame-context-typed-primitive",
            chapterMRef: BASChapterMRef(
                chapter: 403, mNumber: 953)),
    ]

    // MARK: - Typed queries

    /// All entries naming a given motherboard layer。
    public static func entries(
        for layer: BASMotherboardLayer
    ) -> [BASNamingMatrixEntry] {
        entries.filter { $0.layer == layer }
    }

    /// All entries naming a given roadmap gap。
    public static func entries(
        for gap: BASCognitiveOSGap
    ) -> [BASNamingMatrixEntry] {
        entries.filter { $0.roadmapGap == gap }
    }

    /// All entries naming a given vision section number。
    public static func entries(
        forVisionSection number: Int
    ) -> [BASNamingMatrixEntry] {
        entries.filter { $0.visionSection?.number == number }
    }

    /// Look up a concept by exact name。
    public static func entry(
        named conceptName: String
    ) -> BASNamingMatrixEntry? {
        entries.first { $0.conceptName == conceptName }
    }

    /// Resolve canonical stable IDs and the exact L9 display aliases
    /// without minting another semantic-layer identity.
    public static func layerID(
        resolving alias: String
    ) -> BASSemanticLayerID? {
        if let stableID = BASSemanticLayerID(rawValue: alias) {
            return stableID
        }

        switch alias {
        case "Kunlun", "Dream":
            return .dreamLoop
        default:
            return nil
        }
    }
}
