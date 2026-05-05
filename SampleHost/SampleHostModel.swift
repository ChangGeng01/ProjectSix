import Foundation
import BASHostKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(BASMLXAdapter)
import BASMLXAdapter
import BASOrgan
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

    // M619 chapter 一百七十七 §177 — Hybrid AFM + Gemma bench with
    // CoreML-driven router (ChengluPreflight v0 single head).
    @Published var hybridBenchDurationHours: Double = 8.0
    @Published var hybridBenchStrideRotationCSV: String = "5041,5039,5051,5077,7919"
    @Published var hybridBenchRotationPeriodIter: Int = 11_300
    @Published var hybridBenchMutationSeedCount: Int = 5
    @Published var hybridBenchJSONLRotationMB: Int = 15
    @Published private(set) var hybridBenchIsRunning: Bool = false
    @Published private(set) var hybridBenchIterations: Int = 0
    @Published private(set) var hybridBenchAFMOk: Int = 0
    @Published private(set) var hybridBenchGemmaOk: Int = 0
    @Published private(set) var hybridBenchAFMFallbackToGemmaOk: Int = 0
    @Published private(set) var hybridBenchGemmaFallbackToAFMOk: Int = 0
    @Published private(set) var hybridBenchBothFailed: Int = 0
    @Published private(set) var hybridBenchRouterHits: Int = 0
    @Published private(set) var hybridBenchRouterMisses: Int = 0
    // M628 chapter 一百七十八 — dispatch policy live counters.
    // Tracks how often substrate's permit mode causes LLM skip /
    // both-call / local-only / draft-only path. UI surfaces these
    // so user sees substrate-LLM coupling in real time.
    @Published private(set) var hybridBenchSubstrateSkipBlock: Int = 0
    @Published private(set) var hybridBenchSubstrateSkipReplace: Int = 0
    @Published private(set) var hybridBenchSubstrateSkipDelay: Int = 0
    @Published private(set) var hybridBenchSubstrateBothLLMs: Int = 0
    @Published private(set) var hybridBenchSubstrateLocalOnly: Int = 0
    @Published private(set) var hybridBenchSubstrateDraftOnly: Int = 0
    // M630 chapter 一百七十八 — closed-loop tracking. How often
    // post-LLM substrate observation shifts permit mode (i.e.
    // LLM produced something that would have been blocked).
    @Published private(set) var hybridBenchPostLLMShifted: Int = 0
    // M635 chapter 一百七十九 — 2nd CoreML head agreement counter.
    // How often ChengluPermitPredict's class matches substrate's
    // actual .block decision. High agreement = model is a faithful
    // policy cache; disagreement = doctrine drift signal.
    @Published private(set) var hybridBenchPermitPredictHits: Int = 0
    @Published private(set) var hybridBenchPermitPredictMisses: Int = 0
    // M642 chapter 一百八十 — running mean absolute error of
    // Length + Latency regression heads vs actual LLM outputs.
    // Updated per-iter when LLM body returns; nil samples skipped.
    // These ARE expected to be non-zero (regression heads are
    // not 100% accurate; chapter 176 train MAE was ~479 chars
    // and ~2091 ms) — bench just records empirical residuals.
    @Published private(set) var hybridBenchLengthMAESum: Double = 0
    @Published private(set) var hybridBenchLengthMAECount: Int = 0
    @Published private(set) var hybridBenchLatencyMAESumMs: Double = 0
    @Published private(set) var hybridBenchLatencyMAECount: Int = 0
    @Published private(set) var hybridBenchOutputPath: String = ""
    @Published private(set) var hybridBenchStartTime: Date?
    @Published private(set) var hybridBenchLastError: String?
    @Published private(set) var hybridGemmaLoadStatus: String = "idle"
    @Published private(set) var hybridSinglePromptStatus: String = "idle"
    @Published private(set) var hybridSinglePromptOutput: String = ""
    @Published private(set) var hybridSinglePromptRoute: String = ""
    @Published private(set) var hybridSinglePromptProb: Double = 0
    private var hybridBenchTask: Task<Void, Never>?
    // M627 chapter 177 deep-review fix #3 — Stop→Start race.
    // Each start bumps generation + captures myGen. Old task at
    // exit only writes hybridBenchIsRunning=false if its myGen
    // still matches; otherwise a newer start has already run and
    // we must not clobber its true. Also defends against the old
    // task's final JSONL write racing the new task's runner.
    private var hybridBenchGeneration: Int = 0

    #if canImport(BASMLXAdapter)
    private var gemmaAdapter: MLXOrganAdapter?
    // M627 chapter 177 deep-review fix #2 — gate concurrent loads
    // via in-flight Task. Two callGemma invocations during await
    // suspension would both start loading the 4-bit model + LoRA
    // (~3.4 GB, hundreds of MB resident wasted). Now they share.
    private var gemmaLoadInFlight: Task<MLXOrganAdapter, Error>?
    // M627 deep-review fix #4 — track LoRA load success separately
    // from adapter init so a failed LoRA load doesn't poison the
    // session: status tells the truth + future calls can retry.
    private var gemmaLoraLoaded: Bool = false
    #endif

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

// MARK: - M619 chapter 一百七十七 §177 — Hybrid bench row + runner

