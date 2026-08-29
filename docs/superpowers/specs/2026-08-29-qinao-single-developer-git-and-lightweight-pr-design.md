# Qinao single-developer Git and lightweight PR design

Date: 2026-08-29

Status: amended for the selected trusted-single-owner route; pending user
review before replacement implementation planning

## Outcome

Qinao returns to an ordinary single-developer Git workflow. Plain, unsigned
Git commits, trees, branches, merge commits, and pull requests are the complete
development-control mechanism. The user is the sole product and development
decision-maker. The repository does not add a source-admission signer, trust
root, authority controller, custom compare-and-swap broker, governance
database, quorum, or authority receipt family.

The workflow is lightweight, not lax. Every production change still receives
the testing, automated review, risk classification, failure handling, rollback
thinking, and durable Git history appropriate to its effects. No pull request
auto-merges. Routine work pauses for one concise final user approval after its
objective evidence is complete. High-risk work pauses for a fuller, freshly
bound approval after its additional risks and irreversible effects are
disclosed.

For all future development, this decision supersedes every prior requirement
for a development-control mechanism beyond ordinary Git and pull requests.
That includes source-admission and controlled-document gates, external
signers/trust roots, authority controllers/custom CAS brokers, governance
registries/quorums, and authority receipt families. It does not rewrite
historical commits, delete forensic evidence, or retroactively turn
non-authoritative A0.1-A0.3 observations into authority.

## Context and explicit simplification

The previous design assumed an independently operated V1 authority family:
external verifier, signer scope, durable controller claim, protected-ref CAS,
private source epoch, and isolated helper. Bounded repository and known-custody
searches did not bind the required authority inputs. They did not claim global
nonexistence. The user has now selected a forward development model that does
not use that authority family. The project has one developer and does not need
organizational admission governance.

Continuing to design a substitute external authority would create machinery
without a real principal, duplicate ordinary Git ownership, and risk a
self-approving control loop. That architecture is retired rather than
simulated.

The following distinctions remain important:

- Git is the development source of truth.
- `origin` is the ordinary remote Git copy and collaboration surface.
- iCloud/CloudKit is an application-data and user-continuity surface, not a
  source-code authority.
- Encrypted snapshots are selective disaster-recovery custody, not authority.
- Tests and automated reviewers are evidence and gates, not owners.
- The user alone authorizes exceptional or irreversible work.

## Trust and enforcement boundary

This is deliberately a trusted-single-owner workflow, not a hostile-contributor
or multi-tenant admission system. The user is the sole repository owner and
developer; agents act only within the user's scoped instructions. Candidate
branches, repository workflows, and review automation are still treated as
fallible inputs, but the design does not claim an independent organization or
external authority that does not exist.

A read-only host audit on 2026-08-29 confirmed that the repository is private,
owned by an individual account, and has auto-merge disabled. Both the branch-
protection and repository-ruleset endpoints returned HTTP 403 stating that the
feature requires GitHub Pro or public visibility. Therefore this route does not
claim that GitHub mechanically enforces PR-only updates, required checks,
no-force-push, no-deletion, trusted workflow provenance, or final approval.
Those remain explicit operating invariants backed by scoped commands, remote
OID checks, complete-diff review, least-privilege workflow permissions, and the
user's manual merge decision.

GitHub Actions and same-repository status contexts are evidence, not an
independent trust root: candidate-controlled workflow or status output cannot
prove that a protected-base program produced it. Pull-request workflows receive
no repository secrets, declare top-level `permissions: {}`, and grant only
`contents: read` to jobs that actually require a checkout. A
`pull_request_target`-style metadata workflow, if retained, also declares
top-level `permissions: {}` and grants a metadata job only `contents: read` and
`pull-requests: read`; `id-token: write`, every repository/PR/check/action write
scope, environment credentials, and secrets are forbidden. It must never check
out `head.sha`, execute candidate code, or derive an Action/script revision,
path, or command from PR-controlled data. PR title, body, labels, branch names,
SHAs, and other event fields are parsed only as structured data by static
default-branch logic, never interpolated into a shell command. The workflow
cannot write repository/PR state or merge.

The same boundary applies across all triggers. Code, artifacts, caches,
metadata, or external callbacks originating from an unmerged PR may not flow
into any `workflow_run`, comment/issue/review event, dispatch, reusable
workflow, environment, or job that has secrets, write permission, deployment,
publication, or merge capability. Consuming PR artifacts or caches from a
higher-privilege workflow is forbidden by default. A future exception requires
a separate high-risk design with static trusted logic, no candidate execution,
no secrets, minimum read permission, and explicit user review.

