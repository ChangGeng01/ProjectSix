import Foundation
import BASRuntimeCore

// MARK: - Tribunal observation primitives
//
// M25 — L10 三我庭 Phase 1 seed: typed per-voice tribunal
// observation model.
//
// L10 models deliberation as a three-voice tribunal:
//   - 质我 (baseSelf) — the raw / reactive / honest voice
//   - 律我 (ruleSelf) — the principled / ethical voice
//   - 向我 (aspireSelf) — the goal-directed / growth voice
//
// Each voice can vote on a subject (usually a candidate from the
// L9 frontier), raise objections, offer concessions, and the
// tribunal produces a convergence signal when the three align. A
// rigorous coordinator path is upstream of this file; M25 lands
// the additive primitives so an observer pipeline can emit
// per-voice signals that the L14 surface can reconcile with
// whatever decision L10 eventually produced.
//
// Design mirrors M22/M23/M24 on purpose: the L14 reconciler reads
// one shape across L6/L7/L9/L10.
//
// Design principles:
//   1. Immutability — every observation is a value; a bundle is
//      frozen once emitted.
//   2. Typed voices and signal kinds — no free-form strings;
//      sealed enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (commonly a candidateID from the L9 frontier, but
//      the tribunal can deliberate on any typed subject ID).
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// The three voices of the L10 tribunal.
public enum BASTribunalVoice:
    String, Sendable, Codable, CaseIterable
{
    /// 质我 — raw, honest, reactive. Surfaces what the system
    /// actually wants before rules or aspirations weigh in.
    case baseSelf
    /// 律我 — principled. Applies host boundaries, explicit
    /// rules, and safety constraints to the subject.
    case ruleSelf
    /// 向我 — aspirational. Weighs the subject against the
    /// host's long-horizon goals and growth trajectory.
    case aspireSelf
}

/// Disposition a voice can take toward a subject.
public enum BASTribunalDisposition:
    String, Sendable, Codable, CaseIterable
{
    case affirm
    case oppose
    case abstain
}

/// The five upstream signals a tribunal observer pipeline can
/// emit. Each is attributed to one voice and directed at one
/// subject (candidate, decision, etc.).
public enum BASTribunalSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A typed vote from one voice on one subject.
    case vote
    /// A cross-voice objection — one voice raising a structural
    /// concern a vote alone can't capture.
    case objection
    /// A cross-voice concession — one voice backing down from a
    /// prior stance in light of another voice's argument.
    case concession
    /// A convergence reading — the three voices have aligned on a
    /// subject. Emitted by the tribunal as a whole, not by any
    /// single voice.
    case convergence
    /// A dissent reading — the three voices remain split and the
    /// subject cannot advance without further deliberation.
    case dissent
}

/// A single typed tribunal observation. Salience and confidence
/// are both in [0, 1]; content is opaque to the transport and
/// carries the signal-specific payload (reasoning, objection
/// text, concession rationale). `voice` may be nil for
/// convergence / dissent signals that the tribunal emits as a
/// whole; `disposition` is populated only for `.vote` signals.
public struct BASTribunalObservation: Sendable, Equatable, Codable {
    public let kind: BASTribunalSignalKind
    public let voice: BASTribunalVoice?
    public let disposition: BASTribunalDisposition?
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASTribunalSignalKind,
        voice: BASTribunalVoice?,
        disposition: BASTribunalDisposition?,
        subjectID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.voice = voice
        self.disposition = disposition
        self.subjectID = subjectID
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of tribunal observations emitted in one turn.
public struct BASTribunalObservationBundle:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASTribunalObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASTribunalObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASTribunalSignalKind
    ) -> [BASTribunalObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations attributed to a given voice, in emission
    /// order. Convergence / dissent signals (voice == nil) are
    /// never returned by this filter.
    public func observations(
        by voice: BASTribunalVoice
    ) -> [BASTribunalObservation] {
        observations.filter { $0.voice == voice }
    }

    /// Observations directed at a given subject, across all
    /// voices and kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASTribunalObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// Distinct subject IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var subjectIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.subjectID).inserted {
            ordered.append(obs.subjectID)
        }
        return ordered
    }

    /// True iff at least one vote was cast by each of the three
    /// voices. A tribunal with fewer than three voices on record
    /// should degrade, not silently return a majority.
    public var allVoicesSpoke: Bool {
        let voting = observations
            .filter { $0.kind == .vote }
            .compactMap { $0.voice }
        let heard = Set(voting)
        return BASTribunalVoice.allCases
            .allSatisfy { heard.contains($0) }
    }

    /// The latest vote (by emission order) from `voice` on
    /// `subjectID`, or `nil` if that voice never voted on that
    /// subject.
    public func vote(
        by voice: BASTribunalVoice,
        on subjectID: String
    ) -> BASTribunalObservation? {
        observations.last {
            $0.kind == .vote
                && $0.voice == voice
                && $0.subjectID == subjectID
        }
    }

    /// True iff the three voices cast matching dispositions on
    /// the given subject — a structural convergence signal that
    /// the coordinator can read before it emits a
    /// `.convergence` observation of its own.
    public func voicesAgree(on subjectID: String) -> Bool {
        let dispositions = BASTribunalVoice.allCases
            .compactMap { vote(by: $0, on: subjectID)?.disposition }
        guard dispositions.count == BASTribunalVoice.allCases.count
        else { return false }
        return Set(dispositions).count == 1
    }
}

