# Failed Deep Scan Incomplete-Draft Leads

> **Status: incomplete coverage evidence only.** None of these rows is added to
> the recovered 68-row terminal aggregate. They were recovered from emitted
> `complete:false` drafts, child finals, or failed replacement arguments and
> have not been revalidated against source.

## discovery-0011

The last acknowledged draft contained 10 findings and 9 surfaces. A historical
read proved `result.json` existed at 159,503 bytes before the directory later
disappeared.

1. Response cap follows transport buffering —
   `BASChatCompletionsOrganAdapter.swift:145-173` and streaming `:185-199`.
2. Paired HumanEval executes generated Python outside its sibling sandbox —
   `qinao_humaneval_paired.py:92-104`, `qinao_humaneval.py:6-42`,
   `qinao_sandbox.py:23-31`.
3. Combined release gate ignores pending attestations —
   `build_verdict.py:135-142`, `release_gate.py:239-289`.
4. Predictable unauthenticated metric side-files feed verdict construction —
   `qinao_merge.py:49-96`, `build_verdict.py:12-19`, `run_ladder.sh:7-24`.
5. Caller-selected text log is accepted as substrate-test proof —
   `release_gate.py:58-97,220-248`.
6. Empty or underspecified manifest hashes are accepted —
   `release_gate.py:43,151-170`.
7. Apple FM evaluation uses predictable `/tmp` chunk paths —
   `SampleHostAppleFMExtensions.swift:420-432,462-512,705-718` and
   `main.swift:583-594`.
8. StateLake metadata is unauthenticated and unbounded —
   `BASStateLakeReader.swift:28-68`.
9. Multiple Rust FFI parsers reserve from count fields before validation —
   `bas-tokenizer/src/lib.rs:538-558`,
   `bas-integrity-sentinel/src/lib.rs:377-407`,
   `bas-event-log-codec/src/lib.rs:475-495`,
   `bas-red-team-bench/src/lib.rs:721-752`, and
   `bas-retrieval-ranker/src/lib.rs:665-689,1703-1722`.
10. An unverified commit token can be upgraded into authority —
    `BASSovereignCommitEnforcer.swift:44-73`,
    `BASSovereignGatedCommit.swift:31-81`,
    `BASSovereignTokenAuthority.swift:243-310`, and
    `EBrainControlPlaneCore.swift:675-714`.

Explicit deferred leads included cross-runtime action-bundle replay, halt state
lost on restart, and the remote adapter’s advertised input cap not being
enforced. Raw child containers also preserved unreconciled leads for broad
sandbox reads, missing HumanEval resource quotas, API keys in argv,
future-issued-token TTL bypass, snapshot/host-version binding, halt/rollback
revocation, public `clearHalt`, audit-append failure, unbounded Git output,
unbounded subject/import input, and terminal control characters.

## discovery-0012

The last acknowledged draft contained 2 findings and 5 surfaces. Its baseline
child was lost to a transport failure.

1. Default audit schema signs a non-injective delimiter encoding —
   `BASSovereignEd25519Signing.swift:140-201`,
   `BASSovereignAuditLedger.swift:282-292`,
   `BASSovereignLedgerStorage.swift:937-970`, and
   `QinaoSovereign.swift:1938-1960`.
2. Rehydrated audit history can be read before lazy integrity verification —
   `BASSovereignAuditLedger.swift:332-417,631-717` and
   `QinaoSovereign.swift:1095-1115`.

The draft deferred a structural-only external-warrant upgrade pending host
signature verification:
`BASSovereignWarrantChain.swift:23-45,55-89,173-268,294-347` and
`BASExternalAgentA2A.swift:107-110`.

## discovery-0013

The only acknowledged draft contained zero findings and four coverage surfaces.
All three child sessions ended in transport failures. Its coverage evidence
preserved four unresolved signals:

- unauthenticated commit-token registration —
  `BASSovereignCommitEnforcer.swift:48-65` and control-plane registration paths;
- malformed StateLake metadata — `BASStateLakeReader.swift:48-68` and the
  device probe `:45-60`;
- a native C-ABI parser accepting trailing bytes —
  `bas-sovereign-c-abi/src/lib.rs:289-359`; and
- non-streaming response buffering —
  `BASChatCompletionsOrganAdapter.swift:145-173`.

A later six-candidate replacement added commit replay across restart and broad
model-code sandbox reads, but it failed schema validation because `findings`
was absent and a coverage surface lacked `label`. No retry exists, so those
additions have no `draft_written` acknowledgement.

## discovery-0014

The last acknowledged draft contained 2 findings and 5 surfaces.

1. Model-derived tool calls can reach registered handlers without the SDK
   side-effect authorization gate — `BASToolDispatcher.swift:43-53,225-243`,
   `BASToolPromptRenderer.swift:61-73`, `BASToolCallingPlanner.swift:287-299`,
   with expected control at `QinaoRuntime.swift:176-184`.
2. Response caps do not bound transport or individual SSE-line buffering —
   `BASChatCompletionsOrganAdapter.swift:145-173` and streaming `:167-199`.

Deferred themes were: model tool calls not bound to the advertised tool set or
schema; inconsistent domain-restriction matching; cooperative deadlines that
cannot stop handlers; unbounded concurrent batch fan-out; API keys in process
arguments; and legacy model downloads without integrity/authenticity checks.

## Handling rule

These leads must first be deduplicated against the terminal 68 rows and then
validated on the intended current branch. A matching title, CWE, subsystem, or
sink is insufficient for a merge; remediation must subsume every retained
source/control/sink/impact tuple.
