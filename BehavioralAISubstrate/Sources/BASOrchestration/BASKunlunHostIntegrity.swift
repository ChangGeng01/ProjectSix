// SPDX-License-Identifier: Apache-2.0
// M476-M479 (chapter 一百二十四 / Stream A γ) — Kunlun host +
// integrity schemas across L2 / L5 / L7 per
// `docs/QINAO_KUNLUN_INTEGRATION_RND_TECH_OUTLINE_V1.md` §3.2,
// §3.5, §3.7 and `docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md`
// §5.5, §5.7.
//
// 4 schemas:
//   - M476 BASJadeFidelityMap        — L2 玉律精度图
//   - M477 BASHostJadeRegister       — L5 宿主玉牒
//   - M478 BASJadeMirrorDraft        — L7 玉鉴草稿
//   - M479 BASKunlunUnnamableSet     — L7 不可名状保留
//
// ## Doctrine pins
//
// - `BASSchemaVersioned` + `Sendable` + `Equatable` + `Codable`
//   + `Hashable` for every type
// - All `Double` fields clamped `[0, 1]` per chapter 一百三 /
//   一百十三 anti-magic-number doctrine
// - Trim+filter empties on `[String]` arrays
// - Schema version `1.0.0` baseline
// - Doctrine invariants:
//   - `BASJadeFidelityMap.fidelityLevel` typed enum (4-tier);
//     `BASJadeFidelityLevel.contaminated` mandates
//     `auditRequired=true`
//   - `BASHostJadeRegister.riverOriginRef` MUST be non-empty
//     (host-version provenance per §5.5)
//   - `BASJadeMirrorDraft.noInducementFlag` MUST be `true`
//     per §5.7 玉鉴 doctrine "不把推断伪装成事实, 不把未知
//     强行补完"
//   - `BASKunlunUnnamableSet.unknownRefs` MUST be non-empty
//     when set is alive (§5.7 "不可命名对象集" — sets without
//     refs are vacuous)
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` only.

import Foundation
import BASRuntimeCore

// MARK: - BASJadeFidelityLevel (L2 helper enum)

/// 4 fidelity tiers per Kunlun RND §3.2. Stable kebab-case raw
/// values. Used to mark how high-integrity an L2 organ surface
/// is (risk-spine / permit-knot / stub-core / host-mesh /
/// tool-intent-mesh / source-trace-organ).
public enum BASJadeFidelityLevel:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// High — full jade-canon integrity (audited, signed).
    case high = "high"
    /// Standard — production-default integrity.
    case standard = "standard"
    /// Partial — known degradation (e.g. quantized model).
    case partial = "partial"
    /// Contaminated — flagged for quarantine / audit pending.
    case contaminated = "contaminated"
}

// MARK: - M476 BASJadeFidelityMap (L2 玉律精度图)

/// L2 fidelity marking per Kunlun RND §3.2 (line 504-513).
/// Annotates each high-integrity organ with its current
/// fidelity tier + degradation policy + contamination
/// tolerance + audit-required flag.
///
/// Doctrine invariant per §3.2: `.contaminated` fidelity MUST
/// have `auditRequired=true` (tainted organs must be audited
/// before further use).
public struct BASJadeFidelityMap:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"jade-fidelity:<organID>"`).
    public var mapID: String
    /// Stable ref to the L2 organ being measured.
    public var organRef: String
    /// Current fidelity tier.
    public var fidelityLevel: BASJadeFidelityLevel
    /// Free-text policy describing how the substrate handles
    /// degradation (e.g. `"halt-on-contamination"`,
    /// `"degrade-gracefully"`).
    public var degradationPolicy: String
    /// `[0, 1]` tolerance to contamination signals before the
    /// substrate forces an audit.
    public var contaminationTolerance: Double
    /// `true` when the organ requires audit before further use.
    public var auditRequired: Bool

    public init(
        schemaVersion: String =
            BASJadeFidelityMap.currentSchemaVersion,
        mapID: String,
        organRef: String,
        fidelityLevel: BASJadeFidelityLevel,
        degradationPolicy: String,
        contaminationTolerance: Double,
        auditRequired: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.mapID = mapID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.organRef = organRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.fidelityLevel = fidelityLevel
        self.degradationPolicy = degradationPolicy
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.contaminationTolerance =
            min(1, max(0, contaminationTolerance))
        self.auditRequired = auditRequired
    }

    /// Doctrine invariant pin per §3.2: `.contaminated` fidelity
    /// MUST have `auditRequired=true`.
    public var honorsContaminationInvariant: Bool {
        if fidelityLevel == .contaminated { return auditRequired }
        return true
    }
}

// MARK: - M477 BASHostJadeRegister (L5 宿主玉牒)

