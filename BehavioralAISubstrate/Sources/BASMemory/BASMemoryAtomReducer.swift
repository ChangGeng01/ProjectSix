// MARK: - BASMemoryAtomReducer — chapter 四百二 / M942
//
// Phase 1 第二刀: pure-function reducer that folds memory-atom
// events into a `[String: BASGovernedMemory]` projection。Mirrors
// M842 `BASUserStateReducer` shape so the same replay invariant
// applies (chapter 三百九二 replay-determinism)。
//
// ## Why this exists
//
// M941 ships the typed payload。M942 ships the function that
// turns a stream of `(prior, event)` pairs into a fresh atom-set
// snapshot。Combined with `BASEventReplayRunner.replay(...)`,
// this is the pure-function projection layer that makes the
// event log a valid source-of-truth for memory atom state。
//
// ## What this is (and is NOT)
//
// **Is**:
//   - A typed pure function `reduce(priorAtoms:event:) -> nextAtoms`
//   - Stateless — every call gets fresh prior + event,returns
//     fresh next atoms
//   - Deterministic — same `(priorAtoms, event)` → same output
//   - Compatible with `BASEventReplayRunner.replay(...)` via
//     `reducerStep(prior:event:)` (returns nil for non-memory
//     events so they count as skipped)
//
// **Is NOT**:
//   - A learned model
//   - A decision-maker — atom mutations are observation-class
//     (红线 7) per chapter 二百四十八 governance doctrine
//   - A content store — the reducer projects atom *state* (kind
//     / scope / tier / governanceStatus / etc.) but content stays
//     empty on replay。Hosts that need content cache it ephemerally
//     in M943's event-sourced store
//
// ## Admission resolution rule (chapter 一百八十五 anti-magic-number)
//
// When `.admitted` arrives for an atomID already in the projection,
// the reducer keeps the entry with HIGHER confidence — ties go to
// the existing entry (deterministic tiebreak)。Pinned as named
// `static let admissionConfidenceTiebreakKeepsExisting` so the
// rule is grep-able。
//
// ## Doctrine pins held
//
//   - All M941 doctrine pins
//   - 单提交口 (L11/L14) 不变 — reducer is pure,deterministic,
//     no side effects beyond returning new state
//   - chapter 二百一一 single-source-of-truth — ONE reduce(...)
//     entry point;ONE reducerStep(...) shape for replay
//   - chapter 三百九二 (M892) replay-determinism — pinned by
//     test class via N=1000 random-order replay assertion

import Foundation
import BASRuntimeCore

// MARK: - Reducer namespace

public enum BASMemoryAtomReducer {

    // MARK: - Coefficients (chapter 一百八十五 anti-magic-number)

    /// On `.admitted` arriving for an existing atomID with EQUAL
    /// confidence,keep the existing entry (deterministic tiebreak)。
    /// Set to `false` to flip to "newcomer wins ties" — stays as
    /// a typed constant so the rule is grep-able and audit-pinned。
    public static let admissionConfidenceTiebreakKeepsExisting:
        Bool = true

    // MARK: - Pure-function reduce

    /// Fold a single event into the prior projection。
    ///
    /// - Parameters:
    ///   - priorAtoms: state before the event (S_{t-1})
    ///   - event: typed event log entry
    /// - Returns: state after the event (S_t)。If the event does
    ///   NOT carry a memory-atom payload,returns `priorAtoms`
    ///   unchanged。
    public static func reduce(
        priorAtoms: [String: BASGovernedMemory],
        event: BASEventLogEntry
    ) -> [String: BASGovernedMemory] {
        guard let payload = event.memoryAtomEventPayload else {
            return priorAtoms
        }
        var next = priorAtoms
        switch payload.op {
        case .admitted:
            applyAdmitted(payload: payload, into: &next)
        case .tierChanged:
            applyTierChange(payload: payload, into: &next)
        case .governanceChanged:
            applyGovernanceChange(payload: payload, into: &next)
        case .removed:
            next.removeValue(forKey: payload.atomID)
        }
        return next
    }

    /// `BASEventReplayRunner.replay(...)` reducer adapter。
    /// Returns nil for events that don't carry a memory-atom
    /// payload so the runner counts them as skipped (rather
    /// than consumed),matching M842's reducer pattern。
    public static func reducerStep(
        prior: [String: BASGovernedMemory],
        event: BASEventLogEntry
    ) -> [String: BASGovernedMemory]? {
        guard event.memoryAtomEventPayload != nil else {
            return nil
        }
        return reduce(priorAtoms: prior, event: event)
    }

