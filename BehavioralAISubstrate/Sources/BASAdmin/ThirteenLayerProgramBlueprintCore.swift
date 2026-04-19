import Foundation

public enum BASEBrainTrackKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case physiology
    case cognition
    case infrastructure

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .physiology:
            "Physiology Track"
        case .cognition:
            "Cognition Track"
        case .infrastructure:
            "Infrastructure Track"
        }
    }
}

public enum BASEBrainLayerKind: Int, Codable, Sendable, CaseIterable, Identifiable {
    case powerClock = 1
    case neuralCore = 2
    case compressionRuntime = 3
    case foundation = 4
    case hostProfile = 5
    case context = 6
    case decompose = 7
    case memory = 8
    case loop = 9
    case triSelf = 10
    case risk = 11
    case action = 12
    case evolution = 13
    case sovereign = 14

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .powerClock:
            "L1 Power Clock"
        case .neuralCore:
            "L2 Neural Core"
        case .compressionRuntime:
            "L3 Compression Runtime"
        case .foundation:
            "L4 Foundation"
        case .hostProfile:
            "L5 Host Profile"
        case .context:
            "L6 Context"
        case .decompose:
            "L7 Decompose"
        case .memory:
            "L8 Memory"
        case .loop:
            "L9 Dream Loop"
        case .triSelf:
            "L10 Tri-Self"
        case .risk:
            "L11 Risk Gate"
        case .action:
            "L12 Action"
        case .evolution:
            "L13 Evolution"
        case .sovereign:
            "L14 Sovereign"
        }
    }

    public var track: BASEBrainTrackKind {
        switch self {
        case .powerClock, .neuralCore, .compressionRuntime, .foundation, .hostProfile:
            .physiology
        case .context, .decompose, .memory, .loop, .triSelf, .risk, .action, .evolution:
            .cognition
        case .sovereign:
            .infrastructure
        }
    }
}

public struct BASEBrainLayerBlueprint: Codable, Equatable, Sendable, Identifiable {
    public var kind: BASEBrainLayerKind
    public var summary: String
    public var primaryObjectIDs: [String]
    public var guardedBy: [String]

    public var id: BASEBrainLayerKind { kind }

    public init(
        kind: BASEBrainLayerKind,
        summary: String,
        primaryObjectIDs: [String] = [],
        guardedBy: [String] = []
    ) {
        self.kind = kind
        self.summary = summary
        self.primaryObjectIDs = primaryObjectIDs
        self.guardedBy = guardedBy
    }
}

public enum BASExecutionRepositoryBoundary: String, Codable, Sendable, CaseIterable {
    case currentRepository
    case externalTraining
    case mixed
}

public enum BASDeliveryBatch: Int, Codable, Sendable, CaseIterable {
    case first = 1
    case second = 2
    case third = 3
}

public struct BASWorkPackageOwnership: Codable, Equatable, Sendable {
    public var dri: String
    public var responsible: [String]
    public var consulted: [String]
    public var approver: String

    public init(
        dri: String,
        responsible: [String],
        consulted: [String],
        approver: String
    ) {
        self.dri = dri
        self.responsible = responsible
        self.consulted = consulted
        self.approver = approver
    }
}

public struct BASWorkPackageSchedule: Codable, Equatable, Sendable {
    public var duration: String
    public var prerequisiteIDs: [String]
    public var parallelIDs: [String]
    public var blockers: [String]
    public var milestoneIDs: [String]
    public var exitCriteria: [String]

    public init(
        duration: String,
        prerequisiteIDs: [String] = [],
        parallelIDs: [String] = [],
        blockers: [String] = [],
        milestoneIDs: [String],
        exitCriteria: [String]
    ) {
        self.duration = duration
        self.prerequisiteIDs = prerequisiteIDs
        self.parallelIDs = parallelIDs
        self.blockers = blockers
        self.milestoneIDs = milestoneIDs
        self.exitCriteria = exitCriteria
    }
}

