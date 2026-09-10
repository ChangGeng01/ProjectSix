# Quality Gate 200

Before should ultimately be judged against a `200`-standard apex bar.

This is not the day-to-day release gate. It is the full operating-system-grade standard library for a local-first cognition product. The executable `20 / 20` gate is the current floor; this document is the ceiling we keep climbing toward.

## 001-010 Runtime Integrity

- `Q001` Cold boot must reach a runnable intelligence state without hidden network dependence.
- `Q002` Runtime routing must be deterministic for identical state, budget, and capability inputs.
- `Q003` Every request must have an explicit runtime gear before provider selection begins.
- `Q004` Circuit-breaker state must be consulted before any provider is attempted.
- `Q005` Runtime downgrade must preserve task intent, not just return any fallback text.
- `Q006` No request may bypass admission control and jump straight into a model path.
- `Q007` Runtime strategy must remain serializable for replay and inspection.
- `Q008` A degraded runtime path must still produce a valid user-facing result envelope.
- `Q009` Runtime configuration errors must fail closed, not silently choose arbitrary defaults.
- `Q010` Identical runtime inputs must produce the same provider shortlist order.

## 011-020 Prefill And TTFT

- `Q011` Quick mode must optimize for first-token latency before decode throughput.
- `Q012` Balance mode must have its own TTFT budget instead of inheriting Quick defaults.
- `Q013` Mirror mode must surface a measured TTFT even when the total latency is acceptable.
- `Q014` Prefill cost must be tracked separately from decode cost in telemetry.
- `Q015` Optional context must be dropped before required anchors when prompt budget is tight.
- `Q016` Prompt suggestions must only run when cache warmth indicates low incremental prefill cost.
- `Q017` Tool metadata must count against prefill budget instead of hiding off-book.
- `Q018` Runtime compaction must trigger before a request overruns its first-token budget.
- `Q019` A change in debug copy must never perturb runtime prefill fingerprints.
- `Q020` First-token regressions must be treated as product regressions, not mere performance noise.

## 021-030 Context And KV Discipline

- `Q021` Every mode must have a bounded frontstage context budget.
- `Q022` Persona anchors must survive compaction before any optional evidence survives.
- `Q023` Duplicate evidence must be removed before provider prompting.
- `Q024` Stale context must not be revived simply because tags happen to overlap.
- `Q025` UI copy, debug scaffolding, and tool receipts must never enter the long-lived runtime prefix.
- `Q026` Long outputs must not automatically become future context without governance.
- `Q027` Session continuity must be rebuilt from state, not by replaying raw transcripts.
- `Q028` Context lifecycle expiration must be mode-aware rather than global.
- `Q029` Brain-state restoration must be stable under repeated rebuilds from the same inputs.
- `Q030` Corrupted prior state must be dropped rather than contaminating the next frontstage.

## 031-040 Structured Output And Tool Envelopes

- `Q031` All model-assisted actions must land in a schema-checked envelope.
- `Q032` Invalid structured output must trigger repair or deterministic fallback, never silent acceptance.
- `Q033` Tool schemas must be injected on demand instead of living in the base prompt.
- `Q034` Unsupported tools must stay invisible to providers that cannot use them safely.
- `Q035` Tool-call count must be explicitly budgeted per request.
- `Q036` Output character budget must be enforced as a real runtime guardrail.
- `Q037` Structured envelopes must preserve deterministic actions even when language refinement changes.
- `Q038` Schema versions must be tracked so prompt and consumer stay compatible across releases.
- `Q039` Tool outputs must be redacted or summarized before they re-enter model context.
- `Q040` Action space must be explicit per mode, not inferred from freeform text.

## 041-050 Provider Capability Registry

