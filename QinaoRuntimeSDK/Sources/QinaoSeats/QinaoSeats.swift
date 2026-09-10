import Foundation

// M292.1 — 单脑多席 first-class typed scaffold (seats + verdict).
//
// Manifest v2 第八节 lists 9 seats that share **one** brain (single
// state graph, single permit gate, single sovereign canopy, single
// commit point). Each seat is a *role*, not a separate agent
// instance — they all read from the same typed object bus and write
// verdicts back to a shared board.
//
// Today the runtime carries `QinaoLoop.OrganRole = { .scout, .core }`
// — two roles, both about LLM dispatch flavor, not the 9-seat
// council manifest v2 calls for. Honesty-board 28.1 lists the
// missing 8 + the `.core / .scout` ambiguity as the largest
// engineering gap toward "它真可落地".
//
// M292.1 is the smallest possible first slice:
//
// - `QinaoSeat`: name the 9 seats as a typed enum so dependent
//   modules can reference seats by Swift type, not free-form
//   strings.
// - `SeatVerdict`: the typed shape every seat returns per turn.
//   Urgency [0,1], reason codes (audit-keyable), optional note.
// - **Protocol shipped (M292.2).** `QinaoSeatProtocol` lives in
//   `QinaoSeatRegistry.swift`. Typed inputs are the shared object
//   bus snapshots; verdict shape returns from each seat's `vote`
//   call.
// - **Registry shipped (M292.3).** `QinaoSeatRegistry` keys seats
//   by `QinaoSeat` raw value; verdict merge ships in
//   `QinaoSeatBoardMerge.swift`.
// - **Dispatcher (M292.4) ship 在 `QinaoLoopSeatsRuntime.swift`
//   单文件**——loop-bound parallel verdict spawning。一个独立、
//   doctrine-pinned `QinaoSeatDispatcher` 在 honesty-board 五十六
//   ship。
//
// Doctrine
//
// - **9 seats, no fewer, no more.** The enum count is pinned by
//   tests so silent expansion / contraction is caught.
// - **Urgency clamped to [0,1] on construction.** Same discipline
//   as `triSelfScore`'s concern: callers can pass sloppy values,
//   the type still holds.
// - **Reason codes are stable strings.** Same vocabulary discipline
//   as M74 tribunal codes (`manipulation-risk` etc.) — audit
//   walkers can group across seats by code.

/// One of 9 seats in the single-brain-multi-seat council. Each
/// raw value is stable (Codable round-trips, audit grep keys, UI
/// copy keys).
public enum QinaoSeat: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 前哨席 — fast pass: novelty / urgency / suspicious patterns.
    case scout = "scout"
    /// 时间席 — episode arcs, conflict clusters, continuity anchors.
    case memory = "memory"
    /// 路径席 — multi-path candidate generation, branch projection.
    case planner = "planner"
    /// 反方席 — adversarial review, evidence debt, counterfactual.
    case critic = "critic"
    /// 宿主对齐席 — host constitution checks, value-axis projection.
    case hostAlignment = "hostAlignment"
    /// 风闸席 — risk field, action permits, mode pressure.
    case risk = "risk"
    /// 柔手席 — surface mode selection, render shape.
    case surface = "surface"
    /// 主权哨席 — sovereign integrity, warrant validation, halt.
    case sovereignSentinel = "sovereignSentinel"
    /// 影子席 — evolution candidates, shadow trial, version delta.
    case evolutionShadow = "evolutionShadow"
}

/// Typed shape every seat returns per turn. Urgency in [0,1]
/// expresses how hard this seat wants its concern propagated;
/// reason codes are stable strings; note is free-form for surface
/// rendering (empty by default).
///
/// Constructed via `init`: urgency is clamped to [0,1] so a sloppy
/// caller can't poison the board.
public struct SeatVerdict:
    Sendable, Equatable, Hashable, Codable
{
    public let seat: QinaoSeat
    public let urgency: Double
    public let reasonCodes: [String]
    public let note: String

    public init(
        seat: QinaoSeat,
        urgency: Double,
        reasonCodes: [String] = [],
        note: String = ""
    ) {
        self.seat = seat
        self.urgency = min(max(urgency, 0), 1)
        self.reasonCodes = reasonCodes
        self.note = note
    }
}