Any later GitHub Pro upgrade and branch-protection configuration is optional
defense in depth and requires a separate reviewed, high-risk change; this
design and its acceptance criteria do not depend on it.

The automation audit has a finite, versioned discovery boundary and runs at
final head `H` and again immediately before approval:

- repository tree `H`: every file under `.github/workflows/**` and
  `.github/actions/**`, every reusable-workflow/local-Action call, each external
  Action reference, trigger, job dependency, permission, environment, secret
  name, artifact/cache producer and consumer, and merge/`main` write path;
- host state: repository Actions defaults and allowlists, auto-merge and merge
  settings, host-visible repository/user GitHub App installations and
  integrations, webhooks, environments/deployment rules, and names/metadata --
  never values -- of secrets or variables exposed to automation; and
- final PR state: every observed check/status/review producer, App identity,
  workflow event/path/ref/run identity, external reviewer, and any actor capable
  of changing or merging the PR.

The audit stores the discovery schema/version, frozen time, canonical redacted
responses or response digests, and a disposition for every item. `A` is the
SHA-256 digest of the RFC 8785-canonical inventory state, including schema and
version but excluding observation time; `E` includes `A`. A host endpoint whose
feature is explicitly reported unavailable on the current tier is recorded as
`unavailable-by-tier`; an endpoint that is merely unauthorized, ambiguous,
incomplete, or unavailable and could conceal write, secret, deployment,
publication, or merge capability is `unknown` and blocks approval. The trusted
owner's own interactive credentials are outside the automation inventory but
remain constrained by the manual-merge policy. No claim extends to actors the
host cannot expose; such an actor is unknown rather than assumed absent.

## Source-line convergence

The two preserved histories have one unique merge base:

- common ancestor: `243c083f345f3586ef226020d42af4653b31a62a`;
- protected 33-path preservation lineage:
  `4a9298db261bcfda97ea1748baad65649156ba66`;
- A0.1-A0.3/Deep Scan recovery-evidence lineage:
  `5c87355d5870b8559cadbe3105adbbb86f2008e7`.

The protected worktree's `29d953a... -> 4a9298d...` preservation snapshot adds
the exact 33 dirty/untracked paths. Across the complete lineage from merge base
`243c083...`, the `243c083... -> 4a9298d...` side changes 111 paths and the
`243c083... -> 5c87355...` side changes 39 paths. Their changed-path
intersection is empty. These are useful preconditions, not permission to skip
merge validation.

The protected authoring baseline is deterministic rather than count-only:

- worktree:
  `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-dual-space-controlled-convergence`;
- ref: `refs/heads/codex/qinao-dual-space-controlled-convergence`;
- protected HEAD: `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`;
- protected HEAD/index tree:
  `1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01`, with no staged delta; and
- preservation commit/tree:
  `4a9298db261bcfda97ea1748baad65649156ba66` /
  `22382c1de6680a263ec4a2f4a6c989c0f0e6e220`, whose sole parent is the protected
  HEAD.

The exact content manifest is the NUL-delimited, full-index, no-rename raw diff
from protected HEAD to the preservation commit; it contains 33 entries. For
each entry, the protected working-tree Git-visible type/mode and raw-byte digest
must equal the corresponding preservation-tree blob, while the protected index
remains the HEAD tree. Before and after implementation, read-only verification
uses `GIT_OPTIONAL_LOCKS=0`, freezes the human-readable status/path list plus
raw-manifest and content digests in PR evidence, and performs no index refresh.
Any HEAD, ref, index-tree, status, path, type/mode, or content mismatch stops.
No claim is made about filesystem metadata Git does not preserve, such as file
access times.

After this amended document is reviewed, it will be committed on
`codex/qinao-git-only-design-20260829`. The containing specification commit `S`,
its tree, and this file's blob cannot be embedded here without a self-reference
cycle. They are recorded immediately after commit. The same branch may then add
only the reviewed replacement implementation plan; immediately before
convergence, its final tip is frozen as `D`. The PR record binds full OIDs for
`S`, the `S` tree, the specification blob, `D`, and the `D` tree; proves that
`D` contains `S` and `5c87355...` as ancestors; and rejects any later tip or
blob substitution.

Implementation will create one isolated branch and worktree named
`codex/qinao-git-only-convergence` from the preservation commit, then merge that
exact committed design tip using a normal non-squash merge commit. This first
local convergence commit `C` preserves both parent histories and every frozen
commit identity. It does not cherry-pick, rebase, force-push, copy paths by
hand, or modify the protected dirty worktree. `C` has first parent exactly
`4a9298d...` and second parent exactly frozen `D`.