- `Q041` Each provider must declare strengths, weaknesses, latency class, and memory class.
- `Q042` Language support must be explicit, not guessed from a model name.
- `Q043` Structured-output support must be a routable capability, not an assumption.
- `Q044` Thinking support must be modeled separately from general generation quality.
- `Q045` A pinned provider must still be rejected if it cannot satisfy the active task contract.
- `Q046` Open-model adapters must swap without changing business logic identifiers.
- `Q047` Provider routing must be capability-first, not family-name-first.
- `Q048` Cooldown and circuit-breaker states must demote providers before quality scoring happens.
- `Q049` Mixed-language tasks must prefer providers explicitly marked compatible.
- `Q050` Provider ranking must remain explainable in runtime traces.

## 051-060 Retrieval And Semantic Cache

- `Q051` Retrieval must be optional, not default-on for uncertainty.
- `Q052` A retrieval judge must filter evidence before it reaches the language layer.
- `Q053` Retrieval sources must carry provenance, trust, and freshness metadata.
- `Q054` Semantic cache entries must be validated before write and before reuse.
- `Q055` Cache poisoning defenses must reject suspicious high-overlap hostile payloads.
- `Q056` Retrieval top-k must adapt to task needs instead of staying globally fixed.
- `Q057` Control-only turns must skip retrieval entirely.
- `Q058` Retrieval misses, blocks, and quarantine reasons must be observable.
- `Q059` Cache keys must reflect semantic task state, not cosmetic prompt variation.
- `Q060` Stale low-trust evidence must lose frontstage eligibility before higher-trust evidence does.

## 061-070 Memory Governance

- `Q061` Long-term memory writes must enter a candidate pool before promotion.
- `Q062` Memory maintenance must support add, update, delete, and noop.
- `Q063` User-confirmed memory must decay slower than inferred memory.
- `Q064` Reflection-derived memory must decay faster than repeated-behavior memory.
- `Q065` Contradictory memories must remain unresolved until evidence breaks the tie.
- `Q066` Pending memories must have a bounded grace window.
- `Q067` Situational memories must not silently promote into identity memories.
- `Q068` Memory consolidation must be asynchronous whenever possible.
- `Q069` Every promoted memory must be traceable to its source and last confirmation time.
- `Q070` Users must be able to remove long-term memory without database surgery.

## 071-080 Privacy And Storage Boundaries

- `Q071` Sensitive in-progress state must never live in generic `UserDefaults`.
- `Q072` Shared app-group storage must be restricted to public-safe or sealed payloads.
- `Q073` Widget surfaces must never render raw user-authored reminder text.
- `Q074` Launch handoff must not pass raw prompts through generic shared defaults.
- `Q075` Production traces must not retain raw prompts or raw model previews.
- `Q076` Exported runtime snapshots must omit raw cognitive content by default.
- `Q077` Protected local state must use file protection appropriate for sensitive drafts.
- `Q078` Corrupted protected state must be quarantined, not repeatedly retried.
- `Q079` Sensitive state must age out under explicit retention rules.
- `Q080` Logs must default to privacy-safe redaction even on failure paths.

## 081-090 Recovery And Continuity

- `Q081` Restoring an evaluated workspace must restore a sealed result snapshot, not re-evaluate.
- `Q082` Expired runtime state must be discarded instead of silently revived.
- `Q083` Task-graph continuity must be restored alongside workspace continuity.
- `Q084` Resume must be idempotent across repeated app launches.
- `Q085` Recovery must remain possible even if the preferred provider is unavailable.
- `Q086` Destructive state transitions must checkpoint before mutation.
- `Q087` Rewind must restore both work state and associated cognitive metadata.
- `Q088` App termination during write must preserve the last known-good snapshot.
- `Q089` Recovery failure must degrade explicitly, not crash or silently fork history.
- `Q090` Continuity verification must be observable in testing and runtime exports.

## 091-100 Hooks, Policy, And Permissions

- `Q091` Mandatory lifecycle behavior must live in deterministic hooks or policy code, not prompt prose.
- `Q092` Permissions must distinguish read, write, execute, network, and share operations.
- `Q093` Policy must support allow, ask, and deny semantics.
- `Q094` Dangerous actions must default to deny until positively allowed.
- `Q095` Pre-tool hooks must be able to redact or block unsafe parameters.
- `Q096` Post-tool hooks must sanitize output before it can pollute memory or context.
- `Q097` Pre-compaction hooks must preserve critical state before summarization.
- `Q098` Memory-write hooks must be able to veto low-quality writes.
- `Q099` Policy violations must emit structured telemetry.
- `Q100` Test overrides must require explicit opt-in rather than hidden environment magic.

