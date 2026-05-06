// MARK: - BASRiskCalibrationStratumSubModelRef + Registry —
//          chapter 二百六十五 / M755
//
// Per-stratum sub-model typed contract — Stage 4 Step 5 of 5.
//
// ## Why this exists
//
// chapter 二百六十一 / M744 ADR-012 Hybrid pipeline produces
// per-stratum threshold deltas. For some strata the right
// signal isn't a flat threshold delta but a stratum-specific
// model — e.g. "for tone=angry|stake=high|confidant=public,
// score this prompt with the model trained on that stratum's
// data because base-threshold tuning isn't enough granularity".
//
// 附录 V Stage 4 chapter 二百六十五 calls this "per-stratum
// sub-models". Real training requires real bench data (Stage 3
// chapter 二百五十六 user-action). What this chapter ships:
//
//   - `BASRiskCalibrationStratumSubModelRef` — typed schema
//     pointing to a sub-model artifact (`.mlpackage` path,
//     model version, training provenance, evaluation metric,
//     L14 warrant ref).
//   - `BASRiskCalibrationStratumSubModelRegistry` actor — holds
//     the active sub-model refs by stratum key. Replacement
//     follows the same monotonic-version + warrant-required
//     contract as `BASRiskCalibrationGate` (chapter 二百六十四).
//
// Real `.mlpackage` artifacts are operator-produced offline
// (chapter 二百五十六 → 二百五十八 train pipeline). The schema
// is typed-ready today; once an `.mlpackage` exists, hosts wire
// it via `register(_:)` without further code changes.
//
// ## Doctrine pins
//
//   - 不变量 #2 神经不掌权: sub-model refs are operator-authored
//     + L14-signed (registry rejects empty `approvedByWarrantRef`).
//     Substrate doesn't auto-derive.
//   - 不变量 #3 私有经验不进权重: stratum keys are generalized.
//     Sub-models are trained from aggregated data (chapter
//     二百六十二 aggregator strips host data); per-host sub-models
//     are forbidden by ADR-012.
//   - ADR-006 strict + ADR-012: sub-model registration is a
//     between-deploy event. Per-turn substrate logic reads from
//     the registry; the registry doesn't update mid-turn.
//   - chapter 二百十一 single-source-of-truth: schema + registry
//     in this one file.
//   - chapter 二百六十四 / M747 monotonic-version idiom: same
//     replacement validation.

import Foundation
import BASRuntimeCore

// MARK: - BASRiskCalibrationStratumSubModelRef

/// Typed reference to a per-stratum sub-model artifact.
public struct BASRiskCalibrationStratumSubModelRef:
    BASSchemaVersioned, Sendable, Equatable, Codable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    /// Default minimum acceptable evaluation metric (e.g.
    /// accuracy or F1). Operators can author refs with lower
    /// values, but the registry rejects them as malformed.
    /// Anti-magic-number: chapter 一百十三 doctrine. Default
    /// 0.50 — random-guess baseline; a real sub-model should
    /// beat this trivially.
    public static let defaultMinAcceptableMetric: Double = 0.50

    public var schemaVersion: String

    /// Stable stratum key (matches `BASRiskCalibrationStratumDelta.stratumKey`
    /// format, e.g. `"tone=angry|stake=high|confidant=public"`).
    public let stratumKey: String

    /// Artifact reference. Format is operator-defined; canonical:
    /// `"mlpackage:<filename>"` for CoreML packages, or
    /// `"weights:<sha256>"` for arbitrary weight blobs. Required
    /// (empty is invalid).
    public let modelArtifactRef: String

    /// Monotonic sub-model version, e.g. `"v0.1"`. Same monotonic
    /// rule as bundle versions: a registered sub-model can only
    /// be replaced by one with strictly greater version.
    public let modelVersion: String

    /// When the sub-model was trained.
    public let trainedAt: Date

    /// Reference to the aggregate provenance the sub-model was
    /// trained from. Same format as
    /// `BASRiskCalibrationBundle.aggregateProvenanceRef`. Required.
    public let trainedFromProvenanceRef: String

    /// Number of bench rows the sub-model was trained on.
    /// Operator-recorded; clamped non-negative.
    public let evidenceRowCount: Int

    /// Evaluation metric (e.g. holdout F1, accuracy, AUC) in
    /// `[0, 1]`. Registry rejects refs with metric below
    /// `defaultMinAcceptableMetric`.
    public let evaluationMetric: Double

    /// L14 sovereign warrant authorizing this sub-model.
    /// Required (empty is invalid).
    public let approvedByWarrantRef: String

    /// Optional pointer to the sub-model this version supersedes.
    /// nil means "this is the first sub-model registered for this
    /// stratum".
    public let supersedesModelVersion: String?

    /// Operator-supplied free-text summary. Audit/forensics only.
    public let summary: String

    public init(
        schemaVersion: String =
            BASRiskCalibrationStratumSubModelRef
                .currentSchemaVersion,
        stratumKey: String,
        modelArtifactRef: String,
        modelVersion: String,
        trainedAt: Date = Date(),
        trainedFromProvenanceRef: String,
        evidenceRowCount: Int = 0,
        evaluationMetric: Double = 0,
        approvedByWarrantRef: String,
        supersedesModelVersion: String? = nil,
        summary: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.stratumKey = stratumKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelArtifactRef = modelArtifactRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelVersion = modelVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.trainedAt = trainedAt
        self.trainedFromProvenanceRef = trainedFromProvenanceRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.evidenceRowCount = max(0, evidenceRowCount)
        // Clamp evaluation metric to [0, 1]; NaN resolves to 0.
        self.evaluationMetric = Self.clamp01(evaluationMetric)
        self.approvedByWarrantRef = approvedByWarrantRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.supersedesModelVersion = supersedesModelVersion?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isWellFormed: Bool {
        !stratumKey.isEmpty
            && !modelArtifactRef.isEmpty
            && !modelVersion.isEmpty
            && !trainedFromProvenanceRef.isEmpty
            && !approvedByWarrantRef.isEmpty
            && evaluationMetric >= Self.defaultMinAcceptableMetric
    }

    fileprivate static func clamp01(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1.0, max(0.0, value))
    }
}