The deterministic plan/spec inventory is frozen against `C`. Only the
inventory-authorized supersession pointers and the reviewed implementation
tasks may then add ordinary commits above `C`; the resulting final PR head is
`H`, and `C` must remain its ancestor. With current `origin/main` frozen as
`B`, the exact final candidate tree is `T`. The host-created merge result is
`R`: for the convergence PR it uses `M=merge`, ordered parents `P=[B,H]`, and
tree `T`. Thus `C` proves the two source histories were joined with parents
`[4a,D]`, while `R` separately proves that final head `H` entered `main` through
the PR. Neither object is conflated with the other.

The original worktrees and refs remain recovery inputs until the convergence
PR is merged and validated from a fresh `origin` fetch/checkout. Deleting or
retiring them is a separate later decision.

## Ordinary development flow

After convergence, `main` is the one stable integration branch. Day-to-day
work follows this loop:

1. Fetch the current remote state. The local base OID must equal `origin/main`;
   a behind branch may fast-forward, while an ahead or diverged base stops.
2. Create a short-lived `codex/*` branch. Use an isolated worktree when work is
   parallel or when an existing dirty state needs protection; it is not a
   ceremony required for every small edit.
3. Write a failing test first for behavior changes, then implement the smallest
   coherent change that makes it pass.
4. Run focused tests throughout development.
5. Review the complete diff, preserve unrelated user changes, and create small
   coherent commits. Explicitly marked local/WIP commits are permitted on the
   development branch, but a failing required test always blocks merge.
6. Push the verified development branch to `origin`.
7. Open a pull request containing the outcome, risk class, changed surfaces,
   validation evidence, known limitations, and rollback method.
8. Run required CI and automated code review.
9. Present the final evidence under the routine or high-risk policy below and
   obtain the user's fresh approval before a manual merge.
10. Fetch the merged remote state and verify the host-reported merge commit,
    expected tree/topology, `merged_by`, absence of auto-merge, evidence binding,
    and clean verification checkout. Rerun tests when the exact merged tree was
    not already the candidate tested by the host or the hermetic local verifier.

No pull request may report success from a zero-test filter, an undiscovered
test target, skipped required validation, truncated failure output, or an
unverified background command.

## Pull-request and approval policy

Every change entering `main` uses a pull request, including code, tests,
documentation, CI, tools, dependencies, configuration, and policy. Direct
push, force-push, ref deletion, and administrator/automation bypass of `main`
are forbidden operating actions even though the current host tier cannot
mechanically prevent the owner from performing them. The PR is the lightweight,
durable review boundary; it is not a cryptographic ceremony. Auto-merge remains
disabled. In this document, “required” CI, review, metadata, or validation means
policy-required evidence that the agent and user verify before approval; it
does not imply an unavailable host-enforced required-status rule.

“Manual merge” means native auto-merge, merge queues, workflows, bots, and
unattended merge jobs remain disabled. The user either performs the host merge
action personally or explicitly directs an agent in the active task to issue
one immediate, deliberate merge command for the exact approved state. A PR
comment, checklist value, status, or prior approval never authorizes a later or
unattended merge by itself.

Before convergence, repository-host capabilities and current settings are
recorded read-only. Existing compatible safety settings are retained. This
route does not attempt to purchase a plan, make the repository public, or
mutate unavailable protection/ruleset endpoints. A later protection change,
including removal or weakening of an existing safety setting, is high-risk and
requires its own reviewed design evidence and user approval.

The host supplies ordinary PR diff, mergeability, check-run, and merge-candidate
information when available; local verification independently binds the
observed base OID, head OID, and candidate tree. A short structured PR checklist
records risk, limitations, finding dispositions, and rollback/forward-recovery
facts. One stateless `pr-metadata` check may validate the presence and closed-
set values of those fields on every relevant PR-body update. It stores no
approval state, does not judge code, cannot merge, and is not treated as host-
enforced authority. No database, controller, approval bot, or receipt system is
added.

Every candidate and its evidence use one identity tuple:

- `B`: exact base-branch OID observed before candidate construction;
- `H`: exact PR head OID;
- `T`: exact candidate tree OID constructed from `B` and `H`; and
- `V`: exact revision or digest of the validation matrix, risk classifier,
  metadata schema, and automated-review configuration used for the evidence.

Merge intent adds:

- `M`: the one approved host merge mode -- `squash` for every routine or high-
  risk PR except the initial convergence PR, which uses `merge`; rebase merge is
  outside this design; and
- `P`: the exact ordered parent-OID vector required of the host-created result
  (`[B]` for squash, `[B,H]` for the convergence PR merge commit).

