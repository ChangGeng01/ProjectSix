// MARK: - BASLayerMLHeadRegistry — chapter 三百一〇 / M797
//
// Phase Delta 第一刀:typed slot registry that maps
// `BASMotherboardLayer14` → 0..N `BASLayerMLHead` instances。
// Phase Beta foundation (chapter 三百, M787) shipped the
// `BASLayerMLHead` protocol;Phase Delta starts wiring 14-layer
// CoreML mesh by giving hosts a typed slot registry。
//
// chapter 一百七十七 vision § "Core ML mesh × 14 层" 描述每 layer
// 0..N heads。Phase Delta 的目标是把那个 mapping 落到 typed
// registry,让 future chapters (三百一一+) ship real mlpackage
// adapters into specific layer slots without each one having to
// invent its own registration mechanism。
//
// ## 这一刀 ship 什么
//
// 3 个 typed primitives:
//
//   - `BASLayerMLHeadSlot` (BASSchemaVersioned 1.0.0) — typed
//     description of one slot binding: layerID + headID + kind +
//     priority(cascading order)+ enabled flag
//   - `BASLayerMLHeadRegistry` actor — thread-safe registry
//     mapping layer → ordered list of slots。Hosts register heads
//     at startup;layer actors call `slot(forLayer:)` to fetch
//     their cascading head set
//   - `BASLayerMLHeadRegistrationError` — typed Error: duplicate
//     headID / layer slot conflict / disabled head
//
// ## Why a registry (not direct property on actor)
//
// `BASLayerActor` protocol from chapter 二百九十九 already has an
// implicit "future mlHeadSlot field" hint。Direct property would:
// 1) Tie head registration to actor construction time (rigid)
// 2) Allow only ONE head per layer (chapter 一百七十七 vision wants
//    cascading multiple heads per layer)
// 3) Couple host startup to layer actor construction order
//
// Registry pattern lets hosts register 50 heads across 14 layers
// at startup,then each layer actor pulls its set lazily。Plays
// nicely with future chapters that ship per-mlpackage adapters
// (each chapter adds 1-2 entries to the registry)。
//
// **0 behavior change**:purely additive new file。No layer
// actor currently consumes the registry。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — registry is config plane
//   - 红线 7 watcher hint only — heads are hint, never gate
//   - chapter 二百一一 single-source-of-truth: ONE registry per
//     runtime, ALL slot bindings owned by it
//   - chapter 一百八十五 anti-magic-number: priority is Int
//     (caller assigns;lower = higher priority); enabled flag
//     typed
//   - chapter 一百三 schema-version: 1.0.0 invariant
//   - chapter 一百三十 BASLearnabilityClass: head registry is
//     observability metadata, semi-learnable
//   - chapter 二百九十九 BASLayerActor protocol: registry
//     consumes BASMotherboardLayer14 + BASLayerMLHeadKind from
//     foundation cuts
//   - chapter 三百 BASLayerMLHead protocol: registry stores
//     `any BASLayerMLHead` instances

import Foundation

// MARK: - Slot binding record

/// Typed description of one ML head slot binding。Pairs a head's
/// metadata with its layer assignment + cascading priority。
///
/// Field semantics:
///   - `layerID` — which layer this head serves
///   - `headID` — stable head identifier (matches
///     `BASLayerMLHead.headID`)
///   - `kind` — typed slot classifier (chapter 三百
///     `BASLayerMLHeadKind` 5-case enum)
///   - `priority` — cascading order;lower priority = tried
///     first by `BASLayerActor.process`。Caller assigns
///     (typically: rules=0, coreml=10, mlx=20, AFM=30,
///     external=40 to match chapter 一百七十七 cascading inference
///     stack)
///   - `enabled` — soft-disable flag for runtime gating without
///     unregistering the slot
public struct BASLayerMLHeadSlot:
    BASSchemaVersioned,
    Sendable,
    Equatable,
    Hashable,
    Codable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var headID: String
    public var kind: BASLayerMLHeadKind
    public var priority: Int
    public var enabled: Bool

    public init(
        schemaVersion: String
            = BASLayerMLHeadSlot.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        headID: String,
        kind: BASLayerMLHeadKind,
        priority: Int,
        enabled: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.headID = headID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.priority = priority
        self.enabled = enabled
    }
}

// MARK: - Registration error taxonomy

/// 3-case typed error for registry operations。
public enum BASLayerMLHeadRegistrationError:
    Error, Sendable, Equatable
{
    /// Tried to register a head with `headID` already present in
    /// registry. Caller must unregister first.
    case duplicateHeadID(String)

    /// Caller queried registry by headID + the head is currently
    /// flagged disabled. Registry honors `.enabled` flag.
    case headDisabled(headID: String)

    /// Caller asked for a head by ID that isn't in registry.
    case unknownHead(headID: String)
}

// MARK: - Registry actor

