# Qinao W0 Safety Freeze and Production K4 Proof Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Starting only from the admitted `preW0` seal and the C0-reviewed `C3` import rows, form an immutable W0 payload that freezes every currently reachable Provider/runtime/effect/App-Agent/persona/memory/recognition/learning split-brain hazard, then obtain a real iOS 27 physical-device K4 proof before the protected bootstrap lineage is allowed to create W0 `Cw`, `Sw`, or admission.

**Architecture:** W0 is a fail-closed safety boundary, not an early implementation of W1-W6. It imports reviewed source bytes through C0's destination CAS, adds source/reachability/fixture gates that use only APIs present at W0, and records no result inside `Pw`. The complete W0 source, schema, checker, test, fixture, probe source, and build-input bytes are committed and frozen as one immutable `Pw` commit/tree before K4 begins. The candidate supplies only that exact commit OID to the Bootstrap-owned `ProtectedAdmissionClient`; after a fresh `PayloadDispatchAuthorizationV1`, Bootstrap pins and independently reopens the object before issuing a signed lease. K4 is a controller-side `ExternalPhysicalGate` ceremony: a lease-bound broker selects Xcode/profile/team, archive, physical iOS 27 device, encrypted custody, and two distinct producer/attester principals; the broker binds archive and device before creating a fresh challenge, drives structured `devicectl`, transfers the raw bundle to external encrypted custody, and requires an independent short-lived reopen. The B0 primitive consumes only the broker's signed privacy-clean projection. Starting from the authenticated gate-result bundle, one idempotent Bootstrap operation first derives evidence-only `Cw` and one-receipt `Sw` in a non-host quarantine, stops for a fresh `ProtectedRefAdvanceAuthorizationV1`, and only on the same-key post-authorization invocation imports/reopens those exact objects at the target Git host, performs protected CAS, and finalizes admission. Candidate code creates none of those current-run objects, refs, leaves, commit identities, or authority messages.

**Tech Stack:** Python 3 standard library and `unittest`; Swift 6/XCTest/Swift Testing; Git object/index/ref plumbing; canonical JSON and SHA-256; Xcode 27 release toolchain; ExtensionFoundation/ExtensionKit/XPC public SDK; `xcodebuild`, `codesign`, `security cms`, `xcrun devicectl` JSON output; externally authenticated encrypted evidence custody; no new dependency, package install, private framework, or network search.

## Global Constraints

- Approved design commit: `59c26f508262d7c25869faac0ec0abf968ec1e02`.
- Approved design path: `docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md`.
- Approved design SHA-256: `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
- Approved dynamic-graph amendment: commit `9d484befb4a4593d93789457ebddfd7cde358e3b`, path `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`, blob `e2c59656f9eb184efc3ab933fe442c9dd0b7d507`, SHA-256 `5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5`.
- Governed-learning source: `docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md`, especially §3, §4.12, and §5.
- Governed-learning source SHA-256: `e14375de67f7baf9bfe9c4e466b1182fbe906f849da0e260a37bd8bbd6554079`.
- Adopted candidate root: `/Users/changgeng/.codex/worktrees/e4d7/Project06`.
- Candidate branch: `codex/qinao-w1-clean-candidate`.
- Preserved dirty source root: `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0`. It is read-only during execution.
- Every W0 or K4 candidate-root entry begins with the literal root command below. It must print exactly one canonical JSON line with exactly the sorted keys `candidate_lineage`, `head_commit`, `head_tree`, `schema_version`; `candidate_lineage` is `reparentedProgram`; `schema_version` is integer `1`; mismatch exits `2`.

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
```

- The root command is necessary but not sufficient. Immediately after it, independently reopen the admitted `preW0` receipt, its finalized external attestation, the fixed original forensic ref, the one content-addressed preparation ref, `B0`, and the reparented `preW0 Pw`; prove they describe the same tuple. The audited 22-commit tip is not required to remain an ancestor after legal B0→Pw reparenting.
- `reparentedProgram` means: approved base is an ancestor; `refs/qinao-forensics/clean-candidate-22-commit-tip-20260723` equals `486e1ec5983ad4390c5b07f04607f1345b912c4c`; exactly one ref beneath `refs/qinao-forensics/prew0-preparation/` exists and its suffix equals its target OID; the preparation tree equals reparented `preW0 Pw` tree; reparented `Pw` has sole parent `B0`. Any other shape exits `2`.
- No command in this plan accepts a caller-supplied wave, gate list, verifier, module, build profile, Xcode path, team ID, provisioning profile, signing identity, device ID, challenge, success flag, external evidence root, or release status as authority.
- W0 uses only APIs present in W0. It does not call or test future `executeAtMostOnce`, `TurnOperation.stream().final()`, `spool`, App-Agent root/session, Artifact Mesh, K3/K4 production-owner, W5 helper, W6 certification, or cutover APIs.
- W0 may make an unsafe current production seam unreachable, internal, test/lab/shadow-only, or deterministically fail closed. It may not declare a future capability implemented.
- `Pw` contains source, schemas, checkers, tests, fixtures, candidate parity/preflight K4 producer/attester/state-machine bytes, K4 probe source, exact build inputs, and policy manifests. Candidate K4 tools exercise contract compatibility only; they are never active producer, attester, broker, verifier, or authority. The authoritative W0 open set is the self-contained B0 `w0_open_set_v1_exact_set` program over exact indexed `Pw`; candidate receipt series and raw probe logs are never emitted or consumed. The two imported sequence-zero JSON files remain non-authoritative parser fixtures only, and the separately locked superseded non-series silicon baseline remains immutable historical input rather than current authority. Exact preW0 Cw/Sw/admission evidence may remain only as byte-identical inherited predecessor state proven by the authenticated seal. `Pw` contains no current-W0 result claiming itself, reachability/K4 result, archive, device trace, external bundle receipt, release projection, W0 `Cw`/`Sw`, or W0 admission claim.
- `Cw` is an evidence-only one-parent child of exact W0 `Pw`. `Sw` is a
  one-receipt one-parent child of `Cw`. Only the externally bootstrapped
  admission service may first derive and close their exact bytes in non-host
  quarantine, publish the bound advance-authorization request, stop until a
  fresh `ProtectedRefAdvanceAuthorizationV1` is persisted and reopened, and
  only then import/reopen those exact objects at the target host. No step may
  combine non-host construction with a target-host effect.
- Raw archive/IPA/app/appex/Mach-O, embedded profile/CMS, entitlements dump, signing certificate chain, raw CDHash, Team ID, profile UUID, device identifier, challenge, `devicectl` JSON/logs, app container, XPC trace, custody token, encryption key, or reopen grant never enters Git.
- The preliminary `docs/superpowers/evidence/qinao-k4-platform-spike/` is not production evidence. Its source mechanisms may be migrated only through reviewed C3 rows; its logs, local signatures, beta-toolchain result, blocked device run, and marker text are never copied into an approved proof.
- The 2026-07-19 CoreAI convergence plan is non-authoritative. Its corrected mechanics may guide implementation only after re-deriving them from the approved design and this plan. It is never named as an executable prerequisite, authority, gate source, or evidence source.
- K4 missing infrastructure is not a test skip and not a local pass. The Bootstrap controller-side `ExternalPhysicalGate` returns the authenticated terminal `BLOCKED_K4`, writes no Git evidence, creates no W0 `Cw`/`Sw`, and does not invoke assembly/finalization.
- iOS deployment floor is 27 everywhere. K4 requires a release Xcode 27 toolchain and a physical device whose OS major is 27.
- All Python tests use `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v`; no `pytest`.
- Every Swift filter runs through `scripts/run_nonempty_swift_filter.py`; zero discovered tests is failure.
- Every commit stages an exact path list, compares that list before commit, and leaves a clean worktree. Never use broad `git add .`, `git add -A`, reset, checkout, restore, clean, amend, rebase, squash, or force-update.
- Every checkbox below is one 2–5 minute action. Stop at the first unexpected output; do not reinterpret a RED or blocker as success.
- Every multi-line fenced Bash block, including a single command split across
  continuation lines, begins with `set -euo pipefail`. An expected nonzero
  command uses only a tightly bounded `set +e`, captures its exact return code
  and output, and immediately restores `set -euo pipefail`. In those blocks,
  `git status`, `git diff`, and `git rev-list` output is never
  tested directly through command substitution: first capture and validate the
  Git return code, then test the captured bytes.

### Mandatory graph-spec re-entry

Tasks 2, 4, 11, and 12 are graph-bearing entry/freeze points. At every fresh
session or restart, each task runs these commands after its Root Guard and
before reading or changing a graph-bearing byte:

```bash
set -euo pipefail
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
```

A missing object, wrong blob, wrong digest, replacement object, or nonzero
exit is `BLOCKED_SOURCE_DRIFT`. A prose pin in this header is not execution
evidence.

## Approved Dynamic Graph W0 Freeze Amendment

The authoritative W0 hazard set remains closed at exactly 16 IDs. Do not add
a graph hazard ID and do not implement any future graph contract or behavior.
Extend only the incumbent `runtime.untyped-shared-agent-state` hazard across
its existing source, production-reachability, fixture, and negative-token
coverage.

That one hazard must reject every currently reachable form of:

- a second G1 or G2 graph writer, mutable graph patcher, graph manager,
  graph scheduler, or graph store;
- a Main-Agent/Sub-Agent direct peer call or writable shared scratchpad;
- legacy loop authority that can schedule, retry, remand, or commit outside
  the four existing ControlRings and governed Attempt boundary;
- graph-shaped production entrypoints that bypass App-Agent/session identity,
  Context Compiler, K3 allocation, authorization/effect gates, or receipts.

The W0 fixture set contains one positive incumbent shape and one negative
fixture per category above. Its source scan first proves each selected file is
a readable regular file; missing/renamed input exits 2. Its reachability proof
must classify `BASAppleTaskGraphLifecycleExecutor.refresh` as either
demonstrably read-only or production-unreachable. “Name sounds lifecycle”,
test-only reachability, and an unclassified edge are failures.

W0 freezes these seams only. It does not create `BASSemanticTurnDAG`, G1/G2
wires, graph execution, shadow comparison, cutover, or future-wave tests. The
existing `qinao.w0-open-set` module and closed 16-ID manifest remain the sole
authoritative gate.

### Exact W0 task insertion and fixtures

This plan consumes the reconstruction master's W0 row and returns only the
existing immutable W0 `Pw`/K4/admission handoffs. It neither pulls W1 work
forward nor changes the master wave order.

| Existing task | Added W0-only work |
|---|---|
| Task 2 | Extend only the existing `runtime.untyped-shared-agent-state` row; freeze the exact graph token/fixture matrix in `scripts/test_check_qinao_w0_safety.py`; byte-compare it with B0's indexed `scripts/qinao_gate_modules/v0/corpora/w0_open_set.json` |
| Task 4 | Consume the Task-2 contract/tests read-only and close actual source plus transitive production reachability for second writers, peer calls, scratchpads, legacy loop authority, and `refresh` |
| Task 11 | Run full safety, reachability, nonempty-suite and exact-set closure before freezing `Pw` |
| Tasks 12-14 | Carry the unchanged 16-ID policy into exact `Pw`; accept only B0's `qinao.w0-open-set` result |

The authoritative B0 corpus remains
`scripts/qinao_gate_modules/v0/corpora/w0_open_set.json`. It is predecessor
input, never a W0 edit. Its positive object contains the exact ordered
`graph_freeze_cases` rows below beneath the existing
`runtime.untyped-shared-agent-state` safety row. Its existing missing-suite and
zero-match objects remain the sole outer negative/mutation cases. Task 2
reopens the indexed corpus, rejects a missing/extra/reordered graph row, and
compares the canonical graph-case-array SHA-256 with the identical in-test
fixture. Candidate tests are parity evidence; only B0's
`w0_open_set_v1_exact_set` evaluates the authoritative corpus.

`scripts/test_check_w0_expected_open_set.py` remains a compatibility-parser
regression for the two locked sequence-zero fixtures. This graph amendment
does not modify it, does not add a successor receipt, and never treats it as
`qinao.w0-open-set`.

The exact Task-2 graph case inventory is:

| Ordered test method in `W0SafetyContractTests` | Fixture ID | Single mutation or accepted fact | Exact result |
|---|---|---|---|
| `test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id` | `graph.incumbent-owner.v1` | all graph tokens and reachability predicates are attached to `runtime.untyped-shared-agent-state` | pass; graph hazard IDs equal `["runtime.untyped-shared-agent-state"]` |
| `test_graph_freeze_keeps_exact_sixteen_ids` | `graph.seventeenth-id.v1` | append only `runtime.graph-authority` | reject `qinao.w0-safety.safety-id-set-drift` |
| `test_second_g1_writer_is_rejected` | `graph.second-g1-writer.v1` | activate symbol `BASW0SecondG1Writer` and call `qinaoW0CommitSemanticGraph` in the shipping fixture | reject `runtime.untyped-shared-agent-state:second-g1-writer` |
| `test_second_g2_writer_is_rejected` | `graph.second-g2-writer.v1` | activate symbol `BASW0SecondG2Writer` and call `qinaoW0CommitTaskGraph` in the shipping fixture | reject `runtime.untyped-shared-agent-state:second-g2-writer` |
| `test_main_sub_peer_call_is_rejected` | `graph.main-sub-direct-peer.v1` | activate call `qinaoW0MainCallsSubDirectly` | reject `runtime.untyped-shared-agent-state:main-sub-direct-peer-call` |
| `test_sub_sub_peer_call_is_rejected` | `graph.sub-sub-direct-peer.v1` | activate call `qinaoW0SubCallsPeerSubDirectly` | reject `runtime.untyped-shared-agent-state:sub-sub-direct-peer-call` |
| `test_shared_mutable_scratchpad_is_rejected` | `graph.shared-scratchpad.v1` | activate mutable symbol `BASW0SharedMutableAgentScratchpad` | reject `runtime.untyped-shared-agent-state:shared-mutable-agent-scratchpad` |
| `test_legacy_loop_authority_is_rejected` | `graph.legacy-loop-authority.v1` | activate `BASW0LegacyLoopAuthority.qinaoW0RetryOutsideAttempt` | reject `runtime.untyped-shared-agent-state:legacy-loop-authority` |
| `test_refresh_must_be_read_only_or_production_unreachable` | `graph.refresh-classification.v1` | remove the sole classification from the incumbent `BASAppleTaskGraphLifecycleExecutor.refresh` edge | reject `runtime.untyped-shared-agent-state:unclassified-task-graph-refresh`; the same test separately accepts each of the two exact legal positive shapes below |
| `test_future_graph_contract_is_rejected_at_w0` | `graph.future-contract.v1` | activate declaration `BASSemanticTurnDAG` in a shipping source root | reject `runtime.untyped-shared-agent-state:future-graph-contract-at-w0` |

The strings above are synthetic scanner fixtures, never W0 production
declarations. The `runtime.untyped-shared-agent-state` row appends exactly:

```text
forbidden_active_symbols:
  BASW0SecondG1Writer
  BASW0SecondG2Writer
  BASW0SharedMutableAgentScratchpad
  BASW0LegacyLoopAuthority
  BASSemanticTurnDAG
forbidden_active_calls:
  qinaoW0CommitSemanticGraph
  qinaoW0CommitTaskGraph
  qinaoW0MainCallsSubDirectly
  qinaoW0SubCallsPeerSubDirectly
  qinaoW0RetryOutsideAttempt
forbidden_reachability:
  second-g1-writer
  second-g2-writer
  main-sub-direct-peer-call
  sub-sub-direct-peer-call
  shared-mutable-agent-scratchpad
  legacy-loop-authority
  future-graph-contract-at-w0
  unclassified-task-graph-refresh
```

For that one hazard row, `positive_fixture` is exactly
`graph.incumbent-owner.v1`; `negative_fixture` is the umbrella
`graph.freeze-mutation-matrix.v1`, whose ordered children are the remaining
fixture IDs in the table. `required_suites` retains only the two already-frozen
Swift W0 suite IDs, preserving B0's exact 13 suite rows; the Python class is
candidate parity coverage and is never serialized as a fourteenth B0 suite.
No other hazard row gains a graph fixture, token, or suite.

Each mutation fixture is an in-memory temporary repository constructed by
`scripts/test_check_qinao_w0_safety.py`: one regular `Package.swift`, one
shipping target/source root, one regular Swift source, one release entrypoint,
and the incumbent positive row. It changes exactly the table cell named above.
The same token placed only in a Swift comment, ordinary/raw/multiline string,
or test-only target is a non-match. Missing/symlinked source, package, or
entrypoint is exit `2`, never a clean zero-match. No additional fixture path is
created in Git.

In the incumbent reachability fixture,
`BASAppleTaskGraphLifecycleExecutor.refresh` must have exactly one of:

```text
classification = readOnly
classification = productionUnreachable
```

`readOnly` requires zero writes, CAS, scheduling, retry, remand, commit,
publication, tool/effect dispatch, shared scratchpad mutation, and Provider
invocation across the transitive production call graph.
`productionUnreachable` requires no shipping product/factory/DI/call/link
path. A test/lab-only label without build/link closure is insufficient.

