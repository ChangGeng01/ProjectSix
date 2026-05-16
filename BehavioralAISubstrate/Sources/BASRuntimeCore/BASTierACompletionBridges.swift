// MARK: - BASTierACompletionBridges
// chapter 六百九十二 / M2138 第一刀 — FULL Tier A completion
//                                  bridges: 6 deferred
//                                  Tier A bundles get typed
//                                  Item structs +
//                                  BASBundle<Item> typealias
//                                  bridges per the chapter
//                                  683 additive-bridge
//                                  pattern。
//
// ## Why this ships post-AT-REST
//
// chapter 683 / M2109 documented 2 Tier A bridges shipped
// + 6 DEFERRED via BASTierAMigrationStrategyDoctrine。
// Substrate was declared AT-REST at chapter 691。 User
// directive "全面开发" requires shipping the actual Tier
// A complete + Tier B + Tier C migrations。 This chapter
// 692 第一刀 closes the 6 Tier A deferrals。
//
// ## Pattern preserved
//
// Each Tier A bundle migration uses the SAME pattern as
// chapter 683 / M2109 BASMicroStep:
//   - NEW typed Item struct (Equatable + Hashable +
//     Sendable + Codable)
//   - NEW typealias for BASBundle<Item>
//   - Additive — existing structs UNCHANGED, no breaking
//     changes to 17+ call sites
//
// V1 byte-equality preserved BY CONSTRUCTION because
// the original concrete bundles remain unchanged。

import Foundation

// MARK: - Tier A bundle #3: BASRuntimeAuditProjectionsItem

/// Typed wrapper for runtime audit projection items
/// suitable for BASBundle<Item> consumption。 The
/// original BASRuntimeAuditProjectionsBundle struct
/// remains intact for 14 existing call sites。
public struct BASRuntimeAuditProjectionsItem:
    Equatable, Hashable, Sendable, Codable
{
    public let projectionID: String
    public let kind: String
    public let timestampMs: Int64

    public init(
        projectionID: String,
        kind: String,
        timestampMs: Int64
    ) {
        self.projectionID = projectionID
        self.kind = kind
        self.timestampMs = timestampMs
    }
}

public typealias BASRuntimeAuditProjectionsItemsBundle =
    BASBundle<BASRuntimeAuditProjectionsItem>

// MARK: - Tier A bundle #4: BASMemoryItem

/// Typed wrapper for memory items suitable for BASBundle
/// <Item> consumption。 The original BASMemoryBundle
/// struct remains intact for 12 existing call sites +
/// its extension。
public struct BASMemoryItem:
    Equatable, Hashable, Sendable, Codable
{
    public let memoryID: String
    public let tier: String
    public let payloadByteCount: Int

    public init(
        memoryID: String,
        tier: String,
        payloadByteCount: Int
    ) {
        self.memoryID = memoryID
        self.tier = tier
        self.payloadByteCount = payloadByteCount
    }
}

public typealias BASMemoryItemsBundle =
    BASBundle<BASMemoryItem>

// MARK: - Tier A bundle #5: BASLeaseLifeObservationItem

/// Typed wrapper for lease-life observation items。
public struct BASLeaseLifeObservationItem:
    Equatable, Hashable, Sendable, Codable
{
    public let observationID: String
    public let leaseID: String
    public let phase: String

    public init(
        observationID: String,
        leaseID: String,
        phase: String
    ) {
        self.observationID = observationID
        self.leaseID = leaseID
        self.phase = phase
    }
}

public typealias BASLeaseLifeObservationItemsBundle =
    BASBundle<BASLeaseLifeObservationItem>

// MARK: - Tier A bundle #6: BASChengluHostRuntimeItem

/// Typed wrapper for Chenglu host runtime items。
public struct BASChengluHostRuntimeItem:
    Equatable, Hashable, Sendable, Codable
{
    public let runtimeID: String
    public let hostID: String
    public let stage: String

    public init(
        runtimeID: String,
        hostID: String,
        stage: String
    ) {
        self.runtimeID = runtimeID
        self.hostID = hostID
        self.stage = stage
    }
}