struct SampleHostHybridBenchRow: Codable, Sendable, Equatable {
    let timestamp: String
    let iteration: Int
    let seed: Int
    let stride: Int
    let mutationSeed: Int
    let signature: SampleHostPromptSignature
    let prompt: String
    // Substrate routing
    let auditCodeCount: Int
    let permitMode: String
    // Router prediction
    let routerVersion: String  // "v0-rule-based-binary-LR"
    let routerPredictedRoute: String  // "afm" or "gemma"
    let routerProbability: Double  // afm_success_probability
    // Actual LLM execution
    let firstTriedLLM: String  // "afm" or "gemma"
    let firstTriedStatus: String  // "ok" / "afm-error" / "gemma-error"
    let firstTriedBody: String
    let firstTriedDurationMs: Double
    let fallbackTriedLLM: String?  // nil if first try succeeded
    let fallbackStatus: String?
    let fallbackBody: String?
    let fallbackDurationMs: Double?
    // Final outcome
    let actualRoute: String
    // "afm-predicted-ok" / "gemma-predicted-ok" /
    // "afm-fallback-to-gemma-ok" / "gemma-fallback-to-afm-ok" /
    // "both-failed" / "skipped-by-substrate-{block,delay,replace}"
    let routerHit: Bool
    let totalDurationSeconds: Double
    let errorMessage: String?
    // M628 chapter 一百七十八 — substrate→LLM dispatch coupling.
    // Records HOW substrate's permit mode shaped LLM dispatch.
    // - dispatchPolicy: the typed policy derived from permitMode
    //   (e.g. "skip-block" / "single-llm" / "both-llms" / etc.)
    // - dispatchTaken: actual execution path observed
    // - draftOnly: true if substrate marked output as draft-only
    // - llmSkipped: true if substrate prevented LLM call entirely
    let dispatchPolicy: String?
    let dispatchTaken: String?
    let draftOnly: Bool?
    let llmSkipped: Bool?
    // M630 chapter 一百七十八 — closed-loop observation.
    // After LLM responds, substrate observes the response.
    // If post-LLM permit mode differs from pre-LLM, we know the
    // generated body shifted substrate's verdict (e.g. content
    // would have been blocked if substrate saw it).
    let postLLMPermitMode: String?
    let postLLMAuditCodeCount: Int?
    let postLLMShifted: Bool?  // pre-LLM mode != post-LLM mode
    // M633-M635 chapter 一百七十九 — 2nd CoreML head:
    // ChengluPermitPredict predicts substrate's permit class from
    // signature features. Runs alongside substrate (red line:
    // never replaces). Records prediction-vs-actual agreement.
    // - permitPredictBlockProb: model output probability ∈ [0,1]
    // - permitPredictClass: "block" / "non-block" / nil if model
    //   unavailable
    // - permitPredictAgreement: nil if model unavailable;
    //   else true if predicted class matches substrate's actual
    //   permit-mode being .block (predicted=block && actual=block)
    //   or both non-block.
    let permitPredictBlockProb: Double?
    let permitPredictClass: String?
    let permitPredictAgreement: Bool?
    // M638-M641 chapter 一百八十 — 3rd + 4th CoreML heads:
    // ChengluLengthHead (regression on AFM body chars) +
    // ChengluLatencyHead (regression on AFM duration ms). Both
    // run before LLM call as UI pre-warm hints. Recorded for
    // empirical accuracy analysis: actualLength - predictedLength
    // is the residual error per row.
    // - lengthPredicted: predicted afmBodyLength chars (nil if
    //   model unavailable)
    // - lengthError: actual - predicted (nil if model or LLM
    //   unavailable)
    // - latencyPredictedMs: predicted afmDurationMs (nil if model
    //   unavailable)
    // - latencyErrorMs: actual - predicted (nil if model or LLM
    //   unavailable)
    let lengthPredicted: Double?
    let lengthError: Double?
    let latencyPredictedMs: Double?
    let latencyErrorMs: Double?
}

/// M628 chapter 一百七十八 — typed policy mapping
/// `BASActionPermitMode` → real LLM dispatch behavior.
///
/// 9 permit modes × 3 axes (skip / single / dual) condense into
/// 6 typed policies. Doctrine pin: substrate decides FIRST, then
/// LLM dispatch follows substrate's permit, not the other way
/// around (不变量 #1 先醒再答; #2 神经不掌权).
enum SampleHostHybridDispatchPolicy: String, Sendable {
    /// `.block` / `.replace` — substrate refuses or substitutes.
    /// LLM call is SKIPPED entirely. Returns canned safe text.
    case skipBlock = "skip-block"
    case skipReplace = "skip-replace"
    /// `.delay` — substrate stalls. LLM call is SKIPPED. Returns
    /// canned "let me think about this" stall response.
    case skipDelay = "skip-delay"
    /// `.answer` / `.mirror` — normal path: route via router,
    /// fall back if first LLM errors. v0.2 uncertain-zone logic
    /// still applies (calls both LLMs in [0.30, 0.70] zone).
    case singleLLM = "single-llm"
    /// `.compare` / `.escalate` — call BOTH AFM + Gemma always
    /// regardless of router prediction (substrate explicitly
    /// requested side-by-side / second-check).
    case bothLLMs = "both-llms"
    /// `.localOnly` — only call Gemma (local), never AFM.
    /// substrate flagged this turn as no-cloud-allowed.
    case localOnly = "local-only"
    /// `.draftOnly` — call LLM but tag output as draft-only.
    /// User UI should not commit this output without explicit
    /// confirmation.
    case draftOnly = "draft-only"

    /// Derive the dispatch policy from the substrate permit mode.
    /// Default falls back to `.singleLLM` for unknown / error.
    static func from(permitMode: String) -> Self {
        switch permitMode {
        case "block":
            return .skipBlock
        case "replace":
            return .skipReplace
        case "delay":
            return .skipDelay
        case "compare", "escalate":
            return .bothLLMs
        case "local_only", "localOnly":
            return .localOnly
        case "draft_only", "draftOnly":
            return .draftOnly
        case "answer", "mirror":
            return .singleLLM
        default:
            // unknown / "substrate-error" / future modes
            return .singleLLM
        }
    }

