import Foundation
import QinaoSeats
import QinaoLoop

// M292.3 — three default seat implementations bound to a
// QinaoLoop instance. Each seat takes a loop reference at init,
// reads the loop's typed state inside `contribute(snapshotID:)`
// (where `snapshotID == sessionID` by convention), and returns a
// `SeatVerdict` derived from real loop signals — not mock data.
//
// This is M292.3's deliberately small first slice: only Scout /
// Critic / Risk are shipped. Memory / Planner / HostAlignment /
// Surface / SovereignSentinel / EvolutionShadow either need
// substrate seams that haven't been wired yet (memory, sovereign)
// or rely on signals that downstream milestones will compute
// (planner, evolution). Shipping the three that have unambiguous
// loop signals first keeps M292.3 surgical.
//
// Doctrine
//
// - **Snapshot ID is the session ID.** The dispatcher passes
//   `snapshotID` from `QinaoSeatRegistry.dispatch(...)`; default
//   seats interpret it as the QinaoLoop session to read from.
//   Future M292.3+ may extend this to a richer typed context.
// - **Heuristic, not LLM.** Default seats are deterministic
//   summaries of existing loop signals. They give a baseline
//   verdict in [0,1] urgency; richer LLM-driven verdicts can
//   replace any default by registering a fresh impl
//   (last-write-wins).
// - **Failures translate to throws.** When a seat can't reach
//   its signal (session unknown, no candidates yet), the throw
//   propagates up into `SeatBoard.failures` per M292.2 doctrine.
// - **Reason codes are stable strings.** Same vocabulary
//   discipline as M74 tribunal — audit walkers group across
//   seats by code.

// MARK: - Scout (前哨席)

/// Scout seat: reads the candidate frontier and reports how
/// uncertain the top candidate is. Urgency = `1 - top.score`
/// (low composite score = high scout need to look further).
/// Reason codes flag low-score and multi-candidate shapes.
public struct QinaoScoutDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .scout
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let frontier = try await loop.candidateFrontier(
            sessionID: snapshotID, topK: Int.max)
        guard let top = frontier.first else {
            return SeatVerdict(
                seat: .scout,
                urgency: 0,
                reasonCodes: ["no-candidates"],
                note: "frontier-empty")
        }
        // Scout urgency: how unconfident is the top candidate?
        // `score` is the loop's composite frontier score in [0,1].
        // Low score → high uncertainty → scout should look further.
        let urgency = max(0, min(1, 1 - top.score))
        var codes: [String] = []
        if top.score < 0.5 {
            codes.append("low-top-score")
        }
        if frontier.count >= 2 {
            codes.append("multi-candidate")
        }
        return SeatVerdict(
            seat: .scout,
            urgency: urgency,
            reasonCodes: codes,
            note: "top:\(top.candidateID)")
    }
}

// MARK: - Critic (反方席)

/// Critic seat: reads `vetoExplain` and reports the vetoing
/// voice's concern level as urgency. Reason codes echo the
/// voice's primary + supporting reasons. When no candidate
/// reaches the 0.7 veto threshold, the seat returns urgency 0
/// with a `"no-veto"` reason code (silence is informative —
/// downstream merge can use it).
public struct QinaoCriticDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .critic
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let veto = try await loop.vetoExplain(
            sessionID: snapshotID)
        guard let v = veto else {
            return SeatVerdict(
                seat: .critic,
                urgency: 0,
                reasonCodes: ["no-veto"],
                note: "all-candidates-below-threshold")
        }
        var codes = [v.primaryReason]
        codes.append(contentsOf: v.supportingReasons)
        codes.append("voice:\(v.vetoingVoice.rawValue)")
        return SeatVerdict(
            seat: .critic,
            urgency: v.concernLevel,
            reasonCodes: codes,
            note: "vetoed:\(v.candidateID),alt:\(v.alternativeID)")
    }
}

// MARK: - Risk (风闸席)

