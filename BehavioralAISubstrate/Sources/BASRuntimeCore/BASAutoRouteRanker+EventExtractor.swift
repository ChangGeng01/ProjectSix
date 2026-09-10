// MARK: - BASAutoRouteRanker+EventExtractor
// God-object extraction (audit ch1040, WS1): the EventExtractor domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - L3 Event Extractor (chapter 七百四十五 第一刀 / M2396)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L3 Event
    // Extractor per-event classification port (Cargo/bas-
    // event-log-codec/src/event_extractor.rs)。
    //
    // Full Swift orchestrator (BASKnowledgeGraphEventExtractor)
    // stays Swift。 Rust handles the per-event classification
    // hot-path:given (action, source, memory_atom_tag),
    // decide what edge to emit linking the event to its
    // project node。

    /// Edge kind classification result。 Mirrors Rust EdgeKind。
    public enum EventEdgeKind: Int32, Sendable {
        case none = 0
        case causes = 1
        case delays = 2
        case contradicts = 3
        case mentions = 4
    }

    /// Per-event classification result。
    public struct EventClassification: Sendable {
        public let edgeKind: EventEdgeKind
        public let edgeWeight: Double
        public let isMemoryAtomEvent: Bool
    }

    /// Classify one event via the Rust port。 Returns nil on
    /// FFI fault (null/invalid inputs)。
    public static func classifyEvent(
        action: String,
        source: String,
        memoryAtomEventActionTag: String
    ) -> EventClassification? {
        #if os(iOS) || os(macOS)
        let actionB = Array(action.utf8)
        let sourceB = Array(source.utf8)
        let tagB = Array(memoryAtomEventActionTag.utf8)
        var ek: Int32 = 0
        var ew: Double = 0.0
        var am: Int32 = 0
        let rc = actionB.withUnsafeBufferPointer { ap -> Int32 in
            sourceB.withUnsafeBufferPointer { sp in
                tagB.withUnsafeBufferPointer { tp in
                    let aC = ap.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(
                            to: CChar.self) }
                    let sC = sp.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(
                            to: CChar.self) }
                    let tC = tp.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(
                            to: CChar.self) }
                    return bas_event_extractor_classify(
                        aC, Int32(actionB.count),
                        sC, Int32(sourceB.count),
                        tC, Int32(tagB.count),
                        &ek, &ew, &am)
                }
            }
        }
        guard rc == 0 else { return nil }
        let kind = EventEdgeKind(rawValue: ek) ?? .none
        return EventClassification(
            edgeKind: kind,
            edgeWeight: ew,
            isMemoryAtomEvent: am != 0)
        #else
        return nil
        #endif
    }

    /// Returns the bas-event-extractor ABI version。
    public static func eventExtractorABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_event_extractor_abi_version()
        #else
        return 0
        #endif
    }
}
