import Foundation
import Testing
@testable import BASAppleAdapters

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
struct BASApplePredictiveInterventionLifecycleTests {
    @Test("reconciler preserves the existing candidate when the visible semantics match")
    func reconcilerPreservesExistingCandidateWhenVisibleSemanticsMatch() {
        let existing = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: "medium",
            title: "Pause first",
            detail: "A slower move should help here.",
            evidenceSignalCount: 2,
            preferredModeID: "reflective",
            reason: "Recent regret pattern",
            createdAt: Date(timeIntervalSince1970: 100),
            expiresAt: Date(timeIntervalSince1970: 200)
        )
        let next = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            riskLevelID: "medium",
            title: "Pause first",
            detail: "A slower move should help here.",
            evidenceSignalCount: 2,
            preferredModeID: "reflective",
            reason: "Recent regret pattern",
            createdAt: Date(timeIntervalSince1970: 300),
            expiresAt: Date(timeIntervalSince1970: 400)
        )

        let resolved = BASApplePredictiveInterventionReconciler.reconcile(
            existing: existing,
            next: next
        )

        #expect(resolved == existing)
    }

    @Test("delivery planner skips policy work when the feature is disabled or the risk is low")
    func deliveryPlannerSkipsWhenDisabledOrLowRisk() {
        let disabledPlan = BASApplePredictiveInterventionDeliveryPlanner.plan(
            candidate: BASApplePredictiveInterventionCandidateSummary(
                id: UUID(),
                riskLevelID: "medium",
                title: "Pause",
                detail: "Hold for a beat.",
                evidenceSignalCount: 2,
                preferredModeID: nil,
                reason: "pattern",
                createdAt: .distantPast,
                expiresAt: .distantFuture
            ),
            predictiveInterventionsEnabled: false,
            policyAllowed: true
        )
        let lowRiskPlan = BASApplePredictiveInterventionDeliveryPlanner.plan(
            candidate: BASApplePredictiveInterventionCandidateSummary(
                id: UUID(),
                riskLevelID: "low",
                title: "Pause",
                detail: "Hold for a beat.",
                evidenceSignalCount: 1,
                preferredModeID: nil,
                reason: "pattern",
                createdAt: .distantPast,
                expiresAt: .distantFuture
            ),
            predictiveInterventionsEnabled: true,
            policyAllowed: true
        )

        #expect(disabledPlan.actionKind == .none)
        #expect(lowRiskPlan.actionKind == .none)
    }

    @Test("delivery executor records blocked interventions and cancels their notifications")
    func deliveryExecutorRecordsBlockedInterventionsAndCancelsNotifications() {
        let candidate = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: "high",
            title: "Pause first",
            detail: "A slower move should help here.",
            evidenceSignalCount: 3,
            preferredModeID: "reflective",
            reason: "Recent regret pattern",
            createdAt: .distantPast,
            expiresAt: .distantFuture
        )
        let plan = BASApplePredictiveInterventionDeliveryPlanner.plan(
            candidate: candidate,
            predictiveInterventionsEnabled: true,
            policyAllowed: false
        )

        var calls: [String] = []

        BASApplePredictiveInterventionDeliveryExecutor.execute(
            plan: plan,
            upsertTrigger: { candidate, wasDelivered in
                calls.append("upsert:\(candidate.id.uuidString):\(wasDelivered)")
            },
            cancelNotification: { id in
                calls.append("cancel:\(id.uuidString)")
            },
            scheduleNotification: { _ in
                calls.append("schedule")
            }
        )

        #expect(calls == [
            "upsert:AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE:false",
            "cancel:AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        ])
    }
}
#endif