Task 2 runs the ten methods by fully qualified name, so a renamed or absent
method is a load error rather than a passing module with old tests:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_keeps_exact_sixteen_ids \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g1_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g2_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_main_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_sub_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_shared_mutable_scratchpad_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_legacy_loop_authority_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_refresh_must_be_read_only_or_production_unreachable \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_future_graph_contract_is_rejected_at_w0
```

GREEN expected: `Ran 10 tests`, `OK`, exactly 16 IDs, and all ten literal
method names in verbose output. RED uses the same exact selector list and must
report `Ran 10 tests` before failing only on
`qinao.w0-safety.unimplemented`. Missing source, a zero-match scan,
unclassified `refresh`, or a seventeenth ID is a structural W0 failure; none
may be recorded as `BLOCKED_K4`.

### Session and interruption re-entry

No task relies on shell variables surviving an old session. At every new shell, after the exact root guard and applied-lineage verifier, rederive the local comparison values:

```bash
set -euo pipefail
PREW0_PW="$(python3 -c 'import json; print(json.load(open("/private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json"))["new_payload_oid"])')"
PREW0_PW_TREE="$(git rev-parse "$PREW0_PW^{tree}")"
PREW0_SW="$(git rev-parse refs/heads/qinao-admitted)"
```

Before Task 12, call `ProtectedAdmissionClient.reopen_admitted_predecessor()` immediately and replace the provisional `PREW0_SW` value only with the service-envelope-verified `seal_commit_oid`; compare its independently authenticated payload commit/tree/seal to all three values and then require the protected ref equals it. After Task 12, never rederive `PREW0_SW` from the mutable canonical ref. Retain the originally reopened opaque `AdmittedWaveV1`, rederive the candidate-local payload only from the clean frozen `HEAD`, and verify it against the service-envelope-verified lease:

```bash
set -euo pipefail
W0_PW="$(git rev-parse HEAD)"
W0_PW_TREE="$(git rev-parse "$W0_PW^{tree}")"
set +e
W0_REENTRY_STATUS="$(git status --porcelain=v1)"
W0_REENTRY_STATUS_RC="$?"
set -euo pipefail
test "$W0_REENTRY_STATUS_RC" = 0
test -z "$W0_REENTRY_STATUS"
```

The candidate never creates a payload ref. Bootstrap's separately authorized content-addressed pin and lease carry the authoritative payload commit/tree and predecessor binding. A missing candidate object, failed external pin, failed host reopen, absent service authentication, or inconsistent object/tree terminates as `BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`; it is never reclassified as K4 absence. A crash before a candidate commit restarts the current task from its first guard. A crash after Bootstrap may have pinned or finalized asks the owning service to inspect exact already-applied state; it never repeats a write from memory, chooses “latest,” deletes an output, or manufactures a recovery receipt.

## Phase Boundary and Required Upstream Interface

The bootstrap plan owns all admission types and the closed, signed `ReleaseProfileBinding` carried in `EvaluationLease.selected_release_profiles`. This plan imports the opaque types from the Bootstrap service binding; it neither mirrors a dataclass/schema nor creates a second authority.

W0 does not enumerate or validate that binding's wire fields. It retains only
the Bootstrap schema/binding digest and lets the active B0 modules require a
Release iphoneos arm64 build with deployment/device floor iOS 27, one signed
Xcode 27 identity, and separately bound host/helper bundle, entitlement,
profile, and signing identities. A global/swapped profile or caller-selected
team/toolchain/device fails inside Bootstrap; no W0 parser can reinterpret it.

- The signed lease is issued by the bootstrap admission service after it derives `W0` from admitted `preW0`; candidate bytes cannot add, remove, or choose a row.
- The lease also references one Bootstrap-owned opaque `ExternalPhysicalGateBinding`, which binds the external custody profile, distinct K4 producer and attester identities, retention/destruction policy, controller/broker identity, and physical-device policy. It carries commitments and public policy fields, never a raw device ID or secret.

The bootstrap-owned protected runner exposes the following exact client surface to W0 without adding a repository owner:

```text
ProtectedAdmissionClient.reopen_admitted_predecessor() -> AdmittedWaveV1
ProtectedAdmissionClient.pin_payload_and_issue_lease(
    payload_oid: str
) -> tuple[PayloadProposalReceiptV1, EvaluationLease]
ProtectedAdmissionClient.run_active_gates(
    lease: EvaluationLease
) -> AuthenticatedGateResultBundle
ProtectedAdmissionClient.assemble_import_and_finalize(
    lease: EvaluationLease,
    gate_results: AuthenticatedGateResultBundle
) -> AdmittedWaveV1
```

`AdmittedWaveV1`, `PayloadProposalReceiptV1`, `EvaluationLease`,
`ExternalPhysicalGateBinding`, and `AuthenticatedGateResultBundle` are opaque
Bootstrap imports.
`PayloadDispatchAuthorizationV1` and
`ProtectedRefAdvanceAuthorizationV1` are separately signed, short-lived,
append-only Bootstrap-service records. They are not client arguments or
candidate JSON, and W0 never receives authority by copying their projections.
W0 may compare documented read-only projections, but cannot define, mirror,
subclass, serialize, or construct any of them. `AuthenticatedGateResultBundle`
is emitted only by the protected B0 runner and binds the lease, immutable
payload, active gate set, ordered gate-result digests, exact output-contract
digest, physical-gate projection, and runner/service envelope. The candidate
cannot construct, edit, or supplement it.

Opaque values are deliberately not local checkpoints. On process/session
restart, the candidate reruns the immutable root guard, reopens the admitted
predecessor, freshly rederives exact clean `W0_PW/W0_PW_TREE`, and calls
`pin_payload_and_issue_lease(W0_PW)` again. Bootstrap's idempotency key binds
repository, admitted predecessor, and payload; it must return the original
authenticated proposal receipt and original opaque lease/evaluation when that
logical pin already exists. The verification adapter proves those values bind
the service's existing record before `run_active_gates(lease)` performs only
query/resume. This is neither a new lease nor permission to repeat an effect.

`assemble_import_and_finalize` is one idempotent generic service operation with
one assembly identity, even when authorization separates its invocations. Its
first invocation may derive every Cw/Sw leaf and exact Git object in a
non-host quarantine, then stop before target-host import with
`BLOCKED_EXTERNAL_BOOTSTRAP/CEREMONY_UNAVAILABLE` while the service control
plane obtains a fresh `ProtectedRefAdvanceAuthorizationV1`. A later invocation
with the same lease and byte-identical bundle reopens the same assembly
identity and authorization; only then may it import/reopen the bound objects at
the target Git host, create the one import receipt and admission intent,
perform the protected CAS, and finalize the external attestation. It never
constructs a second Cw/Sw or exposes a fifth client method. Candidate code
supplies no evidence leaf, commit message, author, committer, timestamp,
parent, path, mode, blob, object pack, Cw/Sw OID, receipt, intent, CAS input,
authorization record, or final-attestation field.

These are the only service operations visible to W0. If the client surface or
signed service binding is absent/incomplete, stop with
`BLOCKED_EXTERNAL_BOOTSTRAP`; if payload authorization, object transfer, pin,
or host reopen is absent/incomplete, stop with
`BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`. Do not emulate either path locally.

Every serialized nonfinal outcome uses Bootstrap's closed
`AdmissionTerminalError`. A bare `BLOCKED_*` name in explanatory prose denotes
the terminal class only; the emitted value also carries its required exact
registry reason. `pendingAdmission` alone carries null.

## File Responsibility Map

### C3-reviewed imports and W0 safety

| Path | Responsibility |
|---|---|
| `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json` | C0-stable source inventory; read only |
| `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json` | Operator-reviewed source-stratum and destination-batch decisions; read only |
| `scripts/qinao_execution_root.py` | Permanent exact-root and `reparentedProgram` lineage guard |
| `scripts/apply_qinao_import_map.py` | C0 destination-CAS prepare/apply mechanism |
| `docs/superpowers/specs/qinao-w0-safety-freeze-v1.json` | Closed W0 hazard, allowed seam, forbidden seam, suite, and source-graph contract |
| `scripts/check_qinao_w0_safety.py` | Comment/string-safe source and production-graph freeze checker |
| `scripts/test_check_qinao_w0_safety.py` | Positive, negative, mutation, symlink, missing-root, zero-discovery, and exact ten-case graph-freeze parity tests |
| `scripts/qinao_gate_modules/v0/corpora/w0_open_set.json` | Verify-only B0 authority corpus; exact 13 suites, 16 IDs, and ordered ten-case graph array |
| `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASW0SafetyFreezeTests.swift` | Current-API fail-closed behavior and access-control tests |
| `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoW0SafetyFreezeTests.swift` | Qinao boundary, stream, secret, persona, recognition, and fail-closed tests |

### Learning and Main/Sub contracts

| Path | Responsibility |
|---|---|
| `docs/superpowers/specs/qinao-learning-legacy-disposition-v1.json` | Exact 12-row §4.12 policy and production entrypoint/symbol inventory |
| `docs/superpowers/specs/qinao-learning-legacy-reachability-v1.schema.json` | Closed result schema; results are generated only after `Pw` |
| `scripts/check_qinao_learning_legacy_reachability.py` | Transitive build/AST/SIL/index/linked-symbol reachability analyzer and compare-only verifier |
| `scripts/test_check_qinao_learning_legacy_reachability.py` | Exact-12, missing/extra, direct/indirect/reflection/factory/source-gate mutation tests |
| `docs/superpowers/specs/qinao-learning-causal-fixture-v1.schema.json` | Closed causal order, split lineage, veto, holdout, canary, field, adoption, and invalidation schema |
| `scripts/check_qinao_learning_causal_fixtures.py` | Fixture exact-set and ordering checker |
| `scripts/test_check_qinao_learning_causal_fixtures.py` | Positive and every-adjacent-swap/omission/alias/stale-CAS negative test |
| `scripts/fixtures/qinao-learning-causal-v1/positive.json` | Full legal causal chain |
| `scripts/fixtures/qinao-learning-causal-v1/negative-*.json` | One closed mutation per rejected condition |
| `docs/superpowers/specs/qinao-main-sub-envelope-fixture-v1.schema.json` | Low-entropy per-field Main/Sub artifact envelope and correlation contract |
| `scripts/check_qinao_main_sub_envelopes.py` | Envelope, capsule, store reachability, and correlation checker |
| `scripts/test_check_qinao_main_sub_envelopes.py` | Positive, per-field, correlation, shared-cache, scratchpad, peer-call, and raw-store negatives |
| `scripts/fixtures/qinao-main-sub-envelope-v1/positive.json` | Independent-capsule positive fixture |
| `scripts/fixtures/qinao-main-sub-envelope-v1/negative-*.json` | Exact mutation set |

### Candidate K4 parity/preflight tooling and Bootstrap-owned production gate

| Path | Responsibility |
|---|---|
| `docs/superpowers/specs/qinao-k4-production-run-v1.schema.json` | Candidate parity schema for the broker's closed run-state contract; never service authority |
| `docs/superpowers/specs/qinao-k4-private-bundle-manifest-v1.schema.json` | Candidate parity schema for encrypted raw-bundle/retention/cleanup obligations; never custody authority |
| `docs/superpowers/specs/qinao-k4-public-projection-v1.schema.json` | Candidate parity schema for the privacy-clean projection; never Cw-leaf authority |
| `scripts/qinao_k4_protocol_v1.py` | Canonical value types, closed parsing, domains, state machine, and redaction classifier |
| `scripts/test_qinao_k4_protocol_v1.py` | Parser/state/digest/privacy/ordering mutation tests |
| `scripts/qinao_k4_custody_v1.py` | Pure in-memory/frame-codec parity model for the Bootstrap-owned encrypted-custody protocol; no production transport/capability |
| `scripts/test_qinao_k4_custody_v1.py` | Short-frame, replay, wrong-root, expired-grant, reopen, retention, destruction, cleanup, and no-authority tests |
| `scripts/test_qinao_k4_probe_source.py` | C3 provenance, exact-path, authority-input, challenge, trace, and marker-negative tests |
| `scripts/capture_k4_platform_proof.py` | Candidate parity producer state-machine adapter; fixture/preflight only |
| `scripts/test_capture_k4_platform_proof.py` | Candidate parity sequence, command, structured-output, and no-authority tests |
| `scripts/attest_k4_external_artifact.py` | Candidate parity attester for synthetic external-reopen fixtures only |
| `scripts/test_attest_k4_external_artifact.py` | Parity independence, reopen, recomputation, mismatch, cleanup, and destroyed-bundle tests |
| `scripts/run_k4_platform_proof.py` | Candidate parity state-machine simulator; never launched by the active gate |
| `scripts/test_run_k4_platform_proof.py` | End-to-end fake-process/custody parity tests without claiming physical proof |
| `scripts/check_k4_platform_proof.py` | Hardened fixture/parity validation and production-projection compare-only modes; never current authority |
| `scripts/test_check_k4_platform_proof.py` | Reject marker/log/source/fixture/caller challenge/offline trace/legacy CLI fiction |
| `scripts/fixtures/qinao-k4-checker-v1/valid-synthetic-test-only.json` | Canonical synthetic fixture accepted only by `--fixture`; never production evidence |
| `scripts/fixtures/qinao-k4-platform-probe/` | Exact 21-path privacy-clean public-API probe source and generated metadata |
| Bootstrap `ExternalPhysicalGate` broker | Sole production request builder/orchestrator; launches distinct attested producer and attester, owns encrypted custody/reopen/cleanup, emits signed privacy-clean projection to the B0 primitive |

### Evidence-only outputs

| Path | Responsibility |
|---|---|
| `docs/superpowers/evidence/qinao-learning-legacy-reachability-W0.json` | Cw-only actual 12-row transitive reachability result bound to `Pw` |
| `docs/superpowers/evidence/qinao-k4-platform-proof-W0.json` | Cw-only privacy-clean K4 projection bound to `Pw` and external root |
| The 13 exact W0 gate-result files enumerated literally in Task 14 Step 3 | Cw-only active B0 gate results, each regular mode `100644`; no wildcard or directory authority |
| `docs/superpowers/evidence/qinao-wave-admission/W0-cw-manifest.json` | Cw-only self-excluding exact evidence manifest |
| `docs/superpowers/evidence/qinao-wave-admission/W0.json` | Sw-only one receipt |

## Closed W0 Contract

### Hazard families

`qinao-w0-safety-freeze-v1.json` contains exactly these 16 IDs in UTF-8 byte order:

```text
app-agent.raw-app-agent-continuity
app-agent.raw-main-agent-continuity
app-agent.raw-persona-authority
app-agent.recognition-unproven
effect.direct-production-dispatch
learning.direct-adopt-distill-export-promote-write
memory.self-populating-authority
model.false-afm-certification-accounting
provider.argv-or-raw-header-secret
provider.concrete-runtime-in-qinao-sdk
provider.same-call-fallback
release.stream-then-regenerate
runtime.raw-unbounded-public-stream
runtime.synthetic-execution-success
runtime.untyped-shared-agent-state
state.split-brain-authority
```

Each row has exactly:

```text
id
owner_id
production_roots
source_roots
allowed_current_seams
forbidden_active_symbols
forbidden_active_calls
forbidden_reachability
required_suites
positive_fixture
negative_fixture
disposition
```

The checker rejects an absent root before scanning, symlinks, non-UTF-8 Swift, raw-regex syntax it cannot lex safely, duplicate IDs, a zero production-root set, a zero discovered symbol/call set, missing suites, comments/strings treated as code, or any new active path not classified.

W0 dispositions are exact:

- Provider selection may compute an ordered proposal, but one invocation receives exactly one already-selected Provider. The existing list-loop API may remain as a compatibility/test mechanism only if production call graph cannot reach a count greater than one; W0 does not invent `executeAtMostOnce`.
- Public streaming is unavailable in production W0 unless it is one bounded view over the same single Provider operation and exact final bytes. The existing `streamBody` plus subsequent `generateCandidates` recipe is test/lab only.
- `BASOrganRequest.sessionID` and `personaInstructions` cannot carry Session/App-Agent/Self authority. Production builders pass `nil`; any non-`nil` path is test/lab-only and source-gated. W0 does not invent future App-Agent roots.
- `BASCognitiveBrain+Construction.resolveMemoryService` passes `selfPopulate: false` in both branches. Explicit owner-admitted writes remain future work.
- Recognition completion is mechanically `guestOnlyMechanicallyEnforced`. Relationship-specific rendering and recognition-dependent memory are unreachable.
- AFM/Core AI capability is observation-only. No Provider is certified, selected, or charged as AFM from a model name, import, manifest claim, or successful proposal.
- The remote adapter accepts a secret resolver/capability handle only from host composition; public endpoint values cannot persist arbitrary authorization headers. `QinaoSampleHost` has no `--api-key`, no key in argv, and no printed Authorization value. Local fixture headers are non-production.
- A current production effect without durable broker evidence returns its typed unavailable/indeterminate terminal without calling the legacy closure.
- A command without actuator evidence is `.skipped`/unmeasured, never successful.
- Compatibility, demo, benchmark, migration, and shadow seams are explicit non-shipping products or source-gated compile conditions; prose labels do not count.

### Exact 12-row learning legacy policy

`qinao-learning-legacy-disposition-v1.json` has `schema_version = 1`, both exact source SHA-256 values above, and exactly the following rows:

| ID | Exact mechanism | W0 disposition |
|---|---|---|
| `L01` | `BASDistillationBank` | Non-authoritative compatibility projection or retired; never dataset, truth, eligibility, export, or promotion owner |
| `L02` | `BASAppleInterventionBanditAdvisor` / `BASAppleInterventionBanditSnapshot` | Fixture/mechanism-only or retired; never Policy-A, Evidence-B, reward truth, routing owner, or adaptive-state mouth |
| `L03` | `QinaoLearningExporter` / `QinaoMemory.LearningExportBundle` | Production denied until exact typed manifest/current-policy/minimization/destination-purpose/transfer contracts exist |
| `L04` | `BASUpdateTicketLifecycleCoordinator` | Plain `approveForDistillation`/`markDistilled` production mouths source-gated; projection/client of future K3 lifecycle or retired |
| `L05` | `BASEvolutionLifecycleStage`/`Action`/`Policy`/`Session`, including `.promoted` | Atomically map to future L13/certification/cutover or fence from production |
| `L06` | `BASTrainingDataExporter` | Developer diagnostic over separately authorized synthetic fixtures only; never governed export |
| `L07` | `BASTrainingExampleSublimator` | Projection/demo only or retired; cannot create membership, truth, split, reward, or trainer authority |
| `L08` | `EBrainRuntimeCoordinator+EvolutionGovernance` learning bundles and `BASDistillation*Ingest` | Hard-coded favorable Booleans and same-turn pseudo-shadow fenced; retained as negative fixtures only |
| `L09` | `BASRetractionFurnace` | Compatibility projection only or retired; no retraction, recovery, cleanup, or cutover authority |
| `L10` | `BASMemorySleepConsolidationPass` / `BASSleepConsolidationDriver` | Forced projection/dry-run; no mutation until canonical memory adoption/commit owner exists |
| `L11` | Qwen3.5 capability manifest/MTP seams versus Qinao MLX facade | Design target only, not current default; requires exact Provider load/caller/release/conversion/runtime/certification evidence |
| `L12` | SampleHost learning/export paths | Negative/non-production fixtures; cannot enter release composition |

Each row additionally freezes exact declaration symbols, factory symbols, direct call symbols, dynamic/reflection spellings, package products, release entrypoints, test/lab conditions, and the one allowed disposition. The result schema requires each row to report discovered declarations, direct callers, transitive release callers, factory/reflection edges, shipping reachability, and evidence digests. The policy lives in `Pw`; the result lives only in `Cw`.

The table is a compact index. In the JSON, each row also carries `reality` and `required_disposition` copied byte-for-byte from the matching §4.12 table cells. Tests extract those 12 source rows from the exact governed-learning bytes, compare mechanism/reality/disposition exact equality, and reject paraphrase, whitespace normalization, reordered mechanisms, a merged/split row, or a different source digest.

### Causal and invalidation fixture contracts

The positive fixture's `stages` are exactly:

```text
causalRootDiscovery
preSplitDuplicateComponentFreeze
splitAssignment
withinSplitCleaning
evaluatorFirewall
hardVeto
paretoSelection
protectedHoldoutOpen
protectedHoldoutEvaluation
e0ToE4Certification
cohortCanaryAdmission
delayedFieldAndDriftEvaluation
e5Certification
separatelySealedAdoption
```

It binds:

- one immutable causal root and one complete exact/semantic duplicate component;
- exactly one split assignment before any within-split cleaning;
- no trainer/candidate access to hidden membership, keys, bytes, evaluator result, or adaptive budget;
- hard-veto vector before Pareto/tie-break;
- holdout identity and stage tag frozen before open;
- E0-E4 before canary; canary before delayed field/E5; E5 before a different full-adoption seal;
- one K3 expected-parent invalidation CAS with exactly the four sorted fanouts:

```text
exposure_eligibility
learning_eligibility
projection
runtime_boundary
```

An invalidation fixture fails if it uses two CAS operations, omits a fanout, makes cleanup asynchronous-before-fence, changes a head after CAS loss, or accepts a late trainer/shadow/field result.

### Main/Sub envelope contract

The only legal cooperation object has exactly:

```text
schema_version
work_unit_id
attempt_id
generation
sender_agent_id
sender_role
recipient_agent_id
recipient_role
artifact_kind
artifact_id
artifact_digest
claim_class
evidence_refs
uncertainty_class
correlation_group_id
independence_basis
created_at
expires_at
```

Rules:

- Main and each Sub Agent have distinct context-capsule IDs and no shared mutable scratchpad, transcript buffer, KV cache, Provider session, implicit peer call, or raw StateLake handle.
- Fields are bounded, low entropy, canonical, purpose-specific, and references-only. `artifact_id` is an immutable typed artifact, not free text.
- Per-field negative fixtures independently mutate every field to missing, extra, wrong type, unbounded, stale, cross-workspace, or credential-shaped as applicable.
- Same `correlation_group_id`, source root, Provider lineage, retrieval root, prompt/template, model session, or derived artifact means correlated evidence. Correlated rows cannot satisfy an independent-consensus threshold.
- Main remains the sole session synthesis lane. Sub Agents return proposals/evidence only and cannot commit state, publish, execute tools, mutate App-Agent data, or call each other.

---

### Task 0: Reopen the Admitted `preW0` Boundary

**Files:**
- Read only: candidate Git objects and refs.
- Read only: `/private/tmp/qinao-bootstrap-ceremony-v1/`.
- Read only: external bootstrap/admission attestation through the protected service.

**Interfaces:**
- Consumes: `reparentedProgram` root, `preW0` protected seal, finalized external attestation.
- Produces: a private runner-local `AdmittedWaveV1` predecessor tuple; no repository byte.

- [ ] **Step 1: Run the exact root guard**

Run from `/Users/changgeng/.codex/worktrees/e4d7/Project06`:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
```

Expected: one canonical JSON line whose exact sorted key set is `candidate_lineage,head_commit,head_tree,schema_version`; values are `reparentedProgram`, actual lowercase Git commit OID, actual lowercase Git tree OID, and integer `1`. Any extra key/output or exit other than `0` stops.

- [ ] **Step 2: Reopen B0 and the applied reparent transaction**

```bash
set -euo pipefail
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-proposal /private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json
python3 scripts/verify_qinao_bootstrap_export.py \
  --request /private/tmp/qinao-bootstrap-ceremony-v1/ceremony-request-v1.json \
  --export-directory /private/tmp/qinao-bootstrap-ceremony-v1/export
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
```

Expected: all three commands exit `0`; the first reports the exact B0 commit/tree, the second validates the external bootstrap signatures, and the third reports `reparentedProgram`.

- [ ] **Step 3: Prove the forensic refs and reparented `preW0 Pw` independently**

```bash
set -euo pipefail
test "$(git rev-parse refs/qinao-forensics/clean-candidate-22-commit-tip-20260723)" = 486e1ec5983ad4390c5b07f04607f1345b912c4c
test "$(git for-each-ref --format='%(refname) %(objectname)' refs/qinao-forensics/prew0-preparation/ | wc -l | tr -d ' ')" = 1
git for-each-ref --format='%(refname:strip=3) %(objectname)' refs/qinao-forensics/prew0-preparation/ |
  awk 'NF == 2 && $1 == $2 {ok=1} END {exit !ok}'
PREW0_PW="$(python3 -c 'import json; print(json.load(open("/private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json"))["new_payload_oid"])')"
PREW0_PW_TREE="$(git rev-parse "$PREW0_PW^{tree}")"
B0="$(python3 -c 'import json; print(json.load(open("/private/tmp/qinao-bootstrap-ceremony-v1/b0-proposal-v1.json"))["b0_oid"])')"
set +e
PREW0_PW_PARENT_LINE="$(git rev-list --parents -n 1 "$PREW0_PW")"
PREW0_PW_PARENT_LINE_RC="$?"
set -euo pipefail
test "$PREW0_PW_PARENT_LINE_RC" = 0
test "$PREW0_PW_PARENT_LINE" = "$PREW0_PW $B0"
PREP="$(git for-each-ref --format='%(objectname)' refs/qinao-forensics/prew0-preparation/)"
test "$(git rev-parse "$PREP^{tree}")" = "$PREW0_PW_TREE"
```

Expected: every assertion exits `0`.

- [ ] **Step 4: Reopen the admitted receipt from the protected ref**

```bash
set -euo pipefail
PREW0_SW="$(git rev-parse refs/heads/qinao-admitted)"
git show "$PREW0_SW:docs/superpowers/evidence/qinao-wave-admission/preW0.json" \
  > /private/tmp/qinao-prew0-admitted-receipt.json
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["admitted_wave"]=="preW0"; assert d["payload_commit_oid"]==sys.argv[2]; assert d["payload_tree_oid"]==sys.argv[3]; assert d["gate_result"]=="passed"' \
  /private/tmp/qinao-prew0-admitted-receipt.json "$PREW0_PW" "$PREW0_PW_TREE"
```

Expected: receipt exists only in `PREW0_SW` and binds exact reparented `Pw`.

- [ ] **Step 5: Have the protected service reopen final admission**

Call `ProtectedAdmissionClient.reopen_admitted_predecessor()`. Require exact equality for:

```text
derived_wave = preW0
payload_commit_oid = PREW0_PW
payload_tree_oid = PREW0_PW_TREE
seal_commit_oid = PREW0_SW
receipt_blob_sha256 = SHA256(the Git receipt blob)
finalized_attestation_digest = independently reopened external attestation
```

Expected: one authenticated `AdmittedWaveV1`. If the service, attestation, or equality proof is absent, print `BLOCKED_EXTERNAL_BOOTSTRAP` and stop before C3 import.

- [ ] **Step 6: Fast-forward the implementation branch to exact admitted `preW0 Sw`**

The current branch must derive W0 from the admitted seal, not from the earlier reparented payload. Run:

```bash
set -euo pipefail
CURRENT="$(git rev-parse HEAD)"
if test "$CURRENT" = "$PREW0_PW"; then
  git merge --ff-only "$PREW0_SW"
elif test "$CURRENT" = "$PREW0_SW"; then
  true
else
  echo "unexpected W0 derivation head: $CURRENT" >&2
  exit 2
fi
test "$(git rev-parse HEAD)" = "$PREW0_SW"
set +e
PREW0_FAST_FORWARD_STATUS="$(git status --porcelain=v1)"
PREW0_FAST_FORWARD_STATUS_RC="$?"
set -euo pipefail
test "$PREW0_FAST_FORWARD_STATUS_RC" = 0
test -z "$PREW0_FAST_FORWARD_STATUS"
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
```

Then reopen `AdmittedWaveV1` again and require its seal equals current `HEAD`. Expected: a fast-forward only, no merge commit, and all preW0 Cw/Sw evidence is now in W0 ancestry.

---

### Task 1: Apply Only the Reviewed C3 Rows Through Destination CAS

**Files:**
- Read: C0 inventory.
- Modify and commit before import:
  `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`.
- Create outside Git: `/private/tmp/qinao-c3-source-import-plan.json`.
- Modify/create: only exact rows whose map `decision` is `import` and `destination_batch` is `C3`.

**Interfaces:**
- Consumes: admitted preW0 handoff plus stable inventory and reviewed C3 rows.
- Produces: one exact-path C3 import commit; no C4/K4 result or raw private artifact.

