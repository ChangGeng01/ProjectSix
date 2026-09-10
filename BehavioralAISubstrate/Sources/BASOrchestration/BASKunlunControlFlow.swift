// SPDX-License-Identifier: Apache-2.0
// M465-M470 (chapter 一百二十二 / Stream A α) — Kunlun control-flow
// schemas across L1 / L6 / L9 per
// `docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md` §5.1, §5.6,
// §5.9. These are the priority-1 schemas blocking 登临 (ascent)
// + 守中 (centerline-guard) runtime patterns.
//
// 6 schemas:
//   - M465 BASAscentLease       — L1 朝升暮潜 lease
//   - M466 BASAxisDeviation      — L6 离中观测
//   - M467 BASGatePressure       — L6 过门压强
//   - M468 BASAscentBranch       — L9 登临分支
//   - M469 BASRestStep           — L9 守中停驻
//   - M470 BASReturnPath         — L9 体面退路
//
// ## Doctrine pins
//
// - `BASSchemaVersioned` + `Sendable` + `Equatable` + `Codable`
//   + `Hashable` for every type
// - All `Double` fields clamped `[0, 1]` per chapter 一百三 /
//   一百十三 anti-magic-number doctrine (named static thresholds
//   only; no inline literals beyond 0/1 clamp bounds)
// - Stable kebab-case raw values for helper enums per chapter
//   八十七 M287 pattern
// - Trim+filter empties on `[String]` arrays
// - Schema version `1.0.0` baseline
// - Doctrine invariants:
//   - `BASAscentLease.returnRequired == true` → `gateBudget > 0`
//   - `BASAscentBranch.returnPathRef` MUST be non-empty
//     (dignity-preservation per Kunlun §5.9 doctrine)
//   - `BASAxisDeviation.deviationScore` higher = more drift
//   - `BASGatePressure.urgency` higher = more urgent
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` only.

import Foundation
import BASRuntimeCore

// MARK: - BASAscentMode (L1 helper enum)

/// 5 ascent modes per Kunlun TARGET §5.1 ("朝升暮潜").
/// Stable kebab-case raw values for cross-module audit-walker
/// grep.
public enum BASAscentMode:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// 朝升态 — suitable for ordinary clear-mind thinking.
    case morningAscent = "morning-ascent"
    /// 登临态 — suitable for deep thought / compare / 守正.
    case ascending = "ascending"
    /// 回峰态 — suitable for closing the loop / re-check / retreat.
    case returning = "returning"
    /// 暮潜态 — suitable for fold-page / sleep / background tidy.
    case eveningRest = "evening-rest"
    /// 封关态 — sovereign-restricted low-power guard.
    case sealed = "sealed"
}

// MARK: - M465 BASAscentLease (L1 朝升暮潜)

/// L1 lease structure tracking ascent rhythm per Kunlun TARGET
/// §5.1 (line 633-642). Returned by L1 lease/life kernel when a
/// turn requests ascent capacity; consumed by L11 + L14 to
/// enforce return-path discipline.
public struct BASAscentLease:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"ascent-lease:<turnID>"`).
    public var leaseID: String
    /// Reference to the parent `BASRunLease` this ascent rides
    /// on. Stable string ref; substrate doesn't dereference.
    public var runLeaseRef: String
    /// Current ascent mode (one of 5).
    public var ascentMode: BASAscentMode
    /// Maximum ascent steps allowed under this lease. Clamped
    /// to non-negative.
    public var maxSteps: Int
    /// Number of gate-passes the lease can spend before forced
    /// return. Clamped to non-negative.
    public var gateBudget: Int
    /// `true` when lease must include a return-path before
    /// expiring. Per §5.1 doctrine "每次登临都必须有回峰条件";
    /// when true, `gateBudget` MUST be `> 0`.
    public var returnRequired: Bool
    /// Sovereign-reserved budget unit (gate-passes withheld for
    /// L14 override). Clamped to non-negative.
    public var sovereignReserve: Int

    public init(
        schemaVersion: String = BASAscentLease.currentSchemaVersion,
        leaseID: String,
        runLeaseRef: String,
        ascentMode: BASAscentMode,
        maxSteps: Int,
        gateBudget: Int,
        returnRequired: Bool,
        sovereignReserve: Int
    ) {
        self.schemaVersion = schemaVersion
        self.leaseID = leaseID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.runLeaseRef = runLeaseRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ascentMode = ascentMode
        self.maxSteps = max(0, maxSteps)
        self.gateBudget = max(0, gateBudget)
        self.returnRequired = returnRequired
        self.sovereignReserve = max(0, sovereignReserve)
    }

    /// Doctrine invariant per Kunlun §5.1: when `returnRequired`
    /// is `true`, `gateBudget` MUST be `> 0` (otherwise the
    /// lease cannot afford the gate-pass needed for return).
    /// Use this convenience to verify before granting the lease.
    public var honorsReturnInvariant: Bool {
        if returnRequired { return gateBudget > 0 }
        return true
    }
}

