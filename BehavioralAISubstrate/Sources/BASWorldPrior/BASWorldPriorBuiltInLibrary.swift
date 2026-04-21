import Foundation

/// Built-in content for the world-prior vault. Covers the 8 domains
/// required by §9.3 (physics / body / time / money / social / language
/// / learning / ethics) with 20 causal templates and 8 cross-domain
/// bridges.
///
/// This is the minimum viable "understands the world" surface — it is
/// *not* a general-purpose causal knowledge base. Scope is deliberately
/// narrow: everyday reasoning about a personal-assistant-class brain.
/// Callers may and should extend the vault at boot with additional
/// templates from signed manifests; the built-in set exists so that a
/// newly-initialized brain is never *empty* on world priors.
///
/// ## Calibration principles
///
/// 1. Templates are written so each either survives adversarial pressure
///    or declares its weakness via `evidence < .wellSupported`.
/// 2. `.axiomatic` is reserved for physical invariants and mathematical
///    truths — NOT for social norms, which are `.plausible` at best.
/// 3. Reversibility is rated from the affected party's perspective, not
///    the actor's. "I said something hurtful" is `.costly` (the
///    listener may forgive but not forget); "I sent a payment" is
///    `.bounded` (chargebacks exist).
public enum BASWorldPriorBuiltInLibrary {

    // MARK: - Axioms (BoundaryBedrock)

    public static let axioms: [BASWorldPriorAxiom] = [
        .init(
            id: "axiom-physics-gravity",
            domain: .physics,
            statement: "Unsupported objects fall in a gravitational field."
        ),
        .init(
            id: "axiom-physics-conservation",
            domain: .physics,
            statement: "Matter and energy are not created or destroyed in closed classical systems."
        ),
        .init(
            id: "axiom-time-arrow",
            domain: .time,
            statement: "Past events cannot be unmade by later choices in the actor's frame."
        ),
        .init(
            id: "axiom-body-sleep-required",
            domain: .body,
            statement: "Humans require periodic sleep to maintain baseline cognitive function.",
            evidence: .wellSupported
        ),
        .init(
            id: "axiom-ethics-consent",
            domain: .ethics,
            statement: "Irrevocable consequences on another person require their informed consent.",
            evidence: .axiomatic
        )
    ]

    // MARK: - Causal templates (20 total, grouped by domain)

