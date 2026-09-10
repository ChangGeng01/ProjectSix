// ch1049 / v1.0 L10 (三我庭) — RegretProfile (悔意剖面) + SacrificeMap (牺牲地图).
//
// The gap audit found L10 bearability has MergedChoice / AgencyReservation / BASTradeoffLedger, but:
//   - RegretProfile (悔意剖面) was MISSING — no regret-modeling type (only "regret cost" prose).
//   - SacrificeMap (牺牲地图) was PARTIAL — only `BASTradeoffLedger.sacrifices: [String]`, an
//     unattributed flat list, not a structured per-stakeholder map.
//
// These two additive value types complete the L10 squeeze objects (§4: "悔意剖面 / 牺牲地图"). They are
// standalone (opt-in / byte-equal-off, ADR-014): the existing `BASTradeoffLedger.sacrifices` field is
// PRESERVED untouched (it has live readers), and `BASSacrificeMap.fromFlat(_:)` bridges it losslessly
// into the structured form so a host/tribunal gains a per-stakeholder view without any breaking change.

import Foundation
import BASRuntimeCore

// MARK: - RegretProfile (悔意剖面)

/// One anticipated-regret dimension for a choice.
public struct BASRegretEntry: Sendable, Codable, Equatable, Hashable {
    public let dimension: String     // what could be regretted (e.g. "irreversible_disclosure")
    public let likelihood: Double    // [0,1]
    public let severity: Double      // [0,1]
    public let reversible: Bool      // can the regretted outcome be undone?
    public let mitigation: String    // how to reduce it ("" if none)

    public init(dimension: String, likelihood: Double, severity: Double,
                reversible: Bool, mitigation: String = "") {
        self.dimension = dimension
        self.likelihood = BASRegretEntry.clamp(likelihood)
        self.severity = BASRegretEntry.clamp(severity)
        self.reversible = reversible
        self.mitigation = mitigation
    }

    private static func clamp(_ x: Double) -> Double { Swift.min(1.0, Swift.max(0.0, x)) }

    /// Expected regret = likelihood × severity.
    public var weight: Double { likelihood * severity }
}

/// The regret剖面 for one merged choice — the L10 view of "what, and how badly, might be regretted."
public struct BASRegretProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public var schemaVersion: String
    public var choiceRef: String
    public var entries: [BASRegretEntry]

    public init(schemaVersion: String = BASRegretProfile.currentSchemaVersion,
                choiceRef: String, entries: [BASRegretEntry] = []) {
        self.schemaVersion = schemaVersion
        self.choiceRef = choiceRef
        self.entries = entries
    }

    public var totalWeight: Double { entries.reduce(0) { $0 + $1.weight } }
    public var peak: BASRegretEntry? { entries.max { $0.weight < $1.weight } }
    /// Any non-reversible regret dimension that carries weight — a hard caution for L10/L11.
    public var hasIrreversibleRegret: Bool { entries.contains { !$0.reversible && $0.weight > 0 } }

    public static func empty(choiceRef: String) -> BASRegretProfile {
        BASRegretProfile(choiceRef: choiceRef)
    }
}

// MARK: - SacrificeMap (牺牲地图)

/// One sacrifice borne by a specific stakeholder.
public struct BASSacrificeEntry: Sendable, Codable, Equatable, Hashable {
    public let stakeholder: String   // who/what bears the cost
    public let what: String          // what is sacrificed
    public let magnitude: Double     // [0,1]
    public let reversible: Bool

    public init(stakeholder: String, what: String, magnitude: Double, reversible: Bool) {
        self.stakeholder = stakeholder
        self.what = what
        self.magnitude = Swift.min(1.0, Swift.max(0.0, magnitude))
        self.reversible = reversible
    }
}

/// The structured 牺牲地图 for one choice — supersedes the flat `BASTradeoffLedger.sacrifices: [String]`
/// (which is preserved). Attributes each sacrifice to a stakeholder + magnitude + reversibility.
public struct BASSacrificeMap: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public var schemaVersion: String
    public var choiceRef: String
    public var entries: [BASSacrificeEntry]

    public init(schemaVersion: String = BASSacrificeMap.currentSchemaVersion,
                choiceRef: String, entries: [BASSacrificeEntry] = []) {
        self.schemaVersion = schemaVersion
        self.choiceRef = choiceRef
        self.entries = entries
    }

    public var stakeholders: [String] { Array(Set(entries.map { $0.stakeholder })).sorted() }
    public func entries(forStakeholder s: String) -> [BASSacrificeEntry] {
        entries.filter { $0.stakeholder == s }
    }
    public var totalMagnitude: Double { entries.reduce(0) { $0 + $1.magnitude } }
    public var hasIrreversibleSacrifice: Bool {
        entries.contains { !$0.reversible && $0.magnitude > 0 }
    }

    /// Lossless bridge from the legacy flat `BASTradeoffLedger.sacrifices: [String]`: each string
    /// becomes an unattributed, magnitude-0, reversible entry. The flat field stays the source of
    /// record (byte-equality); this gives a structured view alongside it.
    public static func fromFlat(_ sacrifices: [String], choiceRef: String) -> BASSacrificeMap {
        BASSacrificeMap(choiceRef: choiceRef, entries: sacrifices.map {
            BASSacrificeEntry(stakeholder: "unspecified", what: $0, magnitude: 0.0, reversible: true)
        })
    }
}
