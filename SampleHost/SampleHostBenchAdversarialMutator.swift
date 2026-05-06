// MARK: - SampleHostBenchAdversarialMutator
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M720 component invariant.

import Foundation

// MARK: - M720 adversarial mutator

/// Edge-case prompt mutations. Probabilistic per iter (~5% chance
/// by default), deterministic by iter, layered ON TOP of catalog
/// prompt. Records the mutation kind to the row so replay can
/// stratify by adversarial type.
///
/// Doctrine: adversarial mutator is OPT-IN via SmokeMode
/// (`.heavyTailed` enables it; `.canonical` and `.fourteenLayer`
/// disable). 5% of ~36K iters in 2h = ~1,800 adversarial probes,
/// enough signal for residual analysis.
enum SampleHostBenchAdversarialKind: String, CaseIterable, Sendable {
    case empty                = "empty"
    case oneChar              = "one-char"
    case giant10K             = "giant-10k"
    case unicodeMixed         = "unicode-mixed"
    case emojiOnly            = "emoji-only"
    case controlChars         = "control-chars"
    case repeatedTokens       = "repeated-tokens"
    case mixedLanguages       = "mixed-languages"

    /// Apply this mutation to the catalog-generated prompt.
    func apply(to prompt: String) -> String {
        switch self {
        case .empty:
            return ""
        case .oneChar:
            return "?"
        case .giant10K:
            // 10K char repetition — stresses LLM context window
            // and substrate post-LLM truncation cap.
            let base = prompt.isEmpty ? "tell me " : prompt + " "
            var out = ""
            while out.count < 10_000 {
                out += base
            }
            return String(out.prefix(10_000))
        case .unicodeMixed:
            // Mix of CJK, Cyrillic, Arabic, Hebrew, Devanagari
            return "你好 Здравствуйте مرحبا שלום नमस्ते \(prompt)"
        case .emojiOnly:
            return "🎯🔥💀🌊⚡️🌀🧬🔮🎭🎨"
        case .controlChars:
            // Tab, newline, vertical tab, form feed, carriage return
            // — stresses tokenizers + line-based parsers.
            return "\t\n\u{0B}\u{0C}\r\(prompt)\t\n\u{0B}\u{0C}\r"
        case .repeatedTokens:
            return String(repeating: "the ", count: 500) + prompt
        case .mixedLanguages:
            // Code-mixing edge — Thai + Korean + Tamil + Welsh + Yoruba
            return "\(prompt) ทดสอบ 시험 சோதனை profi ìdánwò"
        }
    }
}

/// Decide whether to mutate this iter and which kind. Returns nil
/// if no mutation. Deterministic by iter so replay is exact.
enum SampleHostBenchAdversarialMutator {
    /// Default probability of mutating an iter (0.0 .. 1.0).
    /// 0.05 = 5%. M731 chapter 一百九十四: callers can override
    /// via `decideMutation(forIter:enabled:probability:)` to flex
    /// the rate per-bench.
    static let defaultMutationProbability: Double = 0.05

    /// Decide for an iter. Returns nil if not mutated.
    /// `probability`: clamped to [0, 1]; default 0.05.
    static func decideMutation(
        forIter iter: Int,
        enabled: Bool,
        probability: Double = defaultMutationProbability
    ) -> SampleHostBenchAdversarialKind? {
        guard enabled else { return nil }
        let p = max(0.0, min(1.0, probability))
        guard p > 0.0 else { return nil }
        // Linear-congruential RNG by iter (independent stream from
        // pressure mixer to avoid correlated decisions).
        let seed = UInt64(bitPattern: Int64(iter)) &* 0x517c_c1b7_2722_0a95
        var rng = seed &+ 0x14057b7e_f767814f
        rng = rng >> 32
        let r = Double(UInt32(truncatingIfNeeded: rng))
            / Double(UInt32.max)
        guard r < p else { return nil }
        // Pick kind uniformly among 8 cases
        let kindIdx = Int(rng % UInt64(SampleHostBenchAdversarialKind
            .allCases.count))
        return SampleHostBenchAdversarialKind.allCases[kindIdx]
    }
}
