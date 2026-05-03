// SPDX-License-Identifier: Apache-2.0
// M462 (chapter 一百二十一) — L8 SealedMemory typed schema per
// Cthulhu Spec V1 §5.8.
//
// ## Why this exists
//
// Phase 1 strict audit of 14-layer Cthulhu coverage revealed
// L8 SealedMemory as a distinct schema gap. `BASSealEnvelope`
// (chapter 八十七 M287) is a broader sealing protocol that
// covers any sealed artifact (memory atoms, candidates,
// snapshots, etc.). Cthulhu Spec V1 §5.8 specifies
// `SealedMemory` as a NARROWER L8-specific schema with 4
// fields binding to a memory ref:
//
//   - memory_ref
//   - seal_class
//   - disclosure_mode
//   - reentry_conditions[]
//
// The two are complementary:
//
//   - `BASSealEnvelope` — generic seal envelope (what's sealed
//     + access policy + audit-trail + lineage cuts)
//   - `BASSealedMemory` — L8-specific binding (how a memory
//     atom is sealed + reveal mode + reentry path)
//
// Hosts may construct a `BASSealedMemory` and store it via a
// `BASSealEnvelope` for broader audit ledger semantics. This
// chapter ships only the typed L8-specific schema; future M-
// chapter wires production consumption.
//
// ## Doctrine pins
//
// - **Distinct from BASSealEnvelope**: SealedMemory is L8
//   memory-atom binding; SealEnvelope is broader.
// - **Stable kebab-case raw values**: `BASSealClass` and
//   `BASSealDisclosureMode` enums use stable identifiers.
// - **Schema-only ship**: schema + governance entry; production
//   wiring is future M-chapter when L8 query path gates on
//   these fields.
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore`.

import Foundation
import BASRuntimeCore

// MARK: - BASSealClass (Cthulhu Spec V1 §5.8 — 5 thermal classes)

/// L8 seal class per Cthulhu Spec V1 §5.8 — maps to the 5
/// thermal layers (`BASMemoryTemperatureLayer` from chapter
/// 一百十五). The 4 sealable classes (excludes `tide-surface-
/// memory` since unsealed surface memory needs no sealing
/// envelope).
public enum BASSealClass:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case midLayer = "mid-layer"
    case deepWell = "deep-well"
    case abyssal = "abyssal"
    case oldSeal = "old-seal"
}

// MARK: - BASSealDisclosureMode

/// Disclosure mode controlling how a sealed memory may be
/// revealed. Per Cthulhu Spec V1 §5.8: "高敏记忆可以保留,
/// 但默认不召回." 4 stable kebab-case modes.
public enum BASSealDisclosureMode:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Default — memory exists in storage but never surfaces
    /// in retrieval queries. Audit-walker can still see the
    /// seal record via L14 query.
    case never = "never"
    /// Memory may surface only with explicit host recall (e.g.
    /// host-typed key matching a registered ritual).
    case hostExplicitOnly = "host-explicit-only"
    /// Memory may surface only with sovereign warrant (L14
    /// signed warrant required).
    case sovereignWarrant = "sovereign-warrant"
    /// Memory has been formally revealed and re-entered the
    /// normal retrieval pool.
    case revealed = "revealed"
}

// MARK: - BASSealedMemory

/// L8 SealedMemory typed binding per Cthulhu Spec V1 §5.8.
///
/// 4 fields verbatim from the whitepaper:
///
///  - `memoryRef` — stable reference to the L8 memory atom
///    being sealed
///  - `sealClass` — typed class (one of 4 sealable layers)
///  - `disclosureMode` — typed disclosure rule
///  - `reentryConditions[]` — reason codes that, when ALL
///    fired, allow disclosure to advance toward `.revealed`
public struct BASSealedMemory:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this sealed-memory binding.
    public var sealedMemoryID: String
    /// Stable reference to the L8 memory atom being sealed.
    public var memoryRef: String
    /// Seal class (which thermal layer the memory occupies
    /// when sealed).
    public var sealClass: BASSealClass
    /// Disclosure mode controlling reveal path.
    public var disclosureMode: BASSealDisclosureMode
    /// Reason codes that must ALL be satisfied before the
    /// disclosure mode can advance toward `.revealed`. Trimmed,
    /// empties filtered.
    public var reentryConditions: [String]

    public init(
        schemaVersion: String =
            BASSealedMemory.currentSchemaVersion,
        sealedMemoryID: String,
        memoryRef: String,
        sealClass: BASSealClass,
        disclosureMode: BASSealDisclosureMode,
        reentryConditions: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.sealedMemoryID = sealedMemoryID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryRef = memoryRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sealClass = sealClass
        self.disclosureMode = disclosureMode
        self.reentryConditions = reentryConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
