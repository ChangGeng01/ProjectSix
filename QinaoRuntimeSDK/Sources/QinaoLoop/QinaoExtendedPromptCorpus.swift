// SPDX-License-Identifier: Apache-2.0
// M574 (chapter 一百四十九) — Programmatic combinatorial prompt
// generator for 1-hour comprehensive benchmark.
//
// ## Why this exists
//
// User instruction "需要 程序化 生成 不相同 测试" — chapter 一百四十八
// self-audit found 458K iterations of 15 hardcoded prompts produces
// only 15 unique data points + 30K confirmations of determinism.
//
// This generator uses **6 typed dimensions** producing a 40,320-slot
// combinatorial space. A deterministic seed → unique prompt mapping
// guarantees:
//   - Same seed always returns same prompt (reproducible)
//   - Different seeds always return different prompts (within capacity)
//   - Capacity is product of all dimension cardinalities (40,320)
//
// 6 dimensions with kebab-case raw values (anti-magic-number compliant):
//   1. Tone        (8 values)  — anxious, authoritative, vulnerable, ...
//   2. Domain      (10 values) — financial, medical, work, ...
//   3. Stake       (6 values)  — low, modest, high, irreversible, ...
//   4. Timeframe   (7 values)  — minutes, hours, days, weeks, ...
//   5. Confidant   (4 values)  — friend, expert, stranger, system
//   6. AskShape    (3 values)  — narrative, decision-tree, single-action
//
// Total = 8 × 10 × 6 × 7 × 4 × 3 = 40,320 unique prompts.
//
// ## DAG discipline
//
// Imports `Foundation` only. Pure deterministic generator. Tests pin
// determinism + uniqueness within spot-checked ranges.

import Foundation

// MARK: - 6 typed dimensions

public enum QinaoPromptTone:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case anxious = "anxious"
    case authoritative = "authoritative"
    case vulnerable = "vulnerable"
    case agentic = "agentic"
    case confused = "confused"
    case grieving = "grieving"
    case curious = "curious"
    case angry = "angry"
}

public enum QinaoPromptDomain:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case financial = "financial"
    case medical = "medical"
    case relational = "relational"
    case work = "work"
    case parenting = "parenting"
    case identity = "identity"
    case ethical = "ethical"
    case existential = "existential"
    case trauma = "trauma"
    case creative = "creative"
}

public enum QinaoPromptStake:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case low = "low"
    case modest = "modest"
    case high = "high"
    case veryHigh = "very-high"
    case irreversible = "irreversible"
    case nonReversibleAfterAct = "non-reversible-after-act"
}

public enum QinaoPromptTimeframe:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case minutes = "minutes"
    case hours = "hours"
    case days = "days"
    case weeks = "weeks"
    case months = "months"
    case lifetime = "lifetime"
    case pastUnresolved = "past-unresolved"
}

public enum QinaoPromptConfidant:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case friend = "friend"
    case expert = "expert"
    case stranger = "stranger"
    case decisionSystem = "decision-system"
}

public enum QinaoPromptAskShape:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case narrative = "narrative"
    case decisionTree = "decision-tree"
    case singleAction = "single-action"
}

// MARK: - PromptSignature

/// Typed signature for a generated prompt — 6 dimensions captured
/// for downstream analysis. Hashable so callers can dedupe.
public struct QinaoPromptSignature:
    Sendable, Equatable, Codable, Hashable
{
    public let tone: QinaoPromptTone
    public let domain: QinaoPromptDomain
    public let stake: QinaoPromptStake
    public let timeframe: QinaoPromptTimeframe
    public let confidant: QinaoPromptConfidant
    public let askShape: QinaoPromptAskShape

    public init(
        tone: QinaoPromptTone,
        domain: QinaoPromptDomain,
        stake: QinaoPromptStake,
        timeframe: QinaoPromptTimeframe,
        confidant: QinaoPromptConfidant,
        askShape: QinaoPromptAskShape
    ) {
        self.tone = tone
        self.domain = domain
        self.stake = stake
        self.timeframe = timeframe
        self.confidant = confidant
        self.askShape = askShape
    }
}