    // Physics (2)
    public static let physicsTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-physics-fall",
            domain: .physics,
            preconditions: ["object lacks support", "object within gravitational field"],
            effect: "Object accelerates toward ground.",
            effectKind: .physicalChange,
            blockers: ["object is buoyant in medium", "upward external force present"],
            reversibility: .bounded,
            latency: .immediate,
            evidence: .axiomatic
        ),
        .init(
            id: "tmpl-physics-heat-dissipation",
            domain: .physics,
            preconditions: ["hot object in cooler medium"],
            effect: "Thermal energy transfers until equilibrium.",
            effectKind: .physicalChange,
            blockers: ["perfect insulation", "continuous reheating"],
            reversibility: .bounded,
            latency: .gradual,
            evidence: .axiomatic
        )
    ]

    // Body (3)
    public static let bodyTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-body-sleep-debt",
            domain: .body,
            preconditions: ["repeated nights of undersleep"],
            effect: "Reaction time, mood regulation, and error rate degrade.",
            effectKind: .stateTransition,
            blockers: ["genetic short-sleeper variant (rare)"],
            reversibility: .bounded,
            latency: .cumulative,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-body-hydration",
            domain: .body,
            preconditions: ["water intake below maintenance"],
            effect: "Cognitive performance and headache frequency worsen.",
            effectKind: .stateTransition,
            blockers: [],
            reversibility: .trivial,
            latency: .prompt,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-body-exercise-mood",
            domain: .body,
            preconditions: ["moderate aerobic exertion"],
            effect: "Short-term mood elevation via endorphin release.",
            effectKind: .stateTransition,
            blockers: ["injury", "overtraining state"],
            reversibility: .trivial,
            latency: .prompt,
            evidence: .plausible
        )
    ]

    // Time (2)
    public static let timeTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-time-deadline-compression",
            domain: .time,
            preconditions: ["fixed deadline", "scope underestimated"],
            effect: "Quality, scope, or wellbeing of actor is sacrificed.",
            effectKind: .stateTransition,
            blockers: ["early scope reduction", "surge of additional capacity"],
            reversibility: .costly,
            latency: .gradual,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-time-sunk-cost",
            domain: .time,
            preconditions: ["significant prior investment", "no future value on completion"],
            effect: "Actor over-weights continuation against evidence.",
            effectKind: .informationShift,
            blockers: ["explicit cost/value re-evaluation"],
            reversibility: .bounded,
            latency: .gradual,
            evidence: .wellSupported
        )
    ]

    // Money (3)
    public static let moneyTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-money-budget-deplete",
            domain: .money,
            preconditions: ["spend exceeds income"],
            effect: "Reserves draw down; runway shortens.",
            effectKind: .valueTransfer,
            blockers: ["new income stream", "expense cut"],
            reversibility: .bounded,
            latency: .cumulative,
            evidence: .axiomatic
        ),
        .init(
            id: "tmpl-money-compounding",
            domain: .money,
            preconditions: ["capital invested at positive real return", "time elapses"],
            effect: "Value grows super-linearly.",
            effectKind: .valueTransfer,
            blockers: ["drawdown", "inflation outpacing return"],
            reversibility: .bounded,
            latency: .cumulative,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-money-irreversible-transfer",
            domain: .money,
            preconditions: ["funds sent via non-reversible rail (crypto, wire past recall)"],
            effect: "Control of funds transfers permanently.",
            effectKind: .valueTransfer,
            blockers: ["counterparty voluntarily refunds"],
            reversibility: .irreversible,
            latency: .immediate,
            evidence: .axiomatic
        )
    ]

    // Social (3)
    public static let socialTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-social-trust-decay",
            domain: .social,
            preconditions: ["promise broken without repair"],
            effect: "Counterparty's baseline trust decays.",
            effectKind: .relationshipChange,
            blockers: ["explicit acknowledgement and repair"],
            reversibility: .costly,
            latency: .gradual,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-social-hurtful-utterance",
            domain: .social,
            preconditions: ["sharp statement delivered in loaded context"],
            effect: "Listener retains affective memory of the statement.",
            effectKind: .relationshipChange,
            blockers: [],
            reversibility: .costly,
            latency: .immediate,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-social-reciprocity",
            domain: .social,
            preconditions: ["unprompted favor extended"],
            effect: "Counterparty feels mild obligation to reciprocate.",
            effectKind: .relationshipChange,
            blockers: ["favor framed as transactional", "relationship already strained"],
            reversibility: .trivial,
            latency: .prompt,
            evidence: .plausible
        )
    ]

    // Language (2)
    public static let languageTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-language-ambiguity-loss",
            domain: .language,
            preconditions: ["utterance with multiple plausible interpretations", "listener under cognitive load"],
            effect: "Listener latches onto one interpretation; alternatives are lost.",
            effectKind: .informationShift,
            blockers: ["explicit disambiguation before listener commits"],
            reversibility: .bounded,
            latency: .immediate,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-language-framing-effect",
            domain: .language,
            preconditions: ["identical content wrapped in different frames"],
            effect: "Listener evaluates the same proposition differently.",
            effectKind: .informationShift,
            blockers: ["listener does meta-analysis of framing"],
            reversibility: .bounded,
            latency: .immediate,
            evidence: .wellSupported
        )
    ]

    // Learning (3)
    public static let learningTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-learning-spacing",
            domain: .learning,
            preconditions: ["material revisited with spaced intervals"],
            effect: "Long-term retention improves vs. massed practice.",
            effectKind: .skillGainOrLoss,
            blockers: ["intervals shorter than forgetting curve demands", "no retrieval attempt made"],
            reversibility: .bounded,
            latency: .cumulative,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-learning-active-retrieval",
            domain: .learning,
            preconditions: ["learner attempts recall before looking up"],
            effect: "Subsequent retention strengthens more than passive review.",
            effectKind: .skillGainOrLoss,
            blockers: ["learner gives up before productive struggle"],
            reversibility: .bounded,
            latency: .cumulative,
            evidence: .wellSupported
        ),
        .init(
            id: "tmpl-learning-skill-atrophy",
            domain: .learning,
            preconditions: ["skill unused for extended period"],
            effect: "Fluency degrades; reacquisition is faster than cold learning.",
            effectKind: .skillGainOrLoss,
            blockers: ["intermittent refresher"],
            reversibility: .bounded,
            latency: .cumulative,
            evidence: .wellSupported
        )
    ]

    // Ethics (2)
    public static let ethicsTemplates: [BASWorldPriorCausalTemplate] = [
        .init(
            id: "tmpl-ethics-consent-violation",
            domain: .ethics,
            preconditions: ["irreversible consequence imposed on another", "informed consent absent"],
            effect: "Harm obligation accrues to the actor.",
            effectKind: .relationshipChange,
            blockers: ["emergency preserving life with no feasible alternative"],
            reversibility: .irreversible,
            latency: .immediate,
            evidence: .axiomatic
        ),
        .init(
            id: "tmpl-ethics-delegated-responsibility",
            domain: .ethics,
            preconditions: ["actor delegates action to agent they knew was unfit"],
            effect: "Actor retains responsibility for downstream outcomes.",
            effectKind: .relationshipChange,
            blockers: [],
            reversibility: .costly,
            latency: .gradual,
            evidence: .wellSupported
        )
    ]

    public static var allTemplates: [BASWorldPriorCausalTemplate] {
        physicsTemplates
        + bodyTemplates
        + timeTemplates
        + moneyTemplates
        + socialTemplates
        + languageTemplates
        + learningTemplates
        + ethicsTemplates
    }

    // MARK: - 8 Domain bridges

    public static let bridges: [BASWorldPriorDomainBridge] = [
        // 1. body ↔ money: fatigue ↔ budget depletion
        .init(
            id: "bridge-body-to-money",
            sourceDomain: .body,
            targetDomain: .money,
            analogy: "Sleep debt accrues like budget overspend — daily deficits compound.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-body-sleep-debt",
                      targetTemplateID: "tmpl-money-budget-deplete")
            ],
            evidence: .plausible
        ),
        // 2. learning ↔ money: spaced practice ↔ compounding
        .init(
            id: "bridge-learning-to-money",
            sourceDomain: .learning,
            targetDomain: .money,
            analogy: "Spaced retrieval compounds like invested capital — small consistent inputs, super-linear payoff.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-learning-spacing",
                      targetTemplateID: "tmpl-money-compounding")
            ],
            evidence: .wellSupported
        ),
        // 3. social ↔ money: trust decay ↔ budget depletion (both drain reserves)
        .init(
            id: "bridge-social-to-money",
            sourceDomain: .social,
            targetDomain: .money,
            analogy: "Broken promises draw down a trust reserve like unbudgeted spend.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-social-trust-decay",
                      targetTemplateID: "tmpl-money-budget-deplete")
            ],
            evidence: .plausible
        ),
        // 4. language ↔ ethics: framing ↔ delegated responsibility (both shift moral weight)
        .init(
            id: "bridge-language-to-ethics",
            sourceDomain: .language,
            targetDomain: .ethics,
            analogy: "Framing choices shift moral weight like delegated responsibility shifts accountability.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-language-framing-effect",
                      targetTemplateID: "tmpl-ethics-delegated-responsibility")
            ],
            evidence: .plausible
        ),
        // 5. time ↔ body: deadline pressure ↔ sleep debt
        .init(
            id: "bridge-time-to-body",
            sourceDomain: .time,
            targetDomain: .body,
            analogy: "Deadline compression trades tomorrow's body for today's scope, same as sleep debt.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-time-deadline-compression",
                      targetTemplateID: "tmpl-body-sleep-debt")
            ],
            evidence: .plausible
        ),
        // 6. physics ↔ money: heat dissipation ↔ irreversible transfer
        .init(
            id: "bridge-physics-to-money",
            sourceDomain: .physics,
            targetDomain: .money,
            analogy: "Heat dissipation to environment parallels funds leaving a reversible rail — both tend toward equilibrium you can't easily undo.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-physics-heat-dissipation",
                      targetTemplateID: "tmpl-money-irreversible-transfer")
            ],
            evidence: .speculative
        ),
        // 7. learning ↔ body: skill atrophy ↔ exercise mood fade
        .init(
            id: "bridge-learning-to-body",
            sourceDomain: .learning,
            targetDomain: .body,
            analogy: "Unused skills atrophy on the same timescale as missed exercise dampens baseline mood.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-learning-skill-atrophy",
                      targetTemplateID: "tmpl-body-exercise-mood")
            ],
            evidence: .speculative
        ),
        // 8. social ↔ language: hurtful utterance ↔ ambiguity loss (both lock in listener state)
        .init(
            id: "bridge-social-to-language",
            sourceDomain: .social,
            targetDomain: .language,
            analogy: "A hurtful utterance locks in the listener's affective reading the same way ambiguity loss locks in one interpretation.",
            templatePairings: [
                .init(sourceTemplateID: "tmpl-social-hurtful-utterance",
                      targetTemplateID: "tmpl-language-ambiguity-loss")
            ],
            evidence: .plausible
        )
    ]

    // MARK: - Horizon assembly

    /// Build the per-domain horizons from the flat lists above.
    /// Horizons carry only axioms and templates; bridges are attached
    /// via a second pass at bootstrap time so that cross-domain
    /// targets already exist when each bridge is validated.
    public static func horizons() -> [BASWorldPriorHorizon] {
        var templatesByDomain: [BASWorldPriorDomain: [BASWorldPriorCausalTemplate]] = [:]
        var axiomsByDomain: [BASWorldPriorDomain: [BASWorldPriorAxiom]] = [:]

        for tmpl in allTemplates {
            templatesByDomain[tmpl.domain, default: []].append(tmpl)
        }
        for ax in axioms {
            axiomsByDomain[ax.domain, default: []].append(ax)
        }
        // Bridges are returned separately — see `bridgesByDomain()`.
        // Note: we still include every domain even if it has no
        // templates of its own, so bridge sources always find their
        // horizon.
        let bridgeDomains = Set(bridges.map(\.sourceDomain))
        let allDomains: Set<BASWorldPriorDomain> =
            Set(templatesByDomain.keys)
            .union(axiomsByDomain.keys)
            .union(bridgeDomains)

        return allDomains
            .sorted { $0.rawValue < $1.rawValue }
            .map { domain in
                BASWorldPriorHorizon(
                    domain: domain,
                    axioms: axiomsByDomain[domain] ?? [],
                    templates: templatesByDomain[domain] ?? [],
                    bridgesOutbound: []
                )
            }
    }

    /// Load the built-in library into a vault. Registers every
    /// horizon (axioms + templates) first, then registers the
    /// bridges once all cross-domain targets are known to the vault.
    public static func bootstrap(into vault: BASWorldPriorVault) async throws {
        for horizon in horizons() {
            try await vault.registerHorizon(horizon)
        }
        for bridge in bridges {
            try await vault.registerBridge(bridge)
        }
    }
}