public struct BASWorkPackageBlueprint: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var ownedLayers: [BASEBrainLayerKind]
    public var repositoryBoundary: BASExecutionRepositoryBoundary
    public var deliveryBatch: BASDeliveryBatch
    public var ownership: BASWorkPackageOwnership
    public var schedule: BASWorkPackageSchedule

    public init(
        id: String,
        title: String,
        summary: String,
        ownedLayers: [BASEBrainLayerKind],
        repositoryBoundary: BASExecutionRepositoryBoundary,
        deliveryBatch: BASDeliveryBatch,
        ownership: BASWorkPackageOwnership,
        schedule: BASWorkPackageSchedule
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.ownedLayers = ownedLayers
        self.repositoryBoundary = repositoryBoundary
        self.deliveryBatch = deliveryBatch
        self.ownership = ownership
        self.schedule = schedule
    }
}

public struct BASMilestoneBlueprint: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var exitCriteria: [String]

    public init(id: String, title: String, summary: String, exitCriteria: [String]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.exitCriteria = exitCriteria
    }
}

public struct BASSchemaGovernanceEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String { objectID }
    public var objectID: String
    public var currentVersion: String
    public var compatibilityWindow: String
    public var deprecationPolicy: String
    public var migrationTestIDs: [String]
    public var rollbackPolicy: String

    public init(
        objectID: String,
        currentVersion: String,
        compatibilityWindow: String,
        deprecationPolicy: String,
        migrationTestIDs: [String],
        rollbackPolicy: String
    ) {
        self.objectID = objectID
        self.currentVersion = currentVersion
        self.compatibilityWindow = compatibilityWindow
        self.deprecationPolicy = deprecationPolicy
        self.migrationTestIDs = migrationTestIDs
        self.rollbackPolicy = rollbackPolicy
    }
}

public struct BASProgramExecutionBlueprint: Codable, Equatable, Sendable {
    public var title: String
    public var summary: String
    public var layers: [BASEBrainLayerBlueprint]
    public var workPackages: [BASWorkPackageBlueprint]
    public var milestones: [BASMilestoneBlueprint]
    public var governedSchemas: [BASSchemaGovernanceEntry]
    public var requiredAppendices: [String]
    public var hardRedLines: [String]

    public init(
        title: String,
        summary: String,
        layers: [BASEBrainLayerBlueprint],
        workPackages: [BASWorkPackageBlueprint],
        milestones: [BASMilestoneBlueprint],
        governedSchemas: [BASSchemaGovernanceEntry],
        requiredAppendices: [String],
        hardRedLines: [String]
    ) {
        self.title = title
        self.summary = summary
        self.layers = layers
        self.workPackages = workPackages
        self.milestones = milestones
        self.governedSchemas = governedSchemas
        self.requiredAppendices = requiredAppendices
        self.hardRedLines = hardRedLines
    }
}

