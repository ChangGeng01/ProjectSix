// MARK: - SampleHostBenchPromptCatalog
//
// chapter 二百十二 / M793 — extracted from SampleHostModel.swift.
//
// Carve-out target: full canonical prompt catalog (40,320-combination
// signature space) + scatter walk + procedural mutation alphabet.
// Self-contained value-type — no @Published, no actor, no I/O.
//
// Doctrine pin (chapter 一百五十 + 一百七十三 + 一百七十四):
//   - Coprime stride 5041 = 71² with gcd(5041, 40320) = 1 so
//     adjacent iter values produce DISTANT signatures (not the
//     same tone/domain bucket repeated 5040 times in a row).
//   - 5-variant mutation alphabet exercises substrate response to
//     surface-level prompt variations without changing typed
//     signature.
//
// Architectural deconstruction step 4 (chapter 二百九 → 二百十一
// did cooldown / iter context / dispatch policy; this batch shifts
// to schema / catalog carve-outs):
//   - chapter 二百十二 (this file): prompt catalog
//   - chapter 二百十三: FourteenLayerSmokeProfile
//   - chapter 二百十四: SampleHostHybridBenchRow schema
//   - chapter 二百十五: HybridBenchConfig + SmokeMode + tuning
//   - chapter 二百十六: JSONL runner actors
//
// Each carve-out shrinks SampleHostModel.swift toward "just
// @Published model + bench loop orchestrator". By chapter 二百十
// 八 the model file should be < 3000 LOC, paving the way for the
// long-deferred chapter 二百十九+ SampleHostBenchEngine actor
// extraction (which can finally happen on a clean base).
//
// Doctrine pins (red-line preservation):
//   - 不变量 #1-#3:                     ✓ pure derive, no I/O.
//   - Red line 7 (HINT-ONLY):           ✓ catalog has no decision-
//     making power; it just produces deterministic prompt text.
//   - chapter 一百九十二 single-source-of-truth: this file owns
//     the canonical prompt-space invariant.

import Foundation

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
