// MARK: - BASModuleConsolidationPolicy — chapter 四百三十 / M1093
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase D 第二刀。 Typed policy
// surface naming the 4 modules planned for merge or
// drop + their current consolidation status。 Sets up
// the explicit user-confirmed deletion path without
// performing the deletions in autonomous mode。
//
// ## Why this exists (system entropy framing)
//
// The 2026-04-26 audit identified 4 modules as
// dead-weight or consolidation candidates:
//
//   1. BASChatCompletionsAdapter (~486 LOC) — generic
//      OpenAI-compatible HTTP organ provider; vendored
//      by Qinao SDK separately
//   2. BASMLXAdapter (~1,124 LOC) — MLX organ provider;
//      ANE replacement path lives in the new
//      BASMetalSubstrate (Phase E)
//   3. BASLeaseLife (~1,309 LOC) — leaf module; planned
//      merge into BASAppleAdapters
//   4. BASWorldPrior (~2,447 LOC) — leaf module; planned
//      merge into BASRuntimeCore
//
// Total ~5,366 LOC of consolidation-target code。
//
// In autonomous mode the actual module operations
// (Package.swift drops + git mv merges) are too
// destructive — they can:
//   - Break Qinao SDK / SampleHost build immediately
//   - Orphan tests that import via @testable
//   - Conflict with BASChatCompletionsAdapter being a
//     PUBLIC library exported in Package.swift
//   - Require explicit downstream consumer migration
//
// `BASModuleConsolidationPolicy` ships the typed
// policy surface that:
//   - Names each consolidation candidate
//   - Carries its current status (.pendingMerge /
//     .merged / .blocked)
//   - Carries the merge target module name
//   - Carries the rationale for blocked status (where
//     applicable)
//
// Future cleanup chapters consult this policy to
// know which modules are SAFE to drop and which need
// further consumer-coordination first。
//
// ## What this ships (M1093)
//
//   - `BASModuleConsolidationCandidate` enum (4 cases:
//     chatCompletionsAdapter / mlxAdapter / leaseLife
//     / worldPrior) with String rawvalues matching
//     module names
//   - `BASModuleConsolidationStatus` enum (3 cases:
//     pendingMerge / merged / blocked)
//   - `BASModuleConsolidationEntry` Sendable + Codable
//     struct (candidate + status + targetModule +
//     blockedReason + estimatedLOCDelta)
//   - `BASModuleConsolidationPolicy` namespace with
//     `entries: [BASModuleConsolidationEntry]` static
//     constant covering all 4 candidates
//
// ## What this DOES NOT ship (deferred)
//
// The actual module operations (Package.swift
// modifications + source file moves + import statement
// rewrites) are NOT performed at M1093。 They land in
// follow-up chapters under explicit user control。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     candidate + status enums)
//   - chapter 二百一一 — single source-of-truth (one
//     policy lists all 4 candidates)
//   - chapter 三百九二 — replay-determinism (entries
//     list is a static constant)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive policy;no module touched)
//   - 红线 7 — hint-only (policy is observation/planning,
//     not commitment authority)
//   - ADR-014 OPT-IN — purely additive
//   - RADICAL EVOLUTION SWEEP Phase D — this chapter

import Foundation

// MARK: - Candidate enum

/// Typed enum naming the 4 modules identified as
/// consolidation candidates by the 2026-04-26 audit。
public enum BASModuleConsolidationCandidate:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// Generic OpenAI-compatible HTTP organ provider。
    /// ~486 LOC。 Qinao SDK vendors its own copy。
    case chatCompletionsAdapter =
        "BASChatCompletionsAdapter"

    /// MLX organ provider for Gemma weights。 ~1,124 LOC。
    /// ANE replacement path lives in BASMetalSubstrate
    /// (Phase E)。
    case mlxAdapter = "BASMLXAdapter"

    /// Leaf module for thermal/pressure observation +
    /// breath scheduling。 ~1,309 LOC。 Planned merge
    /// into BASAppleAdapters。
    case leaseLife = "BASLeaseLife"

    /// Leaf module for world-knowledge layer。 ~2,447 LOC。
    /// Planned merge into BASRuntimeCore。
    case worldPrior = "BASWorldPrior"
}

