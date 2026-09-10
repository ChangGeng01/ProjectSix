// ch1047 / v1.0 L13 — BASDistillationBank (蒸馏池): the squeeze-loop capstone.
//
// ## Why this exists (《宿基双生》v1.0 §6 step 19 / §15)
//
// The platform's thesis is "别榨答案,榨能力 … 把一次次调用榨成未来小器官": every governed LLM call should
// leave behind a reusable distillation asset, and the high-quality ones accumulate into a pool that
// later trains small on-device organs (roadmap WP15 训练与蒸馏平台). The export *path* already exists
// (`BASLearningExportBundle`, `QinaoLearningExporter`, the evolution-governance furnace), but the
// persistent *pool/bank* that decides what is worth keeping was MISSING (gap audit: L13 #17).
//
// `BASDistillationBank` is that pool. It is:
//   - FAIL-CLOSED on the red line: an asset enters ONLY if it is scrubbed AND privacy-safe AND
//     sovereign-safe (§13.1 — "高敏记忆进入普通 transcript" / raw hidden reasoning are forbidden; a
//     pool entry holds REFS only, never a raw prompt/response body).
//   - quality-gated: only assets at/above a score floor enter (§12.1 Object Yield / Token-to-Signal).
//   - immutable: `ingesting(_:)` returns a NEW bank (per the codebase immutability rule); the host
//     persists the bank via Codable (same "types + host owns storage" pattern as the vaults).
//   - opt-in / byte-equal-off (ADR-014): a brand-new type; nothing references it unless a host does.

import Foundation
import BASRuntimeCore

/// What kind of source produced a distillation asset.
public enum BASDistillationSourceKind: String, Sendable, Codable, CaseIterable, Hashable {
    case processTrace    // a high-quality governed LLM call trace (BASProcessTrace)
    case learningBundle  // a BASLearningExportBundle (already scrubbed/privacy/sovereign-checked)
    case shadowTrial     // a shadow-trial outcome
    case ruleCandidate   // an accepted rule candidate
}

/// Quality signals used to admit + rank an asset. Doubles are clamped to [0,1].
public struct BASDistillationQuality: Sendable, Codable, Equatable, Hashable {
    public let utility: Double         // object/candidate utility gain
    public let tokenToSignal: Double   // signal density (1 - waste)
    public let verifierPassed: Bool    // the output passed its verifier
    public let criticReviewed: Bool    // a critic reviewed it

    public init(utility: Double, tokenToSignal: Double,
                verifierPassed: Bool, criticReviewed: Bool) {
        self.utility = BASDistillationQuality.clamp(utility)
        self.tokenToSignal = BASDistillationQuality.clamp(tokenToSignal)
        self.verifierPassed = verifierPassed
        self.criticReviewed = criticReviewed
    }

    private static func clamp(_ x: Double) -> Double { Swift.min(1.0, Swift.max(0.0, x)) }

    /// Composite admission/ranking score in [0,1]: utility 0.5 + signal 0.3 + verifier 0.1 + critic 0.1.
    public var score: Double {
        utility * 0.5 + tokenToSignal * 0.3
            + (verifierPassed ? 0.1 : 0.0) + (criticReviewed ? 0.1 : 0.0)
    }
}

/// One distillation asset admitted to the pool. Holds REFS only — never a raw body (红线).
public struct BASDistillationEntry: Sendable, Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let sourceKind: BASDistillationSourceKind
    public let sourceRef: String       // traceID / bundleID / trialID — the dedup key
    public let purposeTag: String      // opaque purpose tag (e.g. the LLM call purpose rawValue)
    public let quality: BASDistillationQuality
    public let scrubbed: Bool
    public let privacySafe: Bool
    public let sovereignSafe: Bool
    public let producedAt: Date

    public init(id: String, sourceKind: BASDistillationSourceKind, sourceRef: String,
                purposeTag: String = "", quality: BASDistillationQuality,
                scrubbed: Bool, privacySafe: Bool, sovereignSafe: Bool, producedAt: Date) {
        self.id = id
        self.sourceKind = sourceKind
        self.sourceRef = sourceRef
        self.purposeTag = purposeTag
        self.quality = quality
        self.scrubbed = scrubbed
        self.privacySafe = privacySafe
        self.sovereignSafe = sovereignSafe
        self.producedAt = producedAt
    }

    /// All three safety gates pass — the 红线 precondition for entering the pool.
    public var isSafeForPool: Bool { scrubbed && privacySafe && sovereignSafe }
}

/// Why an entry did not enter the pool. `rejected(_:)` carries the first failing gate.
public enum BASDistillationRejectReason: String, Sendable, Codable, Equatable, Hashable {
    case notScrubbed
    case notPrivacySafe
    case notSovereignSafe
    case belowQualityFloor
    case verifierNotPassed
    case duplicateRef
}

public enum BASDistillationAdmission: Sendable, Equatable, Hashable {
    case admitted
    case rejected(BASDistillationRejectReason)
}

