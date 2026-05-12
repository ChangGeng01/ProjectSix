// MARK: - BASAuditObservationProjectionsObservationBundlesBlock
// chapter 五百十四 / M1433 — 3rd typed input block for
//                            audit projections
//
// Aggregates the 11 cognitive-layer observation bundles
// that feed `BASAuditObservationProjections`。 Sibling of
// the M1421 Kunlun inputs block (18 fields) + M1423
// Cthulhu inputs block (8 fields)。
//
// ## Why this exists
//
// `BASAuditObservationProjections` has 56+ named fields。
// Chapters 511+513 grouped 26 of them into 2 typed input
// blocks (Kunlun + Cthulhu)。 Chapter 514 closes the
// observation-bundles cluster:
//
//   - presenceObservationBundle (L4)
//   - decompositionObservationBundle (L6/L7)
//   - softHandObservationBundle (L11/L12)
//   - leaseLifeObservationBundle (L8/L9)
//   - hostConstitutionObservationBundle (L13)
//   - thoughtFoldObservationBundle (L7/L8)
//   - neuralOrganObservationBundle (L2/L3)
//   - hippocampalMemoryObservationBundle (L8)
//   - worldPriorObservationBundle (L7)
//   - riskObservationBundle (L11)
//   - updateTicketObservationBundle (L13)
//
// 11 cognitive observation bundles, each optional。 The
// block carries all 11 as a single typed surface so call
// sites can pass `observationBundles:` instead of naming
// each one individually。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 11
//     cognitive bundles accessed via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable + Codable
//   - chapter 四百二十九:typed-surface count 59 → 60
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1432 → M1433

import Foundation
import BASMemory
import BASOrchestration
import BASRuntimeCore
import BASWorldPrior

/// Typed-surface block packaging the 11 cognitive-layer
/// observation bundles that feed audit projections。 All
/// fields optional — hosts populating partial coverage
/// (e.g. skipping risk-observation bundle on a non-risky
/// turn) can leave fields nil。
public struct BASAuditObservationProjectionsObservationBundlesBlock:
    Equatable, Sendable
{

    // MARK: - 11 cognitive observation bundles

    /// L4 presence-observation bundle (chapter 一百).
    public let presence: BASPresenceObservationBundle?

    /// L6/L7 decomposition-observation bundle (chapter
    /// 一百).
    public let decomposition:
        BASDecompositionObservationBundle?

    /// L11/L12 soft-hand observation bundle (chapter
    /// 一百).
    public let softHand: BASSoftHandObservationBundle?

    /// L8/L9 lease-life observation bundle (chapter
    /// 一百二).
    public let leaseLife: BASLeaseLifeObservationBundle?

    /// L13 host-constitution observation bundle (chapter
    /// 一百四).
    public let hostConstitution:
        BASHostConstitutionObservationBundle?

    /// L7/L8 thought-fold observation bundle (chapter
    /// 一百四).
    public let thoughtFold:
        BASThoughtFoldObservationBundle?

    /// L2/L3 neural-organ observation bundle (chapter
    /// 一百五).
    public let neuralOrgan:
        BASNeuralOrganObservationBundle?

    /// L8 hippocampal-memory observation bundle
    /// (chapter 一百五).
    public let hippocampalMemory:
        BASHippocampalMemoryObservationBundle?

    /// L7 world-prior observation bundle (chapter 一百
    /// 五).
    public let worldPrior:
        BASWorldPriorObservationBundle?

    /// L11 risk-observation bundle (chapter 一百五).
    public let risk: BASRiskObservationBundle?

    /// L13 update-ticket observation bundle (chapter
    /// 一百五).
    public let updateTicket:
        BASUpdateTicketObservationBundle?

    // MARK: - Construction

    public init(
        presence:
            BASPresenceObservationBundle? = nil,
        decomposition:
            BASDecompositionObservationBundle? = nil,
        softHand:
            BASSoftHandObservationBundle? = nil,
        leaseLife:
            BASLeaseLifeObservationBundle? = nil,
        hostConstitution:
            BASHostConstitutionObservationBundle? = nil,
        thoughtFold:
            BASThoughtFoldObservationBundle? = nil,
        neuralOrgan:
            BASNeuralOrganObservationBundle? = nil,
        hippocampalMemory:
            BASHippocampalMemoryObservationBundle? = nil,
        worldPrior:
            BASWorldPriorObservationBundle? = nil,
        risk:
            BASRiskObservationBundle? = nil,
        updateTicket:
            BASUpdateTicketObservationBundle? = nil
    ) {
        self.presence = presence
        self.decomposition = decomposition
        self.softHand = softHand
        self.leaseLife = leaseLife
        self.hostConstitution = hostConstitution
        self.thoughtFold = thoughtFold
        self.neuralOrgan = neuralOrgan
        self.hippocampalMemory = hippocampalMemory
        self.worldPrior = worldPrior
        self.risk = risk
        self.updateTicket = updateTicket
    }

    // MARK: - Coverage queries

    /// Count of bundles that are non-nil。 0-11。 Useful
    /// for "how many of the 11 cognitive bundles did we
    /// observe?" audits。
    public var populatedBundleCount: Int {
        var n = 0
        if presence != nil { n += 1 }
        if decomposition != nil { n += 1 }
        if softHand != nil { n += 1 }
        if leaseLife != nil { n += 1 }
        if hostConstitution != nil { n += 1 }
        if thoughtFold != nil { n += 1 }
        if neuralOrgan != nil { n += 1 }
        if hippocampalMemory != nil { n += 1 }
        if worldPrior != nil { n += 1 }
        if risk != nil { n += 1 }
        if updateTicket != nil { n += 1 }
        return n
    }

    /// `true` when all 11 bundles are populated。
    public var hasFullObservationCoverage: Bool {
        populatedBundleCount == 11
    }

    /// `true` when ZERO bundles populated — host
    /// emitted projection without any observation
    /// data (cold path)。
    public var hasNoObservationCoverage: Bool {
        populatedBundleCount == 0
    }

    /// All-nil empty singleton。 Useful for tests +
    /// hosts emitting minimal projections。
    public static let empty =
        BASAuditObservationProjectionsObservationBundlesBlock()

    /// Field count invariant — 11 cognitive bundles。
    /// If a future audit chapter adds a 12th bundle to
    /// the audit projections surface,this constant
    /// moves AND `BASAuditObservationProjections` gains
    /// a matching field,or audit emission silently
    /// loses coverage。 PROOF test pins this。
    public static let observationBundleCount: Int = 11
}