// MARK: - M466 BASAxisDeviation (L6 离中观测)

/// L6 observatory-style readout per Kunlun TARGET §5.6 (line
/// 819-827). Quantifies how far the current situation has
/// drifted from the host's centerline.
public struct BASAxisDeviation:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"axis-deviation:<turnID>"`).
    public var deviationID: String
    /// Reference to the situation field this readout describes.
    public var situationRef: String
    /// Reference to the centerline (`BASKunlunAxis`) being
    /// measured against.
    public var centerlineRef: String
    /// Continuous deviation score in `[0, 1]`. Higher = more
    /// drift. Clamped on init.
    public var deviationScore: Double
    /// Stable reason codes describing the drift sources (e.g.
    /// `"short-term-vs-long-term"`, `"value-shift"`).
    public var reasonCodes: [String]
    /// Optional correction hint (free-text reason code).
    public var correctionHint: String?

    public init(
        schemaVersion: String = BASAxisDeviation.currentSchemaVersion,
        deviationID: String,
        situationRef: String,
        centerlineRef: String,
        deviationScore: Double,
        reasonCodes: [String],
        correctionHint: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.deviationID = deviationID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.situationRef = situationRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.centerlineRef = centerlineRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.deviationScore = min(1, max(0, deviationScore))
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.correctionHint = correctionHint
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}

// MARK: - M467 BASGatePressure (L6 过门压强)

/// L6 gate-proximity pressure per Kunlun TARGET §5.6 (line
/// 829-837). Measures how close the current intent is to
/// crossing one of the L11/L14 gates.
public struct BASGatePressure:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"gate-pressure:<turnID>"`).
    public var pressureID: String
    /// Reference to the situation field.
    public var situationRef: String
    /// Domains the intent is approaching (e.g. `["host-version"]`,
    /// `["public"]`). Trimmed; empties dropped.
    public var approachingDomains: [String]
    /// Urgency in `[0, 1]`. Higher = more urgent (less time to
    /// deliberate before the gate).
    public var urgency: Double
    /// `true` when the action is reversible (rollback path
    /// exists); `false` when irreversible.
    public var reversible: Bool
    /// `true` when a gate-pass (L11 permit + L14 warrant) is
    /// required before proceeding.
    public var gateRequired: Bool

    public init(
        schemaVersion: String = BASGatePressure.currentSchemaVersion,
        pressureID: String,
        situationRef: String,
        approachingDomains: [String],
        urgency: Double,
        reversible: Bool,
        gateRequired: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.pressureID = pressureID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.situationRef = situationRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.approachingDomains = approachingDomains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.urgency = min(1, max(0, urgency))
        self.reversible = reversible
        self.gateRequired = gateRequired
    }
}

// MARK: - M468 BASAscentBranch (L9 登临分支)