`E` is the SHA-256 digest of a schema-versioned canonical UTF-8 JSON evidence
object using the complete RFC 8785 JSON Canonicalization Scheme (JCS). The
closed schema forbids floating-point values and limits integers to the exact
IEEE-754 safe range; strings remain their exact valid-Unicode values under JCS,
and arrays have schema-defined order. The object includes the PR number and
full-body digest; `B/H/T/V/M/P`; automation-inventory schema/version/digest `A`;
risk and limitations; the complete validation-matrix results; automated-review
identity, artifact digests, findings and dispositions; every other external
evidence URI/digest; rollback/forward-recovery; irreversible effects; and
draft/mergeability/auto-merge observations. Secrets and private data are never
included. `E` is not written into the PR body whose digest it covers; it is
recorded in the final summary and `approval-audit` entry, avoiding a self-
reference cycle. The audit-entry record digest likewise hashes the audit
payload with its own digest field omitted.

Before approval, the canonical JSON object itself -- not only `E` -- is stored
as a non-sensitive `final-evidence` record in the PR timeline. It includes its
schema version and computed `E`. If it exceeds one comment, it is split into
deterministically ordered chunks with a manifest containing total count and
per-chunk digests; the manifest/record digest excludes its own digest field.
Comment IDs and storage metadata are not inputs to `E`. All evidence needed to
decide risk, validation, findings, and recovery is present in this canonical
record; external URIs are supplemental and carry content digests. A missing
chunk, digest mismatch, unreadable required external object before post-merge
verification, or unknown schema makes the evidence `incomplete`. Sensitive or
large raw material remains outside PR text and is represented only by its
approved redacted metadata, URI, and digest.

Validation counts, check results, risk output, automated-review findings, and
their inputs are accepted only when they bind the same `(B,H,T,V)` tuple. The
final summary and merge intent additionally bind `M`, `P`, and `E`. A generic
green status or a result attached only to `H` is not sufficient evidence for
`T`.

### Routine PR

A routine PR may be presented for fresh user approval and then manually merged
when all of the following are true:

- the branch is pushed and an exact merge candidate has been constructed from
  the final head and base; when the host publishes its own candidate, the two
  candidate trees agree;
- a transparent, repository-versioned `risk-check` output classifies the exact
  diff as routine; known sensitive paths are high-risk, and unknown,
  unavailable, failed, or ambiguous classification is high-risk;
- every required CI check finishes successfully against that final candidate;
- a repository-versioned changed-surface validation matrix selects every
  required target/suite, and each target reports identity plus
  discovered/executed/passed/skipped counts; zero discovery, missing targets,
  unexpected skips, stale/neutral/cancelled/timed-out states, and unknown
  filters fail;
- the focused and change-appropriate validation suites pass;
- an automated review in a fresh context finishes against the exact final
  merge-candidate tree, bound to both head OID and base OID, with no confirmed
  actionable or disputed correctness, security, concurrency, data-loss, or
  architectural finding; any head, base, or candidate-tree change makes the
  review stale, and partial, unavailable, or stale review fails;
- `git diff --check`, build/compile, lint/static analysis, and repository
  invariants required by the changed surfaces pass;
- the PR checklist records the change, tests, risk, limitations, finding
  disposition, and rollback/forward-recovery/irreversibility class;
- no high-risk trigger below applies; and
- the host still considers the final candidate current and mergeable; and
- a concise final summary binds the PR number, base OID, head OID, candidate
  tree, evidence/configuration revision, merge mode/parent vector, canonical
  evidence digest `E`, risk result, completed validation, terminal review and
  finding disposition, limitations, and tested rollback or forward-recovery
  method.

The `risk-check` is a stateless diff check, not an authority. It may only keep a
PR routine or escalate it to high-risk; it cannot approve or merge anything.
Because the current host cannot guarantee protected-base workflow provenance,
the complete diff and evidence remain subject to fresh-context review and the
user's final decision. A PR that changes `risk-check`, `pr-metadata`, validation
discovery/matrix selection, the policy-required evidence set, or automated-
review configuration is always high-risk. Its proposed scripts may run only as
shadow evidence; the last reviewed base versions are also run against the exact
candidate where technically applicable, and the proposed scripts cannot
classify their own change as routine.

If the host cannot provide an up-to-date candidate that was tested exactly,
the candidate is reconstructed hermetically from the observed base and head,
its tree is compared with the host candidate when one exists, and the policy-
required checks are rerun before approval. Unknown or unequal candidates stop.

Routine approval is intentionally small: the concise final summary above and
one user `好` (or equivalent explicit approval) for that exact state. Any `B`,
`H`, `T`, `V`, `M`, `P`, `E`, diff, required evidence, review finding,
limitation, draft/mergeability state, or auto-merge setting change invalidates
it. Merge follows immediately in the active task for that exact state or a
fresh summary and approval are required.