## 101-110 Task Graph And Plans

- `Q101` Task graphs must live outside the model context.
- `Q102` Task nodes must have explicit lifecycle states such as pending, in-progress, and completed.
- `Q103` Successful plans must be cached separately from one-off answers.
- `Q104` Failed plans must be retained as anti-patterns, not discarded as noise.
- `Q105` Subtasks must not orphan when the parent task is restored.
- `Q106` Plan templates must preserve user constraints when reused.
- `Q107` Plan cache invalidation must happen when policy or capability assumptions change.
- `Q108` Plan execution cost must be measurable per template family.
- `Q109` Similar successful plans should distill into reusable strategy templates over time.
- `Q110` A task graph restore must not require the model to remember its own pending work.

## 111-120 Multilingual And Multimodal Core

- `Q111` Internal memory objects must use language-neutral structure whenever possible.
- `Q112` Response language must derive from live task state, not only device locale.
- `Q113` Mixed-script prompts must receive explicit language/script tagging.
- `Q114` Retrieval language and answer language must be modeled separately.
- `Q115` Multimodal signals must be represented structurally instead of ballooning prompt text.
- `Q116` Missing multimodal inputs must degrade gracefully without changing system personality.
- `Q117` JSON, tool, and memory schemas must remain internally canonical across languages.
- `Q118` Provider routing must block language-incompatible models before generation starts.
- `Q119` Multilingual users must not experience personality drift after language switches.
- `Q120` Language-detection uncertainty must be observable and influence routing conservatively.

## 121-130 Device, Battery, And Thermal Adaptation

- `Q121` Low-battery mode must reduce thinking, retrieval, and output budgets.
- `Q122` Thermal pressure must downshift runtime gear before the OS forces a harsher failure.
- `Q123` Low-memory devices must avoid heavy providers by policy, not by accident.
- `Q124` Simulator and physical-device execution profiles must be explicitly distinct.
- `Q125` Offline mode must disable external dependencies without breaking core flows.
- `Q126` Background mode must prefer checkpointing over ongoing heavy inference.
- `Q127` Foreground restore must not automatically replay expensive computation if a sealed result exists.
- `Q128` Gear shifts must be logged and testable.
- `Q129` Hardware capability snapshots must be reusable across requests within reason.
- `Q130` Energy-saving adaptation must preserve system stance and trust, not just shorten output.

## 131-140 Observability And Telemetry

- `Q131` TTFT must be recorded per request.
- `Q132` Prefill size must be recorded separately from total context size.
- `Q133` Total latency must be split into retrieval, provider, and post-processing segments.
- `Q134` Tool-call counts must be tracked per turn.
- `Q135` Retrieval item counts must be tracked per turn.
- `Q136` Cache hit and miss rates must be split by prompt cache, response cache, and semantic cache.
- `Q137` Budget breaches must be captured as first-class telemetry, not inferred later.
- `Q138` Degraded-mode reasons must be explicit in telemetry.
- `Q139` Recovery source and fallback tier must be visible in runtime export.
- `Q140` Privacy-sensitive telemetry must default to redacted payloads.

## 141-150 Determinism And Flake Resistance

- `Q141` UI smoke must be repeat-run, not single-run.
- `Q142` Recovery tests must be repeatable without hidden simulator state.
- `Q143` Seed data must be resettable between tests.
- `Q144` Clock-driven logic must be injectable under test.
- `Q145` Randomness must be seeded or eliminated in deterministic test paths.
- `Q146` Model stubs must produce stable outputs across repeated runs.
- `Q147` Tests must not depend on shared mutable singleton residue.
- `Q148` Quarantine and corruption paths must be covered by dedicated tests.
- `Q149` Missing entitlements and missing app-group containers must be represented in tests.
- `Q150` A passing gate must leave the worktree clean.