- [ ] **Step 1: Re-run root and predecessor guards**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
```

Then independently call `ProtectedAdmissionClient.reopen_admitted_predecessor()` and compare the complete `PREW0_PW/PREW0_PW_TREE/PREW0_SW` tuple. Expected: exact root and admitted predecessor remain unchanged.

- [ ] **Step 2: Review and freeze the exact 20-row C3 source slice**

C0 initially left every row at `hold`; admitted preW0 now carries the
unchanged reviewed C1+C2 groups while every C3 row remains `hold`. Execute
Bootstrap Task 1A Step 8 at this exact clean, admitted-preW0 descendant:
freeze the fixed C3 context,
obtain the external two-person record, persist/reopen its append-only object,
and authenticate its immutable receipt. Then require:

```bash
set -euo pipefail
set +e
C3_PRE_REVIEW_STATUS="$(git status --porcelain=v1)"
C3_PRE_REVIEW_STATUS_RC="$?"
set -euo pipefail
test "$C3_PRE_REVIEW_STATUS_RC" = 0
test -z "$C3_PRE_REVIEW_STATUS"
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C3
```

Expected: exactly one opaque `VerifiedImportReviewV1` for C3, twenty rows,
and one authenticated reopen receipt. The operators must compare and approve
exactly these 20 public API/probe-source paths before any import:

```text
docs/superpowers/evidence/qinao-k4-platform-spike/spike/Extension/K4SpikeExtension.entitlements
docs/superpowers/evidence/qinao-k4-platform-spike/spike/Extension/K4SpikeExtension.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/Host/K4SpikeHost.entitlements
docs/superpowers/evidence/qinao-k4-platform-spike/spike/Host/K4SpikeHostApp.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/K4PlatformSpike.xcodeproj/project.pbxproj
docs/superpowers/evidence/qinao-k4-platform-spike/spike/K4PlatformSpike.xcodeproj/project.xcworkspace/contents.xcworkspacedata
docs/superpowers/evidence/qinao-k4-platform-spike/spike/K4PlatformSpike.xcodeproj/xcshareddata/xcschemes/K4SpikeHost.xcscheme
docs/superpowers/evidence/qinao-k4-platform-spike/spike/Shared/SpikeMessages.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/fixtures/EnhancedSecurityInitializerShapes.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/fixtures/NoGeneratedProtocol.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/fixtures/XPCReplyShapes.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/generated-metadata/extension-binding-fragment.plist
docs/superpowers/evidence/qinao-k4-platform-spike/spike/generated-metadata/extension-binding-info.plist
docs/superpowers/evidence/qinao-k4-platform-spike/spike/generated-metadata/host-extension-point.appexpt
docs/superpowers/evidence/qinao-k4-platform-spike/spike/generated-metadata/sdk-public-interface-symbols.txt
docs/superpowers/evidence/qinao-k4-platform-spike/spike/project.yml
docs/superpowers/evidence/qinao-k4-platform-spike/spike/template-snapshot/AppExtension-EnhancedSecurity.entitlements
docs/superpowers/evidence/qinao-k4-platform-spike/spike/template-snapshot/AppExtension-EnhancedSecurity.swift
docs/superpowers/evidence/qinao-k4-platform-spike/spike/template-snapshot/ExtensionKit-Base-TemplateInfo.plist
docs/superpowers/evidence/qinao-k4-platform-spike/spike/template-snapshot/TemplateInfo.plist
```

For each decoded raw-path row, require the frozen inventory's `index` stratum
to be present as regular mode `100644`; require the opaque verified record's
signed decision-row projection to equal:

```text
decision = import
source_stratum = index
source_sha256/source_mode = exact frozen inventory values
destination_batch = C3
rationale = w0-k4-public-api-probe-source-only
```

Do not edit the map or copy any field manually. Bootstrap's fixed
materializer derives `review_record_digest = verified.record_digest`,
`reviewer_identity_digest = verified.reviewer_principal_digest`, and
`reviewed_at = verified.reviewed_at` in-process, then atomically writes the
only legal complete C3 postimage. No console transcription, unverified record
parse, old-map carry-forward, or caller-selected record is accepted.

Require the complete decoded `decision=import,destination_batch=C3` path set
to equal the 20 paths above—no 21st row, log, status, signed-entitlement dump,
archive, profile, runtime result, or device identity. Validate and commit only
the reviewed map:

```bash
set -euo pipefail
python3 scripts/qinao_import_review_v1.py --apply-fixed-map-postimage C3
PYTHONDONTWRITEBYTECODE=1 python3 scripts/check_qinao_import_map.py \
  --operation-batch C3 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git add docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
set +e
C3_MAP_CACHED_PATHS="$(git diff --cached --name-only)"
C3_MAP_CACHED_PATHS_RC="$?"
set -euo pipefail
test "$C3_MAP_CACHED_PATHS_RC" = 0
test "$C3_MAP_CACHED_PATHS" = \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
git commit -m "docs(qinao): review exact w0 c3 source slice"
python3 scripts/qinao_import_review_v1.py --verify-fixed-export C3
PYTHONDONTWRITEBYTECODE=1 python3 scripts/check_qinao_import_map.py \
  --operation-batch C3 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
set +e
C3_MAP_COMMIT_STATUS="$(git status --porcelain=v1)"
C3_MAP_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$C3_MAP_COMMIT_STATUS_RC" = 0
test -z "$C3_MAP_COMMIT_STATUS"
```

A missing path/stratum, changed source byte, unauthenticated review, or set
drift is top-level `BLOCKED_IMPORT_REVIEW` with reason
`BLOCKED_C3_REVIEW`; a commit between the frozen context and this map-only
commit, any other path in the commit, or failed postcommit/history reopen is
the same terminal. Both checker calls also reopen the C1 and C2 records and
prove those groups byte-identical. Do not silently rebuild or select a
different stratum.

- [ ] **Step 3: Validate inventory and reviewed map**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/capture_qinao_candidate_inventory.py \
  --operation-batch C3 \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
PYTHONDONTWRITEBYTECODE=1 python3 scripts/check_qinao_import_map.py \
  --operation-batch C3 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 - <<'PY'
import json
from pathlib import Path

mapping = json.loads(
    Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/import-map.json"
    ).read_text(encoding="utf-8")
)
rows = [
    row
    for row in mapping["rows"]
    if row["decision"] == "import" and row["destination_batch"] == "C3"
]
assert len(rows) == 20
assert all(row["source_stratum"] == "index" for row in rows)
assert all(row["source_mode"] == "100644" for row in rows)
assert all(
    row["rationale"] == "w0-k4-public-api-probe-source-only"
    and len(row["review_record_digest"]) == 64
    and len(row["reviewer_identity_digest"]) == 64
    and row["reviewed_at"].endswith("Z")
    for row in rows
)
print("reviewed_c3_rows=20")
PY
```

Expected: both tools pass and the final line is exactly
`reviewed_c3_rows=20`.

- [ ] **Step 4: Reject private preliminary K4 bytes**

```bash
set -euo pipefail
python3 -c 'import base64,json; d=json.load(open("docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json")); bad=[]; forbidden=("docs/superpowers/evidence/qinao-k4-platform-spike/spike/logs/","pre-w5-host-signed-entitlements.plist","pre-w5-extension-signed-entitlements.plist"); \
[(bad.append(base64.b64decode(r["path_b64"],validate=True).decode("utf-8","strict"))) for r in d["rows"] if r["decision"]=="import" and r["destination_batch"]=="C3" and any(x in base64.b64decode(r["path_b64"],validate=True).decode("utf-8","strict") for x in forbidden)]; assert not bad,bad'
```

Expected: exit `0`; no raw log or signed dump is selected.

- [ ] **Step 5: Prepare the destination-CAS plan**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --prepare-batch C3 \
  --output-plan /private/tmp/qinao-c3-source-import-plan.json
```

Expected: `apply_plan_status=prepared batch=C3 rows=20`; candidate
index/worktree remains clean.

- [ ] **Step 6: Apply the exact plan**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
git merge-base --is-ancestor "$PREW0_SW" HEAD
PYTHONDONTWRITEBYTECODE=1 python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --apply-plan /private/tmp/qinao-c3-source-import-plan.json
```

Between the root/ancestry assertions and apply, independently reopen the signed admitted predecessor through the service. Expected: destination-CAS apply passes; every selected postimage/mode equals the reviewed source stratum and only those paths are staged.

- [ ] **Step 7: Commit only the selected C3 paths**

```bash
set -euo pipefail
python3 -c 'import base64,json,subprocess; d=json.load(open("/private/tmp/qinao-c3-source-import-plan.json")); expected=b"".join(base64.b64decode(r["path_b64"],validate=True)+b"\0" for r in d["rows"]); actual=subprocess.check_output(["git","diff","--cached","--name-only","-z"]); assert actual==expected,(expected,actual)'
git commit -m "build(qinao): import reviewed W0 safety slice"
PYTHONDONTWRITEBYTECODE=1 python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --finalize-plan /private/tmp/qinao-c3-source-import-plan.json
set +e
C3_IMPORT_COMMIT_STATUS="$(git status --porcelain=v1)"
C3_IMPORT_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$C3_IMPORT_COMMIT_STATUS_RC" = 0
test -z "$C3_IMPORT_COMMIT_STATUS"
git merge-base --is-ancestor "$PREW0_SW" HEAD
```

Expected: one 20-path commit, byte-exact NUL-delimited path equality against
authoritative `path_b64` values, clean worktree, admitted `preW0 Sw` remains
ancestor. `display_path` is never used to select or stage a path.

---

### Task 2: Freeze the W0 Safety Contract Before Changing More Production Code

**Files:**
- Create: `docs/superpowers/specs/qinao-w0-safety-freeze-v1.json`
- Create: `scripts/check_qinao_w0_safety.py`
- Create: `scripts/test_check_qinao_w0_safety.py`
- Create: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASW0SafetyFreezeTests.swift`
- Create: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoW0SafetyFreezeTests.swift`
- Verify only from authenticated predecessor/B0:
  `scripts/qinao_gate_modules/v0/corpora/w0_open_set.json`

**Interfaces:**

```text
@dataclass(frozen=True)
class HazardRow:
    id: str
    owner_id: str
    production_roots: tuple[str, ...]
    source_roots: tuple[str, ...]
    allowed_current_seams: tuple[str, ...]
    forbidden_active_symbols: tuple[str, ...]
    forbidden_active_calls: tuple[str, ...]
    forbidden_reachability: tuple[str, ...]
    required_suites: tuple[str, ...]
    positive_fixture: str
    negative_fixture: str
    disposition: str

@dataclass(frozen=True)
class W0SafetyResult:
    mode: Literal["diagnostic", "production"]
    status: Literal["preflight", "result"]
    verdict: Literal["passed", "failed"]
    payload_commit_oid: str | None
    payload_tree_oid: str | None
    discovered_source_count: int
    discovered_production_root_count: int
    executed_predicate_count: int
    hazard_results: tuple[tuple[str, str], ...]
    reviewed_change_paths_b64: tuple[str, ...]

def load_contract(path: Path) -> tuple[HazardRow, ...]
def evaluate_worktree(root: Path, rows: tuple[HazardRow, ...]) -> W0SafetyResult
def compare_result(expected_payload_commit: str, expected_payload_tree: str, result_bytes: bytes) -> W0SafetyResult
```

The `HazardRow.id` tuple is the one canonical 16-ID UTF-8-sorted list in
`Closed W0 Contract → Hazard families` above; Task 2 must reference that
constant and may not redeclare or alias it. Each row expands the literal
production/source roots, allowed current seams, forbidden
symbols/calls/reachability, required suites, positive/negative fixture IDs,
and fail-closed disposition prescribed by Tasks 3–7. Only
`runtime.untyped-shared-agent-state` receives the exact graph token and
reachability additions from the header matrix. The Bootstrap plan independently
freezes the same 16-ID set plus the same ordered ten-case graph array in B0;
`W0SafetyContractTests` reopens the corpus blob from the authenticated
predecessor tree and compares the indexed contract/case tuples and canonical
array SHA-256 before active evaluation. The corpus is read-only and is not in
this task's staging set.

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
```

Then independently call `ProtectedAdmissionClient.reopen_admitted_predecessor()` and require the exact `PREW0_PW/PREW0_PW_TREE/PREW0_SW` tuple. Expected: all checks pass before a file is created.

- [ ] **Step 1: Write RED Python tests**

Tests must cover all 16 IDs, exact fields/order, missing/extra row, absent and symlink roots, comment/string non-match, active-symbol match, active-call match, indirect factory reachability, package-product reachability, raw regex fail-closed, required-suite zero, duplicate result, and candidate result claiming a different payload.

In `scripts/test_check_qinao_w0_safety.py`, declare one
`W0SafetyContractTests(unittest.TestCase)` class. It contains the exact ten
graph methods from the header table and an immutable `GRAPH_FREEZE_CASES`
tuple of canonical dictionaries with exact keys
`case_id,fixture_id,hazard_id,mutation,expected`, in that same order and with
the table's literal values. `GRAPH_FREEZE_CASE_IDS` is derived only as
`tuple(row["case_id"] for row in GRAPH_FREEZE_CASES)`, never independently
declared. The fixture builder writes only to `TemporaryDirectory`, creates the
exact one-package/one-shipping-target shape described above, and applies
exactly one mutation per test. It also
reopens
`$PREW0_PW_TREE:scripts/qinao_gate_modules/v0/corpora/w0_open_set.json`
through `git show`, rejects a non-regular/missing indexed blob before parsing,
and compares the complete corpus `graph_freeze_cases` tuple and canonical
digest with `GRAPH_FREEZE_CASES`. No test reads the worktree copy as
authority.

First create an importable `scripts/check_qinao_w0_safety.py` typed seam with
the final dataclasses and signatures above. Each operation raises
`W0SafetyError("qinao.w0-safety.unimplemented")`; the CLI parses only its
final closed arguments and raises the same diagnostic. Syntax, import,
attribute, or zero-discovery failure is invalid RED.

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_keeps_exact_sixteen_ids \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g1_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g2_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_main_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_sub_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_shared_mutable_scratchpad_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_legacy_loop_authority_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_refresh_must_be_read_only_or_production_unreachable \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_future_graph_contract_is_rejected_at_w0 \
  >/private/tmp/qinao-w0-graph-red.txt 2>&1
GRAPH_RED_RC="$?"
set -euo pipefail
test "$GRAPH_RED_RC" = 1
python3 - <<'PY'
from pathlib import Path

case_ids = (
    "test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id",
    "test_graph_freeze_keeps_exact_sixteen_ids",
    "test_second_g1_writer_is_rejected",
    "test_second_g2_writer_is_rejected",
    "test_main_sub_peer_call_is_rejected",
    "test_sub_sub_peer_call_is_rejected",
    "test_shared_mutable_scratchpad_is_rejected",
    "test_legacy_loop_authority_is_rejected",
    "test_refresh_must_be_read_only_or_production_unreachable",
    "test_future_graph_contract_is_rejected_at_w0",
)
text = Path("/private/tmp/qinao-w0-graph-red.txt").read_text()
assert "Ran 10 tests" in text, text
assert all(case_id in text for case_id in case_ids), text
assert text.count("qinao.w0-safety.unimplemented") >= 10, text
PY
```

Then run the complete module once:

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_w0_safety \
  >/private/tmp/qinao-w0-safety-full-red.txt 2>&1
FULL_RED_RC="$?"
set -euo pipefail
test "$FULL_RED_RC" = 1
python3 - <<'PY'
import re
from pathlib import Path

text = Path("/private/tmp/qinao-w0-safety-full-red.txt").read_text()
match = re.search(r"Ran ([0-9]+) tests?", text)
assert match and int(match.group(1)) >= 28, text
assert "qinao.w0-safety.unimplemented" in text, text
for forbidden in (
    "ModuleNotFoundError",
    "Failed to import test module",
    "AttributeError:",
    "No such file or directory",
):
    assert forbidden not in text, (forbidden, text)
PY
```

Expected: at least 28 named tests are discovered; the exact ten graph names
are present; every semantic failure is
`qinao.w0-safety.unimplemented`; there is no load, import, fixture, path, or
zero-discovery error.

- [ ] **Step 2: Write RED Swift behavior tests**

The BAS suite uses only current symbols and proves:

```text
selfPopulate is false in both memory factory branches
multi-Provider list execution is absent from shipping call graph
no actuator evidence yields skipped/unmeasured
plain learning mouths are unavailable to shipping composition
sleep consolidation shipping path is dry-run/projection
```

The Qinao suite proves:

```text
raw persona/session values cannot alter production authority
recognition is guest-only mechanically
stream plus final view performs one Provider invocation
effect without broker evidence never calls legacy closure
SampleHost has no argv secret or raw Authorization construction
Qinao shipping products do not contain concrete Provider runtimes
```

Run:

```bash
set -euo pipefail
set +e
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASW0SafetyFreezeTests \
  --require-suite BehavioralAISubstrateTests.BASW0SafetyFreezeTests \
  >/private/tmp/qinao-w0-bas-safety-red.txt 2>&1
W0_BAS_SAFETY_RED_RC="$?"
set -euo pipefail
test "$W0_BAS_SAFETY_RED_RC" = 1
set +e
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoW0SafetyFreezeTests \
  --require-suite QinaoRuntimeSDKTests.QinaoW0SafetyFreezeTests \
  >/private/tmp/qinao-w0-qinao-safety-red.txt 2>&1
W0_QINAO_SAFETY_RED_RC="$?"
set -euo pipefail
test "$W0_QINAO_SAFETY_RED_RC" = 1
```

Expected: each suite is discovered and fails on at least one real current hazard; compilation succeeds without a future API.

- [ ] **Step 3: Implement the checker**

Use Python `tokenize` only for Python and a bounded Swift lexical scanner for Swift. The Swift scanner handles ordinary/raw/multiline strings, interpolations, line comments, and nested block comments. An unsupported raw-regex literal fails the containing source root. Build/package roots are enumerated from `Package.swift`, checked-in Xcode project/workspace/scheme files, and the Owner-Ledger active release profile set; a missing graph input fails rather than reducing scope.

The checker maps every header-matrix symbol/call/reachability diagnostic to
the existing `runtime.untyped-shared-agent-state` row. It does not accept a
generic “graph” substring, documentation hit, fixture self-report, or
caller-provided classification. `refresh` classification is derived from the
transitive source/build/link graph and must be exactly `readOnly` or
`productionUnreachable`; every other value and every absent edge is the exact
`unclassified-task-graph-refresh` diagnostic.

The two mutually exclusive invocation shapes are exactly:

```bash
set -euo pipefail
python3 scripts/check_qinao_w0_safety.py \
  --root . \
  --contract docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  --diagnostic-staged \
  --output /private/tmp/qinao-w0-safety-preflight.json
python3 scripts/check_qinao_w0_safety.py \
  --root . \
  --contract docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  --payload-commit "$W0_PW" \
  --payload-tree "$W0_PW_TREE" \
  --output /private/tmp/qinao-w0-safety-result.json
```

`--output` is required and outside Git. It writes canonical JSON only after all predicates execute. Diagnostic mode reads the exact staged tree through a temporary index, reports `mode = "diagnostic"` and `status = "preflight"`, and cannot serialize payload/result authority. The second shape is candidate parity/compare-only: it is legal only after `W0_PW` and `W0_PW_TREE` were frozen from clean `HEAD` and matched to the signed lease, and its bytes cannot become an authoritative gate result except through the B0 active primitive.

- [ ] **Step 4: Make checker tests green**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_keeps_exact_sixteen_ids \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g1_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g2_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_main_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_sub_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_shared_mutable_scratchpad_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_legacy_loop_authority_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_refresh_must_be_read_only_or_production_unreachable \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_future_graph_contract_is_rejected_at_w0
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_w0_safety
```

Expected: the focused command prints `Ran 10 tests` and `OK`; the full module
discovers at least 28 tests and passes with no skip. Missing/renamed focused
method is a load error. The indexed B0 corpus comparison, comment/string
non-match rows, both legal `refresh` positive shapes, and every single-mutation
negative all execute.

- [ ] **Step 5: Commit the contract/checker/test slice**

```bash
set -euo pipefail
git add \
  docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  scripts/check_qinao_w0_safety.py \
  scripts/test_check_qinao_w0_safety.py \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASW0SafetyFreezeTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoW0SafetyFreezeTests.swift
set +e
W0_CONTRACT_CACHED_PATHS="$(git diff --cached --name-only)"
W0_CONTRACT_CACHED_PATHS_RC="$?"
set -euo pipefail
test "$W0_CONTRACT_CACHED_PATHS_RC" = 0
test "$(printf '%s\n' "$W0_CONTRACT_CACHED_PATHS" | LC_ALL=C sort)" = "$(printf '%s\n' \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASW0SafetyFreezeTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoW0SafetyFreezeTests.swift \
  docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  scripts/check_qinao_w0_safety.py \
  scripts/test_check_qinao_w0_safety.py | LC_ALL=C sort)"
git commit -m "test(qinao): freeze W0 safety boundaries"
set +e
W0_CONTRACT_COMMIT_STATUS="$(git status --porcelain=v1)"
W0_CONTRACT_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$W0_CONTRACT_COMMIT_STATUS_RC" = 0
test -z "$W0_CONTRACT_COMMIT_STATUS"
```

Expected: exact five-path commit.

---

### Task 3: Close Current-API Provider, Runtime, Effect, Stream, AFM, Memory, and Secret Hazards

**Files:**
- Modify only source paths selected by the reviewed C3 import plus the failing W0 checker.
- Test: the eleven pre-existing W0 suites, including
  `BASRoutedMemoryFlipTests`, and two new W0 suites.

**Interfaces:**
- Consumes: current W0 APIs.
- Produces: fail-closed W0 shipping reachability; no W1-W6 API.

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 0A: Capture the pre-edit failure-to-path ledger**

On the clean index, run:

```bash
set -euo pipefail
set +e
python3 scripts/check_qinao_w0_safety.py \
  --root . \
  --contract docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  --diagnostic-staged \
  --output /private/tmp/qinao-w0-runtime-preedit.json \
  >/private/tmp/qinao-w0-runtime-preedit-command.txt 2>&1
W0_RUNTIME_PREEDIT_RC="$?"
set -euo pipefail
test "$W0_RUNTIME_PREEDIT_RC" = 1
python3 -c 'import base64,json; d=json.load(open("/private/tmp/qinao-w0-runtime-preedit.json")); rows=d["reviewed_change_paths_b64"]; assert rows==sorted(set(rows)); assert rows; open("/private/tmp/qinao-w0-runtime-reviewed-paths.z","wb").write(b"".join(base64.b64decode(x,validate=True)+b"\0" for x in rows))'
```

Expected: all predicates execute, the diagnostic result says `status = preflight` and `verdict = failed`, and the exact nonempty repair path set is frozen before an edit.

- [ ] **Step 1: Run the exact imported Provider suites**

```bash
set -euo pipefail
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASProviderBoundaryTests \
  --require-suite BehavioralAISubstrateTests.BASProviderBoundaryTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoProviderBoundaryTests \
  --require-suite QinaoRuntimeSDKTests.QinaoProviderBoundaryTests
```

Expected: BAS discovers at least 2 tests; Qinao discovers at least 3; inventory tests execute. They may report the frozen open set but must not compile against future APIs.

- [ ] **Step 2: Run the exact imported BAS runtime suites**

```bash
set -euo pipefail
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter 'BASNativeStageExecutorTests|BASTurnRuntimeNativeV2DispatchTests|BASSyntheticExecutionReceiptFreezeTests|BASSovereignReceiptHonestyTests|BASRoutedMemoryFlipTests' \
  --require-suite BehavioralAISubstrateTests.BASNativeStageExecutorTests \
  --require-suite BehavioralAISubstrateTests.BASTurnRuntimeNativeV2DispatchTests \
  --require-suite BehavioralAISubstrateTests.BASSyntheticExecutionReceiptFreezeTests \
  --require-suite BehavioralAISubstrateTests.BASSovereignReceiptHonestyTests \
  --require-suite BehavioralAISubstrateTests.BASRoutedMemoryFlipTests
```

Expected: all five exact suites are nonempty; at least 18 tests execute,
including every test in the existing routed-memory flip suite.

- [ ] **Step 3: Run the exact imported Qinao runtime/effect suites**

```bash
set -euo pipefail
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter 'QinaoRuntimeGateTests|QinaoTokenSigningTests|QinaoSovereignHostAssemblyTests|QinaoEffectFacadeFreezeTests' \
  --require-suite QinaoRuntimeSDKTests.QinaoRuntimeGateTests \
  --require-suite QinaoRuntimeSDKTests.QinaoTokenSigningTests \
  --require-suite QinaoRuntimeSDKTests.QinaoSovereignHostAssemblyTests \
  --require-suite QinaoRuntimeSDKTests.QinaoEffectFacadeFreezeTests
```

Expected: all four suites nonempty; at least 26 tests execute.

- [ ] **Step 4: Make memory self-population fail closed**

In `BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+Construction.swift`, change only both current `selfPopulate: true` arguments in `resolveMemoryService` to:

```swift
selfPopulate: false,
```

Do not add a replacement writer or owner. Run the BAS W0 suite and the exact
existing `BehavioralAISubstrateTests.BASRoutedMemoryFlipTests` suite through
`run_nonempty_swift_filter.py`; both branches must prove no write after
retrieval. This suite remains in every final exact-suite rerun and in the
signed W0 open-set contract.