public enum BASProgramExecutionBlueprintBuilder {
    public static let v12 = BASProgramExecutionBlueprint(
        title: "宿基双生·13层电子脑全栈研发总纲 v1.2",
        summary: "Three execution tracks, nineteen work packages, explicit cross-layer schemas, and milestone-gated rollout for a mobile-first thirteen-layer electronic brain stack.",
        layers: [
            layer(.powerClock, "Power-clock layer owns lifecycle, wake intent, recovery/quarantine, sovereign actuation, and compute budget.", ["DeviceState", "BudgetFrame"], ["ActionPermit", "RuntimeTrace"]),
            layer(.neuralCore, "Neural-core layer owns Scout/Core model routing and structured heads.", ["ModelArtifact", "HeadOutputs"], ["BudgetFrame"]),
            layer(.compressionRuntime, "Compression runtime owns Breath-Fold-Resume contracts, ThoughtFold recovery anchors, checkpoint-safe rollback, and hot-start recovery.", ["ThoughtFold", "MorphGraph", "HotColdMap", "PrecisionProfile", "ResumeFrame", "RollbackAnchor", "LungState", "BreathScheduler", "RuntimeTrace"], ["BudgetFrame"]),
            layer(.foundation, "Foundation layer owns stable world priors, structure courses, and boundary priors.", ["BaseCheckpoint", "FoundationEval"], ["EvalSample"]),
            layer(.hostProfile, "Host layer owns the host constitution, compatibility host profile projection, host gate, deletion, rollback, and privacy vault.", ["HostConstitution", "HostConstitutionVault", "HostDeletionManifest", "HostSyncRevocationLedger", "HostVersionTree", "HostProfile", "HostVersion"], ["RiskCard", "UpdateTicket"]),
            layer(.context, "Context layer turns raw input into task, emotion, pressure, relation, and manipulation signals.", ["ContextFrame"], ["BudgetFrame", "HostProfile"]),
            layer(.decompose, "Decompose layer extracts facts, goals, unknowns, contradictions, and mirror text.", ["DecomposeFrame"], ["ContextFrame", "MemoryAtom"]),
            layer(.memory, "Memory layer owns hot/warm/cold retrieval, conflict fingerprints, and promotion.", ["MemoryAtom", "MemoryBundle"], ["HostProfile", "UpdateTicket"]),
            layer(.loop, "Dream-loop layer owns candidates, forecasts, critique, convergence, and bounded iteration.", ["ThoughtFrame", "CandidatePath"], ["BudgetFrame", "RiskCard"]),
            layer(.triSelf, "Tri-self layer fuses id, ego, and superego scoring into a merged choice.", ["TriSelfScore", "MergedChoice"], ["HostProfile", "RiskCard"]),
            layer(.risk, "Risk layer owns calibration, GSI, and ActionPermit. It remains on the critical path.", ["RiskCard", "ActionPermit"], ["BudgetFrame", "HostProfile"]),
            layer(.action, "Action layer renders answer, compare, delay, block, and replace modes without weakening boundaries.", ["RenderedOutput"], ["ActionPermit", "HostProfile"]),
            layer(.evolution, "Evolution layer emits UpdateTicket, rule candidates, and offline-learning exports.", ["UpdateTicket", "RuleCandidate"], ["RenderedOutput", "HostProfile"])
        ],
        workPackages: [
            wp("WP0", "总体架构与项目治理", "Freeze layer boundaries, object contracts, regression policy, and change control.", [], .currentRepository, .first, "Chief Architect", ["Chief Architect"], ["Evaluation Lead", "SDK Lead"], "Chief Architect", "2 weeks", [], ["WP14", "WP16"], ["Interface churn before M0"], ["M0"], ["13-layer glossary approved", "Schema governance entries frozen", "Regression gate policy published"]),
            wp("WP1", "灯芯层", "Ship the L1 kernel: run-mode state machine, wake intent, lease enforcement, recovery/quarantine, sovereign actuation, and maintenance arbitration.", [.powerClock], .currentRepository, .first, "Runtime Lead", ["Runtime Lead", "SDK Lead"], ["Loop Lead", "Risk Lead"], "Chief Architect", "4 weeks", ["WP0"], ["WP2", "WP5"], ["Real device thermal data"], ["M1", "M2"], ["L1 kernel contracts shipped", "High-risk downgrade and lease-enforcement rules covered by tests", "Maintenance never steals foreground budget and recovery stays auditable"]),
            wp("WP2", "脑肉层", "Build Scout/Core prototypes, structured heads, and decode controller.", [.neuralCore], .mixed, .first, "Model Lead", ["Model Lead", "Training Lead"], ["Runtime Lead", "Evaluation Lead"], "Chief Architect", "6 weeks", ["WP0"], ["WP1", "WP4", "WP15"], ["Checkpoint selection and head interference"], ["M1", "M5"], ["Scout/Core benchmarked", "Structured head pack defined", "High-risk misroute rate tracked"]),
            wp("WP3", "折叠肺", "Implement the L3 v2 folded-lung contracts, Breath-Fold-Resume state machine, sovereign rollback bridge, and checkpoint-safe recovery anchors before industrial quantization work.", [.compressionRuntime], .currentRepository, .second, "Compression Lead", ["Compression Lead", "SDK Lead"], ["Runtime Lead", "Risk Lead"], "Chief Architect", "5 weeks", ["WP1", "WP2"], ["WP8", "WP17"], ["ThoughtFold checksum and restore fidelity"], ["M4", "M6"], ["ThoughtFoldSpec published", "Hot-start flow passes regression", "Thermal downgrade remains ordered"]),
            wp("WP4", "地平线层", "Train stable base priors, structure curriculum, counterfactual curriculum, and boundary priors.", [.foundation], .externalTraining, .third, "Foundation Lead", ["Foundation Lead", "Training Lead"], ["Evaluation Lead", "Risk Lead"], "Chief Architect", "8 weeks", ["WP0", "WP14"], ["WP2", "WP15"], ["Curriculum quality and over-refusal"], ["M1", "M5"], ["Foundation checkpoint evaluated", "Structure course gain proven", "Boundary prior does not collapse language quality"]),
            wp("WP5", "宿纹层", "Implement the host constitution fabric, compatibility host profile projection, host gate, delete/freeze/rollback, and privacy vault.", [.hostProfile], .currentRepository, .first, "Host & Memory Lead", ["Host & Memory Lead", "SDK Lead"], ["Risk Lead", "Product Lead"], "Chief Architect", "4 weeks", ["WP0"], ["WP1", "WP8"], ["Deletion verification"], ["M1", "M4"], ["HostConstitutionSpec shipped", "Rollback is executable", "Host preference cannot bypass risk gate"]),
            wp("WP6", "临场眼", "Build task/emotion/pressure/relation/manipulation sensing and ContextFrame.", [.context], .currentRepository, .first, "Loop Lead", ["Loop Lead"], ["Risk Lead", "Foundation Lead"], "Chief Architect", "3 weeks", ["WP0", "WP1"], ["WP7", "WP11"], ["Manipulation false positives"], ["M2"], ["ContextFrame schema stable", "Task and manipulation detectors benchmarked"]),
            wp("WP7", "镜刃层", "Build decompose, mirror, contradiction, and slot validation.", [.decompose], .currentRepository, .first, "Loop Lead", ["Loop Lead"], ["Host & Memory Lead", "Product Lead"], "Chief Architect", "4 weeks", ["WP6"], ["WP8", "WP9"], ["Unknown slots must remain honest"], ["M2"], ["DecomposeFrame stable", "Mirror output validated", "Contradiction checks regression-covered"]),
            wp("WP8", "海马井", "Implement hot/warm/cold memory stores, conflict engine, promotion, and audit replay.", [.memory], .currentRepository, .second, "Host & Memory Lead", ["Host & Memory Lead"], ["Loop Lead", "Risk Lead"], "Chief Architect", "5 weeks", ["WP5", "WP7"], ["WP3", "WP13"], ["Conflict promotion and replay"], ["M4"], ["MemoryBundle stable", "Conflict fingerprints enforced", "Cold writes always require review"]),
            wp("WP9", "梦环层", "Implement bounded loop controller, candidates, forecast, critique, and stop policy.", [.loop], .currentRepository, .first, "Loop Lead", ["Loop Lead"], ["Runtime Lead", "Risk Lead"], "Chief Architect", "5 weeks", ["WP1", "WP7"], ["WP10", "WP11"], ["Dead-loop prevention"], ["M2", "M3"], ["Two-path loop shipped", "Stop conditions enforced", "Loop Utility Gain tracked"]),
            wp("WP10", "三我庭", "Implement id/ego/superego heads, fusion, veto, and explanation codes.", [.triSelf], .currentRepository, .second, "Loop Lead", ["Loop Lead", "Risk Lead"], ["Host & Memory Lead", "Product Lead"], "Chief Architect", "4 weeks", ["WP5", "WP9"], ["WP11", "WP12"], ["Over-suppression from superego"], ["M4"], ["TriSelf score contract stable", "Veto reasons surfaced", "Fusion remains explainable"]),
            wp("WP11", "风闸层", "Implement risk taxonomy, GSI, calibrated RiskCard, and ActionPermit.", [.risk], .currentRepository, .first, "Risk Lead", ["Risk Lead"], ["Loop Lead", "Evaluation Lead"], "Chief Architect", "5 weeks", ["WP6", "WP7", "WP9"], ["WP10", "WP16"], ["Calibration drift and GSI precision"], ["M2", "M3"], ["RiskCard schema stable", "Block/delay/replace live", "GSI stays on the main path"]),
            wp("WP12", "柔手层", "Render answer, compare, delay, block, and replace modes with host-aware tone.", [.action], .currentRepository, .first, "Product Lead", ["Product Lead"], ["Risk Lead", "Host & Memory Lead"], "Chief Architect", "3 weeks", ["WP5", "WP9", "WP11"], ["WP18"], ["Alternatives after block"], ["M2", "M3"], ["RenderedOutput supports all five modes", "Tone policy cannot weaken boundaries"]),
            wp("WP13", "蜕变炉", "Implement UpdateTicket generation, rule mining, write gate, and review queue.", [.evolution], .currentRepository, .second, "Host & Memory Lead", ["Host & Memory Lead", "Training Lead"], ["Risk Lead", "Evaluation Lead"], "Chief Architect", "4 weeks", ["WP5", "WP8", "WP11"], ["WP15"], ["No uncontrolled online learning"], ["M4", "M7"], ["UpdateTicket stable", "Cold-memory writes blocked without review", "Offline export path verified"]),
            wp("WP14", "数据工程与标注平台", "Govern structure/risk/host/manipulation data and strong hard negatives.", [], .externalTraining, .third, "Data Engineering Lead", ["Data Engineering Lead"], ["Risk Lead", "Host & Memory Lead"], "Chief Architect", "6 weeks", ["WP0"], ["WP4", "WP15", "WP16"], ["Gaslight and conflict dataset quality"], ["M0", "M3"], ["Annotation guide published", "Hard negatives cover manipulation, conflict, and host-vs-boundary collisions"]),
            wp("WP15", "训练与蒸馏平台", "Build teacher orchestration, multi-task training, distillation, and QAT.", [], .externalTraining, .third, "Training Lead", ["Training Lead", "Model Lead"], ["Evaluation Lead", "Compression Lead"], "Chief Architect", "8 weeks", ["WP2", "WP4", "WP13", "WP14"], ["WP16"], ["Teacher trace quality and task interference"], ["M5", "M6"], ["Teacher traces registered", "Loop strategy distillation measured", "QAT preserves risk heads"]),
            wp("WP16", "评测、红队与回归门禁", "Own benchmarks, gaslight red-team sets, mobile stress suites, and gates.", [], .currentRepository, .third, "Evaluation Lead", ["Evaluation Lead"], ["Risk Lead", "Runtime Lead", "Training Lead"], "Chief Architect", "5 weeks", ["WP0", "WP14"], ["WP11", "WP15", "WP17"], ["Real-device coverage and long-horizon regressions"], ["M0", "M3", "M6"], ["LUG/RCE/GRR/BCS/MCRA/EQR tracked", "Gaslight bench operational", "Daily and weekly gates live"]),
            wp("WP17", "端侧SDK、存储与集成", "Ship runtime API, encrypted store, host console, telemetry panel, and diagnostics.", [], .currentRepository, .third, "SDK Lead", ["SDK Lead", "Runtime Lead"], ["Product Lead", "Security Lead"], "Chief Architect", "6 weeks", ["WP1", "WP3", "WP5"], ["WP16", "WP18"], ["Cross-platform SDK parity"], ["M1", "M6"], ["Runtime API stable", "Encrypted store integrated", "Diagnostic replay available on device"]),
            wp("WP18", "产品化与灰度试运行", "Manage shadow mode, internal dogfood, pilot rollout, rollback, and field reporting.", [], .currentRepository, .third, "Release Lead", ["Release Lead", "Product Lead"], ["Evaluation Lead", "Runtime Lead", "Risk Lead"], "Chief Architect", "6 weeks", ["WP12", "WP16", "WP17"], [], ["Kill-switch coverage"], ["M6", "M7"], ["Shadow mode live", "Rollback plan exercised", "Pilot report includes ticket-to-training asset conversion"])
        ],
        milestones: [
            milestone("M0", "架构冻结", "Freeze 13-layer responsibilities, schema governance, KPI set, and regression gates.", ["13-layer glossary approved", "Program blueprint published", "Governed schema list frozen"]),
            milestone("M1", "底盘P0", "Budget, Scout/Core prototype, HostProfile lifecycle, and hot-start foundations live.", ["BudgetFrame implemented", "Scout/Core prototypes benchmarked", "HostProfile version/delete works"]),
            milestone("M2", "认知闭环Alpha", "Main cognitive loop replays end to end with ThoughtFrame, RiskCard, ActionPermit, and UpdateTicket.", ["Two-path loop works", "Replay path is available", "No uncontrolled loop growth"]),
            milestone("M3", "风险增强Beta", "GSI, forecast, critique, and block/delay/replace are stable and measurably safer than baseline.", ["RCE down vs baseline", "GRR up vs baseline", "High-risk compliance failure rate improved"]),
            milestone("M4", "宿主记忆Beta+", "Hot/warm/cold memory, conflicts, deletion/freeze/rollback, and host fidelity are trustworthy.", ["Conflict handling passes", "Cold writes require review", "Host rollback is verified"]),
            milestone("M5", "参数内化版", "Core heads and loop strategy move from orchestration into trained heads with reduced latency.", ["External orchestration shrinks", "Multi-head core benchmarked", "Distillation retains safety behavior"]),
            milestone("M6", "Mobile RC", "ThoughtFold, hot-start, quantized path, SDK, and mobile thermals meet release-candidate guardrails.", ["Thermal limits pass", "Startup path passes", "SDK integration docs published"]),
            milestone("M7", "Pilot试运行", "Pilot remains bounded, replayable, rollback-safe, and capable of turning tickets into offline learning assets.", ["Kill switch exercised", "Replay and rollback validated", "Field report delivered"])
        ],
        governedSchemas: BASEBrainSchemaGovernanceRegistry.governedSchemas,
        requiredAppendices: [
            "Appendix A: Key-path schedule",
            "Appendix B: RACI / DRI matrix",
            "Appendix C: Schema governance and compatibility",
            "Appendix D: Security, privacy, and rollback plan"
        ],
        hardRedLines: [
            "High-risk conversations must never write directly into cold memory.",
            "Host preferences must never bypass the risk gate.",
            "Host-private data must never enter long-term foundation training.",
            "The system must never be judged on language naturalness alone.",
            "Long-form text CoT must not be the only internal mobile runtime state.",
            "Long-term memory must not ship without delete, freeze, and rollback.",
            "Public rollout must not happen without block, delay, and replace strategies.",
            "Production must not silently rewrite long-term host identity or rules.",
            "Manipulation detection must avoid collapsing normal disagreement into gaslighting.",
            "External messaging must not claim human consciousness, therapy authority, or absolute judgment."
        ]
    )