After the user approves, one `approval-audit` entry is written to the PR
timeline before merge. It records that user decision, risk class,
`B/H/T/V/M/P/E`; high-risk entries also record the complete finding
disposition, limitations, blast radius, irreversible effects, recovery method,
and whether a separate effect authorization is absent or present. This is audit
evidence only: no script, status check, workflow, bot, or resumed task may treat
it as permission to merge. Immediately after recording it, the active merger
re-reads the PR state, `origin/main`, `B/H/T`, `V/M/P/E`, mergeability, and
auto-merge setting, reruns the host-side automation discovery, and requires its
state digest to remain exactly `A`. Any mismatch, high-privilege automation
drift, or interruption expires the active user direction and requires fresh
evidence and approval. Only the user or the agent acting on that still-active,
immediately preceding direction performs the one deliberate merge command or
UI action, which must explicitly select bound merge mode `M`. A confirmed no-
effect or indeterminate result also requires a new final summary and approval
before another attempt.

Every non-convergence PR, routine or high-risk, uses only squash merge so `main`
remains readable. The initial two-lineage convergence PR is the explicit
exception and uses only a merge commit to preserve both histories. Changing the
selected mode or expected parent vector invalidates `E` and approval.

### High-risk PR

A high-risk PR requires every applicable build, test, invariant, checklist, and
final-candidate check above, while the risk status remains high-risk. Automated
review must be terminal and enumerate
the complete finding set; confirmed actionable findings must be fixed, while a
documented false-positive/applicability dispute follows the user-disposition
rule below. The PR additionally requires one fresh, explicit user approval
after the final diff and evidence are available. High-risk triggers are:

- persistent schema or data migration;
- deletion, erasure, retention, backup, or recovery semantics;
- CloudKit, iCloud, Keychain, encryption, privacy, entitlement, permission, or
  credential handling;
- external effects, automation actuation, publication, release, signing, or
  production cutover;
- security boundaries, sandboxing, process isolation, or authorization logic;
- changes to active architecture, the Git/PR policy, required CI, validation
  matrices, risk classification, automated-review configuration, branch
  protection, any `.github/workflows/**` or local/reusable Action, event
  trigger, permission, environment/secret boundary, or artifact/cache policy;
- destructive Git/history/worktree operations;
- Deep Scan execution or any other expensive, proprietary, non-replayable
  external operation; or
- an ambiguity that could reasonably enter one of the categories above.

High-risk approval remains concise but carries more information than routine
approval: one final summary and one user `好` (or equivalent explicit approval).
The summary binds the PR; `B/H/T/V/M/P/E`; risk; checks; complete finding
disposition; limitations; blast radius; rollback/forward-recovery; irreversible
effects; and any separate effect authorization still required. Any bound fact
or effect fact change invalidates that approval. Merge follows immediately in
the active task for that exact state or fresh approval is required. The PR
timeline/checklist is the only durable workflow record; no approval database,
machine-consumable receipt, or reusable token is created. Approval never waives
failing tests, confirmed actionable findings, remote drift, an unknown effect
outcome, or a separately required launch/publication authorization.

This design does not authorize Deep Scan 3. No prior approval, general
development permission, PR approval, automation setting, or successful test
run authorizes it. The following list is the complete forward DS3 preflight
and replaces the old D0-D2 operational workflow gates; D0-D2 remain historical
evidence and are not implicitly inherited. Their factual observations remain
evidence, but a condition gates a future DS3 launch only when restated here:

- re-read the supported callable schema and current documented capabilities;
  private or reverse-engineered surfaces never become permission;
- close/revalidate R0-R3 against current source and freeze a clean, pushed
  target commit/tree with all required validation passing;
- freeze and disclose the exact target, scope, launch mode, monitoring and
  recovery limitations, expected cost, duration bound, and data egress;
- check for another running scan through the supported surface when available
  and stop for the user's explicit decision rather than silently overlap;
- define the supported official completion evidence and where results will be
  durably preserved; a local mirror or report cannot substitute for official
  completed state and canonical artifacts; and
- obtain one fresh, explicit user authorization for exactly one initial launch
  call bound to all facts above.

The approval is consumed on that call. Changed parameters, a replacement run,
a failed-run restart, or an alias/wrapper invocation requires new approval. A
same-ID query/rejoin may only observe or reattach to an already existing run
through a supported idempotent surface and must never create a new scan or a
concurrent second waiter. Terminal failure never authorizes automatic restart.