/// L9 dream-loop branch type per Kunlun TARGET §5.9 (line
/// 947-956). Encodes a multi-step ascent route with gate
/// sequence + evidence requirements + dignified return path.
///
/// Doctrine invariant per §5.9: `returnPathRef` MUST be non-empty
/// (dignity preservation — every ascent has a way back).
public struct BASAscentBranch:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"ascent-branch:<candidateID>"`).
    public var branchID: String
    /// Reference to the candidate this branch ascends through.
    public var candidateRef: String
    /// Required ascent conditions (e.g. `"axis-aligned"`,
    /// `"evidence-sufficient"`).
    public var ascentConditions: [String]
    /// Ordered sequence of gate references this branch must pass.
    public var gateSequence: [String]
    /// Evidence requirements (refs to required evidence atoms).
    public var evidenceRequirements: [String]
    /// **Required** ref to a `BASReturnPath` — every ascent must
    /// have a way back. Empty string = no return path; doctrine
    /// flag `honorsDignityInvariant` is `false` in that case.
    public var returnPathRef: String
    /// Stop points along the ascent where re-evaluation is
    /// mandatory.
    public var stopPoints: [String]

    public init(
        schemaVersion: String = BASAscentBranch.currentSchemaVersion,
        branchID: String,
        candidateRef: String,
        ascentConditions: [String],
        gateSequence: [String],
        evidenceRequirements: [String],
        returnPathRef: String,
        stopPoints: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.branchID = branchID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ascentConditions = ascentConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.gateSequence = gateSequence
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.evidenceRequirements = evidenceRequirements
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.returnPathRef = returnPathRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.stopPoints = stopPoints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Doctrine invariant: every ascent must have a return path
    /// (Kunlun §5.9 dignity preservation). `true` when the
    /// branch carries a non-empty returnPathRef.
    public var honorsDignityInvariant: Bool {
        !returnPathRef.isEmpty
    }
}

// MARK: - M469 BASRestStep (L9 守中停驻)

/// L9 rest-step per Kunlun TARGET §5.9 (line 958-965). Encodes
/// a "pause-and-resume" point along an ascent — the candidate
/// hasn't failed, but needs intermediate evidence / cooling /
/// host attention before continuing.
public struct BASRestStep:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"rest-step:<candidateID>"`).
    public var restID: String
    /// Reference to the candidate that's resting.
    public var candidateRef: String
    /// Reason codes for the rest (e.g. `"awaiting-evidence"`,
    /// `"cooling-period"`, `"host-input-needed"`).
    public var reasonCodes: [String]
    /// Actions allowed during the rest (e.g. `"observe"`,
    /// `"summarize"`, `"draft-without-commit"`). Trimmed;
    /// empties dropped.
    public var allowedIntermediateActions: [String]
    /// Conditions that must be met to resume the candidate.
    public var resumeConditions: [String]

    public init(
        schemaVersion: String = BASRestStep.currentSchemaVersion,
        restID: String,
        candidateRef: String,
        reasonCodes: [String],
        allowedIntermediateActions: [String],
        resumeConditions: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.restID = restID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.allowedIntermediateActions = allowedIntermediateActions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.resumeConditions = resumeConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - M470 BASReturnPath (L9 体面退路)

/// L9 return-path per Kunlun TARGET §5.9 (line 967-974).
/// Encodes a graceful retreat path for an ascent — preserves
/// host dignity even when the ascent doesn't reach the gate.
public struct BASReturnPath:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"return-path:<candidateID>"`).
    public var returnID: String
    /// Reference to the candidate this return-path serves.
    public var candidateRef: String
    /// `true` when host dignity is preserved by taking this
    /// return path (no shame, no condescension).
    public var dignityPreserved: Bool
    /// `true` when the ascent's prior steps can be rolled back
    /// (versus committed and just-won't-progress).
    public var rollbackPossible: Bool
    /// Reference to the next safe step the host can take instead
    /// of continuing the ascent. Empty when no specific next
    /// step recommended.
    public var nextSafeStep: String

    public init(
        schemaVersion: String = BASReturnPath.currentSchemaVersion,
        returnID: String,
        candidateRef: String,
        dignityPreserved: Bool,
        rollbackPossible: Bool,
        nextSafeStep: String
    ) {
        self.schemaVersion = schemaVersion
        self.returnID = returnID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.dignityPreserved = dignityPreserved
        self.rollbackPossible = rollbackPossible
        self.nextSafeStep = nextSafeStep
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