- [ ] **Step 5: Fence same-call Provider fallback without future API**

Keep the existing public compatibility value types. Shipping composition must pass one already-selected Provider to the current executor, and the production call graph must not reach `BASProviderAttemptExecutor.execute(providers:)` with more than one element. If the current implementation itself remains shipping-reachable, replace its loop with a single-element guard using current return types:

```swift
guard let provider = providers.first, providers.count == 1 else {
    return .noResult(attemptedProviderIDs: [])
}
let selectedProviderID = providerID(provider)
let attemptedProviderIDs = [selectedProviderID]
```

Then execute the existing cache/invoke/verdict body once for `provider`; rejected cache/result or miss returns `.noResult(attemptedProviderIDs: attemptedProviderIDs)` and never advances to a second Provider. Do not add or name `executeAtMostOnce`.

- [ ] **Step 6: Fence stream-then-regenerate**

Use one current Provider operation as the source of both incremental view and final body. If that cannot be expressed with present W0 types, remove the shipping call path to public `QinaoLoop.streamBody` and keep the method test/lab-only. Delete documentation that tells production hosts to stream and then call `generateCandidates`. Tests assert one call counter and byte-equal final output; no future `spool` field or `operation.stream().final()` appears.

- [ ] **Step 7: Fence concrete Provider packages from Qinao SDK shipping products**

Move no implementation into Qinao. Restrict `QinaoAppleFoundation`, `QinaoMLX`, and Provider-specific SampleHost products to explicit host/provider packages or non-shipping examples. The comment/string-safe gate permits the names in documentation but rejects active imports, declarations, factories, callbacks, reflection, linked symbols, or shipping package products under QinaoRuntimeSDK.

- [ ] **Step 8: Remove raw secret authority**

Remove `BASChatCompletionsOrganAdapter.Endpoint.headers: [String:String]`. Keep `Endpoint` as the Codable non-secret URL/model value and add this actor initializer argument:

```swift
authorizeRequest: @escaping @Sendable (URLRequest) async throws -> URLRequest = { $0 }
```

Store the closure separately from `Endpoint`; do not make it Codable, Equatable, printable, or descriptor metadata. Both eager and streaming transports call it exactly once on the fully formed request immediately before `URLSession`; no request/header value enters an error, trace, cache key, debug description, or receipt. Tests inject non-secret fixture headers through this closure.

Remove `--api-key` from `QinaoSampleHost`, its usage text, parser, tests, and process invocation. A host demo may resolve a credential through an injected non-argv capability; absence yields a stable unavailable error. Tests inspect `CommandLine.arguments`, `/proc`-style process text where supported, logs, and encoded endpoint values and find no secret.

- [ ] **Step 9: Preserve honest AFM accounting**

Provider kind/capability metadata may report observed support but `certificationTier` remains experimental/unknown unless a release-bound certificate exists. Model name, FoundationModels/CoreAI import, successful request, or manifest row cannot produce `certified`, AFM-specific billing, ANE residency, or a production-default claim. Add negative fixtures for each inference.

- [ ] **Step 10: Re-run all 13 W0 suites**

Run the six commands from Steps 1–3 and Task 2 Step 2. Expected: all
13 required suites are nonempty and green; no future symbol occurs in compiler
diagnostics.

- [ ] **Step 11: Commit exact production corrections**

Use the exact pre-edit `/private/tmp/qinao-w0-runtime-reviewed-paths.z` from Step 0A. Require every changed path to be in that frozen set and every frozen path to have its prescribed postcondition; then:

```bash
set -euo pipefail
git add --pathspec-from-file=/private/tmp/qinao-w0-runtime-reviewed-paths.z --pathspec-file-nul
python3 -c 'import subprocess; expected=open("/private/tmp/qinao-w0-runtime-reviewed-paths.z","rb").read(); actual=subprocess.check_output(["git","diff","--cached","--name-only","-z"]); assert actual==expected,(expected,actual)'
git commit -m "fix(qinao): fail closed at W0 runtime boundaries"
set +e
W0_RUNTIME_COMMIT_STATUS="$(git status --porcelain=v1)"
W0_RUNTIME_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$W0_RUNTIME_COMMIT_STATUS_RC" = 0
test -z "$W0_RUNTIME_COMMIT_STATUS"
```

Expected: one byte-exact reviewable correction commit; no unknown path and no evidence/result file.

---

### Task 4: Freeze App-Agent, Persona, Memory, Recognition, and Split-Brain Boundaries

**Files:**
- Modify: current raw Session/persona and graph-lifecycle source/call sites only
  where the Task-2 checker reports shipping reachability.
- Verify only: `docs/superpowers/specs/qinao-w0-safety-freeze-v1.json`,
  `scripts/check_qinao_w0_safety.py`,
  `scripts/test_check_qinao_w0_safety.py`, the authenticated B0
  `w0_open_set.json` corpus, and both W0 safety suites.

**Interfaces:**
- Consumes: the committed Task-2 16-ID contract and exact ten-case graph matrix
  without changing either.
- Produces: guest-only W0 recognition, presentation-only persona compatibility,
  and one mechanically derived `refresh` classification with every discovered
  graph writer/peer/scratchpad/loop edge closed or production-unreachable.
- Does not create: App-Agent root, Session-selection CAS, Self owner, memory owner, context capsule authority, or recognition authority.

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 0A: Reopen the Task-2 graph freeze and classify the real source graph**

First prove this task did not edit its input contracts and run all ten exact
focused tests:

```bash
set -euo pipefail
set +e
W0_GRAPH_INPUT_DIFF="$(
  git diff --name-only -- \
  docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  scripts/check_qinao_w0_safety.py \
  scripts/test_check_qinao_w0_safety.py
)"
W0_GRAPH_INPUT_DIFF_RC="$?"
set -euo pipefail
test "$W0_GRAPH_INPUT_DIFF_RC" = 0
test -z "$W0_GRAPH_INPUT_DIFF"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_graph_freeze_keeps_exact_sixteen_ids \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g1_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_second_g2_writer_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_main_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_sub_sub_peer_call_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_shared_mutable_scratchpad_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_legacy_loop_authority_is_rejected \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_refresh_must_be_read_only_or_production_unreachable \
  scripts.test_check_qinao_w0_safety.W0SafetyContractTests.test_future_graph_contract_is_rejected_at_w0
```

Expected: `Ran 10 tests`, `OK`, and no input-contract diff. Next run
`check_qinao_w0_safety.py --diagnostic-staged` over the clean index and reopen
its canonical result. For the real
`BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleTaskGraphLifecycleCore.swift`
declaration and
`BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift` call site,
require exactly one derived result:

```text
readOnly:
  transitive write/CAS/schedule/retry/remand/commit/publication/effect/
  scratchpad/Provider-call edge count = 0
productionUnreachable:
  shipping product/factory/DI/call/link path count = 0
```

The current callback names `saveSnapshot` and `clearSnapshot` are treated as
write-capable until call-graph proof shows otherwise; a name or closure type
cannot establish read-only behavior. If neither legal result is proven, use
the checker's nonempty reviewed source-path set to remove/fence only the
shipping reachability. In the same pass, classify every discovered G1/G2
writer, direct Main/Sub or Sub/Sub call, mutable shared scratchpad, and
schedule/retry/remand/commit loop. Unknown and ambiguous edges fail; this task
does not edit the contract, corpus, checker, or fixture matrix to make them
pass.

- [ ] **Step 1: Execute the Task-2 raw-string negative matrix**

The already-committed Swift tests independently inject:

```text
different BASOrganRequest.sessionID
different BASOrganRequest.personaInstructions
different raw main-agent string
different raw app-agent string
same raw persona across two workspaces
relationship-specific phrase while recognition is unproven
persona text asking to override evidence/policy/tool authorization
```

Expected RED: at least one current shipping path changes behavior or accepts authority-shaped content.

- [ ] **Step 2: Force production builders to nil compatibility fields**

All shipping builders of `BASOrganRequest` pass:

```swift
sessionID: nil,
personaInstructions: nil
```

Compatibility/demo builders with non-`nil` values must live in test, lab, benchmark, or shadow products excluded from active release reachability. Do not delete Codable fields in W0 and do not add future typed App-Agent refs.

- [ ] **Step 3: Lock persona to presentation**

W0 shipping composition uses the neutral presentation profile only; no raw persona text reaches a model or authority boundary. Existing raw persona compatibility remains test/lab-only. The freeze test applies adversarial persona strings at that compatibility seam and proves they cannot alter safety facts, citations, uncertainty, tool arguments, structured fields, locked spans, memory, policy, identity, or effect decisions. Rich closed presentation profiles remain later App-Agent work rather than a W0 keyword filter or second persona owner.

- [ ] **Step 4: Mechanically enforce guest-only recognition**

Use the current composition seam to make:

```text
recognition_completion = guestOnlyMechanicallyEnforced
relationship_specific_rendering_reachable = false
recognition_dependent_memory_reachable = false
```

This is a testable production-graph fact, not a Boolean claim. A planted relationship renderer or recognition-dependent store edge must fail the checker.

- [ ] **Step 5: Prove no split-brain authority**

Scan current production factories, singletons, actors, registries, SQLite writers, callbacks, notification handlers, reflection, and linked symbols for a second owner of Session/App-Agent/Self/persona/memory/recognition/provider route/effect result. Each discovered responsibility maps to the existing Owner Ledger row or is test/lab-only. Unknown or unclassified writers fail.

- [ ] **Step 6: Run and commit**

```bash
set -euo pipefail
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASW0SafetyFreezeTests \
  --require-suite BehavioralAISubstrateTests.BASW0SafetyFreezeTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoW0SafetyFreezeTests \
  --require-suite QinaoRuntimeSDKTests.QinaoW0SafetyFreezeTests
set +e
W0_APP_AGENT_REVIEWED_PATHS="$(git diff --name-only)"
W0_APP_AGENT_REVIEWED_PATHS_RC="$?"
set -euo pipefail
test "$W0_APP_AGENT_REVIEWED_PATHS_RC" = 0
test -n "$W0_APP_AGENT_REVIEWED_PATHS"
printf '%s\n' "$W0_APP_AGENT_REVIEWED_PATHS" | LC_ALL=C sort \
  > /private/tmp/qinao-w0-app-agent-reviewed-paths.txt
test -s /private/tmp/qinao-w0-app-agent-reviewed-paths.txt
python3 -c 'from pathlib import Path; rows=Path("/private/tmp/qinao-w0-app-agent-reviewed-paths.txt").read_text().splitlines(); roots=("BehavioralAISubstrate/Sources/","QinaoRuntimeSDK/Sources/"); assert rows==sorted(set(rows)); assert all(any(row.startswith(root) for root in roots) for row in rows)'
git add --pathspec-from-file=/private/tmp/qinao-w0-app-agent-reviewed-paths.txt
set +e
W0_APP_AGENT_CACHED_PATHS="$(git diff --cached --name-only)"
W0_APP_AGENT_CACHED_PATHS_RC="$?"
set -euo pipefail
test "$W0_APP_AGENT_CACHED_PATHS_RC" = 0
printf '%s\n' "$W0_APP_AGENT_CACHED_PATHS" | LC_ALL=C sort \
  > /private/tmp/qinao-w0-app-agent-staged.txt
cmp /private/tmp/qinao-w0-app-agent-reviewed-paths.txt \
  /private/tmp/qinao-w0-app-agent-staged.txt
python3 scripts/check_qinao_w0_safety.py \
  --root . \
  --contract docs/superpowers/specs/qinao-w0-safety-freeze-v1.json \
  --diagnostic-staged \
  --output /private/tmp/qinao-w0-app-agent-precommit.json
git commit -m "fix(qinao): isolate W0 agent identity and persona"
set +e
W0_APP_AGENT_COMMIT_STATUS="$(git status --porcelain=v1)"
W0_APP_AGENT_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$W0_APP_AGENT_COMMIT_STATUS_RC" = 0
test -z "$W0_APP_AGENT_COMMIT_STATUS"
```

Expected: suites pass, the checker reports one legal `refresh`
classification and zero forbidden graph/peer/scratchpad/loop reachability,
the Task-2 contract/checker/tests and B0 corpus remain byte-identical, and the
commit contains source only with no result JSON.

---

### Task 5: Freeze the Exact 12-Row Legacy Learning Disposition and Reachability Analyzer

**Files:**
- Create the four policy/schema/checker/test files in the File Responsibility Map.
- Modify only current production mouths required to enforce the exact dispositions.

**Interfaces:**

```text
@dataclass(frozen=True)
class LegacyPolicyRow:
    id: str
    mechanisms: tuple[str, ...]
    reality: str
    required_disposition: str
    declaration_symbols: tuple[str, ...]
    factory_symbols: tuple[str, ...]
    direct_call_symbols: tuple[str, ...]
    dynamic_spellings: tuple[str, ...]
    package_products: tuple[str, ...]
    allowed_conditions: tuple[str, ...]
    forbidden_shipping_roles: tuple[str, ...]

@dataclass(frozen=True)
class LegacyReachabilityRow:
    id: str
    declarations: tuple[str, ...]
    direct_callers: tuple[str, ...]
    transitive_release_callers: tuple[str, ...]
    factory_edges: tuple[str, ...]
    reflection_edges: tuple[str, ...]
    shipping_reachable: bool
    enforced_disposition: str
    source_graph_digest: str

@dataclass(frozen=True)
class LegacyAnalysisResult:
    rows: tuple[LegacyReachabilityRow, ...]
    required_source_fence_paths_b64: tuple[str, ...]

def analyze_payload(
    git_dir: Path,
    payload_commit_oid: str,
    payload_tree_oid: str,
    policy: tuple[LegacyPolicyRow, ...],
    active_release_graph: ActiveReleaseGraph,
) -> LegacyAnalysisResult
```

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 1: Encode the exact 12 rows**

Copy the IDs/mechanisms/dispositions from this plan's table verbatim. Add exact current symbols by comment/string-safe discovery. Do not merge rows, split rows, add a thirteenth “miscellaneous” row, or call Qwen3.5 current default.

- [ ] **Step 2: Write RED exact-set and reachability tests**

Tests include every direct mechanism plus planted:

```text
HostKit factory -> plain lifecycle mouth
protocol witness -> training exporter
closure capture -> sleep mutation
reflection string -> distillation ingest
SampleHost product -> markDistilled
conditional compilation -> release product
alias/typealias -> promoted stage
Qwen manifest without a load caller
```

Each planted shipping edge fails; the same edge under an exact non-shipping fixture condition passes only with its required negative test.

- [ ] **Step 2A: Freeze the diagnostic source-fence path set**

Run the compare-only analyzer against the clean worktree's complete checked-in release graph:

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 scripts/check_qinao_learning_legacy_reachability.py \
  --root . \
  --policy docs/superpowers/specs/qinao-learning-legacy-disposition-v1.json \
  --diagnostic-worktree \
  --output /private/tmp/qinao-learning-legacy-preedit.json \
  >/private/tmp/qinao-learning-legacy-preedit-command.txt 2>&1
W0_LEARNING_PREEDIT_RC="$?"
set -euo pipefail
test "$W0_LEARNING_PREEDIT_RC" = 1
python3 -c 'import base64,json; d=json.load(open("/private/tmp/qinao-learning-legacy-preedit.json")); rows=d["required_source_fence_paths_b64"]; assert rows==sorted(set(rows)); assert rows; base=b"docs/superpowers/specs/qinao-learning-legacy-disposition-v1.json\0docs/superpowers/specs/qinao-learning-legacy-reachability-v1.schema.json\0scripts/check_qinao_learning_legacy_reachability.py\0scripts/test_check_qinao_learning_legacy_reachability.py\0"; paths=sorted(set(base.split(b"\0")[:-1]+[base64.b64decode(x,validate=True) for x in rows])); open("/private/tmp/qinao-learning-legacy-reviewed-paths.z","wb").write(b"".join(x+b"\0" for x in paths))'
```

Expected: `status = preflight`, failed disposition verdict, exact nonempty sorted source-fence set. This diagnostic graph is not the later authority-derived Cw result.

- [ ] **Step 3: Run RED**

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_learning_legacy_reachability \
  >/private/tmp/qinao-learning-legacy-red.txt 2>&1
W0_LEARNING_RED_RC="$?"
set -euo pipefail
test "$W0_LEARNING_RED_RC" = 1
```

Expected: at least 24 tests discovered and import/behavior RED.

- [ ] **Step 4: Implement analysis from immutable Git objects**

The analyzer materializes exact `payload_tree_oid` read-only, enumerates all active package/Xcode/workspace products from the authority-derived release graph, records declaration/call/factory/reflection edges, and supplements AST/index results with SIL/linked-symbol reachability when Swift dispatch obscures a call. It never trusts a candidate-authored “unreachable” Boolean.

Before `Pw`, the candidate checker can run diagnostic worktree mode only.
After freeze it may run an immutable parity comparison over explicit
`payload_commit_oid`/`payload_tree_oid` plus a redacted synthetic release-graph
fixture; it never accepts or parses the opaque lease. Its canonical 12-row
output remains outside Git and cannot satisfy the current gate. The B0 active
primitive independently derives the authoritative graph and Cw projection.

- [ ] **Step 5: Source-gate direct mouths**

Using existing access control and compile conditions only:

- plain `approveForDistillation` and `markDistilled` are not public/package shipping mouths;
- HostKit wrapper/factory calls cannot restore them;
- `BASTrainingDataExporter`, Sublimator, Furnace, legacy evolution `.promoted`, distillation ingest, and SampleHost paths are test/lab/shadow-only;
- sleep consolidation cannot call `BASMemoryClosedLoopApplier` in shipping W0 and defaults to dry-run/projection;
- Qwen3.5 manifest/MTP remains design/mechanism evidence, never production default.

Do not create the future K3 lifecycle, dataset owner, trainer owner, certification owner, or cutover owner.

- [ ] **Step 6: Make tests green**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_learning_legacy_reachability
```

Expected: at least 24 tests pass; all 12 policy rows exercised; every negative diagnostic ID observed.

- [ ] **Step 7: Commit policy and source fences**

Build `/private/tmp/qinao-learning-legacy-reviewed-paths.z` from the four contract/tool paths plus the analyzer's exact sorted `required_source_fence_paths_b64`; compare it to the complete changed set, then:

```bash
set -euo pipefail
git add --pathspec-from-file=/private/tmp/qinao-learning-legacy-reviewed-paths.z --pathspec-file-nul
python3 -c 'import subprocess; expected=open("/private/tmp/qinao-learning-legacy-reviewed-paths.z","rb").read(); actual=subprocess.check_output(["git","diff","--cached","--name-only","-z"]); assert actual==expected,(expected,actual)'
git commit -m "fix(qinao): fence legacy learning mouths at W0"
set +e
W0_LEARNING_COMMIT_STATUS="$(git status --porcelain=v1)"
W0_LEARNING_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$W0_LEARNING_COMMIT_STATUS_RC" = 0
test -z "$W0_LEARNING_COMMIT_STATUS"
```

Expected: no generated reachability result in the commit.

---

### Task 6: Freeze Causal Order and One-CAS K3 Invalidation Fanout

**Files:**
- Create the schema/checker/test and fixture directory listed above.

**Interfaces:**

```text
@dataclass(frozen=True)
class CausalFixture:
    fixture_id: str
    expected: Literal["pass", "fail"]
    diagnostic_id: str | None
    causal_root_id: str
    duplicate_component_id: str
    split_id: str
    stages: tuple[str, ...]
    holdout_stage_tag: str
    holdout_lineage_digest: str
    trainer_visible_refs: tuple[str, ...]
    evaluator_visible_refs: tuple[str, ...]
    invalidation_expected_parent: str
    invalidation_new_head: str
    invalidation_cas_count: int
    invalidation_fanout: tuple[str, ...]
    late_result_disposition: str

def validate_fixture(value: object) -> CausalFixture
def validate_fixture_set(root: Path) -> tuple[CausalFixture, ...]
```

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 1: Create the positive fixture**

Use the exact 14 stages and four fanouts above. Use fixed lowercase 64-hex fixture digests; no random values.

- [ ] **Step 2: Create the complete negative set**

Create one file for each:

```text
missing-causal-root
split-before-component-freeze
cleaning-before-split
cross-split-dedup
trainer-sees-holdout-membership
candidate-sees-holdout-result
firewall-after-evaluation
pareto-before-hard-veto
holdout-stage-tag-missing
holdout-lineage-stale
canary-before-e0-e4
field-before-canary
adoption-before-e5
same-seal-canary-and-adoption
two-invalidation-cas
missing-runtime-boundary-fanout
missing-projection-fanout
missing-learning-eligibility-fanout
missing-exposure-eligibility-fanout
cas-loser-mutates
late-result-adopted
```

Each differs from positive by one semantic mutation and names one exact diagnostic.

- [ ] **Step 3: Write and run RED tests**

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_learning_causal_fixtures \
  >/private/tmp/qinao-learning-causal-red.txt 2>&1
W0_CAUSAL_RED_RC="$?"
set -euo pipefail
test "$W0_CAUSAL_RED_RC" = 1
```

Expected: at least 25 tests discovered and behavior RED.

- [ ] **Step 4: Implement closed validation**

Reject unknown keys, duplicate stages/fanouts, out-of-order stages, multiple split IDs for one component, same evaluator/trainer visibility, missing immutable lineages, fanout aliases, and any expected-fail fixture that accidentally passes. Require the fixture directory exact set; an extra file fails.

- [ ] **Step 5: Make tests green and commit**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_learning_causal_fixtures
git add \
  docs/superpowers/specs/qinao-learning-causal-fixture-v1.schema.json \
  scripts/check_qinao_learning_causal_fixtures.py \
  scripts/test_check_qinao_learning_causal_fixtures.py \
  scripts/fixtures/qinao-learning-causal-v1
git commit -m "test(qinao): freeze governed learning causal order"
set +e
W0_CAUSAL_COMMIT_STATUS="$(git status --porcelain=v1)"
W0_CAUSAL_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$W0_CAUSAL_COMMIT_STATUS_RC" = 0
test -z "$W0_CAUSAL_COMMIT_STATUS"
```

Expected: all tests pass; exact fixture set committed.

---

### Task 7: Freeze Independent Main/Sub Context Envelopes and Correlation

**Files:**
- Create schema/checker/test and fixture directory listed above.

**Interfaces:**

```text
@dataclass(frozen=True)
class AgentEnvelope:
    schema_version: Literal[1]
    work_unit_id: str
    attempt_id: str
    generation: int
    sender_agent_id: str
    sender_role: Literal["main", "sub"]
    recipient_agent_id: str
    recipient_role: Literal["main", "sub"]
    artifact_kind: str
    artifact_id: str
    artifact_digest: str
    claim_class: str
    evidence_refs: tuple[str, ...]
    uncertainty_class: str
    correlation_group_id: str
    independence_basis: str
    created_at: str
    expires_at: str

def parse_envelope_bytes(raw: bytes) -> AgentEnvelope
def validate_exchange_set(raw: bytes) -> tuple[AgentEnvelope, ...]
def independent_support_count(rows: tuple[AgentEnvelope, ...]) -> int
```

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 1: Write positive fixture**

Use one Main request and two Sub proposal artifacts with separate capsule/model/retrieval roots. Give the two Subs different correlation groups and evidence refs. The Main's final synthesis references both immutable artifacts but no raw response body.

- [ ] **Step 2: Generate the exact negative matrix**

For every one of the 18 envelope fields, create a single-field missing/wrong mutation with a stable diagnostic. Add:

```text
extra-field
duplicate-key
same-sender-recipient
sub-to-sub
sub-state-commit
sub-tool-execution
shared-context-capsule
shared-kv-session
shared-mutable-cache
shared-scratchpad
raw-statelake-handle
raw-transcript
credential-shaped-value
same-source-root-counted-independent
same-provider-lineage-counted-independent
same-retrieval-root-counted-independent
same-prompt-template-counted-independent
expired-envelope
generation-regression
cross-workspace-artifact
```

- [ ] **Step 3: Write/run RED and implement**

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_main_sub_envelopes \
  >/private/tmp/qinao-main-sub-envelope-red.txt 2>&1
W0_ENVELOPE_RED_RC="$?"
set -euo pipefail
test "$W0_ENVELOPE_RED_RC" = 1
```