    /// Convenience: replay all memory-atom events for `sessionID`
    /// from the given storage and return the final projection。
    public static func project(
        from storage: any BASEventLogStorage,
        sessionID: String
    ) async -> [String: BASGovernedMemory] {
        let events = await storage.events(forSession: sessionID)
        var atoms: [String: BASGovernedMemory] = [:]
        for event in events {
            atoms = reduce(priorAtoms: atoms, event: event)
        }
        return atoms
    }

    // MARK: - Internal application helpers

    private static func applyAdmitted(
        payload: BASMemoryAtomEventPayload,
        into atoms: inout [String: BASGovernedMemory]
    ) {
        guard let kind = payload.kind,
              let scope = payload.scope,
              let sensitivity = payload.sensitivity,
              let tier = payload.tier,
              let confidence = payload.confidence,
              let sourceType = payload.sourceType,
              let governanceStatus = payload.governanceStatus,
              let provenanceSummary = payload.provenanceSummary
        else {
            // Malformed `.admitted` payload — ignore (forward-
            // compat: future op variants may relax fields)。
            return
        }
        let candidateUUID =
            UUID(uuidString: payload.atomID) ?? UUID()
        let lastConfirmedAt = payload.lastConfirmedAtMs.map {
            Date(timeIntervalSince1970:
                Double($0) / 1000.0)
        }
        let newAtom = BASGovernedMemory(
            id: candidateUUID,
            kind: kind,
            // Content is host-side ephemeral data;event log keeps
            // contentDigest only (privacy doctrine)。Replay produces
            // empty content;hosts cache content separately if needed。
            content: "",
            scope: scope,
            sensitivity: sensitivity,
            tier: tier,
            confidence: confidence,
            sourceType: sourceType,
            lastConfirmedAt: lastConfirmedAt,
            decayScore: 0.0,
            governanceStatus: governanceStatus,
            provenanceSummary: provenanceSummary)
        if let existing = atoms[payload.atomID] {
            let existingWins:
                Bool
            if existing.confidence > confidence {
                existingWins = true
            } else if existing.confidence < confidence {
                existingWins = false
            } else {
                existingWins =
                    admissionConfidenceTiebreakKeepsExisting
            }
            if !existingWins {
                atoms[payload.atomID] = newAtom
            }
            // else: keep existing — no-op
        } else {
            atoms[payload.atomID] = newAtom
        }
    }

    private static func applyTierChange(
        payload: BASMemoryAtomEventPayload,
        into atoms: inout [String: BASGovernedMemory]
    ) {
        guard let newTier = payload.tier,
              var atom = atoms[payload.atomID] else {
            return
        }
        atom.tier = newTier
        atoms[payload.atomID] = atom
    }

    private static func applyGovernanceChange(
        payload: BASMemoryAtomEventPayload,
        into atoms: inout [String: BASGovernedMemory]
    ) {
        guard let newStatus = payload.governanceStatus,
              var atom = atoms[payload.atomID] else {
            return
        }
        atom.governanceStatus = newStatus
        atoms[payload.atomID] = atom
    }
}

// MARK: - chapter 四百三 / M955 — BASEventReducer conformance
//
// Phase 2 entropy 第三刀:formalize the existing M942 reducer
// shape against the typed `BASEventReducer<State>` protocol。
// Conformance lives in this file (not a separate extension
// file) because Swift 6 requires Sendable conformance to be
// declared in the same module/file as the enum to avoid
// retroactive `@unchecked Sendable` annotations。

extension BASMemoryAtomReducer: BASEventReducer {

    /// State type:`[String: BASGovernedMemory]` projection map
    /// keyed by atom UUID string (M942 contract)。
    public typealias State = [String: BASGovernedMemory]

    /// `BASEventReducer` conformance — wraps the existing M942
    /// `reducerStep(prior:event:)` static function so callers
    /// can route through the typed protocol。
    public static func reduceStep(
        prior: [String: BASGovernedMemory],
        event: BASEventLogEntry
    ) -> [String: BASGovernedMemory]? {
        reducerStep(prior: prior, event: event)
    }
}