// MARK: - BASRiskCalibrationSubModelRegistryReplaceOutcome

public struct BASRiskCalibrationSubModelRegistryReplaceOutcome:
    Sendable, Equatable, Codable, Hashable
{
    public let stratumKey: String
    public let priorModelVersion: String?
    public let newModelVersion: String
    public let auditReasonCodes: [String]
    public let appliedAt: Date

    public init(
        stratumKey: String,
        priorModelVersion: String?,
        newModelVersion: String,
        auditReasonCodes: [String],
        appliedAt: Date = Date()
    ) {
        self.stratumKey = stratumKey
        self.priorModelVersion = priorModelVersion
        self.newModelVersion = newModelVersion
        self.auditReasonCodes = auditReasonCodes
        self.appliedAt = appliedAt
    }
}

// MARK: - BASRiskCalibrationSubModelRegistry

/// Per-stratum sub-model registry. Hosts construct one per L11
/// deployment alongside `BASRiskCalibrationGate`. Sub-models are
/// keyed by `stratumKey`; replacement uses monotonic-version +
/// supersedes-chain validation analogous to chapter 二百六十四.
public actor BASRiskCalibrationSubModelRegistry {

    public enum RegistryError: Error, Equatable, Sendable {
        case malformedRef(reason: String)
        case nonMonotonicModelVersion(
            current: String, proposed: String, stratumKey: String)
        case supersedesMismatch(
            current: String?, proposed: String,
            stratumKey: String)
    }

    private var refs: [String: BASRiskCalibrationStratumSubModelRef] =
        [:]

    public init() {}

    /// Currently-registered ref for the given stratum, or nil.
    public func ref(
        forStratumKey key: String
    ) -> BASRiskCalibrationStratumSubModelRef? {
        refs[key]
    }

    /// All registered stratum keys.
    public var registeredStratumKeys: Set<String> {
        Set(refs.keys)
    }

    /// Total registered sub-model count.
    public var count: Int { refs.count }

    /// Register or replace a sub-model ref. Validation:
    ///   1. `proposed.isWellFormed` must be true (warrant ref +
    ///      provenance ref + artifact ref non-empty + metric ≥
    ///      `defaultMinAcceptableMetric`).
    ///   2. If a prior ref exists, `proposed.modelVersion` must
    ///      be strictly greater (string compare).
    ///   3. If `proposed.supersedesModelVersion` is non-nil, must
    ///      match the prior ref's modelVersion. If nil, no prior
    ///      ref may exist (otherwise audit history is silently
    ///      dropped).
    @discardableResult
    public func register(
        _ proposed: BASRiskCalibrationStratumSubModelRef
    ) throws -> BASRiskCalibrationSubModelRegistryReplaceOutcome
    {
        guard proposed.isWellFormed else {
            throw RegistryError.malformedRef(
                reason: "isWellFormed=false; check stratumKey, " +
                    "modelArtifactRef, modelVersion, " +
                    "trainedFromProvenanceRef, " +
                    "approvedByWarrantRef, " +
                    "evaluationMetric ≥ defaultMinAcceptableMetric")
        }
        let key = proposed.stratumKey
        let existing = refs[key]
        // Monotonic version check.
        if let existing = existing {
            guard proposed.modelVersion > existing.modelVersion
            else {
                throw RegistryError.nonMonotonicModelVersion(
                    current: existing.modelVersion,
                    proposed: proposed.modelVersion,
                    stratumKey: key)
            }
        }
        // Supersedes-chain consistency.
        if let supersedes = proposed.supersedesModelVersion {
            guard supersedes == existing?.modelVersion else {
                throw RegistryError.supersedesMismatch(
                    current: existing?.modelVersion,
                    proposed: supersedes,
                    stratumKey: key)
            }
        } else {
            guard existing == nil else {
                throw RegistryError.supersedesMismatch(
                    current: existing?.modelVersion,
                    proposed: "(nil)",
                    stratumKey: key)
            }
        }
        // Audit reason codes (analogous to chapter 二百六十四 gate).
        var codes: [String] = [
            "submodel-registry:registered:" +
                "stratum-\(key):version-\(proposed.modelVersion)",
            "submodel-registry:metric:" +
                "\(proposed.evaluationMetric)",
            "submodel-registry:warrant:" +
                "\(proposed.approvedByWarrantRef)",
            "submodel-registry:provenance:" +
                "\(proposed.trainedFromProvenanceRef)",
            "submodel-registry:evidence-rows:" +
                "\(proposed.evidenceRowCount)"
        ]
        if let prior = existing?.modelVersion {
            codes.insert(
                "submodel-registry:supersedes:\(prior)",
                at: 1)
        }

        refs[key] = proposed

        return BASRiskCalibrationSubModelRegistryReplaceOutcome(
            stratumKey: key,
            priorModelVersion: existing?.modelVersion,
            newModelVersion: proposed.modelVersion,
            auditReasonCodes: codes)
    }
}