Expected RED before implementation. Implement the parser and validator, then
rerun under strict mode:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_main_sub_envelopes
```

Expected: at least 42 tests pass. Parser has a 64 KiB document cap, rejects
duplicate JSON keys, requires canonical bytes, uses UTC timestamps, bounds
every string/array, and never logs rejected raw values.

- [ ] **Step 4: Commit**

```bash
set -euo pipefail
git add \
  docs/superpowers/specs/qinao-main-sub-envelope-fixture-v1.schema.json \
  scripts/check_qinao_main_sub_envelopes.py \
  scripts/test_check_qinao_main_sub_envelopes.py \
  scripts/fixtures/qinao-main-sub-envelope-v1
git commit -m "test(qinao): freeze independent agent envelopes"
set +e
W0_ENVELOPE_COMMIT_STATUS="$(git status --porcelain=v1)"
W0_ENVELOPE_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$W0_ENVELOPE_COMMIT_STATUS_RC" = 0
test -z "$W0_ENVELOPE_COMMIT_STATUS"
```

Expected: exact four responsibility groups committed; no runtime multi-agent scheduler created.

---

### Task 8: Define the K4 Contract and Candidate Parity Model Under RED Tests

**Files:**
- Create: the three K4 schemas.
- Create: `scripts/qinao_k4_protocol_v1.py`.
- Create: `scripts/test_qinao_k4_protocol_v1.py`.
- Create: `scripts/qinao_k4_custody_v1.py`.
- Create: `scripts/test_qinao_k4_custody_v1.py`.

**Interfaces:**

```python
class K4State(Enum):
    INITIALIZED = "initialized"
    PROFILE_BOUND = "profileBound"
    ARCHIVE_BUILT = "archiveBuilt"
    ARCHIVE_INSPECTED = "archiveInspected"
    DEVICE_BOUND = "deviceBound"
    CHALLENGE_ISSUED = "challengeIssued"
    INSTALLED = "installed"
    LAUNCHED = "launched"
    DIRECT_REPLY_VERIFIED = "directReplyVerified"
    ASYNC_REPLY_VERIFIED = "asyncReplyVerified"
    CONTAINER_COPIED = "containerCopied"
    UNINSTALLED = "uninstalled"
    REINSTALLED = "reinstalled"
    REOPEN_VERIFIED = "reopenVerified"
    RAW_BUNDLE_SEALED = "rawBundleSealed"
    INDEPENDENTLY_ATTESTED = "independentlyAttested"
    LOCAL_RAW_CLEANED = "localRawCleaned"
    PROJECTED = "projected"
    PASSED = "passed"
    BLOCKED = "blocked"
    FAILED = "failed"

@dataclass(frozen=True)
class ArchiveBindingFixture:
    archive_tree_digest: str
    archive_info_digest: str
    host_macho_digest: str
    helper_macho_digest: str
    host_cdhash: str
    helper_cdhash: str
    host_profile_digest: str
    helper_profile_digest: str
    host_entitlements_digest: str
    helper_entitlements_digest: str
    team_id: str
    profile_id: str
    profile_version: str
    selected_xcode_identity: str
    payload_commit_oid: str
    payload_tree_oid: str

@dataclass(frozen=True)
class DeviceBindingFixture:
    private_device_identifier: str
    device_commitment: str
    platform: Literal["iOS"]
    os_major: Literal[27]
    os_version: str
    os_build: str
    connection_kind: str
    developer_mode: bool
    archive_tree_digest: str

@dataclass(frozen=True)
class ChallengeBindingFixture:
    challenge: bytes
    challenge_digest: str
    archive_tree_digest: str
    device_commitment: str
    issued_at: str
    expires_at: str

@dataclass(frozen=True)
class CustodyRootFixture:
    bundle_id: str
    bundle_root_digest: str
    manifest_digest: str
    encryption_profile_digest: str
    retention_policy_digest: str
    retained_until: str
    destruction_obligation_digest: str

@dataclass(frozen=True)
class ReopenReceiptFixture:
    bundle_root_digest: str
    manifest_digest: str
    grant_digest: str
    attester_identity_digest: str
    reopened_blob_count: int
    reopened_byte_count: int
    recomputed_root_digest: str
    opened_at: str
    closed_at: str
    result: Literal["passed", "failed"]

@dataclass(frozen=True)
class K4PublicProjectionFixture:
    schema_version: Literal[1]
    status: Literal["passed"]
    payload_commit_oid: str
    payload_tree_oid: str
    build_identity: str
    release_profile_id: str
    release_profile_version: str
    selected_xcode_identity_digest: str
    archive_root_digest: str
    host_product_digest: str
    helper_product_digest: str
    host_cdhash_commitment: str
    helper_cdhash_commitment: str
    host_profile_commitment: str
    helper_profile_commitment: str
    team_id_commitment: str
    device_commitment: str
    device_os_major: Literal[27]
    device_os_build_commitment: str
    challenge_digest: str
    direct_reply_digest: str
    async_reply_digest: str
    structured_devicectl_digest: str
    external_bundle_root: str
    external_bundle_manifest_digest: str
    custody_profile_digest: str
    ephemeral_storage_profile_digest: str
    reopen_receipt_digest: str
    attester_identity_digest: str
    retention_policy_digest: str
    retained_until: str
    destruction_obligation_digest: str
    cleanup_terminal_digest: str
    coverage: tuple[str, ...]
    result: Literal["passed"]
```

All dataclasses in this interface block are untrusted parity values used only
for schemas, canonicalization, mutation tests, and privacy classification.
They are not service messages and cannot satisfy a gate. Bootstrap alone owns
the opaque `ReleaseProfileBinding` and `ExternalPhysicalGateBinding`;
`qinao_k4_protocol_v1.py` may validate only a redacted digest/projection
fixture and must not import, parse, mirror, copy, or widen either binding.
Public digest/commitment fields are lower-case SHA-256. Raw CDHashes, Team ID,
profile IDs beyond the public Owner-Ledger profile identity, device ID/build,
challenge, path, and trace never occur in `K4PublicProjectionFixture`.

Low-entropy private values are not hashed bare. The production contract
requires the controller-side producer to obtain one 32-byte
`projection_blinding_nonce` from the broker's protected random source after
archive/device binding, place it only in the encrypted raw bundle, and compute
each `*_commitment` as
`domain_digest(b"qinao-k4-private-commitment-v1",
projection_blinding_nonce, field_domain, raw_value)`. Candidate parity tests
use an injected synthetic nonce and never handle a live raw value. The
projection exposes neither nonce nor a digest of the nonce. The external
attester and active B0 primitive independently reopen and recompute it.
`challenge_digest`, artifact digests, public Owner-Ledger
`release_profile_id/version`, and already-public payload identities are
bindings rather than disguises for low-entropy private data.

Domain functions are exact:

```python
def domain_digest(domain: bytes, *parts: bytes) -> str:
    return hashlib.sha256(
        domain + b"\0" + b"\0".join(
            len(part).to_bytes(8, "big") + part for part in parts
        )
    ).hexdigest()

def challenge_digest(binding: ChallengeBindingFixture) -> str:
    return domain_digest(
        b"qinao-k4-challenge-v1",
        binding.challenge,
        binding.archive_tree_digest.encode("ascii"),
        binding.device_commitment.encode("ascii"),
        binding.issued_at.encode("ascii"),
        binding.expires_at.encode("ascii"),
    )
```

The parity state transition table is total and models the Bootstrap broker's
linear contract. `BLOCKED` may be entered from `INITIALIZED` or
`PROFILE_BOUND` only for an unavailable external prerequisite before a
physical effect. Any mismatch after archive/device activity is `FAILED`, never
`BLOCKED`. `CHALLENGE_ISSUED` requires both `ARCHIVE_INSPECTED` and
`DEVICE_BOUND`; `LOCAL_RAW_CLEANED` requires independent external reopen plus a
signed key/volume no-residue terminal; `PROJECTED` requires that cleanup
terminal. A caller challenge field is not part of any parser.

The private bundle manifest contains exactly:

```text
schema_version
bundle_id
payload_commit_oid
payload_tree_oid
build_identity
producer_identity_digest
attester_identity_digest
evaluation_lease_digest
release_profile_binding_digest
archive_binding_digest
device_binding_digest
challenge_binding_digest
encryption_profile_digest
ephemeral_storage_profile_digest
retention_policy_digest
retained_until
destruction_obligation_digest
cleanup_policy_digest
entries
bundle_root_digest
```

Each entry contains exactly `role`, `media_type`, `byte_count`, `sha256`, `chunk_count`, and `chunk_root_digest`. The exact required roles are:

```text
admission-evaluation-lease-envelope
payload-object-reopen-receipt
selected-xcode-version
selected-sdk-identity
xcodebuild-archive-log
xcodebuild-result-bundle
archive-tree-inventory
archive-info-plist
host-macho
helper-macho
host-codesign-detail
helper-codesign-detail
host-signed-entitlements
helper-signed-entitlements
host-embedded-profile-cms
helper-embedded-profile-cms
host-decoded-profile
helper-decoded-profile
device-list-json
install-json
launch-json
process-list-json
first-container-copy-json
first-container-trace
uninstall-json
reinstall-json
relaunch-json
reopen-process-list-json
reopen-container-copy-json
reopen-container-trace
direct-xpc-request-reply
async-xpc-request-reply
cancellation-timeout-drain
private-challenge-binding
```

`private-challenge-binding` is a canonical private object containing the raw challenge binding plus the independent 32-byte `projection_blinding_nonce`; neither value or nonce digest enters the public projection. An absent, extra, duplicate, empty, symlink, nonregular, oversized-without-chunking, or digest-mismatched role fails.

The public projection coverage is exactly:

```text
archive
code-signing
entitlements
provisioning
physical-ios27
structured-devicectl
direct-xpc
async-xpc
timeout-cancellation-drain
uninstall-reinstall-reopen
external-encrypted-custody
independent-reopen
retention-destruction
encrypted-ephemeral-cleanup
```

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 1: Write protocol RED tests**

Tests cover exact keys, duplicate keys, noncanonical JSON, wrong enums, every
illegal state jump, challenge before archive, challenge before device, caller
challenge alias, changed archive/device after challenge, malformed digest,
privacy leak in every public string, raw
path/UDID/Team/profile/CDHash/challenge/log fragment, wrong coverage, passed
projection without reopen, projection before cleanup, wrong cleanup terminal,
and any import/construction of an opaque Bootstrap binding.

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_k4_protocol_v1 \
  >/private/tmp/qinao-k4-protocol-red.txt 2>&1
K4_PROTOCOL_RED_RC="$?"
set -euo pipefail
test "$K4_PROTOCOL_RED_RC" = 1
```

Expected: at least 36 tests discovered and the forbidden opaque-binding
reference is rejected by the typed boundary.

- [ ] **Step 2: Implement canonical protocol values**

Use frozen dataclasses, exact field-name sets, duplicate-key rejection, canonical UTF-8 JSON with one LF, RFC 3339 UTC timestamps, 64 KiB metadata cap, checked integer bounds, sorted-unique tuples, and explicit domain separators. No `dict.get` default may turn a missing required field into a value. Define `K4_PROBE_PATHS_V1` as the literal, ordered 21-string tuple in Task 9 Step 1; protocol tests assert exact byte equality and cardinality.

- [ ] **Step 3: Make protocol tests green**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_k4_protocol_v1
```

Expected: at least 36 tests pass; no skip.

- [ ] **Step 4: Write custody frame/parity RED tests**

The candidate module is a pure frame codec plus deterministic in-memory
semantic model. It opens no descriptor/socket/path/URL, reads no environment,
accepts no token/key/credential/capability, and exposes no production client.
Its closed parity surface is:

```text
encode_frame(canonical_json_header: bytes, blob: bytes) -> bytes
decode_frame(frame: bytes) -> tuple[bytes, bytes]
CustodyParityModel.begin_bundle(manifest_header: bytes) -> str
CustodyParityModel.put_chunk_no_replace(
    bundle_id: str, role: str, index: int, data: bytes, sha256: str
) -> None
CustodyParityModel.seal_bundle(
    bundle_id: str, manifest: bytes
) -> CustodyRootFixture
CustodyParityModel.request_reopen_grant(
    bundle_root_digest: str, attester_identity_digest: str
) -> str
CustodyParityModel.read_chunk(grant: str, role: str, index: int) -> bytes
CustodyParityModel.close_grant(grant: str) -> bytes
CustodyParityModel.read_retention_state(bundle_root_digest: str) -> bytes
CustodyParityModel.destroy_bundle(
    bundle_root_digest: str, destruction_lease: bytes
) -> bytes
```

Only the Bootstrap external service performs authenticated encryption, key
custody, monotonic no-replace, immutable sealing, grant authorization,
retention, destruction, and crash cleanup. The pure frame bytes are
`uint64be(length) || canonical_json_header || uint64be(blob_length) || blob`;
the codec rejects partial/trailing/oversized frames.

- [ ] **Step 5: Implement and test custody parity**

Use only immutable `bytes`, injected deterministic clock/random fixtures, and an
in-memory mapping. AST/import tests reject `socket`, network libraries,
subprocess, Git, Keychain, filesystem writes, environment reads, Bootstrap
protocol imports, or descriptor construction. Tests cover partial/trailing
frames, changed chunks, replayed sequence, expired grant, wrong attester, wrong
root, post-destroy read, destruction-before-retention, cleanup-terminal
mismatch, and a fake capability field.

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_k4_custody_v1
```

Expected: at least 20 tests pass; no external service is falsely claimed.

- [ ] **Step 6: Commit schemas/protocol/custody**

```bash
set -euo pipefail
git add \
  docs/superpowers/specs/qinao-k4-production-run-v1.schema.json \
  docs/superpowers/specs/qinao-k4-private-bundle-manifest-v1.schema.json \
  docs/superpowers/specs/qinao-k4-public-projection-v1.schema.json \
  scripts/qinao_k4_protocol_v1.py \
  scripts/test_qinao_k4_protocol_v1.py \
  scripts/qinao_k4_custody_v1.py \
  scripts/test_qinao_k4_custody_v1.py
set +e
K4_CONTRACT_CACHED_PATHS="$(git diff --cached --name-only)"
K4_CONTRACT_CACHED_PATHS_RC="$?"
set -euo pipefail
test "$K4_CONTRACT_CACHED_PATHS_RC" = 0
test "$(
  printf '%s\n' "$K4_CONTRACT_CACHED_PATHS" |
    LC_ALL=C sort
)" = "$(
  printf '%s\n' \
    docs/superpowers/specs/qinao-k4-private-bundle-manifest-v1.schema.json \
    docs/superpowers/specs/qinao-k4-production-run-v1.schema.json \
    docs/superpowers/specs/qinao-k4-public-projection-v1.schema.json \
    scripts/qinao_k4_custody_v1.py \
    scripts/qinao_k4_protocol_v1.py \
    scripts/test_qinao_k4_custody_v1.py \
    scripts/test_qinao_k4_protocol_v1.py |
    LC_ALL=C sort
)"
git commit -m "test(qinao): define fail-closed K4 parity contract"
set +e
K4_CONTRACT_COMMIT_STATUS="$(git status --porcelain=v1)"
K4_CONTRACT_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$K4_CONTRACT_COMMIT_STATUS_RC" = 0
test -z "$K4_CONTRACT_COMMIT_STATUS"
```

Expected: exact seven-path commit.

---

### Task 9: Promote Only the Privacy-Clean K4 Probe Source

**Files:**
- Read only as provenance input: the exact 20 non-log, non-signature-dump files beneath `docs/superpowers/evidence/qinao-k4-platform-spike/spike/` that Task 1 imported through reviewed C3 destination CAS.
- Create/adapt: the exact 20 corresponding paths beneath `scripts/fixtures/qinao-k4-platform-probe/`.
- Create deterministically from the final 20 postimages: `scripts/fixtures/qinao-k4-platform-probe/source-manifest-v1.json`.
- Create: `scripts/test_qinao_k4_probe_source.py`.
- Delete from the final W0 tree: the 20 temporary preliminary source inputs after their provenance and final postimages are verified.
- Never create beneath that prefix: logs, archive, profile, signature dump, device output, runtime trace, status claim.

**Interfaces:**
- Consumes: 20 C3-reviewed preliminary public-API source rows as mechanism guidance, with inventory/map digests and exact source hashes.
- Produces: 20 adapted production-probe source files plus one self-excluding source manifest and one test module; no proof status.

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 1: Prove the exact 20 C3 source inputs**

Take the 21-path list in Step 4, remove only `scripts/fixtures/qinao-k4-platform-probe/source-manifest-v1.json`, and replace its target prefix with `docs/superpowers/evidence/qinao-k4-platform-spike/spike/`. Require those exact 20 source paths to be regular files whose Git blob bytes/modes equal the corresponding reviewed C3 rows. Require the two `pre-w5-*-signed-entitlements.plist` files, `logs/`, and `status.json` absent from the selected set. A missing mapping, non-C3 decision, wrong source stratum/hash/mode, or extra selected preliminary source is top-level `BLOCKED_IMPORT_REVIEW` with reason `BLOCKED_C3_REVIEW`; do not copy from the dirty worktree.

- [ ] **Step 2: Write RED production-source tests**

`scripts/test_qinao_k4_probe_source.py` creates source mutations and requires stable failures for:

```text
hard-coded host bundle ID
hard-coded helper bundle ID
automatic signing
caller/env team or profile selector
missing host/helper Info binding
missing 32-byte producer challenge parser
fixed challenge or correlation ID
stdout pass/fail marker
missing atomic canonical trace
trace without direct or async reply
trace without timeout/cancellation drain
trace with pending or unexpected reply
helper embedded under PlugIns
deployment target below 27
generated/private protocol assumption
manifest missing/extra/self-including/stale path
manifest source-provenance mismatch
```

Run:

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_k4_probe_source \
  >/private/tmp/qinao-k4-probe-source-red.txt 2>&1
K4_PROBE_SOURCE_RED_RC="$?"
set -euo pipefail
test "$K4_PROBE_SOURCE_RED_RC" = 1
```

Expected: at least 18 tests are discovered and fail before adaptation.

- [ ] **Step 3: Adapt the proven mechanism into the production probe**

Copy the 20 C3-imported inputs to their one-to-one target suffixes, then make these explicit W0 adaptations:

- replace all `com.example...` Swift literals with exact Info keys `QinaoK4HostBundleIdentifier` and `QinaoK4HelperBundleIdentifier`; both values must be nonempty, distinct, and equal the inspected signed products;
- make target build settings consume `QINAO_K4_HOST_BUNDLE_ID`, `QINAO_K4_HELPER_BUNDLE_ID`, separate manual-signing team/profile variables, and separate entitlement files from the private authority-derived xcconfig; no default bundle ID, team, profile, or `Automatic` signing remains;
- parse exactly one producer-created `qinao-k4-challenge-v1:<unpadded-base64url>` application argument into exactly 32 bytes; reject missing, duplicate, malformed, or extra challenge arguments before opening XPC;
- derive per-run direct/async correlation IDs from the challenge with domain separation rather than fixed `direct-1`/`async-1`;
- write one versioned canonical trace atomically at `Library/Application Support/QinaoK4/trace.json` with file protection, challenge digest, direct and asynchronous typed request/reply facts, timeout/cancellation drain, exact counts, zero pending, zero unexpected, process/run identity, and a terminal enum; the producer binds that trace digest and challenge to the already-inspected archive/device binding outside the app;
- remove all `K4SPIKE PASS`, `K4SPIKE FAIL`, `ARCHIVE SUCCEEDED`, and `valid on disk` markers. Console text is diagnostic only and cannot contain a success Boolean.

The host obtains the helper identity from the bound Info value; the helper obtains the host identity the same way. `@Definition`, `EnhancedSecurity`, the narrow source-defined `AppExtension` protocol, direct typed reply, and asynchronous `session.send(reply)` remain the only reused public-API mechanisms.

- [ ] **Step 4: Generate and require the exact 21-path set**

The final set is exactly:

```text
scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.entitlements
scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.swift
scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHost.entitlements
scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHostApp.swift
scripts/fixtures/qinao-k4-platform-probe/K4PlatformSpike.xcodeproj/project.pbxproj
scripts/fixtures/qinao-k4-platform-probe/K4PlatformSpike.xcodeproj/project.xcworkspace/contents.xcworkspacedata
scripts/fixtures/qinao-k4-platform-probe/K4PlatformSpike.xcodeproj/xcshareddata/xcschemes/K4SpikeHost.xcscheme
scripts/fixtures/qinao-k4-platform-probe/Shared/SpikeMessages.swift
scripts/fixtures/qinao-k4-platform-probe/fixtures/EnhancedSecurityInitializerShapes.swift
scripts/fixtures/qinao-k4-platform-probe/fixtures/NoGeneratedProtocol.swift
scripts/fixtures/qinao-k4-platform-probe/fixtures/XPCReplyShapes.swift
scripts/fixtures/qinao-k4-platform-probe/generated-metadata/extension-binding-fragment.plist
scripts/fixtures/qinao-k4-platform-probe/generated-metadata/extension-binding-info.plist
scripts/fixtures/qinao-k4-platform-probe/generated-metadata/host-extension-point.appexpt
scripts/fixtures/qinao-k4-platform-probe/generated-metadata/sdk-public-interface-symbols.txt
scripts/fixtures/qinao-k4-platform-probe/project.yml
scripts/fixtures/qinao-k4-platform-probe/source-manifest-v1.json
scripts/fixtures/qinao-k4-platform-probe/template-snapshot/AppExtension-EnhancedSecurity.entitlements
scripts/fixtures/qinao-k4-platform-probe/template-snapshot/AppExtension-EnhancedSecurity.swift
scripts/fixtures/qinao-k4-platform-probe/template-snapshot/ExtensionKit-Base-TemplateInfo.plist
scripts/fixtures/qinao-k4-platform-probe/template-snapshot/TemplateInfo.plist
```

Generate `source-manifest-v1.json` only after all 20 target postimages are final. It has `schema_version = 1`, `authority = "none"`, `proof_status = "source_only"`, the canonical C0 inventory/import-map digests, and exactly 20 rows with source `path_b64`/source SHA-256/source mode plus target path/target SHA-256/target mode. It excludes itself.

Run:

```bash
set -euo pipefail
find scripts/fixtures/qinao-k4-platform-probe -type f -print | LC_ALL=C sort \
  > /private/tmp/qinao-k4-probe-actual.txt
