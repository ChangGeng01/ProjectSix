# Qinao single-developer Git and lightweight PR design

Date: 2026-08-29

Status: written design; pending user review before implementation planning

## Outcome

Qinao returns to an ordinary single-developer Git workflow. Plain, unsigned
Git commits, trees, branches, merge commits, and pull requests are the complete
development-control mechanism. The user is the sole product and development
decision-maker. The repository does not add a source-admission signer, trust
root, authority controller, custom compare-and-swap broker, governance
database, quorum, or authority receipt family.

The workflow is lightweight, not lax. Every production change still receives
the testing, automated review, risk classification, failure handling, rollback
thinking, and durable Git history appropriate to its effects. Routine work may
merge automatically after objective checks pass. High-risk work pauses for one
fresh, explicit user approval.

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

After this document is reviewed, it will be committed on
`codex/qinao-git-only-design-20260829`. That containing design-tip commit cannot
be embedded in this file without a self-reference cycle; the PR and merge
record will bind its exact commit/tree and require `5c87355...` as its ancestor.

Implementation will create one isolated branch and worktree named
`codex/qinao-git-only-convergence` from the preservation commit, then merge that
exact committed design tip using a normal non-squash merge commit. This first
convergence merge preserves both parent histories and every frozen commit
identity. It does not cherry-pick, rebase, force-push, copy paths by hand, or
modify the protected dirty worktree.

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
9. Merge only under the routine or high-risk policy below.
10. Fetch the merged remote state and verify the expected commit, tree, final
    check state, and clean repository status. Rerun tests only when the final
    merge candidate was not already tested by the host.

No pull request may report success from a zero-test filter, an undiscovered
test target, skipped required validation, truncated failure output, or an
unverified background command.

## Pull-request and approval policy

Every change entering `main` uses a pull request, including code, tests,
documentation, CI, tools, dependencies, configuration, and policy. Direct
push, force-push, ref deletion, and administrator/automation bypass of `main`
are forbidden. The PR is the lightweight, durable review boundary; it is not
a cryptographic ceremony.

Before convergence, the repository-host rules are audited. Ordinary
protections such as PR-only updates, required CI, and no force-push/deletion
are retained. Rules that require the retired authority, an unavailable second
reviewer/signature, stale status checks, or a merge method that prevents the
initial two-parent convergence are removed only through a high-risk,
user-approved change.

The host mechanically enforces PR-only updates, mergeability, required status
checks, exact head/base freshness, and native auto-merge/merge-queue behavior.
A short structured PR checklist records risk, limitations, finding
dispositions, and rollback/forward-recovery facts. One stateless required
`pr-metadata` check validates the presence and closed-set values of those
fields on every relevant PR-body update and again for the final merge
candidate. It stores no approval state and does not judge code. No database,
controller, approval bot, or receipt system is added.

### Routine PR

A routine PR may auto-merge when all of the following are true:

- the branch is pushed and the host has built an exact merge candidate from
  the final head and base;
- a transparent, repository-versioned `risk-check` status classifies the exact
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
- the host still considers the final candidate current and mergeable.

The `risk-check` is a stateless diff check, not an authority. It may only keep
a PR routine or escalate it to high-risk; it cannot approve or merge anything.
Every eligibility-defining gate -- `risk-check`, `pr-metadata`, validation-
target discovery/matrix selection, required-check policy, and automated-review
configuration/scope -- executes from the protected base branch's last trusted
version or an equivalent host-owned fixed rule, while the code under test is
the exact final merge candidate. A PR that changes any such gate is classified
high-risk by the old trusted version; its proposed gate may run only as non-
gating shadow evidence until that PR is approved and merged. It cannot evaluate
itself into routine status. If the host cannot preserve this trusted-base
boundary, routine auto-merge is disabled for that PR.

If the host cannot provide an up-to-date/merge-queue equivalent that retests
the final candidate, routine auto-merge is disabled and the refreshed checks
must be reviewed before manual merge.

