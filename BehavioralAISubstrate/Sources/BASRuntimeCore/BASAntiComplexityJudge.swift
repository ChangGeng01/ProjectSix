// MARK: - BASAntiComplexityJudge — chapter 四百一 / M938
//
// Phase C step 3 of the LLM Extraction Engine MVP per user
// vision §12 ("榨干反方能力"): typed substrate-side judge
// that detects scope-creep / over-complexity signals in
// host's proposed actions BEFORE the LLM commits to them。
//
// User vision §12 pin:
//
// > 你不能只让 LLM 帮你变强,还要让它阻止你走偏。
// > Anti-Complexity Judge 反复杂度审判官:
// > 每当你说 最先进 / 最强大 / 最终局 / 还可以加什么
// > 系统应该自动问:这项技术是否解决当前 MVP 的核心瓶颈?
// > 不用它会死吗?有没有更简单替代?
//
// > 你真正的风险不是想法不够强,而是系统越想越宏大,
// > MVP 越来越远。
//
// ## What this ships
//
// Pure-function judge that scans proposed text for typed
// scope-creep signals (Chinese + English variants) and emits
// a typed risk assessment:
//
//   - Detects trigger phrases ("最先进" / "最强大" / "最终局"
//     / "还可以加什么" / "state-of-the-art" / "world-class"
//     / "every feature" / etc.)
//   - Counts the matches per signal type
//   - Returns a typed risk level (clean / warning / critical)
//     based on signal density
//   - Surfaces specific flagged signals so the host can
//     inject them as `riskFlags` into the M932 engine's
//     extraction byproducts
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — judge is observation
// - 红线 7 hint-only — assessment is HINT;host decides
// - chapter 二百一一 single-source-of-truth — ONE typed
//   judge,signals catalog extensible via additional
//   typed entries (not host strings)
// - chapter 一百八十五 anti-magic-number — thresholds
//   named typed constants
// - ADR-014 OPT-IN — judge is queried only when caller
//   invokes;substrate doesn't auto-judge

import Foundation

// MARK: - Signal kind

/// Typed enum naming canonical scope-creep signal categories
/// the judge detects。Raw values pinned for wire stability +
/// grep。
public enum BASScopeCreepSignal:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// "最先进" / "state-of-the-art" / "cutting-edge"
    case bleedingEdgeAdmiration = "bleedingEdgeAdmiration"
    /// "最强大" / "most powerful" / "best-in-class"
    case maximalPowerSeeking = "maximalPowerSeeking"
    /// "最终局" / "final-form" / "end-game"
    case finalFormFantasy = "finalFormFantasy"
    /// "还可以加什么" / "what else can we add" /
    /// "every feature"
    case featureAddictionLoop = "featureAddictionLoop"
    /// "全套" / "complete suite" / "all-in-one"
    case completionismDrive = "completionismDrive"
    /// "终极" / "ultimate" / "pinnacle"
    case ultimateFraming = "ultimateFraming"
}

// MARK: - Risk level

public enum BASScopeCreepRiskLevel:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// 0 signals detected
    case clean = "clean"
    /// 1-2 signals — surface but don't block
    case warning = "warning"
    /// 3+ signals OR multiple strong-signal categories —
    /// downstream gate should escalate
    case critical = "critical"
}

// MARK: - Assessment

public struct BASScopeCreepAssessment:
    Codable, Equatable, Sendable
{
    public let riskLevel: BASScopeCreepRiskLevel
    /// Per-signal hit counts。Only signals with ≥1 hit are
    /// included。
    public let signalHits: [BASScopeCreepSignal: Int]
    /// Total signal-hit count (sum of `signalHits.values`)。
    public let totalHitCount: Int
    /// Specific source phrases the judge matched on,for
    /// host UI / log surfaces。Limited to the first 8 to
    /// avoid bloat。
    public let flaggedPhrases: [String]
    /// Suggested mitigation hint (chapter 二百一一 single-
    /// source-of-truth — ONE canonical question per signal)。
    public let mitigationHint: String

    public init(
        riskLevel: BASScopeCreepRiskLevel,
        signalHits: [BASScopeCreepSignal: Int],
        totalHitCount: Int,
        flaggedPhrases: [String],
        mitigationHint: String
    ) {
        self.riskLevel = riskLevel
        self.signalHits = signalHits
        self.totalHitCount = totalHitCount
        self.flaggedPhrases = flaggedPhrases
        self.mitigationHint = mitigationHint
    }
}

// MARK: - Judge namespace

