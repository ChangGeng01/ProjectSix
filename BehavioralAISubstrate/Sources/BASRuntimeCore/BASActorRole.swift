import Foundation

// 四十五.7+ — typed reference for honesty-board 四十五.1 四角色 +
// Doctrine D enforcement matrix.
//
// ## Why this exists
//
// Doctrine D from honesty-board 四十五.3:
//
//   宿主 = 直接给方向 (directive)
//   神经网络 = 产生意向 (advisory)
//   第二大脑 = 产生许可 (authoritative)
//   SDK = 执行现实接口 (execution)
//
// The doctrine is enforced architecturally (QinaoRuntime's three-
// signature gate, organ endpoints don't ship side effects, etc.)
// — but it was implicit. This file makes it typed: the
// `permittedOutputClasses` matrix lets audit code grep "did this
// actor produce an output class outside its permitted set" as a
// stable typed query.
//
// ## Doctrine
//
// - **Direct execution is SDK's exclusive privilege.** Neural
//   network NEVER produces execution; second brain NEVER
//   produces execution; host NEVER produces execution. Only SDK.
// - **Authoritative permits / warrants / verdicts are second
//   brain's exclusive privilege.** Neural network can suggest;
//   only second brain can authorize.
// - **Advisory outputs (intents / drafts / candidates) are
//   neural-network territory** — second brain can also reframe
//   advisory (e.g., wrapping organ output with seat verdicts),
//   but no other actor produces advisory primaries.
// - **Directives (goals / boundaries / authorization) are host
//   territory** — only the host (human) produces them.

public enum BASActor:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 人类宿主 — provides goals, boundaries, authorization.
    case host

    /// L1-L14 整体脑体 — produces typed authoritative permits /
    /// warrants / verdicts.
    case secondBrain

    /// L2 脑肉 — produces typed advisory intents / drafts /
    /// candidates. Doctrine D: NEVER produces execution.
    case neuralNetwork

    /// 产品接口 / 设备接口 / 权限接口 — executes on the world.
    /// Doctrine D: SDK is the exclusive execution boundary.
    case sdk
}

public enum BASActorOutputClass:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Goals / boundaries / authorization. Host territory.
    case directive

    /// Intents / drafts / candidates / suggestions. Neural-
    /// network territory; second brain may reframe.
    case advisory

    /// Permits / warrants / verdicts / sovereign decisions.
    /// Second-brain territory.
    case authoritative

    /// Actual side effects on devices / APIs / tools.
    /// SDK-exclusive.
    case execution
}

public extension BASActor {
    /// Doctrine D matrix — which output classes this actor is
    /// permitted to produce. Audit code grep this set against
    /// observed outputs to catch violations.
    var permittedOutputClasses: Set<BASActorOutputClass> {
        switch self {
        case .host:
            return [.directive]
        case .secondBrain:
            // Second brain produces authoritative permits and
            // may reframe advisory output (e.g., wrapping organ
            // output in seat verdicts).
            return [.authoritative, .advisory]
        case .neuralNetwork:
            // Doctrine D: only advisory. NEVER execution,
            // NEVER authoritative.
            return [.advisory]
        case .sdk:
            // Doctrine D: SDK is execution-exclusive.
            return [.execution]
        }
    }

    /// Quick boolean — is this actor permitted to produce this
    /// output class?
    func permits(
        outputClass: BASActorOutputClass
    ) -> Bool {
        permittedOutputClasses.contains(outputClass)
    }
}