// MARK: - Budget

/// Pure lookup: what does each tribunal signal cost the L1 wake
/// budget? Values are weights in abstract budget units (0.0–1.0).
/// Objections are most expensive (cross-voice synthesis over the
/// full subject state); votes are cheapest.
public enum BASTribunalObservationBudget {
    public static let signalCost:
        [BASTribunalSignalKind: Double] = [
            .vote: 0.10,
            .objection: 0.25,
            .concession: 0.15,
            .convergence: 0.10,
            .dissent: 0.10
        ]

    public static func cost(
        for kind: BASTribunalSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASTribunalObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent tribunal observation
/// bundles so the L14 audit surface (and integration tests) can
/// inspect what L10 emitted across a session. 128 entries covers
/// any realistic turn stream without unbounded growth.
public actor BASTribunalObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASTribunalObservationBundle] = []

    public init(
        capacity: Int =
            BASTribunalObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASTribunalObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASTribunalObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASTribunalObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASTribunalObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}

// MARK: - M55 main-chain derivation from a completed BASThoughtFrame

extension BASTribunalObservationBundle {
    /// M55 — Derive an L10 observation bundle from a completed
    /// `BASThoughtFrame`. The derivation is deterministic: for the
    /// same input frame + turn/session + emittedAt it produces the
    /// same bundle byte-for-byte. No I/O, no actor hop.
    ///
    /// Signal mapping (each signal kind is emitted iff the frame
    /// carries structural evidence for it):
    ///   - `.vote`         emitted 3× per `BASTriSelfScore`, one per
    ///                     voice. Voice → score mapping:
    ///                     baseSelf (质我) ← idScore (raw / honest),
    ///                     ruleSelf (律我) ← superegoScore (principled),
    ///                     aspireSelf (向我) ← egoScore (integrating /
    ///                     growth). Disposition: `.affirm` if
    ///                     score ≥ 0.6, `.oppose` if score ≤ 0.3,
    ///                     else `.abstain`. salience = score.
    ///                     confidence = mergedScore (how unified the
    ///                     tribunal feels about this candidate).
    ///                     subjectID = candidateID.
    ///   - `.objection`    emitted per `BASVetoMark`. Voice is mapped
    ///                     from vetoType: boundary / hostConstitution /
    ///                     sovereignPrecondition → ruleSelf (legal /
    ///                     principled veto), dignity → baseSelf (raw
    ///                     dignity concern), irreversibility /
    ///                     calibration → aspireSelf (long-horizon
    ///                     growth concern). salience = 1.0 if veto is
    ///                     non-compensable, 0.7 if compensable.
    ///                     confidence = 1.0 (the frame committed to
    ///                     this veto). subjectID = candidateID.
    ///   - `.dissent`      emitted per `BASRemandOrder`. Voice = nil
    ///                     (remand is a tribunal-level signal that
    ///                     the subject cannot advance without more
    ///                     work). salience = 0.8 (remand is a strong
    ///                     signal but not terminal). confidence = 1.0.
    ///                     subjectID = targetLayer.
    ///   - `.convergence`  emitted iff `courtDecisionDraft != nil`
    ///                     AND `voicesAgree(on: preferredCandidateID)`
    ///                     AND `vetoMarks.isEmpty`. Voice = nil
    ///                     (convergence is a tribunal-level signal).
    ///                     salience = 1.0 (decision is made).
    ///                     confidence = 1.0 when no vetos. subjectID =
    ///                     preferredCandidateID.
    ///
    /// Invariants:
    ///   - a completely empty `BASThoughtFrame` (no triScores, no
    ///     vetos, no remands, no decision draft) produces a bundle
    ///     with zero observations.
    ///   - `allVoicesSpoke` iff the frame carried ≥1 triScore (every
    ///     triScore emits one vote per voice, so any non-empty
    ///     triScores array yields all three voices voting).
    ///   - `hasCoreSignalCoverage` (L10 coverage projection) maps to
    ///     `allVoicesSpoke` — so a non-empty triScores array suffices
    ///     for L10 to register as "covered this turn".
    ///   - budget cost via `BASTribunalObservationBudget.totalCost`
    ///     clamps to [0, 1] even at high signal emission.
    public static func derive(
        from thoughtFrame: BASThoughtFrame,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASTribunalObservationBundle {
        var observations: [BASTribunalObservation] = []

        // .vote — 3× per triScore, one per voice
        for score in thoughtFrame.triScores {
            observations.append(contentsOf:
                voteObservations(for: score, at: emittedAt))
        }

        // .objection — per vetoMark
        for mark in thoughtFrame.vetoMarks ?? [] {
            observations.append(objectionObservation(
                for: mark, at: emittedAt))
        }

        // .dissent — per remandOrder
        for order in thoughtFrame.remandOrders ?? [] {
            observations.append(dissentObservation(
                for: order, at: emittedAt))
        }

        // .convergence — iff decision draft + voices agree + no vetos
        if let convergence = convergenceObservation(
            from: thoughtFrame, at: emittedAt) {
            observations.append(convergence)
        }

        return BASTribunalObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }

    private static func voteObservations(
        for score: BASTriSelfScore,
        at emittedAt: Date
    ) -> [BASTribunalObservation] {
        let merged = clamp01(score.mergedScore)
        let idObs = voteObservation(
            voice: .baseSelf,
            rawScore: score.idScore,
            mergedScore: merged,
            candidateID: score.candidateID,
            veto: score.veto,
            at: emittedAt)
        let superegoObs = voteObservation(
            voice: .ruleSelf,
            rawScore: score.superegoScore,
            mergedScore: merged,
            candidateID: score.candidateID,
            veto: score.veto,
            at: emittedAt)
        let egoObs = voteObservation(
            voice: .aspireSelf,
            rawScore: score.egoScore,
            mergedScore: merged,
            candidateID: score.candidateID,
            veto: score.veto,
            at: emittedAt)
        return [idObs, superegoObs, egoObs]
    }

    private static func voteObservation(
        voice: BASTribunalVoice,
        rawScore: Double,
        mergedScore: Double,
        candidateID: String,
        veto: Bool,
        at emittedAt: Date
    ) -> BASTribunalObservation {
        let clamped = clamp01(rawScore)
        let disposition: BASTribunalDisposition
        if clamped >= 0.6 {
            disposition = .affirm
        } else if clamped <= 0.3 {
            disposition = .oppose
        } else {
            disposition = .abstain
        }
        let content = "score:\(formatDouble(clamped))"
            + "|merged:\(formatDouble(mergedScore))"
            + "|veto:\(veto)"
        return BASTribunalObservation(
            kind: .vote,
            voice: voice,
            disposition: disposition,
            subjectID: candidateID,
            salience: clamped,
            confidence: mergedScore,
            content: content,
            observedAt: emittedAt
        )
    }

    private static func objectionObservation(
        for mark: BASVetoMark,
        at emittedAt: Date
    ) -> BASTribunalObservation {
        let voice = voiceForVetoType(mark.vetoType)
        let salience = mark.compensable ? 0.7 : 1.0
        let content = "vetoType:\(mark.vetoType.rawValue)"
            + "|reasons:\(mark.reasonCodes.count)"
            + "|compensable:\(mark.compensable)"
        return BASTribunalObservation(
            kind: .objection,
            voice: voice,
            disposition: nil,
            subjectID: mark.candidateID,
            salience: salience,
            confidence: 1.0,
            content: content,
            observedAt: emittedAt
        )
    }

    private static func dissentObservation(
        for order: BASRemandOrder,
        at emittedAt: Date
    ) -> BASTribunalObservation {
        let content = "work:\(order.requiredWork.count)"
            + "|reasons:\(order.reasonCodes.count)"
        return BASTribunalObservation(
            kind: .dissent,
            voice: nil,
            disposition: nil,
            subjectID: order.targetLayer,
            salience: 0.8,
            confidence: 1.0,
            content: content,
            observedAt: emittedAt
        )
    }

    private static func convergenceObservation(
        from thoughtFrame: BASThoughtFrame,
        at emittedAt: Date
    ) -> BASTribunalObservation? {
        guard let draft = thoughtFrame.courtDecisionDraft else {
            return nil
        }
        let hasVetos = (thoughtFrame.vetoMarks ?? []).isEmpty == false
        guard hasVetos == false else { return nil }
        // Build an ephemeral bundle from only votes to ask
        // voicesAgree — keeps the logic in one place.
        let voteOnly = thoughtFrame.triScores.flatMap { score in
            voteObservations(for: score, at: emittedAt)
        }
        let ephemeral = BASTribunalObservationBundle(
            turnID: "",
            sessionID: "",
            observations: voteOnly,
            emittedAt: emittedAt
        )
        guard ephemeral.voicesAgree(on: draft.preferredCandidateID)
        else { return nil }
        let content = "readiness:\(draft.readinessLevel)"
            + "|fallbacks:\(draft.fallbackCandidateIDs.count)"
            + "|disclosures:\(draft.requiredDisclosures.count)"
        return BASTribunalObservation(
            kind: .convergence,
            voice: nil,
            disposition: nil,
            subjectID: draft.preferredCandidateID,
            salience: 1.0,
            confidence: 1.0,
            content: content,
            observedAt: emittedAt
        )
    }

    private static func voiceForVetoType(
        _ vetoType: BASCourtVetoType
    ) -> BASTribunalVoice {
        switch vetoType {
        case .boundary,
             .hostConstitution,
             .sovereignPrecondition:
            return .ruleSelf
        case .dignity:
            return .baseSelf
        case .irreversibility,
             .calibration:
            return .aspireSelf
        }
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func formatDouble(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