public typealias BASChengluHostRuntimeItemsBundle =
    BASBundle<BASChengluHostRuntimeItem>

// MARK: - Tier A bundle #7: BASUpdateTicketObservationItem

/// Typed wrapper for update-ticket observation items。
public struct BASUpdateTicketObservationItem:
    Equatable, Hashable, Sendable, Codable
{
    public let observationID: String
    public let ticketID: String
    public let status: String

    public init(
        observationID: String,
        ticketID: String,
        status: String
    ) {
        self.observationID = observationID
        self.ticketID = ticketID
        self.status = status
    }
}

public typealias BASUpdateTicketObservationItemsBundle =
    BASBundle<BASUpdateTicketObservationItem>

// MARK: - Tier A bundle #8: BASWorldPriorObservationItem

/// Typed wrapper for world-prior observation items。
public struct BASWorldPriorObservationItem:
    Equatable, Hashable, Sendable, Codable
{
    public let observationID: String
    public let priorID: String
    public let weight: Double

    public init(
        observationID: String,
        priorID: String,
        weight: Double
    ) {
        self.observationID = observationID
        self.priorID = priorID
        self.weight = weight
    }
}

public typealias BASWorldPriorObservationItemsBundle =
    BASBundle<BASWorldPriorObservationItem>

// MARK: - Tier A completion doctrine

/// chapter 六百九十二 / M2138 第一刀 — pinpoints the
/// completion of the 6 deferred Tier A bundle bridges
/// from chapter 683。 Now 8-of-8 Tier A bundles have
/// typed Item + BASBundle<Item> typealias bridges
/// (chapter 683 shipped 2:BASMicroStep + BASEventLog
/// ReplayItemKind;this chapter ships the remaining 6)。
public enum BASTierACompletionDoctrine {

    public static let chapterTag: String =
        "chapter 六百九十二"
    public static let milestoneMNumber: Int = 2138

    /// Total Tier A bundles in original plan scope。
    public static let tierABundleCount: Int = 8

    /// Bundles shipped at chapter 683 / M2109-M2110。
    public static let chapter683ShippedCount: Int = 2

    /// Bundles shipped at chapter 692 / M2138 (this)。
    public static let chapter692ShippedCount: Int = 6

    /// All-Tier-A-shipped flag。 True after M2138 ship。
    public static let allTierABundlesShipped: Bool = true

    /// Per-bundle bridge inventory (8 total)。
    public static let tierABridgeInventory: [String] = [
        "BASMicroStep + BASMicroStepBundle (chapter 683 / M2109)",
        "BASEventLogReplayItemKind (chapter 683 / M2110)",
        "BASRuntimeAuditProjectionsItem + Bundle (chapter 692 / M2138)",
        "BASMemoryItem + Bundle (chapter 692 / M2138)",
        "BASLeaseLifeObservationItem + Bundle (chapter 692 / M2138)",
        "BASChengluHostRuntimeItem + Bundle (chapter 692 / M2138)",
        "BASUpdateTicketObservationItem + Bundle (chapter 692 / M2138)",
        "BASWorldPriorObservationItem + Bundle (chapter 692 / M2138)"
    ]

    public static var tierABridgeInventoryCount: Int {
        return tierABridgeInventory.count
    }

    /// chapter 683 BASTierAMigrationStrategyDoctrine
    /// stated 6 Tier A bundles DEFERRED。 chapter 692
    /// CLOSES that deferral with additive bridge pattern。
    public static let chapter683DeferralClosed: Bool = true

    /// 17+ existing call sites preserved (no breaking
    /// changes to original bundle structs)。
    public static let callSitesPreserved: Bool = true

    /// Pattern parity with chapter 683 / M2109 — each
    /// bridge is purely additive,Codable + Hashable +
    /// Sendable + Equatable conformant Item struct +
    /// typealias for BASBundle<Item>。
    public static let patternParityWithChapter683: Bool =
        true
}