/// Actor-isolated typed registry mapping `BASMotherboardLayer14`
/// → ordered list of `BASLayerMLHead` instances。
///
/// Concurrency model:
///   - Single-writer (host startup phase)
///   - Multi-reader (layer actors during turn execution)
///   - Actor isolation guarantees no torn reads/writes
///
/// Host startup pattern:
///
///     let registry = BASLayerMLHeadRegistry()
///     try await registry.register(
///         head: chenglu PreflightAdapter,
///         layerID: .l4,
///         priority: 10)
///     try await registry.register(...) // 50+ heads across 14 layers
///
/// Layer actor consumption pattern (chapter 三百一一+):
///
///     actor MyL4Actor: BASLayerActor {
///         let registry: BASLayerMLHeadRegistry
///         func process(input:) async throws -> Output {
///             let heads = await registry.heads(forLayer: .l4)
///             // cascading inference: try each head in priority
///             // order; fall through if confidence < floor
///         }
///     }
public actor BASLayerMLHeadRegistry {

    // Stored: 14 ordered lists keyed by layer。Slot order matches
    // priority (lower priority = earlier index).
    private var slotsByLayer: [BASMotherboardLayer14:
        [BASLayerMLHeadSlot]] = [:]

    // Side-table: headID → instance. Lets us return the actual
    // `any BASLayerMLHead` when caller asks by ID.
    private var headsByID: [String: any BASLayerMLHead] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a head into the layer's slot list at given priority。
    /// Throws `.duplicateHeadID` if headID already exists.
    public func register(
        head: any BASLayerMLHead,
        layerID: BASMotherboardLayer14,
        priority: Int,
        enabled: Bool = true
    ) throws {
        if headsByID[head.headID] != nil {
            throw BASLayerMLHeadRegistrationError
                .duplicateHeadID(head.headID)
        }
        let slot = BASLayerMLHeadSlot(
            layerID: layerID,
            headID: head.headID,
            kind: head.kind,
            priority: priority,
            enabled: enabled)
        var list = slotsByLayer[layerID] ?? []
        list.append(slot)
        list.sort { $0.priority < $1.priority }
        slotsByLayer[layerID] = list
        headsByID[head.headID] = head
    }

    /// Unregister a head by ID。Returns true if removed, false if
    /// not present.
    @discardableResult
    public func unregister(headID: String) -> Bool {
        guard headsByID.removeValue(forKey: headID) != nil
        else { return false }
        for (layer, list) in slotsByLayer {
            slotsByLayer[layer] = list.filter {
                $0.headID != headID
            }
        }
        return true
    }

    /// Toggle enabled state without removing from registry。
    /// Throws `.unknownHead` if headID not present.
    public func setEnabled(
        headID: String, enabled: Bool
    ) throws {
        guard headsByID[headID] != nil else {
            throw BASLayerMLHeadRegistrationError.unknownHead(
                headID: headID)
        }
        for (layer, list) in slotsByLayer {
            slotsByLayer[layer] = list.map { slot in
                guard slot.headID == headID else { return slot }
                var updated = slot
                updated.enabled = enabled
                return updated
            }
        }
    }

    // MARK: - Query

    /// Number of registered heads across all layers。
    public var totalHeadCount: Int {
        headsByID.count
    }

    /// Slots for a specific layer, in priority order, INCLUDING
    /// disabled slots。Layer actors that want to filter on
    /// enabled call `enabledSlots(forLayer:)`.
    public func slots(
        forLayer layerID: BASMotherboardLayer14
    ) -> [BASLayerMLHeadSlot] {
        slotsByLayer[layerID] ?? []
    }

    /// Slots for a specific layer where `enabled == true`, in
    /// priority order。This is the canonical query for cascading
    /// inference loops.
    public func enabledSlots(
        forLayer layerID: BASMotherboardLayer14
    ) -> [BASLayerMLHeadSlot] {
        (slotsByLayer[layerID] ?? []).filter { $0.enabled }
    }

    /// `(BASLayerMLHead, priority)` pairs for a specific layer,
    /// in priority order, only enabled。Layer actors call this
    /// during cascading inference to walk the head set.
    public func enabledHeads(
        forLayer layerID: BASMotherboardLayer14
    ) -> [(head: any BASLayerMLHead, slot: BASLayerMLHeadSlot)] {
        let slots = enabledSlots(forLayer: layerID)
        return slots.compactMap { slot in
            guard let head = headsByID[slot.headID] else {
                return nil
            }
            return (head, slot)
        }
    }

    /// Look up a single head by ID。
    /// Throws `.unknownHead` if not registered;
    /// `.headDisabled` if registered but currently disabled.
    public func head(headID: String) throws -> any BASLayerMLHead {
        guard let head = headsByID[headID] else {
            throw BASLayerMLHeadRegistrationError.unknownHead(
                headID: headID)
        }
        // Check if disabled by looking up its slot record.
        for (_, list) in slotsByLayer {
            for slot in list where slot.headID == headID {
                if !slot.enabled {
                    throw BASLayerMLHeadRegistrationError
                        .headDisabled(headID: headID)
                }
                return head
            }
        }
        // Slot record missing — registry corruption (shouldn't
        // happen with correct register/unregister pairing).
        return head
    }

    /// All registered slot records, sorted by (layerID, priority)。
    /// Useful for audit emission + diagnostic dumps.
    public var allSlots: [BASLayerMLHeadSlot] {
        var result: [BASLayerMLHeadSlot] = []
        let orderedLayers = BASMotherboardLayer14.allCases
        for layer in orderedLayers {
            if let list = slotsByLayer[layer] {
                result.append(contentsOf: list)
            }
        }
        return result
    }
}
