// MARK: - BASEvidenceContentType
// ADR-020 Arc-2 — latent plumbing for evidence-resolving deliberation.
//
// The category of a piece of resolved evidence。 These four cases
// MIRROR the four typed unknown-buckets a decompose frame surfaces
// (`BASUnknownSet` in BASOrchestration):
//   - `fact`        ↔ missingFacts
//   - `constraint`  ↔ missingConstraints
//   - `role`        ↔ missingRoles
//   - `permission`  ↔ unresolvedPermissions
//
// This enum lives in BASMemory (Foundation + BASRuntimeCore only) so
// the matcher + ledger stay string-based + free of orchestration
// types。 The contentType is one half of an evidence-matching key
// (see `BASEvidenceMatcher.evidenceKey`),which is why equal semantic
// content under DIFFERENT content types must NOT collide。
//
// DORMANT (ADR-020 Arc-2 Step 2a):nothing in production references
// this type yet。 Byte-equal-by-construction — no existing type is
// modified + nothing is wired into the runtime。

import Foundation

/// The category of a resolved piece of evidence。 Raw values are
/// stable + lowercased so they can be embedded directly in an
/// evidence-matching key + survive Codable round-trips byte-for-byte。
///
/// Mirrors the four typed unknown-buckets of a decompose frame
/// (missingFacts / missingConstraints / missingRoles /
/// unresolvedPermissions) — see ADR-020 Arc-2。
public enum BASEvidenceContentType: String, Codable, CaseIterable, Sendable {
    /// A resolved fact (↔ `BASUnknownSet.missingFacts`)。
    case fact
    /// A resolved constraint (↔ `BASUnknownSet.missingConstraints`)。
    case constraint
    /// A resolved role / actor (↔ `BASUnknownSet.missingRoles`)。
    case role
    /// A resolved permission (↔ `BASUnknownSet.unresolvedPermissions`)。
    case permission
}