python3 -c 'from pathlib import Path; from scripts.qinao_k4_protocol_v1 import K4_PROBE_PATHS_V1; rows=Path("/private/tmp/qinao-k4-probe-actual.txt").read_text().splitlines(); assert tuple(rows)==K4_PROBE_PATHS_V1; assert len(rows)==21'
```

`K4_PROBE_PATHS_V1` is the literal 21-string tuple printed immediately above and is frozen in `qinao_k4_protocol_v1.py`. Expected: exact set and cardinality 21. Exactly 20 rows carry C3 source provenance; the manifest is the sole deterministically generated twenty-first path.

- [ ] **Step 5: Enforce the proven public SDK facts**

The source must:

- define its own narrow shared `AppExtension` protocol; it must not assume a generated `SovereignK4` protocol;
- use public `EnhancedSecurity()` or `EnhancedSecurity(true)`;
- set `EX_ENABLE_EXTENSION_POINT_GENERATION=YES` on both host and helper targets;
- embed the ExtensionKit helper under `Extensions/K4SpikeExtension.appex`, never `PlugIns`;
- set both deployment targets to `27.0`;
- carry separate host/helper bundle IDs and manual-signing profile bindings supplied by a private generated xcconfig;
- implement direct typed reply and asynchronous `session.send(reply)` shapes;
- require exact correlation, route, responder, delivery, challenge, request/reply count, five-second timeout, cancellation, zero pending continuation, and zero unexpected reply.

`K4SPIKE PASS`, `ARCHIVE SUCCEEDED`, `valid on disk`, or another marker is forbidden from the final source and is never accepted as evidence.

- [ ] **Step 6: Verify source manifest and privacy**

`source-manifest-v1.json` binds the exact 20 other final paths and their C3 source provenance, excludes itself, has `authority = "none"` and `proof_status = "source_only"`, and contains no absolute path/account/device/profile/certificate identifier.

```bash
set -euo pipefail
set +e
rg -n '/Users/|UDID|TeamIdentifier|ProvisionedDevices|DeveloperCertificates|BEGIN (RSA |EC )?PRIVATE KEY|K4SPIKE PASS|ARCHIVE SUCCEEDED|valid on disk' \
  scripts/fixtures/qinao-k4-platform-probe \
  >/private/tmp/qinao-k4-probe-privacy-scan.txt 2>&1
K4_PRIVACY_SCAN_RC="$?"
set -euo pipefail
test "$K4_PRIVACY_SCAN_RC" = 1
test ! -s /private/tmp/qinao-k4-probe-privacy-scan.txt
```

Expected: exit `1` with zero matches. Exit `2` is failure.

- [ ] **Step 7: Make source tests green**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_k4_probe_source
```

Expected: at least 18 tests pass, exact 21-path/source-provenance checks included, zero skip.

- [ ] **Step 8: Unsigned public-API build is only a fixture test**

Before `Pw`, the candidate parity harness clears inherited Xcode selectors,
reads the host's one active `xcode-select` developer directory, and requires
its observed major version to be 27 before setting parity-local
`SELECTED_DEVELOPER_DIR`. It does not scan for or choose among installations.
This is compile coverage only: it neither consumes a Bootstrap binding nor
selects a W0 release. Run:

```bash
set -euo pipefail
unset DEVELOPER_DIR TOOLCHAINS SDKROOT
SELECTED_DEVELOPER_DIR="$(/usr/bin/xcode-select --print-path)"
test -n "$SELECTED_DEVELOPER_DIR"
test -x "$SELECTED_DEVELOPER_DIR/usr/bin/xcodebuild"
test -x /usr/bin/xcrun
XCODE_VERSION="$("$SELECTED_DEVELOPER_DIR/usr/bin/xcodebuild" -version)"
case "$XCODE_VERSION" in
  "Xcode 27."*) ;;
  *) printf '%s\n' "$XCODE_VERSION" >&2; exit 1 ;;
esac
test "$(
  env -u TOOLCHAINS -u SDKROOT \
    DEVELOPER_DIR="$SELECTED_DEVELOPER_DIR" \
    /usr/bin/xcrun --find xcodebuild
)" = "$SELECTED_DEVELOPER_DIR/usr/bin/xcodebuild"
"$SELECTED_DEVELOPER_DIR/usr/bin/xcodebuild" \
  -project scripts/fixtures/qinao-k4-platform-probe/K4PlatformSpike.xcodeproj \
  -scheme K4SpikeHost \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/qinao-k4-probe-unsigned-derived \
  CODE_SIGNING_ALLOWED=NO \
  clean build
env -u TOOLCHAINS -u SDKROOT \
  DEVELOPER_DIR="$SELECTED_DEVELOPER_DIR" \
  /usr/bin/xcrun --sdk iphoneos swiftc -typecheck \
  -target arm64-apple-ios27.0 \
  scripts/fixtures/qinao-k4-platform-probe/fixtures/EnhancedSecurityInitializerShapes.swift \
  scripts/fixtures/qinao-k4-platform-probe/fixtures/XPCReplyShapes.swift
set +e
env -u TOOLCHAINS -u SDKROOT \
  DEVELOPER_DIR="$SELECTED_DEVELOPER_DIR" \
  /usr/bin/xcrun --sdk iphoneos swiftc -typecheck \
  -target arm64-apple-ios27.0 \
  scripts/fixtures/qinao-k4-platform-probe/fixtures/NoGeneratedProtocol.swift \
  >/private/tmp/qinao-k4-no-generated-protocol.txt 2>&1
NO_GENERATED_PROTOCOL_RC="$?"
set -euo pipefail
test "$NO_GENERATED_PROTOCOL_RC" = 1
set +e
K4_EXPECTED_PRIMARY_COUNT="$(
  rg -c \
    "^[^:]+:[0-9]+:[0-9]+: error: cannot find type 'SovereignK4' in scope$" \
    /private/tmp/qinao-k4-no-generated-protocol.txt
)"
K4_EXPECTED_PRIMARY_RG_RC="$?"
K4_ALL_PRIMARY_COUNT="$(
  rg -c \
    "^[^:]+:[0-9]+:[0-9]+: (error|warning): .+$" \
    /private/tmp/qinao-k4-no-generated-protocol.txt
)"
K4_ALL_PRIMARY_RG_RC="$?"
set -euo pipefail
test "$K4_EXPECTED_PRIMARY_RG_RC" = 0
test "$K4_ALL_PRIMARY_RG_RC" = 0
test "$K4_EXPECTED_PRIMARY_COUNT" = 1
test "$K4_ALL_PRIMARY_COUNT" = 1
```

Expected: selector/version/resolution checks and both builds pass. The source
tests execute the selector block against a fake Xcode 27, a wrong-major
installation, a missing `xcodebuild`, an inherited-selector attempt, and an
`xcrun` resolution mismatch; only the first passes. The negative fixture must
exit exactly `1` for the one missing `SovereignK4` type diagnostic; exit `2`,
a missing file, a tool failure, or another compiler diagnostic is not the
expected negative. This is API/source coverage only and cannot satisfy K4.

- [ ] **Step 9: Remove temporary preliminary inputs and commit the adapted source**

Delete only the exact 20 C3-imported preliminary input paths after the manifest/test have verified their provenance and the final 20 postimages. Do not delete a pre-existing preliminary path outside that exact set. Build a reviewed NUL-delimited pathspec containing the 20 deletions, the 21 final probe paths, and `scripts/test_qinao_k4_probe_source.py`; compare it byte-for-byte to the staged set, then:

```bash
set -euo pipefail
python3 -c 'from scripts.qinao_k4_protocol_v1 import K4_PROBE_PATHS_V1; tp="scripts/fixtures/qinao-k4-platform-probe/"; sp="docs/superpowers/evidence/qinao-k4-platform-spike/spike/"; targets=list(K4_PROBE_PATHS_V1); sources=[sp+p[len(tp):] for p in targets if not p.endswith("/source-manifest-v1.json")]; paths=sorted(set(sources+targets+["scripts/test_qinao_k4_probe_source.py"])); assert len(sources)==20 and len(targets)==21 and len(paths)==42; open("/private/tmp/qinao-k4-probe-reviewed-paths.z","wb").write(b"".join(p.encode("utf-8")+b"\0" for p in paths))'
git add --pathspec-from-file=/private/tmp/qinao-k4-probe-reviewed-paths.z --pathspec-file-nul
set +e
K4_PROBE_CACHED_PATHS="$(git diff --cached --name-only)"
K4_PROBE_CACHED_PATHS_RC="$?"
set -euo pipefail
test "$K4_PROBE_CACHED_PATHS_RC" = 0
test "$(
  printf '%s\n' "$K4_PROBE_CACHED_PATHS" |
    awk 'NF { count += 1 } END { print count + 0 }'
)" = 42
python3 -c 'import subprocess; expected=open("/private/tmp/qinao-k4-probe-reviewed-paths.z","rb").read(); actual=subprocess.check_output(["git","diff","--cached","--name-only","-z"]); assert actual==expected,(expected,actual)'
git commit -m "feat(qinao): adapt reviewed K4 source into production probe"
set +e
K4_PROBE_COMMIT_STATUS="$(git status --porcelain=v1)"
K4_PROBE_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$K4_PROBE_COMMIT_STATUS_RC" = 0
test -z "$K4_PROBE_COMMIT_STATUS"
```

Expected: one exact migration commit; the final W0 tree contains the 21 production-probe paths and test module, no preliminary K4 source/log/status/signature dump, and no result or proof claim.

---

### Task 10: Implement Candidate K4 Parity/Preflight Tools and the Hardened Compare-Only Checker

**Files:**
- Create: parity producer/attester/state-machine simulator and their three tests.
- Modify: `scripts/check_k4_platform_proof.py`.
- Modify: `scripts/test_check_k4_platform_proof.py`.
- Create: `scripts/fixtures/qinao-k4-checker-v1/valid-synthetic-test-only.json`.

**Interfaces:**

```text
@dataclass(frozen=True)
class ParityProducerFixture:
    payload_commit_oid: str
    payload_tree_oid: str
    build_identity: str
    release_profile_projection: Mapping[str, object]
    external_physical_gate_binding_digest: str
    synthetic_command_results: tuple[SyntheticCommandResult, ...]

@dataclass(frozen=True)
class ParityProducerObservation:
    synthetic_custody_root: str
    private_manifest_digest: str
    archive_binding_digest: str
    device_binding_digest: str
    challenge_digest: str

def simulate_capture(
    fixture: ParityProducerFixture
) -> ParityProducerObservation

@dataclass(frozen=True)
class ParityAttesterFixture:
    producer_observation: ParityProducerObservation
    synthetic_reopen_bytes: Mapping[str, bytes]
    distinct_principal_digest: str

@dataclass(frozen=True)
class ParityAttesterObservation:
    synthetic_reopen_receipt: Mapping[str, object]
    privacy_projection: K4PublicProjectionFixture

def simulate_attestation(
    fixture: ParityAttesterFixture
) -> ParityAttesterObservation
```

These are non-authoritative fixture types, not Bootstrap types or production
messages. Candidate modules never parse an `EvaluationLease`, never receive a
custody/lease/result descriptor, never construct
`ExternalPhysicalGateBinding`, and never emit a gate-result or admission leaf.
Tests model the required distinction between producer and attester, but the
actual principals, processes, encrypted custody, reopen grant, signatures, and
projection are created only by Bootstrap's controller-side broker in Task 13.

- [ ] **Step 0: Re-enter through the permanent guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse "$PREW0_PW^{tree}")" = "$PREW0_PW_TREE"
```

Then independently reopen the signed admitted predecessor through the service. Expected: exact tuple equality.

- [ ] **Step 1: Replace old checker tests with production-authority negatives**

Preserve pure fixture parser tests, but delete any assertion that a repository directory, source marker, plist, JSON status, copied log, `ARCHIVE SUCCEEDED`, `valid on disk`, `K4SPIKE PASS`, caller nonce/challenge, caller `--expected-team-id`, or `/Library/...ExecutionGate` can pass production.

The fixture and broker-private compare-only command shapes are exactly:

```bash
set -euo pipefail
python3 scripts/check_k4_platform_proof.py \
  --fixture \
  --bundle scripts/fixtures/qinao-k4-checker-v1/valid-synthetic-test-only.json
python3 scripts/check_k4_platform_proof.py \
  --production-projection "$PARITY_RUN_ROOT/k4-public-projection.json" \
  --signed-attestation "$PARITY_RUN_ROOT/k4-independent-attestation.json" \
  --reopen-receipt "$PARITY_RUN_ROOT/k4-reopen-receipt.json" \
  --payload-commit "$W0_PW" \
  --payload-tree "$W0_PW_TREE"
```

Modes are mutually exclusive. `--fixture` is accepted only when the fixture
says `proof_class = "synthetic-test-only"` and production-projection comparison
rejects that class. `PARITY_RUN_ROOT` is a broker-created, read-only,
privacy-filtered scratch projection exposed only for parity diagnostics; it is
not raw custody and its output is not consumed by the active gate. There is no
`--root`, `--evidence`, `--expected-team-id`, `--challenge`, `--success`, or
marker/log mode.

- [ ] **Step 2: Run checker RED**

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_k4_platform_proof \
  >/private/tmp/qinao-k4-checker-red.txt 2>&1
K4_CHECKER_RED_RC="$?"
set -euo pipefail
test "$K4_CHECKER_RED_RC" = 1
```

Expected: at least 30 tests discovered; legacy-acceptance tests fail until checker is replaced.

- [ ] **Step 3: Implement compare-only checker**

Broker-projection compare-only mode:

1. parses three closed canonical objects;
2. uses a read-only Bootstrap verification adapter, without importing or
   mirroring its types, to verify the attestation against the signed service
   binding and attester identity;
3. requires attester principal distinct from producer, product signer, profile issuer, and candidate;
4. requires projection/reopen/attestation exact payload, archive, device,
   challenge, external-root, retention, cleanup-terminal, and coverage
   equality;
5. requires `reopened_blob_count = 34`, positive bytes, equal recomputed root,
   `result = passed`, fresh timestamps, active retention, no destruction
   receipt, and a valid local-key/volume no-residue terminal;
6. applies the privacy classifier to the complete projection bytes;
7. emits one canonical summary line and no raw value.

It cannot validate physical truth from the projection alone and cannot return
a `GateResult`; the active B0 `physical_evidence_external_root` primitive
receives the signed broker projection, independently reopens external custody,
and runs the B0-owned validators.

- [ ] **Step 4: Make checker tests green**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_k4_platform_proof
```

Expected: at least 30 pass, including every legacy-fiction negative.

- [ ] **Step 5: Write parity state-machine RED tests**

Use injected synthetic `CommandResultSource`, `Clock`, `RandomSource`, and
`CustodyFixture`. Tests assert the exact broker contract sequence without
launching a production command:

```text
consume a redacted binding projection for exact W0 Pw/PwTree
derive selected release Xcode/profile/team fixture from that projection
write private per-target xcconfig
archive
inspect archive/signatures/profiles/entitlements
structured physical-device listing
select exactly one iOS 27 policy match
bind archive plus device
generate fresh 32-byte challenge
generate independent fresh 32-byte projection blinding nonce
install
launch
inspect processes
copy first container
validate direct reply
validate asynchronous reply
validate timeout/cancel/zero pending
uninstall
reinstall
relaunch
inspect reopened processes
copy reopened container
validate reopened trace
model raw-bundle external sealing and independent reopen
```

Mutations reorder each adjacent pair, inject challenge before binding, pass
team/profile/device/challenge through candidate CLI/environment, substitute a
simulator, use Xcode beta when release is required, use `PlugIns`, collapse
profiles, parse human output, omit JSON output, reuse stale output, or accept a
marker. Tests also reject any candidate attempt to parse a lease, request a
custody grant, sign an attestation, emit a gate result, or select a production
device.

- [ ] **Step 6: Implement archive-command parity validation**

The parity validator begins from an explicit synthetic environment allowlist
and rejects inherited `DEVELOPER_DIR`, `TOOLCHAINS`, `SDKROOT`,
signing/profile/team/device selector variables, `DEVICECTL_CHILD_*`, and
credential-shaped keys. It validates a redacted signed-binding projection,
derives `SELECTED_XCODE_APP` and
`SELECTED_DEVELOPER_DIR = SELECTED_XCODE_APP/Contents/Developer`, and compares
the recorded archive invocation to the exact mechanical shape:

```text
SELECTED_DEVELOPER_DIR/usr/bin/xcodebuild
-project scripts/fixtures/qinao-k4-platform-probe/K4PlatformSpike.xcodeproj
-scheme K4SpikeHost
-configuration Release
-destination generic/platform=iOS
-archivePath PRIVATE_RUN_ROOT/K4PlatformSpike.xcarchive
-derivedDataPath PRIVATE_RUN_ROOT/DerivedData
-xcconfig PRIVATE_RUN_ROOT/release-binding.xcconfig
-resultBundlePath PRIVATE_RUN_ROOT/archive.xcresult
archive
```

The candidate does not run this authoritative archive during W0 admission. The
controller-side producer substitutes the concrete path only after Bootstrap
verifies the opaque binding. Parity checks require `CODE_SIGN_STYLE = Manual`,
distinct host/helper team/profile/bundle/entitlement values, no fallback
defaults, no `-allowProvisioningUpdates`, no automatic profile creation, and
no keychain/profile/caller selection.

Inspect:

- exact archive regular-tree inventory with no symlink escape;
- host at `Products/Applications/K4SpikeHost.app`;
- helper at `Products/Applications/K4SpikeHost.app/Extensions/K4SpikeExtension.appex`;
- `codesign --verify --deep --strict` host and strict helper;
- `codesign -d --verbose=4`, `codesign -d --entitlements :-`;
- both `embedded.mobileprovision` files through `security cms -D -i`;
- Team ID, application identifiers, profile class, expiration, devices, entitlements, bundle IDs, architectures, minimum OS, and generated extension metadata against the signed release row.

Any mismatch is `FAILED`.

- [ ] **Step 7: Implement physical-device transcript parity before challenge**

Validate that every recorded `devicectl` invocation uses executable
`/usr/bin/xcrun` with a separate exact environment binding
`DEVELOPER_DIR=SELECTED_DEVELOPER_DIR`, cleared `TOOLCHAINS`/`SDKROOT`, and
an `xcrun --find xcodebuild` result equal to
`SELECTED_DEVELOPER_DIR/usr/bin/xcodebuild`. Reject unbound ambient
`/usr/bin/xcrun`, inherited `DEVELOPER_DIR`, a caller path, or an
Xcode-internal `usr/bin/xcrun` assumption. Device discovery uses structured
output:

```text
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl list devices
--json-output PRIVATE_RUN_ROOT/device-list.json
--log-output PRIVATE_RUN_ROOT/device-list.log
```

The parity model parses synthetic JSON and proves that the controller-side
contract selects exactly one connected, developer-mode physical iOS device
satisfying the signed OS-build policy. It models zero/multiple matches as
`BLOCKED_K4` only before any physical effect and proves archive/device binding
precedes challenge generation. It never observes or selects a live device.

- [ ] **Step 8: Implement structured transcript parity**

All recorded commands must use the same bound `SELECTED_DEVELOPER_DIR`,
require `--json-output` and `--log-output`, and treat JSON as the only
scripting input:

```text
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device install app --device DEVICE_ID HOST_APP --json-output INSTALL_JSON --log-output INSTALL_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device process launch --device DEVICE_ID --terminate-existing HOST_BUNDLE_ID CHALLENGE_ARGUMENT --json-output LAUNCH_JSON --log-output LAUNCH_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device info processes --device DEVICE_ID --json-output PROCESS_JSON --log-output PROCESS_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device copy from --device DEVICE_ID --source Library/Application Support/QinaoK4/trace.json --destination FIRST_TRACE --domain-type appDataContainer --domain-identifier HOST_BUNDLE_ID --json-output FIRST_COPY_JSON --log-output FIRST_COPY_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device uninstall app --device DEVICE_ID HOST_BUNDLE_ID --json-output UNINSTALL_JSON --log-output UNINSTALL_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device install app --device DEVICE_ID HOST_APP --json-output REINSTALL_JSON --log-output REINSTALL_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device process launch --device DEVICE_ID --terminate-existing HOST_BUNDLE_ID CHALLENGE_ARGUMENT --json-output RELAUNCH_JSON --log-output RELAUNCH_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device info processes --device DEVICE_ID --json-output REOPEN_PROCESS_JSON --log-output REOPEN_PROCESS_LOG
env -u TOOLCHAINS -u SDKROOT DEVELOPER_DIR=SELECTED_DEVELOPER_DIR /usr/bin/xcrun devicectl device copy from --device DEVICE_ID --source Library/Application Support/QinaoK4/trace.json --destination REOPEN_TRACE --domain-type appDataContainer --domain-identifier HOST_BUNDLE_ID --json-output REOPEN_COPY_JSON --log-output REOPEN_COPY_LOG
```

`DEVICE_ID`, `HOST_APP`, `HOST_BUNDLE_ID`, `CHALLENGE_ARGUMENT`, and private
paths remain controller-side values and are not candidate CLI parameters.
Parity fixtures replace every raw value with a commitment or a synthetic
non-production token. The checker validates the challenge grammar, omission of
`--console`, at most 40 `Clock`-driven 250 ms read attempts, one atomically
complete terminal trace, and no console parsing or unbounded wait.

Trace validation requires one exact direct request/reply and one exact asynchronous request/reply, matching challenge/correlation/route/responder/delivery, request count one each, reply count one each, five-second bound, cancellation probe, zero pending continuation, zero unexpected reply, process identity from structured output, and first/reopen run identities.

- [ ] **Step 9: Implement custody/cleanup contract parity**

Synthetic tests model all 34 roles, bounded no-replace chunks, canonical
manifest sealing, external retention, one independent short-lived reopen, key
destruction, verified no-residue cleanup, and crash recovery. Candidate code
never receives a production custody capability or raw bundle.

For destruction:

- unit/integration tests create a separate fixture bundle, obtain an authorized destruction lease after its retention condition, destroy it, and prove reopen fails with a signed destruction receipt;
- a synthetic retained-bundle fixture proves a retained live proof would not
  destroy its externally held bundle during admission;
- a synthetic later destruction receipt invalidates certification and must
  enter the next invalidation/admission cycle.

- [ ] **Step 10: Write and implement independent-attester parity**

Tests use distinct synthetic principals/process identities and prove the
contract requires a fresh short-lived read-only grant, no producer filesystem
access, all 34 roles reopened, every digest/root and
archive/device/challenge/reply relation recomputed, repeated
signature/profile/entitlement/devicectl/trace parsing, active retention, grant
closure, local-key destruction, and no residue. A projection generated without
reopening fails. Candidate code cannot sign or submit the observation.

The attester signs:

```text
qinao-k4-independent-attestation-v1
payload commit/tree
build identity
release profile binding digest
archive binding digest
device binding digest
challenge digest
external bundle root/manifest
reopen receipt digest
retention/destruction obligations
public projection digest
result
```

The list above is the parity-checked signed content contract. In production,
only the external attester returns those bytes to Bootstrap custody; candidate
code returns only a synthetic observation to its unit test. Only the
Bootstrap-authenticated privacy-clean projection is eligible for B0.

- [ ] **Step 11: Write and implement the candidate parity simulator**

The only candidate CLI is fixture-only:

```text
python3 scripts/run_k4_platform_proof.py \
  --fixture scripts/fixtures/qinao-k4-checker-v1/valid-synthetic-test-only.json
```

The parser accepts only `--fixture` and the exact checked-in synthetic fixture;
it rejects every root, payload, ref, wave, lease, descriptor, custody, result,
device, team, profile, Xcode, challenge, output, success, or authority option.
It performs no network, Git-object/ref, Xcode, device, signing, custody, or
service operation. Bootstrap never launches this script in
`run_active_gates`.

If release profile, release Xcode 27, valid separate Enhanced Security profiles, product signing identities, one physical policy-matching iOS 27 device, external custody, independent attester, or retention/reopen capability is absent before effects, write exactly:

```text
BLOCKED_K4
```

as a synthetic state-machine terminal, exit `3`, and write no projection
claiming pass. This behavior proves parity only; Bootstrap owns the real
authenticated terminal.

Blocked-path tests use only synthetic fixtures and assert: terminal projection
`BLOCKED_K4`; no service/client import; no evidence upload; no assembly record; no
Git object-import receipt; no admission intent/finalization request; no Git ref
read/write; and no candidate authority output.

- [ ] **Step 12: Run all K4 unit tests**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_k4_protocol_v1 \
  scripts.test_qinao_k4_custody_v1 \
  scripts.test_qinao_k4_probe_source \
  scripts.test_capture_k4_platform_proof \
  scripts.test_attest_k4_external_artifact \
  scripts.test_run_k4_platform_proof \
  scripts.test_check_k4_platform_proof
```