Routine PRs use squash merge by default so `main` remains readable. The
initial two-lineage convergence PR is the explicit exception and uses a merge
commit to preserve both histories.

### High-risk PR

A high-risk PR requires every applicable build, test, invariant, checklist, and
final-candidate check above, while the risk status remains high-risk and
auto-merge remains disabled. Automated review must be terminal and enumerate
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
  matrices, risk classification, automated-review configuration, or branch
  protection;
- destructive Git/history/worktree operations;
- Deep Scan execution or any other expensive, proprietary, non-replayable
  external operation; or
- an ambiguity that could reasonably enter one of the categories above.

Approval is deliberately small: a concise final summary and one user `好` (or
equivalent explicit approval). The summary binds the PR, final head OID/tree,
base OID, risk, checks, findings, and irreversible effects. Any diff, head,
base, merge candidate, required check, or finding change invalidates that
approval. Merge follows immediately for that exact state or fresh approval is
required. The PR timeline/checklist is the only durable workflow record; no
approval database or reusable token is created. Approval never waives failing
tests, confirmed actionable findings, remote drift, or an unknown effect
outcome.

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

Automated review may be performed by Codex, CodeRabbit, or a later equivalent
that can produce a terminal full-diff review for an exact merge-candidate tree
and its head/base pair. The tool is replaceable. Findings are evaluated on
evidence and severity; the review tool never becomes an authority or
substitutes for executable tests.

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
- Before a push or remote mutation, record the observed remote-old OID and
  expected-new OID. On an unknown result, query the exact ref/state: expected
  means success, old means confirmed no effect and permits a safe retry, while
  any other value or an unavailable query remains unknown and stops. The same
  rule applies to unknown PR and merge mutations.
- Normal target advancement causes the host to recompute the merge candidate
  and rerun stale checks. Only a conflict, failed/invalidated check, or unknown
  state stops auto-merge.
- Force-push/direct-push to `main`, destructive reset, history/ref deletion,
  bypass, and automatic conflict choice are forbidden in the ordinary
  workflow.
- Unrelated dirty or untracked user files are preserved and excluded.
- A partial tool/CI/review result is `incomplete`, never inferred successful.
- A failed post-merge verification creates a repair or revert PR; it does not
  silently edit the remote branch. The repair/revert is classified by its own
  real effects and is not automatically routine.
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

Verified development milestones may be pushed automatically. Routine PRs may
auto-merge only under the closed policy above. High-risk PRs remain open until
the fresh user approval is recorded for the exact final state. Repository-host
rules are audited against this design: compatible stronger safety rules remain,
while stale authority/signature/reviewer checks and incompatible merge-method
rules are removed only through the high-risk policy. Automation must not
weaken compatible host protection.

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
During implementation, each previously active design/plan that could be read as
a forward authority gate receives only one short, prominent pointer to this
superseding document; the new policy is not copied into multiple files. The
pointer states:

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

1. one new convergence branch normally merges `4a9298d...` with the exact
   committed design tip whose ancestry includes `5c87355...`, preserving both
   parent histories;
2. the protected dirty worktree and every prior evidence commit remain
   byte-identical and addressable;
3. supersession pointers retire the uncompleted external-authority requirement
   from the forward development gate without asserting global nonexistence or
   rewriting historical claims;
4. the validation matrix's focused and full targets pass on the final merged
   tree with exact target identity and nonzero discovered/executed tests;
5. the convergence PR records complete evidence and uses a history-preserving
   merge commit;
6. host checks and the PR checklist keep routine auto-merge distinct from
   high-risk fresh user approval without adding an approval controller;
7. no custom authority service, signer, receipt family, or source-control
   database is introduced;
8. snapshots remain optional custody globally; a separately approved,
   verified snapshot is a mandatory precondition only for a specific
   irreversible operation whose recovery plan depends on it, and never becomes
   development authority;
9. application-data/iCloud work remains separately scoped; and
10. Deep Scan 3 remains not started and not authorized.
