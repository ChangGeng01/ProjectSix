// MARK: - BASCognitiveOSBuilder — chapter 三百七二 / M859
//
// A2 Builder integration: factory namespace that constructs the
// optional cognitive-OS primitives (event log / state store /
// vector index / knowledge graph) per caller-supplied
// `BASCognitiveOSBundleOptions`。
//
// Closes the M858-audit gap H2 (M841-M858 primitives not wired
// into any builder) by providing a single async factory entry
// point。Hosts compose:
//
//     let bundle = try BASCognitiveOSBuilder.build(
//         options: BASCognitiveOSBundleOptions(
//             enableEventLog: true,
//             eventLogSQLiteURL: docsDir.appending("events.db"),
//             enableUserState: true,
//             enableVectorIndex: true,
//             enableKnowledgeGraph: true))
//     // bundle.eventLog / .userStateStore / .vectorIndex /
//     // .knowledgeGraph all populated
//
// ## Doctrine pins held
//
// All `BASCognitiveOSBundle.swift` pins apply。Additionally:
//   - chapter 三百二九 (M816) `BASChengluHostRuntimeBuilder`
//     pattern mirrored — pure factory namespace,no hidden state
//   - Throws on SQLite construction errors;in-memory paths
//     never throw (defensive pin tested)

import Foundation
import BASMemory
import BASRuntimeCore

/// Factory namespace for `BASCognitiveOSBundle`。Mirror of the
/// M816 `BASChengluHostRuntimeBuilder` pattern — single async
/// `build(...)` entry point。
public enum BASCognitiveOSBuilder {

    /// Build a `BASCognitiveOSBundle` per the caller's
    /// `BASCognitiveOSBundleOptions`。
    ///
    /// **In-memory vs SQLite**: each enabled primitive checks
    /// its corresponding `*SQLiteURL` option:
    ///   - URL provided → SQLite-backed conformer constructed
    ///   - URL nil → in-memory conformer constructed
    ///
    /// **Errors**: re-throws any SQLite open / schema error
    /// (per M735 BASSQLiteMemoryAtomStore doctrine — integrity
    /// outranks availability)。
    ///
    /// - Parameter options: typed flags + optional URLs
    /// - Returns: typed bundle with primitives the caller
    ///   opted into; nil for disabled primitives
    /// - Throws: re-throws SQLite construction errors when
    ///   any `*SQLiteURL` open fails
    public static func build(
        options: BASCognitiveOSBundleOptions
    ) throws -> BASCognitiveOSBundle {
        // Empty bundle if all flags disabled
        if options == .allDisabled {
            return .empty
        }

        // Event log
        let eventLog: (any BASEventLogStorage)?
        if options.enableEventLog {
            if let url = options.eventLogSQLiteURL {
                eventLog =
                    try BASSQLiteEventLogStorage(
                        databaseURL: url)
            } else {
                eventLog = BASInMemoryEventLogStorage()
            }
        } else {
            eventLog = nil
        }

        // User state store
        let userStateStore: (any BASUserStateStorage)?
        if options.enableUserState {
            if let url = options.userStateSQLiteURL {
                userStateStore =
                    try BASSQLiteUserStateStorage(
                        databaseURL: url)
            } else {
                userStateStore =
                    BASInMemoryUserStateStorage()
            }
        } else {
            userStateStore = nil
        }

        // Vector index (in-memory) + optional SQLite backing
        let vectorIndex: BASVectorIndex?
        let vectorIndexStorage:
            BASSQLiteVectorIndexStorage?
        if options.enableVectorIndex {
            vectorIndex = BASVectorIndex()
            if let url = options.vectorIndexSQLiteURL {
                vectorIndexStorage =
                    try BASSQLiteVectorIndexStorage(
                        databaseURL: url)
            } else {
                vectorIndexStorage = nil
            }
        } else {
            vectorIndex = nil
            vectorIndexStorage = nil
        }

        // Knowledge graph (in-memory) + optional SQLite backing
        // (M866 closes M856 deferred persistence work — same
        // sibling pattern as vector index)
        let knowledgeGraph: BASKnowledgeGraph?
        let knowledgeGraphStorage:
            BASSQLiteKnowledgeGraphStorage?
        if options.enableKnowledgeGraph {
            knowledgeGraph = BASKnowledgeGraph()
            if let url = options.knowledgeGraphSQLiteURL {
                knowledgeGraphStorage =
                    try BASSQLiteKnowledgeGraphStorage(
                        databaseURL: url)
            } else {
                knowledgeGraphStorage = nil
            }
        } else {
            knowledgeGraph = nil
            knowledgeGraphStorage = nil
        }

        return BASCognitiveOSBundle(
            eventLog: eventLog,
            userStateStore: userStateStore,
            vectorIndex: vectorIndex,
            vectorIndexStorage: vectorIndexStorage,
            knowledgeGraph: knowledgeGraph,
            knowledgeGraphStorage: knowledgeGraphStorage)
    }
}