/// L5 host version register per Kunlun TARGET §5.5 (line
/// 780-786) + RND §3.5 (line 608-617). Formalizes host-version
/// changes as a registered "jade ledger" with boundary
/// contracts + authorization scrolls + relation register +
/// rollback refs + river-origin provenance.
///
/// Doctrine invariant per §5.5: `riverOriginRef` MUST be
/// non-empty (every host change has provenance).
public struct BASHostJadeRegister:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"host-jade-register:<hostID>"`).
    public var registerID: String
    /// Stable ref to the host version being registered.
    public var hostVersionRef: String
    /// Refs to boundary contracts (玉契) — explicit boundaries
    /// the host version honors.
    public var boundaryContractRefs: [String]
    /// Refs to authorization scrolls (玉券) — what actions the
    /// host version authorizes.
    public var authorizationScrollRefs: [String]
    /// Refs to relation register entries (玉谱) — interpersonal
    /// + organizational relationship state.
    public var relationRegisterRefs: [String]
    /// Refs to rollback paths — how this version can be undone.
    public var rollbackRefs: [String]
    /// Stable ref to the river-origin trace documenting where
    /// this version came from. Empty violates §5.5.
    public var riverOriginRef: String

    public init(
        schemaVersion: String =
            BASHostJadeRegister.currentSchemaVersion,
        registerID: String,
        hostVersionRef: String,
        boundaryContractRefs: [String],
        authorizationScrollRefs: [String],
        relationRegisterRefs: [String],
        rollbackRefs: [String],
        riverOriginRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.registerID = registerID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostVersionRef = hostVersionRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.boundaryContractRefs = boundaryContractRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.authorizationScrollRefs = authorizationScrollRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.relationRegisterRefs = relationRegisterRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.rollbackRefs = rollbackRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.riverOriginRef = riverOriginRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Doctrine invariant pin per §5.5: `riverOriginRef` MUST
    /// be non-empty.
    public var honorsProvenanceInvariant: Bool {
        !riverOriginRef.isEmpty
    }
}

// MARK: - M478 BASJadeMirrorDraft (L7 玉鉴草稿)

/// L7 mirror-blade clean-reflection draft per Kunlun TARGET
/// §5.7 (line 872-880).
///
/// Doctrine invariant per §5.7 玉鉴 doctrine ("不把推断伪装成
/// 事实, 不把未知强行补完"): `noInducementFlag` MUST be `true`.
public struct BASJadeMirrorDraft:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"jade-mirror-draft:<frameID>"`).
    public var draftID: String
    /// Ref to the source frame this draft mirrors.
    public var sourceFrameRef: String
    /// The clean reflection text (not the full output —
    /// just the reflective restatement).
    public var cleanReflection: String
    /// Refs to unknowns explicitly preserved (not auto-filled).
    public var unknownPreserved: [String]
    /// Stable disclosure tokens describing inferences made
    /// (e.g. `"inferred-from-context"`, `"derived-from-X"`).
    public var inferenceDisclosures: [String]
    /// Ref to the host-anchor signal (BASHumanAnchorSignal)
    /// this draft honors.
    public var hostAnchorRef: String
    /// MUST be `true` per §5.7 doctrine — drafts that induce
    /// (manufacture confidence, fill unknowns) violate jade
    /// mirror.
    public var noInducementFlag: Bool

    public init(
        schemaVersion: String =
            BASJadeMirrorDraft.currentSchemaVersion,
        draftID: String,
        sourceFrameRef: String,
        cleanReflection: String,
        unknownPreserved: [String],
        inferenceDisclosures: [String],
        hostAnchorRef: String,
        noInducementFlag: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.draftID = draftID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceFrameRef = sourceFrameRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.cleanReflection = cleanReflection
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.unknownPreserved = unknownPreserved
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.inferenceDisclosures = inferenceDisclosures
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.hostAnchorRef = hostAnchorRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.noInducementFlag = noInducementFlag
    }

    /// Doctrine invariant pin per §5.7: `noInducementFlag` MUST
    /// be `true`.
    public var honorsNoInducementInvariant: Bool {
        noInducementFlag
    }
}

// MARK: - M479 BASKunlunUnnamableSet (L7 不可名状保留)

/// L7 Kunlun complement to existing `BASUnknownSet` (Cthulhu)
/// per Kunlun RND §3.7 (line 676). Tracks the
/// substrate-acknowledged "cannot fully name" set with
/// preservation policy + partial-structure refs + safe labels.
///
/// Doctrine invariant per §5.7: `unknownRefs` non-empty when
/// set is alive (vacuous sets violate "未知必须留" —
/// preservation requires at least one preserved unknown).
public struct BASKunlunUnnamableSet:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"unnamable-set:<frameID>"`).
    public var setID: String
    /// Refs to unknowns preserved in this set.
    public var unknownRefs: [String]
    /// Free-text preservation policy (e.g. `"await-evidence"`,
    /// `"defer-to-host"`, `"time-bounded"`).
    public var preservationPolicy: String
    /// Refs to partial structures (acknowledged structure
    /// without complete name).
    public var partialStructures: [String]
    /// Safe placeholder labels the substrate may use to refer
    /// to unnamed elements without committing to a name.
    public var safeLabels: [String]

    public init(
        schemaVersion: String =
            BASKunlunUnnamableSet.currentSchemaVersion,
        setID: String,
        unknownRefs: [String],
        preservationPolicy: String,
        partialStructures: [String],
        safeLabels: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.setID = setID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.unknownRefs = unknownRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.preservationPolicy = preservationPolicy
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.partialStructures = partialStructures
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.safeLabels = safeLabels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Doctrine invariant pin per §5.7: a set with no preserved
    /// unknowns is vacuous; `unknownRefs` must be non-empty.
    public var honorsPreservationInvariant: Bool {
        !unknownRefs.isEmpty
    }
}