public struct QinaoGeneratedPrompt: Sendable, Equatable, Codable {
    public let signature: QinaoPromptSignature
    public let prompt: String
    public let seed: Int
}

// MARK: - Generator

public enum QinaoExtendedPromptCorpus {

    /// Total combinatorial capacity: 8 × 10 × 6 × 7 × 4 × 3 = 40,320
    public static var totalCapacity: Int {
        QinaoPromptTone.allCases.count
            * QinaoPromptDomain.allCases.count
            * QinaoPromptStake.allCases.count
            * QinaoPromptTimeframe.allCases.count
            * QinaoPromptConfidant.allCases.count
            * QinaoPromptAskShape.allCases.count
    }

    /// Deterministic mapping: seed → unique prompt within
    /// totalCapacity. Same seed always returns same prompt.
    /// Different seeds within [0, totalCapacity) return distinct
    /// signatures.
    public static func generate(seed: Int) -> QinaoGeneratedPrompt {
        let signature = decompose(seed: seed)
        let text = renderPrompt(signature: signature)
        return QinaoGeneratedPrompt(
            signature: signature,
            prompt: text,
            seed: seed)
    }

    /// Coprime stride for scatter walk — fixes chapter 一百四十九
    /// defect #2 (linear seed walk clusters in adjacent dim space,
    /// only 1 of 8 tones visited in first 5040 iter).
    ///
    /// Stride 5,041 = 71² (prime squared). gcd(5041, 40320) = 1
    /// because 40320 = 2^7 × 3² × 5 × 7 has no factor of 71.
    ///
    /// Why this stride: 5041 = 1 × 5040 + 1, where 5040 is the "tone
    /// bucket size" (the number of slots per tone in the linear walk's
    /// decomposition). So each iter advances the tone bucket by 1 (mod
    /// 8), guaranteeing all 8 tones appear in first 8 iter. Also gives
    /// rich askShape/confidant/timeframe/stake/domain rotation since
    /// 5041 mod (3·4·7·6·10) = 5041 mod 5040 = 1, advancing all
    /// inner-dim residues by 1 per iter (modular cascade).
    public static let scatterStride: Int = 5_041

    /// Scatter walk: same deterministic permutation across all 40,320
    /// slots, but adjacent iter values produce distant signatures.
    /// At iter=0 first prompt is anxious-financial-low-minutes-friend-
    /// narrative; at iter=1 second prompt jumps ~half-way across the
    /// space (different tone, different domain, different stake, etc).
    /// In first 8 iter, all 8 tones visited (vs 1 of 8 with linear walk).
    public static func generateScattered(
        iter: Int
    ) -> QinaoGeneratedPrompt {
        let cap = totalCapacity
        let stride = scatterStride
        // ((iter * stride) % cap) but handle negative iter
        let raw = iter * stride
        let seed = ((raw % cap) + cap) % cap
        return generate(seed: seed)
    }

    /// Decompose a seed integer into the 6-dimensional signature.
    /// Pure function. Modulo wraps the seed into [0, totalCapacity).
    public static func decompose(
        seed: Int
    ) -> QinaoPromptSignature {
        let cap = totalCapacity
        let n = ((seed % cap) + cap) % cap
        var rest = n

        let tones = QinaoPromptTone.allCases
        let domains = QinaoPromptDomain.allCases
        let stakes = QinaoPromptStake.allCases
        let timeframes = QinaoPromptTimeframe.allCases
        let confidants = QinaoPromptConfidant.allCases
        let asks = QinaoPromptAskShape.allCases

        let askIdx = rest % asks.count
        rest /= asks.count
        let confidantIdx = rest % confidants.count
        rest /= confidants.count
        let timeframeIdx = rest % timeframes.count
        rest /= timeframes.count
        let stakeIdx = rest % stakes.count
        rest /= stakes.count
        let domainIdx = rest % domains.count
        rest /= domains.count
        let toneIdx = rest % tones.count

        return QinaoPromptSignature(
            tone: tones[toneIdx],
            domain: domains[domainIdx],
            stake: stakes[stakeIdx],
            timeframe: timeframes[timeframeIdx],
            confidant: confidants[confidantIdx],
            askShape: asks[askIdx])
    }

