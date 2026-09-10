import Foundation

// 四十九 — typed cross-pillar guard combining Doctrines B + C + D
// into one operation-level compliance check.
//
// ## Why this exists
//
// Doctrines B (state-update scope), C (growth velocity), and D
// (actor output authority) each have their own typed
// references and individual checks. Engines that want to
// validate "is this actor's operation simultaneously consistent
// with all three doctrines?" had to call three separate
// predicates and merge the results manually.
//
// `BASDoctrineActorOperationGuard` ships the unified entry point:
// pass a typed `BASDoctrineActorOperation` (actor + output class
// + scope + velocity), get back a typed `[Violation]`. Empty list
// means "compliant"; non-empty means each violation case carries
// the typed evidence for audit.
//
// Doctrine A (private experience ≠ L2 weights) lives in the
// Qinao package's `BASWorldPriorTrainingPipelineFilter` because
// its inputs are Qinao envelope types — that filter stays the
// independent Doctrine A check; this guard composes B + C + D
// for BAS-side operations.
//
// ## Doctrine
//
// - **Three pillar checks.** Output authority (D), scope canonical
//   per actor (B), velocity-at-scope (C). All three run; all
//   violations accumulate into the result list.
// - **Pure value check.** No I/O, no actor hop, no throw.
// - **Empty list = compliant.** Engines branch on
//   `isCompliant(_:)` for the boolean form.
// - **Codable violations.** Audit can serialize a violation list
//   into the ledger / log.

public struct BASDoctrineActorOperation:
    Sendable, Equatable, Hashable, Codable
{
    public let actor: BASActor
    public let outputClass: BASActorOutputClass
    public let stateUpdateScope: BASStateUpdateScope
    public let stateUpdateVelocity: BASGrowthVelocity

    public init(
        actor: BASActor,
        outputClass: BASActorOutputClass,
        stateUpdateScope: BASStateUpdateScope,
        stateUpdateVelocity: BASGrowthVelocity
    ) {
        self.actor = actor
        self.outputClass = outputClass
        self.stateUpdateScope = stateUpdateScope
        self.stateUpdateVelocity = stateUpdateVelocity
    }
}

public enum BASDoctrineViolation:
    Sendable, Equatable, Hashable, Codable
{
    /// Doctrine D: actor produced an output class outside its
    /// permitted set. Carries the actor and the disallowed
    /// class for audit.
    case actorOutputClassDenied(
        BASActor, BASActorOutputClass)

    /// Doctrine B: actor performed a state update at a scope
    /// different from its canonical scope. Carries the actor
    /// and the scope it tried to use.
    case scopeMismatch(
        BASActor, BASStateUpdateScope)

    /// Doctrine C: state update at a scope used a velocity
    /// outside the scope's permitted floor. For `.parameter`
    /// scope this fires unless velocity is exactly `.veryLow`;
    /// for other scopes when velocity exceeds canonical floor.
    case velocityViolatesScope(
        BASStateUpdateScope, BASGrowthVelocity)
}

public enum BASDoctrineActorOperationGuard {

    /// Run all three pillar checks. Returns a (possibly empty)
    /// list of violations. Empty = compliant.
    public static func check(
        _ operation: BASDoctrineActorOperation
    ) -> [BASDoctrineViolation] {
        var violations: [BASDoctrineViolation] = []

        // Doctrine D: actor permits output class?
        if !operation.actor.permits(
            outputClass: operation.outputClass)
        {
            violations.append(
                .actorOutputClassDenied(
                    operation.actor,
                    operation.outputClass))
        }

        // Doctrine B: actor's canonical scope matches?
        if operation.actor.canonicalUpdateScope
            != operation.stateUpdateScope
        {
            violations.append(
                .scopeMismatch(
                    operation.actor,
                    operation.stateUpdateScope))
        }

        // Doctrine C: scope permits this velocity?
        if !BASDoctrineCInvariant.permits(
            velocity: operation.stateUpdateVelocity,
            at: operation.stateUpdateScope)
        {
            violations.append(
                .velocityViolatesScope(
                    operation.stateUpdateScope,
                    operation.stateUpdateVelocity))
        }

        return violations
    }

    /// Convenience — empty violations = compliant.
    public static func isCompliant(
        _ operation: BASDoctrineActorOperation
    ) -> Bool {
        check(operation).isEmpty
    }
}
