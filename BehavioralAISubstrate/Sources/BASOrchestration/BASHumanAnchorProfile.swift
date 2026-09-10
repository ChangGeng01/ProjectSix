// SPDX-License-Identifier: Apache-2.0
// M460 (chapter 一百二十一) — L5 HumanAnchorProfile per Cthulhu
// Spec V1 §5.5 + Abyssal VINF §4.5.
//
// ## Why this exists
//
// Phase 1 strict audit of 14-layer Cthulhu coverage revealed
// L5 HumanAnchorProfile as a distinct schema gap: BAS already
// has `BASHumanAnchorSignal` (M304 chapter 八十九, per-turn
// observation with risk axes) but Cthulhu Spec V1 §5.5
// specifies a SEPARATE `HumanAnchorProfile` (host-level
// configuration with 4 invariant arrays). The two are
// complementary:
//
//   - `BASHumanAnchorSignal` — per-turn READING (this turn's
//     surface-erosion risks)
//   - `BASHumanAnchorProfile` — host-level CONFIGURATION (the
//     host's standing invariants the signal must respect)
//
// ## Doctrine pins
//
// - **Schema-only ship**: per chapter 一百十八 lesson, schema
//   alone is not integration. This chapter ships schema +
//   governance entry; future M-chapter wires production
//   consumption when the host configuration surface gains a
//   real source.
// - **Stable raw-value identifiers**: each field is `[String]`
//   where elements are stable reason codes / invariant tokens
//   the host has agreed to.
// - **Trim-on-init**: per chapter 一百十三/一百十四 anti-magic-
//   string doctrine, all string fields trimmed of whitespace +
//   empties filtered.
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore`.

import Foundation
import BASRuntimeCore

// MARK: - BASHumanAnchorProfile

/// L5 host-level human anchor configuration per Cthulhu Spec V1
/// §5.5. The 4 array fields define what the substrate MUST
/// honor when synthesizing per-turn surfaces. Producer is the
/// host's configuration system; consumer is the L11 / L12 /
/// L14 surface synthesis layers.
///
/// Field doctrine (Cthulhu Spec V1 §5.5 verbatim):
///
///  - `dignityInvariants[]` — host invariants the substrate
///    cannot violate (e.g. `"no-shame"`, `"no-condescension"`,
///    `"no-urgency-coercion"`).
///  - `noExploitationGuards[]` — explicit guard conditions
///    against exploitation (e.g. `"no-vulnerability-mining"`,
///    `"no-emotional-leverage"`).
///  - `sensitivityWindows[]` — time / context windows when the
///    host is more sensitive (e.g. `"grief-window-30d"`,
///    `"post-incident-1w"`). Format is host-defined.
///  - `anchoringRituals[]` — references to grounding rituals
///    the host has registered (e.g. `"morning-3-breath"`,
///    `"evening-summary"`).
public struct BASHumanAnchorProfile:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for the host this profile binds to.
    public var profileID: String
    /// Stable reference to the parent host profile snapshot
    /// (typically `BASHostProfile.hostID`).
    public var hostRef: String
    /// Host invariants the substrate MUST honor. Trimmed,
    /// empties filtered.
    public var dignityInvariants: [String]
    /// Explicit guard conditions against exploitation patterns.
    /// Trimmed, empties filtered.
    public var noExploitationGuards: [String]
    /// Time / context windows when the host is more sensitive.
    /// Format is host-defined; substrate treats as opaque
    /// reason-code strings.
    public var sensitivityWindows: [String]
    /// Anchoring ritual references registered by the host.
    /// Substrate may surface them; never invent new ones.
    public var anchoringRituals: [String]

    public init(
        schemaVersion: String =
            BASHumanAnchorProfile.currentSchemaVersion,
        profileID: String,
        hostRef: String,
        dignityInvariants: [String],
        noExploitationGuards: [String],
        sensitivityWindows: [String],
        anchoringRituals: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostRef = hostRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.dignityInvariants = dignityInvariants
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.noExploitationGuards = noExploitationGuards
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.sensitivityWindows = sensitivityWindows
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.anchoringRituals = anchoringRituals
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
