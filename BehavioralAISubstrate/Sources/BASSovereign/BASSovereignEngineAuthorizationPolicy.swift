import Foundation

// M296.2.yy — typed engine-side authorization policy that joins
// intent classification + dual-key gate.
//
// deep-audit DORMANT (2026-07-13): this CONVENIENCE FAÇADE has no production consumer. No engine
// calls `policy.authorize` — the live high-consequence path constructs `BASSovereignGatedIntent`
// and drives the gate directly (BASSovereignGatedCommit / BASConstitutionApprovalGate), so the
// "Engines now adopt M296.2 in one line" claim below describes an adoption that has not happened.
// LOWER stakes than a dark capability: the underlying authorization (the gate/enforcer) IS live
// and exercised; only this one-call wrapper is inert. Per pin-boundary-defer-interface it stays
// honestly marked, not stripped (consult-before-deleting). TRIGGER to make the claim true = the
// first engine that centralizes its high-consequence intent list through this policy.
//
// ## Why this exists
//
// M296.2.y ship 了 `BASSovereignGatedIntent` (typed bundle) +
// `Validator` (delegate to gate). But engines still have to:
//
// 1. Decide whether an intent is high-consequence
// 2. Construct a `BASSovereignGatedIntent` from name + digest +
//    commit
// 3. Pass it through `Validator.authorize`
//
// Step 1 is what differentiates engines — each engine deployment
// has its own list of high-consequence intent names. M296.2.yy
// makes that list typed (`BASSovereignIntentClassRegistry`) and
// joins it with the validator into one authorization-call entry
// point (`BASSovereignEngineAuthorizationPolicy`).
//
// Engines now adopt M296.2 in one line:
//
// ```swift
// let policy = BASSovereignEngineAuthorizationPolicy(
//     registry: BASSovereignIntentClassRegistry(
//         highConsequenceIntentNames: [
//             "delete-host-version",
//             "freeze-sovereign-policy",
//             ...
//         ]),
//     validator: BASSovereignGatedIntentValidator(gate: gate))
//
// // Per-intent:
// let ok = policy.authorize(
//     intentName: "delete-host-version",
//     intentDigest: digest,
//     commit: maybeCommit)
// ```
//
// ## Doctrine
//
// - **Engine doesn't know dual-key details.** Policy hides
//   gate / verifier / commit shape; engine just asks
//   "authorize this intent name with this digest + maybe commit".
// - **Registry is configuration.** Each deployment registers its
//   high-consequence intent names; routine intents are anything
//   not in the registry. Empty registry = everything routine
//   (sane default for staging / development).
// - **Codable registry.** Hosts can ship registry as static
//   config (JSON / plist / etc.) without code change.
// - **Both auths return Bool, no throw.** Engine branches on
//   the Bool; throwing here would muddle policy with
//   exception-handling.

public struct BASSovereignIntentClassRegistry:
    Sendable, Equatable, Hashable, Codable
{
    /// Names of intents this engine deployment treats as
    /// high-consequence. Anything not in this set is routine.
    public let highConsequenceIntentNames: Set<String>

    public init(
        highConsequenceIntentNames: Set<String> = []
    ) {
        self.highConsequenceIntentNames =
            highConsequenceIntentNames
    }

    /// Classify an intent name. Returns `.highConsequence`
    /// when the name is in the registry; otherwise `.routine`.
    public func classify(
        intentName: String
    ) -> BASSovereignIntentClass {
        highConsequenceIntentNames.contains(intentName)
            ? .highConsequence
            : .routine
    }
}

public struct BASSovereignEngineAuthorizationPolicy: Sendable {
    public let registry: BASSovereignIntentClassRegistry
    public let validator: BASSovereignGatedIntentValidator

    public init(
        registry: BASSovereignIntentClassRegistry,
        validator: BASSovereignGatedIntentValidator
    ) {
        self.registry = registry
        self.validator = validator
    }

    /// Authorize an intent end-to-end. Routine intents (not in
    /// registry) pass without commit; high-consequence intents
    /// require valid dual-key commit + matching digest.
    public func authorize(
        intentName: String,
        intentDigest: Data,
        commit: BASSovereignDualKeyCommit?
    ) -> Bool {
        let intentClass = registry.classify(
            intentName: intentName)
        let intent = BASSovereignGatedIntent(
            intentName: intentName,
            intentClass: intentClass,
            intentDigest: intentDigest,
            dualKeyCommit: commit)
        return validator.authorize(intent)
    }
}