`DS3-authorized-once` and `high-risk-approved-for-merge` are different states
with different human confirmations and different durable records. Merge
approval is recorded in the PR timeline; DS3 authorization is recorded in its
separate launch-preflight evidence. The DS3 record must explicitly say “one
initial launch” and bind the target, scope, mode, cost, duration, egress, and
supported launch idempotency identifier when one exists. PR approval/merge/
reopen, scan query/rejoin, and a failed launch do not create, reuse, or replenish
that state. Only the immediately adjacent supported initial-launch call may
consume it.

## Review and validation depth

Lightweight ceremony must not reduce engineering depth. Validation is selected
by affected behavior, not by PR size alone.

The minimum evidence set is:

- focused tests for the changed behavior;
- regression tests for the nearest owner and integration boundary;
- build or compile checks for every affected target;
- static checks and repository invariants already owned by the project;
- explicit negative and interruption tests for recovery, persistence,
  concurrency, or effect changes;
- a full suite before merging architectural, cross-cutting, or release changes;
- a reviewed diff with generated/vendor/noise paths separated from authored
  behavior; and
- a fresh post-merge verification of the remote-backed commit, tree, and final
  check state. Tests are rerun post-merge only if the exact merge result was not
  already the tested candidate.

The changed-surface validation matrix is versioned and closed-set. Each selected
unit records its surface class, stable target identifier, validation kind,
command, applicability reason, and result counters. Test targets report
discovered/executed/passed/failed/skipped; static/document targets report
enumerated/checked/failed inputs. Every selected unit must be nonempty. A
documentation-only PR may use deterministic Markdown, link, reference, schema,
or policy consistency checks with nonzero checked-file counts rather than
pretending those are unit tests. Policy, workflow, validation, or test-
infrastructure changes are high-risk and also run the last reviewed policy/
invariant test suite. Unknown surfaces or unrecognized validation kinds stop
and escalate; they never become a zero-test exemption.

Automated review may be performed by Codex, CodeRabbit, or a later equivalent
that can produce a terminal full-diff review for an exact merge-candidate tree
and its head/base pair. The tool is replaceable. Findings are evaluated on
evidence and severity; the review tool never becomes an authority or
substitutes for executable tests.

The PR checklist records the automated-review producer and version or execution
method, start/end time, complete-diff scope, `(B,H,T,V)`, terminal state, a
durable artifact link or redacted digest, the complete finding list, and each
finding's disposition. Missing, partial, stale, or unbound review evidence is
`incomplete`. Changing the producer or review configuration is high-risk but
does not turn that tool into a permanent authority.

Confirmed actionable findings are fixed and cleared by a fresh review of the
corrected merge candidate before merge; user approval cannot waive them. A
tool false positive or a genuine applicability/severity dispute is documented
with the specific code and evidence, makes the PR high-risk, and is presented
to the user for final disposition. Once the user accepts that evidenced
disposition for the exact final state, it is recorded as resolved rather than
left as an unresolved finding. High-risk automated review must still terminate
and list the complete finding set; it need not pretend the review tool itself
agreed with the user's evidenced disposition. Suppressing a finding merely to
obtain green status is not accepted.

## Failure and recovery behavior

- A failing or missing required test stops merge progression. An explicitly
  marked WIP commit may exist only on the development branch and cannot satisfy
  a PR gate.
- Before a branch push, record the observed remote-old OID and expected-new
  OID and push only the immutable expected OID to the named non-`main` ref. On
  an unknown result, require a successful, unique exact-ref query: expected
  means Git-ref success, old means only that the Git ref did not advance, while
  any other value or an unavailable/ambiguous query remains `indeterminate` and
  stops. LFS or another pre-push side effect is inventoried separately; old-ref
  equality does not prove that no object was uploaded, and retry is forbidden
  until every such effect is confirmed absent, safely idempotent, or explicitly
  accepted and recorded.
- PR creation uses a deterministic intent digest over repository, base, head
  branch, `H`, and the exact body/evidence digest. After an unknown result,
  query open and closed PRs by exact base/head and confirm success only when
  exactly one PR matches `H` and the intent digest. An authoritative zero match
  confirms no effect and permits one retry; multiple, conflicting, or
  unavailable results remain `indeterminate` and stop. PR-body update recovery
  similarly compares the observed old body digest and intended new digest for
  the exact PR number: intended is success, old is no effect, anything else is
  `indeterminate`.
- Every `final-evidence` chunk/manifest and `approval-audit` timeline entry
  contains a deterministic record digest. After an unknown comment result,
  query the complete PR timeline/comments and accept success only when exactly
  one entry matches that digest. An authoritative zero match permits reposting
  only while `B/H/T/V/M/P/E`, PR state, and -- for approval audit -- the user's
  active decision remain fresh; multiple, conflicting, unavailable, or
  interrupted results expire any active direction and stop.
