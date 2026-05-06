// MARK: - SampleHostPromptTypes
//
// chapter 二百十八 / M799 — extracted from SampleHostModel.swift.
//
// Combinatorial prompt-space type bundle (chapter 一百四十九):
// 6 typed dimension enums + signature struct + generated-prompt
// struct. The 6 dimensions multiply to 8 × 10 × 6 × 7 × 4 × 3 =
// 40,320 unique combinations — the catalog space exercised by
// `SampleHostBenchPromptCatalog` (chapter 二百十二 carve-out)
// via coprime stride 5041 = 71² scatter walk.
//
// Pre-this-batch: ~50 LOC of typed prompt-space schema buried at
// the top of the god file alongside @Published / orchestrator code.
// Post-this-batch: prompt-space types own their file.
//
// This bundle mirrors `QinaoExtendedPromptCorpus` from the
// BehavioralAISubstrate / QinaoLoop module exactly. SampleHost
// inlines the types instead of importing QinaoLoop because the
// iOS target can't depend on QinaoLoop without Xcode project
// surgery (chapter 一百四十九 doctrine: SampleHost stays as
// thin BAS host with minimal cross-module deps).
//
// Doctrine pins:
//   - 6 dimensions and their case orderings are doctrine; any
//     re-ordering breaks `generate(seed:)` reproducibility.
//   - kebab-case raw values where the case has compound naming
//     (`very-high` / `non-reversible-after-act` / `past-unresolved`
//     / `decision-system` / `decision-tree` / `single-action`).
//   - `SampleHostPromptSignature` is `Codable + Hashable + Equatable`
//     so it can be a dict key + JSONL field across the bench code.
//   - 不变量 #1-#3 + Red line 7: ✓ schema is data-only.
//   - chapter 二百十一 single-source-of-truth: prompt-space
//     invariant owned by one file.

import Foundation

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
