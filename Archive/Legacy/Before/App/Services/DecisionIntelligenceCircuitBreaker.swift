import Foundation

enum DecisionIntelligenceCircuitTripReason: String, CaseIterable, Sendable {
    case repeatedProviderFailure
    case repeatedSlowSuccess
}

struct DecisionIntelligenceCircuitBreakerSnapshot: Equatable, Sendable {
    let activeProviders: [DecisionModelProviderKind]
    let openUntilByProvider: [DecisionModelProviderKind: Date]
    let totalTripCountByProvider: [DecisionModelProviderKind: Int]
    let totalTripCountByReason: [DecisionIntelligenceCircuitTripReason: Int]
    let failureStreakByProvider: [DecisionModelProviderKind: Int]
    let slowStreakByProvider: [DecisionModelProviderKind: Int]
    let lastTripReasonByProvider: [DecisionModelProviderKind: DecisionIntelligenceCircuitTripReason]

    var totalTripCount: Int {
        totalTripCountByProvider.values.reduce(0, +)
    }
}

enum DecisionIntelligenceCircuitHealthEvent: Equatable, Sendable {
    case cacheHit
    case providerSuccess(kind: DecisionIntelligenceTraceKind, durationMs: Double)
    case providerFailure
}

actor DecisionIntelligenceCircuitBreaker {
    static let shared = DecisionIntelligenceCircuitBreaker()

    private var openUntilByProvider: [DecisionModelProviderKind: Date] = [:]
    private var totalTripCountByProvider: [DecisionModelProviderKind: Int] = [:]
    private var totalTripCountByReason: [DecisionIntelligenceCircuitTripReason: Int] = [:]
    private var failureStreakByProvider: [DecisionModelProviderKind: Int] = [:]
    private var slowStreakByProvider: [DecisionModelProviderKind: Int] = [:]
    private var lastTripReasonByProvider: [DecisionModelProviderKind: DecisionIntelligenceCircuitTripReason] = [:]

    func snapshot(now: Date = .now) -> DecisionIntelligenceCircuitBreakerSnapshot {
        cleanupExpiredCooldowns(now: now)

        return DecisionIntelligenceCircuitBreakerSnapshot(
            activeProviders: openUntilByProvider.keys.sorted { $0.rawValue < $1.rawValue },
            openUntilByProvider: openUntilByProvider,
            totalTripCountByProvider: totalTripCountByProvider,
            totalTripCountByReason: totalTripCountByReason,
            failureStreakByProvider: failureStreakByProvider,
            slowStreakByProvider: slowStreakByProvider,
            lastTripReasonByProvider: lastTripReasonByProvider
        )
    }

    func record(
        provider: DecisionModelProviderKind,
        event: DecisionIntelligenceCircuitHealthEvent,
        now: Date = .now
    ) {
        guard provider != .template else { return }
        cleanupExpiredCooldowns(now: now)

        switch event {
        case .cacheHit:
            resetStreaks(for: provider)
        case let .providerSuccess(kind, durationMs):
            failureStreakByProvider[provider] = 0
            if durationMs >= slowThresholdMs(for: kind) {
                slowStreakByProvider[provider, default: 0] += 1
                if (slowStreakByProvider[provider] ?? 0) >= BeforePolicy.Settings.intelligenceCircuitSlowTripThreshold {
                    trip(provider: provider, reason: .repeatedSlowSuccess, now: now)
                }
            } else {
                slowStreakByProvider[provider] = 0
            }
        case .providerFailure:
            slowStreakByProvider[provider] = 0
            failureStreakByProvider[provider, default: 0] += 1
            if (failureStreakByProvider[provider] ?? 0) >= BeforePolicy.Settings.intelligenceCircuitFailureTripThreshold {
                trip(provider: provider, reason: .repeatedProviderFailure, now: now)
            }
        }
    }

    func clear() {
        openUntilByProvider.removeAll()
        totalTripCountByProvider.removeAll()
        totalTripCountByReason.removeAll()
        failureStreakByProvider.removeAll()
        slowStreakByProvider.removeAll()
        lastTripReasonByProvider.removeAll()
    }

    private func trip(
        provider: DecisionModelProviderKind,
        reason: DecisionIntelligenceCircuitTripReason,
        now: Date
    ) {
        openUntilByProvider[provider] = now.addingTimeInterval(BeforePolicy.Settings.intelligenceCircuitCooldownInterval)
        totalTripCountByProvider[provider, default: 0] += 1
        totalTripCountByReason[reason, default: 0] += 1
        lastTripReasonByProvider[provider] = reason
        resetStreaks(for: provider)
    }

    private func resetStreaks(for provider: DecisionModelProviderKind) {
        failureStreakByProvider[provider] = 0
        slowStreakByProvider[provider] = 0
    }

    private func cleanupExpiredCooldowns(now: Date) {
        openUntilByProvider = openUntilByProvider.filter { $0.value > now }
    }

    private func slowThresholdMs(
        for kind: DecisionIntelligenceTraceKind
    ) -> Double {
        switch kind {
        case .quick:
            800
        case .balance, .mirror:
            1_500
        case .reminder:
            450
        }
    }
}