Expected: at least 140 tests pass, zero skips. Fake processes/custody prove mechanics only; no test labels itself physical proof.

- [ ] **Step 13: Commit the candidate K4 parity/preflight tooling**

```bash
set -euo pipefail
git add \
  scripts/capture_k4_platform_proof.py \
  scripts/test_capture_k4_platform_proof.py \
  scripts/attest_k4_external_artifact.py \
  scripts/test_attest_k4_external_artifact.py \
  scripts/run_k4_platform_proof.py \
  scripts/test_run_k4_platform_proof.py \
  scripts/check_k4_platform_proof.py \
  scripts/test_check_k4_platform_proof.py \
  scripts/fixtures/qinao-k4-checker-v1/valid-synthetic-test-only.json
set +e
K4_CACHED_PATHS="$(git diff --cached --name-only)"
K4_CACHED_PATHS_RC="$?"
set -euo pipefail
test "$K4_CACHED_PATHS_RC" = 0
test "$(
  printf '%s\n' "$K4_CACHED_PATHS" |
    awk 'NF { count += 1 } END { print count + 0 }'
)" = 9
git commit -m "test(qinao): freeze iOS 27 K4 broker parity"
set +e
K4_COMMIT_STATUS="$(git status --porcelain=v1)"
K4_COMMIT_STATUS_RC="$?"
set -euo pipefail
test "$K4_COMMIT_STATUS_RC" = 0
test -z "$K4_COMMIT_STATUS"
```

Expected: exact nine-path commit. Protocol/custody files were committed in
Task 8. None of these nine paths is referenced by the active B0 production
module as a producer, attester, broker, or authority.

---

### Task 11: Prove W0 Suite Closure and Run the Complete Pre-Pw Gate

**Files:**
- Create no receipt, successor, transcript, result, or other evidence file.
- Modify no production source after the final test run.

**Interfaces:**
- Consumes: committed W0 source/test/checker tree and the independently
  reopened B0 `w0-open-set-v1` program/contract/corpus.
- Produces: one clean immutable `W0 Pw` candidate whose exact indexed suites
  can be evaluated by B0 after payload pinning. It creates no current-run gate
  result or local authority.

- [ ] **Step 1: Run root and admitted predecessor guards**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
```

Then independently reopen the signed admitted predecessor through `ProtectedAdmissionClient.reopen_admitted_predecessor()`. Expected: root/lineage/predecessor unchanged and exact tuple equality.

- [ ] **Step 2: Run all Python unit suites**

```bash
set -euo pipefail
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_apply_qinao_import_map \
  scripts.test_check_w0_expected_open_set \
  scripts.test_run_nonempty_swift_filter \
  scripts.test_check_qinao_w0_safety \
  scripts.test_check_qinao_learning_legacy_reachability \
  scripts.test_check_qinao_learning_causal_fixtures \
  scripts.test_check_qinao_main_sub_envelopes \
  scripts.test_qinao_k4_protocol_v1 \
  scripts.test_qinao_k4_custody_v1 \
  scripts.test_qinao_k4_probe_source \
  scripts.test_capture_k4_platform_proof \
  scripts.test_attest_k4_external_artifact \
  scripts.test_run_k4_platform_proof \
  scripts.test_check_k4_platform_proof \
  >/private/tmp/qinao-w0-python-closure.txt 2>&1
W0_PYTHON_RC="$?"
set -euo pipefail
test "$W0_PYTHON_RC" = 0
python3 - <<'PY'
from pathlib import Path
import re

text = Path("/private/tmp/qinao-w0-python-closure.txt").read_text(
    encoding="utf-8",
    errors="strict",
)
runs = re.findall(r"^Ran ([0-9]+) tests? in ", text, flags=re.MULTILINE)
assert len(runs) == 1, runs
assert int(runs[0]) >= 296, runs[0]
assert "skipped=" not in text, text[-2000:]
assert text.rstrip().endswith("OK"), text[-2000:]
required = (
    "test_graph_freeze_reuses_runtime_untyped_shared_agent_state_id",
    "test_graph_freeze_keeps_exact_sixteen_ids",
    "test_second_g1_writer_is_rejected",
    "test_second_g2_writer_is_rejected",
    "test_main_sub_peer_call_is_rejected",
    "test_sub_sub_peer_call_is_rejected",
    "test_shared_mutable_scratchpad_is_rejected",
    "test_legacy_loop_authority_is_rejected",
    "test_refresh_must_be_read_only_or_production_unreachable",
    "test_future_graph_contract_is_rejected_at_w0",
)
assert all(name in text for name in required), [
    name for name in required if name not in text
]
PY
```

Expected: every named module exists, at least 296 total tests pass, zero
failure/skip; all ten fully qualified `W0SafetyContractTests` selectors from
Task 2 are present in the verbose transcript.
`scripts.test_check_w0_expected_open_set` is a compatibility-parser regression
only; passing it does not satisfy `qinao.w0-open-set`, and this task never
invokes the legacy checker CLI.

- [ ] **Step 3: Run all 13 B0-frozen nonempty Swift suite rows**

From the independently reopened B0 `w0-open-set-v1` contract, execute all 13
literal `suite_rows` independently through
`scripts/run_nonempty_swift_filter.py`. Each invocation uses the exact
package, regular indexed test path, fully qualified `test_symbol`, and exact
short `Suite`/`Suite/method` selector frozen by Bootstrap Task 2. The current
helper proves non-empty discovery and executed-equals-discovered; it has no
minimum-count CLI and must not be credited with one. The explicit count
table below provides an observational local parity comparison only, while
the protected B0 runtime alone enforces the frozen per-row and 18/26
aggregate minima. No receipt, candidate checker, directory discovery, or
group filter may substitute for an independent B0 row.

After all 13 independent rows pass, repeat Task 3 Step 2's exact BAS grouped
command and Task 3 Step 3's exact Qinao grouped command once and compare the
observed transcripts with the aggregate 18/26 thresholds. This diagnostic
comparison is not enforcement. Expected observation:

```text
BASProviderBoundaryTests: 2
QinaoProviderBoundaryTests: 3
BAS five-suite group, including BASRoutedMemoryFlipTests: 18
Qinao four-suite group: >=26 (current baseline 27)
BASW0SafetyFreezeTests: 5
QinaoW0SafetyFreezeTests: 6
```

The nonempty runner, rather than Swift's zero-match exit behavior, proves
positive discovery and executed-equals-discovered for each diagnostic rerun.
Only the reopened B0 primitive and its exact aggregate constraints enforce
the frozen per-row and aggregate minima. The exact final suite set includes
`BehavioralAISubstrateTests.BASRoutedMemoryFlipTests`; omission is a W0
open-set failure.

- [ ] **Step 4: Run the iOS 27 floor gate**

```bash
set -euo pipefail
bash BehavioralAISubstrate/scripts/check-ios27-floor.sh
```

Expected: exit `0`; all three `Package.swift`, all governed Xcode settings, and `BehavioralAISubstrate/scripts/build-rust-xcframework.sh` report 27. No `18.0` or stale `.iOS(.v18)` comment remains.

- [ ] **Step 5: Run the actual SampleHost iOS gate**

Run the actual Swift-package Xcode scheme from `SampleHost/`:

```bash
set -euo pipefail
(cd SampleHost &&
xcodebuild test \
  -scheme SampleHost \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath /private/tmp/qinao-w0-samplehost-derived)
```

Expected: iOS scheme tests pass. `swift test --package-path SampleHost` on macOS is not a substitute. The protected B0 `qinao.samplehost-ios` primitive uses its signed release destination and records the authoritative result later.

- [ ] **Step 6: Commit any final source/test correction before the final closure proof**

```bash
set -euo pipefail
set +e
W0_FINAL_STATUS="$(git status --porcelain=v1)"
W0_FINAL_STATUS_RC="$?"
W0_FINAL_DIFF_PATHS="$(git diff --name-only)"
W0_FINAL_DIFF_PATHS_RC="$?"
set -euo pipefail
test "$W0_FINAL_STATUS_RC" = 0
test "$W0_FINAL_DIFF_PATHS_RC" = 0
if test -n "$W0_FINAL_STATUS"; then
  printf '%s\n' "$W0_FINAL_DIFF_PATHS" \
    > /private/tmp/qinao-w0-final-correction-paths.txt
  exit 1
fi
```

Expected: clean. If dirty, review, test, and make an exact-path commit first;
then restart Task 11 from Step 1. No correction and no evidence emission may
occur after the final closure proof begins.

- [ ] **Step 7: Reopen the exact active B0 W0 program**

Rerun Bootstrap's authenticated export/lineage verifier against the fixed
ceremony request/export and independently reopen `B0` from the admitted
predecessor. Without executing a candidate generator, recompute from the B0
blobs:

```text
program-spec-v1 raw digest
catalog raw digest and program_graph_digest
w0_open_set module/contract/corpus digests
runtime.py digest
W0 matrix cell: qinao.w0-open-set -> w0-open-set-v1
```

Require the contract's ordered primitives to be exactly
`w0_open_set_v1_exact_set` followed by `swiftpm_filter_nonempty`, with no
helper, argv, history directory, receipt-series selector, or log path.
Require exactly the 13 literal suite rows, 16 sorted safety IDs, and two
aggregate constraints frozen in Bootstrap Task 2. Byte-compare their paths,
exact short filter selectors, fully qualified suite names, member suite IDs,
and minimum counts to Step 3. Any divergence is
`BLOCKED_EXTERNAL_BOOTSTRAP/BLOCKED_NON_LITERAL_GATE_PROGRAM`; do not repair
it in W0.

- [ ] **Step 8: Verify the three-class W0 corpus without producing a result**

Reopen the B0 `w0_open_set` corpus and validate its literal positive,
negative, and mutation objects structurally. The positive object has all 13
suites, all 16 safety IDs, and the exact ordered ten-row
`graph_freeze_cases` array plus its Task-2-matching canonical SHA-256; the
negative removes only
`BASRoutedMemoryFlipTests` and expects `missing-freeze-suite`; the mutation
keeps that indexed path but replaces its exact filter with
`__QINAO_W0_INTENTIONAL_ZERO_MATCH__` and expects `zero-match-filter`. The three canonical
digests must be distinct and match the signed catalog.

This is contract verification only. It does not call the active primitive,
create `GateResult`, or claim that `Pw` passed before
`pin_payload_and_issue_lease`.

- [ ] **Step 9: Prove no legacy open-set output was created**

Require the candidate tree and index to contain no path under
`docs/superpowers/evidence/qinao-w0-probe-logs/` and no W0 series receipt
other than the two literal imported sequence-zero compatibility fixtures:

```text
docs/superpowers/evidence/qinao-runtime-w0-baseline-violations.json
docs/superpowers/evidence/qinao-silicon-w0-baseline-correction-2026-07-18.json
```

Also require no staged/untracked receipt or log path and no direct
`check_w0_expected_open_set.py` invocation in ordinary CI. A sequence-1
receipt, renamed successor carrying either legacy `series_id`, or raw
transcript is a payload-purity failure, not evidence.

- [ ] **Step 10: Run pre-Pw purity and execution-root checks**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
set +e
W0_PREPW_MERGES="$(git rev-list --min-parents=2 "$PREW0_SW..HEAD")"
W0_PREPW_MERGES_RC="$?"
W0_PREPW_STATUS="$(git status --porcelain=v1)"
W0_PREPW_STATUS_RC="$?"
set -euo pipefail
test "$W0_PREPW_MERGES_RC" = 0
test "$W0_PREPW_STATUS_RC" = 0
test -z "$W0_PREPW_MERGES"
test -z "$W0_PREPW_STATUS"
git merge-base --is-ancestor "$PREW0_SW" HEAD
```

In the same authenticated controller-side harness that retained Step 1's
opaque `admitted_predecessor`, call:

```text
check_successor_payload_delta_purity(
    root = exact candidate root,
    candidate_commit = HEAD,
    candidate_tree = HEAD tree,
    admitted_predecessor = admitted_predecessor,
)
```

This is the Authority-owned generic parity checker, not a Bootstrap
primitive, and it accepts no caller wave or predecessor OID. Expected: every
preW0 Cw/Sw evidence blob inherited from the authenticated predecessor is
byte-identical; the predecessor→W0 delta contains no W0 result claiming its
own payload, no legacy successor/log output, no raw K4 class, no W0 Cw/Sw
receipt, no Artifact Mesh/W1 path, and no unclassified source path. The clean
`HEAD` is the only W0 `Pw` candidate; there is no intervening evidence commit.

---

### Task 12: Freeze Immutable W0 `Pw`, `PwTree`, and Build Identity Before K4

**Files:**
- Create no candidate file, Git object, or Git ref.
- Create only in Bootstrap-owned external storage: one fresh
  `PayloadDispatchAuthorizationV1`, an immutable content-addressed payload pin,
  signed proposal receipt, and signed `EvaluationLease`.

**Interfaces:**
- Consumes: clean candidate `HEAD` OID and the already reopened opaque
  `AdmittedWaveV1` predecessor plus one externally signed, short-lived
  `PayloadDispatchAuthorizationV1`.
- Produces: one opaque signed `EvaluationLease` whose service-owned payload
  object and tree were independently reopened.
- No source/index/worktree mutation is legal after this point.

- [ ] **Step 1: Re-run root and predecessor identity**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
python3 scripts/build_qinao_bootstrap_lineage.py \
  --verify-applied-lineage \
  /private/tmp/qinao-bootstrap-ceremony-v1/prew0-lineage-plan-v1.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
```

Then call
`ProtectedAdmissionClient.reopen_admitted_predecessor()` and require the
service-envelope-verified wave/payload/tree/seal/attestation tuple to equal the
originally reopened preW0 tuple. Expected: exact admitted predecessor; no stale
or competing protected state.

- [ ] **Step 2: Freeze the candidate payload only as clean `HEAD` OID/tree**

```bash
set -euo pipefail
W0_PW="$(git rev-parse HEAD)"
W0_PW_TREE="$(git rev-parse "$W0_PW^{tree}")"
set +e
W0_FREEZE_STATUS="$(git status --porcelain=v1)"
W0_FREEZE_STATUS_RC="$?"
set -euo pipefail
test "$W0_FREEZE_STATUS_RC" = 0
test -z "$W0_FREEZE_STATUS"
git cat-file -e "$W0_PW^{commit}"
git cat-file -e "$W0_PW_TREE^{tree}"
git merge-base --is-ancestor "$PREW0_SW" "$W0_PW"
```

Expected: both objects reopen locally, the candidate is clean, and no
candidate-local ref is created. From this point, every re-entry derives
`W0_PW/W0_PW_TREE` from unchanged clean `HEAD` and byte-compares them to the
signed lease.

- [ ] **Step 3: Obtain fresh payload-dispatch authorization, then ask Bootstrap to pin/reopen**

Through Bootstrap's external append-only control plane, obtain and
service-reopen one fresh `PayloadDispatchAuthorizationV1` that binds the exact
repository, authenticated `PREW0_SW` chain digest, `W0_PW/W0_PW_TREE`,
proposal-object-set digest and immutable proposal ref, one create-once dispatch
intent/run ref, active B0 verifier-bundle digest, authorized operator
principal/role, issue/expiry instants, nonce, and signature. It authorizes only
the target-host payload-object import/reopen, immutable proposal pin, and that
one evaluation dispatch. Candidate JSON, environment, CLI values, an earlier
authorization, or process memory cannot supply it.

Only after the protected adapter authenticates that fresh record, call:

```text
proposal_receipt, lease =
  ProtectedAdmissionClient.pin_payload_and_issue_lease(W0_PW)
```

The Bootstrap verification adapter authenticates both envelopes and requires
`proposal_receipt.payload_commit_oid == lease.payload_commit_oid == W0_PW`,
the receipt/lease tree equals `W0_PW_TREE`, and the receipt's immutable
service-owned ref plus host-reopen observation validate before reading any
lease projection. It also requires the receipt, lease, proposal object-set,
dispatch intent, run ref, and active-verifier digest to equal the authenticated
`PayloadDispatchAuthorizationV1`; the authorization record itself is never
passed as a fifth client argument.

`W0_PW` is the sole candidate-supplied admission value. The service:

```text
authenticates the caller and freshly reopens PayloadDispatchAuthorizationV1
derives W0 and the predecessor from finalized canonical state
imports/reopens and pins the exact authorized commit in Bootstrap-owned
  content-addressed storage at the bound immutable proposal ref
reopens commit bytes, tree bytes, sole ancestry, and every referenced object
creates or reopens the one authorized dispatch intent/run ref
derives payload tree, authority/catalog/Owner-Ledger bindings, and gate set
issues a signed lease only after host-side reopen succeeds
```

The candidate never supplies payload tree, predecessor, wave, ref, dispatch
intent, gate list, profile, build identity, ExternalPhysicalGate binding, or
object-host identity. Missing/expired/replayed authorization, absent object,
incomplete transfer, wrong commit/tree/parent, failed host reopen, or ambiguous
external state terminates without a proposal receipt or lease as
`AdmissionTerminalError(
terminal = BLOCKED_PAYLOAD_OBJECT_AVAILABILITY,
reason_code = PAYLOAD_OBJECT_NOT_HOST_REOPENED
)`. It is not a K4 blocker and cannot fall back to local objects or mint a
replacement authorization.

- [ ] **Step 4: Verify the opaque lease's read-only projections**

Without decoding or reconstructing any opaque type, use the Bootstrap
verification adapter to require the signed lease projects:

```text
derived wave = W0
predecessor seal = PREW0_SW
payload commit = W0_PW
payload tree = W0_PW_TREE
required gate set = the exact first 13 B0 catalog rows
exactly one selected W0 ReleaseProfileBinding
exactly one ExternalPhysicalGateBinding reference
source import-review audit root =
  compile_review_audit_root((
    verify_fixed_c1_import_review_export(),
    verify_fixed_c2_import_review_export(),
    verify_fixed_c3_import_review_export(),
))
```

The functional audit-root expression is executed only by the external
service-owned opaque import-review verifier before it signs the lease. W0 and
B0 compare the resulting signed digest to the predecessor/Output-B binding;
they do not import the candidate preparation script or reopen raw records.

The external physical binding, its producer/attester/custody/broker identities,
and their schema remain Bootstrap-owned and opaque. A missing selected release
or physical-gate binding is `BLOCKED_K4`; a missing payload pin/reopen remains
`BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`. Never read environment authority or
define a W0 copy of either binding. The audit-root equality is evaluated only
through Bootstrap's opaque verified-review objects and read-only compiler;
W0 never parses review records into a second wire or derives the root from map
fields. The same C1+C2+C3 digest must byte-match the authenticated gate-result
bundle, W0 Sw receipt, intent, finalized attestation, and returned
`AdmittedWaveV1`.

- [ ] **Step 5: Prove immutability**

```bash
set -euo pipefail
test "$(git rev-parse HEAD)" = "$W0_PW"
test "$(git rev-parse "HEAD^{tree}")" = "$W0_PW_TREE"
set +e
W0_IMMUTABLE_STATUS="$(git status --porcelain=v1)"
W0_IMMUTABLE_STATUS_RC="$?"
set -euo pipefail
test "$W0_IMMUTABLE_STATUS_RC" = 0
test -z "$W0_IMMUTABLE_STATUS"
```

From this line onward, every K4 entry repeats the exact root guard and these
three assertions, then verifies the same values through the opaque lease. No
candidate commit/ref/object write occurs after freeze. Bootstrap alone may
construct `Cw`/`Sw` in non-host quarantine and, only after the separately
authorized boundary, import them to the target Git host while resuming the
same final generic operation.

---

### Task 13: Run the Real K4 Ceremony or Stop at Exact `BLOCKED_K4`

**Files:**
- Read immutable `W0 Pw`.
- Write raw material only through Bootstrap's encrypted ephemeral run volume
  and external encrypted custody; write nothing to candidate storage.
- Produce one signed privacy-clean projection in Bootstrap custody.

**Interfaces:**
- Consumes: opaque `EvaluationLease`, including its
  `ExternalPhysicalGateBinding` reference.
- Produces: one opaque `AuthenticatedGateResultBundle`, or the authenticated
  exact blocker `BLOCKED_K4`.

- [ ] **Step 1: Run the immutable-entry guards**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
test "$(git rev-parse HEAD)" = "$W0_PW"
test "$(git rev-parse "HEAD^{tree}")" = "$W0_PW_TREE"
set +e
K4_ENTRY_STATUS="$(git status --porcelain=v1)"
K4_ENTRY_STATUS_RC="$?"
set -euo pipefail
test "$K4_ENTRY_STATUS_RC" = 0
test -z "$K4_ENTRY_STATUS"
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
```

Then call `ProtectedAdmissionClient.reopen_admitted_predecessor()` and verify
the predecessor plus `W0_PW/W0_PW_TREE` through the lease's authenticated
read-only projections. The candidate does not decode the lease or receive a
physical-gate request.

- [ ] **Step 2: Invoke the active B0 DAG exactly once**

Call only:

```text
authenticatedGateResults =
    ProtectedAdmissionClient.run_active_gates(lease)
```

The Bootstrap controller derives the literal 13-gate W0 DAG and executes each
active B0 module over the service-pinned payload. For
`qinao.k4-platform-proof`, the controller-side `ExternalPhysicalGate` broker:

```text
reopens the lease's opaque ExternalPhysicalGateBinding
builds and signs the physical-gate request from lease/payload/profile facts
allocates one separately attested producer principal/process
allocates one distinct separately attested attester principal/process
gives only the producer a write-scoped encrypted-custody capability
gives only the attester a fresh short-lived read-only reopen capability
accepts only the attester's signed privacy-clean projection
passes that projection and external-root commitment to the B0 primitive
```

The candidate scripts in Task 10 are not imported, spawned, or granted any
lease/custody/device/service capability in this active path. A candidate
executable, result string, JSON file, projection, or signature can neither
start nor satisfy the gate.

- [ ] **Step 3: Enforce encrypted ephemeral raw storage and crash cleanup**

Before any archive/device effect, the broker creates a unique per-run encrypted
ephemeral volume with a fresh out-of-process key, private mount namespace,
directory mode `0700`, regular-file mode `0600`, no swap/snapshot/backup/index
eligibility, and no path beneath the candidate, repository, user Documents, or
shared temporary directory. Raw archive, profiles, signing material, device
identifier, challenge, logs, container copies, and trace bytes exist only on
that mounted volume or in external encrypted custody.

The producer streams the exact 34-role bundle no-replace to external encrypted
custody and closes its write grant. The distinct attester obtains a fresh
short-lived read-only grant, reopens every role, recomputes the root and every
archive/device/challenge/reply relation, and signs the privacy-clean
projection. Only after this independent reopen succeeds, the broker must:

```text
close every raw handle and terminate the producer/attester sandboxes
destroy the local ephemeral-volume key through its owning key service
unmount and destroy the encrypted ephemeral volume
stable-open the parent storage and prove no run path, mount, key handle,
snapshot, swap entry, index entry, or cleanup journal remains
record a signed cleanup terminal bound to run ID and external bundle root
```

External custody retains its independently encrypted bundle only for the
lease-bound retention period; destroying the local run key does not destroy
that retained evidence. A later authorized external destruction receipt
invalidates K4 certification and enters the next invalidation/admission cycle.