    /// Whether this policy skips the LLM call entirely.
    var skipsLLM: Bool {
        self == .skipBlock || self == .skipReplace || self == .skipDelay
    }

    /// Canned response string when LLM is skipped. Doctrine pin:
    /// these strings are typed (not free-form), so JSONL grep on
    /// "skip-*" captures every substrate-driven skip.
    var cannedResponse: String? {
        switch self {
        case .skipBlock:
            return SampleHostHybridDispatchCanned.block
        case .skipReplace:
            return SampleHostHybridDispatchCanned.replace
        case .skipDelay:
            return SampleHostHybridDispatchCanned.delay
        default:
            return nil
        }
    }
}

/// M628 chapter 一百七十八 — typed canned responses for skipped
/// LLM dispatches. Per anti-magic-number doctrine (chapter 一百
/// 三十) these are named constants, not inline literals scattered
/// across call sites.
enum SampleHostHybridDispatchCanned {
    static let block = "I can't help with that request."
    static let replace = "Let me suggest a different approach: I'd want to understand more before answering."
    static let delay = "Let me think about this carefully before responding."
}

extension SampleHostBenchHelpers {
    static func hybridBenchOutputDirURL() -> URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("iphone-hybrid-bench")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func encodeHybrid(_ row: SampleHostHybridBenchRow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(row)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

actor SampleHostHybridBenchJSONLRunner {
    private let rotationBytes: Int
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var rotationIndex: Int = 0
    // M627 chapter 177 deep-review fix #9 — track running byte
    // count in-actor instead of querying FileManager.attributesOf.
    // attributesOf may not reflect just-written bytes (FS / OS
    // buffering), causing rotation to miss its window. Running
    // tally is exact + cheap. Pre-existing files (resume case)
    // seed currentBytes from disk on first open.
    private var currentBytes: Int = 0

    init(rotationBytes: Int) {
        self.rotationBytes = rotationBytes
    }

    func appendRow(_ row: SampleHostHybridBenchRow) async throws {
        let line = try SampleHostBenchHelpers.encodeHybrid(row) + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let needNew: Bool
        if fileHandle != nil, currentURL != nil {
            needNew = currentBytes + data.count > rotationBytes
        } else {
            needNew = true
        }
        if needNew {
            await close()
            rotationIndex += 1
            let dir = SampleHostBenchHelpers.hybridBenchOutputDirURL()
            let url = dir.appendingPathComponent(
                "hybrid-iterations.\(rotationIndex).jsonl")
            FileManager.default.createFile(
                atPath: url.path, contents: nil)
            currentURL = url
            fileHandle = try FileHandle(forWritingTo: url)
            // Fresh file → 0 bytes. (For resume: seek-to-end +
            // offset would be the path; we always create a new
            // numbered shard so this is exact.)
            currentBytes = 0
        }
        try fileHandle?.write(contentsOf: data)
        currentBytes += data.count
    }

    func close() async {
        try? fileHandle?.close()
        fileHandle = nil
        currentURL = nil
        currentBytes = 0
    }
}

// MARK: - M619 chapter 一百七十七 §177 — Hybrid bench methods on SampleHostModel

extension SampleHostModel {
    /// Single-prompt hybrid test (UI panel). Predicts route via
    /// CoreML, calls chosen LLM, falls back to other on error.
    ///
    /// **M627 deep-review note #12** — by design this single-prompt
    /// path does NOT take the v0.2 confidence-aware uncertain-zone
    /// dual-LLM branch (chosen→fallback only). Rationale: the UI
    /// panel is a "tap once + see it work" smoke probe. Always
    /// calling both LLMs would double the latency that the user
    /// is staring at, for marginal benefit on a single sample.
    /// Bench path (`startHybridBench`) still uses dual-LLM voting
    /// in the uncertain zone for the real signal collection.
    /// Hardcoded features (agentic / creative / modest / …) are
    /// also intentional: it's a smoke test, not signature-driven
    /// inference. Bench rows derive features from the actual
    /// generated prompt's signature.
    func runHybridSinglePrompt() {
        let prompt = afmTestPrompt
        let features = ChengluPromptFeatures(
            tone: "agentic",
            domain: "creative",
            stake: "modest",
            timeframe: "minutes",
            confidant: "decision-system",
            askShape: "single-action",
            mutationSeed: 0)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hybridSinglePromptStatus = "predicting…"
            let decision = ChengluPreflightInference.shared
                .predictOrNil(features: features)
            guard let d = decision else {
                self.hybridSinglePromptStatus = "router unavailable"
                return
            }
            self.hybridSinglePromptProb = d.afmSuccessProbability
            self.hybridSinglePromptRoute = d.route.rawValue
            self.hybridSinglePromptStatus =
                "router: \(d.route.rawValue) (prob \(String(format: "%.3f", d.afmSuccessProbability))) calling…"
            // Try chosen LLM
            do {
                if d.route == .afm {
                    let body = try await self.callAFM(prompt: prompt)
                    self.hybridSinglePromptOutput = body
                    self.hybridSinglePromptStatus =
                        "ok afm (predicted) \(body.count) chars"
                } else {
                    let body = try await self.callGemma(prompt: prompt)
                    self.hybridSinglePromptOutput = body
                    self.hybridSinglePromptStatus =
                        "ok gemma (predicted) \(body.count) chars"
                }
            } catch {
                // Fallback to the other LLM
                self.hybridSinglePromptStatus =
                    "first try failed (\(d.route.rawValue)), trying fallback…"
                do {
                    let body: String
                    if d.route == .afm {
                        body = try await self.callGemma(prompt: prompt)
                        self.hybridSinglePromptStatus =
                            "ok gemma fallback \(body.count) chars (router miss)"
                    } else {
                        body = try await self.callAFM(prompt: prompt)
                        self.hybridSinglePromptStatus =
                            "ok afm fallback \(body.count) chars (router miss)"
                    }
                    self.hybridSinglePromptOutput = body
                } catch {
                    self.hybridSinglePromptStatus =
                        "both failed: \(error)"
                    self.hybridSinglePromptOutput = ""
                }
            }
        }
    }

    /// Call AFM with a prompt. Throws on error/guardrail.
    private func callAFM(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw NSError(domain: "AFMUnavailable", code: -1)
    }

    /// Call Gemma 4 E2B (MLX) with a prompt. Lazy-loads on first
    /// call + applies LoRA M247 chat-template adapter (chapter 176
    /// §176.10 — 3.6× better convergence + learned [RISK]/[NEEDS_PERMIT]
    /// markers). Throws on error.
    ///
    /// M627 deep-review fix #2 + #4: load is gated through a single
    /// in-flight Task so concurrent callers share, and LoRA load
    /// status is tracked separately from adapter readiness so a
    /// failed LoRA doesn't poison subsequent retries.
    private func callGemma(prompt: String) async throws -> String {
        #if canImport(BASMLXAdapter)
        let adapter = try await ensureGemmaAdapter()
        let request = BASOrganRequest(
            requestID: "hybrid-prompt",
            role: .scout,
            preset: .scout,
            instruction: prompt)
        let draft = try await adapter.draft(request)
        return draft.body
        #else
        throw NSError(
            domain: "GemmaUnavailable",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "BASMLXAdapter not built"])
        #endif
    }

