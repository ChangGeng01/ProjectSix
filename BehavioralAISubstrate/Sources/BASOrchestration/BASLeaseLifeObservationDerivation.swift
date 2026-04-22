import Foundation
import BASRuntimeCore

// MARK: - M60 main-chain derivation from the turn's finalized
//         `BASBudgetFrame`
//
// M60 graduates the L1 灯芯层 surface from static budget frame
// to main-chain load-bearing observation output. The derivation
// lives in BASOrchestration (next to the rest of the observation
// family — M55 / M56 / M57 / M58 / M59) and reads `BASBudgetFrame`
// from BASRuntimeCore.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (budgetFrame, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with the routed budget: every signal
//     references fields the coordinator has already sealed before
//     calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedLeaseLifeObservationBundle(...)`
//     once the routed budget is finalized — right after the M53
//     session / turn id is derived so the bundle shares coordinates
//     with the L4..L13 bundles on the same turn.
//   - The L14 audit surface reads
//     `BASThoughtFrame.leaseLifeObservationBundle` to reconcile
//     "what L1 claimed about this turn's run mode / guard level /
//     maintenance window / device route" against "what the
//     runtime actually consumed under those constraints".
//   - Follow-on coverage projections can read
//     `hasCoreSignalCoverage` (= lease + runMode + thermal +
//     device route all emitted) from the derived bundle.