    public static let v13: BASProgramExecutionBlueprint = {
        var blueprint = v12
        blueprint.title = "宿基双生·14层电子脑全栈研发总纲 v1.3"
        blueprint.summary = "Three execution tracks, nineteen work packages, explicit cross-layer schemas, and milestone-gated rollout for a mobile-first fourteen-layer electronic brain stack."
        blueprint.layers = v12.layers.map { layer in
            var updated = layer
            switch layer.kind {
            case .powerClock:
                updated.summary = "Power-clock layer owns lifecycle, wake intent, recovery/quarantine, lease enforcement, and compute budget."
                updated.guardedBy = ["ActionPermit", "RuntimeTrace", "SovereignExecutionReceipt"]
            case .evolution:
                updated.summary = "Evolution layer emits UpdateTicket, rule candidates, review payloads, and offline-learning exports."
            default:
                break
            }
            return updated
        } + [
            layer(
                .sovereign,
                "Sovereign layer owns actuation commands, execution receipts, kill-switch contraction, and rollback-safe command bridging.",
                [
                    "SovereignVerdict",
                    "SovereignCommitToken",
                    "SovereignLock",
                    "QuarantineRecord",
                    "SovereignAuditEntry",
                    "SovereignActuationCommand",
                    "SovereignExecutionReceipt",
                    "RuntimePolicyLineage"
                ],
                ["ActionPermit", "ThoughtFold", "HostConstitution"]
            )
        ]
        blueprint.workPackages = v12.workPackages.map { package in
            var updated = package
            switch package.id {
            case "WP0":
                updated.schedule.exitCriteria = updated.schedule.exitCriteria.map { criterion in
                    criterion == "13-layer glossary approved" ? "14-layer glossary approved" : criterion
                }
            case "WP1":
                updated.summary = "Ship the L1/L14 kernel spine: run-mode state machine, wake intent, lease enforcement, recovery/quarantine, sovereign actuation, and maintenance arbitration."
                updated.ownedLayers = [.powerClock, .sovereign]
            default:
                break
            }
            return updated
        }
        blueprint.milestones = v12.milestones.map { milestone in
            var updated = milestone
            if milestone.id == "M0" {
                updated.summary = "Freeze 14-layer responsibilities, schema governance, KPI set, and regression gates."
                updated.exitCriteria = milestone.exitCriteria.map { criterion in
                    criterion == "13-layer glossary approved" ? "14-layer glossary approved" : criterion
                }
            }
            return updated
        }
        return blueprint
    }()

