import Foundation
import BASHostKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - M573 (chapter 一百四十七 part 2) bench helpers (inlined here
// because adding a separate file requires Xcode project edits)

struct SampleHostBenchRow: Codable, Sendable, Equatable {
    let timestamp: String
    let iteration: Int
    let seed: Int
    let signature: SampleHostPromptSignature
    let prompt: String
    let auditCodeCount: Int
    let permitMode: String
    let bodyLength: Int
    let durationSeconds: Double
    let status: String
    let errorMessage: String?
    /// **M604 chapter 一百七十四 — procedural generation params**.
    /// Captured per-iter so post-bench analysis can correlate
    /// substrate behavior with stride × mutation combinations.
    /// Goal (user "通过冒烟找到最合适程序化生成"): discover which
    /// stride / mutation combos surface defects.
    let stride: Int?
    let mutationSeed: Int?
}

// MARK: - M574 (chapter 一百四十九) — Combinatorial prompt generator
// inlined for SampleHost iOS target (which can't depend on QinaoLoop
// module without Xcode project surgery). Mirrors
// QinaoExtendedPromptCorpus exactly: 6 typed dimensions = 8 × 10 × 6 ×
// 7 × 4 × 3 = 40,320 unique prompts.

enum SampleHostPromptTone: String, CaseIterable {
    case anxious, authoritative, vulnerable, agentic
    case confused, grieving, curious, angry
}

enum SampleHostPromptDomain: String, CaseIterable {
    case financial, medical, relational, work, parenting
    case identity, ethical, existential, trauma, creative
}

enum SampleHostPromptStake: String, CaseIterable {
    case low, modest, high
    case veryHigh = "very-high"
    case irreversible
    case nonReversibleAfterAct = "non-reversible-after-act"
}

enum SampleHostPromptTimeframe: String, CaseIterable {
    case minutes, hours, days, weeks, months, lifetime
    case pastUnresolved = "past-unresolved"
}

enum SampleHostPromptConfidant: String, CaseIterable {
    case friend, expert, stranger
    case decisionSystem = "decision-system"
}

enum SampleHostPromptAskShape: String, CaseIterable {
    case narrative
    case decisionTree = "decision-tree"
    case singleAction = "single-action"
}

struct SampleHostPromptSignature: Sendable, Equatable, Codable, Hashable {
    let tone: String
    let domain: String
    let stake: String
    let timeframe: String
    let confidant: String
    let askShape: String
}

struct SampleHostGeneratedPrompt: Sendable, Equatable {
    let signature: SampleHostPromptSignature
    let prompt: String
    let seed: Int
}

enum SampleHostBenchPromptCatalog {
    static var totalCapacity: Int {
        SampleHostPromptTone.allCases.count
            * SampleHostPromptDomain.allCases.count
            * SampleHostPromptStake.allCases.count
            * SampleHostPromptTimeframe.allCases.count
            * SampleHostPromptConfidant.allCases.count
            * SampleHostPromptAskShape.allCases.count
    }

    /// Coprime stride for scatter walk — chapter 一百五十 fix for
    /// defect #2 (chapter 一百四十九). 5041 = 71². gcd(5041, 40320) = 1
    /// because 40320 = 2^7 × 3² × 5 × 7 has no factor 71. Stride
    /// design: 5041 = 5040 + 1 advances tone bucket by 1 each iter,
    /// so iter 0..7 visits all 8 tones (vs linear walk visiting only
    /// 1 tone in first 5040 iter).
    static let scatterStride: Int = 5_041

    /// Scatter walk: same prompt space coverage as `generate(seed:)`
    /// but adjacent iter values produce distant signatures.
    static func generateScattered(iter: Int) -> SampleHostGeneratedPrompt {
        return generateScattered(
            iter: iter, stride: scatterStride)
    }

    /// **M604 chapter 一百七十四 — parameterized stride** (mirrors
    /// chapter 一百七十三 M603 QinaoExtendedPromptCorpus API).
    /// Allows multi-trial fuzz with different coprime strides
    /// to sample different subsets of combinatorial space.
    static func generateScattered(
        iter: Int,
        stride: Int
    ) -> SampleHostGeneratedPrompt {
        let cap = totalCapacity
        let raw = iter * stride
        let seed = ((raw % cap) + cap) % cap
        return generate(seed: seed)
    }

    /// **M604 chapter 一百七十四 — procedural prompt mutation**
    /// (mirrors chapter 一百七十三 M603). 5-variant deterministic
    /// suffix alphabet exercises substrate response to surface-
    /// level variations without changing typed signature.
    static func generateScatteredWithMutation(
        iter: Int,
        stride: Int = scatterStride,
        mutationSeed: Int
    ) -> SampleHostGeneratedPrompt {
        let base = generateScattered(
            iter: iter, stride: stride)
        let suffix = mutationSuffixes[
            ((mutationSeed % mutationSuffixes.count)
                + mutationSuffixes.count)
                % mutationSuffixes.count]
        guard !suffix.isEmpty else { return base }
        return SampleHostGeneratedPrompt(
            signature: base.signature,
            prompt: base.prompt + suffix,
            seed: base.seed)
    }

    /// Mutation alphabet — parity with chapter 一百七十三
    /// QinaoExtendedPromptCorpus.mutationSuffixes.
    static let mutationSuffixes: [String] = [
        "",
        " — but I'm not certain.",
        " I need to decide quickly.",
        " Given my situation last year, please advise.",
        " What would you say if I were a stranger?",
    ]

    static func generate(seed: Int) -> SampleHostGeneratedPrompt {
        let cap = totalCapacity
        let n = ((seed % cap) + cap) % cap
        var rest = n

        let tones = SampleHostPromptTone.allCases
        let domains = SampleHostPromptDomain.allCases
        let stakes = SampleHostPromptStake.allCases
        let timeframes = SampleHostPromptTimeframe.allCases
        let confidants = SampleHostPromptConfidant.allCases
        let asks = SampleHostPromptAskShape.allCases

        let askIdx = rest % asks.count; rest /= asks.count
        let cfIdx = rest % confidants.count; rest /= confidants.count
        let tfIdx = rest % timeframes.count; rest /= timeframes.count
        let stIdx = rest % stakes.count; rest /= stakes.count
        let dmIdx = rest % domains.count; rest /= domains.count
        let tnIdx = rest % tones.count

        let sig = SampleHostPromptSignature(
            tone: tones[tnIdx].rawValue,
            domain: domains[dmIdx].rawValue,
            stake: stakes[stIdx].rawValue,
            timeframe: timeframes[tfIdx].rawValue,
            confidant: confidants[cfIdx].rawValue,
            askShape: asks[askIdx].rawValue)

        let text = render(
            tone: tones[tnIdx],
            domain: domains[dmIdx],
            stake: stakes[stIdx],
            timeframe: timeframes[tfIdx],
            confidant: confidants[cfIdx],
            askShape: asks[askIdx])
        return SampleHostGeneratedPrompt(
            signature: sig, prompt: text, seed: seed)
    }

    private static func render(
        tone: SampleHostPromptTone,
        domain: SampleHostPromptDomain,
        stake: SampleHostPromptStake,
        timeframe: SampleHostPromptTimeframe,
        confidant: SampleHostPromptConfidant,
        askShape: SampleHostPromptAskShape
    ) -> String {
        let toneOpen: String = {
            switch tone {
            case .anxious: return "I'm spiralling and trying to think clearly."
            case .authoritative: return "I've already decided in principle but want pressure-tested."
            case .vulnerable: return "I'm not sure I'm in a place to handle this well."
            case .agentic: return "I need a clear set of trade-offs to choose from."
            case .confused: return "I'm not even sure what I'm actually deciding."
            case .grieving: return "I lost something recently and this decision sits inside that."
            case .curious: return "I'm trying to understand what's actually at stake."
            case .angry: return "I'm furious and don't fully trust my own judgment right now."
            }
        }()
        let stakePhrase: String = {
            switch stake {
            case .low: return "low-stakes"
            case .modest: return "modest-stakes"
            case .high: return "high-stakes"
            case .veryHigh: return "very-high-stakes"
            case .irreversible: return "irreversible"
            case .nonReversibleAfterAct: return "irreversible-once-acted"
            }
        }()
        let domainCtx: String = {
            switch domain {
            case .financial: return "It's a \(stakePhrase) money decision."
            case .medical: return "It's a \(stakePhrase) health/medical situation."
            case .relational: return "It's a \(stakePhrase) interpersonal conflict."
            case .work: return "It's a \(stakePhrase) work or career move."
            case .parenting: return "It's a \(stakePhrase) parenting / family call."
            case .identity: return "It's a \(stakePhrase) question about who I am or what I value."
            case .ethical: return "It's a \(stakePhrase) moral grey area I'm caught in."
            case .existential: return "It's a \(stakePhrase) larger-frame question I can't easily reduce."
            case .trauma: return "It's connected to a \(stakePhrase) past harm I haven't fully named."
            case .creative: return "It's a \(stakePhrase) creative / making decision I'm stuck on."
            }
        }()
        let timeFrame: String = {
            switch timeframe {
            case .minutes: return "I have minutes to decide."
            case .hours: return "I have a few hours."
            case .days: return "I have days to decide."
            case .weeks: return "I have a few weeks to decide."
            case .months: return "I have months but the decision is creeping closer."
            case .lifetime: return "This is a long-arc decision that touches my whole life."
            case .pastUnresolved: return "It's already happened — I'm trying to figure out what to do with it now."
            }
        }()
        let conf: String = {
            switch confidant {
            case .friend: return "I'm asking you the way I'd ask a trusted friend."
            case .expert: return "I'm asking the way I'd consult an expert with credentials."
            case .stranger: return "I'm asking like a stranger in a coffee shop — no context, no judgment."
            case .decisionSystem: return "I'm asking a decision system — give me structure, not opinions."
            }
        }()
        let ask: String = {
            switch askShape {
            case .narrative: return "Talk me through what I'm probably missing."
            case .decisionTree: return "Give me a 3-bullet decision tree to walk through."
            case .singleAction: return "Tell me the single most important next move."
            }
        }()
        return [toneOpen, domainCtx, timeFrame, conf, ask]
            .joined(separator: " ")
    }
}

enum SampleHostBenchHelpers {
    /// Chapter 一百五十 fix for defect #8 (devicectl 20MB cap during
    /// active write): rotate JSONL files at 15MB so each individual
    /// file stays well below 20MB cap. Pulls during active write get
    /// the most recent rotated-out file complete; only the active file
    /// is potentially truncated. After bench finishes, all rotated
    /// files + final file pull cleanly.
    static let rotationByteThreshold: Int64 = 15 * 1024 * 1024

    static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    static func encode(_ row: SampleHostBenchRow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(row)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func documentsDirectory() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask).first!
    }

    static func benchOutputDir() -> URL {
        let dir = documentsDirectory()
            .appendingPathComponent(
                "iphone-bench", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func benchOutputURL(rotationIndex: Int = 0) -> URL {
        let dir = benchOutputDir()
        if rotationIndex == 0 {
            return dir.appendingPathComponent(
                "iterations.jsonl", isDirectory: false)
        } else {
            return dir.appendingPathComponent(
                "iterations.\(rotationIndex).jsonl",
                isDirectory: false)
        }
    }
}

actor SampleHostBenchRunner {
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var currentBytes: Int64 = 0
    private var rotationIndex: Int = 0

    /// Chapter 一百五十 fix for defect #8: when active file exceeds
    /// rotation threshold, close it and start a new file with index
    /// suffix (iterations.jsonl → iterations.1.jsonl → 2.jsonl …).
    /// This ensures Apple's devicectl 20MB cap during active write
    /// affects ONLY the latest file; all rotated-out files pull
    /// cleanly via single-file copy.
    func appendRow(_ row: SampleHostBenchRow) async throws {
        let line = try SampleHostBenchHelpers.encode(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let lineBytes = Int64(data.count)

        // Rotate if active file would exceed threshold AND we've
        // written something already
        if let _ = fileHandle,
           currentBytes + lineBytes
            > SampleHostBenchHelpers.rotationByteThreshold
        {
            try? fileHandle?.synchronize()
            try? fileHandle?.close()
            fileHandle = nil
            rotationIndex += 1
            currentBytes = 0
        }

        if fileHandle == nil {
            let url = SampleHostBenchHelpers.benchOutputURL(
                rotationIndex: rotationIndex)
            currentURL = url
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(
                    atPath: url.path, contents: nil)
            }
            fileHandle = try FileHandle(forWritingTo: url)
            try fileHandle?.seekToEnd()
            // Recompute size in case file already had content
            // (post-relaunch resume path)
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path),
               let n = attrs[.size] as? Int64
            {
                currentBytes = n
            }
        }

        try fileHandle?.write(contentsOf: data)
        currentBytes += lineBytes
    }

    func flush() async {
        try? fileHandle?.synchronize()
    }

    func close() async {
        try? fileHandle?.close()
        fileHandle = nil
    }

    /// Diagnostic accessor for tests + UI
    func currentRotationIndex() async -> Int {
        rotationIndex
    }
}

@MainActor
final class SampleHostModel: ObservableObject {
    @Published private(set) var result: BASHostSessionResult
    @Published private(set) var lastError: String?
    @Published private(set) var benchIsRunning: Bool = false
    @Published private(set) var benchIterationsCompleted: Int = 0
    @Published private(set) var benchAuditCodesTotal: Int = 0
    @Published private(set) var benchStartTime: Date?
    @Published private(set) var benchLastError: String?
    @Published private(set) var benchOutputPath: String = ""
    // M609 chapter 一百七十六 §176.13 — direct AFM test (foreground UI invocation)
    @Published private(set) var afmTestStatus: String = "idle"
    @Published private(set) var afmTestOutput: String = ""
    @Published private(set) var afmTestPrompt: String = "Suggest one calming evening habit in one sentence."
    @Published private(set) var afmTestDurationMs: Double = 0
    @Published private(set) var afmIsRunning: Bool = false

    // M610 chapter 一百七十六 §176.14 — long-running AFM bench
    // (8h default per user request; full flexible config: every numeric
    // value is a `@Published` so all "fixed values" are programmatic).
    @Published var afmBenchDurationHours: Double = 8.0
    @Published var afmBenchStrideRotationCSV: String = "5041,5039,5051,5077,7919"
    @Published var afmBenchRotationPeriodIter: Int = 11_300
    @Published var afmBenchMutationSeedCount: Int = 5
    @Published var afmBenchJSONLRotationMB: Int = 15
    // Default `false` — substrate routes ~50% to .delay + ~50% to
    // .block (chapter 175 empirical), so default skipBlocked=true would
    // skip every iter. User saw "全 skip 了" with default true. New
    // default: always call AFM (toggle on if 8h bench should respect
    // substrate routing for AFM cost-saving).
    @Published var afmBenchSkipBlocked: Bool = false
    @Published var afmBenchAFMTimeoutSec: Int = 30
    @Published private(set) var afmBenchIsRunning: Bool = false
    @Published private(set) var afmBenchIterations: Int = 0
    @Published private(set) var afmBenchAFMSuccessCount: Int = 0
    @Published private(set) var afmBenchAFMSkippedCount: Int = 0
    @Published private(set) var afmBenchAFMErrorCount: Int = 0
    @Published private(set) var afmBenchOutputPath: String = ""
    @Published private(set) var afmBenchStartTime: Date?
    @Published private(set) var afmBenchLastError: String?
    private var afmBenchTask: Task<Void, Never>?

    private var benchTask: Task<Void, Never>?
    private let benchRunner = SampleHostBenchRunner()

    private let runtime: BASHostRuntime
    private static let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
        modeIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
            BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
            BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
        ],
        templateIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: ["samplehost.template.pulse-lens"],
            BASHostWorkflowProfile.comparative.rawValue: ["samplehost.template.contrast-lens"],
            BASHostWorkflowProfile.reflective.rawValue: ["samplehost.template.signal-lens"]
        ],
        memorySourceIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASMemorySource.archive.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.reflection.rawValue
        ],
        interactiveRetrievalModeByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: "compact",
            BASHostWorkflowProfile.comparative.rawValue: "balanced",
            BASHostWorkflowProfile.reflective.rawValue: "full"
        ],
        providerObservationNarrativesByKindID: [
            BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Pulse Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Pulse Lens pass.",
                deterministicFallbackBase: "No provider returned a Pulse Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Pulse Lens pass",
                providerConsistencySource: "provider Pulse Lens pass"
            ),
            BASDecisionMode.comparativeID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Contrast Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Contrast Lens pass.",
                deterministicFallbackBase: "No provider returned a Contrast Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Contrast Lens pass",
                providerConsistencySource: "provider Contrast Lens pass"
            ),
            BASDecisionMode.reflectiveID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Signal Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Signal Lens pass.",
                deterministicFallbackBase: "No provider returned a Signal Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Signal Lens pass",
                providerConsistencySource: "provider Signal Lens pass"
            ),
            BASSemanticTaskKind.selectionID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the candidate selection pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the candidate selection pass.",
                deterministicFallbackBase: "No provider returned a candidate selection result, so SampleHost kept the deterministic ordering.",
                cachedConsistencySource: "cached candidate selection pass",
                providerConsistencySource: "provider candidate selection pass"
            )
        ],
        memorySourceIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: BASMemorySource.cue.rawValue,
            BASHostSessionKind.reopen.rawValue: BASMemorySource.archive.rawValue,
            BASHostSessionKind.notification.rawValue: BASMemorySource.cue.rawValue
        ],
        retrievalModeIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: "guarded",
            BASHostSessionKind.reopen.rawValue: "balanced",
            BASHostSessionKind.handoff.rawValue: "compact",
            BASHostSessionKind.widget.rawValue: "compact",
            BASHostSessionKind.notification.rawValue: "guarded"
        ],
        failureGuardIDsByRiskLevelID: [
            BASHostRiskLevel.high.rawValue: ["samplehost.guard/elevated-risk"]
        ],
        hostNamespace: "samplehost"
    )
    private static let lifecycleBehavior = BASHostLifecycleBehaviorConfiguration(
        bootstrapBehavior: BASAppleLifecycleBootstrapBehavior(
            actionsByPhaseID: [
                BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest)
                ],
                BASAppleLifecycleBootstrapPhase.sceneActive.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace)
                ]
            ],
            activeRefreshDefaultModeID: BASDecisionMode.primary.identifier,
            activeRefreshDefaultRetrievalModeID: "balanced"
        ),
        currentBrainBootstrapBehavior: BASCurrentBrainBootstrapBehavior(
            defaultModeID: BASDecisionMode.primaryID,
            defaultTriggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue,
            defaultRiskLevelID: BASRiskLevel.low.rawValue,
            defaultSourceSurfaceID: BASInteractionSurface.app.rawValue,
            modeIDAliasesByID: [
                "pulse-lens": BASDecisionMode.primaryID,
                "contrast-lens": BASDecisionMode.comparativeID,
                "signal-lens": BASDecisionMode.reflectiveID
            ],
            triggerIDAliasesByID: [
                "alert": BASCurrentBrainBootstrapTrigger.notification.rawValue,
                "resume": BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
            ],
            riskLevelIDAliasesByID: [
                "elevated": BASRiskLevel.high.rawValue,
                "guarded": BASRiskLevel.medium.rawValue
            ],
            sourceSurfaceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
            ],
            enforcedSourceSurfaceByTriggerID: [
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
            ],
            defaultMemorySourceID: BASMemorySource.archive.rawValue,
            memorySourceIDAliasesByID: [
                "archive": BASMemorySource.archive.rawValue,
                "reflection-notes": BASMemorySource.reflection.rawValue,
                "signal-cache": BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.sceneActive.rawValue: BASMemorySource.pattern.rawValue,
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue: BASMemorySource.archive.rawValue,
                BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue: BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByModeID: [
                BASDecisionMode.comparative.identifier: BASMemorySource.archive.rawValue,
                BASDecisionMode.reflective.identifier: BASMemorySource.reflection.rawValue
            ],
            unknownRequestedModeFallbackPolicy: .useConfiguredDefault,
            unknownRequestedTriggerFallbackPolicy: .useConfiguredDefault,
            bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior(
                highRiskSignalGroups: [
                    ["send", "publish", "post", "reply"],
                    ["buy", "upgrade", "subscribe", "checkout"]
                ],
                nightFallbackRiskLevelByModeID: [
                    BASDecisionMode.primary.identifier: BASRiskLevel.medium.rawValue,
                    BASDecisionMode.comparative.identifier: BASRiskLevel.medium.rawValue,
                    BASDecisionMode.reflective.identifier: BASRiskLevel.high.rawValue
                ],
                defaultRiskLevelByModeID: [
                    BASDecisionMode.reflective.identifier: BASRiskLevel.medium.rawValue
                ]
            )
        ),
        predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
            lowRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Hold this in the Pulse Lens a little longer.",
                detail: "SampleHost prefers a short pause before committing this move.",
                preferredModeID: BASDecisionMode.primary.identifier
            ),
            mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Run this through Contrast Lens first.",
                detail: "SampleHost wants one cleaner comparison pass before you act.",
                preferredModeID: BASDecisionMode.comparative.identifier
            ),
            highRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Switch into Signal Lens before you move.",
                detail: "SampleHost sees elevated risk and wants a calmer signal-reading pass first.",
                preferredModeID: BASDecisionMode.reflective.identifier
            ),
            preferredModeIDsByCurrentModeID: [
                BASDecisionMode.reflective.identifier: BASDecisionMode.reflective.identifier
            ],
            mediumRiskNegativeRecentThreshold: 1,
            highRiskNegativeRecentThreshold: 2,
            nightWindowReason: "SampleHost treats this time window as lower-fidelity decision time.",
            negativeRecentReason: "Recent rushed passes under similar conditions ended poorly.",
            failureGuardReasonsByID: [
                "samplehost.guard/elevated-risk": "SampleHost already has a guard up for elevated-risk conditions."
            ],
            defaultReason: "SampleHost prefers a steadier lane here."
        ),
        projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits(
            recordLimit: 48,
            candidateLimit: 20,
            checkEventLimit: 64,
            comparativeRecordLimit: 20,
            reflectiveRecordLimit: 20
        )
    )
    private static let cognitionBehavior = BASHostCognitionBehaviorConfiguration(
        reactionWeightsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASReactionWeights(
                briefLanguage: 0.60,
                warmDirectTone: 0.50,
                lowCognitiveLoad: 0.56,
                interruptiveActionBias: 0.58,
                boundaryNamingBias: 0.32,
                tradeoffClarityBias: 0.40
            ),
            BASHostWorkflowProfile.comparative.rawValue: BASReactionWeights(
                briefLanguage: 0.46,
                warmDirectTone: 0.52,
                lowCognitiveLoad: 0.44,
                interruptiveActionBias: 0.34,
                boundaryNamingBias: 0.48,
                tradeoffClarityBias: 0.72
            ),
            BASHostWorkflowProfile.reflective.rawValue: BASReactionWeights(
                briefLanguage: 0.48,
                warmDirectTone: 0.64,
                lowCognitiveLoad: 0.52,
                interruptiveActionBias: 0.22,
                boundaryNamingBias: 0.68,
                tradeoffClarityBias: 0.40
            )
        ],
        identityProfilesByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASIdentityProfile(
                role: .boundedGuide,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost keeps the lane narrow and practical."
            ),
            BASHostWorkflowProfile.comparative.rawValue: BASIdentityProfile(
                role: .tradeoffGuide,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost compares pressures without deciding for you."
            ),
            BASHostWorkflowProfile.reflective.rawValue: BASIdentityProfile(
                role: .reflectiveWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.66,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost reflects the pattern without taking center stage."
            )
        ],
        substrateBehavior: BASCognitionBehavior(
            sessionBias: BASSessionBiasBehavior(
                defaultBiasesByModeID: [
                    BASDecisionMode.primary.identifier: ["Keep the lane narrow before expanding it."],
                    BASDecisionMode.comparative.identifier: ["Hold the active pressures in view without collapsing them."],
                    BASDecisionMode.reflective.identifier: ["Surface the signal before making it actionable."]
                ],
                briefLanguageSignals: ["brief", "tight", "concise"],
                nightBias: "SampleHost treats late sessions as lower-fidelity decision windows.",
                nightLowLoadBias: "SampleHost lowers cognitive load when energy is thin.",
                lowCognitiveLoadSignals: ["lighter", "shorter guidance", "overloaded"],
                interruptiveActionSignals: ["pause", "hold", "step away"],
                interruptiveActionBias: "SampleHost prefers one regulating move before extra analysis.",
                boundaryNamingSignals: ["limit", "edge", "boundary"],
                boundaryNamingBias: "SampleHost names the limit before it reframes it.",
                tradeoffClaritySignals: ["tradeoff", "constraint", "cost", "benefit"],
                tradeoffClarityBias: "SampleHost keeps the trade-off explicit before polishing language."
            ),
            memoryTrust: BASMemoryTrustBehavior(
                baseScoresBySourceID: [
                    BASMemorySource.cue.rawValue: 0.72,
                    BASMemorySource.pattern.rawValue: 0.78,
                    BASMemorySource.reflection.rawValue: 0.84,
                    BASMemorySource.archive.rawValue: 0.88
                ],
                sourceDecayMultipliersBySourceID: [
                    BASMemorySource.cue.rawValue: 1.08,
                    BASMemorySource.pattern.rawValue: 1.04,
                    BASMemorySource.reflection.rawValue: 0.94,
                    BASMemorySource.archive.rawValue: 1.12
                ]
            )
        )
    )
    private static let sampleHostPresentation = BASHostPresentationConfiguration(
        workflowTitles: BASHostWorkflowTitles(
            primary: "Pulse Lens",
            comparative: "Contrast Lens",
            reflective: "Signal Lens"
        ),
        sessionTitles: BASHostSessionTitles(
            primary: "Pulse Lens",
            comparative: "Contrast Lens",
            reflective: "Signal Lens",
            initialAppearance: "SampleHost Bootstrap",
            sceneActive: "SampleHost Refresh"
        ),
        followUpActions: BASHostFollowUpActions(
            primary: ["Spot the impulse", "Name one next move"],
            comparative: ["Frame the competing pulls", "Choose one bounded comparison"],
            reflective: ["Name the deeper signal", "Choose one grounded reflection"],
            highRiskEscalation: ["Add one more confirmation step"]
        ),
        lifecycle: BASHostLifecyclePresentation(
            initialAppearancePromptFallback: "Load the substrate before the host asks it to speak.",
            sceneActivePromptFallback: "Refresh the current brain and restore the shell."
        ),
        notices: BASHostNoticeTemplates(
            enteredWorkflow: "{surface} entered the {workflow} lane in SampleHost.",
            runtimeProfile: "SampleHost runtime profile {runtimeProfile} is active.",
            reopenFollowUpAction: "Reopen with the {workflow} lane",
            emptyPromptGoalFallback: "Keep the host steady before acting."
        ),
        predictiveIntervention: BASHostPredictiveInterventionPresentation(
            mediumRiskTitle: "Pause for one slower pass.",
            mediumRiskDetail: "SampleHost wants one more comparison step here.",
            highRiskTitle: "Add one more checkpoint.",
            highRiskDetail: "SampleHost sees elevated risk and wants stronger confirmation.",
            reopenRiskDetail: "This reopen path needs a little more structure in SampleHost.",
            fallbackReopenSuggestionDetail: "A prior hold suggests restoring friction first.",
            defaultReason: "SampleHost prefers a slower lane here."
        )
    )
    private static let runtimeTuning: BASEBrainRuntimeSynthesisPolicy = {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(
            "samplehost.runtime-synthesis.v1"
        )
        tuning.wakeIntent.highRiskGuardThreshold = 0.69
        tuning.stateTransitions.quarantineFailureGuardThreshold = 3
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.lease.restrictedEnergyQuota = 0.46
        tuning.maintenance.standardBatteryFloor = 0.36
        tuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        tuning.context.emotionalLoadDriftingIncrement = 0.09
        tuning.triSelf.directPathSuperegoPenalty = 0.46
        tuning.risk.defaultForecastUncertainty = 0.24
        return tuning
    }()

    init(
        runtime: BASHostRuntime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "samplehost.default-runtime",
                policyProfileID: "samplehost.default-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: SampleHostModel.lifecycleBehavior,
                workflowBehavior: SampleHostModel.workflowBehavior,
                cognitionBehavior: SampleHostModel.cognitionBehavior,
                presentation: SampleHostModel.sampleHostPresentation,
                runtimeTuning: SampleHostModel.runtimeTuning,
                runtimePolicyLineage: BASRuntimePolicyLineage(
                    bundleVersion: "samplehost.runtime-policy-bundle.v1",
                    providerRoutingRegistryVersion: "samplehost.provider-routing-registry.v1",
                    providerRoutingPolicyID: "samplehost.provider-routing.v1",
                    runtimeTuningRegistryVersion: "samplehost.runtime-tuning-registry.v1",
                    runtimeTuningPolicyID: "samplehost.runtime-tuning.v1",
                    resolutionSourceID: "sample_host_default"
                ),
                hostRhythmProfile: .generic
            )
        )
    ) {
        var initialError: String?
        self.runtime = runtime
        self.result = Self.perform(
            using: runtime,
            errorSink: { initialError = $0 },
            request: {
                try runtime.bootstrap(
                    BASHostLifecycleRequest(
                        phase: .initialAppearance,
                        sessionKind: .ambient,
                        preferredProfile: .primary,
                        sourceSurface: .application,
                        promptSeed: "Load the substrate before the host asks it to speak.",
                        riskLevel: .low
                    )
                )
            }
        )
        self.lastError = initialError

        // M573 auto-start: chapter 一百四十七 SampleHost build is the
        // bench-enabled variant. Auto-start the bench loop on launch
        // so the iPhone produces real-device data without requiring
        // a button tap. User can still tap "Stop" via the bench panel
        // if they want to halt it.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s grace
            self?.startBench()
        }
    }

    func bootstrap() {
        result = Self.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.bootstrap(
                    BASHostLifecycleRequest(
                        phase: .sceneActive,
                        sessionKind: .ambient,
                        preferredProfile: .primary,
                        sourceSurface: .application,
                        promptSeed: "Refresh the current brain and restore the shell.",
                        riskLevel: .low
                    )
                )
            }
        )
    }

    func start(_ profile: BASHostWorkflowProfile) {
        let prompts: [BASHostWorkflowProfile: String] = [
            .primary: "Should I do this right now?",
            .comparative: "What tradeoff am I refusing to name?",
            .reflective: "What is the honest story here?"
        ]
        result = Self.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: profile,
                        surface: .application,
                        prompt: prompts[profile] ?? "Hold this decision for one more beat.",
                        title: "\(SampleHostModel.sampleHostPresentation.workflowTitles.title(for: profile)) from SampleHost",
                        riskLevel: profile == .reflective ? .medium : .low
                    )
                )
            }
        )
    }

    func reopen() {
        result = Self.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.reopen(
                    BASHostReopenRequest(
                        workflowProfile: .comparative,
                        title: "Reopen this held decision",
                        detail: "SampleHost is proving the reopen path through BASHostKit.",
                        promptSeed: "Take one slower pass before committing.",
                        riskLevel: .high,
                        reopenHint: "Reopen with more structure",
                        templateHint: "Use a cooling template before acting.",
                        interventionHistorySummary: "High-risk reopen requests should restore more friction."
                    )
                )
            }
        )
    }

    // MARK: - M573 (chapter 一百四十七 part 2) — iPhone real-device bench loop

    /// Toggle bench. If running, stops gracefully. If stopped,
    /// kicks off a Task that drives BASHostRuntime.startSession()
    /// in a loop and appends per-iteration JSONL rows to the app's
    /// Documents/iphone-bench/iterations.jsonl file.
    func toggleBench() {
        if benchIsRunning {
            benchTask?.cancel()
        } else {
            startBench()
        }
    }

    private func startBench() {
        benchIsRunning = true
        benchIterationsCompleted = 0
        benchAuditCodesTotal = 0
        benchStartTime = Date()
        benchLastError = nil
        benchOutputPath = SampleHostBenchHelpers
            .benchOutputURL().path

        // M573 (chapter 一百四十七 part 2 b) — keep screen on while
        // bench runs so iOS doesn't suspend the foreground app.
        // User must keep iPhone plugged to power for sustained 8h
        // run; iOS still suspends if user backgrounds the app.
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        // M574 (chapter 一百四十九) — 1-hour bench cap.
        // **M604 chapter 一百七十四**: extended to 2h cap per user
        // "真机 跑2小时冒烟 ... 极大提高benchmark". Doubles
        // combinatorial prompt coverage from chapter 一百四十九's
        // 56,585 iterations / 100% coverage to ~113K iter
        // exercising substrate's 14 observation bundles + 7 typed
        // projection fields + 11 named per-layer coverage codes
        // (chapter 一百七十三 smoke pattern) ~113K times each.
        let maxDurationSeconds: TimeInterval = 7200

        let runtime = self.runtime
        let runner = self.benchRunner

        let benchStartedAt = Date()
        benchTask = Task { @MainActor [weak self] in
            var iter = 0
            while !Task.isCancelled {
                // 8h cap — gracefully halt
                if Date().timeIntervalSince(benchStartedAt)
                    > maxDurationSeconds
                {
                    break
                }
                // M574 (chapter 一百四十九) + chapter 一百五十 fix:
                // combinatorial prompt generator with coprime stride
                // scatter walk (defect #2 fix). Each iter gets a
                // unique prompt across 40,320-slot space, but adjacent
                // iter values produce distant signatures (all 8 tones
                // visited in first 8 iter vs only 1 with linear walk).
                //
                // **M604 chapter 一百七十四**: cycle 5 mutation variants
                // every iter via `mutationSeed = iter % 5`. Each
                // base prompt runs through all 5 surface perturbations
                // (none / hesitation / urgency / context-frame /
                // qualifier) over a 5-iter window. Empirical goal
                // (user "通过冒烟找到最合适程序化生成"): discover
                // which stride×mutation combos surface defects via
                // 2h bench observation. Stride doctrine: stride
                // changes every 11,300 iter (≈ 10min on iPhone 17e
                // 15 iter/sec sustained) cycling through 5 coprime
                // primes [5041, 5039, 5051, 5077, 7919] for full
                // multi-trial coverage of combinatorial subspaces.
                let strideRotation = [5041, 5039, 5051, 5077, 7919]
                let strideIndex = (iter / 11_300)
                    % strideRotation.count
                let chosenStride = strideRotation[strideIndex]
                let mutationSeed = iter % 5
                let g = SampleHostBenchPromptCatalog
                    .generateScatteredWithMutation(
                        iter: iter,
                        stride: chosenStride,
                        mutationSeed: mutationSeed)
                let prompt = g.prompt
                let signature = g.signature
                let t0 = Date()
                var auditCount = 0
                var permitMode = "unknown"
                var bodyLength = 0
                var status = "ok"
                var errorMessage: String?
                do {
                    // Map stake to risk level (combinatorial)
                    let riskLevel: BASHostRiskLevel
                    switch signature.stake {
                    case "low", "modest":
                        riskLevel = .low
                    case "high", "very-high":
                        riskLevel = .medium
                    case "irreversible",
                         "non-reversible-after-act":
                        riskLevel = .high
                    default:
                        riskLevel = .medium
                    }
                    let result = try runtime.startSession(
                        BASHostSessionRequest(
                            kind: .interactive,
                            workflowProfile: .reflective,
                            surface: .application,
                            prompt: prompt,
                            title: "iphone-bench-\(iter)",
                            riskLevel: riskLevel))
                    if let turn = result.eBrainTurn {
                        if let entry = turn.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = turn.actionPermit
                            .mode.rawValue
                        let body = turn.thoughtFold
                            .compactSlots["body"]
                            ?? turn.thoughtFold
                                .compactSlots["summary"]
                            ?? ""
                        bodyLength = body.count
                    }
                } catch {
                    status = "error"
                    errorMessage = "\(error)"
                }
                let dur = Date().timeIntervalSince(t0)
                let row = SampleHostBenchRow(
                    timestamp: SampleHostBenchHelpers
                        .iso8601(Date()),
                    iteration: iter,
                    seed: iter,
                    signature: signature,
                    prompt: prompt,
                    auditCodeCount: auditCount,
                    permitMode: permitMode,
                    bodyLength: bodyLength,
                    durationSeconds: dur,
                    status: status,
                    errorMessage: errorMessage,
                    stride: chosenStride,
                    mutationSeed: mutationSeed)
                do {
                    try await runner.appendRow(row)
                } catch {
                    self?.benchLastError =
                        "write failed: \(error)"
                }
                iter += 1
                self?.benchIterationsCompleted = iter
                self?.benchAuditCodesTotal += auditCount
                // Flush every 50 iterations
                if iter % 50 == 0 {
                    await runner.flush()
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
                await Task.yield()
            }
            await runner.flush()
            await runner.close()
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
            self?.benchIsRunning = false
        }
    }

    // MARK: - shared helpers

    private static func perform(
        using runtime: BASHostRuntime,
        errorSink: (String?) -> Void,
        request: () throws -> BASHostSessionResult
    ) -> BASHostSessionResult {
        do {
            errorSink(nil)
            return try request()
        } catch {
            errorSink(String(describing: error))
            return fallbackResult(using: runtime)
        }
    }

    private static func fallbackResult(using runtime: BASHostRuntime) -> BASHostSessionResult {
        (try? runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Recover the host shell after an integration error.",
                title: "Integration Recovery",
                riskLevel: .low
            )
        )) ?? BASHostSessionResult(
            requestKind: .interactive,
            workflowProfile: .primary,
            currentBrain: BASHostCurrentBrain(
                workflowProfile: .primary,
                workflowTitle: "Primary",
                roleID: "samplehost.recovery",
                identityPosture: .reflective,
                identityInitiative: .guided,
                confidenceCeiling: 0.5,
                relationshipBoundary: "Fallback shell",
                boundaryHeadline: "SampleHost is holding a safe fallback state.",
                boundaryMode: .localOnlyAdvisory,
                boundaryConstraints: [.lockSensitiveMemory],
                calibrationStatus: .stable,
                calibrationAlerts: [],
                riskFlags: [],
                dominantGoals: ["Recover from host integration failure."],
                activeConstraints: ["integration-fallback"],
                retrievalTags: ["fallback"],
                verificationSummary: "samplehost/fallback",
                activeTemplateCount: 0,
                failureGuardCount: 0,
                evolutionPendingReviewCount: 0,
                evolutionRollbackReady: true
            ),
            projection: BASHostProjectionSummary(
                recordCount: 0,
                candidateCount: 0,
                recentEventCount: 0,
                activeTemplateIDs: [],
                failureGuardIDs: []
            ),
            activeSessionTitle: "Integration Recovery",
            notices: ["SampleHost recovered from an integration configuration error."],
            followUpActions: [],
            consoleSnapshot: BASHostConsoleSnapshot(
                overallSummary: "SampleHost recovered from an integration configuration error.",
                reports: []
            )
        )
    }

    // MARK: - M609 chapter 一百七十六 §176.13 — direct AFM foreground test
    //
    // The chapter 174 bench has bodyLength=0 in all 119K rows because
    // BASHostRuntime's L2 organ stage is stubbed (no AFM adapter
    // registered). chapter 176 §176.12 (I20 walkback) confirmed Mac
    // CLI cannot invoke AFM at all due to macOS 26 modelmanagerd
    // foreground-only architectural policy. iPhone is the only
    // realistic path: SampleHost.app foreground UI directly creates
    // a `LanguageModelSession` (FoundationModels framework) and
    // calls `respond(to:)`. This bypasses BAS substrate entirely
    // — pure AFM end-to-end smoke test.

    func runAFMTestNow() {
        guard !afmIsRunning else { return }
        afmIsRunning = true
        afmTestStatus = "starting…"
        afmTestOutput = ""
        afmTestDurationMs = 0
        let prompt = afmTestPrompt
        Task { @MainActor [weak self] in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                do {
                    let session = LanguageModelSession()
                    self?.afmTestStatus = "calling AFM…"
                    let started = Date()
                    let response = try await session.respond(to: prompt)
                    let elapsed = Date().timeIntervalSince(started)
                    self?.afmTestOutput = response.content
                    self?.afmTestDurationMs = elapsed * 1000
                    self?.afmTestStatus =
                        "ok — \(String(format: "%.0f", elapsed * 1000)) ms / \(response.content.count) chars"
                } catch {
                    self?.afmTestOutput = ""
                    self?.afmTestStatus = "error: \(error)"
                }
            } else {
                self?.afmTestStatus =
                    "AFM unavailable — needs iOS 26+ / macOS 26+"
            }
            #else
            self?.afmTestStatus =
                "AFM unavailable — FoundationModels framework not imported"
            #endif
            self?.afmIsRunning = false
        }
    }

    func updateAFMTestPrompt(_ newPrompt: String) {
        afmTestPrompt = newPrompt
    }

    // MARK: - M610 chapter 一百七十六 §176.14 — AFM 8h long-running bench
    //
    // User trigger (2026-05-05): "我想连续跑 afm 8小时" + "进化算法
    // 加强 程序化生成 极致 找到 所有 缺陷 bug 不足" + "我希望 大部分
    // 固定 数值 都可以 改成 完全 flexible 程序化 生成 而不是 死数值".
    //
    // Per-iter flow:
    //   1. Generate scattered+mutation prompt (chapter 173 corpus,
    //      coprime stride proven full-orbit)
    //   2. Run BASHostRuntime.startSession (substrate routing — gets
    //      14-layer audit codes + permit decision)
    //   3. If permit allows AND skipBlocked=true → call AFM directly
    //      via LanguageModelSession.respond(to:) for body
    //   4. Record both substrate decision + AFM body to JSONL
    //
    // All 7 numeric params are @Published flexibles per user "大部分
    // 固定数值 改 flexible 程序化生成":
    //   - duration (1.0..24.0 hours, default 8.0)
    //   - stride rotation (CSV, must be coprime to 40320, default 5)
    //   - rotation period (1000..50_000 iter, default 11_300)
    //   - mutation seed count (1..5, default 5)
    //   - JSONL rotation (1..100 MB, default 15)
    //   - AFM timeout (5..120s, default 30)
    //   - skip blocked (Bool, default true — don't waste AFM calls)
    //
    // Doctrine pin: doctrine-fixed values (sum-to-one weights / coprime
    // stride math / 4-tier orderings) NOT exposed as flexible —
    // they're not magic numbers, they're invariants (chapter 175 E
    // class). Only TRUE magic numbers exposed.

    func startAFMBench() {
        guard !afmBenchIsRunning else { return }
        // Sanitize and parse stride list once
        let strideRotation = afmBenchStrideRotationCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && gcd($0, 40_320) == 1 }
        guard !strideRotation.isEmpty else {
            afmBenchLastError = "stride rotation empty / no coprime entries"
            return
        }
        let durationSec = afmBenchDurationHours * 3600.0
        let rotationPeriod = max(1, afmBenchRotationPeriodIter)
        let mutationCount = max(1, min(5, afmBenchMutationSeedCount))
        let rotationBytes = max(1, afmBenchJSONLRotationMB) * 1024 * 1024
        let afmTimeoutSec = max(5, min(120, afmBenchAFMTimeoutSec))
        let skipBlocked = afmBenchSkipBlocked

        afmBenchIsRunning = true
        afmBenchIterations = 0
        afmBenchAFMSuccessCount = 0
        afmBenchAFMSkippedCount = 0
        afmBenchAFMErrorCount = 0
        afmBenchLastError = nil
        afmBenchStartTime = Date()
        afmBenchOutputPath = SampleHostBenchHelpers
            .afmBenchOutputDirURL().path

        let runtime = self.runtime
        afmBenchTask = Task { @MainActor [weak self] in
            let startedAt = Date()
            var iter = 0
            let runner = SampleHostAFMBenchJSONLRunner(
                rotationBytes: rotationBytes)
            while !Task.isCancelled {
                if Date().timeIntervalSince(startedAt) > durationSec {
                    break
                }
                let strideIndex = (iter / rotationPeriod)
                    % strideRotation.count
                let chosenStride = strideRotation[strideIndex]
                let mutationSeed = iter % mutationCount
                let g = SampleHostBenchPromptCatalog
                    .generateScatteredWithMutation(
                        iter: iter,
                        stride: chosenStride,
                        mutationSeed: mutationSeed)
                let prompt = g.prompt
                let signature = g.signature

                // Substrate routing
                let t0 = Date()
                var auditCount = 0
                var permitMode = "unknown"
                var afmBody: String = ""
                var afmStatus: String = "skipped"
                var afmDurationMs: Double = 0
                var errorMessage: String?
                let riskLevel: BASHostRiskLevel
                switch signature.stake {
                case "low", "modest":         riskLevel = .low
                case "high", "very-high":     riskLevel = .medium
                case "irreversible",
                     "non-reversible-after-act": riskLevel = .high
                default:                      riskLevel = .medium
                }
                do {
                    let result = try runtime.startSession(
                        BASHostSessionRequest(
                            kind: .interactive,
                            workflowProfile: .reflective,
                            surface: .application,
                            prompt: prompt,
                            riskLevel: riskLevel))
                    if let turn = result.eBrainTurn {
                        if let entry = turn.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = turn.actionPermit.mode.rawValue
                    }
                } catch {
                    errorMessage = "substrate: \(error)"
                }

                // AFM body call (skip if permit blocks AND skipBlocked)
                let permitBlocks = permitMode == "block"
                    || permitMode == "delay"
                let shouldCallAFM = !(skipBlocked && permitBlocks)
                if shouldCallAFM {
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, macOS 26.0, *) {
                        let afmStarted = Date()
                        do {
                            let session = LanguageModelSession()
                            let response = try await session
                                .respond(to: prompt)
                            afmBody = response.content
                            afmStatus = "ok"
                            self?.afmBenchAFMSuccessCount += 1
                        } catch {
                            afmStatus = "afm-error"
                            errorMessage = (errorMessage ?? "")
                                + " afm: \(error)"
                            self?.afmBenchAFMErrorCount += 1
                        }
                        afmDurationMs = Date()
                            .timeIntervalSince(afmStarted) * 1000
                    } else {
                        afmStatus = "afm-unavailable-os"
                        self?.afmBenchAFMSkippedCount += 1
                    }
                    #else
                    afmStatus = "afm-unavailable-framework"
                    self?.afmBenchAFMSkippedCount += 1
                    #endif
                } else {
                    self?.afmBenchAFMSkippedCount += 1
                }

                let dur = Date().timeIntervalSince(t0)
                let row = SampleHostAFMBenchRow(
                    timestamp: SampleHostBenchHelpers.iso8601(Date()),
                    iteration: iter,
                    seed: iter,
                    stride: chosenStride,
                    mutationSeed: mutationSeed,
                    signature: signature,
                    prompt: prompt,
                    auditCodeCount: auditCount,
                    permitMode: permitMode,
                    afmStatus: afmStatus,
                    afmBody: afmBody,
                    afmBodyLength: afmBody.count,
                    afmDurationMs: afmDurationMs,
                    totalDurationSeconds: dur,
                    errorMessage: errorMessage)
                do {
                    try await runner.appendRow(row)
                } catch {
                    self?.afmBenchLastError = "jsonl: \(error)"
                }
                iter += 1
                self?.afmBenchIterations = iter
                // Cooperative cancel; yield to UI for status updates
                if iter % 8 == 0 { await Task.yield() }
            }
            await runner.close()
            self?.afmBenchIsRunning = false
        }
    }

    func stopAFMBench() {
        afmBenchTask?.cancel()
        afmBenchTask = nil
        afmBenchIsRunning = false
    }

    func updateAFMBenchDurationHours(_ newValue: Double) {
        afmBenchDurationHours = max(0.1, min(24.0, newValue))
    }

    func updateAFMBenchStrideCSV(_ newValue: String) {
        afmBenchStrideRotationCSV = newValue
    }

    func updateAFMBenchRotationPeriod(_ newValue: Int) {
        afmBenchRotationPeriodIter = max(1_000, min(100_000, newValue))
    }

    func updateAFMBenchMutationCount(_ newValue: Int) {
        afmBenchMutationSeedCount = max(1, min(5, newValue))
    }

    func updateAFMBenchSkipBlocked(_ newValue: Bool) {
        afmBenchSkipBlocked = newValue
    }
}