// MARK: - Status enum

/// Typed status of a consolidation candidate。
public enum BASModuleConsolidationStatus:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// Merge planned but not yet performed。 Future
    /// chapter under explicit user control will execute
    /// the move + Package.swift update + import
    /// rewrites。
    case pendingMerge = "pending-merge"

    /// Merge completed。 Source files now live under
    /// `targetModule`;Package.swift has dropped the
    /// candidate's library + target declarations。
    case merged = "merged"

    /// Merge blocked by an external dependency (e.g.
    /// Qinao SDK still imports the module directly)。
    /// `blockedReason` carries the human-readable
    /// explanation。
    case blocked = "blocked"
}

// MARK: - Entry struct

/// Per-candidate policy entry。 Names the candidate,
/// its current status,merge target,and rationale for
/// blocked status (if applicable)。
public struct BASModuleConsolidationEntry:
    Equatable, Hashable, Codable, Sendable
{

    public let candidate: BASModuleConsolidationCandidate
    public let status: BASModuleConsolidationStatus
    public let targetModule: String?
    public let blockedReason: String?
    public let estimatedLOCDelta: Int

    public init(
        candidate: BASModuleConsolidationCandidate,
        status: BASModuleConsolidationStatus,
        targetModule: String? = nil,
        blockedReason: String? = nil,
        estimatedLOCDelta: Int
    ) {
        self.candidate = candidate
        self.status = status
        self.targetModule = targetModule
        self.blockedReason = blockedReason
        self.estimatedLOCDelta = estimatedLOCDelta
    }
}

// MARK: - Policy

/// Single-source-of-truth typed policy for module
/// consolidation。 At M1093 all 4 candidates are
/// `.pendingMerge`;future chapters under explicit
/// user control flip status to `.merged` after
/// performing the actual operations。
public enum BASModuleConsolidationPolicy {

    public static let entries:
        [BASModuleConsolidationEntry] =
    [
        BASModuleConsolidationEntry(
            candidate: .chatCompletionsAdapter,
            status: .pendingMerge,
            targetModule: nil,  // dropped, not merged
            blockedReason: nil,
            estimatedLOCDelta: -486),
        BASModuleConsolidationEntry(
            candidate: .mlxAdapter,
            status: .pendingMerge,
            targetModule: nil,  // dropped, not merged
            blockedReason: nil,
            estimatedLOCDelta: -1124),
        BASModuleConsolidationEntry(
            candidate: .leaseLife,
            status: .pendingMerge,
            targetModule: "BASAppleAdapters",
            blockedReason: nil,
            estimatedLOCDelta: 0),  // moved, not deleted
        BASModuleConsolidationEntry(
            candidate: .worldPrior,
            status: .pendingMerge,
            targetModule: "BASRuntimeCore",
            blockedReason: nil,
            estimatedLOCDelta: 0)   // moved, not deleted
    ]

    public static var entryCount: Int {
        return entries.count
    }

    /// Look up policy entry by candidate enum。
    public static func entry(
        for candidate: BASModuleConsolidationCandidate
    ) -> BASModuleConsolidationEntry? {
        return entries.first {
            $0.candidate == candidate
        }
    }

    /// All candidates currently in `.pendingMerge`
    /// status。 Future cleanup chapters iterate this
    /// list to know what's ready for execution。
    public static var pendingMergeCandidates:
        [BASModuleConsolidationCandidate]
    {
        return entries
            .filter { $0.status == .pendingMerge }
            .map { $0.candidate }
    }

    /// Cumulative LOC delta if all `.pendingMerge`
    /// entries land。 Negative delta = net deletion。
    /// At M1093: -486 + -1124 + 0 + 0 = -1610 LOC
    /// (the 2 leaf modules MOVE without LOC delta;
    /// the 2 adapter drops produce the actual
    /// reduction)。
    public static var pendingLOCDelta: Int {
        return entries
            .filter { $0.status == .pendingMerge }
            .reduce(0) { $0 + $1.estimatedLOCDelta }
    }
}