/// Risk seat: reads tri-self scores and reports the loudest
/// guardian concern across all candidates. Urgency = max
/// guardian concern; reason codes echo the guardian's reason
/// vocabulary on the candidate that drove the max.
public struct QinaoRiskDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .risk
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let scores = try await loop.triSelfScores(
            sessionID: snapshotID)
        guard !scores.isEmpty else {
            return SeatVerdict(
                seat: .risk,
                urgency: 0,
                reasonCodes: ["no-scores"],
                note: "no-tri-self-scores")
        }
        let loudest = scores.max {
            $0.guardVoice.concern < $1.guardVoice.concern
        }
        guard let l = loudest else {
            return SeatVerdict(
                seat: .risk,
                urgency: 0,
                reasonCodes: [])
        }
        var codes = l.guardVoice.reasonCodes
        if l.guardVoice.concern >= 0.7 {
            codes.append("guardian-veto-tier")
        } else if l.guardVoice.concern >= 0.4 {
            codes.append("guardian-audible")
        }
        return SeatVerdict(
            seat: .risk,
            urgency: l.guardVoice.concern,
            reasonCodes: codes,
            note: "loudest-on:\(l.candidateID)")
    }
}

// MARK: - Sovereign Sentinel (主权哨席, M292.5)

/// Sovereign Sentinel seat: watches for board-level anomalies —
/// veto-tier concerns, voice saturation across candidates — and
/// reports the maximum of these as urgency. Distinct from Critic
/// (which only reports `vetoExplain`'s level) by also factoring
/// in saturation: if every candidate has any voice ≥ 0.7, the
/// council is in trouble even when no single veto stands out.
///
/// Doctrine: this seat is the bridge to L14. When its urgency is
/// high, the runtime should consider escalating to sovereign
/// review. M292.5 ships the seat; explicit runtime escalation
/// hook is a future milestone.
public struct QinaoSovereignSentinelDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .sovereignSentinel
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let scores = try await loop.triSelfScores(
            sessionID: snapshotID)
        guard !scores.isEmpty else {
            return SeatVerdict(
                seat: .sovereignSentinel,
                urgency: 0,
                reasonCodes: ["no-scores"],
                note: "no-tri-self-scores")
        }

        // Veto-tier signal: highest max-voice across candidates.
        let perCandidateMax = scores.map { s in
            max(
                s.guardVoice.concern,
                max(s.scoutVoice.concern, s.harmonyVoice.concern))
        }
        let topMax = perCandidateMax.max() ?? 0

        // Saturation signal: fraction of candidates with any voice
        // at or above 0.7.
        let saturatedCount = perCandidateMax.filter {
            $0 >= 0.7
        }.count
        let saturation =
            Double(saturatedCount) / Double(scores.count)

        let urgency = max(topMax, saturation)

        var codes: [String] = []
        if topMax >= 0.7 {
            codes.append("veto-tier-reached")
        }
        if saturation >= 0.5 {
            codes.append("voice-saturation")
        }
        if codes.isEmpty {
            codes.append("clean")
        }

        return SeatVerdict(
            seat: .sovereignSentinel,
            urgency: urgency,
            reasonCodes: codes,
            note: "saturation:\(String(format: "%.2f", saturation))")
    }
}

// MARK: - Planner (路径席, M292.6a)

/// Planner seat: reads the candidate frontier and reports how
/// much the candidates *diverge* in score. High divergence = the
/// frontier is offering substantively different paths and the
/// planner has work to do; low divergence (or single candidate)
/// = there's no meaningful path to plan among. Urgency =
/// `max(score) - min(score)` clamped to [0,1]. Reason codes
/// flag single-candidate / score-spread shapes.
///
/// Distinct from Scout (which reads top candidate uncertainty):
/// Planner cares about the SHAPE of the frontier as a whole.
public struct QinaoPlannerDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .planner
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let frontier = try await loop.candidateFrontier(
            sessionID: snapshotID, topK: Int.max)
        guard !frontier.isEmpty else {
            return SeatVerdict(
                seat: .planner,
                urgency: 0,
                reasonCodes: ["no-candidates"],
                note: "frontier-empty")
        }
        guard frontier.count >= 2 else {
            return SeatVerdict(
                seat: .planner,
                urgency: 0,
                reasonCodes: ["single-candidate"],
                note: "no-paths-to-plan")
        }
        let scores = frontier.map(\.score)
        let spread = (scores.max() ?? 0) - (scores.min() ?? 0)
        let urgency = max(0, min(1, spread))
        var codes: [String] = []
        if spread >= 0.5 {
            codes.append("wide-spread")
        } else if spread >= 0.2 {
            codes.append("moderate-spread")
        } else {
            codes.append("narrow-spread")
        }
        codes.append("candidate-count:\(frontier.count)")
        return SeatVerdict(
            seat: .planner,
            urgency: urgency,
            reasonCodes: codes,
            note: "spread:\(String(format: "%.2f", spread))")
    }
}