- Before merge, retain the PR number, `B/H/T/V/M/P/E`, and the
  `approval-audit` entry, and verify that `M` remains available, the PR remains
  mergeable, and auto-merge remains disabled. After an unknown merge result,
  success requires the PR to report `merged`, identify host result `R`, and
  fresh `origin/main` to have
  tree `T`, exact ordered parent vector `P`, and merge mode `M`, while the audit
  entry preserves the matching pre-merge `E`. No effect is confirmed only when
  the PR remains open, `origin/main == B`, and the host reports no merge in
  progress. Every other or unavailable state is `indeterminate` and forbids
  retry. A confirmed no-effect still requires fresh approval before a second
  merge attempt.
- Normal target advancement invalidates the candidate, evidence summary, and
  approval. The candidate and all affected evidence are refreshed; conflict,
  mismatch, failed/invalidated evidence, or unknown state stops progression.
- Force-push/direct-push to `main`, destructive reset, history/ref deletion,
  bypass, and automatic conflict choice are forbidden in the ordinary
  workflow.
- Unrelated dirty or untracked user files are preserved and excluded.
- A partial tool/CI/review result is `incomplete`, never inferred successful.
- A failed post-merge verification creates a repair or revert PR; it does not
  silently edit the remote branch. The repair/revert is classified by its own
  real effects and is not automatically routine.
- Post-merge evidence records the merged PR, host-reported merge commit,
  result `R`, `merged_by`, `B/H/T/V/M/P/E`, final `origin/main`
  OID/tree/topology, current auto-merge setting, and the matching
  `approval-audit` entry. A missing or mismatched field is a failed
  verification, not presumed success.
- A PR distinguishes tested rollback, forward recovery, and explicitly
  irreversible effects. Git revert is never described as undoing data loss,
  an external publication, or another completed external effect. Irreversible
  work records backup/restore evidence where applicable, containment,
  cutover/abort conditions, and blast radius before fresh approval.
- Secrets, private application data, and large runtime evidence are not added
  to Git, PR text/comments, CI logs/artifacts, automated-review input, or remote
  fixtures merely to make recovery convenient. Only minimized, redacted test
  material may cross those surfaces.

## Upload and remote policy

For source code, “upload” means an ordinary `git push` to `origin` followed by
a PR. There is no parallel iCloud source-code workflow and no direct filesystem
sync of an active Git worktree.

Verified development milestones may be pushed automatically after the remote-
old OID is recorded and the push result is verified. Every PR remains open
until the fresh user approval is recorded for the exact final state; no PR
auto-merges. Repository-host capabilities and settings are audited read-only
against this design. Compatible stronger safety settings remain, and any later
mutation of them follows the high-risk policy. Automation must not weaken
compatible host protection or imply unavailable enforcement.

## Encrypted-snapshot policy

Encrypted snapshots are optional recovery insurance for important state that
Git does not cover. They are not required for ordinary committed/pushed source
work and are not a PR or development authority.

A snapshot is considered only when at least one of these holds:

- an important state is intentionally uncommitted or Git-ignored;
- a destructive or difficult-to-reverse migration is about to run;
- a proprietary/non-replayable operation such as a Deep Scan is authorized;
- a local database or schema is about to undergo an irreversible transition;
  or
- external evidence cannot safely or practically enter Git.

Snapshot creation or upload is a separately disclosed high-risk action; a Deep
Scan or migration approval does not imply snapshot approval. Its final summary
records an exact inclusion/exclusion inventory, destination, authenticated
encryption, digest, retention/deletion policy, recovery-secret failure domain,
and decrypt/restore verification. Secrets and private application data are
excluded unless the user explicitly approves their named inclusion. If an
irreversible operation relies on a snapshot for recovery, the verified
snapshot becomes a precondition for that operation instead of being called
optional.

Completed DS1 encrypted custody and any separately observed external A0.3
custody remain preserved. The repository-internal A0.3 precommit review itself
made no completed-encryption claim, so implementation must not use it as that
proof. No snapshot is deleted or upgraded to authority by this design. A
snapshot whose recovery secret exists only on the same device is not claimed
as an independent device-loss backup.

## Application-data boundary

Application-data/iCloud behavior is outside this Git/PR design. A later design
will decide local-first persistence, CloudKit/iCloud synchronization, the
user-requested minimum three-day durability for temporary conversations, and
rebuilding derived embeddings/reranker indexes. None is claimed implemented or
validated here. CloudKit is not source-code authority, and the convergence PR
does not implement application-data persistence.

That later design must remain honest that live process memory, unsent hidden
reasoning, arbitrary PTYs/sockets, and device-bound Secure Enclave private keys
cannot be described as ordinary restorable App data.

