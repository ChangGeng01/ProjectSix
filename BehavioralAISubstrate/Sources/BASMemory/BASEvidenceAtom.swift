// MARK: - BASEvidenceAtom
// ADR-020 Arc-2 — latent plumbing for evidence-resolving deliberation.
//
// The matchable unit of resolved evidence。 Where a decompose frame
// surfaces a typed UNKNOWN (e.g。 missingFacts: ["the budget"]),an
// evidence atom is a typed KNOWN that may resolve it:a normalized
// matching key + the human-readable fact text that backs it + its
// provenance + how strongly it resolves。
//
// ## Why a value type that mirrors BASMemoryAtom
//
// This atom is the evidence-plane sibling of `BASMemoryAtom`。 It
// adopts the SAME schema idiom — `BASSchemaVersioned` conformance,a
// `currentSchemaVersion` string constant,a `schemaVersion` field
// defaulting to that constant,+ a synthesized Codable (NO custom
// CodingKeys / decodeIfPresent — `BASMemoryAtom` uses synthesized
// Codable,so this does too,which keeps the wire format predictable
// + byte-stable)。
//
// ## Matching contract
//
// `evidenceKey` is the normalized structured key derived by
// `BASEvidenceMatcher.evidenceKey(contentType:content:)`。 The SAME
// function derives the key for an unknown-bucket value,so equal
// semantic content under the same content type yields an equal key —
// that EXACT key equality (never fuzzy / substring) is the
// anti-"theater" guarantee:a near-miss prose atom must NOT resolve a
// required key。
//
// DORMANT (ADR-020 Arc-2 Step 2a):nothing in production references
// this type yet。 Byte-equal-by-construction — no existing type is
// modified + nothing is wired into the runtime。

import Foundation
import BASRuntimeCore

/// A matchable unit of resolved evidence。 Mirrors the schema idiom of
/// `BASMemoryAtom` (BASSchemaVersioned + synthesized Codable)。
///
/// The `evidenceKey` is the normalized structured matching key (see
/// `BASEvidenceMatcher`);`content` is the human-readable resolved
/// fact text that backs it。 See ADR-020 Arc-2。
public struct BASEvidenceAtom: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identity of this evidence atom。
    public var evidenceID: String
    /// The normalized structured matching key (see
    /// `BASEvidenceMatcher.evidenceKey`)。 Equal semantic content under
    /// the same content type yields an equal key。
    public var evidenceKey: String
    /// Human-readable resolved fact text。
    public var content: String
    /// The category of evidence (mirrors the unknown-bucket kind)。
    public var contentType: BASEvidenceContentType
    /// Provenance — the turn that surfaced this evidence。
    public var sourceTurnID: String
    /// How strongly this resolves its key,∈ [0.0, 1.0]。
    public var confidence: Double
    /// When this evidence was recorded。
    public var recordedAt: Date

    public init(
        schemaVersion: String = BASEvidenceAtom.currentSchemaVersion,
        evidenceID: String,
        evidenceKey: String,
        content: String,
        contentType: BASEvidenceContentType,
        sourceTurnID: String,
        confidence: Double,
        recordedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceID = evidenceID
        self.evidenceKey = evidenceKey
        self.content = content
        self.contentType = contentType
        self.sourceTurnID = sourceTurnID
        self.confidence = confidence
        self.recordedAt = recordedAt
    }
}
