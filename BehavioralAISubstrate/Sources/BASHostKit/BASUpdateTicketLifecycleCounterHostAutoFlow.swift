// MARK: - chapter 二百五十四 / M741 — Counter-Host gate auto-flow
//                                       resolver convenience
//
// 附录 V Stage 2 Step 1 of 2: production wire for chapter 一百三十一
// `BASUpdateTicketLifecycleCoordinator
//     .approveForDistillationWithCounterHostCheck(...)`.
//
// ## Why this exists
//
// chapter 一百三十一 / M514 shipped the gate-aware promotion variant.
// What was missing: the convenience that hosts use *every promotion
// call* to have the gate fire automatically — without the host
// needing to derive a `BASCounterHostCheck?` upfront.
//
// chapter 二百五十四 introduces a **resolver pattern**: hosts wire
// one closure that derives a `BASCounterHostCheck?` from a
// lifecycle entry; subsequent calls invoke
// `approveForDistillationResolvingCounterHost(...)` and the
// resolver runs per-ticket, then the gate fires.
//
// Without this, hosts would either:
//   - skip the gate entirely (the chapter 一百三十 documented
//     concern: "gate has 0 production callers"), or
//   - duplicate Counter-Host derive boilerplate at every promotion
//     call site.
//
// The resolver pattern matches the chapter 二百六十五 audit-sink
// convention: one closure per coordinator, applied uniformly.
//
// ## Doctrine pins
//
//   - 不变量 #3 加固 — "私有经验不进权重 + 不通过宿主自证循环
//     塑造宿主". The resolver makes the gate the default flow, so
//     skipping it is now an explicit `approveForDistillation(...)`
//     call rather than the easy default.
//   - 红线 7 watcher-only-hint: the resolver returns `nil` for
//     non-host candidates → gate passes through unchanged. Hint
//     surface preserved.
//   - chapter 一百三十一 single-source-of-truth: the gate logic
//     stays in `BASUpdateTicketLifecycleCounterHostGate.swift`.
//     This file is convenience — does not redefine the gate.

import BASMemory
import BASObservability
import Foundation

public extension BASUpdateTicketLifecycleCoordinator {

    /// Resolver closure that derives a `BASCounterHostCheck?` from
    /// a lifecycle entry. Hosts implement once; the
    /// `approveForDistillationResolvingCounterHost(...)` helper
    /// invokes it per promotion. Returning `nil` means "gate not
    /// applicable" (e.g. candidate doesn't update host
    /// constitution); the gate then passes through unchanged.
    typealias CounterHostCheckResolver = @Sendable (
        BASUpdateTicketLifecycleEntry
    ) async -> BASCounterHostCheck?

    /// **chapter 二百五十四 / M741** — resolver-driven Counter-Host
    /// gate convenience. Equivalent to:
    ///
    /// ```swift
    /// let entry = await coord.entry(ticketID: id)!
    /// let check = await resolver(entry)
    /// return try await coord
    ///     .approveForDistillationWithCounterHostCheck(
    ///         ticketID: id,
    ///         sovereignVerdictRef: ref,
    ///         counterHostCheck: check)
    /// ```
    ///
    /// Hosts wire one resolver and use this method every time they
    /// promote a ticket. The Counter-Host gate auto-fires.
    ///
    /// Throws `LifecycleError.unknownTicket` if the ticketID is
    /// absent from the coordinator's entries (resolver is not
    /// invoked in that case).
    @discardableResult
    func approveForDistillationResolvingCounterHost(
        ticketID: String,
        sovereignVerdictRef: String,
        resolver: CounterHostCheckResolver
    ) async throws -> BASCounterHostGateOutcome {
        guard let entry = await self.entry(ticketID: ticketID)
        else {
            throw LifecycleError.unknownTicket(id: ticketID)
        }
        let check = await resolver(entry)
        return try await
            approveForDistillationWithCounterHostCheck(
                ticketID: ticketID,
                sovereignVerdictRef: sovereignVerdictRef,
                counterHostCheck: check)
    }
}