// MARK: - M610 chapter 一百七十六 §176.14 — AFM bench row + JSONL runner

struct SampleHostAFMBenchRow: Codable, Sendable, Equatable {
    let timestamp: String
    let iteration: Int
    let seed: Int
    let stride: Int
    let mutationSeed: Int
    let signature: SampleHostPromptSignature
    let prompt: String
    let auditCodeCount: Int
    let permitMode: String
    let afmStatus: String  // ok / skipped / afm-error / afm-unavailable-*
    let afmBody: String
    let afmBodyLength: Int
    let afmDurationMs: Double
    let totalDurationSeconds: Double
    let errorMessage: String?
}

extension SampleHostBenchHelpers {
    static func afmBenchOutputDirURL() -> URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-afm-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func encodeAFM(_ row: SampleHostAFMBenchRow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(row)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

actor SampleHostAFMBenchJSONLRunner {
    private let rotationBytes: Int
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var rotationIndex: Int = 0

    init(rotationBytes: Int) {
        self.rotationBytes = rotationBytes
    }

    func appendRow(_ row: SampleHostAFMBenchRow) async throws {
        let line = try SampleHostBenchHelpers.encodeAFM(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let needNew: Bool
        if let h = fileHandle, let url = currentURL {
            let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? Int) ?? 0
            needNew = size + data.count > rotationBytes
            _ = h
        } else {
            needNew = true
        }
        if needNew {
            await close()
            rotationIndex += 1
            let dir = SampleHostBenchHelpers.afmBenchOutputDirURL()
            let url = dir.appendingPathComponent(
                "afm-iterations.\(rotationIndex).jsonl")
            FileManager.default.createFile(
                atPath: url.path, contents: nil)
            currentURL = url
            fileHandle = try FileHandle(forWritingTo: url)
        }
        try fileHandle?.write(contentsOf: data)
    }

    func close() async {
        try? fileHandle?.close()
        fileHandle = nil
        currentURL = nil
    }
}

// Pure gcd helper (no external dep)
private func gcd(_ a: Int, _ b: Int) -> Int {
    var (x, y) = (abs(a), abs(b))
    while y != 0 { (x, y) = (y, x % y) }
    return x
}