// MARK: - Surface (柔手席, M292.6a)

/// Surface seat: reads `vetoExplain` and frontier shape and
/// reports which L12 surface mode the council leans toward.
/// Urgency reflects how protective the seat thinks the surface
/// must be (boundary > compare > draft > silentStub). The
/// recommended mode is encoded in reason codes
/// (`"mode:boundary"` etc.) so audit walkers can grep without
/// a separate field.
///
/// This seat is advisory — actual surface mode selection still
/// runs through `BASSoftHandModeSelector` in the runtime. The
/// seat lets multi-seat dispatch register *that the council
/// noticed* a particular surface shape.
public struct QinaoSurfaceDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .surface
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let frontier = try await loop.candidateFrontier(
            sessionID: snapshotID, topK: Int.max)
        let veto = try await loop.vetoExplain(
            sessionID: snapshotID)

        if frontier.isEmpty {
            return SeatVerdict(
                seat: .surface,
                urgency: 0,
                reasonCodes: ["no-candidates", "mode:silentStub"],
                note: "frontier-empty")
        }

        if let v = veto, v.concernLevel >= 0.7 {
            return SeatVerdict(
                seat: .surface,
                urgency: v.concernLevel,
                reasonCodes: [
                    "veto-tier-reached",
                    "mode:boundary",
                    "voice:\(v.vetoingVoice.rawValue)",
                ],
                note: "boundary-on:\(v.candidateID)")
        }

        if frontier.count >= 2 {
            return SeatVerdict(
                seat: .surface,
                urgency: 0.4,
                reasonCodes: [
                    "multi-candidate",
                    "mode:compare",
                ],
                note: "compare-\(frontier.count)-candidates")
        }

        // Single candidate, no veto → draft.
        return SeatVerdict(
            seat: .surface,
            urgency: 0.2,
            reasonCodes: ["single-candidate", "mode:draft"],
            note: "single-draft")
    }
}

// MARK: - Standard registry factory (M292.5 + M292.6a)

public extension QinaoSeatRegistry {

    /// One-call factory wiring six default seats (Scout, Critic,
    /// Risk, Planner, Surface, Sovereign Sentinel) bound to a
    /// loop. Hosts wanting a richer council can register
    /// additional seats after this returns; last-write-wins
    /// semantics let them override any default.
    ///
    /// Memory / HostAlignment / EvolutionShadow are NOT
    /// registered — those need substrate adapter seams (memory
    /// adapter, host constitution reader, evolution furnace
    /// reader) that the loop doesn't yet expose. Their default
    /// implementations land in M292.6b once those seams are
    /// wired.
    static func standardLoopSeats(
        loop: QinaoLoop
    ) async -> QinaoSeatRegistry {
        let registry = QinaoSeatRegistry()
        await registry.register(
            QinaoScoutDefaultSeat(loop: loop))
        await registry.register(
            QinaoCriticDefaultSeat(loop: loop))
        await registry.register(
            QinaoRiskDefaultSeat(loop: loop))
        await registry.register(
            QinaoPlannerDefaultSeat(loop: loop))
        await registry.register(
            QinaoSurfaceDefaultSeat(loop: loop))
        await registry.register(
            QinaoSovereignSentinelDefaultSeat(loop: loop))
        return registry
    }
}