Before effects, the broker durably registers a privacy-clean cleanup intent in
its external recovery store. After a crash/restart, a separate cleanup worker
reopens the intent, revokes all grants, destroys the local key/volume, performs
the same no-residue proof, and closes the intent. Unknown key/volume/grant or
cleanup state is fail-closed: the evaluation becomes `BLOCKED_K4`, or
`quarantinedAdmission` when authenticated lineage disagrees, and cannot yield
a gate result or call final assembly.

- [ ] **Step 4A: If blocked, stop cleanly**

Require the authenticated service terminal `BLOCKED_K4` and one private typed
reason from the closed set:

```text
RELEASE_PROFILE_BINDING_UNAVAILABLE
RELEASE_XCODE27_UNAVAILABLE
ENHANCED_SECURITY_HOST_PROFILE_UNAVAILABLE
ENHANCED_SECURITY_HELPER_PROFILE_UNAVAILABLE
PRODUCT_SIGNING_IDENTITY_UNAVAILABLE
PHYSICAL_IOS27_DEVICE_UNAVAILABLE
EXTERNAL_ENCRYPTED_CUSTODY_UNAVAILABLE
INDEPENDENT_ATTESTER_UNAVAILABLE
SHORT_LIVED_REOPEN_UNAVAILABLE
RETENTION_DESTRUCTION_POLICY_UNAVAILABLE
EPHEMERAL_ENCRYPTED_STORAGE_UNAVAILABLE
RAW_CLEANUP_UNVERIFIED
```

Then assert:

```bash
set -euo pipefail
test ! -e docs/superpowers/evidence/qinao-k4-platform-proof-W0.json
test "$(git rev-parse refs/heads/qinao-admitted)" = "$PREW0_SW"
set +e
K4_BLOCKED_STATUS="$(git status --porcelain=v1)"
K4_BLOCKED_STATUS_RC="$?"
set -euo pipefail
test "$K4_BLOCKED_STATUS_RC" = 0
test -z "$K4_BLOCKED_STATUS"
```

Require the service evaluation state to contain no authenticated gate-result
bundle, assembly record, object-import receipt, admission intent, CAS, or final
attestation. Bootstrap tests prove `assemble_import_and_finalize` is not called
after this terminal. Expected: no Cw/Sw/admission and canonical ref unchanged.

- [ ] **Step 4B: If passed, require the signed external proof**

The controller-side attester must have independently proved:

```text
all 34 roles reopened
recomputed root equals custody root
payload = exact W0 Pw/PwTree
archive and device bound before challenge
challenge fresh/in-window
release Xcode 27/profile/team exact
physical iOS 27 exact
direct and async replies exact
zero pending/unexpected
uninstall/reinstall/reopen exact
retention active
no destruction receipt
local ephemeral key destroyed
local encrypted run volume absent
signed no-residue cleanup terminal valid
```

The B0 `physical_evidence_external_root` primitive receives the signed
privacy-clean projection and external-root commitment directly from the
broker, independently reopens custody through the lease-bound service, and
returns its result only inside `authenticatedGateResults`. The K4 result binds
`W0_PW/W0_PW_TREE`, the active B0 contract/module/corpus, nonzero
positive/negative/mutation counts, the external bundle root, independent
reopen receipt, cleanup terminal, and `result = passed`.

- [ ] **Step 5: Preserve or idempotently resume the one evaluation**

Do not create a second evaluation or lease, serialize/rebuild the bundle, or
extract leaves from it. Keep the opaque `authenticatedGateResults` value in the
authenticated client session for Task 14. After a session interruption, first
execute the restart sequence frozen in the upstream-interface section:

```text
admittedPreW0 =
  ProtectedAdmissionClient.reopen_admitted_predecessor()
proposal_receipt, lease =
  ProtectedAdmissionClient.pin_payload_and_issue_lease(W0_PW)
authenticatedGateResults =
  ProtectedAdmissionClient.run_active_gates(lease)
```

The root/clean-tree checks freshly prove the same `W0_PW/W0_PW_TREE`; the
service proves the returned receipt/lease belong to the existing
preW0→W0-Pw evaluation. `run_active_gates` is then an idempotent query/resume:
if the evaluation terminal already exists, Bootstrap returns the byte-identical
`AuthenticatedGateResultBundle` and performs zero new physical effects.
Unknown or nonterminal effect state remains blocked until Bootstrap's recovery
oracle resolves it; it is never rerun from memory or replaced by a candidate
cache.

---

### Task 14: Have Bootstrap Assemble in Quarantine, Authorize Import, and Admit W0

**Files:**
- Construct only in the Bootstrap service's non-host quarantine, then import
  to the target Git host only after fresh protected-ref authorization: Cw with
  the two named W0 projections, 13 literal active gate-result files, and exact
  self-excluding manifest; Sw with only
  `docs/superpowers/evidence/qinao-wave-admission/W0.json`.

**Interfaces:**
- Consumes: opaque `EvaluationLease` and the exact opaque
  `AuthenticatedGateResultBundle` returned once in Task 13.
- Consumes only through Bootstrap's append-only control plane after exact
  non-host object derivation: one fresh
  `ProtectedRefAdvanceAuthorizationV1`; it is not a fifth client argument.
- Produces: one opaque service-envelope-verified `AdmittedWaveV1`.
- Candidate output: no leaf, manifest, Cw/Sw tree or commit, receipt, commit
  identity, object pack, admission intent, CAS input, or attestation.

- [ ] **Step 1: Run immutable-entry and predecessor guards**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
test "$(git rev-parse HEAD)" = "$W0_PW"
test "$(git rev-parse "HEAD^{tree}")" = "$W0_PW_TREE"
set +e
W0_ADMISSION_ENTRY_STATUS="$(git status --porcelain=v1)"
W0_ADMISSION_ENTRY_STATUS_RC="$?"
set -euo pipefail
test "$W0_ADMISSION_ENTRY_STATUS_RC" = 0
test -z "$W0_ADMISSION_ENTRY_STATUS"
```

Before asserting an expected-old protected ref, call
`ProtectedAdmissionClient.reopen_admitted_predecessor()` and execute this
closed recovery oracle:

1. if the authenticated current seal is exact `PREW0_SW`, execute Task 13
   Step 5's full re-entry sequence and use only its service-recovered original
   lease and byte-identical bundle; the service may then resume only the same
   assembly identity in its pre-authorization, authorized, import-pending, or
   finalization-pending state;
2. if the authenticated current result is already `derived_wave == W0`,
   `payload_commit_oid == W0_PW`, and its seal/CAS/finalized attestation all
   verify, treat the same operation as completed, bind `admittedW0` to that
   byte-identical reopen, and skip Steps 2-4; or
3. for every other seal, payload, chain, CAS, or attestation state, raise
   `AdmissionTerminalError(terminal = quarantinedAdmission,
   reason_code = IDENTITY_MISMATCH)` and perform no pin, gate, assembly, or ref
   write.

Only branch 1 may now require
`refs/heads/qinao-admitted == PREW0_SW`. This ordering makes a crash after CAS
and final attestation but before client return recoverable without mistaking
the successful W0 seal for a stale predecessor. Expected: exact immutable
payload plus either one service-resumed bundle with zero repeated effects or
the already-finalized byte-identical `admittedW0`.

- [ ] **Step 2: Require the authenticated result bundle to cover every output**

Execute this step only for recovery-oracle branch 1. Branch 2 has already
authenticated the finalized output and jumps to Step 5.

The service verification adapter, not W0 code, authenticates the bundle and
requires all 13 B0 W0 gate rows exactly once. The active B0
`qinao.production-reachability` result must derive the exact 12-row learning
projection from the signed release graph; the active K4 result must bind the
external root, independent reopen, privacy-clean projection, and no-residue
cleanup terminal. Every row binds exact `W0_PW/W0_PW_TREE`, lease, active
contract/module/corpus, nonzero discovery/execution/positive/negative/mutation
counts, evidence-output digests, and `passed`.

The service alone materializes
`docs/superpowers/evidence/qinao-learning-legacy-reachability-W0.json` and
`docs/superpowers/evidence/qinao-k4-platform-proof-W0.json` from authenticated
outputs. Candidate analyzers may have produced disposable parity bytes before
payload freeze, but cannot generate, compare into, supplement, or authorize a
current-run leaf.

Expected: exact 12 rows, every shipping disposition enforced, no direct promotion/export/write/distill/adopt mouth, and Qwen3.5 reported only as design target.

- [ ] **Step 3: Freeze the exact literal `100644` Cw allowlist**

Execute this step only for recovery-oracle branch 1.

The B0 output contract permits exactly these 16 stage-0 regular files; each
line is literal `path mode`, and no prefix, directory, wildcard, symlink,
submodule, executable bit, or inferred filename is legal:

```text
docs/superpowers/evidence/qinao-gate-results/W0/qinao.architecture-closure.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.ios27-floor.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.k4-platform-proof.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.owner-ledger.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.plan-remediation.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.production-reachability.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.provider-boundary.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.review-candidate.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.review-closure.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.samplehost-ios.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.v2-quarantine.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.w0-open-set.json 100644
docs/superpowers/evidence/qinao-gate-results/W0/qinao.xcode27-toolchain.json 100644
docs/superpowers/evidence/qinao-k4-platform-proof-W0.json 100644
docs/superpowers/evidence/qinao-learning-legacy-reachability-W0.json 100644
docs/superpowers/evidence/qinao-wave-admission/W0-cw-manifest.json 100644
```

The manifest is present in `Cw` but self-excluding: its canonical row set is
the other 15 paths and modes exactly. `qinao-k4-platform-proof-W0.json` is only
the schema-valid privacy-clean projection; it contains commitments, active
retention/destruction obligation, independent-reopen digest, and cleanup
terminal digest, never a raw private class.

- [ ] **Step 4: Resume one idempotent operation across the protected-ref authorization boundary**

Execute this step only for recovery-oracle branch 1.

The one logical operation is keyed by repository, lease, authenticated bundle
digest, assembly-contract digest, deterministic `W0 Cw/Sw` identities,
evidence-object-set digest, intended target-host import key, and immutable
admission-intent key. Repeating the method with the same opaque arguments is
query/resume of that identity, never a second assembly or admission.

Before a `ProtectedRefAdvanceAuthorizationV1` exists, call the existing method
once:

```text
ProtectedAdmissionClient.assemble_import_and_finalize(
    lease,
    authenticatedGateResults
)
```

This pre-authorization invocation may only:

```text
validates the exact 16-path/mode Cw allowlist and self-exclusion
derives every leaf without accepting caller bytes
constructs deterministic one-parent Cw over W0 Pw in non-host quarantine
constructs deterministic one-parent Sw adding only W0.json mode 100644
  in that same non-host quarantine
derives every author/committer/timestamp/parent/tree/blob/commit identity
derives the closed evidence-object-set digest, intended target-host import key,
  immutable admission-intent key, and exact Pw/Cw/Sw topology
obtains a fresh live AdmissionProtectionProjectionV1
persists the one assembly identity and exposes its exact external
  protected-ref-advance authorization request
performs no target-host object import/reopen, import receipt, admission intent,
  protected-ref CAS, or final attestation
```

If no matching authorization is already service-reopened, this invocation
raises exactly
`AdmissionTerminalError(
terminal = BLOCKED_EXTERNAL_BOOTSTRAP,
reason_code = CEREMONY_UNAVAILABLE
)`; it never returns a partial `AdmittedWaveV1`. Through Bootstrap's external
append-only control plane, obtain one fresh
`ProtectedRefAdvanceAuthorizationV1` only after the non-host object closure is
complete. The service authenticates that it binds the exact repository,
canonical protected ref, wave, expected `PREW0_SW`, `W0_PW`, derived W0 Cw/Sw,
proposal-receipt digest, lease ID, authenticated-bundle digest,
evidence-object-set digest, intended target-host import key, admission-intent
key, fresh live protection-projection digest, authorized operator
principal/role, issue/expiry instants, nonce, and signature.

The authorization is not a client argument, environment value, candidate file,
or new `ProtectedAdmissionClient` method. Missing, expired, replayed,
substituted, wrong-old/new-OID, wrong-object-set, or protection-drifted bytes
remain `BLOCKED_EXTERNAL_BOOTSTRAP/CEREMONY_UNAVAILABLE` before any target-host
effect.

After that exact authorization is persisted and freshly reopened, invoke the
same method with the same opaque values:

```text
admittedW0 = ProtectedAdmissionClient.assemble_import_and_finalize(
    lease,
    authenticatedGateResults
)
```

This normally second invocation reopens the existing non-host Cw/Sw bytes and
assembly identity; it does not construct a second object or authorization
request. Only now may the service:

```text
imports the authorization-bound complete object set into the target Git host
reopens every imported object and exact Pw/Cw/Sw topology at that host
creates and persists the one signed object-import receipt
creates the one immutable admission intent bound by the authorization
performs one non-force expected-PREW0_SW protected-ref CAS
finalizes the same intent as an external signed admission attestation
returns only the opaque finalized AdmittedWaveV1
```

On re-entry, an already-valid matching authorization allows the first
post-restart call to resume this second phase directly; it is still the same
logical operation. The caller cannot pass a leaf, allowlist, mode, Cw/Sw OID,
commit identity, object set, authorization, receipt, old/new ref OID, intent,
or attestation field. Any missing/extra leaf, raw class,
object-import/reopen mismatch, stale lease, CAS loss, unknown host state,
changed external root, invalid cleanup terminal, or missing final attestation
follows Bootstrap's pending/reconcile/quarantine recovery oracle. The client
never decomposes the operation, creates a new lease, substitutes a new bundle,
or exposes more than its four frozen methods.

- [ ] **Step 5: Verify the opaque finalized result and immutable candidate**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py --root /Users/changgeng/.codex/worktrees/e4d7/Project06 --expect-candidate-lineage reparentedProgram --require-clean
test "$(git rev-parse HEAD)" = "$W0_PW"
test "$(git rev-parse "HEAD^{tree}")" = "$W0_PW_TREE"
set +e
W0_ADMISSION_FINAL_STATUS="$(git status --porcelain=v1)"
W0_ADMISSION_FINAL_STATUS_RC="$?"
set -euo pipefail
test "$W0_ADMISSION_FINAL_STATUS_RC" = 0
test -z "$W0_ADMISSION_FINAL_STATUS"
```

Using only the Bootstrap verification adapter over `admittedW0`, require:

```text
derived_wave = W0
payload commit/tree = W0_PW/W0_PW_TREE
Cw sole parent = W0_PW
Cw diff = exact 16-path/mode allowlist
Sw sole parent = Cw
Sw diff = docs/superpowers/evidence/qinao-wave-admission/W0.json mode 100644
receipt binds predecessor, payload, Cw, 13 gates, and K4 external root
object-import receipt binds ProtectedRefAdvanceAuthorizationV1,
  evidence-object-set digest, target-host import key, and admission-intent key
canonical ref = returned Sw projection
finalized external attestation binds returned Sw and receipt blob
active verifier/modules remain B0 versions
next-chain digest is computed outside Pw/Cw/Sw
```

Expected: exact `preW0 Sw … W0 Pw → W0 Cw → W0 Sw`, finalized external
admission, and unchanged candidate payload/worktree. None of the projected
identities is fed back into an assembly or finalization call.

- [ ] **Step 6: Fast-forward the implementation branch to authenticated W0 `Sw`**

Only after Step 5 has authenticated `admittedW0`, capture the canonical ref
once and require the Bootstrap verification adapter to prove
`admittedW0.seal_commit_oid` equals that exact value. Then run:

```bash
set -euo pipefail
W0_SW="$(git rev-parse refs/heads/qinao-admitted)"
CURRENT="$(git rev-parse HEAD)"
if test "$CURRENT" = "$W0_PW"; then
  git merge --ff-only "$W0_SW"
elif test "$CURRENT" = "$W0_SW"; then
  true
else
  echo "unexpected post-W0 implementation head: $CURRENT" >&2
  exit 2
fi
test "$(git rev-parse HEAD)" = "$W0_SW"
set +e
W0_SW_PARENT_LINE="$(git rev-list --parents -n 1 HEAD)"
W0_SW_PARENT_LINE_RC="$?"
W0_FAST_FORWARD_STATUS="$(git status --porcelain=v1)"
W0_FAST_FORWARD_STATUS_RC="$?"
set -euo pipefail
test "$W0_SW_PARENT_LINE_RC" = 0
test "$W0_FAST_FORWARD_STATUS_RC" = 0
test "$(
  printf '%s\n' "$W0_SW_PARENT_LINE" |
    awk 'NF == 2 { print 2; found = 1 } END { if (!found) print 0 }'
)" = 2
test -z "$W0_FAST_FORWARD_STATUS"
```

Immediately call
`ProtectedAdmissionClient.reopen_admitted_predecessor()` again and require
the same service-envelope-verified `derived_wave == W0`,
`seal_commit_oid == W0_SW`, finalized-attestation digest, and admission-chain
digest. A changed protected ref, different seal, merge commit, dirty tree, or
non-fast-forward stops before Artifact Phase A. This advances only the
implementation branch; it performs no protected-ref write and does not rerun
assembly/finalization.

---

## Final Verification Matrix

| Property | Required proof |
|---|---|
| Execution root | Every W0/K4 entry used exact `reparentedProgram` CLI; canonical four-key JSON; mismatch exit 2 |
| Admitted predecessor | Fixed original ref, one suffix-equals-target prep ref, B0→preW0 Pw tree equality, preW0 receipt, protected ref, external attestation all equal |
| Import | Nonzero operator-reviewed C3 rows; stable source; destination CAS; exact staged set; no raw K4 log/profile/device byte |
| Current API | W0 tests compile with no future Provider/spool/App-Agent/K3/K4/W5/W6 API |
| Safety freeze | Exact 16 hazards; nonempty source/production roots/predicates/suites; comments/strings safe; unknown path fails |
| Legacy learning | Exact 12 §4.12 rows; direct and transitive mouths fenced; actual result only in Cw |
| Causal learning | Exact 14-stage order; full negative set; holdout lineage; E0-E4→canary→field/E5→separate adoption |
| K3 invalidation | One expected-parent CAS; exactly runtime-boundary/projection/learning/exposure fanout; late results inert |
| Main/Sub | Independent capsules; typed immutable artifacts; per-field negatives; correlation cannot fake consensus |
| Swift gates | All 13 suites, including `BASRoutedMemoryFlipTests`, discovered and executed; zero-match impossible |
| Open set | B0-self-contained exact 13-suite/16-safety-ID program is reopened from signed B0; all suites are nonempty/green; no successor receipt or raw log exists |
| iOS | Bash floor gate passes; actual SampleHost iOS scheme passes; no macOS substitute |
| Pw boundary | W0 source/schema/checker/test/fixture/probe/build inputs committed; clean HEAD OID/tree frozen; one fresh `PayloadDispatchAuthorizationV1` binds the exact proposal object set/ref and create-once dispatch before Bootstrap pins and independently reopens the payload; no candidate payload ref |
| K4 authority | Bootstrap controller-side `ExternalPhysicalGate` derives release Xcode/team/profile/device/custody/producer/attester from the opaque lease binding; no candidate executable/env/caller authority |
| K4 sequence | Actual archive inspected and physical iOS 27 device bound before fresh challenge |
| Device execution | Structured `devicectl` JSON for install/launch/process/copy/uninstall/reinstall/reopen |
| XPC | Exact direct and async replies; challenge/correlation/route/responder/delivery; timeout/cancel; zero pending/unexpected |
| Raw evidence | 34 exact roles originate in an encrypted ephemeral run volume and enter external encrypted no-replace custody; no raw Git/candidate bytes |
| Independent reopen | Separate principal/process; fresh short-lived grant; every byte/root recomputed |
| Destruction | Independent reopen precedes local run-key/volume destruction and signed no-residue proof; crash cleanup is recoverable; external live bundle retained; later external destruction invalidates proof |
| Checker hardening | Legacy marker/log/source/plist/status/caller-team/challenge/ExecutionGate fiction rejected |
| Privacy projection | Closed fields and coverage; raw path/device/team/profile/CDHash/challenge/log/trace absent |
| Admission | `BLOCKED_K4` means no Cw/Sw; pass uses one idempotent `assemble_import_and_finalize(lease, gate_results)` identity whose pre-authorization invocation constructs exact Cw/Sw only in non-host quarantine, whose fresh `ProtectedRefAdvanceAuthorizationV1` is obtained through Bootstrap's control plane, and whose same-key post-authorization invocation alone imports/reopens at the target Git host, receipts, intents, CASes, and finalizes; the four-method client surface and candidate no-leaf/no-commit/no-ref rule remain unchanged; only afterward the implementation branch fast-forwards from W0 Pw to authenticated W0 Sw |
| Scope | No Artifact Mesh W1, no W1-W6 implementation, no second owner/verifier/scheduler/compiler |

## Self-Review Before Execution

- [ ] Compare every file in this responsibility map with the actual candidate path and package target; a nonexistent target/path is a plan defect, not an expected RED.
- [ ] Search this plan for unfinished prose markers, concrete function bodies containing ellipsis, or an undefined interface; none is permitted. Tuple variadics are Python typing syntax, not omitted implementation instructions.
- [ ] Verify every exact test suite with `swift test list` before using its filter.
- [ ] Verify every Python module is invoked with `python3 -m unittest`, never direct-file-only or `pytest`.
- [ ] Verify every K4 production input is signed/derived, every runtime private selector remains internal, and every public projection string passes the leak classifier.
- [ ] Verify `ReleaseProfileBinding`, `ExternalPhysicalGateBinding`, `EvaluationLease`, `AuthenticatedGateResultBundle`, and `AdmittedWaveV1` remain opaque Bootstrap imports and no local mirror/redeclaration exists.
- [ ] Verify `PayloadDispatchAuthorizationV1` precedes proposal pin/dispatch and
  `ProtectedRefAdvanceAuthorizationV1` follows exact non-host Cw/Sw derivation
  but precedes every target-host import/receipt/intent/CAS effect; both remain
  signed external-service records rather than client arguments or candidate
  schemas.
- [ ] Verify the protected root guard implements `reparentedProgram` exactly; an old audited-tip-ancestor-only guard blocks legal reparenting and must be repaired upstream first.
- [ ] Verify clean `HEAD` OID/tree is frozen and the Bootstrap-owned payload pin is authorized/reopened before the first K4 archive/device command; no candidate payload ref or ref-writing command exists.
- [ ] Verify missing payload authorization/object/pin/reopen yields `BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`; a missing physical prerequisite yields `BLOCKED_K4`; neither path creates W0 Cw/Sw/admission.
- [ ] Verify `ProtectedAdmissionClient` exposes only the four frozen methods, active K4 is controller-side `ExternalPhysicalGate`, and candidate K4 scripts are parity/preflight only.
- [ ] Verify the Cw allowlist contains exactly 16 literal `100644` paths, including exactly 13 B0 W0 gate IDs, with a self-excluding manifest and no wildcard/directory row.
- [ ] Verify the CoreAI convergence plan is never consumed as authority or evidence; only re-derived mechanisms appear here.
- [ ] Verify all result-producing commands run after `Pw`, and only the bootstrap protected child can put privacy-clean results into `Cw`.

## Scope Boundary

This plan ends at admitted W0. It does not implement Artifact Mesh W1 Task 0, LayerCells, StateLake lanes, full App-Agent roots/sessions, future `executeAtMostOnce`, production semantic DAG/executor, K3/K4 owners, W5 Enhanced Security adapter, W6 certification/cutover, model conversion, throughput claims, or 40/30 performance closure. Those remain in their owner/wave plans and may consume W0 only after the final protected admission above.