    public static let latest = v13

    private static func layer(
        _ kind: BASEBrainLayerKind,
        _ summary: String,
        _ primaryObjectIDs: [String],
        _ guardedBy: [String]
    ) -> BASEBrainLayerBlueprint {
        BASEBrainLayerBlueprint(
            kind: kind,
            summary: summary,
            primaryObjectIDs: primaryObjectIDs,
            guardedBy: guardedBy
        )
    }

    private static func wp(
        _ id: String,
        _ title: String,
        _ summary: String,
        _ ownedLayers: [BASEBrainLayerKind],
        _ repositoryBoundary: BASExecutionRepositoryBoundary,
        _ deliveryBatch: BASDeliveryBatch,
        _ dri: String,
        _ responsible: [String],
        _ consulted: [String],
        _ approver: String,
        _ duration: String,
        _ prerequisites: [String],
        _ parallelIDs: [String],
        _ blockers: [String],
        _ milestoneIDs: [String],
        _ exitCriteria: [String]
    ) -> BASWorkPackageBlueprint {
        BASWorkPackageBlueprint(
            id: id,
            title: title,
            summary: summary,
            ownedLayers: ownedLayers,
            repositoryBoundary: repositoryBoundary,
            deliveryBatch: deliveryBatch,
            ownership: BASWorkPackageOwnership(
                dri: dri,
                responsible: responsible,
                consulted: consulted,
                approver: approver
            ),
            schedule: BASWorkPackageSchedule(
                duration: duration,
                prerequisiteIDs: prerequisites,
                parallelIDs: parallelIDs,
                blockers: blockers,
                milestoneIDs: milestoneIDs,
                exitCriteria: exitCriteria
            )
        )
    }

    private static func milestone(
        _ id: String,
        _ title: String,
        _ summary: String,
        _ exitCriteria: [String]
    ) -> BASMilestoneBlueprint {
        BASMilestoneBlueprint(id: id, title: title, summary: summary, exitCriteria: exitCriteria)
    }
}