extension BASLeaseLifeObservationBundle {
    /// M60 — Derive an L1 kernel observation bundle from the turn's
    /// finalized `BASBudgetFrame`. The derivation is deterministic:
    /// for the same input (budget, turnID, sessionID, emittedAt) it
    /// produces the same bundle byte-for-byte. No I/O, no actor
    /// hop.
    ///
    /// Primary path: emit up to six signals in a fixed order:
    ///   1. `.leaseGranted`           — always, one per turn.
    ///                                  subjectID = `leaseID` when
    ///                                  present, else the synthetic
    ///                                  `"lease.<runMode>"`.
    ///   2. `.runModeDetermined`      — always, one per turn.
    ///                                  subjectID = `"runmode.<rawValue>"`.
    ///   3. `.thermalReadingObserved` — always, one per turn.
    ///                                  subjectID = `"thermal.<guardLevel>"`.
    ///   4. `.guardLevelEscalated`    — gated on
    ///                                  `guardLevel != .nominal`,
    ///                                  salience rises with severity.
    ///   5. `.maintenanceClassified`  — gated on
    ///                                  `maintenanceAllowed == true`
    ///                                  AND `maintenanceClass != .none`.
    ///                                  subjectID = `"maintenance.<class>"`.
    ///   6. `.deviceRouteSelected`    — always, one per turn.
    ///                                  subjectID = `"device.<route>"`.
    ///
    /// Shape classification runs once per budget and every
    /// observation on this bundle carries the same shape — it's a
    /// turn-level categorical summary, not a per-signal one. See
    /// `classifyShape(of:)` for the rules.
    public static func derive(
        fromBudgetFrame budget: BASBudgetFrame,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASLeaseLifeObservationBundle {
        var observations: [BASLeaseLifeObservation] = []
        let shape = classifyShape(of: budget)

        // Lease grant — subjectID prefers the real leaseID, falls
        // back to a synthetic `"lease.<runMode>"` when the budget
        // frame has no lease id (e.g. tests, sentinel mode).
        let leaseSubject = budget.leaseID
            ?? "lease.\(budget.runMode.rawValue)"
        let leaseContent =
            "l1.lease.id:" + leaseSubject
            + ".runMode:" + budget.runMode.rawValue
            + (budget.leaseExpiresAt.map {
                ".expiresAt:" + formatTimestamp($0)
            } ?? "")
        observations.append(BASLeaseLifeObservation(
            kind: .leaseGranted,
            shape: shape,
            subjectID: leaseSubject,
            salience: 0.85,
            confidence: 1.0,
            content: leaseContent,
            observedAt: emittedAt
        ))

        // Run mode determination.
        observations.append(BASLeaseLifeObservation(
            kind: .runModeDetermined,
            shape: shape,
            subjectID: "runmode." + budget.runMode.rawValue,
            salience: 0.80,
            confidence: 1.0,
            content:
                "l1.runmode.value:" + budget.runMode.rawValue
                + ".requiresRunLease:"
                + String(budget.runMode.requiresRunLease)
                + ".maxLoops:" + String(budget.maxLoops)
                + ".maxCandidates:" + String(budget.maxCandidates),
            observedAt: emittedAt
        ))

        // Thermal reading — always emitted so the turn carries
        // evidence L1 looked at thermal even at nominal.
        observations.append(BASLeaseLifeObservation(
            kind: .thermalReadingObserved,
            shape: shape,
            subjectID: "thermal." + budget.thermalGuardLevel.rawValue,
            salience: thermalSalience(for: budget.thermalGuardLevel),
            confidence: 1.0,
            content:
                "l1.thermal.guardLevel:"
                + budget.thermalGuardLevel.rawValue
                + ".precisionProfile:"
                + budget.precisionProfile.rawValue,
            observedAt: emittedAt
        ))

        // Guard-level escalation — gated on level > nominal.
        if budget.thermalGuardLevel != .nominal {
            observations.append(BASLeaseLifeObservation(
                kind: .guardLevelEscalated,
                shape: shape,
                subjectID:
                    "thermal.escalation."
                    + budget.thermalGuardLevel.rawValue,
                salience: escalationSalience(
                    for: budget.thermalGuardLevel),
                confidence: 1.0,
                content:
                    "l1.thermal.escalation.guardLevel:"
                    + budget.thermalGuardLevel.rawValue
                    + ".severity:" + severityTag(
                        for: budget.thermalGuardLevel),
                observedAt: emittedAt
            ))
        }

        // Maintenance classification — gated on allowed + non-none.
        if budget.maintenanceAllowed,
           budget.maintenanceClass != .none {
            observations.append(BASLeaseLifeObservation(
                kind: .maintenanceClassified,
                shape: shape,
                subjectID:
                    "maintenance."
                    + budget.maintenanceClass.rawValue,
                salience: maintenanceSalience(
                    for: budget.maintenanceClass),
                confidence: 1.0,
                content:
                    "l1.maintenance.class:"
                    + budget.maintenanceClass.rawValue
                    + ".allowed:true",
                observedAt: emittedAt
            ))
        }

        // Device route selection.
        observations.append(BASLeaseLifeObservation(
            kind: .deviceRouteSelected,
            shape: shape,
            subjectID: "device." + budget.deviceRoute.rawValue,
            salience: 0.70,
            confidence: 1.0,
            content:
                "l1.device.route:" + budget.deviceRoute.rawValue
                + ".retrievalDepth:"
                + String(budget.retrievalDepth)
                + ".maxDecodeTokens:"
                + String(budget.maxDecodeTokens),
            observedAt: emittedAt
        ))

        return BASLeaseLifeObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }
}

// MARK: - Shape classification
//
// Every observation on a given turn carries the same shape — it's
// the turn-level categorical summary for the kernel's phase.
// Precedence (checked top-down, first match wins):
//   1. `lockdown` run modes (recovery / quarantine / lockdown) →
//      `.lockdown`. This is the extraction phase; guard level
//      doesn't dominate.
//   2. `dormant` run modes (dormant / pulse / sentinel) →
//      `.dormant`. Background heartbeat.
//   3. `.emergency` guard level → `.emergency`. Panic phase
//      regardless of run mode.
//   4. `.throttle` guard level → `.throttled`. Kernel is actively
//      downgrading classes.
//   5. Maintenance allowed + class != .none → `.maintenance`.
//   6. Everything else → `.nominal`.
fileprivate func classifyShape(
    of budget: BASBudgetFrame
) -> BASLeaseLifeShape {
    switch budget.runMode {
    case .recovery, .quarantine, .lockdown:
        return .lockdown
    case .dormant, .pulse, .sentinel:
        return .dormant
    case .engage, .reflect, .deepLoop, .guard:
        // Fall through to guard-level classification.
        break
    }
    switch budget.thermalGuardLevel {
    case .emergency:
        return .emergency
    case .throttle:
        return .throttled
    case .nominal, .watch:
        break
    }
    if budget.maintenanceAllowed,
       budget.maintenanceClass != .none {
        return .maintenance
    }
    return .nominal
}

// MARK: - Salience helpers

/// Thermal-reading salience scales with guard level: nominal is
/// routine evidence (low salience), emergency dominates the turn
/// (salience 1.0).
fileprivate func thermalSalience(
    for level: BASThermalGuardLevel
) -> Double {
    switch level {
    case .nominal: return 0.55
    case .watch: return 0.70
    case .throttle: return 0.85
    case .emergency: return 1.0
    }
}

/// Escalation salience is always high (the signal only fires when
/// we're above nominal) but rises sharply with severity.
fileprivate func escalationSalience(
    for level: BASThermalGuardLevel
) -> Double {
    switch level {
    case .nominal: return 0
    case .watch: return 0.70
    case .throttle: return 0.85
    case .emergency: return 1.0
    }
}

fileprivate func severityTag(
    for level: BASThermalGuardLevel
) -> String {
    switch level {
    case .nominal: return "none"
    case .watch: return "watch"
    case .throttle: return "high"
    case .emergency: return "critical"
    }
}

/// Maintenance salience scales with class: deferred (background
/// bulk) is most audit-relevant because it implies the kernel is
/// deliberately postponing work; light is routine (low).
fileprivate func maintenanceSalience(
    for cls: BASMaintenanceClass
) -> Double {
    switch cls {
    case .none: return 0
    case .light: return 0.55
    case .standard: return 0.70
    case .deferred: return 0.85
    }
}

// MARK: - Content helpers

/// Format a `Date` as a deterministic ISO-8601 string so content
/// fields are stable across locales and time zones. Emits in UTC.
fileprivate func formatTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds
    ]
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
}
