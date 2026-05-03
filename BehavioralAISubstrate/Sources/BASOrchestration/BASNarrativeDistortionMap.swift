// SPDX-License-Identifier: Apache-2.0
// M461 (chapter 一百二十一) — L7 NarrativeDistortionMap aggregate
// per Cthulhu Spec V1 §5.7.
//
// ## Why this exists
//
// Phase 1 strict audit of 14-layer Cthulhu coverage revealed
// L7 NarrativeDistortionMap as a distinct schema gap.
// `BASNarrativeDistortion` (M316 chapter 八十九) is per-subject
// observation. Cthulhu Spec V1 §5.7 lists `NarrativeDistortion
// Map` as a distinct typed concept — an aggregate of
// distortion observations across multiple subjects within a
// single turn (e.g. distortion-per-candidate / distortion-per-
// memory / distortion-per-host-relation).
//
// The distinction matters for L7 mirror-blade audit: a single
// distortion record is "this conversation has X" but a Map is
// "across this turn's observed subjects, here's the distribution
// of distortion shapes" — useful for "which subject is the
// dominant source of distortion?" queries.
//
// ## Doctrine pins
//
// - **Schema-only ship**: schema + governance entry. Production
//   consumption is future M-chapter when L7 audit-walker
//   queries demand the aggregate shape.
// - **Map type**: stored as `[String: BASNarrativeDistortion]`
//   keyed by subject ref; deterministic ordering preserved by
//   the `subjectRefs` array.
// - **Anti-drift**: `subjectRefs` and `distortionsBySubject`
//   maintain parallel-array invariant — every subject has a
//   distortion entry.
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore`. Same-module
// reference to `BASNarrativeDistortion` (defined in
// `BASAbyssalProtocol.swift`).

import Foundation
import BASRuntimeCore

// MARK: - BASNarrativeDistortionMap

/// L7 mirror-blade aggregate readout per Cthulhu Spec V1 §5.7.
///
/// Carries per-subject distortion observations collected within
/// a single turn. Producers populate this when L7 mirror blade
/// detects distortion across multiple distinct subjects (e.g.
/// candidate paths, memory atoms, host-relation references).
public struct BASNarrativeDistortionMap:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this map (e.g.
    /// `"distortion-map-<turnID>"`).
    public var mapID: String
    /// Ordered list of subject refs this map covers. Parallel
    /// to `distortionsBySubject` keys.
    public var subjectRefs: [String]
    /// Per-subject distortion observations. Keys must match
    /// `subjectRefs` (init enforces parallel-array invariant).
    public var distortionsBySubject: [String: BASNarrativeDistortion]
    /// Optional dominant subject ref (the subject with the
    /// highest aggregate distortion). Producer-computed; nil
    /// when the map is empty or no subject is clearly dominant.
    public var dominantSubjectRef: String?

    public init(
        schemaVersion: String =
            BASNarrativeDistortionMap.currentSchemaVersion,
        mapID: String,
        subjectRefs: [String],
        distortionsBySubject: [String: BASNarrativeDistortion],
        dominantSubjectRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mapID = mapID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Parallel-array invariant: subjectRefs and
        // distortionsBySubject keys must match. Filter
        // subjectRefs to only those with corresponding
        // distortions; trim + drop empties.
        let trimmedRefs = subjectRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let validKeys = Set(distortionsBySubject.keys)
        self.subjectRefs = trimmedRefs.filter {
            validKeys.contains($0)
        }
        self.distortionsBySubject = distortionsBySubject
        if let dom = dominantSubjectRef
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }),
           !dom.isEmpty,
           validKeys.contains(dom)
        {
            self.dominantSubjectRef = dom
        } else {
            self.dominantSubjectRef = nil
        }
    }

    /// Aggregate maximum across all subjects' max-axis values.
    /// Returns 0 when map is empty.
    public var aggregateMaxDistortion: Double {
        var maxValue: Double = 0
        for distortion in distortionsBySubject.values {
            let candidates = [
                distortion.realityDenial,
                distortion.historyRewrite,
                distortion.forcedClosure,
                distortion.roleInversion,
                distortion.urgencyMask,
            ]
            if let local = candidates.max(), local > maxValue {
                maxValue = local
            }
        }
        return maxValue
    }
}