## Historical evidence disposition

A0.1-A0.3 scripts, JSON, reviews, commits, snapshots, and receipts remain exact
historical recovery evidence. This document becomes the single forward policy.
At local convergence commit `C`, implementation deterministically enumerates every
tracked Markdown file under `docs/superpowers/plans` and
`docs/superpowers/specs`, and records one versioned inventory entry per path:
path, source blob OID, disposition (`supersede`, `historical-only`, or
`unrelated`), review reason, permitted transformation, and expected final blob
OID. Keyword searches for admission, authority, controlled documents, signer,
trust root, controller, CAS, receipt, registry, and quorum are completeness aids,
not substitutes for that all-file inventory. Only the exact pointer
transformation for a `supersede` entry may change a plan/spec blob above `C`;
`historical-only` and `unrelated` blobs remain unchanged. The final inventory at
`H` records and verifies every resulting blob. Both inventory path lists and
digests are frozen in PR evidence; an unclassified path, an unlisted
transformation, or any later plan/spec change stops convergence.

Each inventory entry classified `supersede` receives only one short, prominent
pointer to this superseding document; the new policy is not copied into
multiple files. The pointer states:

- external authority closure was never completed;
- no historical authority is retroactively claimed;
- the single developer selected ordinary Git as the development-control model;
- all source-admission, controlled-document, signer/trust-root,
  controller/CAS, authority-receipt, registry, and quorum gates beyond ordinary
  Git/PR are retired for forward development; and
- factual evidence and hashes remain unchanged; a historical non-authority
  limitation remains a forward gate only when this design explicitly restates
  it.

Historical evidence files are not bulk-rewritten to match the new policy.

## Non-goals

This design does not:

- create a multi-developer governance or release organization;
- add commit/tag signing, a quorum, a signer, or a trust root;
- claim bit-identical restoration of live processes or hidden model state;
- use iCloud as the source-code authority;
- make snapshots globally or routinely mandatory; a separately approved,
  verified snapshot is mandatory only for the specific irreversible operation
  whose recovery plan depends on it, and never becomes development authority;
- auto-resolve conflicts, force-push, or delete recovery refs/worktrees;
- waive tests or findings for small PRs; or
- authorize Deep Scan 3.

## Acceptance criteria

The design is correctly implemented when:

1. PR evidence freezes full OIDs for specification commit/tree/blob `S` and
   final design tip/tree `D`, proves `D` contains `S` and `5c87355...`, freezes
   local convergence commit `C` with parents exactly `[4a9298d...,D]`, and
   proves final PR head `H` descends from `C`;
2. the protected ref/worktree still matches the frozen HEAD/index/snapshot
   identities and exact 33-entry raw/status/content manifest, while every prior
   evidence commit remains addressable;
3. the all-plan/spec inventory maps every source path/blob at `C` to its exact
   final path/blob at `H`, and every `supersede` entry has exactly the prescribed
   pointer without asserting global nonexistence or rewriting historical claims;
4. the versioned validation matrix's focused/full test and static/document
   units pass on the final merged tree with exact target identities and nonzero
   discovered or checked inputs;
5. the PR records complete automated-review evidence bound to `(B,H,T,V)` and
   persists the canonical evidence object plus digest `E`, then host result `R`
   uses exactly approved merge mode `M`, parent vector `P`, and tree `T`;
6. the exact-state user approval is durably recorded before one merge attempt,
   but the audit entry is never machine-consumed as permission; every merge is
   manual, post-merge evidence records `merged_by` and disabled auto-merge, and
   no approval controller or unavailable host enforcement is claimed;
7. unknown push, PR-create/update, approval-record, and merge outcomes pass the
   operation-specific recovery rules above without duplicate PRs, duplicate
   approvals, unclassified LFS effects, or repeated merges;
8. the versioned automation inventory covers every repository/host/PR source
   in the finite discovery boundary above, records trigger, permission,
   secret/environment, artifact/cache, and merge/`main`-write capability, and
   contains no unresolved high-privilege `unknown`, unmerged-PR input crossing
   into a privileged job, or automated merge path; its digest `A` is included
   in `E` and remains unchanged at the post-approval pre-merge reread;
9. no custom authority service, signer, receipt family, or source-control
   database is introduced;
10. snapshots remain optional custody globally; a separately approved,
   verified snapshot is a mandatory precondition only for a specific
   irreversible operation whose recovery plan depends on it, and never becomes
   development authority;
11. application-data/iCloud work remains separately scoped; and
12. `DS3-authorized-once` remains absent, Deep Scan 3 remains not started, and
    no PR approval is interpreted as a scan-launch authorization.