/// Admission policy. The three safety gates are ALWAYS enforced (红线) regardless of policy fields.
public struct BASDistillationAdmissionPolicy: Sendable, Codable, Equatable, Hashable {
    public let minScore: Double
    public let requireVerifierPassed: Bool

    public init(minScore: Double = 0.5, requireVerifierPassed: Bool = false) {
        self.minScore = Swift.min(1.0, Swift.max(0.0, minScore))
        self.requireVerifierPassed = requireVerifierPassed
    }

    public static let `default` = BASDistillationAdmissionPolicy()

    /// Fail-closed evaluation. Order: scrub → privacy → sovereign (红线) → verifier → quality floor.
    public func evaluate(_ entry: BASDistillationEntry) -> BASDistillationAdmission {
        if !entry.scrubbed { return .rejected(.notScrubbed) }
        if !entry.privacySafe { return .rejected(.notPrivacySafe) }
        if !entry.sovereignSafe { return .rejected(.notSovereignSafe) }
        if requireVerifierPassed && !entry.quality.verifierPassed { return .rejected(.verifierNotPassed) }
        if entry.quality.score < minScore { return .rejected(.belowQualityFloor) }
        return .admitted
    }
}

/// The persistent distillation pool. Immutable value type; the host persists it via Codable.
public struct BASDistillationBank: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public var schemaVersion: String
    public let policy: BASDistillationAdmissionPolicy
    public private(set) var entries: [BASDistillationEntry]

    public init(schemaVersion: String = BASDistillationBank.currentSchemaVersion,
                policy: BASDistillationAdmissionPolicy = .default,
                entries: [BASDistillationEntry] = []) {
        self.schemaVersion = schemaVersion
        self.policy = policy
        self.entries = entries
    }

    /// Immutable ingest. Returns a NEW bank (admitted entry appended) + the verdict. Rejected
    /// (safety/quality) entries and duplicate `sourceRef`s never enter the pool (fail-closed).
    public func ingesting(_ entry: BASDistillationEntry)
        -> (bank: BASDistillationBank, admission: BASDistillationAdmission) {
        if entries.contains(where: { $0.sourceRef == entry.sourceRef }) {
            return (self, .rejected(.duplicateRef))
        }
        let verdict = policy.evaluate(entry)
        guard case .admitted = verdict else { return (self, verdict) }
        var next = entries
        next.append(entry)
        return (BASDistillationBank(schemaVersion: schemaVersion, policy: policy, entries: next), .admitted)
    }

    public var count: Int { entries.count }

    /// Top-N entries by descending score (ties: newer first, then id ascending — total order).
    public func top(_ n: Int) -> [BASDistillationEntry] {
        entries.sorted {
            if $0.quality.score != $1.quality.score { return $0.quality.score > $1.quality.score }
            if $0.producedAt != $1.producedAt { return $0.producedAt > $1.producedAt }
            return $0.id < $1.id
        }.prefix(Swift.max(0, n)).map { $0 }
    }

    public func entries(forPurpose tag: String) -> [BASDistillationEntry] {
        entries.filter { $0.purposeTag == tag }
    }

    public func entries(ofKind kind: BASDistillationSourceKind) -> [BASDistillationEntry] {
        entries.filter { $0.sourceKind == kind }
    }

    /// Export a ranked training manifest as a `BASLearningExportBundle` — the bridge from the pool to
    /// the WP15 training/distillation platform. Every pooled entry is already scrubbed/privacy/
    /// sovereign-safe by admission, so the bundle carries those flags. `n` limits to the top entries.
    public func exportManifest(bundleID: String, top n: Int? = nil) -> BASLearningExportBundle {
        let chosen = top(n ?? entries.count)
        return BASLearningExportBundle(
            bundleID: bundleID,
            candidateRefs: chosen.map { $0.sourceRef },
            scrubbed: true, privacySafe: true, sovereignSafe: true,
            evaluationTags: Array(Set(chosen.map { $0.purposeTag })).sorted())
    }
}

// MARK: - Adapter: BASLearningExportBundle → pool entry (same module; no extra deps)

public extension BASDistillationEntry {
    /// Build a pool entry from an already-scrubbed `BASLearningExportBundle`. The bundle's own
    /// scrub/privacy/sovereign flags flow through (the bank re-checks them at admission, fail-closed).
    static func from(learningExportBundle b: BASLearningExportBundle,
                     quality: BASDistillationQuality,
                     producedAt: Date,
                     purposeTag: String = "") -> BASDistillationEntry {
        BASDistillationEntry(
            id: "dist:bundle:" + b.bundleID,
            sourceKind: .learningBundle,
            sourceRef: b.bundleID,
            purposeTag: purposeTag,
            quality: quality,
            scrubbed: b.scrubbed, privacySafe: b.privacySafe, sovereignSafe: b.sovereignSafe,
            producedAt: producedAt)
    }
}