    #if canImport(BASMLXAdapter)
    /// Singleton-load gate — concurrent callers share one in-flight
    /// Task instead of racing on `if gemmaAdapter == nil` (review #2).
    private func ensureGemmaAdapter() async throws -> MLXOrganAdapter {
        if let existing = gemmaAdapter { return existing }
        if let inFlight = gemmaLoadInFlight {
            return try await inFlight.value
        }
        let task = Task { [weak self] () throws -> MLXOrganAdapter in
            // Off-actor work — we don't capture self's actor here.
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.gemma4_E2B_4bit)
            try await adapter.loadModel()
            await MainActor.run { [weak self] in
                self?.hybridGemmaLoadStatus = "model loaded, loading LoRA M247…"
            }
            // v0.3 — load LoRA M247 adapter from app bundle
            var loraOK = false
            if let loraURL = Bundle.main.url(
                forResource: "qinao_curriculum_lora_m247",
                withExtension: "safetensors")
            {
                do {
                    try await adapter.loadAdapter(from: loraURL)
                    loraOK = true
                } catch {
                    // Non-fatal — bare Gemma still works (review #4)
                    await MainActor.run { [weak self] in
                        self?.hybridGemmaLoadStatus =
                            "lora-load-failed: \(error)"
                    }
                }
            }
            try await adapter.prewarm()
            await MainActor.run { [weak self] in
                self?.gemmaLoraLoaded = loraOK
                self?.hybridGemmaLoadStatus = loraOK
                    ? "ready (with LoRA M247)"
                    : "ready (bare Gemma, NO LoRA)"
            }
            return adapter
        }
        gemmaLoadInFlight = task
        hybridGemmaLoadStatus = "loading model…"
        do {
            let adapter = try await task.value
            gemmaAdapter = adapter
            gemmaLoadInFlight = nil
            return adapter
        } catch {
            gemmaLoadInFlight = nil  // Allow retry next call
            throw error
        }
    }
    #endif

    /// Update prompt text for single-prompt hybrid test.
    /// (Reuses afmTestPrompt setter.)

    /// Start long-running hybrid bench (8h default).
    func startHybridBench() {
        guard !hybridBenchIsRunning else { return }
        let strideRotation = hybridBenchStrideRotationCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && gcd($0, 40_320) == 1 }
        guard !strideRotation.isEmpty else {
            hybridBenchLastError = "stride CSV empty / no coprime entries"
            return
        }
        let durationSec = hybridBenchDurationHours * 3600.0
        let rotationPeriod = max(1, hybridBenchRotationPeriodIter)
        let mutationCount = max(1, min(5, hybridBenchMutationSeedCount))
        let rotationBytes = max(1, hybridBenchJSONLRotationMB) * 1024 * 1024

        // M627 deep-review fix #3 — defensively cancel any
        // previous task before starting (Stop→Start race guard).
        // The previous task may still be in its loop (finishing
        // an iter); cancellation propagates so it bails out.
        hybridBenchTask?.cancel()
        hybridBenchGeneration += 1
        let myGen = hybridBenchGeneration

        hybridBenchIsRunning = true
        hybridBenchIterations = 0
        hybridBenchAFMOk = 0
        hybridBenchGemmaOk = 0
        hybridBenchAFMFallbackToGemmaOk = 0
        hybridBenchGemmaFallbackToAFMOk = 0
        hybridBenchBothFailed = 0
        hybridBenchRouterHits = 0
        hybridBenchRouterMisses = 0
        // M628/M630 chapter 一百七十八 reset
        hybridBenchSubstrateSkipBlock = 0
        hybridBenchSubstrateSkipReplace = 0
        hybridBenchSubstrateSkipDelay = 0
        hybridBenchSubstrateBothLLMs = 0
        hybridBenchSubstrateLocalOnly = 0
        hybridBenchSubstrateDraftOnly = 0
        hybridBenchPostLLMShifted = 0
        // M635 chapter 一百七十九 reset
        hybridBenchPermitPredictHits = 0
        hybridBenchPermitPredictMisses = 0
        // M642 chapter 一百八十 reset
        hybridBenchLengthMAESum = 0
        hybridBenchLengthMAECount = 0
        hybridBenchLatencyMAESumMs = 0
        hybridBenchLatencyMAECount = 0
        hybridBenchLastError = nil
        hybridBenchStartTime = Date()
        hybridBenchOutputPath = SampleHostBenchHelpers
            .hybridBenchOutputDirURL().path

        let runtime = self.runtime
        hybridBenchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startedAt = Date()
            var iter = 0
            let runner = SampleHostHybridBenchJSONLRunner(
                rotationBytes: rotationBytes)
            while !Task.isCancelled {
                if Date().timeIntervalSince(startedAt) > durationSec {
                    break
                }
                let strideIndex = (iter / rotationPeriod) % strideRotation.count
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
                let riskLevel: BASHostRiskLevel
                switch signature.stake {
                case "low", "modest": riskLevel = .low
                case "high", "very-high": riskLevel = .medium
                case "irreversible", "non-reversible-after-act":
                    riskLevel = .high
                default: riskLevel = .medium
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
                    permitMode = "substrate-error"
                }

                // Router predict
                let features = ChengluPromptFeatures(
                    tone: signature.tone,
                    domain: signature.domain,
                    stake: signature.stake,
                    timeframe: signature.timeframe,
                    confidant: signature.confidant,
                    askShape: signature.askShape,
                    mutationSeed: mutationSeed)
                let decision = ChengluPreflightInference.shared
                    .predictOrNil(features: features)
                let routerRoute = decision?.route ?? .afm
                let routerProb = decision?.afmSuccessProbability ?? 0.5
                let routerVersion = decision?.modelVersion ?? "missing"
                // v0.2 — confidence-aware: in uncertain zone, call
                // BOTH LLMs and pick longer body. Outside uncertain
                // zone, use chosen LLM with fallback safety net.
                let routerConfidence = decision?.confidence ?? .high

                // M628 chapter 一百七十八 — derive substrate
                // dispatch policy BEFORE calling LLM. Substrate's
                // permit mode shapes WHETHER + HOW we call LLM.
                let dispatchPolicy =
                    SampleHostHybridDispatchPolicy.from(
                        permitMode: permitMode)

                // M649 chapter 一百八十一 — try MultiHead FIRST
                // (1 inference call, 4 outputs). Fall back to
                // separate per-head models if MultiHead missing.
                let multiHead = ChengluMultiHeadInference
                    .shared.predictOrNil(features: features)

                // M635 chapter 一百七十九 — 2nd CoreML head.
                // Permit predict: prefer MultiHead's block_prob;
                // fall back to standalone PermitPredict head if
                // MultiHead unavailable.
                let permitPredictBlockProb: Double?
                let permitPredictClass: String?
                if let mh = multiHead {
                    permitPredictBlockProb = mh.blockProbability
                    permitPredictClass = mh.blockProbability >= 0.5
                        ? "block" : "non-block"
                } else {
                    let permitDecision = ChengluPermitPredictInference
                        .shared.predictOrNil(features: features)
                    permitPredictBlockProb =
                        permitDecision?.blockProbability
                    permitPredictClass =
                        permitDecision?.predictedClass.rawValue
                }
                // Agreement: predicted class matches substrate's
                // actual .block decision. nil if model unavailable.
                let permitPredictAgreement: Bool? = {
                    guard let cls = permitPredictClass
                    else { return nil }
                    let actualIsBlock = (permitMode == "block")
                    let predictedIsBlock = (cls == "block")
                    return actualIsBlock == predictedIsBlock
                }()
                if let agree = permitPredictAgreement {
                    if agree {
                        self.hybridBenchPermitPredictHits += 1
                    } else {
                        self.hybridBenchPermitPredictMisses += 1
                    }
                }

                // M638-M641 chapter 一百八十 — 3rd + 4th CoreML
                // heads. M649 chapter 一百八十一 — prefer
                // MultiHead, fall back to separate heads.
                let lengthPredicted: Double?
                let latencyPredictedMs: Double?
                if let mh = multiHead {
                    lengthPredicted = mh.predictedBodyLength
                    latencyPredictedMs = mh.predictedDurationMs
                } else {
                    let lengthDecision = ChengluRegressionHeadInference
                        .lengthHead.predictOrNil(features: features)
                    let latencyDecision = ChengluRegressionHeadInference
                        .latencyHead.predictOrNil(features: features)
                    lengthPredicted = lengthDecision?.predicted
                    latencyPredictedMs = latencyDecision?.predicted
                }

                // Call chosen LLM
                var firstTriedLLM = routerRoute.rawValue
                var firstStatus = "ok"
                var firstBody = ""
                var firstDurationMs: Double = 0
                var fallbackLLM: String?
                var fallbackStatus: String?
                var fallbackBody: String?
                var fallbackDurationMs: Double?
                var actualRoute = ""
                var routerHit = true
                var errorMessage: String?
                var dispatchTaken: String = dispatchPolicy.rawValue
                var llmSkipped: Bool = false
                var draftOnlyFlag: Bool = false

                let firstStart = Date()

                // M628 — substrate-skip path: when permit is
                // .block / .replace / .delay, do NOT call LLM.
                // Return canned response. This is THE 真实 path
                // for "substrate decides we shouldn't ask LLM".
                if dispatchPolicy.skipsLLM {
                    let canned = dispatchPolicy.cannedResponse ?? ""
                    firstTriedLLM = "none-substrate-skip"
                    firstBody = canned
                    firstStatus = "ok-substrate-skip"
                    firstDurationMs =
                        Date().timeIntervalSince(firstStart) * 1000
                    actualRoute = "skipped-by-substrate-\(dispatchPolicy.rawValue.dropFirst("skip-".count))"
                    llmSkipped = true
                    dispatchTaken = dispatchPolicy.rawValue
                    // Skip-path counts as router-hit by definition:
                    // substrate decided no LLM, router prediction
                    // is irrelevant. We still increment the
                    // respective LLM counter at 0 for clarity.
                    self.hybridBenchRouterHits += 1
                    switch dispatchPolicy {
                    case .skipBlock:
                        self.hybridBenchSubstrateSkipBlock += 1
                    case .skipReplace:
                        self.hybridBenchSubstrateSkipReplace += 1
                    case .skipDelay:
                        self.hybridBenchSubstrateSkipDelay += 1
                    default: break
                    }
                } else if dispatchPolicy == .bothLLMs {
                    // M628 — substrate explicitly wants both LLMs
                    // (compare / escalate). Force dual-call
                    // regardless of router prediction.
                    var afmBodyMaybe: String?
                    var gemmaBodyMaybe: String?
                    var afmErr: Error?
                    var gemmaErr: Error?
                    let afmStart = Date()
                    do {
                        afmBodyMaybe = try await self.callAFM(prompt: prompt)
                    } catch { afmErr = error }
                    let afmMs = Date().timeIntervalSince(afmStart) * 1000
                    let gemmaStart = Date()
                    do {
                        gemmaBodyMaybe = try await self.callGemma(prompt: prompt)
                    } catch { gemmaErr = error }
                    let gemmaMs = Date().timeIntervalSince(gemmaStart) * 1000

                    firstTriedLLM = "afm"
                    firstBody = afmBodyMaybe ?? ""
                    firstStatus = afmErr == nil ? "ok" : "afm-error"
                    firstDurationMs = afmMs
                    if let g = gemmaBodyMaybe {
                        fallbackLLM = "gemma"
                        fallbackBody = g
                        fallbackStatus = gemmaErr == nil ? "ok-substrate-both" : "gemma-error"
                    }
                    fallbackDurationMs = gemmaMs
                    let bothFailed =
                        afmBodyMaybe == nil && gemmaBodyMaybe == nil
                    actualRoute = bothFailed
                        ? "substrate-both-failed"
                        : "substrate-both-\(dispatchPolicy.rawValue)"
                    if bothFailed {
                        self.hybridBenchBothFailed += 1
                        self.hybridBenchRouterMisses += 1
                        routerHit = false
                    } else {
                        if afmBodyMaybe != nil {
                            self.hybridBenchAFMOk += 1
                        }
                        if gemmaBodyMaybe != nil {
                            self.hybridBenchGemmaOk += 1
                        }
                        self.hybridBenchRouterHits += 1
                    }
                    if afmErr != nil { errorMessage = "afm: \(afmErr!)" }
                    if gemmaErr != nil {
                        errorMessage = (errorMessage ?? "") + " gemma: \(gemmaErr!)"
                    }
                    self.hybridBenchSubstrateBothLLMs += 1
                } else if dispatchPolicy == .localOnly {
                    // M628 — substrate flagged no-cloud. Force
                    // Gemma path, never AFM. Treat as router-hit
                    // if Gemma succeeds.
                    do {
                        firstBody = try await self.callGemma(prompt: prompt)
                        firstTriedLLM = "gemma"
                        firstStatus = "ok-substrate-local-only"
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        actualRoute = "local-only-gemma-ok"
                        self.hybridBenchGemmaOk += 1
                        self.hybridBenchRouterHits += 1
                    } catch {
                        firstTriedLLM = "gemma"
                        firstStatus = "gemma-error"
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        errorMessage = "gemma local-only: \(error)"
                        actualRoute = "local-only-gemma-failed"
                        self.hybridBenchBothFailed += 1
                        self.hybridBenchRouterMisses += 1
                        routerHit = false
                    }
                    self.hybridBenchSubstrateLocalOnly += 1
                } else {
                    // M628 — `.singleLLM` or `.draftOnly` falls
                    // through to original router-driven logic.
                    // For `.draftOnly` we additionally tag the
                    // row so downstream UI can flag the output
                    // as not-yet-committed.
                    if dispatchPolicy == .draftOnly {
                        draftOnlyFlag = true
                        self.hybridBenchSubstrateDraftOnly += 1
                    }
                    if routerConfidence == .uncertain {
                    // v0.2 — uncertain zone: call BOTH LLMs, pick
                    // longer body (simple heuristic, will swap to
                    // ShadowEvaluator-based picker in chapter 一百八十).
                    var afmBodyMaybe: String?
                    var gemmaBodyMaybe: String?
                    var afmErr: Error?
                    var gemmaErr: Error?
                    let afmStart = Date()
                    do {
                        afmBodyMaybe = try await self.callAFM(prompt: prompt)
                    } catch { afmErr = error }
                    let afmMs = Date().timeIntervalSince(afmStart) * 1000
                    let gemmaStart = Date()
                    do {
                        gemmaBodyMaybe = try await self.callGemma(prompt: prompt)
                    } catch { gemmaErr = error }
                    let gemmaMs = Date().timeIntervalSince(gemmaStart) * 1000

                    // Pick longer non-empty body (simple heuristic)
                    let pickedAFM: Bool
                    if let a = afmBodyMaybe, let g = gemmaBodyMaybe {
                        pickedAFM = a.count >= g.count
                    } else if afmBodyMaybe != nil {
                        pickedAFM = true
                    } else if gemmaBodyMaybe != nil {
                        pickedAFM = false
                    } else {
                        pickedAFM = true  // both failed
                    }
                    if pickedAFM {
                        firstTriedLLM = "afm"
                        firstBody = afmBodyMaybe ?? ""
                        firstStatus = afmErr == nil ? "ok" : "afm-error"
                        firstDurationMs = afmMs
                        if let other = gemmaBodyMaybe {
                            fallbackLLM = "gemma"
                            fallbackBody = other
                            fallbackStatus = "ok-uncertain-side"
                        }
                        fallbackDurationMs = gemmaMs
                        actualRoute = "uncertain-both-pick-afm"
                    } else {
                        firstTriedLLM = "gemma"
                        firstBody = gemmaBodyMaybe ?? ""
                        firstStatus = gemmaErr == nil ? "ok" : "gemma-error"
                        firstDurationMs = gemmaMs
                        if let other = afmBodyMaybe {
                            fallbackLLM = "afm"
                            fallbackBody = other
                            fallbackStatus = "ok-uncertain-side"
                        }
                        fallbackDurationMs = afmMs
                        actualRoute = "uncertain-both-pick-gemma"
                    }
                    let bothFailed =
                        afmBodyMaybe == nil && gemmaBodyMaybe == nil
                    if afmBodyMaybe != nil && gemmaBodyMaybe == nil {
                        self.hybridBenchAFMOk += 1
                    } else if gemmaBodyMaybe != nil && afmBodyMaybe == nil {
                        self.hybridBenchGemmaOk += 1
                    } else if bothFailed {
                        self.hybridBenchBothFailed += 1
                        // M627 review #6: actualRoute lied as
                        // "uncertain-both-pick-afm" when both bodies
                        // are empty. Correct semantic:
                        actualRoute = "uncertain-both-failed"
                    } else {
                        // Both succeeded (best case)
                        if pickedAFM {
                            self.hybridBenchAFMOk += 1
                        } else {
                            self.hybridBenchGemmaOk += 1
                        }
                    }
                    if afmErr != nil { errorMessage = "afm: \(afmErr!)" }
                    if gemmaErr != nil {
                        errorMessage = (errorMessage ?? "") + " gemma: \(gemmaErr!)"
                    }
                    // M627 review #5: only count router-hit when
                    // at least one body returned. Both-failed
                    // increments routerMisses instead.
                    if bothFailed {
                        self.hybridBenchRouterMisses += 1
                        routerHit = false
                    } else {
                        self.hybridBenchRouterHits += 1
                    }
                } else {
                    // Confident — original single-LLM-with-fallback path
                    do {
                        if routerRoute == .afm {
                            firstBody = try await self.callAFM(prompt: prompt)
                        } else {
                            firstBody = try await self.callGemma(prompt: prompt)
                        }
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        actualRoute = "\(routerRoute.rawValue)-predicted-ok"
                        if routerRoute == .afm {
                            self.hybridBenchAFMOk += 1
                        } else {
                            self.hybridBenchGemmaOk += 1
                        }
                        self.hybridBenchRouterHits += 1
                    } catch {
                        firstStatus = "\(routerRoute.rawValue)-error"
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        errorMessage = "first: \(error)"
                        routerHit = false
                        self.hybridBenchRouterMisses += 1
                        let fbStart = Date()
                        do {
                            let other: String
                            if routerRoute == .afm {
                                other = try await self.callGemma(prompt: prompt)
                                fallbackLLM = "gemma"
                                fallbackStatus = "ok"
                                fallbackBody = other
                                actualRoute = "afm-fallback-to-gemma-ok"
                                self.hybridBenchAFMFallbackToGemmaOk += 1
                            } else {
                                other = try await self.callAFM(prompt: prompt)
                                fallbackLLM = "afm"
                                fallbackStatus = "ok"
                                fallbackBody = other
                                actualRoute = "gemma-fallback-to-afm-ok"
                                self.hybridBenchGemmaFallbackToAFMOk += 1
                            }
                            fallbackDurationMs =
                                Date().timeIntervalSince(fbStart) * 1000
                        } catch {
                            fallbackLLM = routerRoute == .afm ? "gemma" : "afm"
                            fallbackStatus = "error"
                            errorMessage = (errorMessage ?? "") + " fb: \(error)"
                            actualRoute = "both-failed"
                            self.hybridBenchBothFailed += 1
                            fallbackDurationMs =
                                Date().timeIntervalSince(fbStart) * 1000
                        }
                    }
                }
                }
                // M628 — close of outer else for .singleLLM/.draftOnly

                // M630 chapter 一百七十八 — CLOSED LOOP post-LLM
                // observation. After LLM responds (or skip-canned),
                // run substrate observation pass on the response
                // body. If substrate's permit shifts (e.g. body
                // would have been blocked), we know LLM crossed a
                // line invisible to pre-call substrate.
                //
                // Doctrine pin: substrate is THE arbiter — even
                // its own LLM's body is subject to substrate
                // re-audit. This is "shadow evaluator lite":
                // ShadowEvaluator full ML model lives in chapter
                // 一百八十+; this one is single substrate-pass.
                //
                // Cost: doubles substrate calls per iter. Trade:
                // empirical visibility into "did the LLM say
                // something substrate wouldn't have permitted".
                var postLLMPermitMode: String? = nil
                var postLLMAuditCount: Int? = nil
                var postLLMShifted: Bool? = nil
                if !firstBody.isEmpty && !llmSkipped {
                    let observeText =
                        "Original: \(prompt)\n\nResponse: \(firstBody)"
                    if let observed = try? runtime.startSession(
                        BASHostSessionRequest(
                            kind: .interactive,
                            workflowProfile: .reflective,
                            surface: .application,
                            prompt: observeText,
                            riskLevel: riskLevel)).eBrainTurn
                    {
                        postLLMPermitMode = observed.actionPermit
                            .mode.rawValue
                        postLLMAuditCount = observed
                            .sovereignAuditEntry?.signalRefs.count ?? 0
                        postLLMShifted =
                            postLLMPermitMode != permitMode
                        if postLLMShifted == true {
                            self.hybridBenchPostLLMShifted += 1
                        }
                    }
                }

                let dur = Date().timeIntervalSince(t0)

                // M642 chapter 一百八十 — compute regression
                // residuals against actual LLM outputs (firstBody
                // length + firstDurationMs). Skipped iters
                // (llmSkipped == true) have no real LLM output to
                // compare against — skip residual computation.
                var lengthError: Double? = nil
                var latencyErrorMs: Double? = nil
                if !llmSkipped, !firstBody.isEmpty {
                    if let pred = lengthPredicted {
                        let actual = Double(firstBody.count)
                        let err = actual - pred
                        lengthError = err
                        self.hybridBenchLengthMAESum += abs(err)
                        self.hybridBenchLengthMAECount += 1
                    }
                    if let pred = latencyPredictedMs {
                        let err = firstDurationMs - pred
                        latencyErrorMs = err
                        self.hybridBenchLatencyMAESumMs += abs(err)
                        self.hybridBenchLatencyMAECount += 1
                    }
                }

                let row = SampleHostHybridBenchRow(
                    timestamp: SampleHostBenchHelpers.iso8601(Date()),
                    iteration: iter,
                    seed: iter,
                    stride: chosenStride,
                    mutationSeed: mutationSeed,
                    signature: signature,
                    prompt: prompt,
                    auditCodeCount: auditCount,
                    permitMode: permitMode,
                    routerVersion: routerVersion,
                    routerPredictedRoute: routerRoute.rawValue,
                    routerProbability: routerProb,
                    firstTriedLLM: firstTriedLLM,
                    firstTriedStatus: firstStatus,
                    firstTriedBody: firstBody,
                    firstTriedDurationMs: firstDurationMs,
                    fallbackTriedLLM: fallbackLLM,
                    fallbackStatus: fallbackStatus,
                    fallbackBody: fallbackBody,
                    fallbackDurationMs: fallbackDurationMs,
                    actualRoute: actualRoute,
                    routerHit: routerHit,
                    totalDurationSeconds: dur,
                    errorMessage: errorMessage,
                    dispatchPolicy: dispatchPolicy.rawValue,
                    dispatchTaken: dispatchTaken,
                    draftOnly: draftOnlyFlag,
                    llmSkipped: llmSkipped,
                    postLLMPermitMode: postLLMPermitMode,
                    postLLMAuditCodeCount: postLLMAuditCount,
                    postLLMShifted: postLLMShifted,
                    permitPredictBlockProb: permitPredictBlockProb,
                    permitPredictClass: permitPredictClass,
                    permitPredictAgreement: permitPredictAgreement,
                    lengthPredicted: lengthPredicted,
                    lengthError: lengthError,
                    latencyPredictedMs: latencyPredictedMs,
                    latencyErrorMs: latencyErrorMs)
                do {
                    try await runner.appendRow(row)
                } catch {
                    self.hybridBenchLastError = "jsonl: \(error)"
                }
                iter += 1
                // M627 deep-review fix #3 — only update iter
                // counter if we're still the active generation.
                // Stale tasks (cancelled by newer start) must not
                // clobber the new bench's published counters.
                if self.hybridBenchGeneration == myGen {
                    self.hybridBenchIterations = iter
                }
                if iter % 8 == 0 { await Task.yield() }
            }
            await runner.close()
            // M627 deep-review fix #3 — only flip isRunning if
            // we're still the active generation. If a newer start
            // already bumped generation + set isRunning=true, our
            // exit must not flip it back to false.
            if self.hybridBenchGeneration == myGen {
                self.hybridBenchIsRunning = false
            }
        }
    }

    func stopHybridBench() {
        // M627 deep-review fix #3 — keep the task ref so we don't
        // lose the cancellation handle. Setting isRunning=false
        // here lets UI react immediately; the task itself will
        // see Task.isCancelled, exit its loop, close the JSONL
        // runner, and (via generation check) skip the final
        // isRunning=false write so a fast restart isn't clobbered.
        hybridBenchTask?.cancel()
        hybridBenchTask = nil
        hybridBenchIsRunning = false
    }

    func updateHybridBenchDurationHours(_ newValue: Double) {
        hybridBenchDurationHours = max(0.1, min(24.0, newValue))
    }

    func updateHybridBenchStrideCSV(_ newValue: String) {
        hybridBenchStrideRotationCSV = newValue
    }

    func updateHybridBenchRotationPeriod(_ newValue: Int) {
        hybridBenchRotationPeriodIter = max(1_000, min(100_000, newValue))
    }

    func updateHybridBenchMutationCount(_ newValue: Int) {
        hybridBenchMutationSeedCount = max(1, min(5, newValue))
    }
}