public enum BASAntiComplexityJudge {

    /// chapter 一百八十五 anti-magic-number — typed
    /// thresholds
    public static let warningThreshold: Int = 1
    public static let criticalThreshold: Int = 3
    public static let maxFlaggedPhrases: Int = 8

    /// User vision §12 canonical mitigation question hosts
    /// should surface to the user when the judge flags
    /// scope creep。Pinned as one source-of-truth string
    /// (chapter 二百一一)。
    public static let canonicalMitigationHint: String =
        "Does this technology solve the current MVP " +
        "bottleneck? Will it die without it? Is there a " +
        "simpler alternative? Can it wait until phase 2?"

    /// Pinned phrase catalog per signal category。Hosts
    /// can fork the file to add language-specific phrases。
    public static let signalPhrases:
        [BASScopeCreepSignal: [String]] =
    [
        .bleedingEdgeAdmiration: [
            "最先进", "最前沿", "前沿技术",
            "state-of-the-art", "cutting-edge",
            "bleeding-edge", "next-generation",
            "next generation"
        ],
        .maximalPowerSeeking: [
            "最强大", "最强", "最厉害",
            "most powerful", "best-in-class",
            "world-class", "world class"
        ],
        .finalFormFantasy: [
            "最终局", "最终形态", "终极形态",
            "final-form", "final form",
            "end-game", "end game"
        ],
        .featureAddictionLoop: [
            "还可以加", "还能加什么", "再加什么",
            "what else can we add",
            "add another feature",
            "add more features",
            "every feature"
        ],
        .completionismDrive: [
            "全套", "整套", "一整套",
            "complete suite", "all-in-one",
            "all in one", "full stack"
        ],
        .ultimateFraming: [
            "终极", "极致",
            "ultimate", "pinnacle"
        ]
    ]

    /// Pure function:scan `text` for scope-creep signals,
    /// return typed assessment。Case-insensitive matching for
    /// English phrases;exact matching for Chinese (no case
    /// concept)。
    public static func assess(
        text: String
    ) -> BASScopeCreepAssessment {
        // M940 audit fix:iterate `BASScopeCreepSignal
        // .allCases` (CaseIterable order is the declaration
        // order — DETERMINISTIC) instead of the
        // `signalPhrases` Dictionary (Swift Dictionary
        // iteration is NON-DETERMINISTIC across executions
        // due to hash randomization)。Pre-M940 the same
        // input could produce different `flaggedPhrases`
        // arrays across builds when `maxFlaggedPhrases (8)`
        // capped the output mid-iteration。Post-M940 the
        // output is byte-stable across runs (M892 replay
        // determinism doctrine)。
        let lowercased = text.lowercased()
        var signalHits: [BASScopeCreepSignal: Int] = [:]
        var flaggedPhrases: [String] = []
        for signal in BASScopeCreepSignal.allCases {
            let phrases = signalPhrases[signal] ?? []
            var hitCount = 0
            for phrase in phrases {
                let count = lowercased.components(
                    separatedBy: phrase.lowercased())
                    .count - 1
                if count > 0 {
                    hitCount += count
                    if flaggedPhrases.count
                        < maxFlaggedPhrases
                    {
                        flaggedPhrases.append(phrase)
                    }
                }
            }
            if hitCount > 0 {
                signalHits[signal] = hitCount
            }
        }
        let totalHits = signalHits.values.reduce(0, +)
        let level: BASScopeCreepRiskLevel
        if totalHits >= criticalThreshold
            || signalHits.count >= 2
        {
            level = .critical
        } else if totalHits >= warningThreshold {
            level = .warning
        } else {
            level = .clean
        }
        return BASScopeCreepAssessment(
            riskLevel: level,
            signalHits: signalHits,
            totalHitCount: totalHits,
            flaggedPhrases: flaggedPhrases,
            mitigationHint: canonicalMitigationHint)
    }

    /// Convenience:produce a typed list of `riskFlags`
    /// strings suitable for `BASLLMTaskPackage.riskFlags`
    /// or `BASLLMExtractionByproducts.riskFlags`。Flags
    /// are namespaced `"anti-complexity:<signal>"` so
    /// downstream consumers can grep。
    public static func riskFlags(
        for assessment: BASScopeCreepAssessment
    ) -> [String] {
        if assessment.riskLevel == .clean {
            return []
        }
        return assessment.signalHits.keys
            .sorted { $0.rawValue < $1.rawValue }
            .map { "anti-complexity:\($0.rawValue)" }
    }
}