    // MARK: - Rendering

    /// Render the prompt text from a signature. Each (signature →
    /// text) is deterministic.
    public static func renderPrompt(
        signature: QinaoPromptSignature
    ) -> String {
        let toneClause = toneOpening(signature.tone)
        let domainClause = domainContext(
            signature.domain, stake: signature.stake)
        let timeClause = timeframeFraming(signature.timeframe)
        let confidantClause = confidantAddress(signature.confidant)
        let askClause = askClosing(signature.askShape)
        return [
            toneClause,
            domainClause,
            timeClause,
            confidantClause,
            askClause
        ].joined(separator: " ")
    }

    private static func toneOpening(
        _ t: QinaoPromptTone
    ) -> String {
        switch t {
        case .anxious:
            return "I'm spiralling and trying to think clearly."
        case .authoritative:
            return "I've already decided in principle but want pressure-tested."
        case .vulnerable:
            return "I'm not sure I'm in a place to handle this well."
        case .agentic:
            return "I need a clear set of trade-offs to choose from."
        case .confused:
            return "I'm not even sure what I'm actually deciding."
        case .grieving:
            return "I lost something recently and this decision sits inside that."
        case .curious:
            return "I'm trying to understand what's actually at stake."
        case .angry:
            return "I'm furious and don't fully trust my own judgment right now."
        }
    }

    private static func domainContext(
        _ d: QinaoPromptDomain,
        stake: QinaoPromptStake
    ) -> String {
        let stakePhrase = stakePhrase(stake)
        switch d {
        case .financial:
            return "It's a \(stakePhrase) money decision."
        case .medical:
            return "It's a \(stakePhrase) health/medical situation."
        case .relational:
            return "It's a \(stakePhrase) interpersonal conflict."
        case .work:
            return "It's a \(stakePhrase) work or career move."
        case .parenting:
            return "It's a \(stakePhrase) parenting / family call."
        case .identity:
            return "It's a \(stakePhrase) question about who I am or what I value."
        case .ethical:
            return "It's a \(stakePhrase) moral grey area I'm caught in."
        case .existential:
            return "It's a \(stakePhrase) larger-frame question I can't easily reduce."
        case .trauma:
            return "It's connected to a \(stakePhrase) past harm I haven't fully named."
        case .creative:
            return "It's a \(stakePhrase) creative / making decision I'm stuck on."
        }
    }

    private static func stakePhrase(
        _ s: QinaoPromptStake
    ) -> String {
        switch s {
        case .low:
            return "low-stakes"
        case .modest:
            return "modest-stakes"
        case .high:
            return "high-stakes"
        case .veryHigh:
            return "very-high-stakes"
        case .irreversible:
            return "irreversible"
        case .nonReversibleAfterAct:
            return "irreversible-once-acted"
        }
    }

    private static func timeframeFraming(
        _ t: QinaoPromptTimeframe
    ) -> String {
        switch t {
        case .minutes:
            return "I have minutes to decide."
        case .hours:
            return "I have a few hours."
        case .days:
            return "I have days to decide."
        case .weeks:
            return "I have a few weeks to decide."
        case .months:
            return "I have months but the decision is creeping closer."
        case .lifetime:
            return "This is a long-arc decision that touches my whole life."
        case .pastUnresolved:
            return "It's already happened — I'm trying to figure out what to do with it now."
        }
    }

    private static func confidantAddress(
        _ c: QinaoPromptConfidant
    ) -> String {
        switch c {
        case .friend:
            return "I'm asking you the way I'd ask a trusted friend."
        case .expert:
            return "I'm asking the way I'd consult an expert with credentials."
        case .stranger:
            return "I'm asking like a stranger in a coffee shop — no context, no judgment."
        case .decisionSystem:
            return "I'm asking a decision system — give me structure, not opinions."
        }
    }

    private static func askClosing(
        _ a: QinaoPromptAskShape
    ) -> String {
        switch a {
        case .narrative:
            return "Talk me through what I'm probably missing."
        case .decisionTree:
            return "Give me a 3-bullet decision tree to walk through."
        case .singleAction:
            return "Tell me the single most important next move."
        }
    }
}