## 151-160 Adversarial And Security Standards

- `Q151` Prompt-injection markers must be filtered before they become memory or evidence.
- `Q152` Retrieval corruption must be treated as a first-class attack surface.
- `Q153` Semantic cache poisoning must have detection and quarantine paths.
- `Q154` Suspicious tool parameter payloads must be blocked before execution.
- `Q155` Malformed shared payloads must be quarantined instead of retried indefinitely.
- `Q156` Untrusted imported memory must not auto-promote into long-term brain state.
- `Q157` Unsafe markup and HTML-like content must be stripped from evidence inputs.
- `Q158` Repeated expensive-path abuse must trigger rate-limiting or degradation.
- `Q159` Security fallback text must remain calm, generic, and non-leaking.
- `Q160` Security failures must not dump sensitive state to logs or exports.

## 161-170 Migration And Corruption Handling

- `Q161` State objects must carry explicit schema versions.
- `Q162` Legacy generic-defaults payloads must be scrubbed rather than trusted.
- `Q163` Migrations must be idempotent.
- `Q164` Partial migration failure must degrade to a recoverable path, not crash.
- `Q165` Corrupted state must move to quarantine before a new clean state is written.
- `Q166` Persistence fallback tiers must be observable.
- `Q167` Bootstrap must never rely on `fatalError` as the final persistence policy.
- `Q168` Save failures must surface as issues, not disappear behind `try?`.
- `Q169` Recovery stores must be rebuildable after corruption.
- `Q170` Migration coverage must include regression tests for both success and failure branches.

## 171-180 Interaction And UX Quality

- `Q171` Quick outputs must stay brief enough to feel like an interruption aid, not a lecture.
- `Q172` Balance outputs must foreground the core tradeoff rather than verbose synthesis.
- `Q173` Mirror outputs must stay honest without sliding into melodrama.
- `Q174` Widget copy must remain non-exposing even after legacy snapshot migration.
- `Q175` Low-power mode copy must become shorter without becoming colder.
- `Q176` Cache hits must not create duplicated or stale visible suggestions.
- `Q177` Restored sessions must feel continuous to the user, not regenerated.
- `Q178` Side-question or bypass queries must not pollute the main decision thread.
- `Q179` Empty states and degraded states must be actionable rather than vague.
- `Q180` User-visible fallbacks must preserve the same product philosophy as ideal paths.

## 181-190 Release And Rollback Readiness

- `Q181` Project generation must be reproducible from source control.
- `Q182` Project metadata listing must remain healthy after generation.
- `Q183` Release-grade gates must be documented in-repo, not only in chat.
- `Q184` Gate scripts must match the documented scorecard exactly.
- `Q185` Persisted state changes must have a rollback story.
- `Q186` Generated artifacts needed for a passing build must not remain accidentally untracked.
- `Q187` Smoke evidence must remain inspectable through stored xcresult bundles.
- `Q188` A branch must not be pushed as healthy without passing the documented gate.
- `Q189` The gate itself must be versioned and reviewable like product code.
- `Q190` Release quality must be enforceable without tribal knowledge.

## 191-200 Self-Healing And Evolution

- `Q191` Circuit-breakers must cool providers down and allow later recovery.
- `Q192` Response caches must quarantine suspicious entries instead of serving them repeatedly.
- `Q193` Memory trust must evolve based on source quality and reconfirmation.
- `Q194` Stale pending memories must age out before they can dominate current brain state.
- `Q195` Runtime must degrade to template or deterministic mode without semantic collapse.
- `Q196` Plan and task templates must be updatable without destructive migration.
- `Q197` Sensitive runtime state must expire under explicit retention policies.
- `Q198` Brain-state verification snapshots must remain stable for identical inputs.
- `Q199` Storage faults must still permit a reduced but coherent user experience.
- `Q200` Every self-healing path that exists in production must have at least one regression test.
