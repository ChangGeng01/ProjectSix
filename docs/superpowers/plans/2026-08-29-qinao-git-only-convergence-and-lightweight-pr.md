# Qinao Git-Only Convergence and Lightweight PR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge the two preserved Qinao histories without touching the protected dirty worktree, retire the former admission/controller path from active development, and establish a trusted-single-owner Git plus lightweight manual-PR workflow whose complete evidence is reproducible and interruption-safe.

**Architecture:** A normal local merge creates source-line convergence commit `C` with parents exactly `[4a9298d…, D]`; ordinary TDD commits above `C` create final PR head `H`. Four small Python modules separately audit Git/document state, define the PR/evidence protocol, execute typed validation, and validate the finite automation inventory. GitHub Actions remains candidate-controlled read-only evidence, while one fresh user decision immediately precedes one native manual merge; no status, comment, bot, controller, or receipt is an authorization mechanism.

**Tech Stack:** Git 2.53+, Git LFS, Python 3.9 standard library, SwiftPM/XCTest, Xcode/`xcresulttool`, Cargo, GitHub CLI/API, GitHub Actions with pinned action commits, RFC 8785 JSON Canonicalization Scheme, SHA-256.

**Spec:** [`docs/superpowers/specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md`](../specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md)

## Global Constraints

- This plan implements the trusted-single-owner route. CI, metadata checks, reviews, comments, digests, and receipts are evidence only; none is protected-base provenance or merge permission.
- The repository remains private on its current personal tier. Do not purchase a plan, publish the repository, transfer ownership, mutate branch protection/rulesets, or claim unavailable host enforcement.
- Planning-time local evidence says the active `gh` credential is invalid, and ordinary Git push permission for workflow-file changes has not yet been authoritatively proved. Tasks 1–7 and 9–10 perform no network read. Task 8 may make only its separately sealed, public, credential-free, checksum-pinned crates.io archive GETs when the local archive census is incomplete; that narrow dependency import cannot read GitHub or establish Git/GitHub authority. Task 11 must stop before the first Git/GitHub/LFS network read until the user restores authentication and both the independent `gh` and Git-transport credential generations satisfy the exact read/write table. This is an external execution precondition, not a reason to weaken or bypass the plan.
- The planning-time Cargo census found 115 registry packages, with checksum-correct local archives for 113 and exact missing inputs `curve25519-dalek-derive 0.1.1 / f46882e17999c6cc590af592290432be3bce0428cb0d5f8b6715e4dc7b383eb3` and `fiat-crypto 0.2.9 / 28dea519a9695b9977216879a3ebfddf92f1c08c05d984f8996aecd6ecdc811d`. Task 8 recomputes rather than trusts this observation, but the execution plan therefore includes the explicit bounded archive-acquisition frontier instead of assuming a warm Cargo cache.
- Normal personal `gh` credentials cannot authoritatively enumerate every GitHub App installation or OAuth/PAT grant: the documented user-installations REST family requires a GitHub App user access token. This plan never asks for or creates that second credential. It inventories every API-visible hook/check/deployment/workflow/collaborator/deploy-key producer, records the installation/grant visibility gap as an explicit high-risk host limitation in `A/E`, and makes no claim that the host is a complete trust root. A newly visible or unclassified producer still blocks; the fresh owner decision in Task 14 is the only path past the disclosed visibility limitation.
- The available normal-owner APIs provide complete bounded point-in-time observations for the enumerated surfaces, not an organization/audit-log-grade continuous history of every transient host mutation. Persist `transientHostMutationVisibility="unavailable-no-audit-log"` in `A/E`, bind all raw/safe observation evidence outside semantic `A`, and require the user to accept this disclosed trusted-single-owner limitation at Task 14. If the threat model requires proof against a malicious concurrent actor or an unobserved create-delete interval, this ordinary solo workflow blocks; repeated point-in-time reads must not be marketed as that stronger guarantee.
- Every change entering `main` uses one PR. Direct-to-`main` push, unconditional or non-fast-forward force-push, ref deletion, `--admin`, auto-merge, merge queue, rebase merge, bots, and unattended merge jobs are forbidden operating actions. The private candidate branch uses one exact old-value `--force-with-lease` solely as compare-and-swap around an independently proved fast-forward/creation.
- The initial convergence PR uses `M="merge"` and `P=[B,H]`. Later routine/high-risk PRs use `M="squash"` and `P=[B]`.
- No `pull_request_target`, `workflow_run`, status-writing workflow, PR-writing workflow, secret-bearing job, deployment environment, artifact/cache handoff into a higher-privilege job, custom controller, signer/trust root, CAS broker, quorum, or approval token is introduced.
- GitHub Pages or another branch-native publication is not part of this authorization. Repository `has_pages` and the Pages endpoint must prove disabled, and the complete deployments collection must expose no unreviewed publication producer; otherwise this route blocks before push/merge for a separate user decision.
- Before this one convergence merge, each legacy workflow path is observed independently at `B`: absent means no old source generation; equality with its exact reviewed `C` legacy blob creates a closed, high-risk `base-retiring` generation; any third blob blocks. Workflow identity is `(path, sourceBlobOid|null)`, never numeric ID/path alone. Before H exists remotely, an active record with no `B` source is stale/unknown and blocks; after H is pushed, `test.yml@reviewedNewBlob` is a distinct required candidate generation and is allowed only when every selected run's `head_sha:path` reopens to that blob. Any actual old generation is never silently treated as absent: its features, reused workflow ID, variables/runners it could reach, and complete run state enter `A`; no dispatch is authorized; any nonterminal or newly created old-blob run blocks. `H` must still replace/delete the legacy `C` paths, and Task 15 must prove the old-generation transition closed while retaining the new read-only generation.
- Stateless candidate-controlled `pr-metadata` and `risk-check` checks validate body shape and exact-diff risk evidence. They cannot merge, mutate the PR, store approval, downgrade high/unknown risk, or be described as independent trust.
- `S`, `D`, `C`, `B`, `H`, `T`, `V`, `A`, `E`, `M`, `P`, and `R` are distinct typed identities. Never reuse a commit OID where a tree OID or digest is required.
- Complete diffs use NUL-delimited `--raw --full-index --no-abbrev --no-renames` records. A path-only list is never sufficient for risk, review, LFS, or recovery decisions.
- The protected authoring worktree is read only. Use `GIT_OPTIONAL_LOCKS=0`; do not refresh its index, stage, stash, commit, checkout, clean, reset, switch, merge, rebase, or invoke a command that may run its hooks.
- The source convergence worktree is new, isolated, and durable at its exact recovery path. Use `GIT_LFS_SKIP_SMUDGE=1`, an empty `core.hooksPath`, no signing, and no verification hooks while constructing `C`; inventory LFS separately before any real push.
- Python production code and tests run through `qinao_python`; the frozen local interpreter is `/usr/bin/python3` 3.9.6, while each candidate-controlled CI job binds and reports its own compatible `/usr/bin/python3` projection rather than pretending it is the local binary. Neither profile may require third-party packages. JSON parsing rejects duplicate keys, floats, out-of-range integers, invalid Unicode, unknown fields, and noncanonical bytes.
- Every selected validation target is nonempty. Tests report discovered/executed/passed/failed/skipped counts; static/document targets report enumerated/checked/failed counts. Missing, cancelled, skipped-required, truncated, stale, or partial evidence is `incomplete`.
- Existing intentional XCTest/Cargo skips are not converted into blanket failure or blanket acceptance. Focused required tests allow no skips; full-suite skips require exact test identities and reviewed reasons.
- The current iOS 18 manifests and failing historical iOS 27 floor are an explicit separate product-migration limitation, not a convergence success criterion and not something this plan hides or edits.
- `final-evidence` stores the reconstructable canonical object and `E` in the PR timeline. `approval-audit` records a human decision but is never consumed as authorization.
- Unknown outcomes are operation-specific. Do not replay a push, PR creation, body update, comment, or merge until authoritative observation classifies the first attempt.
- Equality of a remote Git ref with its old OID does not prove that a lost receive-pack transaction cannot later become visible. Git push runs with hooks and submodule recursion disabled, and this plan performs no LFS upload.
- Encrypted snapshots are not required for this ordinary Git workflow. Application-data/iCloud persistence and Deep Scan 3 are outside scope.
- `DS3-authorized-once` remains absent. Do not launch, rejoin, restart, alias, wrap, wait for, or schedule Deep Scan 3.
- No original worktree, live convergence worktree, branch, recovery/audit ref, LFS object, or evidence record is deleted by this plan; the sole exception is targeted removal of a **missing** linked-worktree registration after a sealed clean-boundary proof, solely to recreate the same branch/path under Task 2's closed recovery table.

---

## Mandatory sterile execution root

No Task 1–15 fence is evaluated by an inherited interactive shell. The exact fence bytes are supplied without caller-side interpolation to this outer process boundary:

```bash
/usr/bin/env -i \
  HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin \
  /bin/bash --noprofile --norc -s -- qinao-plan-step
```

The payload begins `set -euo pipefail`, `umask 077`, rejects unexpected positional arguments, and performs discovery only through absolute executables or executables whose absolute path/version/content digest is already frozen by the current local preflight. Because `/usr/bin/env -i` runs before `/bin/bash`, `BASH_ENV`, `ENV`, `CDPATH`, `SHELLOPTS`, exported functions, aliases, traps, user `PATH`, proxy/token variables, and startup files cannot affect even the first pipeline. The fixed bootstrap set is `/bin/bash`, `/bin/chmod`, `/bin/mkdir`, `/bin/test`, `/usr/bin/env`, `/usr/bin/git`, `/usr/bin/awk`, `/usr/bin/sed`, `/usr/bin/head`, `/usr/bin/wc`, `/usr/bin/tr`, `/usr/bin/cut`, `/usr/bin/sort`, `/usr/bin/comm`, `/usr/bin/find`, `/usr/bin/stat`, `/usr/bin/shasum`, `/usr/bin/xargs`, `/usr/bin/dirname`, and `/usr/bin/mktemp`; Task 1 freezes their resolved regular-file target/stat/version-when-supported/content projection, and Task 3 persists/reopens it before admitting later execution. Code-fence and runtime tests fail if any pre-preflight command is dynamic, relative outside that fixed set, shell-resolved from caller state, or evaluated before this boundary.

The fenced commands below are task-specific payloads, not fragments pasted into an existing terminal. The versioned execution harness concatenates its exact sterile recovery prelude with the unchanged fence bytes, then supplies that complete script on standard input to the boundary above. The prelude derives only the variables explicitly named by that task from the frozen repository anchor, branch, immutable ledger, and sealed selectors; it never serializes or imports a caller variable/function. A static extractor checks each fence's declared inputs against that prelude, and an integration test launches every Task 1–15 fence separately from `env -i` with hostile caller state. The explicitly shown Task 11/15 cold starts remain self-contained reference implementations of the same recovery, including their own `qinao_python` definition.

GitHub Actions has no local convergence ledger, so it uses a distinct exact CI profile. The reviewed workflow sets every `run` shell to the literal custom template `/usr/bin/env -i HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin /bin/bash --noprofile --norc -e -o pipefail {0}`. Every `run` block then begins with the same literal CI prelude: `set -euo pipefail`, `umask 077`, server-generated `${{ github.workspace }}`, `${{ runner.temp }}`, and `${{ github.event_path }}` are assigned as non-exported shell data, validated as an absolute non-symlink workspace directory and event file beneath a closed hosted-runner root, and mode-0700 `home/tmp/run` directories are created without following symlinks. The root selects literal `/Users/runner` or `/home/runner`; it is derived from the validated workspace, not inherited. The prelude defines `qinao_python` locally with the launcher below plus `--profile ci` and that derived root; no inherited value crosses the inner `env -i`. The workflow-contract AST requires the full prelude byte-for-byte at the start of every `run` block, rejects `shell: bash`, raw Python, inherited `BASH_ENV`, or a shortened alias, and binds the prelude and workflow blob into `V`.

Each CI shell gets a fresh private run root. The sole cross-step file is exact basename `qinao-ci-current-identity.json` directly below the already validated `RUNNER_TEMP`: exactly one applicable binder creates it O_EXCL as a mode-0600 regular non-symlink file, fsyncs/reopens/canonical-validates it, and later validation steps may open it read-only only when their literal `--identity` argument names that exact path. The CI profile revalidates owner/mode/path, event file, checked-out `HEAD`, schema, self-digest, `V`, and policy inputs on every reopen; no other runner-temp file or directory becomes import/input authority, and no generic external-path allowance exists. Collision, replacement, hard link, wrong link count, changed bytes, or a second producer fails the job. This CI is still candidate-controlled evidence, never local or host authorization.

After Task 3's bootstrap commit, every Python token shown as `qinao_python` is a reserved harness operation, **not** a `PATH` executable, alias, or inherited function. The sterile step payload defines it locally as the following literal function after recovering exact `WT`, `RUN_ROOT`, mode-0700 `home/` and `tmp/`, and the committed launcher/ledger identity:

```bash
qinao_python() {
  /bin/test "$#" -ge 1
  /bin/test -d "$RUN_ROOT/home"
  /bin/test -d "$RUN_ROOT/tmp"
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" TMPDIR="$RUN_ROOT/tmp" \
    LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    /usr/bin/python3 -I -S -B \
    "$WT/scripts/qinao_convergence_audit.py" sterile-python \
    --root "$RUN_ROOT" --repository "$WT" -- "$@"
}
```

`sterile-python` is the only post-bootstrap Python entry. The audit file itself imports standard library only and is first reopened against its committed Git blob, SHA-256, ledger identity, `/usr/bin/python3` binary/framework/dylib projection, `sys.flags` (`isolated=1`, `ignore_environment=1`, `no_user_site=1`, `no_site=1`, `dont_write_bytecode=1`), OpenSSL identity, and compiled default CA file/directory digests. It never adds the repository, script directory, current directory, user site, or a generic import root to `sys.path`. A closed meta-path loader maps only the exact Qinao module/test names declared by the current task frontier or immutable policy manifest to regular, non-symlink files with recomputed Git-blob/SHA-256 identities; each invocation appends/fsyncs that complete module closure and target argv before executing it. Standard-library imports continue to resolve only from the interpreter's frozen standard-library roots. Script targets, `--version`, and the exact `-m unittest` forms in the matrix are the only entry modes; arbitrary `-c`, stdin code, zip/egg/namespace packages, dynamic plugin discovery, and third-party imports are rejected.

Every local invocation allocates one never-reused mode-0700 `RUN_ROOT/tmp/invocation.<id>/` before target execution, records its profile/argv/module/tool/input projection in the ledger, and writes a terminal outcome only after bounded child teardown and output digests are durable. A crash leaves an inventoried incomplete generation; recovery never resumes its code execution or treats its outputs as evidence, but the surrounding task frontier determines whether the logical pure command may be rerun. Declared target outputs live in their capture/result roots, never in this scratch directory. Neither launcher nor a later task deletes an incomplete invocation generation. CI uses the same generation shape inside its ephemeral job root and emits the terminal projection/digest to logs.

Before every invocation, the launcher performs a NUL-safe inventory of every candidate repository import directory. Tracked regular Python sources outside the selected closure may coexist, but they are indexed as non-importable and never enter generic `sys.path`; an undeclared source becomes an error only if it aliases/collides with an admitted module or target namespace. During TDD, only an exact ordinary regular `.py` path declared by the one open task frontier may be untracked/dirty and loaded; its descriptor/path/blob-style/SHA-256 identity is recorded for that invocation and must still match the frontier before every rerun. Every other untracked or ignored source, and any symlinked, duplicate, or namespace-colliding `.py`, plus every `.pyc`, `.pyo`, `.pth`, `.egg`, zip, `__pycache__`, `sitecustomize`, `usercustomize`, or standard-library-name shadow file, is rejected. `-B` prevents new bytecode, and the inventory proves ignored cache state cannot influence or evade clean-status/secret-scan evidence. The parent `env -i` leaves `PYTHONHOME`, `PYTHONPATH`, `PYTHONSTARTUP`, `PYTHONINSPECT`, `PYTHONWARNINGS`, `PYTHONBREAKPOINT`, `SSL_CERT_FILE`, `SSL_CERT_DIR`, `SSLKEYLOGFILE`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `GIT_SSL_CAINFO`, proxy, trace, and token variables absent; the launcher rejects their appearance rather than normalizing them. Network preflight binds the actual interpreter/runtime/OpenSSL/default-CA projection, launcher blob, module-closure manifest, and absence projection before any credential lookup or socket.

The sole pre-ledger bootstrap runs only the new `SterilePythonLauncherTests` and then the audit module through the same outer sterile shell and direct `/usr/bin/python3 -I -S -B`; it has no credentials, network, subprocess transport, or write target outside the two declared Task 3 paths and mode-0700 bootstrap diagnostics. The dispatcher selects its bootstrap profile only when the convergence ledger is absent, the exact Task 2 identity/dirty-set state reopens, and argv is one of the named Task 3 test/replay/`init-run-state` transitions; the caller cannot request bootstrap after publication. It selects `ci` only through the exact workflow launcher form and reviewed workflow/policy identities. Every other invocation requires the published ledger profile. Once the bootstrap commit and ledger exist, raw local interpreter execution is forbidden. Adversarial tests plant user-site `.pth`, `sitecustomize`, `usercustomize`, ignored `__pycache__`/`.pyc`, an undeclared local `ssl.py`/`json.py`/`hashlib.py`, malicious `BASH_ENV`/exported function/`PATH`, `SSLKEYLOGFILE`, and custom-CA/proxy variables; every marker, keylog, file, socket, import, and state mutation must remain absent. At `C`, the scanner may inventory—but never execute—one frozen migration debt: the exact `check_sovereign_redaction.sh` blob containing its historical heredoc, with mandatory-removal frontier Task 8 and no other caller than the enumerated boundary scripts. Its blob/path/caller set enters the initial ledger and any attempt to run that graph before Task 8 completion blocks. At final `H`, a plan/source/workflow AST test permits the literal `/usr/bin/python3` only inside an exact byte-template local/cold-start launcher definition, the exact CI-profile definition, and the one named bootstrap test command; every occurrence must have the exact `-I -S -B` argv shape, and every other raw Python entry or unclosed migration debt is rejected.

---

## Frozen inputs and identity algebra

These values are execution preconditions, not values to rediscover by guessing:

| Symbol | Frozen value or construction |
|---|---|
| `S` | `fba300fc9e040d2f5d9d08cd158fa3321dc36b93` |
| tree of `S` | `6e23fba9f09edcc56eb9692ef76df0006d8c2d4a` |
| spec blob in `S` | `7212afb0b29d83d8695ab8ae1b7f042b87400863` |
| parent of `S` | `5f17569d902da9d7a024c99158c44cbb72c34131` |
| required design ancestor | `5c87355d5870b8559cadbe3105adbbb86f2008e7` |
| protected HEAD | `29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895` |
| protected HEAD/index tree | `1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01` |
| preservation commit | `4a9298db261bcfda97ea1748baad65649156ba66` |
| preservation tree | `22382c1de6680a263ec4a2f4a6c989c0f0e6e220` |
| unique merge base | `243c083f345f3586ef226020d42af4653b31a62a` |
| protected index SHA-256 | `089b62d56244917e72b528d9bc832fcf9dceeb9ba37fe5016f503fbedcd67592` |
| protected index stage-record SHA-256 | `4e942296c7e6ff7bf7b61457e31b5cfef62bb1915c36ae00e1f8380cad590599` |
| protected index stage/flag-record SHA-256 | `19776d5274171c529bfc69ebe8ab81ffcbe36a21811b0a2503236850f23e5149` |
| protected porcelain-v1 `-z` SHA-256 | `45faece29aad471828a39eef3acc600d8828bf0e45133ad72ce83b76a1a6c875` |
| protected porcelain-v2 `-z` SHA-256 | `f3cf7d41c4e7b928737e10d86f980baa0f0126af67581d8b237c9481f7496539` |
| protected tracked binary diff SHA-256 | `58628700af05929c4f8d0d3a57c0f6dbf16fdff2ddc1a61be854ead0b5f9e7b2` |
| frozen `29d→4a` raw-manifest SHA-256 | `67b8958268caeda7b1dfcdd9f249824fd9b70ebbfdcf01aa528cacf89da88e3c` |
| protected content-manifest SHA-256 | `a9263c98711aca058577c014ef11525ecdfcd448dac7dc6df6ae1d372525688d` |
| `D` | final design-branch tip after this reviewed plan is the only path committed above `S` |
| `C` | normal local merge commit with ordered parents `[4a9298d…,D]` |
| `B` | fresh exact remote `refs/heads/main` OID before final candidate construction |
| `H` | final implementation head, with `C` as ancestor |
| `T` | tree OID returned by hermetic merge construction from exact `B,H` |
| `V` | SHA-256 of the canonical policy-revision object binding matrix, schemas, risk code, workflow contract, and review configuration blobs |
| `A` | SHA-256 of the RFC-8785-canonical finite automation inventory, excluding observation time |
| `E` | SHA-256 of the canonical final-evidence payload with its own digest field omitted |
| `R` | fresh host merge result, required to have tree `T` and ordered parents exactly equal to `P`; for this convergence PR only, `P=[B,H]` |

The implementation must preserve this graph:

```text
5c87355… ──ancestor──> S ──plan-only commit──> D
                                               \
4a9298d… ───────────────────────────────────────> C ──ordinary commits──> H

B + H ──hermetic merge-tree──> T
(B,H,T,V,A,M,P,body,risk,validation,review,recovery) ──JCS/SHA-256──> E
B + H ──one approved native merge──> R(tree=T, parents=[B,H])
```

## File and responsibility map

| Path | Action | Single responsibility |
|---|---|---|
| `scripts/qinao_convergence_audit.py` | Create | Own the durable run ledger; parse raw Git records; verify frozen topology/protected state; capture/verify the complete `C→H` plan/spec inventory; emit CI identity bindings; enforce the sealed Git/GitHub invocation wrapper; perform one explicit presence-only LFS Batch observation. The wrapper executes only an already ledger-bound exact argv/destination/operation and grants no authorization; it never connects to an LFS action URL. |
| `scripts/test_qinao_convergence_audit.py` | Create | Fixtures for raw-byte paths, modes/types/OIDs, 33-path preservation, parent order, and document transformations. |
| `scripts/qinao_pr_protocol.py` | Create | Closed PR metadata, candidate/merge identities, risk classification, RFC 8785 serialization, `V/E`, chunk manifests, audit rendering, and pure unknown-outcome decisions. No subprocess/network/merge. |
| `scripts/test_qinao_pr_protocol.py` | Create | Adversarial metadata, risk, JCS, chunk, self-digest, stale identity, audit non-authority, and remote-outcome tests. |
| `scripts/qinao_pr_validation.py` | Create | Load the closed matrix, select targets from structured diff, execute bounded commands, and validate typed result objects bound to `(B,H,T,V)`. |
| `scripts/test_qinao_pr_validation.py` | Create | Nonempty selection/results, exact skip handling, parser fixtures, timeout/output-limit, environment, and stale-identity tests. |
| `BehavioralAISubstrate/Cargo/.cargo/config.toml` | Create | Force the Rust workspace to the repository-local vendored source and offline mode; no registry or ambient Cargo configuration participates in validation. |
| `BehavioralAISubstrate/Cargo/vendor/**` | Create from the locked offline import | Exact crates.io source closure for `Cargo.lock`; every file is tracked and bound by the vendor manifest. |
| `docs/superpowers/evidence/2026-08-29-qinao-cargo-vendor-manifest.v1.json` | Create | Canonical package/file/blob inventory binding `Cargo.lock`, Cargo source configuration, and the complete vendored dependency closure. |
| `scripts/qinao_workflow_inventory.py` | Create | Validate a complete repository/host/PR automation observation and compute `A`; block omissions, unknown privilege, and cross-trigger data flow. |
| `scripts/test_qinao_workflow_inventory.py` | Create | Coverage, permission, trigger, secret/environment, external-action, artifact/cache, endpoint-state, and digest tests. |
| `docs/superpowers/schemas/qinao-pr-evidence.v1.json` | Create | Closed field/type/order contract for policy revision, validation, review, automation, final evidence, comment chunks, and audit records. |
| `docs/superpowers/validation/qinao-pr-validation-matrix.v1.json` | Create | Versioned changed-surface-to-target mapping, command adapters, time/output bounds, and explicit limitations. |
| `docs/superpowers/validation/qinao-plan-spec-disposition.v1.json` | Create | Reviewed disposition seed for every tracked plan/spec object expected at `C`; runtime capture still proves the actual complete set. |
| `docs/superpowers/evidence/2026-08-29-qinao-plan-spec-inventory.v1.json` | Create | Machine record of every source blob at `C`, disposition/reason/permitted transform, and exact final blob at `H`. |
| `docs/superpowers/evidence/2026-08-29-qinao-pr-review-configuration.v1.json` | Create | Exact review partitions, producer identities, completeness rule, finding schema, and terminal criteria included in `V`. |
| `docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json` | Create | Closed reviewed semantics and exact blob binding for every active workflow; avoids pretending that a partial YAML parser proves completeness. |
| `.github/pull_request_template.md` | Create | Lightweight human checklist and exact machine-readable metadata markers; contains no approval field/token. |
| `.github/workflows/test.yml` | Modify from the `4a` version present after `C` | Preserve six baseline validation jobs; remove old controller/iOS-floor jobs; add read-only stateless protocol tests and metadata validation. |
| `.github/workflows/qinao-wave-admission.yml` | Delete from active `H` | Retire the former workflow-dispatch/JIT admission control surface; its exact blob remains in `C` and Git history. |
| `scripts/run_nonempty_xcode_test.py` and test | Preserve/reuse from `4a` | Structured nonempty SampleHost XCTest evidence; do not rewrite its mature parser in the new protocol module. |
| `scripts/run_nonempty_swift_filter.py` and test | Preserve/reuse from `4a` | Closed focused Swift test selection with exact non-skipped xUnit execution. |
| `scripts/test_chenglu_feature_schema.py` | Modify | Convert the existing pytest-only smoke tests to standard-library `unittest`, removing an unpinned runtime install from CI. |
| `docs/superpowers/plans/**/*.md`, `docs/superpowers/specs/**/*.md` | Modify only where inventory says `supersede` | Insert exactly one prescribed pointer; `historical-only` and `unrelated` blobs remain byte-identical to `C`. |

The old admission, managed-convergence, owner-ledger, A0.2/A0.3, snapshot, and Deep Scan tools may remain reachable as historical source. No workflow, validation matrix, PR metadata check, or merge procedure invokes them. Their continued presence is not a second active policy.

## Public data contracts

All four modules use immutable standard-library dataclasses and JSON-compatible values. Python 3.9 lacks built-in `slots=True` dataclasses and PEP 604 unions, so use `Optional[T]`, `Tuple[T, ...]`, and `@dataclass(frozen=True)`.

```python
@dataclass(frozen=True)
class CandidateIdentity:
    base_oid: str
    head_oid: str
    candidate_tree_oid: str
    policy_revision_sha256: str

@dataclass(frozen=True)
class PostMergeIdentity:
    result_oid: str
    base_oid: str
    head_oid: str
    tree_oid: str
    policy_revision_sha256: str

@dataclass(frozen=True)
class MergeIntent:
    mode: str
    parent_oids: Tuple[str, ...]

@dataclass(frozen=True)
class RawDiffEntry:
    old_mode: str
    new_mode: str
    old_oid: str
    new_oid: str
    status: str
    old_path_b64: Optional[str]
    new_path_b64: Optional[str]

@dataclass(frozen=True)
class RiskDecision:
    risk: str
    reason_codes: Tuple[str, ...]
    raw_diff_sha256: str
    entry_count: int

@dataclass(frozen=True)
class ValidationResult:
    target_id: str
    kind: str
    identity: CandidateIdentity
    discovered: int
    executed: int
    passed: int
    failed: int
    skipped: int
    enumerated: int
    checked: int
    outcome: str
    evidence: "ValidationEvidence"

@dataclass(frozen=True)
class ValidationSubresult:
    subresult_id: str
    argv_sha256: str
    exit_code: int
    stdout_sha256: str
    stderr_sha256: str
    discovered: int
    executed: int
    passed: int
    failed: int
    skipped_test_ids: Tuple[str, ...]
    enumerated: int
    checked: int

@dataclass(frozen=True)
class ValidationEvidence:
    command_exit_code: int
    timed_out: bool
    cancelled: bool
    stdout_truncated: bool
    stderr_truncated: bool
    stdout_sha256: str
    stderr_sha256: str
    merged_summary_sha256: str
    raw_evidence_sha256: str
    skipped_test_ids: Tuple[str, ...]
    subresults: Tuple[ValidationSubresult, ...]
```

Closed values:

- `MergeIntent.mode ∈ {"merge","squash"}`.
- `PostMergeIdentity` is valid only after reopening `R` as a commit with ordered parents `[B,H]`, `R^{tree}=T`, and the same policy revision `V`; a candidate identity cannot be silently coerced into it.
- `RawDiffEntry.status` stores the full Git status token; any rename/copy token, unmerged token, unknown token, mode/type change, symlink, gitlink, binary, `.gitattributes`, workflow/action, entitlement, privacy, encryption, persistence, recovery, schema, dependency, or unclassified path is high risk.
- Path optionality is status-closed: add has no old path, delete has no new path, rename/copy has both paths, and every other accepted status has one logical path represented in both fields. Any other combination is invalid.
- `RiskDecision.risk ∈ {"routine","high"}`; high risk is monotonic and cannot be overridden by declared PR metadata.
- `ValidationResult.kind ∈ {"test","static","document","build"}`; `outcome ∈ {"success","failure","incomplete"}`.
- `ValidationEvidence` is mandatory even on failure/incomplete. A timeout, cancellation, signal, nonzero or inconsistent exit, output truncation, missing stream digest, unknown/duplicate skip ID, or missing/duplicate sequence subresult makes the result `incomplete` or `failure` according to the closed adapter rule; it can never be normalized into success.
- Test success requires `discovered=executed=passed>0`, `failed=0`, and `skipped=0`, except a full-suite target whose exact skip identities equal its versioned reviewed baseline. Static/document/build success requires `enumerated=checked>0` and `failed=0`.
- Every object rejects unknown fields. Arrays whose order carries meaning retain schema order; set-like arrays are sorted by their canonical byte representation before hashing.

## Explicitly absent architecture

The implementation must not create or retain active references to any of the following:

- a new `.github/workflows/qinao-pr-policy.yml`;
- `pull_request_target`, `workflow_run`, `merge_group`, `repository_dispatch`, or comment-triggered policy evaluation;
- `statuses: write`, `checks: write`, `pull-requests: write`, `contents: write`, `actions: write`, `deployments: write`, `id-token: write`, or a secret/environment on candidate jobs;
- base-trusted, protected-base, self-green-resistant, bootstrap-shadow, required-context, canary-activation, or host-rule-migration claims;
- branch-protection/ruleset writes, a plan-tier upgrade, repository-publication, merge queue, native auto-merge, or custom GitHub App;
- an approval token/receipt, stored approval state, resumable merge permission, durable controller, CAS broker, signer, quorum, or hidden second policy;
- path-only risk/review inventories, SHA-1-only API assumptions, unsigned deterministic JSON presented as RFC 8785, or candidate-commit/tree conflation;
- blanket zero-skip rules for full existing suites, acceptance of best-effort Swift Testing warnings as full success, or the known-failing iOS 27 floor as this convergence gate;
- automatic retries after an indeterminate remote mutation;
- a snapshot, iCloud source-code path, application-data migration, or any Deep Scan 3 action.

### Task 1: Freeze the reviewed design tip and prove all read-only preconditions

**Files:**
- Read: `docs/superpowers/specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md`
- Read: `docs/superpowers/plans/2026-08-29-qinao-git-only-convergence-and-lightweight-pr.md`
- Read: `docs/superpowers/evidence/2026-08-28-qinao-p0-protected-worktree-preservation-manifest.tsv`
- Read: `docs/superpowers/evidence/2026-08-28-qinao-p0-protected-worktree-preservation-receipt.md`

**Interfaces:**
- Consumes: frozen constants in this plan and the final plan-only design commit.
- Produces: immutable `D`, local recovery ref `refs/qinao/recovery/git-only-design-tip`, and one or more retained bootstrap tool-projection generations (exactly one agreeing complete generation is sufficient); no tracked file change and no remote mutation.

- [ ] **Step 1: Load the execution skills and census any interrupted implementation state**

Read `superpowers:using-git-worktrees`, then `superpowers:subagent-driven-development` or `superpowers:executing-plans`, and `superpowers:test-driven-development`. List worktrees, the candidate ref, and the dedicated run-state directory. An existing candidate branch is not automatically failure and is never deleted/reset/overwritten: Task 2's closed recovery table must classify it before any new worktree or merge action.

Run:

```bash
git worktree list --porcelain
git show-ref --verify refs/heads/codex/qinao-git-only-convergence || true
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
test ! -L "$COMMON_GIT_DIR"
find "$COMMON_GIT_DIR/qinao-runs/git-only-convergence" \
  -maxdepth 2 -type f -print 2>/dev/null || true
```

Expected: a complete census with no mutation. First execution normally finds no branch/run state; recovery may find exactly one state admitted by Task 2.

- [ ] **Step 1A: Freeze the sterile bootstrap executable projection before trusting its output**

Still inside the outer `env -i` boundary, enumerate the exact fixed bootstrap set from the Mandatory sterile execution root by literal absolute pathname—never by PATH search, glob, or directory order. For each entry, use only `/bin/test`, `/usr/bin/stat`, and `/usr/bin/shasum` from that same closed set to require a resolved regular executable, record any platform-owned symlink chain without crossing onto a user-writable volume, and capture literal path, resolved path, device/inode/mode/uid/gid/size/mtime, SHA-256, and version output only where that binary has a noninteractive version operation. Record the running shell's `/bin/bash` projection and require it matches the pathname used by the outer boundary. The first projection grants no authority by itself; repeat it immediately after the census and require byte equality so even the bootstrap read is bracketed.

Using only the now-bracketed bootstrap set, safely create or reopen non-symlink mode-0700 `$COMMON_GIT_DIR/qinao-runs`, `git-only-convergence`, and its empty `home`, `tmp`, and `bootstrap` children; any other top-level child, wrong owner/mode/type, or pre-existing unclassified bootstrap entry blocks. Persist the two equal canonical projections and their digest in one never-used mode-0700 `bootstrap/capture.tool-projection.XXXXXX/` generation created atomically by the frozen absolute `mktemp`; use noclobber regular files, a self-including manifest, and a last-written terminal marker. A crash leaves a forensic partial generation that is never resumed or deleted; recovery allocates a new generation. Task 3's bootstrap tests recompute the same projection from exact paths, require every complete generation to agree and every partial generation to be explicitly inventoried, then import their manifests/digests into the atomic initial ledger before any later task can use a non-bootstrap executable. If Task 1 is interrupted, rerun Steps 1–1A and retain the older generation. A path/target/stat/hash change, user-writable parent/target, symlink loop, unsupported file type, missing binary, shell mismatch, differing repeated projection, or two disagreeing complete generations blocks before `D` is frozen. Tests substitute a hostile PATH binary, crash before each file/marker boundary, and swap a symlink target; none can be executed, accepted, or silently overwritten.

- [ ] **Step 2: Freeze `D` and prove the plan-only delta**

Run this block in the design worktree:

```bash
set -euo pipefail
S=fba300fc9e040d2f5d9d08cd158fa3321dc36b93
D="$(git rev-parse --verify HEAD^{commit})"
test "$(git rev-parse "$S^{tree}")" = 6e23fba9f09edcc56eb9692ef76df0006d8c2d4a
test "$(git rev-parse "$S^")" = 5f17569d902da9d7a024c99158c44cbb72c34131
test "$(git rev-parse "$S:docs/superpowers/specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md")" = 7212afb0b29d83d8695ab8ae1b7f042b87400863
git merge-base --is-ancestor "$S" "$D"
git merge-base --is-ancestor 5c87355d5870b8559cadbe3105adbbb86f2008e7 "$D"
test "$(git rev-parse "$D^")" = "$S"
test "$(git diff --name-status "$S" "$D")" = $'A\tdocs/superpowers/plans/2026-08-29-qinao-git-only-convergence-and-lightweight-pr.md'
test -z "$(git status --porcelain=v1 --untracked-files=all)"
printf 'S=%s\nD=%s\nD_TREE=%s\n' "$S" "$D" "$(git rev-parse "$D^{tree}")"
```

Reopen `git cat-file commit "$D"` as raw bytes and require exactly one `tree`, one `parent S`, `author Qinao design <qinao-design@invalid.local>`, `committer Qinao design <qinao-design@invalid.local>`, valid integer timestamps/timezones, no encoding/gpgsig/mergetag/unknown header, one blank separator, and exact message bytes `docs: plan Qinao Git-only convergence\n`. Expected: every assertion succeeds and the only `S..D` path is this plan. A default host/user identity, extra trailer, signature, second parent, or different full message blocks before the recovery ref is created.

Freeze that exact value once, without moving a branch:

```bash
set -euo pipefail
FROZEN_REF=refs/qinao/recovery/git-only-design-tip
ZERO=0000000000000000000000000000000000000000
D="$(git rev-parse --verify HEAD^{commit})"
if git show-ref --verify --quiet "$FROZEN_REF"; then
  test "$(git rev-parse --verify "$FROZEN_REF^{commit}")" = "$D"
else
  git update-ref -m 'freeze reviewed Qinao Git-only design tip' \
    "$FROZEN_REF" "$D" "$ZERO"
fi
test "$(git rev-parse --verify "$FROZEN_REF^{commit}")" = "$D"
```

Expected: the local recovery ref is either created once at `D` or already equals it. Any different existing value stops as recovery state. All later tasks read `D` only from this ref; they never rediscover it from a mutable design-worktree `HEAD`. The ref is never pushed or deleted by this plan.

- [ ] **Step 3: Reopen the frozen commits and merge-base facts**

Run:

```bash
set -euo pipefail
test "$(git rev-parse 4a9298db261bcfda97ea1748baad65649156ba66^)" = 29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895
test "$(git rev-parse 4a9298db261bcfda97ea1748baad65649156ba66^{tree})" = 22382c1de6680a263ec4a2f4a6c989c0f0e6e220
test "$(git merge-base 4a9298db261bcfda97ea1748baad65649156ba66 "$(git rev-parse refs/qinao/recovery/git-only-design-tip^{commit})")" = 243c083f345f3586ef226020d42af4653b31a62a
test "$(git diff --name-only 243c083f345f3586ef226020d42af4653b31a62a 4a9298db261bcfda97ea1748baad65649156ba66 | wc -l | tr -d ' ')" = 111
D="$(git rev-parse refs/qinao/recovery/git-only-design-tip^{commit})"
test "$(git diff --name-only 243c083f345f3586ef226020d42af4653b31a62a "$D" | wc -l | tr -d ' ')" = 41
```

Then compare the two sorted changed-path sets for `merge-base→4a` and `merge-base→D` and require an empty intersection. The frozen `D`, not the earlier required ancestor `5c`, is the complete design-side input. Do not treat the empty intersection as permission to skip the real merge-tree check in Task 2.

- [ ] **Step 4: Verify the protected worktree without refreshing its index**

Run each read with `GIT_OPTIONAL_LOCKS=0` against:
`/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-dual-space-controlled-convergence`.

```bash
set -euo pipefail
P=/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-dual-space-controlled-convergence
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" symbolic-ref -q HEAD)" = refs/heads/codex/qinao-dual-space-controlled-convergence
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" rev-parse HEAD)" = 29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" rev-parse HEAD^{tree})" = 1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01
GIT_OPTIONAL_LOCKS=0 git -C "$P" diff --cached --quiet HEAD --
test "$(shasum -a 256 "$(git -C "$P" rev-parse --git-path index)" | cut -d ' ' -f 1)" = 089b62d56244917e72b528d9bc832fcf9dceeb9ba37fe5016f503fbedcd67592
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" ls-files --stage -z | shasum -a 256 | cut -d ' ' -f 1)" = 4e942296c7e6ff7bf7b61457e31b5cfef62bb1915c36ae00e1f8380cad590599
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" ls-files --stage -v -z | shasum -a 256 | cut -d ' ' -f 1)" = 19776d5274171c529bfc69ebe8ab81ffcbe36a21811b0a2503236850f23e5149
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" status --porcelain=v1 -z --untracked-files=all | shasum -a 256 | cut -d ' ' -f 1)" = 45faece29aad471828a39eef3acc600d8828bf0e45133ad72ce83b76a1a6c875
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" status --porcelain=v2 -z --untracked-files=all | shasum -a 256 | cut -d ' ' -f 1)" = f3cf7d41c4e7b928737e10d86f980baa0f0126af67581d8b237c9481f7496539
test "$(GIT_OPTIONAL_LOCKS=0 git -C "$P" diff --binary --full-index --no-ext-diff --no-textconv | shasum -a 256 | cut -d ' ' -f 1)" = 58628700af05929c4f8d0d3a57c0f6dbf16fdff2ddc1a61be854ead0b5f9e7b2
test "$(git diff-tree --no-commit-id -r --raw -z --no-renames --abbrev=40 29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895 4a9298db261bcfda97ea1748baad65649156ba66 | shasum -a 256 | cut -d ' ' -f 1)" = 67b8958268caeda7b1dfcdd9f249824fd9b70ebbfdcf01aa528cacf89da88e3c
```

Expected: exact identity, clean staged delta, and every digest match. The content-manifest verifier later also requires `a9263c98711aca058577c014ef11525ecdfcd448dac7dc6df6ae1d372525688d`. Record the human-readable status separately for evidence; do not invoke `write-tree` or pass `--refresh`.

- [ ] **Step 5: Record the host limitation without writing host state**

Do not make a network call from this pre-implementation task: the scrubbed egress verifier and quarantine are not committed until Task 3. Record the planning-time observation that `gh auth status --hostname github.com` currently reports the active `ChangGeng01` token invalid, plus the previously observed private/user-owned, `allow_auto_merge=false`, and protection/ruleset tier limitation as **untrusted stale context only**. It grants no permission and is not used to create `C` or implementation commits.

Task 11 Step 1A/1B is the first authoritative host read, after the egress boundary exists. It must stop and ask the user to restore normal GitHub authentication before any network request if the token remains invalid, then freshly prove repository visibility/owner, Actions permissions, `main` state, Pages/deployments, protection, and rulesets. A success response or materially different limitation is changed capability and stops for review; it never authorizes mutation by itself.

Expected: local diagnostic note only, zero network request, and no local commit in this task.

### Task 2: Construct the hermetic two-parent convergence commit `C`

**Files:**
- Create/recover worktree only: `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-git-only-convergence`
- Before the first Task 3 commit, create/recover only private `home/` and `tmp/` directories plus unique bootstrap diagnostics below the absolute common Git directory; that commit then initializes the append-only run-state ledger at `qinao-runs/git-only-convergence/`
- No tracked file edits

**Interfaces:**
- Consumes: exact `D` from Task 1 and preservation commit `4a9298d…`.
- Produces: branch `codex/qinao-git-only-convergence`, worktree discoverable through `git worktree list --porcelain`, and merge commit `C` with ordered parents `[4a,D]`.

Before `worktree add`, capture `git config --local --no-includes --null --show-origin --list` and the optional worktree-config file as raw bytes. The closed allowlist is limited to core repository-format/filemode/bare/logallrefupdates/ignorecase/precomposeunicode, exact `core.hooksPath=.githooks` (observed but always overridden to `/dev/null`), exact `remote.origin.url`/fetch, inert `branch.*.(remote|merge|vscode-merge-base)`, `extensions.worktreeconfig=true`, `coderabbit.basebranch=main`, and the two exact repository LFS metadata keys. Reject every include, alias, filter, external diff/textconv, merge driver, fsmonitor, signing, credential, URL rewrite, custom upload/receive pack, SSH command, protocol override, submodule command, HTTP extra-header, or unknown key. Require both common/worktree `info/attributes` absent, no non-LFS filter attribute in the `4a`/`D` trees, no partial-clone/promisor config, and no missing object in the complete `4a`/`D` closure with lazy fetch disabled. Record the canonical allowlist projection/digest and any replacement refs; the sterile wrapper disables replacements. Repeat these assertions after worktree creation and before the merge. Any drift stops before `C`.

Before Step 1 takes any creating action, derive `COMMON_GIT_DIR`, its parent primary repository root, the exact durable `WT` above, and mode-0700 `RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"`. Do **not** pretend that the append-only ledger exists yet: its standard-library implementation and tests are the first deliverable in Task 3. Until that commit exists, Git's branch/worktree/index/sequencer state plus the exact declared Task 3 file set are the only recovery authority; Task 2 bootstrap captures are unique, noclobber diagnostics that may be repeated read-only but are not called sealed ledger evidence. Apply this closed table:

- branch absent with no registration/path: create once; an existing safe mode-0700 `RUN_ROOT` may contain only `home/`, `tmp/`, unique `bootstrap/capture.*` diagnostics (including agreeing Task 1 tool-projection generations), and immutable `bootstrap/tree-prediction.*` generations classified by their complete/partial tables, otherwise block;
- exactly one live registration at exact `WT`, branch at clean `4a`, and no merge sequencer: resume Task 2 Step 2 without another `worktree add`;
- exact in-progress merge state `HEAD=4a`, `ORIG_HEAD=4a`, `MERGE_HEAD=D`, no unmerged entry, predicted index tree, index-matching working tree, and no untracked path: resume only the fixed merge commit in Step 3;
- clean `HEAD=C` with exact parents `[4a,D]`, predicted tree, exact full message bytes, fixed synthetic author/committer names/emails, captured valid timestamps/timezones, and no encoding/signature/mergetag/unknown commit header: resume Step 4/7, then begin Task 3;
- before the Task 3 ledger commit, `HEAD=C` with dirty/untracked state is resumable only when every entry is one of the two declared Task 3 paths, no merge/rebase/cherry-pick sequencer exists, and rerunning the focused failing tests reproduces the expected Task 3 phase; any other state blocks;
- clean `HEAD` at the exact Task 3 bootstrap commit, with parent `C`, exact full message bytes, fixed Task-2-prelude author/committer names/emails, captured valid timestamps/timezones, no optional/unknown commit header, a delta limited to the two declared Task 3 paths, passing focused ledger/scanner tests, and a complete matching bootstrap secret-scan diagnostic, while the ledger is absent or has only an admitted incomplete `ledger.init.*` staging directory: resume only Task 3 Step 0D using the reopened committed module; validate or preserve every staging generation and create-once publish the initial ledger—do not rerun or amend the commit;
- after the Task 3 ledger commit, verify its immutable run identity/frontiers; for a descendant of one valid `C`, verify every expected Tasks 3–10 commit subject/order/tree delta, cumulative declared path set, and optional Task 11 base-reconciliation merge frontier, then resume the single exact open frontier or next task;
- existing directory with a valid linked-worktree `.git` file but stale reverse registration: capture admin bytes into a new diagnostic directory, run targeted `git worktree repair "$WT"`, then restart this table;
- registered but missing `WT`: before a Task 3 sealed clean frontier, block because externally lost unstaged/untracked bytes cannot be disproved. After such a frontier, preserve exact branch/reflog/admin digests, remove only that stale registration with targeted `git worktree remove --force "$WT"`, recreate the same branch/path, and revalidate the sealed commit/tree; an open/dirty frontier still blocks;
- multiple registrations, another branch/path occupant, changed `D`, unexpected commit/diff/config, a missing ledger outside the single exact bootstrap-transition state, malformed published ledger, ambiguous complete init staging, unclassified dirty state, or any other case: block and preserve everything.

No recovery case resets, cleans, checks out over, rebases, amends, deletes a branch, or prunes other worktrees. Before and after every recovery action, repeat the protected-worktree witness. Process interruption immediately after worktree creation or during the controlled merge is recoverable from Git state; externally deleted pre-ledger working bytes are explicitly beyond what any truthful plan can reconstruct.

- [ ] **Step 1: Create only the classified-absent durable worktree with LFS smudge and hooks disabled**

Run from any clean worktree in the shared repository:

```bash
set -euo pipefail
D="$(git rev-parse --verify refs/qinao/recovery/git-only-design-tip^{commit})"
REPOSITORY="$(git rev-parse --path-format=absolute --show-toplevel)"
COMMON_GIT_DIR="$(git -C "$REPOSITORY" rev-parse --path-format=absolute --git-common-dir)"
PRIMARY_ROOT="$(dirname "$COMMON_GIT_DIR")"
RUNS_PARENT="$COMMON_GIT_DIR/qinao-runs"
RUN_ROOT="$RUNS_PARENT/git-only-convergence"
WT="$PRIMARY_ROOT/.worktrees/qinao-git-only-convergence"
umask 077
test ! -e "$WT"
test -z "$(git worktree list --porcelain | awk '/^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print}')"
test -z "$(git show-ref --verify refs/heads/codex/qinao-git-only-convergence 2>/dev/null || true)"
if test -e "$RUNS_PARENT"; then
  test -d "$RUNS_PARENT"
  test ! -L "$RUNS_PARENT"
else
  mkdir -m 700 "$RUNS_PARENT"
fi
test "$(stat -f '%Lp' "$RUNS_PARENT")" = 700
if test -e "$RUN_ROOT"; then
  test -d "$RUN_ROOT"
  test ! -L "$RUN_ROOT"
  test -d "$RUN_ROOT/home"
  test ! -L "$RUN_ROOT/home"
  test -d "$RUN_ROOT/tmp"
  test ! -L "$RUN_ROOT/tmp"
  test -z "$(find "$RUN_ROOT" -mindepth 1 -maxdepth 1 \
    ! -name home ! -name tmp ! -name bootstrap -print -quit)"
else
  mkdir -m 700 "$RUN_ROOT"
  mkdir -m 700 "$RUN_ROOT/home"
  mkdir -m 700 "$RUN_ROOT/tmp"
fi
test "$(stat -f '%Lp' "$RUN_ROOT")" = 700
test "$(stat -f '%Lp' "$RUN_ROOT/home")" = 700
test "$(stat -f '%Lp' "$RUN_ROOT/tmp")" = 700
if test ! -e "$RUN_ROOT/bootstrap"; then
  mkdir -m 700 "$RUN_ROOT/bootstrap"
fi
test -d "$RUN_ROOT/bootstrap"
test ! -L "$RUN_ROOT/bootstrap"
BOOTSTRAP_DIR="$(mktemp -d "$RUN_ROOT/bootstrap/capture.XXXXXX")"
test "$(stat -f '%Lp' "$BOOTSTRAP_DIR")" = 700
set -C
test ! -e "$COMMON_GIT_DIR/info/attributes"
git -C "$REPOSITORY" config --local --no-includes --name-only \
  --get-regexp '.*' | LC_ALL=C sort -u >"$BOOTSTRAP_DIR/local-config-keys.txt"
while IFS= read -r key; do
  case "$key" in
    core.repositoryformatversion|core.filemode|core.bare|core.logallrefupdates|core.ignorecase|core.precomposeunicode|core.hookspath|remote.origin.url|remote.origin.fetch|extensions.worktreeconfig|coderabbit.basebranch|lfs.repositoryformatversion|lfs.https://github.com/ChangGeng01/ProjectSix.git/info/lfs.access|branch.*.remote|branch.*.merge|branch.*.vscode-merge-base) ;;
    *) printf 'unreviewed local config key: %s\n' "$key" >&2; exit 1 ;;
  esac
done <"$BOOTSTRAP_DIR/local-config-keys.txt"
test "$(git -C "$REPOSITORY" config --local --no-includes --get core.hookspath)" = .githooks
test "$(git -C "$REPOSITORY" config --local --no-includes --get remote.origin.url)" = https://github.com/ChangGeng01/ProjectSix.git
test "$(git -C "$REPOSITORY" config --local --no-includes --get remote.origin.fetch)" = '+refs/heads/*:refs/remotes/origin/*'
git -C "$REPOSITORY" config --local --no-includes --null --show-origin --list \
  >"$BOOTSTRAP_DIR/local-config.raw"
shasum -a 256 "$BOOTSTRAP_DIR/local-config.raw" "$BOOTSTRAP_DIR/local-config-keys.txt"
/usr/bin/env -i \
  HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
  XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  GIT_CONFIG_SYSTEM=/dev/null GIT_LITERAL_PATHSPECS=1 \
  GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
  GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 \
  GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 PAGER=cat \
  /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
  -c core.hooksPath=/dev/null \
  -c core.autocrlf=false \
  -c filter.lfs.clean= -c filter.lfs.smudge= \
  -c filter.lfs.process= -c filter.lfs.required=false \
  -c commit.gpgSign=false -c merge.gpgSign=false \
  -C "$REPOSITORY" worktree add \
  -b codex/qinao-git-only-convergence \
  "$WT" 4a9298db261bcfda97ea1748baad65649156ba66
test "$(git -C "$WT" rev-parse HEAD)" = 4a9298db261bcfda97ea1748baad65649156ba66
WORKTREE_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-dir)"
test ! -e "$WORKTREE_GIT_DIR/info/attributes"
test ! -e "$WORKTREE_GIT_DIR/config.worktree"
test "$(git -C "$WT" show 4a9298db261bcfda97ea1748baad65649156ba66:.gitattributes)" = 'docs/Recovery/3a011899-aafa-43e6-961a-5c2649331735.jsonl filter=lfs diff=lfs merge=lfs -text'
test "$(git -C "$WT" show "${D}:.gitattributes")" = 'docs/Recovery/3a011899-aafa-43e6-961a-5c2649331735.jsonl filter=lfs diff=lfs merge=lfs -text'
GIT_NO_REPLACE_OBJECTS=1 GIT_NO_LAZY_FETCH=1 \
  git -C "$WT" rev-list --objects --missing=print \
  4a9298db261bcfda97ea1748baad65649156ba66 "$D" \
  >"$BOOTSTRAP_DIR/source-object-closure.txt"
awk '$1 ~ /^\?/ { missing=1 } END { exit missing }' \
  "$BOOTSTRAP_DIR/source-object-closure.txt"
git -C "$WT" for-each-ref --format='%(objectname)%09%(refname)' refs/replace/ \
  >"$BOOTSTRAP_DIR/replacement-refs.tsv"
printf 'convergence_worktree=%s\nD=%s\n' "$WT" "$D"
```

Expected: the classified-absent case creates one durable worktree/branch and one unique noclobber bootstrap diagnostic generation; every other admitted case bypasses creation and resumes from the closed table. A partial diagnostic is retained and recovery allocates a new generation—no fixed file is overwritten. The diagnostic is not called sealed ledger evidence: after Task 3's first commit, only a complete generation may be imported by digest, while a partial generation is ignored except as preserved forensic input and the observation is recaptured. No checkout or hook runs in either original worktree.

- [ ] **Step 2: Predict the exact merge tree**

Rediscover `WT` from the branch entry in `git worktree list --porcelain`; require exactly one match. Then run:

```bash
set -euo pipefail
D="$(git rev-parse --verify refs/qinao/recovery/git-only-design-tip^{commit})"
WT="$(git worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
COMMON_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -n "$WT"
sterile_git() {
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_SYSTEM=/dev/null GIT_LITERAL_PATHSPECS=1 \
    GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 \
    GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 PAGER=cat \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.autocrlf=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c commit.gpgSign=false -c merge.gpgSign=false \
    -C "$WT" "$@"
}
umask 077
PREDICTION_ROOT="$(mktemp -d "$RUN_ROOT/bootstrap/tree-prediction.XXXXXX")"
PREDICTION_OBJECTS="$PREDICTION_ROOT/objects"
mkdir -m 700 "$PREDICTION_OBJECTS"
shared_objects_digest() {
  find "$COMMON_GIT_DIR/objects" -type f -print0 | LC_ALL=C sort -z | \
    xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
}
SHARED_OBJECTS_BEFORE="$(shared_objects_digest)"
prediction_git() {
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_OBJECT_DIRECTORY="$PREDICTION_OBJECTS" \
    GIT_ALTERNATE_OBJECT_DIRECTORIES="$COMMON_GIT_DIR/objects" \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -C "$WT" "$@"
}
PREDICTED_TREE="$(prediction_git merge-tree --write-tree --no-messages \
  4a9298db261bcfda97ea1748baad65649156ba66 "$D")"
test "$(shared_objects_digest)" = "$SHARED_OBJECTS_BEFORE"
test -n "$(find "$PREDICTION_OBJECTS" -type f -print -quit)"
case "$PREDICTED_TREE" in
  [0-9a-f][0-9a-f]*) ;;
  *) exit 1 ;;
esac
test "$(printf '%s' "$PREDICTED_TREE" | wc -c | tr -d ' ')" = 40
test "$(prediction_git cat-file -t "$PREDICTED_TREE")" = tree
set -C
printf 'predicted_tree=%s\nshared_objects_before=%s\n' \
  "$PREDICTED_TREE" "$SHARED_OBJECTS_BEFORE" >"$PREDICTION_ROOT/result.tsv"
shasum -a 256 "$PREDICTION_ROOT/result.tsv"
```

Expected: one 40-hex tree OID and exit zero. Any conflict message or other output stops; do not auto-select a side.

Every `tree-prediction.*` directory is an immutable bootstrap resource generation. A process interruption preserves that directory exactly; recovery never removes, repairs, or imports it. A generation is usable only when `result.tsv` is the last successfully created file, contains exactly the two declared keys once, its tree is a 40-hex object that reopens as `tree` through that generation's isolated object directory plus the shared read-only alternate, and its recorded shared-object digest still equals a fresh before-merge snapshot. Zero usable generations causes a new empty generation; multiple usable generations must agree on the tree or recovery blocks. Tests interrupt before the object directory, after `merge-tree` writes objects, before/inside `result.tsv`, and after completion, and prove the shared object manifest is byte-identical at every boundary.

- [ ] **Step 3: Create the normal merge commit**

The ledger code does not exist yet, so this step does not claim to append a frontier. Before `C`, the exact `HEAD/ORIG_HEAD/MERGE_HEAD`, index tree, predicted tree, clean/untracked state, and fixed commit message in the closed Task 2 table are the recovery authority. At the beginning of this fresh process, repeat Step 2's entire isolated prediction block into a new `tree-prediction.*` generation and retain its validated `PREDICTED_TREE`; `merge-tree --write-tree` is forbidden against the shared object directory. After `C`, Task 3's first committed ledger implementation imports the verified Task 1/2 identities and diagnostic digests into its initial immutable run record; it never retroactively labels a partial bootstrap capture as complete.

```bash
set -euo pipefail
D="$(git rev-parse --verify refs/qinao/recovery/git-only-design-tip^{commit})"
WT="$(git worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
COMMON_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test "$(git -C "$WT" rev-parse HEAD)" = 4a9298db261bcfda97ea1748baad65649156ba66
sterile_git() {
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_SYSTEM=/dev/null GIT_LITERAL_PATHSPECS=1 \
    GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 \
    GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_AUTHOR_NAME='Qinao convergence' \
    GIT_AUTHOR_EMAIL=qinao-convergence@invalid.local \
    GIT_COMMITTER_NAME='Qinao convergence' \
    GIT_COMMITTER_EMAIL=qinao-convergence@invalid.local \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.autocrlf=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c commit.gpgSign=false -c merge.gpgSign=false \
    -c merge.autoStash=false -c rerere.enabled=false \
    -C "$WT" "$@"
}
umask 077
PREDICTION_ROOT="$(mktemp -d "$RUN_ROOT/bootstrap/tree-prediction.XXXXXX")"
PREDICTION_OBJECTS="$PREDICTION_ROOT/objects"
mkdir -m 700 "$PREDICTION_OBJECTS"
shared_objects_digest() {
  find "$COMMON_GIT_DIR/objects" -type f -print0 | LC_ALL=C sort -z | \
    xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
}
SHARED_OBJECTS_BEFORE="$(shared_objects_digest)"
prediction_git() {
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_OBJECT_DIRECTORY="$PREDICTION_OBJECTS" \
    GIT_ALTERNATE_OBJECT_DIRECTORIES="$COMMON_GIT_DIR/objects" \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -C "$WT" "$@"
}
PREDICTED_TREE="$(prediction_git merge-tree --write-tree --no-messages \
  4a9298db261bcfda97ea1748baad65649156ba66 "$D")"
test "$(shared_objects_digest)" = "$SHARED_OBJECTS_BEFORE"
test -n "$(find "$PREDICTION_OBJECTS" -type f -print -quit)"
case "$PREDICTED_TREE" in
  [0-9a-f][0-9a-f]*) ;;
  *) exit 1 ;;
esac
test "$(printf '%s' "$PREDICTED_TREE" | wc -c | tr -d ' ')" = 40
test "$(prediction_git cat-file -t "$PREDICTED_TREE")" = tree
set -C
printf 'predicted_tree=%s\nshared_objects_before=%s\n' \
  "$PREDICTED_TREE" "$SHARED_OBJECTS_BEFORE" >"$PREDICTION_ROOT/result.tsv"
shasum -a 256 "$PREDICTION_ROOT/result.tsv"
if test -f "$(sterile_git rev-parse --git-path MERGE_HEAD)"; then
  test "$(sterile_git rev-parse MERGE_HEAD)" = "$D"
  test "$(sterile_git rev-parse ORIG_HEAD)" = 4a9298db261bcfda97ea1748baad65649156ba66
else
  test "$(sterile_git rev-parse HEAD)" = 4a9298db261bcfda97ea1748baad65649156ba66
  test -z "$(sterile_git status --porcelain=v1 --untracked-files=all)"
  sterile_git merge --no-ff --no-commit --no-edit --no-gpg-sign --no-verify "$D"
fi
test -z "$(sterile_git ls-files -u)"
test -n "${PREDICTED_TREE:-}"
case "$PREDICTED_TREE" in
  [0-9a-f][0-9a-f]*) ;;
  *) exit 1 ;;
esac
test "$(printf '%s' "$PREDICTED_TREE" | wc -c | tr -d ' ')" = 40
test "$(sterile_git write-tree)" = "$PREDICTED_TREE"
test -z "$(sterile_git diff --name-only)"
test -z "$(sterile_git ls-files --others --exclude-standard)"
sterile_git commit --no-verify --no-gpg-sign \
  -m 'Merge frozen Qinao Git-only design into preservation lineage'
C="$(sterile_git rev-parse HEAD)"
test "$(sterile_git rev-list --parents -n 1 "$C")" = "$C 4a9298db261bcfda97ea1748baad65649156ba66 $D"
test -z "$(sterile_git ls-files -u)"
test -z "$(sterile_git status --porcelain=v1 --untracked-files=all)"
printf 'C=%s\nC_TREE=%s\n' "$C" "$(sterile_git rev-parse "$C^{tree}")"
```

Expected: a clean normal merge commit; first parent is preservation, second parent is `D`. Reopen the full raw commit object and require the exact one-line message plus terminal LF, synthetic author/committer names and `@invalid.local` emails from the sterile environment, valid captured timestamps/timezones, and only `tree`, ordered `parent`, `author`, and `committer` headers. Any `encoding`, `gpgsig`, `mergetag`, duplicate, continuation, or unknown header blocks recovery and continuation.

- [ ] **Step 4: Compare the predicted and actual trees**

In a fresh process, recompute `PREDICTED_TREE` by repeating the complete isolated Task 2 Step 2 block into another never-used generation; snapshot the shared object namespace immediately before and after and require it byte-identical. Never run `merge-tree --write-tree` through `sterile_git` or any shared object directory. Then require:

```bash
set -euo pipefail
D="$(git rev-parse --verify refs/qinao/recovery/git-only-design-tip^{commit})"
WT="$(git worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
test -n "$WT"
COMMON_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
sterile_git() {
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -C "$WT" "$@"
}
C="$(sterile_git rev-parse HEAD^{commit})"
test "$(sterile_git rev-list --parents -n 1 "$C")" = \
  "$C 4a9298db261bcfda97ea1748baad65649156ba66 $D"
umask 077
PREDICTION_ROOT="$(mktemp -d "$RUN_ROOT/bootstrap/tree-prediction.XXXXXX")"
PREDICTION_OBJECTS="$PREDICTION_ROOT/objects"
mkdir -m 700 "$PREDICTION_OBJECTS"
shared_objects_digest() {
  find "$COMMON_GIT_DIR/objects" -type f -print0 | LC_ALL=C sort -z | \
    xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
}
SHARED_OBJECTS_BEFORE="$(shared_objects_digest)"
prediction_git() {
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_OBJECT_DIRECTORY="$PREDICTION_OBJECTS" \
    GIT_ALTERNATE_OBJECT_DIRECTORIES="$COMMON_GIT_DIR/objects" \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -C "$WT" "$@"
}
PREDICTED_TREE="$(prediction_git merge-tree --write-tree --no-messages \
  4a9298db261bcfda97ea1748baad65649156ba66 "$D")"
test "$(shared_objects_digest)" = "$SHARED_OBJECTS_BEFORE"
test -n "$(find "$PREDICTION_OBJECTS" -type f -print -quit)"
case "$PREDICTED_TREE" in
  [0-9a-f][0-9a-f]*) ;;
  *) exit 1 ;;
esac
test "$(printf '%s' "$PREDICTED_TREE" | wc -c | tr -d ' ')" = 40
test "$(prediction_git cat-file -t "$PREDICTED_TREE")" = tree
set -C
printf 'predicted_tree=%s\nshared_objects_before=%s\n' \
  "$PREDICTED_TREE" "$SHARED_OBJECTS_BEFORE" >"$PREDICTION_ROOT/result.tsv"
shasum -a 256 "$PREDICTION_ROOT/result.tsv"
test "$(sterile_git rev-parse "$C^{tree}")" = "$PREDICTED_TREE"
```

Also capture exact NUL-delimited raw full-index diffs with `--raw -z --full-index --no-abbrev --no-renames --no-ext-diff --no-textconv` and require the bytes for `4a^{tree}→C^{tree}` to equal the bytes for `merge-base^{tree}→D^{tree}`. This proves that the first-parent-relative merge delta is exactly the second lineage; comparing `4a→D` would be wrong because that range also reverses first-lineage changes. Require `D` and `5c87355…` to be ancestors of `C`.

- [ ] **Step 5: Re-run the complete protected-worktree witness**

Repeat Task 1 Step 4 byte-for-byte and compare the human-readable status/path list. Any mismatch stops and preserves all worktrees/refs for investigation.

- [ ] **Step 6: Review `C` as an independently testable deliverable**

Inspect:

```bash
git -C "$WT" show --stat --summary --decorate "$C"
git -C "$WT" diff-tree --cc --raw --full-index --no-abbrev "$C"
```

Expected: no unresolved combined-diff entry and no tracked edit above the merge. `C` itself is the task commit; do not amend it later.

- [ ] **Step 7: Establish the mandatory implementation-worktree prelude**

Every new shell process, agent task, test command, file edit, and commit in Tasks 3–10 must first run this exact prelude. Commands shown in those tasks are payloads after this prelude, not permission to use the caller's current directory:

```bash
set -euo pipefail
BRANCH=refs/heads/codex/qinao-git-only-convergence
D="$(git rev-parse --verify refs/qinao/recovery/git-only-design-tip^{commit})"
WT_ROWS="$(git worktree list --porcelain | awk -v b="branch $BRANCH" '
  /^worktree / { w=substr($0,10) }
  $0 == b { print w }
')"
test "$(printf '%s\n' "$WT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
WT="$(printf '%s\n' "$WT_ROWS" | sed '/^$/d')"
test -n "$WT"
COMMON_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -d "$RUN_ROOT/home"
test -d "$RUN_ROOT/tmp"
qinao_git() {
  /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_AUTHOR_NAME='Qinao development' GIT_AUTHOR_EMAIL=qinao-development@invalid.local \
    GIT_COMMITTER_NAME='Qinao development' GIT_COMMITTER_EMAIL=qinao-development@invalid.local \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.fsmonitor=false -c core.autocrlf=false \
    -c diff.external= -c commit.gpgSign=false -c merge.gpgSign=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c merge.autoStash=false -c rerere.enabled=false -C "$WT" "$@"
}
git() { qinao_git "$@"; }
qinao_python() {
  /bin/test "$#" -ge 1
  /bin/test -d "$RUN_ROOT/home"
  /bin/test -d "$RUN_ROOT/tmp"
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" TMPDIR="$RUN_ROOT/tmp" \
    LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    /usr/bin/python3 -I -S -B \
    "$WT/scripts/qinao_convergence_audit.py" sterile-python \
    --root "$RUN_ROOT" --repository "$WT" -- "$@"
}
test "$(git -C "$WT" symbolic-ref -q HEAD)" = "$BRANCH"
C="$(git -C "$WT" rev-list --merges --ancestry-path \
  4a9298db261bcfda97ea1748baad65649156ba66..HEAD --reverse | head -n 1)"
test -n "$C"
test "$(git -C "$WT" rev-list --parents -n 1 "$C")" = \
  "$C 4a9298db261bcfda97ea1748baad65649156ba66 $D"
git -C "$WT" merge-base --is-ancestor "$C" HEAD
cd -- "$WT"
test "$(git rev-parse --show-toplevel)" = "$WT"
git status --short --untracked-files=all
```

Before each `apply_patch`, pass an absolute path below this resolved `WT`. Every Git command in Tasks 3–10—including every shown `git add`, `git diff`, `git commit`, and object query—runs through the function defined above; never bypass it with another binary/path. Repeat the Task 2 local/worktree config allowlist, info-attributes, filter-attribute, promisor/missing-object, replacement-disabled, and config-digest assertions at the start of every new shell and task boundary. The explicit synthetic commit identity is recorded in evidence; hooks/signing/fsmonitor/external diff/LFS clean filters are disabled, every commit additionally spells `--no-verify --no-gpg-sign`, and Tasks 3–10 may not modify an LFS path. The ambient `.githooks/pre-commit`, optional PATH `gitleaks`, global includes, and signing configuration never execute.

Task 3 has one explicit bootstrap exception: until its first ledger commit exists, the closed Task 2 table plus exact dirty set `{scripts/qinao_convergence_audit.py,scripts/test_qinao_convergence_audit.py}` is authoritative. Inside the already sterile outer shell, that bootstrap first writes failing sterile-launcher/ledger/scanner tests, implements only their standard-library core, invokes the one named `/usr/bin/python3 -I -S -B` no-network test command, reruns through the resulting `qinao_python`, commits those two paths, then initializes the ledger from the committed implementation and imports the verified Task 1/2 facts plus sterile-runtime projection. From that clean frontier onward, raw interpreter execution is forbidden; Task 3 remainder and Tasks 4–10 use the ledger-backed `qinao_python` before editing, and no uncommitted bootstrap module is treated as recovery authority.

Immediately before every Tasks 3–10 commit and every Task 11 review-fix commit, after its declared tests and `git add`, run the versioned first-party `secret-scan-worktree` over the exact index plus every declared dirty/untracked regular file and require a nonzero scanned-file/byte/rule count. For Task 3's bootstrap commit, the tested scanner writes that result into a fresh bootstrap diagnostic and the newly committed ledger imports its digest; every later commit stores it directly in the open durable task/review-fix frontier. A hit, unreadable/symlink/special/oversized-unknown file, rule failure, zero count, or output mismatch blocks; hook suppression never means scan suppression. Task 11 independently reruns `secret-scan-objects` over the complete newly reachable full commit/tag/blob/LFS closure, so the pre-commit scan is defense in depth rather than remote-egress authority.

At each task boundary require a clean status. The sole pre-ledger bootstrap follows the explicit Task 3 exception above. Thereafter, before editing, append/fsync one `task-started` frontier with task number, starting `HEAD`, declared file set, expected failing-test IDs, and clean-status/config digests; after commit/tests append a separate `task-completed` frontier with commit/tree/delta/test/secret-scan digests. Inside a TDD task require every printed dirty path to be in the open frontier's declared file list before continuing. A subagent must receive `WT`, `C`, expected branch/config digest/frontier ID in its task text and repeat the prelude itself. If the branch has more than one candidate `[4a,D]` convergence merge, an unexpected dirty path/config exists, or any identity differs, stop and inspect recovery state. Never fall back to the design or protected worktree.

### Task 3: Implement the raw Git, topology, and document-inventory audit

**Files:**
- Create: `scripts/qinao_convergence_audit.py`
- Create: `scripts/test_qinao_convergence_audit.py`

**Interfaces:**
- Consumes: raw bytes from Git commands and frozen OIDs/digests.
- Produces: `init_run_state`, `allocate_capture`, `seal_capture`, `allocate_resource`, `snapshot_resource`, `snapshot_git_state`, `frontier_start`, `frontier_complete`, `recover_run_state`, `parse_raw_diff_z(payload, object_format)`, `verify_convergence_topology(repository, frozen)`, `capture_plan_spec_inventory(repository, revision)`, `verify_protected_snapshot(repository, frozen)`, `verify_final_plan_spec_inventory(repository, inventory, final_revision)`, and CLI subcommands `sterile-python` (ledger/bootstrap auto-profile locally; literal `--profile ci` only under the workflow contract), `init-run-state`, `allocate-capture`, `seal-capture`, `allocate-resource`, `snapshot-resource`, `snapshot-git-state`, `frontier-start`, `frontier-complete`, `recover-captures`, `protected`, `topology`, `documents-capture`, `documents-verify`, `documents-lint`, `diff-inventory`, `review-assignment-verify`, `validate-remote-advertisement`, `remote-object-revisions`, `remote-object-disclosure`, `secret-scan-worktree`, `secret-scan-objects`, `network-egress-preflight`, `seal-network-request-manifest`, `git-credential-auth-read`, `network-git`, `network-gh`, `quarantine-ref-observe`, `lfs-batch-observe`, `ci-bind`, `ci-push-bind`, `ci-supplemental-bind`, `risk-check-event`, and `risk-check-raw`.

For `sterile-python`, `--profile ci` and `--ci-runner-home` are inseparable and legal only when the current workflow file, shell template, literal run prefix, repository/workspace/event/temp topology, and policy inputs reopen to the reviewed CI contract. The runner home must be exactly the case-derived parent selected by that prefix; it is used only as a bounded read root for first-party toolchain discovery and is never passed as `HOME`. Local/bootstrap profiles reject both options. Expected-runner-owned toolchains are candidate evidence admitted only by Task 8's deterministic compatible-version selection plus immediate before/after recursive stat/digest bracketing; group/world-writable components, a changed symlink chain, same-release byte ambiguity, or unbracketed drift fails. A missing/mismatched root, undeclared tool, or workflow-prefix drift fails before target execution.

`protected` and `network-egress-preflight` each have closed create and reopen modes. Create mode writes one O_EXCL canonical record to the caller's fresh capture; `--verify RECORD --print-field ...` reopens that ordinary non-symlink file, rejects unknown schema/field/digest/input drift, and prints only a named scalar from the verified record. `protected` owns the frozen protected-worktree path, branch/OIDs and all witness constants in Task 1 and emits `witnessDigest`; `network-egress-preflight` always emits `recordDigest` and `localConfigProjectionDigest`, while the full network profile additionally emits `stableProjectionDigest`. `localConfigProjectionDigest` is the exact common subset over repository/worktree config, attributes, object/replacement/partial-clone state, local executable identities, and forbidden local environment; it deliberately excludes destinations, fetch policy, and both credential generations. A `--local-only` record can be compared only through this common subset and can never claim the full network stable projection. Neither verifier samples live state, mutates Git/index state, or accepts an arbitrary path outside the selected capture. Tests cover undefined output variables, altered files, wrong capture lineage, live protected drift between creation and frontier start, local/full subset equality, forbidden full-stable comparison from a local-only record, and a record/projection mismatch.

`recover-captures` has path-safe selectors needed after a fresh process: `--select-current-evidence-root` replays the convergence ledger and returns the one nonsuperseded evidence-root identity/path; `--select-current-preflight-root` replays that same parent ledger and returns the one nonsuperseded, terminally initialized `preflight-root` generation whose recorded parent-frontier suffix and `H0` still equal the current admitted chain, rejecting an incomplete, stale, drifted, or multiple generation; `--select-capture --phase PHASE --state sealed` returns exactly one matching terminal generation or fails on zero/multiple. Optional `--require-seal-record RECORD` must byte/path-match that selected generation's exact terminal seal after reopening its allocation, manifest, and every member. Only a registered typed phase schema may expose payload fields through this selector: `remote-main` admits exactly `ref` and `advertisedOid` in addition to generic capture/seal identity fields, and tests reject those names for every other phase or a seal from another generation. `--seal-record RECORD --print-field sealDigest|captureId|absolutePath` is the generic alternative and never exposes payload. `allocate-capture --parent-capture RECORD` may be repeated; it persists the ordered parent seal paths **and** independently recomputed seal digests in the allocation record, and rejects an unsealed, mutable, cyclic, duplicated, or tuple-incompatible parent. Typed `allocate-capture --parent-attempt RECORD` is admitted only by a registered remote-observation phase: under the ledger lock it reopens the attempt self-digest, its unique start/frontier/logical key and request seal, requires a repeated `--parent-capture` to be that exact request seal, and persists all of those paths/digests/IDs. A cross-intent, open/unwritten/duplicate attempt, missing request parent, logical-key drift, or phase not mapped to that mutation kind fails. `recover-captures --intent RECORD --print-field attemptRecordPath|requestSealRecordPath` is total only when exactly one self-digest-valid wrapper attempt and one sealed request are bound to that same start/frontier; zero/multiple/cross-intent records fail rather than returning a path. Thus a child cannot merely name an older capture or attempt while observing different bytes. `--select-recovery-capture --frontier-id ID --intent RECORD --phase PHASE` follows allocation sequence and explicit supersession links for a read-only recovery phase and returns exactly `absent`, `replace-incomplete`, or `sealed` plus only the state-appropriate named fields. For a registered remote-observation phase, repeated `--require-parent-capture RECORD --require-parent-attempt RECORD` must reopen and exactly equal its allocation's typed parents before any state/field is returned. `allocate-capture --replace-incomplete-capture OLD_ID` atomically appends a `forensic-incomplete` terminal classification over that read-only generation's exact current manifest and allocates one successor bound to it; it cannot replace a sealed capture, mutation capture, unbound phase, or more than one live incomplete generation. A valid sealed generation is always reopened, never replaced; more than one sealed/unlinked live generation blocks. `--select-task15-context --require-phase PHASE` derives a closed post-merge context only from the immutable identity, the unique `[4a,D]` convergence topology, the original merge intent/terminal record, and terminal phase records; it returns named `C/B/H/T/V/A/E/R/tupleDigest/prNumber/expectedActorId/mergeRequestSealRecordPath/mergeAttemptRecordPath/completionPreflightRecordPath/terminalContinuationPreflightRecordPath` fields plus the closed `openLocalFrontierKind/openLocalFrontierId` recovery projection. The two merge-parent fields reopen the original start, exact sealed canonical merge request, and unique wrapper attempt; they cannot be supplied by the recovery observation itself. `completionPreflightRecordPath` is immutable historical proof of the exact credential/config generation used to observe/close the merge; after closure, every later network call must instead use the unique sealed terminal-child `terminalContinuationPreflightRecordPath`, whose stable projection and both credential generations equal that historical proof. Reserved alias `merge-confirmed` requires the original `remote-merge-put` terminal `confirmed-success` record, its one lineage-compatible sealed `postmerge-merge-recovery-entry` observation parent-bound to those exact request/attempt records, **and** the one compatible sealed terminal-continuation preflight; it is not a free-standing/missing phase name and creates no extra record. The selector rejects a missing/duplicate source, phase regression, incompatible record, an open remote mutation, or more than one/phase-incompatible open local frontier. None of these selectors reads an ambient variable or chooses a pathname by mtime.

`allocate-capture --read-only-recovery --blocked-frontier ID` is permitted while that exact remote mutation frontier is open. An ordinary recovery-observation capture may contain only deterministic request-row inputs, sealed request manifests, wrapper-generated safe projections/status metadata, one validated advertisement record, one pure normalized merge-observation record, and its exact self-including whitelist. `postmerge-merge-recovery-entry` is a registered `remote-merge-put` observation phase and always requires the original `merge-put-request` seal as `--parent-capture` plus the same frontier's unique wrapper attempt as `--parent-attempt`, whether the merge frontier is still open or already terminal; selection/replacement revalidates both typed parents. Preflight has two distinct monotone phases rather than one mixed schema: `postmerge-merge-recovery-preflight-open` contains exactly one fresh full `qinao.network-egress.v1` record plus seal and binds `blockedFrontierId`, its start/unique attempt, baseline merge intent, prior stable-projection digest, and both credential generations; `postmerge-merge-recovery-preflight-terminal` is an ordinary child capture allocated only after the exact `confirmed-success` terminal exists and instead binds that terminal path/digest/result `R` plus the same start/attempt/baseline/stable-projection/credential generations. The phases cannot replace or satisfy one another. An open seal remains immutable historical evidence after closure; a terminal cold start selects/creates the terminal child, never reuses/supersedes the open phase. No other file class is admitted. Only the open phase temporarily permits the read-only recovery exception; `frontier-start`, resource allocation/mutation, Git-state mutation, and host mutation remain rejected until that blocker closes. Tests restart from `env -i`, cover open-preflight seal→merge completion→terminal-preflight child, first entry after a normal Task 14 synchronous terminal success, and reject an ambient/relative/symlink root, stale/superseded root, mixed/open-without-blocked/terminal-without-terminal-record schema, multiple live/sealed/unlinked entry captures within either phase (while accepting a single explicit forensic-incomplete predecessor chain), cross-phase substitution, a missing/wrong/cross-intent request or attempt parent, duplicate attempt, an unbound read capture, a missing/extra/drifted record, a recovery file outside those closed classes, and every attempted mutation under the open-frontier exception.

There is one closed way to cross from such a sealed recovery observation to a terminal merge frontier without opening another generation: `frontier-complete --classify-merge-recovery-from-observation`. While holding the ledger lock, it reopens the exact start, the unique wrapper-owned attempt record already bound to that frontier, and the sealed observation, calls the committed pure Task 6 classifier in-process, requires `confirmed-success`, embeds the canonical classification/digest and the observation-bound `completionPreflightRecordPath` in the one O_EXCL terminal record, fsyncs, and returns it. It accepts no caller-supplied attempt/state/classification file; absence or multiplicity of the persisted attempt blocks. A crash before that terminal fsync leaves only the sealed read capture and the original open frontier, so `--recover-exact` safely repeats the pure computation; a crash after fsync returns the same terminal bytes. Tests cover start-without-attempt, duplicate/mismatched attempt, observation-seal→classification, classification→terminal-fsync, and lost-terminal-stdout boundaries and prove no classification file is appended to a sealed capture.

- [ ] **Step 0A: Write the failing sterile-launcher, ledger, and bootstrap secret-scan tests before any other Task 3 implementation**

Using only the two declared Task 3 paths, add focused tests for an immutable run identity, append-only frontiers, and capture generations. The tests require:

- `SterilePythonLauncherTests` to spawn the exact outer `env -i`/`python -I -S -B` boundary with hostile `BASH_ENV`, exported functions, `PATH`, `PYTHONHOME/PYTHONPATH`, user-site `.pth`/customizers, ignored bytecode/cache, local standard-library shadows, TLS keylog/custom-CA/proxy variables, and marker/socket/file side effects; require the exact interpreter/stdlib/OpenSSL/default-CA/launcher/module closure, zero repository path on generic `sys.path`, only closed target modes, no bytecode/keylog/marker/socket, and rejection before target execution for every undeclared import artifact or environment field;
- a NUL-safe plan/source/workflow scanner that rejects every new raw Python executable entry except exact local/cold-start launcher templates, the exact CI-profile prefix, and one named no-network bootstrap command; at `C` it quarantines only the exact historical redaction-heredoc blob/caller set as non-executable Task 8 migration debt, and final-H mode requires that debt absent; it also rejects any Task 1–15 fence not rooted in the exact sterile outer shell or any pre-preflight ambient executable/function;
- an existing mode-0700, non-symlink `RUN_ROOT` whose only pre-initialization children are the admitted empty `home/` and `tmp/`, `bootstrap/capture.*` diagnostics (including Task 1 tool projections), immutable `bootstrap/tree-prediction.*` generations, and recoverable `ledger.init.*` staging generations; initialization validates and imports a manifest/digest for every diagnostic/prediction generation, marks a generation without its terminal/result record forensic-partial only, requires every complete tool projection to agree and every complete prediction to agree with `C^{tree}`, and never deletes or promotes a partial generation;
- `identity.json`, lock, record, phase, and capture directories created without following symlinks, with files mode 0600 and directories mode 0700;
- `os.open(..., O_CREAT|O_EXCL|O_NOFOLLOW)`, complete short-write handling, `fsync` of each file and every affected parent directory before a record is returned, and an advisory `fcntl.flock` held across sequence/previous-digest allocation;
- canonical self-digesting records with one immutable run identity, contiguous sequence, `previousRecordDigest`, operation kind, input digest, declared filenames, and completion state; no record is edited, renamed over, or reused;
- `allocate_capture` to create a never-used `captures/<phase>/<sequence>-<random-id>/` before appending its allocation record; `seal_capture` to admit only a caller-supplied exact filename whitelist of ordinary, non-symlink files, hash/fsync each file, create one O_EXCL manifest, fsync the generation, then append its terminal seal record;
- `frontier_start` to reject a second open **peer/top-level** task or mutation frontier and `frontier_complete` to require the exact open ID/input/declared path set; start and completion are different immutable records. One exact open task frontier may own at most one simultaneously open, schema-enumerated local-resource child through `--parent-frontier TASK_FRONTIER_ID --component-kind KIND`; that child is not a peer, has no child of its own, may mutate only its bound resource, and may perform a network operation only when its enumerated kind is read-only with no remote write. The parent task cannot complete while a child is open, and a child cannot outlive/change parent, touch repository declared paths, authorize another component, or weaken the one-peer rule. Task 8's only admitted child kinds are `cargo-archive-census` and `cargo-archive-acquisition`, sequentially; every other Tasks 3–10 task schema defaults to no child unless this plan names one exactly. Their CLI `--recover-exact` mode may only return an already persisted byte-identical start/completion after lost stdout—it never creates a second record. A local-resource-only child frontier may terminate as `tainted-preserved` only after binding a fresh complete snapshot of its current bytes and proving that its operation class had no remote write; ordinary task, Git-state, and remote-mutation frontiers cannot use that state. Tests reject two children, a peer disguised as a child, absent/wrong/completed parent, unenumerated kind, child repository/remote-write mutation, child after parent completion, and parent completion before its child;
- `allocate_resource` to create a never-used mode-0700 resource directory (for example a bare fetch quarantine) under a closed root, and `snapshot_resource` to append a generation containing a NUL-safe/base64 relative-path manifest of every directory/ordinary file, mode, size, and SHA-256 after rejecting symlinks, hard-link surprises, special files, path escape, unexpected names, and concurrent change; a resource may mutate only under one exact open frontier, and restart accepts it only when current bytes equal the latest complete snapshot;
- `snapshot_git_state` to double-read and bind the shared repository's complete ref namespace, packed refs, stable NUL/base64 recursive object-store manifest, object-format/closure, index/worktree admin files, `FETCH_HEAD`, shallow/promisor/alternates/commit-graph/MIDX/maintenance/config state, and absence of transient locks. Its remote-main-import classifier admits only unchanged input, valid content-addressed object additions attributable to the exact source closure with the destination ref still absent, or the exact completed ref/object post-state; a changed/deleted existing object, foreign ref, admin/config drift, temp/lock file, or incomplete closure blocks;
- recovery to replay the complete digest chain, reconstruct the single open frontier and capture states, and classify any gap, fork, duplicate ID, collision, symlink, unexpected filename, truncation, malformed/noncanonical JSON, digest mismatch, orphan seal, or incomplete mutation as `indeterminate` without changing it; a caller may subsequently close only an exactly reconciled resource-local frontier as `tainted-preserved`, while every other indeterminate mutation remains open and blocks;
- mocked short writes/fsync failures plus process interruption during every init file/directory/fsync/atomic-publish boundary, an external destination-creation race, unsupported no-replace filesystem behavior, after capture/resource allocation, during payload/resource mutation, before/after snapshot or manifest, and before terminal record; a read-only incomplete capture may be recaptured in a fresh generation, while an intent-bearing mutation may only be observed, never replayed except for the separately proved deterministic local-import continuation below; a resource that differs from its latest snapshot is preserved as tainted and replaced by a new empty resource generation rather than cleaned/reused;
- crash fixtures before/after isolated `merge-tree --write-tree` creates its prediction object tree, before `result.tsv`, and at successful `C`→ledger initialization; shared object namespace must remain byte-identical during prediction, every partial/complete generation must be imported with its correct forensic classification, and no valid generation may become an unexpected-child blocker. Also cover base-merge start-before-merge, merge-prepared, commit-before-completion, and completion-response loss; plus remote-main local-import crashes before object copy, with valid attributable partial object additions, after exact ref update, and after terminal-record fsync. Exact same-source local import may continue from the first two import states; exact post-state recovers completion; a foreign ref/object, changed existing object, lock/temp/admin drift, or incomplete result closure blocks without cleanup;
- `secret-scan-worktree` to scan the exact index plus declared dirty/untracked ordinary files, report positive file/byte/rule counts, and fail on a hit, zero selection, symlink, special/unreadable file, size bound, undeclared dirty path, or output collision.

Run only these tests first and require their expected import/attribute failures. Before this first implementation commit, restart recovery remains the Task 2 closed-table exception and never executes an uncommitted ledger module.

- [ ] **Step 0B: Implement the sterile launcher, minimal standard-library ledger, and worktree scanner**

Implement only the tested `sterile-python` dispatcher, run-state primitives, and `secret-scan-worktree` in `scripts/qinao_convergence_audit.py`. The dispatcher follows the Mandatory sterile execution root exactly, uses no repository import at module top level, and writes its exact execution/module manifest through the bootstrap diagnostic or committed ledger before target execution. The immutable identity binds repository common-dir identity, exact `WT`, branch, `S/D/C`, protected witness digests, config digest, sterile-shell/executable/interpreter/stdlib/OpenSSL/default-CA/launcher projections, object format, schema/rule-set version, and creation nonce. `init_run_state` first builds a never-used `ledger.init.<random-id>/` with O_EXCL files, **the complete initial digest chain**, and all directories fully fsynced. For the convergence profile, that initial chain already contains the verified Task 1/2 imports, complete bootstrap-diagnostic and scanner digests, exact bootstrap commit/tree/parent/full-commit metadata, clean-status/config/protected witnesses, and terminal `bootstrap-completed`; there is no post-publication bootstrap append. While holding the common advisory lock, publish it with macOS `renameatx_np(fromDirFd, stagingName, toDirFd, "ledger", RENAME_EXCL=0x00000004)` through standard-library `ctypes`, fixed argument/return/errno declarations, relative single-component names, and already-open non-symlink directory FDs; then fsync `RUN_ROOT`. Plain `os.rename`, `os.replace`, check-then-rename, or an overwrite fallback is forbidden. `EEXIST` reopens and validates the winner without changing either directory; `ENOTSUP`, missing symbol, unexpected errno, or an external collision that is not the exact identity blocks and preserves both. On restart it validates and may no-clobber publish exactly one complete matching staging generation, preserves incomplete generations, and rejects two complete candidates or a different published identity. Thus a crash or non-cooperating creator cannot expose/replace a published ledger without its identity and terminal initial record. Bootstrap diagnostics are imported only by filename/size/digest after reopening them as ordinary files; a partial diagnostic remains listed as incomplete input and is never promoted to a seal.

All persisted JSON uses the same strict canonical subset later frozen for evidence: UTF-8/LF, duplicate-key rejection, no floats or unsafe integers, valid Unicode, sorted keys, one terminal newline, bounded bytes, and self-digest computed with the digest field omitted. The lock file contains no authority and is never interpreted as a record. Recovery trusts only reopened committed code plus the immutable on-disk chain.

- [ ] **Step 0C: Verify and commit the bootstrap implementation**

Within the outer sterile shell, the one allowed raw interpreter bootstrap command is `/usr/bin/python3 -I -S -B scripts/test_qinao_convergence_audit.py SterilePythonLauncherTests LedgerTests SecretScanWorktreeTests`; it has no credential/network imports and writes only declared bootstrap diagnostics. After it passes, run those classes again through the newly implemented `qinao_python`, stage only the two Task 3 files, rerun `secret-scan-worktree` from those staged bytes plus the exact declared dirty set, and write its canonical output into a fresh mode-0700 `bootstrap/capture.*` diagnostic using noclobber. Require a positive scan count and zero findings, then commit:

```bash
git add scripts/qinao_convergence_audit.py scripts/test_qinao_convergence_audit.py
git commit --no-verify --no-gpg-sign -m "feat: add durable Qinao run ledger"
```

Expected: the first ordinary commit above `C` contains only the two files, passes its focused tests, and has no LFS path. Reopen its full raw commit object and require the exact message bytes, one parent `C`, expected tree, the sterile Task-2-prelude synthetic author/committer identities, valid captured timestamps/timezones, and no optional/unknown header. Interruption before this commit remains recoverable only under the exact two-path pre-ledger rule; interruption after the commit never falls back to uncommitted code.

- [ ] **Step 0D: Initialize and recover-check the ledger from the committed implementation**

With clean `HEAD` at the bootstrap commit, render the exact bounded bootstrap-import input and run `init-run-state --profile convergence --bootstrap-import ...` once. The no-clobber atomic publication includes the verified Task 1/2 facts (`D`, `C`, ordered parents/tree/full-commit metadata, protected witness, config projection, agreed merge prediction), a path-safe manifest/size/digest/classification for **every** `bootstrap/tree-prediction.*` generation, complete other bootstrap-diagnostic/scanner digests, and terminal clean `bootstrap-completed` record in the initial chain. Partial prediction generations remain `forensic-partial`; complete generations must agree with `C^{tree}` and remain independently reopenable through their isolated objects. No second append is permitted. Run `recover-captures` in a fresh process and require exact identity, contiguous chain, the terminal bootstrap record, no open frontier, the clean `HEAD/tree`, and every imported digest. Repeat the protected-worktree witness.

Only now open the normal Task 3 remainder frontier, declaring the same two paths and the exact remaining failing-test IDs. Every following Task 3 step, capture, and commit uses these committed primitives. This is the sole transition from the Task 2 Git-state bootstrap to ledger-governed recovery.

- [ ] **Step 1: Write failing raw-diff parser tests**

Add tests that use literal NUL records and assert preservation of modes, full OIDs, status, and base64 raw paths:

```python
def test_parse_raw_diff_preserves_mode_oid_status_and_raw_path(self):
    old_oid = b"1" * 40
    new_oid = b"2" * 40
    payload = (
        b":100644 120000 " + old_oid + b" " + new_oid
        + b" T\x00bad\xffname\x00"
    )
    entries = module.parse_raw_diff_z(payload, "sha1")
    self.assertEqual(len(entries), 1)
    self.assertEqual(entries[0].old_mode, "100644")
    self.assertEqual(entries[0].new_mode, "120000")
    self.assertEqual(entries[0].status, "T")
    self.assertEqual(
        base64.b64decode(entries[0].new_path_b64),
        b"bad\xffname",
    )

def test_parse_raw_diff_rejects_truncation_abbreviated_oid_and_extra_fields(self):
    bad = b":100644 100644 1234 " + b"2" * 40 + b" M\x00x\x00"
    with self.assertRaises(module.AuditError):
        module.parse_raw_diff_z(bad, "sha1")
```

Cover add/delete, mode-only/type change, control bytes, duplicate path, rename/copy token, unmerged token, unknown status, SHA-256 object format, and a record missing its terminal NUL.

- [ ] **Step 2: Run the focused tests and confirm failure**

Run:

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_convergence_audit.RawDiffTests
```

Expected: import or attribute failure because the module is not present.

- [ ] **Step 3: Implement the strict parser**

Use this record grammar:

```python
RAW_HEADER = re.compile(
    rb"\A:([0-7]{6}) ([0-7]{6}) ([0-9a-f]+) ([0-9a-f]+) "
    rb"([A-Z](?:[0-9]{1,3})?)\Z"
)
OBJECT_HEX_LENGTH = {"sha1": 40, "sha256": 64}
```

Split on NUL, require the final empty field, consume exactly one path for every non-`R/C` entry and two paths for `R/C`, validate full OID length, reject duplicate destination raw paths, and encode path bytes with `base64.b64encode(...).decode("ascii")`. Do not decode paths for identity; a separately derived display string may use UTF-8 replacement only for human output.

- [ ] **Step 4: Write failing topology and protected-state tests**

Use a temporary repository fixture. Assert:

- `C` has exactly two parents and exact order;
- `D` contains both `S` and `5c87355…`;
- `H` contains `C`;
- a swapped parent order fails;
- one changed protected status byte, index digest, file mode, file type, blob/content digest, path, or count fails;
- filesystem access-time differences are not inspected.

The protected result type is:

```python
@dataclass(frozen=True)
class ProtectedSnapshot:
    head_oid: str
    index_tree_oid: str
    index_sha256: str
    index_stage_sha256: str
    index_stage_flags_sha256: str
    porcelain_v1_z_sha256: str
    porcelain_v2_z_sha256: str
    binary_diff_sha256: str
    manifest_entry_count: int
    raw_manifest_sha256: str
    content_manifest_sha256: str
```

- [ ] **Step 5: Implement topology/protected verification as read-only subprocess calls**

Every Git child uses an argv list, `stdin=DEVNULL`, bounded output, `GIT_OPTIONAL_LOCKS=0`, `GIT_NO_REPLACE_OBJECTS=1`, `GIT_NO_LAZY_FETCH=1`, `GIT_TERMINAL_PROMPT=0`, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_SYSTEM=/dev/null`, and `core.hooksPath=/dev/null`. Use `git hash-object` without `-w` for working-file blob identity and `os.lstat` for Git-visible regular/symlink mode. Reject gitlinks and special files.

Parse the exact `29d→4a` raw manifest as 33 entries—11 additions and 22 modifications—with final mode `100644`. Require its raw paths to equal the protected status paths. For each entry, reopen `4a:path`, require its OID to equal the raw new OID, require the protected working object to be an ordinary file, and require working bytes to equal the blob. Hash the NUL-delimited field stream `path,change,old_mode,new_mode,old_oid,new_oid,sha256` and require `a9263c98711aca058577c014ef11525ecdfcd448dac7dc6df6ae1d372525688d`. Never count raw NUL tokens with `wc`; one record has a header token and path token.

The CLI exits `0` only after every exact field closes; validation failure exits `1`; invocation/incomplete observation exits `2`. It writes canonical JSON only to an explicitly supplied path outside the protected worktree and never invokes `write-tree` against the protected worktree.

- [ ] **Step 5A: Specify and test the PR-CI identity binding**

`ci-bind --repository ROOT --event-path EVENT --output RESULT` is PR-only. It reads a regular, bounded event JSON as data and requires exact `repository.full_name="ChangGeng01/ProjectSix"`, same-repository head, base ref `main`, 40-hex `pull_request.base.sha=B`, 40-hex `pull_request.head.sha=H`, checked-out `HEAD=H`, and both objects already present locally. It never fetches or calls a network API. With replacements, lazy fetch, hooks, signing, global/system config, pager, and prompts disabled, it computes `T` using `git merge-tree --write-tree --no-messages B H`, reopens every closed policy path at `H`, computes `V`, and writes/prints one canonical record:

```json
{
  "schemaVersion": "qinao.ci-identity.v1",
  "event": "pull_request",
  "repository": "ChangGeng01/ProjectSix",
  "B": "40 lowercase hex",
  "H": "40 lowercase hex",
  "T": "40 lowercase tree hex",
  "V": "64 lowercase hex",
  "prBodySha256": "64 lowercase hex",
  "policyInputsSha256": "64 lowercase hex",
  "recordDigest": "64 lowercase hex"
}
```

`recordDigest` self-excludes. The function verifies `T` is a tree, requires `git merge-base --is-ancestor B H`, and requires `H^{tree} == T`; therefore the checked-out bytes tested by the job are exactly the candidate tree, not merely a head that reports another merge-tree result. A base advancement not yet merged into `H`, missing base object, default PR merge checkout, fork, stale event, conflict, extra output, different path/blob, or noncanonical record is `incomplete`. Unit fixtures cover each failure. Task 6 freezes the exact policy-path list and JCS implementation before this CLI becomes usable.

- [ ] **Step 5B: Specify and test the future-safe main-push identity binding**

`ci-push-bind --repository ROOT --event-path EVENT --output RESULT` is push-only and remains valid for future ordinary/squash/rebase/native-merge commits. It requires exact repository, `ref="refs/heads/main"`, non-deleted push, checked-out `HEAD=after`, and `before` equal to the event's old main OID. It reopens `after^{tree}`, parses/binds the commit's actual complete ordered parent array without imposing a count, computes `V` from the same closed policy paths, and emits exactly one canonical record per required main-push job:

```json
{
  "schemaVersion": "qinao.ci-push-identity.v1",
  "event": "push",
  "repository": "ChangGeng01/ProjectSix",
  "ref": "refs/heads/main",
  "before": "40 lowercase old-main hex",
  "after": "40 lowercase hex",
  "parents": ["zero or more ordered 40 lowercase commit OIDs"],
  "tree": "40 lowercase tree hex",
  "V": "64 lowercase hex",
  "policyInputsSha256": "64 lowercase hex",
  "recordDigest": "64 lowercase hex"
}
```

It performs no fetch/network call and uses the same sterile Git/JCS rules as `ci-bind`. A workflow-dispatch event, non-main branch push, deleted ref, merge-checkout, wrong `before`/`after`, parent-array disagreement with the raw commit, missing policy object, or noncanonical record fails. The binder deliberately does **not** require a two-parent result, so later squash/linear commits do not make the permanent workflow fail. Only Task 15's offline verifier specializes the selected convergence event by requiring `before=B`, `after=R`, `parents=[B,H]`, `R^{tree}=T`, and the same `V`.

- [ ] **Step 5C: Specify the explicitly non-candidate supplemental identity**

`ci-supplemental-bind --repository ROOT --event-path EVENT --output RESULT` accepts only `workflow_dispatch` or a non-deleted, non-`main` `push`. It requires the exact checked-out event commit, raw tree/ordered parents, repository/ref/event, workflow blob and computed `V`, then emits `qinao.ci-supplemental-identity.v1` with `claimScope="supplemental-only"` and a self-excluding digest. It has no `B`, `T`, PR-body, merge, or approval field and is rejected anywhere candidate/post-merge evidence is required. A PR or main-push event, wrong checkout/ref, missing policy input, or attempt to upgrade the claim scope fails. Every workflow event therefore has exactly one applicable binder, while only `ci-bind` can produce pre-merge candidate evidence.

Its closed canonical field set is exactly `schemaVersion`, `event`, `repository`, `ref`, `eventCommit`, `parents`, `tree`, `V`, `policyInputsSha256`, `claimScope`, and self-excluding `recordDigest`. For non-main push, `eventCommit=after`; for workflow dispatch it equals the event's checked-out commit. Both require `eventCommit=HEAD`, raw ordered parents/tree equality, and `claimScope="supplemental-only"`. Fixtures reject a field borrowed from either other identity schema and prove this record round-trips through the Task 6 evidence schema.

`risk-check-event` consumes the verified CI-identity record, computes the complete raw `B^{tree}→T` diff with the same parser, invokes `classify_risk`, and emits a self-digesting `qinao.risk-result.v1` object containing exact `(B,H,T,V)`, PR-body digest, raw-diff digest/count, effective class, and sorted reason codes. Unknown parsing or any disagreement with declared metadata escalates to high/failure; it never returns routine by default.

`risk-check-raw` consumes an already verified identity JSON plus the exact raw-diff byte file and emits the same risk object without an event/body claim. It exists so Task 11 can run both the candidate implementation and a reviewed base implementation, when present, on identical immutable inputs. Neither subcommand reads a declaration to lower structured risk.

`remote-object-revisions --H OID --advertisement RECORD --source-map RECORD --imported-ref-map FILE --exclude-ref LITERAL --output FILE --excluded-output FILE` is a pure output-O_EXCL generator. It reopens the advertisement/source-map parent captures through their seal-bound records, verifies the imported namespace against the import terminal, and emits exactly `H\n` followed by sorted unique `^OID\n` negative tips for every advertised/fetched head/tag except the one literal candidate ref. Its separate canonical excluded-target record binds that ref/OID and both output digests. It rejects another omission, duplicate/symbolic/unborn/non-head-or-tag ref, unsafe text, altered map, absent import terminal, or `candidate=H` cancellation fixture.

`remote-object-disclosure --repository ROOT --H OID --revision-input FILE --advertisement-record RECORD --fetched-ref-map FILE --object-oids FILE --object-types-sizes FILE --output RESULT` is local/read-only after the caller has separately captured/fetched remote refs. It reopens the seal-bound exact heads-and-tags-scoped `ls-remote --refs --branches --tags` advertisement record and the private fetched-ref map, independently reruns `rev-list --objects --no-object-names --stdin` and `cat-file --batch-check`, compares those bytes with both supplied capture files, and performs NUL-safe `ls-tree -r -z` over every newly reachable commit before emitting `qinao.remote-object-disclosure.v1`. For every reachable LFS pointer it reopens the local content-addressed object without smudge/network, recomputes SHA-256 and byte size, and fails closed if the object is absent, changed, unreadable, or not locally classifiable.

For every newly reachable commit, reopen the complete bounded raw object with `cat-file`, recompute its Git object ID without writing, and parse raw headers before the first blank line. Require exactly one tree, **zero or more** ordered parent rows, exactly one author and committer with bounded raw identity/timestamp/timezone fields, and the remaining message bytes. Zero parents is allowed only when graph traversal independently proves the object is a root; otherwise the raw ordered list must equal the independently traversed exact parents, including every parent of an octopus merge. Optional `encoding`, continuation-formed `gpgsig`, and `mergetag` headers are admitted only through explicit typed records and review; duplicate required header, malformed continuation, NUL/control violation, unknown header, signature/tag parse failure, or OID mismatch blocks. Hash and scan every byte of author/committer name/email, timestamps, optional header/signature/tag content, and message—not only the subject/body. Annotated tag objects receive the same full-object treatment for `object/type/tag/tagger`, optional signature, and message. Tree records preserve every raw path/mode/OID. The disclosure persists only redacted field IDs, byte ranges, sizes, SHA-256 values, classifications, and terminal dispositions; a local/private email or signature is real egress data, not metadata exempt from review.

The record binds the advertisement digest, negative tips, every new commit/tree/blob/tag OID/type/size, all path reachability for every new blob, full commit/tag-object digests and header dispositions, a pure-local LFS manifest digest and terminal content dispositions, binary/large/generated/vendor/recovery classification, local secret/private-data scan rule IDs, and a self-excluding manifest digest. Raw secret or private bytes never enter the output or a remote request. Tests cover a valid zero-parent root, ordinary and octopus ordered parents, an object reachable at two paths, a blob reachable only from an intermediate historical commit, annotated/signed tags, author/committer private email, secret in author/header/message/signature/mergetag, unknown/duplicate/malformed commit header, remote-advert drift, missing fetched tip, altered OID/type-size capture, missing/mismatched/unreadable local LFS object, malformed LFS pointer, an unrelated local ref containing a different LFS pointer that must stay outside the authoritative set, `docs/Recovery/**`, `.env`/key/database/transcript fixtures, and large/binary blobs. An omitted object/path/header byte or ambiguous classification fails closed.

`secret-scan-worktree` and `secret-scan-objects` share one frozen rule-set/version digest. The worktree mode scans exact index blobs plus declared dirty/untracked regular-file bytes without following symlinks; the object mode scans every byte-bearing field in full commit/annotated-tag objects, every ordinary blob, and every locally resolved LFS object before egress. Rules cover recognized private-key/credential/token formats, high-confidence connection strings, local/private identity and host-name markers, repository-specific private-data/transcript/recovery markers, and bounded entropy candidates with explicit object/field/path context; fixtures include true/false-positive controls and secrets split across binary/text/header-continuation boundaries. Output is redacted canonical JSON containing only rule IDs, base64 path/field IDs, object/file digests, bounded locations, counts, dispositions, rule-set digest, and self-digest—never matched secret bytes. Any skipped/truncated/unreadable/unknown candidate fails closed. Neither command invokes a PATH-discovered scanner, network, hook, filter, or credential helper.

`network-egress-preflight` is a local parser that runs before the first Git/GitHub/LFS network read and immediately before every LFS/Git/GitHub mutation. Task 8's public crate-archive client is a different, credential-free, request-manifest-bound read surface and cannot call these wrappers or GitHub. The preflight captures all effective Git config scopes/origins in memory, but persists only key names, redacted value digests, and an allowlisted projection. It reopens tracked/worktree `.lfsconfig`, `.git/config`, optional `config.worktree`, resolved fetch URL, **all** push URLs, redacted `git lfs env`, absolute/version/digest identities for `/usr/bin/git`, `git-lfs`, the `qinao_python` launcher/audit/module manifest, `/usr/bin/python3` plus its standard-library/OpenSSL/default-CA TLS runtime, and `gh`, and the names—not values—of relevant environment variables. It requires Git 2.53's exact `--negotiation-tip`, `--no-auto-maintenance`, `--no-write-commit-graph`, and `--no-recurse-submodules` capabilities, exactly one fetch/push URL `https://github.com/ChangGeng01/ProjectSix.git`, exact derived Batch endpoint `https://github.com/ChangGeng01/ProjectSix.git/info/lfs`, no unreviewed `.lfsconfig`, and no destination-changing, implicit-ref, push-option/signature, or leakage surface: `remote.*.pushurl`, `remote.*.push`, `remote.*.mirror`, URL `insteadOf/pushInsteadOf`, `push.followTags`, `push.pushOption`, `push.gpgSign`, `push.useForceIfIncludes`, custom upload/receive pack, `lfs.url/pushurl` or `remote.*.lfsurl`, proxy, HTTP extra-header, disabled TLS verification, custom SSH/proxy command, protocol override, trace/debug, injected config, askpass, or token environment. Only a separately reviewed credential-helper projection may remain; its secret/output is held in memory only and never captured. Every `network-git` child receives highest-priority `-c http.followRedirects=false`; any smart-HTTP 3xx is terminal and the wrapper never follows or replays it. The `push` operation additionally injects `-c remote.origin.mirror=false -c push.followTags=false -c push.pushOption= -c push.gpgSign=false -c push.useForceIfIncludes=false`, requires `--porcelain --no-follow-tags --no-signed --no-force-if-includes`, one literal source:destination refspec and one exact lease, and rejects any push-option. Its locale-independent porcelain result is the only output eligible for terminal lease/rejection classification. Tests inject every forbidden key/env/source, multiple push URLs, rewrite, malicious helper, smart-HTTP redirect, `.lfsconfig`, redaction failure, omitted fetch-side-effect flag, missing/locally-private negotiation tip, accidental submodule recursion, inherited follow-tags/push option/signing/force-if-includes/mirror/refspec, missing porcelain mode, and prove a receiving fixture observes exactly one intended ref update with zero push-option/signature/tag side effect.

The emitted `qinao.network-egress.v1` contains exact repository/remote, resolved Git/LFS/GitHub endpoints, executable/config/environment/fetch-policy projection digests, approved Git credential-helper identity/generation digest, approved `gh` token-source identity/generation digest, forbidden-surface count zero, capture timestamp/phase/ID, `localConfigProjectionDigest`, `stableProjectionDigest`, and record self-digest. `localConfigProjectionDigest` is the destination/credential-independent subset defined above. `stableProjectionDigest` hashes exactly that local subset plus destination/fetch-policy and both independent credential-source/generation projections, and excludes observation time, phase, capture ID/path, sequence, and record digest. Fresh full preflights therefore have distinct record digests but must have the same stable projection unless one separately reviewed credential generation is deliberately selected and all dependent proofs/intents are rebuilt; local-only preflights are comparable only by the local subset. Every network wrapper explicitly unsets `GIT_TRACE*`, `GIT_CURL_VERBOSE`, `GIT_REDIRECT_STDERR`, `GIT_SSH*`, `GIT_PROXY_COMMAND`, `GH_DEBUG`, `GH_TRACE`, `GH_TOKEN`, `GITHUB_TOKEN`, `GIT_CONFIG_COUNT/KEY_*/VALUE_*`, askpass, and proxy variables; uses fixed absolute executables/restricted PATH, `GIT_TERMINAL_PROMPT=0`, fixed API media/version headers, and no redirects for the exact LFS Batch observer. Every network `fetch` supplies `--no-auto-maintenance --no-write-commit-graph --no-recurse-submodules --no-write-fetch-head`. A fetch may omit `--negotiation-tip` only when its resource snapshot proves a newly created bare quarantine has zero refs/objects/alternates/promisor/submodule/remote state; its exact requested remote ref set is then intent-bound and it has no local `have` to disclose. Every fetch into a nonempty selected quarantine supplies one or more `--negotiation-tip=<OID>` values that the selected advertisement proves are already remote-known; the wrapper refuses a nonempty fetch lacking every fixed flag or containing an unproved tip. A tainted resource is preserved; a fresh empty replacement may re-fetch its exact required set under the same zero-have rule rather than trusting partial packs. Objects enter the shared repository only afterward through a separately captured local bundle/repository fetch with networking disabled and its own Git-state frontier. This prevents the shared repository's unrelated local refs from entering negotiation and prevents fetch-triggered maintenance or submodule traffic. Every network intent and `E` binds both the selected fresh record digest/generation and its full stable projection; a stable-projection drift invalidates the pending operation, while observation metadata difference alone does not.

`network-git` and `network-gh` are the only Git/GitHub network executors after Task 3. Their closed syntax is `SUBCOMMAND --preflight RECORD --intent INTENT_OR_MANIFEST --operation ENUM -- ARGV...`. A single mutation uses one exact intent. A read phase with several requests first seals an ordered `qinao.network-request-manifest.v1`: every row has a unique sequence/request ID, operation, destination/method/path, exact argv bytes/digest, request-body digest if any, expected capture basenames, maximum uses one, and self-digest. Dynamic IDs discovered by one manifest are never appended to it; a fresh child manifest binds the parent response digest and enumerates the next exact requests. The wrapper hashes the actual argv, requires exactly one still-unconsumed row, locks the ledger, appends/fsyncs its attempt record before execution, and rejects a different/reused/duplicate/unlisted row. Thus one `$HOST_READ_INTENT`-style variable may name a sealed multi-row manifest, not an allocation record and not a wildcard intent.

The executors reopen and validate the selected preflight plus exact intent/manifest, reject environment/executable/stable-projection drift, construct a fresh `env -i` map from the allowlisted projection, and append the child exit/output digests to that row without overwriting its capture. Closed Git operations are `ls-remote`, `fetch-empty`, `fetch-known`, and exact-lease `push`; closed GitHub operations are `auth-read`, `rest-read`, `job-log-read`, `rest-post-pr`, `pr-patch`, `comment-post`, and `merge-put`, each with its exact allowed method/path/headers/canonical input digest. `network-gh` does **not** allow an independent ambient `gh api` credential lookup: it invokes the preflight-bound absolute `gh auth token --hostname github.com` only as a bounded in-memory token resolver, derives the domain-separated token-generation fingerprint, compares it with the selected authenticated permission proof, and then uses those same token bytes in its own fixed-TLS REST/pagination client for the one manifest row before zeroing them. The gh-looking `api --paginate --slurp` argv is therefore an exact manifest syntax, not an independently executed child. The direct client captures and validates **every page's** HTTP status, `Link`, request ID, rate-limit headers, media/version/content type, body shape/digest/size, and termination; a middle-page 401/403/429/5xx, link gap/loop/host change, inconsistent page, or last-page-only success blocks. Poll manifests also contain a fixed `/rate_limit` row rather than inferring rate state from process exit. Only safe projections persist.

All ordinary GitHub operations allow zero redirects. `job-log-read` is the sole closed exception for `GET /repos/ChangGeng01/ProjectSix/actions/jobs/{validated-id}/logs`: its manifest row declares `redirectProfile=github-actions-job-log-v1`; the first authenticated request must return exactly one expected `302` from `api.github.com`. The wrapper parses `Location` only in memory, requires HTTPS/port 443/no userinfo, a label-bound frozen host rule in the versioned workflow contract (`*.actions.githubusercontent.com` or the reviewed `productionresultssa<digits>.blob.core.windows.net` form), public non-reserved DNS addresses with connect/verify bound to the same resolution, and the expected opaque path shape. It records only scheme/host/path digest plus whole-Location digest; signed query/fragment bytes never persist. It then performs exactly one unauthenticated/cookie-free GET—never forwards the GitHub Authorization header—to that URL, accepts no second redirect, streams a bounded response through the log safe-parser/secret scanner, and zeroes the URL. An unrecognized storage host, DNS rebinding/private address, missing/extra redirect, auth forwarding, expired/non-2xx signed URL, or size/scan/parser failure blocks. The signed second URL is an internal child of the one job-log row and is never rendered into a manifest or shell command.

The token never enters argv/environment/disk/stdout; `auth-read` derives its account projection from the same token's `/user` response, while any human-oriented `gh auth status` output is supplemental only. Each new row resolves exactly once and must match the frozen generation; rotation between proof and create/PATCH/comment/merge blocks before the request. The wrapper never chooses an operation, endpoint, permission, or retry; it merely enforces the already persisted one. A mutation intent remains subject to its operation-specific unknown-outcome protocol even if token resolution or transport fails. Unit tests reject a wrong hostname/path/method/header, a redirect outside the job-log profile, missing fetch flag/tip proof, direct `git push`, plain `gh api`, any generic `gh pr` mutation, unbound input, stale preflight, token rotation/scope drift, token in child env/argv/output, a middle-page rate-limit/error masked by final 200, Link gap/loop, malicious/signed/private-host log redirects, authorization forwarding, second log redirect, shell metacharacter-as-data confusion, one row used twice/different argv under one manifest, a dynamic child not bound to its parent response, and any attempt to invoke the absolute executable outside these subcommands.

`quarantine-ref-observe` is a parameterized crash-safe composition used where the plan needs a fresh remote ref inside a shared evidence namespace, especially the post-approval reread. It accepts a ledger/evidence root, repository, preflight, sealed exact advertisement request rows, one literal remote ref plus expected OID, zero or more separately required advertisement invariants, and one previously nonexistent destination evidence ref. It then performs only this fixed chain: fresh scoped advertisement through `network-git`; equality with every required ref/OID; seal of that advertisement capture; fresh `empty-bare-git` resource plus initial snapshot; resource-only `fetch-empty` frontier bound to the advertisement seal path/digest; exact fetched-ref/OID comparison in a second capture; seal of that source-map capture; resource snapshot/completion bound to both seals; shared `snapshot-git-state`; local network-disabled import frontier bound to both seals; exact one-ref/object poststate/completion; and a third sealed canonical observation capture bound to the import terminal. Advertisement/fetch race closes the resource `tainted-preserved` and returns a closed race result; input/attributable-object/exact-poststate recovery is identical to Tasks 11/13/15; foreign shared drift blocks. No capture receives another byte after its seal, and no frontier begins from an unsealed capture.

Its normal and recovery invocations emit one canonical `qinao.quarantine-observe-outcome.v1` with exactly `componentKind`, `componentFrontierId`, `state`, `nextAction`, all applicable resource/capture/seal/terminal IDs and digests, expected/observed ref OIDs, destination ref, and self-digest. Component outcome states are `advertisement-sealed`, `fetch-completed`, `fetch-tainted`, `import-completed`, and `observation-sealed`; `nextAction` is respectively `resume-fetch`, `resume-import`, `allocate-fresh-generation`, `seal-observation`, or `consume-result`. `recover-captures --select-postmerge-main-lineage --expected-R OID --expected-candidate OID` follows explicit predecessor/supersession links and returns exactly `absent`, pre-component `request-incomplete`/`request-sealed`, or one component outcome state. `request-incomplete` exposes only the unique capture ID and typed tainted-predecessor field; `request-sealed` exposes that capture ID, exact seal/manifest paths, destination-ref derivation inputs, and the same typed predecessor field; a component state exposes only its outcome path. For both request states, `--print-field predecessorOutcomeRecordPath` is total and returns exactly literal ASCII `none` for the first lineage or one verified absolute terminal-outcome record path for a successor—never empty, relative, symlinked, or another sentinel. Tests cover first-lineage incomplete/sealed cold starts and reject path/sentinel ambiguity. The selector rejects two live successful lineages, a nonterminal tainted predecessor, two unlinked request generations, or tuple/ref drift. Its `--recover-existing FRONTIER_ID --no-network` mode accepts only one resource-fetch or shared-import component frontier: it locally classifies an unchanged/partial/exact resource as no-effect-tainted/tainted-preserved/completed, or deterministically resumes/reconciles an input-unchanged/attributable-objects-only/exact-poststate shared import from the already sealed resource. It never opens a transport or allocates a new generation in recovery mode.

A terminal `fetch-tainted` outcome can be crossed only by the typed `--supersede-tainted-outcome RECORD` argument. The next request capture allocation and the later `quarantine-ref-observe` invocation must both repeat it. Under the ledger lock, each reopens the terminal outcome and its whole lineage, requires `nextAction=allocate-fresh-generation`, identical tuple/remote ref/expected OID/candidate and no existing successor, and persists the predecessor path plus independently recomputed digest; the second call also requires the sealed request capture to contain that exact predecessor binding. It then admits a new previously nonexistent destination ref/resource generation. A `request-incomplete` generation is never appended or silently abandoned: `allocate-capture --replace-incomplete-capture ID` atomically preserves its exact bytes as forensic-incomplete and creates the one linked replacement, inheriting and revalidating the optional tainted predecessor; when that predecessor exists, the replacement call must repeat `--supersede-tainted-outcome RECORD`. A crash before request allocation leaves `absent`/the tainted predecessor selectable; during request construction yields `request-incomplete`; after capture-seal fsync yields `request-sealed`; after component frontier start resumes that frontier. A sealed request always enters the composition byte-identically and is never replaced. Unlinked/forked successors, two successors for one predecessor, predecessor drift, a live/non-tainted predecessor, or omission of a required typed argument blocks. Tests cover first-generation and repeated-taint request allocation/render/manifest/seal/composition boundaries, including replacement of every incomplete prefix and retention of every older generation as immutable evidence.

`--resume-outcome RECORD --to-terminal` is the only continuation entry. It reopens the entire typed lineage under the ledger lock and performs only the recorded `nextAction`: from `advertisement-sealed`, it may start the one provably never-attempted fetch through the sealed manifest; from `fetch-completed`, it opens/continues only the unique network-disabled import; from `import-completed`, it writes/seals only the pure result capture; `observation-sealed` returns byte-identically; and `fetch-tainted` is rejected so the caller can allocate a new lineage. It advances through at most those three finite transitions and returns after each fsynced outcome, never retries an attempted network operation, chooses a new ref, or hides a component record. After recovery, the caller **must branch on the verified typed outcome**; it is forbidden to call a generic no-open assertion and then unconditionally restart the phase. The composition never cleans/reuses resources, updates an existing ref, negotiates from shared objects, or hides component attempt/frontier records. Tests crash at every boundary—including advertisement seal before attempt, terminal fsync with lost stdout for fetch/import, and import terminal before result seal—and prove the recovered canonical result is byte-equivalent to the uninterrupted path with no phase regression or duplicate terminal generation.

The executors also own bounded `safe-capture`; raw host responses/headers, untrusted mutation **response** bodies, deployment payloads, URLs, and job logs never flow through shell redirection or land on disk. Reviewed canonical request JSON for PR/comment/merge operations is still O_EXCL-persisted and digest-bound by the corresponding intent. While streaming child output in memory, safe-capture computes raw byte count/SHA-256, enforces endpoint/profile bounds, scans secrets/private markers across chunk boundaries, and feeds a strict endpoint/log parser. Wrapper stdout/stderr are themselves only field-allowlisted redacted canonical projections, so a shown shell `>` can never receive raw child bytes. URLs retain only allowed scheme, normalized host, path or path digest, and reject/purge userinfo/query/fragment; the sole job-log redirect profile may consume a signed query in memory under the one-hop rules above but persists only digests/projection. Arbitrary deployment payload/check annotation raw-details/comment bodies receive digest/type/scan projections unless a separately recognized canonical Qinao record requires its already-scanned exact bytes. Job-log capture persists only exact validated `qinao.*-identity`/risk record lines, redacted test counts/status, and the whole-stream digest—never the remaining raw log. An unknown field that could contain credential/private data, signed URL outside that profile, unmasked token, unsafe redirect, scan hit, truncation, or parser uncertainty blocks **before any raw byte is persisted or sent to a reviewer/comment**. Local Git object/source captures remain exact only after the local secret/private egress scanner classifies them as reviewed source.

Tests inject a deployment `payload` token, `temp_clone_token`, signed `details_url`/status `target_url`, hook URL query/userinfo, annotation `raw_details`, comment secret, split-across-chunks credential, and unmasked job-log token; each must block with only a redacted failure disposition persisted. Tests also prove raw response/log temp files are never opened, a safe canonical identity line survives, and a digest/size can be recomputed without retaining the source bytes.

`git-credential-auth-read` closes the otherwise separate Git-transport credential path; a successful `gh auth status` or `gh api` proof can never substitute for it. Under the exact credential-helper identity/config frozen by the selected preflight, it supplies the canonical `protocol=https\nhost=github.com\npath=ChangGeng01/ProjectSix.git\n\n` input to fixed `/usr/bin/git credential fill`, bounds/parses exactly one helper response in memory, rejects redirects/extra hosts/path confusion, and derives a secret-free credential-generation fingerprint over the helper identity plus protocol/host/username and a per-run-domain-separated hash of the password bytes. It then uses those **same in-memory username/password bytes** in a no-redirect TLS client for fixed-header `GET /user` and `GET /repos/ChangGeng01/ProjectSix`, safe-captures only the allowlisted identity/repository-permission/scope projection and raw-stream digests, and zeroes/releases the buffers. For a classic OAuth/PAT response, the same credential's response headers must authoritatively include repository access plus `workflow`; for a fine-grained/App credential, an authoritative permission projection must prove `Contents:write` and `Workflows:write`. Because ordinary fine-grained Git credentials do not expose trustworthy grant introspection through these reads, the normal route classifies them as an external precondition and blocks rather than inferring capability from the owner's repository role. Tests prove that a broad owner role with an under-scoped token fails, that the `gh` token may differ without satisfying Git proof, and that no authorization/header/helper bytes or bare token digest are persisted.

Every later authenticated `network-git` or `lfs-batch-observe` call reruns exactly one helper fill, requires the same credential-generation fingerprint, and uses that exact response—not a second ambient helper lookup—for the child operation. `network-git` passes it to `/usr/bin/git` through a fixed one-shot internal credential broker backed only by an inherited anonymous pipe descriptor: the child gets `credential.helper=` followed by the absolute audited broker subcommand, the secret never enters argv/environment/disk, only `get` is answered, and `store`/`erase` are no-ops with no output. The wrapper owns both pipe ends/lifetime, forbids trace, and proves the broker was consumed only by the expected host/path operation. A helper response rotation/drift, second lookup, prompt, broker reuse, secret in diagnostics, or credential that differs from the authenticated proof invalidates the intent before network execution. The selected credential-generation fingerprint is part of `stableProjectionDigest` and every fetch/LFS/push intent.

`lfs-batch-observe` is the only remote LFS operation in this plan. It is a narrow presence-only standard-library client, not `git lfs push`: after the three local egress reviews, it accepts the exact approved OID/size manifest and the selected preflight, obtains the already-reviewed credential-helper response in memory through fixed `/usr/bin/git credential fill`, and sends one bounded canonical Git LFS Batch `operation="upload"` request to the exact HTTPS Batch endpoint with `transfers=["basic"]` and the exact candidate ref. It uses `ssl.create_default_context`, verified hostname/certificate, direct `http.client.HTTPSConnection`, no proxy, no redirect handler, fixed media headers, fixed timeout/response bound, and zero retry. Credentials, authorization, helper output, response bodies, action header values, and signed query strings are never written or printed.

The strict response parser rejects non-200 and every 3xx, wrong media/schema, duplicate/extra/missing object, changed OID/size, per-object error, unknown transfer, truncation, duplicate JSON key, or noncanonical type. An object with no upload action is `remote-present`. Any `actions.upload` or `actions.verify` marks it `remote-missing`; the client validates HTTPS syntax in memory only to classify/redact, hashes the secret-bearing action object, persists only scheme/normalized host/header-name set plus that digest, and **never opens, follows, resolves, or uploads to its `href`**. The terminal `qinao.lfs-remote-observation.v1` stores request/response byte digests and sizes, exact OID dispositions, preflight/review digests, credential-helper identity digest, redirect count zero, followed-action count zero, and its self-digest. Any missing object blocks this ordinary Git plan before branch push and requires a separately reviewed/user-approved LFS transfer design; there is no hidden `git-lfs` dynamic action-host trust boundary or upload retry here. Tests use an injected local connection adapter to cover TLS/host/request headers, credential redaction, redirect, signed action URLs, malicious headers, duplicate/missing/extra objects, per-object error, bounded reads, transport loss, and proof that no action URL is ever contacted or persisted.

- [ ] **Step 5C: Implement and test the closed network/quarantine/LFS observation boundary**

Implement `network-egress-preflight`, `git-credential-auth-read`, executable `network-git`/`network-gh` sealed invocation enforcement, the composed `quarantine-ref-observe` command, strict advertisement/negotiation-tip validation, empty-quarantine proof, shared `snapshot-git-state`/local-import recovery verification, and `lfs-batch-observe` exactly as specified above. Unit tests never contact a real server: inject `execve`/subprocess/HTTPS adapters and assert exact argv/request bytes, intent/preflight binding, environment scrubbing, independently bound `gh` versus Git credentials, classic scope enforcement, fine-grained unknown-grant blocking, generation rotation rejection, anonymous-pipe broker single consumption, no credential in argv/env/disk/diagnostics, no shared-ref negotiation, no maintenance/submodule/FETCH_HEAD side effect, no redirect/action connection, and secret-free persisted records. For every expanded `fetch-empty`/`fetch-known` kind, remove or alter the frontier's `preflight`/`stableProjectionDigest` and prove `network-git` rejects it before transport; also reject a manifest row bound to a different fresh record despite equal argv. Add the advertise->fetch race fixture: a fetched `main` unequal to the manifest-bound advertised OID must close only as `tainted-preserved`, must never enter the shared repository, and can continue only from a fresh advertisement plus a fresh empty resource. Exercise `quarantine-ref-observe` across every component crash boundary and require byte-identical canonical output versus the expanded primitive sequence. An integration fixture uses two local bare repositories to prove an unrelated private ref in the shared repository is absent from the simulated network fetch negotiation, that only the selected quarantine ref is imported, and that crashes at pre-copy/partial-attributable-objects/exact-ref-before-completion recover to the specified state while foreign/admin drift blocks. Require all focused tests to fail before implementation and pass afterward.

- [ ] **Step 6: Write failing complete plan/spec tree inventory tests**

The capture enumerates every tracked object under both roots, including Markdown and `docs/superpowers/specs/qinao-owner-ledger-v1.json`, using:

```bash
git ls-tree -r -z --full-tree "$C" -- \
  docs/superpowers/plans \
  docs/superpowers/specs
```

It compares the merge-base, `4a`, and `D` maps before trusting `C`: equal sides remain equal; one side equal to merge-base selects the other side; two independently changed values fail. `None` means absent and may represent a real deletion. Tests assert:

```python
def test_inventory_requires_one_disposition_for_every_plan_spec_blob(self):
    captured = module.capture_plan_spec_inventory(repo, source_commit)
    disposition = {
        "docs/superpowers/plans/a.md": disposition_entry("unrelated")
    }
    with self.assertRaisesRegex(module.AuditError, "unclassified"):
        module.bind_dispositions(captured, disposition)

def test_historical_and_unrelated_blobs_must_remain_exact(self):
    with self.assertRaisesRegex(module.AuditError, "blob changed"):
        module.verify_document_transform(
            source=b"alpha\n",
            final=b"alpha changed\n",
            disposition="historical-only",
            pointer=None,
        )
```

Also test an added/deleted path, duplicate disposition, unknown disposition, exact preservation of the non-Markdown owner-ledger JSON, rejection of `supersede` for a non-Markdown blob, a second pointer, pointer placed anywhere except immediately after the first H1 line, and a `supersede` edit beyond the exact inserted bytes.

`documents-lint` accepts only the canonical raw-manifest schema, exact `C/H`, and verified plan/spec inventory. It enumerates every changed Markdown entry, requires strict UTF-8/LF/no BOM, classifies whether bytes are inherited unchanged from `C`, exact-pointer transformed from `C`, or newly authored above `C`, and checks every link introduced above `C` plus the required supersession link against the `H` tree without filesystem/path escape. Inherited historical body links are recorded as inherited rather than reclassified as new changes. It emits positive `enumerated/checked/failed` counts and per-path rule IDs. Fixtures cover missing/extra raw entries, a raw identity file passed instead of a manifest, BOM/CRLF/invalid UTF-8, broken/escaping introduced links, missing or altered pointer, inherited unchanged content, and zero changed documents.

`review-assignment-verify` accepts the canonical raw manifest, the Task 11 assignment object, and the exact identity object. It requires the same manifest digest/entry IDs, review-configuration blob, `(B,H,T,V)`, nonempty allowed partition list for every entry, no unknown/duplicate/extra row, and complete binary/LFS/document dispositions; it emits typed static counts. It never generates an assignment itself.

- [ ] **Step 7: Implement exact document transformation verification**

Define:

```python
DISPOSITIONS = ("supersede", "historical-only", "unrelated")

def expected_final_bytes(
    source: bytes,
    disposition: str,
    pointer_utf8: Optional[bytes],
) -> bytes:
    if disposition in ("historical-only", "unrelated"):
        if pointer_utf8 is not None:
            raise AuditError("unchanged disposition cannot carry a pointer")
        return source
    if pointer_utf8 is None:
        raise AuditError("supersede disposition requires its exact pointer")
    return insert_after_first_h1(source, pointer_utf8)
```

`insert_after_first_h1` requires strict UTF-8 without BOM, LF newlines, exactly one first-line Markdown H1, and no existing forward-status marker. It inserts one blank line, the prescribed pointer, and one blank line; all other bytes are copied exactly. Compute expected Git blob OIDs with `git hash-object --stdin` without `-w`.

- [ ] **Step 8: Run all audit tests**

Run:

```bash
qinao_python -m unittest -v scripts.test_qinao_convergence_audit
```

Expected: a nonzero discovered test count and `OK`.

- [ ] **Step 9: Verify the real `C` and commit**

Run the `topology`, `protected`, and `documents-capture` subcommands against the convergence worktree. Confirm the capture includes this plan from `D` and all tracked plan/spec objects from both source histories.

```bash
git add scripts/qinao_convergence_audit.py scripts/test_qinao_convergence_audit.py
git commit --no-verify --no-gpg-sign -m "feat: add read-only Qinao convergence audit"
```

Expected: one focused audit commit above the already committed ledger bootstrap, with both Task 3 commits descended from `C`. Append the Task 3 remainder completion frontier and verify it from a fresh process.

### Task 4: Freeze the complete `C→H` plan/spec disposition and apply one exact forward pointer

**Files:**
- Create: `docs/superpowers/validation/qinao-plan-spec-disposition.v1.json`
- Create: `docs/superpowers/evidence/2026-08-29-qinao-plan-spec-inventory.v1.json`
- Modify: only inventory entries whose disposition is `supersede`
- Test: `scripts/test_qinao_convergence_audit.py`

**Interfaces:**
- Consumes: `capture_plan_spec_inventory(repository, C)` from Task 3.
- Produces: one complete source/final mapping and exact expected final blob for every tracked plan/spec path at `C`.

- [ ] **Step 1: Re-capture the actual `C` set before authoring the seed**

Run the audit CLI and require exactly one entry for every tracked object under both roots. Current trees predict 46 paths after this plan enters `D`—45 Markdown plus one JSON—but this count is only a drift alarm. The actual NUL-safe `C` enumeration and three-way object map are authoritative.

Expected: no duplicate path/blob and no unclassified path.

- [ ] **Step 2: Author the closed disposition seed**

Use this schema for every actual path:

```json
{
  "schemaVersion": "qinao.plan-spec-disposition.v1",
  "supersedingPath": "docs/superpowers/specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md",
  "entries": [
    {
      "path": "docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md",
      "disposition": "supersede",
      "reviewReason": "Contains forward development-control gates retired by the approved single-owner Git route and has no pre-existing historical-only marker.",
      "permittedTransformation": "insert-qinao-git-only-forward-pointer-v1"
    }
  ]
}
```

The file contains one entry for every actual plan/spec path at `C`, sorted by raw path bytes. There is no implementation-time classification discretion. The predicted 46-path set is closed by the following exact groups; the capture must match these 46 raw paths exactly or stop before any document edit:

- `unrelated` (17): all seven `docs/superpowers/plans/2026-04-*.md`; all eight `docs/superpowers/specs/2026-04-*.md`; the approved `2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md` with reason `current-policy`; and this implementation plan with reason `current-reviewed-plan`. These blobs remain exact.
- `historical-only` (12): the seven exact `4a` Markdown blobs already carrying the `SUPERSEDED_HISTORICAL` marker—`plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md` and all six `plans/2026-07-23-qinao-*.md`—plus `plans/2026-08-24-qinao-p0-execution-containment.md`, `plans/2026-08-29-qinao-a03-source-identity-freeze-and-authority-gate.md`, `specs/2026-08-24-qinao-p0-execution-containment-design.md`, `specs/2026-08-28-qinao-recovery-spine-and-deep-scan-closure-design.md`, and `specs/qinao-owner-ledger-v1.json`. These are already explicitly historical or completed/non-authoritative recovery, containment, A0/DS3, or ownership evidence; they remain byte-identical and never receive a second forward-status pointer. The seed records and tests bind the exact source marker bytes for the seven pre-marked Markdown blobs. The owner-ledger must retain `C` blob `64834006f035a21300d64d0fc41b945f75b10c52` and cannot receive a pointer.
- `supersede` (17): all six `plans/2026-07-15-iphone-air-*.md`, `plans/2026-07-29-qinao-dual-space-automation-controlled-convergence.md` (whose source marker is `ACTIVE_TASKS_0_2_ANNEX`, not `SUPERSEDED_HISTORICAL`), and every spec from `specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md` through `specs/2026-08-10-qinao-global-invariant-firewall-and-recovery-design.md` in the captured set (ten exact paths: 07-14, 07-17, 07-19, 07-22, both 07-23, 07-24, 07-29, 08-02, 08-10). These have no pre-existing historical-only marker. Their product/runtime content remains evidence and may remain a target; the sole inserted pointer retires only their conflicting forward development-control gates.

The seed test expands these groups to literal raw-path records, asserts the group counts `17/12/17`, requires union size 46, rejects overlap, and compares the literal union to the NUL-safe `C` capture. It additionally proves that every source blob already containing `SUPERSEDED_HISTORICAL` is `historical-only`, that none receives the new marker, and that `ACTIVE_TASKS_0_2_ANNEX` is not mistaken for a historical-only marker. A count match with a different path is failure. Keyword review remains a diagnostic that must not change this frozen table.

- [ ] **Step 3: Use the exact pointer text**

For a plan file, insert this block immediately after its H1:

```markdown
> **Forward development status (2026-08-29):** Superseded by [Qinao single-developer Git and lightweight PR design](../specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md). External authority closure was never completed, and no historical authority is retroactively claimed. The single developer selected ordinary Git plus lightweight PR review; former source-admission, controlled-document, signer/trust-root, controller/CAS, authority-receipt, registry, and quorum gates are retired for forward development. Historical facts and hashes remain evidence; a historical non-authority limitation remains a forward gate only when the superseding design explicitly restates it.
```

For a spec file, use the identical text with this relative link:

```markdown
[Qinao single-developer Git and lightweight PR design](2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md)
```

No other byte in a superseded document changes.

- [ ] **Step 4: Write the failing real-inventory test**

Add a test that loads the seed, captures `C`, and fails until every expected transformed file has its exact final bytes. It must additionally assert that the old fixed 18-path set is not a completeness boundary and that all six `2026-07-15-iphone-air-*.md` plans receive explicit reviewed dispositions.

- [ ] **Step 5: Run the test and confirm it fails**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_convergence_audit.RepositoryDocumentInventoryTests
```

Expected: failure listing missing pointers/final blobs, never a generic count mismatch.

- [ ] **Step 6: Apply only the generated exact transforms**

Use the audit module to render a patch or expected bytes, inspect every hunk, and apply those bytes with `apply_patch`. Do not let the module write arbitrary repository paths. Re-run `git diff --word-diff=porcelain` and require that every changed plan/spec hunk is the one pointer block.

- [ ] **Step 7: Generate and verify the final inventory**

Each record has exactly:

```json
{
  "pathB64": "ZG9jcy9zdXBlcnBvd2Vycy9wbGFucy8yMDI2LTA3LTE1LWlwaG9uZS1haXItYXJjaGl0ZWN0dXJlLWNvbnZlcmdlbmNlLW1hc3Rlci5tZA==",
  "displayPath": "docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md",
  "sourceMode": "100644",
  "sourceType": "blob",
  "sourceBlobOid": "40 lowercase hex",
  "sourceSha256": "64 lowercase hex",
  "mergeBaseObject": {"mode": null, "type": null, "oid": null},
  "parent1Object": {"mode": "100644", "type": "blob", "oid": "40 lowercase hex"},
  "parent2Object": {"mode": null, "type": null, "oid": null},
  "disposition": "supersede",
  "reasonCode": "forward-development-control",
  "reviewReason": "exact reviewed reason",
  "sourceLineEvidence": ["exact source line or byte-span digest"],
  "permittedTransformation": "insert-qinao-git-only-forward-pointer-v1",
  "expectedFinalPathB64": "same canonical padded base64 path",
  "expectedFinalMode": "100644",
  "expectedFinalType": "blob",
  "expectedFinalBlobOid": "40 lowercase hex",
  "expectedFinalSha256": "64 lowercase hex"
}
```

Paths use canonical padded base64 of the raw Git path for identity; `displayPath` is diagnostic only. The root record stores `C`, `C^{tree}`, merge-base/`4a`/`D` identities and trees, `S`/spec blob, derived entry count, source-path-list SHA-256, expected-final-path-list SHA-256, source-records SHA-256, expected-final-records SHA-256, pointer-transform ID, and pointer-bytes SHA-256. It deliberately does not embed `H`, because that would be self-referential. Task 11 emits the observed `H` binding externally and rejects any changed object.

- [ ] **Step 8: Run tests and commit**

```bash
qinao_python -m unittest -v scripts.test_qinao_convergence_audit
git diff --check
git add \
  docs/superpowers/validation/qinao-plan-spec-disposition.v1.json \
  docs/superpowers/evidence/2026-08-29-qinao-plan-spec-inventory.v1.json \
  docs/superpowers/plans \
  docs/superpowers/specs \
  scripts/test_qinao_convergence_audit.py
git commit --no-verify --no-gpg-sign -m "docs: supersede former Qinao development-control plans"
```

Expected: only the disposition/inventory, the audit test, and exact authorized pointer insertions are committed.

### Task 5: Implement closed PR metadata and structural risk classification

**Files:**
- Create: `scripts/qinao_pr_protocol.py`
- Create: `scripts/test_qinao_pr_protocol.py`

**Interfaces:**
- Consumes: `RawDiffEntry` values from `qinao_convergence_audit.py`, exact PR-body bytes, and `CandidateIdentity`.
- Produces: `parse_pr_metadata(body_utf8)`, `classify_risk(entries, raw_bytes)`, `validate_identity(identity)`, `validate_merge_intent(identity, intent, initial_convergence)`, and CLI subcommands `render-metadata` plus `validate-event-metadata`.

- [ ] **Step 1: Write failing PR metadata tests**

The body contains exactly one machine block:

```text
<!-- qinao-pr-metadata:v1:start -->
{"changedSurfaces":["workflow","python-policy"],"findingDispositions":[],"forwardRecovery":"Open a new repair PR from fresh remote main; do not edit main directly.","irreversibleEffects":[],"knownLimitations":["iOS 27 product-floor migration remains separate and nonconforming."],"outcome":"Converge preserved histories and replace active admission control with ordinary Git plus manual PR review.","riskDeclared":"high","rollback":"Use a reviewed revert PR against the verified merge commit.","schemaVersion":"qinao.pr-metadata.v1"}
<!-- qinao-pr-metadata:v1:end -->
```

Tests cover:

```python
def test_metadata_accepts_one_closed_canonical_block(self):
    parsed = module.parse_pr_metadata(VALID_BODY.encode("utf-8"))
    self.assertEqual(parsed.risk_declared, "high")
    self.assertEqual(parsed.changed_surfaces, ("workflow", "python-policy"))

def test_metadata_rejects_duplicate_markers_or_reversed_markers(self):
    with self.assertRaises(module.ProtocolError):
        module.parse_pr_metadata((VALID_BODY + VALID_BODY).encode("utf-8"))

def test_metadata_rejects_unknown_key_duplicate_json_key_or_float(self):
    for body in (BODY_WITH_UNKNOWN, BODY_WITH_DUPLICATE, BODY_WITH_FLOAT):
        with self.subTest(body=body):
            with self.assertRaises(module.ProtocolError):
                module.parse_pr_metadata(body.encode("utf-8"))
```

Also reject a BOM, CRLF, invalid UTF-8, more than 65,536 UTF-8 bytes, blank required strings, control characters, unsorted/duplicate surfaces, unknown surface, risk other than `routine/high`, and any approval/authorization/merge-token field.

- [ ] **Step 2: Run metadata tests and confirm failure**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_pr_protocol.MetadataTests
```

Expected: import or attribute failure.

- [ ] **Step 3: Implement the exact body parser**

Use byte offsets, not line counts:

```python
START = b"<!-- qinao-pr-metadata:v1:start -->\n"
END = b"\n<!-- qinao-pr-metadata:v1:end -->"
METADATA_KEYS = (
    "schemaVersion",
    "outcome",
    "riskDeclared",
    "changedSurfaces",
    "findingDispositions",
    "knownLimitations",
    "rollback",
    "forwardRecovery",
    "irreversibleEffects",
)

def parse_pr_metadata(body_utf8: bytes) -> PRMetadata:
    if body_utf8.startswith(b"\xef\xbb\xbf") or b"\r" in body_utf8:
        raise ProtocolError("PR body must be UTF-8/LF without BOM")
    if len(body_utf8) == 0 or len(body_utf8) > 65536:
        raise ProtocolError("PR body byte length is outside the closed range")
    if body_utf8.count(START) != 1 or body_utf8.count(END) != 1:
        raise ProtocolError("PR metadata markers must occur exactly once")
    start = body_utf8.index(START) + len(START)
    end = body_utf8.index(END)
    if start >= end:
        raise ProtocolError("PR metadata markers are reversed or empty")
    value = strict_json_loads(body_utf8[start:end])
    require_exact_keys(value, METADATA_KEYS)
    return metadata_from_json(value)
```

`strict_json_loads` decodes strict UTF-8, uses `object_pairs_hook` to reject duplicates, `parse_float` to raise, validates integers within `[-9007199254740991,9007199254740991]`, and recursively rejects lone surrogate code points.

`findingDispositions` is an ordered array sorted by stable finding ID. Each item has exactly `id`, `state`, `severity`, and `evidenceSha256`; `state ∈ {"fixed","false-positive","disputed-impact","incomplete"}` and severity uses the closed review enum. Empty means no findings have yet been reported. `incomplete` blocks progress. `disputed-impact` is always effective high risk and is not resolved until Task 14 presents that exact finding/evidence to the user and records the user's explicit disposition; a confirmed actionable finding cannot be recoded or waived. The final body list must equal the union of all specialist/integration finding IDs and their terminal dispositions.

`render-metadata --input "$PR_METADATA_INPUT"` emits the exact markers and canonical JSON block. `validate-event-metadata --event-path "$GITHUB_EVENT_PATH"` requires an ordinary regular event file, reads `pull_request.body` as data, calls `parse_pr_metadata`, and emits only the body SHA-256 plus the declared risk and finding-disposition digest. It does **not** claim effective risk because it does not receive the structured raw diff; Task 11 computes effective risk from the complete raw entries. Neither subcommand performs network I/O.

- [ ] **Step 4: Write failing structured-risk tests**

Test every non-path signal that the old draft lost:

```python
def test_mode_type_and_gitattributes_are_high_risk(self):
    cases = (
        entry("100644", "100755", "M", b"docs/readme.md"),
        entry("100644", "120000", "T", b"docs/readme.md"),
        entry("000000", "100644", "A", b".gitattributes"),
    )
    for value in cases:
        with self.subTest(value=value):
            decision = module.classify_risk((value,), b"raw")
            self.assertEqual(decision.risk, "high")

def test_rename_copy_unmerged_binary_and_unknown_are_high_risk(self):
    for status in ("R100", "C100", "U", "X"):
        decision = module.classify_risk(
            (entry("100644", "100644", status, b"ordinary.txt"),),
            status.encode("ascii"),
        )
        self.assertEqual(decision.risk, "high")
```

Include workflow/action, scripts, Git config, dependency/lockfile, Swift/Rust/Python source, tests, schema, persistence, CloudKit/iCloud/Keychain/privacy/encryption/entitlement, recovery/snapshot, DS3, generated/vendor/binary, LFS pointer, deleted protected path, and raw control-byte path cases. A routine case is limited to ordinary Markdown/text/image documentation with unchanged regular-file mode and known suffix.

- [ ] **Step 5: Implement monotonic risk classification**

Define stable reason codes, sorted lexicographically:

```python
HIGH_PATH_PREFIXES = (
    b".github/",
    b".githooks/",
    b"scripts/",
    b"BehavioralAISubstrate/",
    b"QinaoRuntimeSDK/",
    b"SampleHost/",
)
HIGH_BASENAMES = (
    b".gitattributes",
    b".gitignore",
    b"Package.swift",
    b"Package.resolved",
    b"Cargo.toml",
    b"Cargo.lock",
    b"project.yml",
)
ROUTINE_SUFFIXES = (
    b".md",
    b".txt",
    b".png",
    b".jpg",
    b".jpeg",
    b".gif",
)
```

For each entry, classify both old and new raw paths, modes, object IDs, type, status, and extension. Deletions, additions under control prefixes, any old/new mode difference, `120000`, `160000`, a zero OID in an unexpected position, non-UTF-8/control bytes, and unrecognized data are high. Inspect candidate blobs with `git cat-file --batch` outside this pure module and pass the observations in; binary or LFS pointer content is high.

The declared body risk can increase but never decrease computed risk:

```python
def effective_risk(computed: RiskDecision, declared: str) -> str:
    if declared == "high" or computed.risk == "high":
        return "high"
    return "routine"
```

- [ ] **Step 6: Write and implement identity/merge-intent tests**

Require current repository object-format-length OIDs, lowercase hex, distinct semantic fields, `P=[B,H]` for initial convergence, `P=[B]` for squash, and no rebase mode.

```python
def validate_merge_intent(
    identity: CandidateIdentity,
    intent: MergeIntent,
    initial_convergence: bool,
) -> None:
    expected_mode = "merge" if initial_convergence else "squash"
    expected_parents = (
        (identity.base_oid, identity.head_oid)
        if initial_convergence else (identity.base_oid,)
    )
    if intent.mode != expected_mode or intent.parent_oids != expected_parents:
        raise ProtocolError("merge intent does not match the closed policy")
```

Tests explicitly prove a tree OID is never accepted as `H` by checking object type in the convergence audit call site.

- [ ] **Step 7: Run focused tests and commit**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_pr_protocol.MetadataTests \
  scripts.test_qinao_pr_protocol.RiskTests \
  scripts.test_qinao_pr_protocol.IdentityTests
git add scripts/qinao_pr_protocol.py scripts/test_qinao_pr_protocol.py
git commit --no-verify --no-gpg-sign -m "feat: define lightweight PR metadata and risk protocol"
```

Expected: nonzero tests, `OK`, one focused commit.

### Task 6: Implement RFC 8785 evidence, deterministic timeline records, and operation recovery

**Files:**
- Modify: `scripts/qinao_pr_protocol.py`
- Modify: `scripts/test_qinao_pr_protocol.py`
- Create: `docs/superpowers/schemas/qinao-pr-evidence.v1.json`

**Interfaces:**
- Consumes: closed JSON values, `CandidateIdentity`, `MergeIntent`, risk, validation, review, automation, and remote observations.
- Produces: `jcs_bytes(value)`, `policy_revision(inputs)`, `final_evidence(payload)`, `chunk_final_evidence(record)`, `render_approval_audit(decision)`, pure `recover_*_outcome` functions, and CLI subcommands `policy-revision`, `build-final-evidence`, `chunk-final-evidence`, `verify-final-evidence`, `verify-final-evidence-observation`, `render-metadata`, `validate-event-metadata`, `render-approval-audit`, `render-pr-create-request`, `render-pr-patch-request`, `render-merge-request`, `render-comment-request`, `verify-comment-observation`, `normalize-merge-observation`, `classify-merge-recovery`, and `init-evidence-root`. The four request renderers write only their closed canonical schemas via O_EXCL (`PR create`, body-only `PATCH`, `{"merge_method":"merge","sha":H}`, and body-only comment respectively), then reopen and print their self-excluding request digest; arbitrary JSON or extra fields are rejected. `verify-comment-observation` is a pure output-O_EXCL normalizer: it reopens the unique attempt record, parses one complete safe paginated comment projection, emits the closed recovery result plus an exact self-including capture whitelist, and never reads transport state from an ambient variable. `normalize-merge-observation` is a pure bounded reader of one validated scoped advertisement plus safe PR/commit/complete-comment projections. It reopens the original merge intent, verifies exact request/audit/actor/tuple and pagination, emits one canonical observation plus an exact LF-delimited capture whitelist, and supports `--verify ... --print-field resultOid`; it performs no network or mutation. `classify-merge-recovery` is read-only: it reopens that normalized record only through its sealed capture plus the same `remote-merge-put` start and prints the canonical closed classification for tests/debugging without writing a file. Production completion calls the same pure function inside Task 3's atomic `frontier-complete --classify-merge-recovery-from-observation`, so no second capture or mutable handoff exists. `init-evidence-root` registers the evidence schema/root through Task 3's already committed ledger API; this module does not implement a second allocator, capture sealer, recovery log, or frontier store.

- [ ] **Step 1: Write failing RFC 8785 subset tests**

The accepted JSON domain is `null`, booleans, safe integers, valid Unicode strings, arrays, and string-keyed objects. Floats are forbidden by the evidence schema.

```python
def test_jcs_orders_object_keys_by_utf16_code_units(self):
    value = {"\U0001f600": 1, "\ufffd": 2, "a": 3}
    self.assertEqual(
        module.jcs_bytes(value),
        b'{"a":3,"\xf0\x9f\x98\x80":1,"\xef\xbf\xbd":2}',
    )

def test_jcs_uses_short_control_escapes_and_lowercase_unicode_escape(self):
    value = {"s": "\b\t\n\f\r\x00\"\\"}
    self.assertEqual(
        module.jcs_bytes(value),
        b'{"s":"\\b\\t\\n\\f\\r\\u0000\\\"\\\\"}',
    )

def test_jcs_rejects_float_unsafe_integer_and_lone_surrogate(self):
    for value in (1.0, 9007199254740992, "\ud800"):
        with self.subTest(value=repr(value)):
            with self.assertRaises(module.CanonicalizationError):
                module.jcs_bytes(value)
```

Also cover negative safe integers, `None`, `False`, slash not escaped, U+2028/U+2029 preserved as UTF-8, nested arrays, non-string keys, duplicate-key JSON input, and canonical round-trip equality.

- [ ] **Step 2: Run JCS tests and confirm failure**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_pr_protocol.JCSTests
```

Expected: missing `jcs_bytes`.

- [ ] **Step 3: Implement canonicalization without `json.dumps` key ordering**

Use UTF-16BE bytes for key ordering after rejecting surrogates:

```python
def _key_order(value: str) -> bytes:
    _validate_unicode(value)
    return value.encode("utf-16-be")

def _quote(value: str) -> bytes:
    _validate_unicode(value)
    out = bytearray(b'"')
    short = {
        0x08: b"\\b",
        0x09: b"\\t",
        0x0A: b"\\n",
        0x0C: b"\\f",
        0x0D: b"\\r",
    }
    for character in value:
        point = ord(character)
        if point == 0x22:
            out.extend(b'\\"')
        elif point == 0x5C:
            out.extend(b"\\\\")
        elif point in short:
            out.extend(short[point])
        elif point <= 0x1F:
            out.extend(("\\u%04x" % point).encode("ascii"))
        else:
            out.extend(character.encode("utf-8"))
    out.extend(b'"')
    return bytes(out)
```

`jcs_bytes` emits no whitespace, sorts object keys with `_key_order`, preserves array order, emits lowercase `true/false/null`, and emits safe integers with ASCII decimal. It detects recursive containers by object identity and raises.

- [ ] **Step 4: Define the closed evidence schema**

`docs/superpowers/schemas/qinao-pr-evidence.v1.json` is itself canonical JSON and contains exact field lists for:

- `qinao.policy-revision.v1`;
- `qinao.cargo-archive-union.v1`;
- `qinao.cargo-vendor-manifest.v1`;
- `qinao.ci-identity.v1`;
- `qinao.ci-push-identity.v1`;
- `qinao.ci-supplemental-identity.v1`;
- `qinao.risk-result.v1`;
- `qinao.validation-result.v1`;
- `qinao.automation-inventory.v1`;
- `qinao.postmerge-automation-inventory.v1`;
- `qinao.review-result.v1`;
- `qinao.raw-diff-assignment.v1`;
- `qinao.network-egress.v1`;
- `qinao.public-crate-egress.v1`;
- `qinao.remote-object-disclosure.v1`;
- `qinao.egress-review.v1`;
- `qinao.lfs-remote-observation.v1`;
- `qinao.final-evidence.v1`;
- `qinao.final-evidence-manifest.v1`;
- `qinao.final-evidence-chunk.v1`;
- `qinao.approval-audit.v1`;
- `qinao.post-merge-verification.v1`.

The final-evidence payload has exactly:

```json
{
  "schemaVersion": "qinao.final-evidence.v1",
  "evidenceSequence": 1,
  "supersedesManifestDigest": null,
  "prNumber": 1,
  "prBodySha256": "64 lowercase hex",
  "sourceConvergence": {
    "S": "spec commit oid",
    "STree": "spec tree oid",
    "specBlob": "spec blob oid",
    "D": "design tip oid",
    "DTree": "design tree oid",
    "requiredDesignAncestor": "5c87355 commit oid",
    "C": "local convergence oid",
    "CTree": "local convergence tree oid",
    "CParents": ["4a preservation oid", "D oid"]
  },
  "identity": {"B": "oid", "H": "oid", "T": "tree oid", "V": "64 lowercase hex"},
  "mergeIntent": {"M": "merge", "P": ["B oid", "H oid"]},
  "automation": {"schemaVersion": "qinao.automation-inventory.v1", "A": "64 lowercase hex", "observationEvidenceSha256": "64 lowercase hex"},
  "interactiveActor": {"login": "frozen login", "id": 1, "responseSha256": "64 lowercase hex"},
  "networkEgress": {"preflightSha256": "64 lowercase hex", "gitEndpoint": "exact reviewed HTTPS URL", "lfsBatchEndpoint": "exact reviewed HTTPS URL"},
  "diff": {"rawSha256": "64 lowercase hex", "entryCount": 1, "manifestSha256": "64 lowercase hex"},
  "remoteObjectDisclosure": {"advertisementSha256": "64 lowercase hex", "objectManifestSha256": "64 lowercase hex", "lfsLocalManifestSha256": "64 lowercase hex", "lfsRemoteObservationSha256": "64 lowercase hex", "egressReviewSha256": ["three ordered 64 lowercase digests"]},
  "documentInventory": {"sourceSha256": "64 lowercase hex", "expectedFinalSha256": "64 lowercase hex", "observedFinalSha256": "64 lowercase hex"},
  "protectedState": {"beforeSha256": "64 lowercase hex", "preMergeSha256": "64 lowercase hex"},
  "risk": {"class": "high", "reasonCodes": ["workflow-change"]},
  "validation": [],
  "review": {},
  "externalEvidence": [],
  "knownLimitations": [],
  "blastRadius": ["repository history, CI workflow, PR process, and preserved LFS-visible source objects"],
  "rollback": "reviewed revert PR",
  "forwardRecovery": "fresh repair PR",
  "irreversibleEffects": [],
  "separateEffectAuthorization": "absent",
  "hostObservation": {"draft": false, "mergeable": "MERGEABLE", "autoMerge": false}
}
```

The illustrative values above are type examples; tests build complete fixtures with internally matching OIDs/digests. Field order in source files is for readability; JCS determines canonical bytes.

The four pre-push/remote-boundary supporting record types are closed as follows:

- `qinao.raw-diff-assignment.v1` has exactly `schemaVersion`, identity `(B,H,T,V)`, review-configuration blob OID, raw-manifest SHA-256, sorted nonempty assignment rows `{entryId,pathB64,status,partitionIds}`, and self-excluding `assignmentDigest`.
- `qinao.remote-object-disclosure.v1` has exactly `schemaVersion`, `H`, remote-advertisement/fetched-ref/revision-input/OID/type-size digests, sorted negative tips, typed object records, full commit/tag raw-object header/field records, blob path-reachability records, pure-local LFS records plus `lfsLocalManifestSha256`, scanner schema/rule IDs, terminal dispositions, counts, limitations, and self-excluding `objectManifestDigest`. Every object/path/header byte/LFS pointer from the captured closure occurs exactly once in its relevant index and every terminal content disposition is `approved-source`.
- `qinao.egress-review.v1` has exactly `schemaVersion`, stable review ID in `{history-object-completeness,privacy-lfs-egress,integration}`, identity `{H,advertisementSha256,objectManifestSha256,lfsLocalManifestSha256}`, ordered input-report digests (empty for specialists, exactly two for integration), covered object/disposition IDs, terminal state, closed findings, and self-excluding `reviewDigest`.
- `qinao.lfs-remote-observation.v1` has exactly `schemaVersion`, `H`, approved OID/size/path-manifest digest, local-LFS-manifest digest, the three ordered egress-review digests, one immutable presence-capture ID, canonical request/response byte digests and sizes, credential-helper/preflight identity digests, sorted per-OID `remote-present|remote-missing` dispositions, `redirectCount=0`, `followedActionCount=0`, `uploadAttempted=false`, terminal state in `remote-satisfied|remote-missing|indeterminate`, `irreversibleEffect=false`, and self-excluding `lfsRemoteObservationSha256`. An empty approved set still emits one terminal zero-request record; only `remote-satisfied` can enter `E`. Missing/unknown OIDs, a capture collision, any action connection, or a nonterminal parser result blocks before Git push.

Unknown fields, duplicate IDs, an unordered set-like array, a missing digest binding, a nonterminal/incomplete finding, or a self-digest included in its own hash input fails. Fixtures exercise each rejection and prove that the integration report covers the exact union of both specialist reports and the disclosure manifest.

The `qinao.policy-revision.v1` input path set is exact and sorted by raw UTF-8 path bytes:

```text
.github/pull_request_template.md
.github/workflows/test.yml
BehavioralAISubstrate/Cargo/.cargo/config.toml
BehavioralAISubstrate/Cargo/Cargo.lock
docs/superpowers/evidence/2026-08-29-qinao-cargo-vendor-manifest.v1.json
docs/superpowers/evidence/2026-08-29-qinao-plan-spec-inventory.v1.json
docs/superpowers/evidence/2026-08-29-qinao-pr-review-configuration.v1.json
docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json
docs/superpowers/schemas/qinao-pr-evidence.v1.json
docs/superpowers/validation/qinao-full-suite-skip-baseline.v1.json
docs/superpowers/validation/qinao-plan-spec-disposition.v1.json
docs/superpowers/validation/qinao-pr-validation-matrix.v1.json
scripts/check_chenglu_schema_parity.py
scripts/check_god_files.sh
scripts/check_qinao_import_boundaries.sh
scripts/check_sdk_import_boundaries.sh
scripts/check_sovereign_redaction.py
scripts/check_sovereign_redaction.sh
scripts/check_substrate_residual_markers.sh
scripts/check_substrate_residuals.sh
scripts/chenglu_feature_schema.py
scripts/qinao_convergence_audit.py
scripts/qinao_pr_protocol.py
scripts/qinao_pr_validation.py
scripts/qinao_workflow_inventory.py
```

For each of these exact twenty-five paths, `policy_revision` consumes exact mode/type/blob OID from `H`, not working bytes. Missing, extra, duplicate, non-blob, wrong mode, or a path-list change fails. The resulting canonical object stores every sorted `(path,mode,type,blobOid)` tuple plus its own schema version; `V` hashes it. The Cargo vendor manifest additionally binds the exact sorted Git blob/SHA-256/size/mode tuple for every tracked `BehavioralAISubstrate/Cargo/vendor/**` file and the lock/config blobs, and the validator reopens that complete transitive closure from `H`; a self-consistent manifest that omits an actual vendor path or names a nonexistent one still fails. The matrix's closed boundary graph separately binds every entry/delegate edge and its enumerated input-tree projection at `H`; those product/input blobs remain candidate state bound by `H`, while every executable repository script in that graph is one of the direct policy paths above. Because the audit, workflow-contract, Cargo source configuration, lock, vendor-manifest, and boundary-executable blobs are in this closed set, `V` transitively binds the local/CI sterile launcher source, exact CI prefix/template, closed loader, module rules, matrix reserved-operation semantics, and offline Rust dependency closure. Machine-specific interpreter/stdlib/OpenSSL/default-CA executable projections are deliberately not hidden inside portable `V`; the local immutable identity, every validation result, network preflight, and every CI identity record bind their observed projection separately, and incompatible projections are evidence failure. Task 3 `ci-bind` imports this constant and this function, so local and every PR job use the same implementation and inputs.

- [ ] **Step 5: Write failing `V` and `E` self-exclusion tests**

```python
def test_policy_revision_binds_sorted_path_blob_pairs(self):
    inputs = (
        ("scripts/qinao_pr_protocol.py", "1" * 40),
        ("docs/superpowers/validation/qinao-pr-validation-matrix.v1.json", "2" * 40),
    )
    first = module.policy_revision(inputs)
    self.assertEqual(first, module.policy_revision(tuple(reversed(inputs))))

def test_e_hashes_payload_without_its_own_digest_field(self):
    payload = complete_evidence_payload()
    record = module.final_evidence(payload)
    self.assertNotIn("evidenceDigest", payload)
    self.assertEqual(
        record["evidenceDigest"],
        hashlib.sha256(module.jcs_bytes(payload)).hexdigest(),
    )
    self.assertEqual(
        module.verify_final_evidence(record),
        payload,
    )
```

Reject duplicate policy paths, unbound required policy file, an `E` payload already containing `evidenceDigest`, a result bound to a different `(B,H,T,V)`, external evidence without URI/digest, unknown limitation fields, and a host observation with `autoMerge=true`.
Add a non-illustrative constant test that requires the literal raw-byte-sorted `POLICY_PATHS` tuple above, `len(POLICY_PATHS) == 25`, and exact set equality. Fixture one-byte changes to every direct blob, any vendor-manifest tuple, any boundary node/edge/input projection, Cargo lock/config, and the matrix must all change or invalidate `V`; the number thirteen is reserved only for validation target count.

- [ ] **Step 6: Implement deterministic timeline chunks**

Split the complete canonical record at valid Unicode-scalar boundaries into consecutive segments whose original UTF-8 length is at most 20,000 bytes. Each comment carries one canonical JSON envelope with `schemaVersion`, positive `evidenceSequence`, `recordDigest`, one-based `index`, `total`, `encoding="utf-8-json-text-segment"`, `payloadUtf8`, `payloadByteLength`, and `chunkDigest` computed from the original segment bytes; the envelope's own `chunkRecordDigest` is computed with that field omitted. Because the source is already canonical JSON text, wrapping it as a JSON string stays safely below the host comment limit at this bound. The manifest contains the same sequence, `supersedesManifestDigest` (`null` for sequence 1, otherwise the immediately prior complete manifest digest), ordered chunk/payload digests, canonical-record byte length, canonical-record SHA-256, `E`, and its own digest computed with `manifestDigest` omitted.

Tests reconstruct the canonical record by UTF-8 encoding and concatenating `payloadUtf8` in manifest order, then reject a split inside a Unicode scalar, missing, duplicate, reordered, oversized, altered, extra, or noncanonical envelope. Comment IDs, URLs, timestamps, and storage order are not hash inputs. The complete timeline may contain older immutable evidence generations after a review-fix or recovery cycle. Verification requires complete sequences to be unique and contiguous, each non-first manifest to name the prior complete manifest digest, every older generation to remain byte-identical, and exactly one latest complete generation to match the current tuple. It never requires there to be only one manifest across the lifetime of the PR.

Because chunks precede their manifest, the parser has one explicit interruption state: at most one **staging generation** at `maxCompleteSequence+1`, containing no manifest and a strict, duplicate-free prefix of chunks `1...k` whose bodies/record/chunk digests exactly match the canonical record persisted in one digest-valid local evidence root. A staging generation is not counted in the complete chain or used as `supersedesManifestDigest`. Recovery may skip its exact existing prefix and post only chunk `k+1`, subsequent chunks, then the manifest. A gap, non-prefix, duplicate, conflicting digest/body, more than one staging sequence, missing/corrupt local canonical record, or any unrelated marker is `indeterminate`. If candidate inputs changed, first finish the reconstructable old staging generation as historical using its frozen local bytes and generic recovery direction; only then may a new sequence be chosen. No partial comment is deleted or silently abandoned.

Rendered comment markers are:

```text
<!-- qinao-final-evidence-manifest:v1 sequence=1 -->
<!-- qinao-final-evidence-chunk:v1 sequence=1 index=1 total=3 -->
```

The manifest is posted last, so its presence never falsely implies all earlier comments exist; verification always queries and validates the full set.

- [ ] **Step 7: Write failing approval-audit non-authority tests**

The audit payload records positive `decisionSequence`, `supersedesAuditDigest` (`null` only when no earlier valid audit exists), `B/H/T/V/A/M/P/E`, PR number, exact user-decision text digest, decision timestamp supplied by the active task, frozen authenticated-user login/numeric ID/response digest, risk/reason codes, complete finding dispositions, limitations, blast radius, irreversible effects, rollback/forward-recovery method, `separateEffectAuthorization="absent"` for this merge-only decision, and `auditDigest` with self-exclusion. Every copied collection/digest must equal reconstructed `final-evidence`; no field grants or stores permission. Older audit records are immutable historical decisions, not conflicts merely because they exist; exactly one latest sequence may correspond to the current active decision. Tests assert:

- no `authorized`, `permission`, `token`, `resume`, or `canMerge` field is accepted;
- no protocol function accepts an audit object to decide whether merge may run;
- an interrupted task or changed identity requires a new user decision regardless of a valid prior audit;
- sequence gaps, duplicate sequence values, a wrong predecessor digest, reuse of an earlier decision record, and treating an older audit as current all fail;
- rendering is deterministic but parsing it yields only `ApprovalAudit`, never a command.

- [ ] **Step 8: Write failing operation-specific recovery tests**

Use pure observation dataclasses:

```python
def test_push_old_ref_after_lost_transport_is_indeterminate(self):
    decision = module.recover_push_outcome(
        old_ref=None,
        expected_ref="a" * 40,
        observed_ref=None,
        observation_authoritative=True,
        transport_outcome="lost",
    )
    self.assertEqual(decision.state, "indeterminate")

def test_pr_create_recovers_only_one_exact_match(self):
    match = pr_observation(head="a" * 40, body_digest="b" * 64)
    decision = module.recover_pr_create_outcome(
        expected_head="a" * 40,
        expected_body_digest="b" * 64,
        observations=(match,),
        observation_authoritative=True,
    )
    self.assertEqual(decision.state, "confirmed-success")
```

Cover:

- push: expected ref, exact lease rejection versus transport-unknown, unrelated ref, failed `ls-remote`, duplicate rows, and rejection of any claimed LFS/submodule side effect because both are forbidden by this plan;
- PR creation: exactly one match, authoritative zero plus proved terminal rejection, authoritative zero after transport-unknown (must stay indeterminate), multiple matches, stale base/head/body, unreadable pagination;
- body/comment: exact new digest, exact old/zero after proved rejection, exact old/zero after timeout (must stay indeterminate), multiple/partial/conflicting records, and unresolved logical-key replay rejection;
- merge: confirmed `R` with tree/parents/audit, confirmed no-effect only after parsed terminal rejection plus PR open/`main=B`, zero/old observation after lost response (must stay indeterminate), closed-unmerged, merged with wrong tree/parents, unreadable state.

Closed decision states are `confirmed-success`, `confirmed-no-effect`, `retry-once-after-fresh-approval`, and `indeterminate`. `confirmed-no-effect` is available only after a parsed, authenticated terminal rejection whose endpoint semantics prove non-acceptance; a timeout, lost response, disconnected transport, unreadable response, or client cancellation remains `indeterminate` when the intended effect is not observed, even if an immediate read still shows the old/absent state. Such a transport-unknown logical mutation is never retried. No recovery function performs I/O.

Every remote mutation follows one closed storage template. First allocate a request-only capture, render its canonical body/refspec rows by O_EXCL, and seal it before opening the frontier; the frontier must reopen and bind that request seal, not merely caller-supplied file digests. The sealed request directory is never a response destination. The wrapper appends/fsyncs its safe result, exact exit class, and response projection only in the frontier's unique attempt ledger before transport and on return; stdout is discarded unless the wrapper itself writes an allowlisted safe projection there. After any exit, allocate a fresh read-only observation capture parent-bound to the request seal and attempt record, render/seal its read manifest, collect only allowlisted response projections, normalize them through a pure operation-specific classifier, and seal that observation. Completion reopens and binds the start, request seal, unique attempt, observation seal, and canonical classification. A crash fixture at every boundary proves a request capture is immutable, an attempt cannot be substituted or duplicated, an observation cannot be appended to either parent, and a lost stdout never changes the selected generation.

Every remote mutation uses one and only one durable mutation frontier. The closed kinds are `remote-git-push`, `remote-pr-create`, `remote-pr-patch`, `remote-comment-post`, and `remote-merge-put`. `frontier-start --recover-exact` binds the logical key, tuple/current-host state, exact canonical request or refspec/lease, preflight plus both credential-generation fingerprints, and the single wrapper row; the wrapper appends/fsyncs the attempt before transport. For `remote-merge-put`, the start additionally requires literal scalar `--merge-method merge` and exactly two ordered repeated `--parent B --parent H` arguments, persists typed `M="merge",P=[B,H]`, and rejects an encoded array/string substitute, reversed/extra parent, or another method. Read-only recovery captures may be allocated while that frontier remains open, but no second mutation frontier may start. After the pure operation-specific classifier returns a canonical observation, the caller may close only these two terminal states:

| Kind | Confirmed-success observation bound to completion | Confirmed-no-effect observation bound to completion |
|---|---|---|
| `remote-git-push` | exact branch ref `H`, same disclosed object/LFS set | parsed lease/server rejection plus exact old/absent ref |
| `remote-pr-create` | one open exact `B/H/body` PR number | parsed terminal rejection plus authoritative zero all-state branch PRs |
| `remote-pr-patch` | exact PR number with intended body digest | parsed terminal rejection plus exact prior body digest |
| `remote-comment-post` | one exact logical marker/body/record digest and comment ID in complete pages | parsed terminal rejection plus authoritative absence of that logical key |
| `remote-merge-put` | merged PR and exact `R`, parents `[B,H]`, tree `T`, expected actor | parsed terminal rejection plus PR open and `main=B` |

The executable terminal pattern is mandatory for every row above:

```bash
qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$EVIDENCE_ROOT" --frontier-id "$REMOTE_FRONTIER_ID" \
  --recover-exact --state "$CONFIRMED_STATE" \
  --attempt-record "$ATTEMPT_RECORD" \
  --observation-capture "$OBSERVATION_SEAL_RECORD" \
  --classification-record "$RECOVERY_CLASSIFICATION_RECORD" \
  --require-operation-specific-postcondition
```

`CONFIRMED_STATE` is exactly `confirmed-success` or `confirmed-no-effect`. The completion implementation reopens and cross-checks all bound host/ref IDs, digests, response classification, and credential generations; lost completion stdout returns the byte-identical terminal record. `indeterminate` never calls `frontier-complete`, remains the one open blocking mutation, and is never converted to a resource-only state. A confirmed-no-effect completion permits a later fresh frontier only after the task's specified new user instruction/approval. Fixtures for all five kinds crash before attempt append, after append/before network, after effect/lost response, after observation/before completion, and after completion fsync/lost stdout; they prove success/no-effect closes exactly once and transport-unknown permanently blocks replay.

`render-pr-create-request --title TITLE --head HEAD --base BASE --body-file BODY --output REQUEST` accepts only the literal repository-independent fields admitted by this plan and emits canonical JSON with exact keys/values `{title,head,base,body,maintainer_can_modify:false,draft:false}`; no issue, label, project, auto-merge, fork-maintainer, or inferred field is accepted. Its tests assert exact UTF-8/JCS bytes, one-LF bounded body, the literal `head=codex/qinao-git-only-convergence` and `base=main`, false booleans, output O_EXCL, and rejection of any unknown/defaulted key. `render-comment-request --body-file BODY --output REQUEST` accepts one regular LF/UTF-8 record body with exactly one recognized marker and bounded bytes, then emits canonical JSON with the sole key `body`. `verify-comment-observation --comments-pages PAGES --expected-body BODY --expected-record-digest DIGEST --attempt-record ATTEMPT --output RESULT --capture-files-output FILES` reopens the unique attempt, parses the complete safe `gh api --paginate --slurp` page envelope, rejects missing/duplicate page items and edits/deletions/marker conflicts, and O_EXCL-emits one closed recovery state plus its exact self-including whitelist. Its read-only `--verify RESULT --observation-capture SEAL --print-field state` mode reopens the result only through that exact seal and exposes only `confirmed-success`, `confirmed-no-effect`, or `indeterminate`. These pure commands never post, delete, edit, or treat an approval audit as authorization.

- [ ] **Step 9: Run protocol tests and commit**

```bash
qinao_python -m unittest -v scripts.test_qinao_pr_protocol
git diff --check
git add \
  scripts/qinao_pr_protocol.py \
  scripts/test_qinao_pr_protocol.py \
  docs/superpowers/schemas/qinao-pr-evidence.v1.json
git commit --no-verify --no-gpg-sign -m "feat: add canonical PR evidence and recovery protocol"
```

Expected: all protocol tests pass under Python 3.9.6; one focused commit.

### Task 7: Implement the finite automation inventory and digest `A`

**Files:**
- Create: `scripts/qinao_workflow_inventory.py`
- Create: `scripts/test_qinao_workflow_inventory.py`

**Interfaces:**
- Consumes: one manually captured closed JSON observation whose repository files are bound to `H` blobs and whose host/PR responses are bound to endpoint/status/body digests.
- Produces: `validate_automation_inventory(value, identity)`, `automation_digest(value)`, `validate_postmerge_automation_inventory(value, postmerge_identity)`, `postmerge_automation_digest(value)`, and CLI subcommands `validate`, `validate-postmerge`, `validate-candidate-ci`, `validate-postmerge-ci`, `validate-repository`, `repository-inventory`, `render-request-rows`, `select-ci-run`, `read-ci-run-selection`, `select-ci-jobs`, `observation-projection`, `host-candidate-sha`, and `validate-host-candidate`. `validate-host-candidate` is pure/output-O_EXCL: its local-resource/imported-ref mode reopens one commit and requires ordered parents `[B,H]`, tree `T`, exact expected ref and source/import terminal lineage; its REST mode requires the safe pull projection's non-null 40-hex merge SHA, exact base/head repositories/OIDs, then the safe commit projection's same SHA, ordered parents `[B,H]`, and tree `T`. It emits one canonical result and exact capture whitelist, never fetches or selects a fallback. `render-request-rows` has a closed, unit-tested phase table for every literal network family in Tasks 11–15 (`remote-auth`, advertisements/ref reads, host initial/final/postmerge, PR state, host candidate, CI/postmerge CI, comments, approval rereads) and a closed dynamic-child mode. It renders exact argv bytes, method/path/headers, request-body digest, output profile/basename, max-use one, and either immutable tuple inputs or a required semantic parent record plus its self-digest. For every dynamic family it reopens that parent record, validates its self-digest and the exact IDs-sidecar digest stored inside it, and rejects a request-manifest digest masquerading as a semantic parent. Request-manifest safe-projection digests are accepted only as the current parser's `--request-projection` lineage input. It never accepts an arbitrary endpoint/argv passthrough. Tests compare every rendered row byte-for-byte with the corresponding command fence—including the literal preflight-variable name and the exact `--record`/`--input` validator form—reject a missing/extra/reordered row or undefined shell token, and prove that environment/workflow/run-source/suite/annotation/run-attempt/job/comment/merge-commit dynamic rows cannot be rendered before their parent semantic record is complete.

The CI helper commands are pure, bounded readers of already safe-captured projections. `select-ci-run` is deliberately **provisional** because run/check REST metadata cannot prove the PR-body/`T/V` identity that appears only in job logs. It requires complete static/suite/annotation parents, exact event/head/workflow path, a caller-supplied 40-hex workflow blob reopened from that exact head, and the matching frozen workflow-contract record; unique positive run ID/attempt; and one latest eligible run under the closed `(run_number,run_attempt,created_at,id)` order. Ties, duplicate IDs, cap/unknown state, blob/contract mismatch, or an equally eligible producer block. It makes no body/`T/V` success claim. It O_EXCL-emits canonical self-digesting `qinao.ci-run-selection.v1` plus an exact one-line ASCII `runId<TAB>attempt<LF>` ID file whose digest is in the record; `--print-field selectionDigest` reopens both. `read-ci-run-selection` must reopen both outputs, verify schema/self-digest/sidecar digest, require exactly one LF-terminated line and two bounded positive decimal fields with no leading zero, and emit only the requested `runId` or `runAttempt`; shell text never parses or invents either URL component. `select-ci-jobs` reopens its run-selection parent, request projection, and complete selected-attempt jobs collection, validates the literal `candidate-nine` or `postmerge-seven` name set, rejects duplicate/missing/extra eligible names/IDs, sorts by expected-name order then numeric ID, and O_EXCL-emits self-digesting `qinao.ci-job-selection.v1` plus a decimal-ID-per-line file bound by digest; it also exposes `selectionDigest` only after reopening both. Only after every selected job log is streamed do `validate-candidate-ci`/`validate-postmerge-ci` require all identity records to bind exact body/`B,H,T,V` or postmerge identity and emit a terminal result plus an exact self-including capture whitelist; a provisional mismatch invalidates that iteration rather than selecting it. `observation-projection` has three closed stages: `--through static --suite-ids-output FILE`, `--through suites --annotation-counts-output FILE`, and `--through annotations`. Each stage reopens the current request projection and every required semantic parent record, proves lineage/no unconsumed or failed row, and O_EXCL-emits one canonical self-digesting semantic projection plus the exact bounded ASCII sidecar for the next dynamic family; the final stage emits no sidecar. `--print-field projectionDigest` reads only a completed record. Tests first fail on missing commands, then cover provisional selection ties, stale head/event/workflow attribution, workflow blob/contract mismatch, later body/tuple log mismatch, request-digest-as-parent confusion, swapped/altered sidecars, duplicate/cap/partial pages, filename collision, missing/extra/non-LF/malformed/overflow/leading-zero TSV fields, parent-lineage drift, skipped stage, and deterministic output.

- [ ] **Step 1: Write failing completeness tests**

Repository scope is finite:

```python
def test_every_workflow_and_local_action_requires_one_record(self):
    observation = complete_observation()
    observation["repository"]["expectedPaths"].append(
        ".github/workflows/missing.yml"
    )
    with self.assertRaisesRegex(module.InventoryError, "missing automation path"):
        module.validate_automation_inventory(observation, identity())

def test_unlisted_external_action_or_reusable_workflow_fails(self):
    observation = complete_observation()
    observation["repository"]["automations"][0]["uses"].append(
        {"target": "owner/action@v1", "resolvedCommit": None}
    )
    with self.assertRaisesRegex(module.InventoryError, "unresolved external action"):
        module.validate_automation_inventory(observation, identity())
```

Cover duplicate/unexpected path, blob mismatch, omitted trigger/job/permission, wildcard permission, omitted environment/secret name, dynamic `uses:`, branch/tag action ref, local action outside `.github/actions`, reusable workflow, and incomplete pagination. Host-observation fixtures additionally prove that commit-level check enumeration uses `filter=all`, not the provider's default `latest`; enumerate every paginated check suite and every suite's paginated `filter=all` check runs; reject a same-app/same-name older run hidden by `latest`, a missing or duplicated suite, a suite/ref-level union disagreement, an inconsistent `total_count`, or the provider's 1,000-suite/run completeness ceiling being reached. For every admitted check run, bind the full raw run digest plus output title/summary/text/`annotations_count`; fetch and fully paginate `/check-runs/{id}/annotations` when count is positive; reject count/page mismatch, missing/duplicate annotation, invalid path/range/level, or changed annotation/output under the same run ID. A warning/notice on a successful check remains a finding requiring disposition.

- [ ] **Step 2: Write failing privilege and cross-trigger-flow tests**

Reject in the candidate `H` policy:

- any effective write permission;
- `id-token: write`;
- any secret beyond the implicit read-only token;
- any environment/deployment;
- self-hosted runner;
- `pull_request_target`, `workflow_run`, `repository_dispatch`, `issue_comment`, `merge_group`, `schedule`, or dynamic dispatch in active policy;
- upload/download/cache or reusable-workflow data that crosses from a candidate trigger into a job with greater privilege;
- unknown trigger, permission, runner, action ref, input source, or data-flow edge;
- an Actions/host/app endpoint marked `unknown` when it could hide write, secret, deploy, publish, release, package, merge, status, or PR mutation capability.

The sole bootstrap transition is not an exception to candidate validation. For each of `.github/workflows/test.yml` and `.github/workflows/qinao-wave-admission.yml`, the inventory reopens `B:path`: absence means `base-source-absent` with `oldGeneration=null`; equality with the exact reviewed legacy `C` blob means `base-retiring`; any other blob is blocking. Only an actually present exact legacy blob receives the retirement classification. A workflow generation is identified by `(path, sourceBlobOid|null)`, not by the provider's reusable numeric workflow ID: replacement/addition of `test.yml` may legitimately keep or acquire an active registered ID while its old/absent generation remains retired. Each actual legacy generation must have zero queued/in-progress/waiting/requested/pending run and no run created after the initial host snapshot whose `head_sha:path` reopens to that old blob. At the initial pre-push snapshot, an active record with no `B` source is stale/unknown and blocks. At the candidate snapshot, `test.yml@HReviewedBlob` is instead required and allowed only when the record plus every selected run is assigned by reopening `head_sha:path` to the exact new blob; `qinao-wave-admission.yml` has no allowed H generation. Workflow ID/path alone never decides old versus new. No API dispatch/disable operation is permitted, and candidate generation/runs never inherit an old-generation exception.

Known branch-protection/ruleset 403 responses are accepted only as:

```json
{
  "classification": "unavailable-by-tier",
  "httpStatus": 403,
  "responseSha256": "64 lowercase hex",
  "capability": "branch-protection",
  "mutationAttempted": false
}
```

A 403 on hooks, environments, apps, deploy keys, Actions permissions, or PR check/review producers is not automatically the same limitation; it remains `unknown` unless the endpoint-specific reason is closed and reviewed.

- [ ] **Step 3: Run inventory tests and confirm failure**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_workflow_inventory
```

Expected: missing module.

- [ ] **Step 4: Implement the closed observation schema**

The root fields are:

```json
{
  "schemaVersion": "qinao.automation-inventory.v1",
  "identity": {"B": "oid", "H": "oid", "T": "tree oid", "V": "64 lowercase hex"},
  "repository": {
    "treeOid": "tree oid",
    "expectedPaths": [],
    "automations": []
  },
  "host": {
    "repository": {},
    "actionsPermissions": {},
    "workflowPermissions": {},
    "selectedActions": {},
    "registeredWorkflows": {},
    "checkSuites": {},
    "checkRunsByRef": {},
    "checkRunsBySuite": {},
    "checkRunOutputs": {},
    "checkAnnotations": {},
    "hooks": {},
    "pages": {},
    "deployments": {},
    "environments": {},
    "actionsSecrets": {},
    "actionsVariables": {},
    "environmentSecretsAndVariables": {},
    "selfHostedRunners": {},
    "nonterminalRuns": {},
    "deployKeys": {},
    "rulesets": {},
    "branchProtection": {},
    "apiVisibleInstallations": {},
    "installationGrantVisibility": {},
    "collaborators": {},
    "repositoryInvitations": {},
    "runSourceBlobs": []
  },
  "transition": {
    "baseDefaultBranchOid": "B oid",
    "candidateHeadOid": "H oid",
    "baseRetiring": [],
    "candidateActive": [],
    "legacyWorkflowTransportIds": [],
    "runHighWatermarks": []
  },
  "pullRequest": {
    "number": 1,
    "headOid": "oid",
    "baseOid": "oid",
    "checks": [],
    "statuses": [],
    "reviews": [],
    "reviewComments": [],
    "reviewProducers": [],
    "autoMerge": false
  },
  "dataFlows": [],
  "unknowns": [],
  "limitations": []
}
```

Observation times, HTTP request IDs, local capture paths, per-page status/header/request metadata, whole-stream/redacted-response SHA-256 values, rate-limit values, and volatile PR/issue aggregate fields such as `updated_at`/comment counts live in a separate `observationEvidence` capture index and are excluded from `A`. Every endpoint evidence record still includes request method/path, pagination-complete boolean, every page's HTTP status/header projection, safe-response SHA-256, classification, and whether a mutation was attempted; the validator requires every `mutationAttempted` value to be `false` and emits one digest over that evidence set for `E`/audit linkage. `automation_digest` hashes only the field-level automation semantic projection explicitly enumerated by this task. Timestamps that are part of a producer record's history/ordering—check runs, reviews, review comments, commit statuses, workflow runs—remain semantic; transport timestamps and mutable pull/issue aggregates do not. Adding only a recognized Qinao issue/timeline comment must change capture/evidence digests but leave `A` unchanged, while changing a workflow/check/review/status producer must change `A`; fixtures assert both directions and prevent redacted-stream digests from feeding back into `A`.

`checkRunsByRef` must come from the exact commit endpoint with `filter=all`; `checkSuites` must be completely paginated for that commit; and `checkRunsBySuite` must contain one completely paginated `filter=all` collection for every unique suite ID. Normalize the complete run identity `(id,check_suite.id,app.id,name,head_sha,status,conclusion,started_at,completed_at,details_url)`, reject duplicate provider IDs, and require the ref-level and suite-level unions/counts to agree exactly. For each normalized run, `checkRunOutputs` binds the safe source-object digest and exact output `title/summary/text/annotations_count` field digests. If the nonnegative count is zero, `checkAnnotations` records a zero-count no-request proof; otherwise it contains the completely paginated exact `/check-runs/{numeric-id}/annotations?per_page=100` family. GitHub does not provide an annotation ID in this response, so preserve API array order across pages and derive identity exactly as `(checkRunId, zero-based-global-ordinal, canonical-field-digest)`, where the field digest covers `path,start_line,end_line,start_column|null,end_column|null,annotation_level,message,title|null,raw_details|null,blob_href|null`. Validate page order and total count against `annotations_count`; two byte-identical annotations at different ordinals remain two records and are never rejected as duplicates. `blob_href` and every other URL receive the safe scheme/host/path projection, while raw-stream URL digests stay in observation evidence; unsafe userinfo/query/fragment blocks. Every notice/warning/failure annotation enters the finding/disposition union regardless of run conclusion. GitHub's documented 1,000-suite/check-run ceiling is not proof of completeness: reaching it, observing a page/count cap, or being unable to prove termination is `unknown` and blocks.

`pullRequest.statuses` is the **complete historical** commit-status collection from the paginated `GET /repos/ChangGeng01/ProjectSix/commits/$H/statuses` endpoint, never the combined-status endpoint's latest-only projection. Normalize every record as `(id,node_id,sha,context,state,descriptionDigest,targetUrlProjection,creator.id,creator.login,creator.type,created_at,updated_at)`, preserve every older same-context record, reject duplicate IDs/unknown fields or creators/unsafe target URLs, and derive a deterministic per-context latest projection only after ordering by `(updated_at,created_at,id)` with ties or contradictory identities blocking. `A`, approval, and `A_R` bind both the full ordered history digest and the derived latest projection; a later capture must equal or explicitly extend the earlier history without deletion/rewrite. Commit statuses are observational producer evidence only: the required six baseline jobs plus `qinao-protocol-tests`, `risk-check`, and `pr-metadata` can be satisfied solely through the Actions run -> attempt -> job -> streamed-log identity chain, and no status context/state can replace one. Tests cover same-context older failure/latest success, stale success after a newer failure, creator drift, duplicate/tied chronology, unknown context/creator, and a signed-query `target_url` that must block without persistence.

`host.repository` must include and validate `delete_branch_on_merge=false`, `has_pages=false`; merge-mode booleans; visibility/owner/default branch; and default workflow-token permission. `host.pages` must be an authoritative disabled/404-consistent observation made only after Pages-read capability is independently proved; a 200 response, enabled source/build type/custom domain, `has_pages` disagreement, endpoint-specific auth failure, or unreadable status is blocking because publication was not authorized. A 404 is closed-disabled only when permission proof and repository metadata agree; it is never accepted as “not found means off” under ambiguous credentials. `host.deployments` likewise requires Deployments-read capability, complete pagination, and cross-checks every environment/creator/ref/sha/producer; any active, hidden, or unclassified publication/deployment path blocks. `collaborators` and pending repository invitations close every host-visible human write/merge actor other than the separately frozen authenticated owner. Secret/variable collections store names, visibility/selection metadata, update timestamps, and counts only—never values. Environment names are percent-encoded by a pure encoder before their secret/variable endpoints are read. Runner records store ID/name/OS/labels/status/busy only and never registration tokens. `nonterminalRuns` is the complete union of separate paginated `queued`, `in_progress`, `waiting`, `requested`, and `pending` queries with duplicate run IDs rejected. Tests cover branch-based Pages on `main`, Actions Pages, custom domain, `has_pages` mismatch, Pages 403/auth ambiguity, hidden deployment, and a permission-proved disabled/404-consistent success fixture.

`installationGrantVisibility` is a closed limitation record, not an empty-success substitute. It binds the authenticated credential type/projection and states whether the GitHub-App-user-token-only installations family is callable. With the ordinary classic/fine-grained/OAuth `gh` credential admitted by this plan, it must be `unavailable-for-credential-type`, names the omitted endpoint family and official capability reason, records no mutation/second credential, and makes risk high. `apiVisibleInstallations` then contains only app identities independently surfaced by hooks, check suites/runs/annotations, deployments, workflow actions, review comments, and other admitted responses, cross-correlated by numeric app/installation ID where exposed. Any visible writer/producer without a complete disposition blocks. The validator never calls a user-installations endpoint with an unsupported credential, never interprets 403 as an empty app set, and never claims invisible App/OAuth/PAT grants are enumerated. Tests cover an unsupported normal credential with the explicit limitation, an optional already-present GitHub App user access token with complete read-only pagination, a hidden/novel visible check producer, and a false empty-success record.

The personal-repository tier also emits `transientHostMutationVisibility=unavailable-no-audit-log` as an independent high-risk limitation in `A`, `E`, every approval summary, and `A_R`. The captures prove complete **point-in-time API-visible state plus retained histories** at their boundaries; without an organization/enterprise audit log they cannot prove that another actor did not create/trigger/delete a workflow run, hook, deployment, comment, or setting and restore it between captures. High-watermarks close only retained API-visible records, never deleted transient history. The protocol therefore does not claim continuous host-enforcement or adversarial-history completeness. In this ordinary single-owner workflow, execution may continue only when this exact limitation is presented unchanged to the user at Task 14 and no current/retained producer or other write actor is visible; if the user's required guarantee is fail-closed against any transient/concurrent host actor, the personal tier is externally incapable and the process stops before mutation. Tests reject wording that turns snapshot completeness into historical completeness and require the limitation to survive premerge/postmerge digest construction.

The transition validator reopens `B`, `C`, `H`, and every observed run's `head_sha:path`. The literal inspected legacy path set is `{.github/workflows/test.yml,.github/workflows/qinao-wave-admission.yml}`, but the `baseRetiring` subset is derived by the three-state rule above and may be empty. For each run, normalize `run.path` only when it is either the literal path or that literal followed by `@<nonempty ref text>`; no generic `@` split or path substitution is allowed. Require a unique positive run ID and 40-hex `head_sha`, then bind it to one captured `runSourceBlobs` entry keyed by exact `(head_sha,literalPath)`. That entry comes from the authenticated Contents API at the exact historical SHA, contains status/request digest, requires `type="file"`, exact path/name, returned Git blob SHA, decoded-byte SHA-256/size, and proves the bytes hash to the returned Git blob ID. It does not invent a mode field the Contents API does not return; historical generation identity needs exact blob bytes/OID, while current local `B/H/R` tree modes are verified separately. A 404, garbage-collected/unreadable commit, truncated/base64-invalid body, path/ref mismatch, third blob, or absent entry is `unknown` and blocks; the current heads/tags quarantine is never assumed to contain deleted historical run heads.

Independently, `C→H` must leave candidate `test.yml` equal to the reviewed contract blob and candidate `qinao-wave-admission.yml` absent. The validator records host workflow IDs/states and complete run IDs while treating IDs only as transport handles. The initial/final premerge inventories freeze every numeric workflow ID ever associated with either legacy path as `legacyWorkflowTransportIds`, its exact path/blob generations, and both per-ID and repository-wide Actions-run high-watermarks. Those IDs remain mandatory query targets after deletion even if the current workflow registry omits them. An exact old manual-dispatch/self-hosted/variable/artifact surface remains a disclosed high-risk fact only when its source blob is actually present at `B`; an absent old source is not invented as exposure. Before push, an active registry entry without a `B` source is stale/unknown and blocks; after push, it passes only as the required `test.yml@HReviewedBlob` generation with exact candidate runs. Any old-generation trigger execution, extra path, unassigned record/run, missing endpoint without the closed repository-wide fallback, or drift is blocking. Tests cover literal and `path@ref` forms, `@` inside an invalid path, duplicate `(head_sha,path)`, mismatched Contents blob, historical 404, a run head absent from all current refs, a deleted workflow ID whose terminal old-blob run appears between snapshots, registry omission, per-ID 404 with complete fallback, and repository-wide pagination/cap failure. Post-merge uses the separate closed-state transition rule in Task 15 and computes a new digest rather than pretending pre-merge `A` is unchanged after retirement.

`qinao.postmerge-automation-inventory.v1` is a distinct root, not the candidate object with renamed fields. It contains exact `postMergeIdentity={R,B,H,T,V}`, repository tree/ref state at `R`, the complete fresh host endpoint projection, merged PR state, selected main-push run/job/log identity digests, pre-merge transition/high-watermark digests, closed post-merge transition dispositions, data flows, unknowns, and limitations. Validation reopens `R`, requires parents `[B,H]`, tree `T`, policy `V`, and `refs/heads/main=R` before any host record is accepted. This identity is mandatory input to `postmerge_automation_digest`; therefore `A_R` is provably bound to the actual merge commit and cannot equal a candidate-only claim by type confusion.

`host-candidate-sha` is a pure bounded REST-response parser and O_EXCL semantic-record producer. It requires the exact PR number/repository, `state="open"`, `base.sha=B`, `head.sha=H`, same-repository head, non-null 40-hex `merge_commit_sha`, REST `auto_merge == null`, and the current request safe-projection digest. With required `--output` and `--capture-files-output`, it writes canonical `qinao.host-candidate-pull.v1` containing those identity fields, the safe-projection/raw-stream digests, merge OID, and self-digest plus the exact whitelist. `--print-field mergeCommitSha` prints only that OID after reopening the output/whitelist; no implicit stdout form exists. Unknown/duplicate identity field, null/changed candidate, output collision, or a GraphQL-shaped substitute fails. The REST-commit child renderer must consume this record and its self-digest as its semantic parent.

Issue/timeline comment transport items that are recognized **and independently digest-valid** `final-evidence`, approval-audit, or post-merge records are excluded from the semantic inputs of both `automation_digest` (`A`) and `postmerge_automation_digest` (`A_R`) to avoid self-reference. Their complete IDs/bodies/timestamps/producers and raw/safe-capture digests remain in `observationEvidence` and their independent immutable record chains. Posting the exact post-merge verification record must therefore change observation/record-chain digests but leave `A_R` unchanged; a fixture proves this. An unknown, malformed, conflicting, or non-Qinao issue comment is not excluded: its writer/producer/trigger risk remains semantic and can block. GitHub pull-request review comments are different: bind every native response field needed for identity and placement—stable `id/node_id`, `pull_request_review_id`, `in_reply_to_id`, `commit_id/original_commit_id`, path, position/original-position, line/original-line/start-line/original-start-line and side/original-side fields with their documented nullability, user/author-association/app producer, creation/update timestamps, and redacted body digest. The list-review-comments response has no native `state` field, so the validator must not require one; if it needs an outdated/current classification, it derives a separately named `derivedDisposition` solely from the documented null/non-null placement/original-placement relationship and never presents that as provider state. These canonical `pullRequest.reviewComments` inputs are distinct from review submissions and issue/timeline comments, require complete pagination, and reject an unclassified writer or a comment absent from the final review disposition set. The inventory still proves whether any workflow/app/check producer can react to or write either comment class and forbids an active `issue_comment` trigger or PR-writing automation.

- [ ] **Step 5: Implement repository automation validation**

The capture procedure at exact `H` supplies:

- every tree path below `.github/workflows/**` and `.github/actions/**`;
- each path's mode/blob and raw bytes SHA-256;
- triggers and event filters;
- jobs, `needs`, `if`, runner labels, timeouts;
- workflow/job permissions;
- environment and secret names, never secret values;
- every `uses:` target and resolved immutable commit;
- every shell step's declared inputs;
- artifacts, caches, reusable outputs, and all producer→consumer edges.

The validator does not pretend to be a general YAML parser. Instead, `docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json` is the closed parse boundary. For every active workflow/action it contains exact raw path, mode, Git blob OID, raw-byte SHA-256, and a complete reviewed projection of every top-level key, event/filter, job/step, `uses`, `with`, `env` name, expression input, permission, runner, timeout, `if`, `needs`, artifact/cache, and producer→consumer edge. Unknown contract fields or an unrepresented source line/token class fail. The actual `H` tree object must match the contract blob/OID before any semantic assertion is accepted.

`qinao_workflow_inventory.py validate-repository --repository "$WT" --revision "$H" --contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json` first enumerates the complete tree paths, reopens the exact blobs, validates contract coverage/counts and closed values, and emits the repository half of the inventory. Tests use permitted fixtures plus one fixture for every rejected YAML construct. The workflow/security specialist in Task 11 reviews the actual raw blob line-by-line against this contract and signs its digest-bound finding result. A blob or contract change therefore requires an explicit contract revision and fresh review; an ad-hoc hand-written observation cannot make an unreviewed YAML construct complete.

- [ ] **Step 6: Implement canonical `A`**

```python
def automation_digest(
    inventory: Mapping[str, object],
    identity: CandidateIdentity,
) -> str:
    normalized = validate_automation_inventory(inventory, identity)
    if "automationDigest" in normalized:
        raise InventoryError("A input must omit its own digest")
    return hashlib.sha256(jcs_bytes(normalized)).hexdigest()
```

`postmerge_automation_digest` has the same self-exclusion/JCS construction but first calls `validate_postmerge_automation_inventory(value, PostMergeIdentity)` and uses schema `qinao.postmerge-automation-inventory.v1`; passing `CandidateIdentity`, omitting `R`, or changing a parent/tree/ref/push-run field fails. Import `jcs_bytes` from `qinao_pr_protocol`. Tests prove dictionary input order and observation time do not change `A`/`A_R`, while any blob, endpoint classification, app/check producer, permission, trigger, data flow, result commit, push-run identity, or transition change does.

- [ ] **Step 7: Run tests and commit**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_pr_protocol.JCSTests \
  scripts.test_qinao_workflow_inventory
git add \
  scripts/qinao_workflow_inventory.py \
  scripts/test_qinao_workflow_inventory.py
git commit --no-verify --no-gpg-sign -m "feat: add finite Qinao automation inventory"
```

Expected: all tests pass; the module has no GitHub write or merge path.

### Task 8: Implement the versioned typed validation matrix and bounded runner

**Files:**
- Create: `scripts/qinao_pr_validation.py`
- Create: `scripts/test_qinao_pr_validation.py`
- Create: `scripts/check_sovereign_redaction.py`
- Create: `scripts/test_check_sovereign_redaction.py`
- Modify: `scripts/check_sovereign_redaction.sh`
- Modify: `scripts/check_qinao_import_boundaries.sh`
- Modify: `scripts/check_sdk_import_boundaries.sh`
- Modify: `scripts/check_substrate_residuals.sh`
- Modify: `scripts/check_substrate_residual_markers.sh`
- Modify: `scripts/check_chenglu_schema_parity.py`
- Modify: `scripts/check_god_files.sh`
- Preserve/reopen as an explicit loader dependency: `scripts/chenglu_feature_schema.py`
- Create: `BehavioralAISubstrate/Cargo/.cargo/config.toml`
- Create by locked offline import: `BehavioralAISubstrate/Cargo/vendor/**`
- Create: `docs/superpowers/evidence/2026-08-29-qinao-cargo-vendor-manifest.v1.json`
- Create: `docs/superpowers/validation/qinao-pr-validation-matrix.v1.json`
- Create after reviewed capture: `docs/superpowers/validation/qinao-full-suite-skip-baseline.v1.json`
- Preserve/reuse: `scripts/run_nonempty_swift_filter.py`
- Preserve/reuse: `scripts/run_nonempty_xcode_test.py`

**Interfaces:**
- Consumes: `CandidateIdentity`, `RiskDecision`, structured diff, closed matrix, exact executable paths, and versioned skip baseline.
- Produces: `select_targets(matrix, diff, risk)`, `run_target(target, identity, root)`, `validate_result(result, target)`, canonical result JSON files, a generated profile-bound nested-Python shim for declared shell validators only, a locked archive extractor plus separately sealed public no-credential archive acquisition, and CLI subcommands `census-cargo-archives`, `crate-egress-preflight`, `acquire-cargo-archives`, `seal-cargo-archive-union`, `materialize-cargo-vendor`, `verify-cargo-vendor`, `toolchain-report`, `select`, `run-target`, `run-selected`, `run-ci-target`, and `verify-results`.

- [ ] **Step 1: Write failing target-selection tests**

The selection lattice is monotonic:

```python
def test_docs_only_selects_real_document_and_protocol_checks(self):
    selected = module.select_targets(
        matrix(),
        (doc_entry("docs/guide.md"),),
        routine_decision(),
    )
    self.assertEqual(
        selected,
        (
            "protocol-units",
            "document-static",
            "forward-policy-static",
        ),
    )

def test_workflow_change_selects_every_baseline_and_policy_target(self):
    selected = module.select_targets(
        matrix(),
        (workflow_entry(".github/workflows/test.yml"),),
        high_decision("workflow-change"),
    )
    self.assertEqual(set(selected), set(ALL_HIGH_RISK_TARGET_IDS))
```

Tests cover Python-only, Swift BAS, Qinao SDK, SampleHost, Rust, boundary script, dependency/lockfile, LFS, binary/vendor, unknown, deletion, and a declared high risk with routine paths. An unmapped path or reason fails instead of selecting a default. Boundary fixtures also assert the exact nine-node repository executable/module closure, delegate edges, and complete input-tree projections; an omitted nested scanner or dynamically imported module fails.

- [ ] **Step 2: Write failing typed-result tests**

```python
def test_test_success_requires_nonempty_closed_counts(self):
    result = test_result(discovered=2, executed=2, passed=2)
    module.validate_result(result, target("test"))
    with self.assertRaises(module.ValidationError):
        module.validate_result(
            test_result(discovered=0, executed=0, passed=0),
            target("test"),
        )

def test_stale_identity_and_unexpected_skip_are_incomplete(self):
    with self.assertRaises(module.ValidationError):
        module.validate_result(
            test_result(identity=other_identity(), skipped=1),
            target("test", allowed_skips=()),
        )
```

For a full-suite exact baseline:

```text
discovered = passed + failed + skipped
executed = passed + failed
discovered > 0
failed = 0
observed skipped test-ID set = allowed skipped test-ID set
```

For static/document/build:

```text
enumerated = checked
enumerated > 0
failed = 0
discovered = executed = passed = skipped = 0
```

Reject overflow/negative counts, result identity mismatch, duplicate target, unknown kind/outcome, missing raw evidence digest, output truncation, timeout, cancellation, and a command exit inconsistent with counts.

- [ ] **Step 3: Run focused tests and confirm failure**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_pr_validation
```

Expected: missing module.

- [ ] **Step 4: Author the closed matrix**

The matrix has these exact target IDs:

| Target | Kind | Bound | Maximum command time | Required evidence |
|---|---|---:|---:|---|
| `protocol-units` | test | always | 10 min | nonzero `unittest` count for the five new/audit modules plus both preserved nonempty runners |
| `document-static` | document | docs | 5 min | every changed Markdown file enumerated/checked; UTF-8/LF/link/pointer checks |
| `forward-policy-static` | static | always | 5 min | complete `C→H` inventory, dormant legacy gates, DS3 absent, exact identities |
| `boundary-static` | static | source/high | 10 min | all six existing boundary/schema/god-file commands, individually counted |
| `python-feature-tests` | test | Python feature schema | 5 min | standard-library unittest count, no pytest install |
| `bas-xctest` | test | BAS/high | 30 min | `swift test --disable-swift-testing --xunit-output`; exact full-suite skip baseline |
| `qinao-xctest` | test | SDK/high | 30 min | same structured xUnit rule |
| `samplehost-xctest` | test | SampleHost/high | 30 min | `run_nonempty_xcode_test.py` terminal JSON/line and xcresult digest |
| `rust-build` | build | Rust/high | 15 min | vendored closure verified; `cargo metadata --frozen`, tool versions, release build exit zero |
| `rust-test` | test | Rust/high | 20 min | vendored/offline closure verified; all Cargo result summaries aggregated; exact three ignored performance tests |
| `workflow-contract-static` | static | workflow/high | 5 min | only allowed triggers/actions/permissions/data flows; no privileged surface |
| `repository-automation-static` | static | workflow/high | 5 min | exact `H` workflow/action tree paths, blobs, triggers, jobs, permissions, external refs, and data flows are complete; no host/PR observation is claimed by this target |
| `full-diff-review-inventory` | static | high | 5 min | every raw diff entry assigned once, binary/LFS provenance present |

The high-risk set contains all thirteen targets, and every one must finish successfully in Task 11. The host/PR half of the automation inventory is not a pending matrix target: Task 13 captures and validates it together with the already-successful repository portion before computing `A`. A docs-only routine change selects the three targets in Step 1. Source-specific routine changes are not allowed: code/control/dependency changes classify high.

The JSON is not just the table above. Its root has exactly `schemaVersion`, `environment`, `adapters`, `boundaryExecutionClosure`, and `targets`. `boundaryExecutionClosure` names the exact nine repository entry/module nodes, every delegate/import edge, each allowed absolute/tool-profile child, and closed prefix/suffix/mode rules for the input trees that each node reads. The runner enumerates those trees from `H` into sorted `(path,mode,type,blobOid)` projections and binds the projection digest to the target result; a filesystem-only glob or an omitted Git-tree entry is invalid. Each target has exactly:

```json
{
  "id": "stable-id",
  "kind": "test|static|document|build",
  "selectors": ["always|surface:<closed-name>|risk:high"],
  "commands": [
    {
      "subresultId": "stable command ID",
      "executable": {"source": "absolute|xcrun|path|qinao-python", "value": "closed value"},
      "argv": ["literal argv element"],
      "cwd": "repository-relative directory"
    }
  ],
  "environmentKeys": ["closed inherited/generated key"],
  "adapter": "closed-adapter-id",
  "timeoutSeconds": 300,
  "stdoutLimitBytes": 16777216,
  "stderrLimitBytes": 16777216,
  "subresultIds": ["stable nonempty ID"],
  "skipPolicy": {"mode": "none|exact-baseline", "baselinePath": null},
  "failureRule": "zero-nonempty-v1"
}
```

`argv` never contains shell, interpolation, glob, substitution, or an executable; the runner resolves the executable by its declared source and passes the argv list directly. `source="qinao-python"` is a reserved in-process harness operation whose only legal value is `qinao_python`: it does **not** perform PATH lookup or execute a file named `qinao_python`, but constructs the exact `env -i`/`/usr/bin/python3 -I -S -B`/`sterile-python` argv from the already verified ledger (or the exact CI profile), reopens the launcher/module closure, and then appends the matrix argv. Tests plant a same-named executable, alias, function, PATH prefix, Python environment, and ignored import artifact and prove none is observed. Every target has `commands`, an ordered nonempty array; each command has exactly `subresultId`, `executable`, `argv`, and `cwd`. A single-command target still uses a one-item array. Repository/evidence paths and candidate values use only the whole-element closed tokens `@ROOT@`, `@IDENTITY@`, `@RESULT@`, `@XUNIT@`, `@RAW_MANIFEST@`, `@ASSIGNMENT@`, `@B@`, `@C@`, `@H@`, `@T@`, `@CHECKED_OUT_REVISION@`, `@XCODEBUILD@`, `@XCRESULTTOOL@`, `@TARGET_DERIVED_DATA@`, and `@TARGET_XCRESULT@`; substitution is element-wise after type/canonical-path validation, never textual shell expansion. `cwd` is resolved below the verified `WT`. The only generated environment keys are `HOME`, `LANG`, `LC_ALL`, `PATH`, `TMPDIR`, `CARGO_HOME`, `CARGO_NET_OFFLINE`, `CARGO_TARGET_DIR`, `QINAO_PYTHON_SHIM`, `QINAO_BOUNDARY_MATRIX_MODE`, `QINAO_RG_EXECUTABLE`, `QINAO_SWIFT_EXECUTABLE`, `GIT_TERMINAL_PROMPT`, `GIT_OPTIONAL_LOCKS`, `GIT_NO_REPLACE_OBJECTS`, `GIT_NO_LAZY_FETCH`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM`, `GIT_CONFIG_NOSYSTEM`, and an observed absolute `DEVELOPER_DIR`; targets list the subset they receive. `CARGO_HOME` and `CARGO_TARGET_DIR` are separate fresh empty private directories and literal `CARGO_NET_OFFLINE=true` is mandatory only for Rust targets; those targets use the reviewed repository-local source replacement and pass `--frozen`. The two absolute `QINAO_*_EXECUTABLE` values, `QINAO_PYTHON_SHIM`, and literal `QINAO_BOUNDARY_MATRIX_MODE=1` are admitted only for `boundary-static` and come from the runner's already bracketed tool projection. Unlisted keys are removed.

The following is the complete per-target execution mapping encoded in the real JSON; line wrapping here does not change argv elements:

| ID | Selectors | Executable / cwd / literal argv | Adapter and required subresults |
|---|---|---|---|
| `protocol-units` | `always`, `risk:high` | `qinao_python`, `.`, seven separate `-m unittest -v MODULE` invocations for `scripts.test_qinao_convergence_audit`, `scripts.test_qinao_pr_protocol`, `scripts.test_qinao_pr_validation`, `scripts.test_qinao_workflow_inventory`, `scripts.test_check_sovereign_redaction`, `scripts.test_run_nonempty_swift_filter`, `scripts.test_run_nonempty_xcode_test` | `sequence-unittest-combined-v1`; one nonzero subresult per exact module |
| `document-static` | `surface:docs`, `risk:high` | two `qinao_python` commands in `.`: `scripts/qinao_convergence_audit.py documents-verify --repository @ROOT@ --inventory docs/superpowers/evidence/2026-08-29-qinao-plan-spec-inventory.v1.json --revision @H@`; then `documents-lint --repository @ROOT@ --source @C@ --final @H@ --raw-manifest @RAW_MANIFEST@ --inventory docs/superpowers/evidence/2026-08-29-qinao-plan-spec-inventory.v1.json --output @RESULT@` | `sequence-static-json-v1`; `inventory`, `changed-docs` both nonempty |
| `forward-policy-static` | `always`, `risk:high` | `qinao_python`, `.`, `-m unittest -v scripts.test_qinao_convergence_audit.ForwardPolicyTests scripts.test_qinao_pr_protocol.NonAuthorityTests scripts.test_qinao_workflow_inventory.ForwardReferenceTests` | `unittest-combined-v1`; one nonzero result with all three classes present |
| `boundary-static` | `risk:high` | six ordered command objects in `.`: `/bin/bash scripts/check_qinao_import_boundaries.sh`; `/bin/bash scripts/check_sovereign_redaction.sh`; `/bin/bash scripts/check_sdk_import_boundaries.sh`; `/bin/bash scripts/check_substrate_residuals.sh`; `qinao_python scripts/check_chenglu_schema_parity.py`; `/bin/bash scripts/check_god_files.sh` | `sequence-static-exit-v1`; six command `subresultId` values matching the six paths and the target `subresultIds` exactly |
| `python-feature-tests` | `risk:high` | `qinao_python`, `.`, `-m unittest -v scripts.test_chenglu_feature_schema` | `unittest-combined-v1`; exactly the frozen migrated test count from Task 9, zero skipped |
| `bas-xctest` | `risk:high` | `xcrun swift`, `.`, `test --package-path BehavioralAISubstrate --disable-swift-testing --xunit-output @XUNIT@` | `swift-xunit-v1`; one BAS report, exact reviewed skip baseline |
| `qinao-xctest` | `risk:high` | `xcrun swift`, `.`, `test --package-path QinaoRuntimeSDK --disable-swift-testing --xunit-output @XUNIT@` | `swift-xunit-v1`; one SDK report, exact reviewed skip baseline |
| `samplehost-xctest` | `risk:high` | `qinao_python`, `.`, `scripts/run_nonempty_xcode_test.py --xcodebuild-executable @XCODEBUILD@ --xcresulttool-executable @XCRESULTTOOL@ --package-path SampleHost --scheme SampleHost --destination "platform=iOS Simulator,name=iPhone 17e" --derived-data-path @TARGET_DERIVED_DATA@ --result-bundle-path @TARGET_XCRESULT@ --require-target SampleHostTests --timeout-seconds 1800` | `xcode-runner-json-v1`; `SampleHostTests`, nonzero and zero skipped |
| `rust-build` | `risk:high` | resolved `cargo`, `BehavioralAISubstrate/Cargo`, first `metadata --manifest-path Cargo.toml --frozen --no-deps --format-version 1`, then `build --manifest-path Cargo.toml --workspace --frozen --release` | `sequence-cargo-json-exit-v1`; `vendor-closure`, `metadata`, `release-build` |
| `rust-test` | `risk:high` | resolved `cargo`, `BehavioralAISubstrate/Cargo`, `test --manifest-path Cargo.toml --workspace --all-targets --frozen --no-run --message-format=json`, then each discovered test-profile executable with `--ignored --list --format terse`, then `test --manifest-path Cargo.toml --workspace --all-targets --frozen` | `cargo-discovery-test-v1`; `vendor-closure`, compile, every discovered harness, ignored-set, aggregate-test |
| `workflow-contract-static` | `risk:high` | `qinao_python`, `.`, `scripts/qinao_workflow_inventory.py validate-repository --repository @ROOT@ --revision @CHECKED_OUT_REVISION@ --contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json` | `workflow-contract-v1`; active-path enumeration and every contract path |
| `repository-automation-static` | `risk:high` | `qinao_python`, `.`, `scripts/qinao_workflow_inventory.py repository-inventory --repository @ROOT@ --revision @CHECKED_OUT_REVISION@ --contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json --output @RESULT@` | `automation-repository-v1`; paths, triggers, jobs, permissions, refs, data flows |
| `full-diff-review-inventory` | `risk:high` | `qinao_python`, `.`, `scripts/qinao_convergence_audit.py review-assignment-verify --raw-manifest @RAW_MANIFEST@ --assignment @ASSIGNMENT@ --identity @IDENTITY@ --output @RESULT@` | `raw-diff-inventory-v1`; every raw entry and exact partition assignment, binary/LFS/document disposition |

The real JSON stores `destination` as one argv element (the backslashes above only clarify Markdown display). Tests load the file and compare every field to this closed mapping, reject missing/extra targets, adapters, selectors, subresults, env keys, or argv elements, and parse `unittest -v` from the concatenated stdout+stderr capture because its terminal summary is normally written to stderr.

- [ ] **Step 4A: Remove nested ambient Python and shared-temporary state from the active boundary graph**

First write failing fixture tests that exercise the current redaction results and static tests that traverse the complete `boundary-static` command graph, including shell-to-shell delegates and explicit Python imports. They must fail on the embedded `python3 -` heredoc, any direct/raw Python child, hardcoded `/tmp`, unbounded `mktemp`, inherited/exported tool choice, unverified `command -v` result, `sys.path`/`sys.meta_path`/import-hook mutation by an admitted target, hidden delegate, duplicate matrix-mode execution, unsafe path expansion, or a nested executable/module not represented in the matrix closure. Execute every reconstructed complete shell suffix through `/bin/bash -n` and a no-side-effect fixture so the test proves argv continuations as well as graph membership.

Extract the Python body from `check_sovereign_redaction.sh` into import-safe, standard-library-only `check_sovereign_redaction.py` with a typed CLI accepting explicit `--symbol-dir` and `--readme`. Preserve the reviewed forbidden/allowlist semantics, but use duplicate-key-rejecting bounded JSON reads, descriptor-relative regular-file checks, deterministic raw-byte path order, closed UTF-8 handling, and structured nonzero counts. Unit fixtures prove byte-equivalent pass/fail findings for the current cases plus malformed/duplicate/oversized/symlinked symbol graphs and README input. The module has no subprocess, environment lookup, network, deletion, or dynamic import.

The validation runner creates one O_EXCL, mode-0700, digest-recorded shell shim inside its private result root for the `boundary-static` target. Its literal body is only the already selected parent profile's `env -i`/`python -I -S -B`/`sterile-python` launch—ledger-backed locally, exact `ci` profile in Actions—with frozen `WT/RUN_ROOT` and, for CI only, the validated case-derived runner root; the target argv remains caller-supplied data and is revalidated by the dispatcher. The runner passes its absolute path as the sole generated `QINAO_PYTHON_SHIM` value. `check_sovereign_redaction.sh` requires that value, invokes it only as `/bin/bash --noprofile --norc "$QINAO_PYTHON_SHIM" scripts/check_sovereign_redaction.py ...`, and never contains or launches Python itself. The shim rejects stdin/`-c`, undeclared targets, a different root/repository/profile, mutation, or use by another matrix target.

Refactor the entire nine-node repository graph named by `boundaryExecutionClosure`. All shell nodes require the runner's private absolute `TMPDIR`, allocate O_EXCL unique children below it, and remove every hardcoded `/tmp` path. `check_substrate_residual_markers.sh` is an explicit Task 8 edit, not hidden behind its deprecated `check_substrate_residuals.sh` exec shim. Replace all `command -v` fallback selection with the exact runner-generated absolute `QINAO_RG_EXECUTABLE`; replace ambient `swift` with `QINAO_SWIFT_EXECUTABLE`; use literal absolute paths for `cat`, `tail`, `find`, `wc`, `tr`, `dirname`, and other platform children. Rewrite `check_god_files.sh` to enumerate NUL-delimited regular Git/worktree paths without `for $(find ...)` word splitting. The runner brackets every admitted executable stat/digest before and after the target, and the result binds those projections.

Remove the generic scripts-directory insertion from `check_chenglu_schema_parity.py`. The sterile loader admits only its exact `chenglu_feature_schema.py` dependency and records both blobs; the target may not mutate any import structure. Task 9 performs the same removal while converting `test_chenglu_feature_schema.py` to `unittest`. Runtime tests plant a hostile same-name module beside, above, and in ignored state and prove none is loaded.

The outer `check_qinao_import_boundaries.sh` delegates to redaction and SDK checks only in standalone mode; literal runner-owned `QINAO_BOUNDARY_MATRIX_MODE=1` suppresses those two because the next two ordered matrix commands execute them separately. In the same mode `check_sdk_import_boundaries.sh` suppresses its residual delegate because the next matrix command executes the residual shim/scanner once. Missing means standalone, `1` means matrix, and every other value fails. Tests require equal aggregate semantics and exactly one execution of each of the six top-level gates in both modes, including the one residual marker leaf. A direct legacy invocation without the sterile runner fails with one guidance line rather than silently falling back to ambient Python/PATH. Each result binds the exact Git-tree projection for Qinao package/build/symbol inputs, SDK import roots, BAS source/test/README residual inputs, the Chenglu Swift/Python pair, and all god-file scan roots; a symlink, missing/extra input, dirty unbound input, or changed projection fails. Re-run the graph test until it proves every reachable executable/module/environment/temp/input output, then run the new redaction unit fixtures.

- [ ] **Step 4B: Acquire only missing public archives, then materialize a fully offline Rust closure**

Write `CargoVendorClosureTests` before importing anything. They parse `BehavioralAISubstrate/Cargo/Cargo.lock` with a closed TOML subset, require every non-workspace `registry+https://github.com/rust-lang/crates.io-index` package to have a name/version/checksum and reject any Git, alternate-registry, checksum-free, duplicate, path-escape, link, device, socket, or unknown source. The tests initially fail because no repository-local vendor/config/manifest closure exists.

Under the already open parent `TASK8_FRONTIER_ID`, open its one admitted `cargo-archive-census` local-resource child frontier and run `census-cargo-archives` with both IDs plus an explicit absolute source-Cargo-home argument; inherited `HOME`, `CARGO_HOME`, registry token, credentials file, proxy, and network configuration are ignored. The census treats that home only as untrusted read-only input and reads no Cargo config/index/source directory. For every locked registry package it searches only ordinary `.crate` files under descriptor-opened `registry/cache/<one-level-index>/`, recomputes the lock checksum, accepts multiple candidates only when their bytes are identical, and copies one matching archive by O_EXCL into `RESOURCE_DIR/archives/<checksum>.crate`. It records all candidate path/stat/digests and emits one canonical exact missing-package manifest. A symlink, nonregular file, checksum collision, lock/source ambiguity, undeclared archive selected for output, or scan/read drift blocks with the partial generation preserved. The census itself never starts Cargo or a socket. If the missing set is empty, keep this child frontier open only long enough to run the aggregate-seal procedure below and complete it as `completed-zero-missing`; if nonempty, snapshot/seal its census resource and terminally close it as `completed-with-missing` before opening the acquisition successor child. The parent Task 8 frontier remains open throughout.

When the missing manifest is nonempty, after that census child is terminal `completed-with-missing`, allocate one successor `cargo-archive-acquisition` resource-only network-read child bound to `TASK8_FRONTIER_ID`, the census seal, and an ordered exact request manifest, and admit only the Task 8 public-crate importer. Before any DNS or socket, allocate a fresh mode-0700 `cargo-archive-egress-preflight` capture for the next request row and run `crate-egress-preflight --parent-frontier-id TASK8_FRONTIER_ID --frontier-id FRONTIER --lock BehavioralAISubstrate/Cargo/Cargo.lock --missing-manifest MANIFEST --request-manifest REQUESTS --request-id ID --output RECORD`. This command is pure local inspection: it opens no socket and reads no credential source. It O_EXCL-emits and seals one canonical `qinao.public-crate-egress.v1` record containing exactly the parent Task 8 and child frontier/ledger identities; lock path/blob/digest; missing-manifest, request-manifest, and selected-row digests; selected `{logicalKey,name,version,checksum,url,method,headers,maxBytes}`; endpoint `{scheme:"https",host:"static.crates.io",port:443}`; interpreter/standard-library/OpenSSL/default-CA/TLS projection; explicit absence of proxy, credential, cookie, custom-CA, token, referer, query, range, conditional, and content-decoding inputs; per-request and whole-lineage aggregate bounds/bytes; predecessor attempt/outcome identities (exact `null` for the first generation); `stableProjectionDigest`; and a self-excluding `preflightDigest`. `stableProjectionDigest` hashes exactly the endpoint, adapter/schema, interpreter/standard-library/OpenSSL/default-CA/TLS, absence, and bound-limit projection; it excludes the request row/logical key, observation time, capture/frontier/generation/predecessor identity, actual bytes already consumed, and record digest, so distinct permitted rows can prove the same egress environment while each full `preflightDigest` still binds its exact request and lineage. Unknown fields, a URL supplied by the caller, unsealed parents, a different/completed Task 8 parent, an already published vendor closure, or a nonempty forbidden input fails before allocation can become usable.

Immediately before each request, reopen that sealed record, recompute its full current projection, and require both byte identity and stable-projection equality with the first selected preflight in the acquisition lineage. Then call only `acquire-cargo-archives --frontier-id FRONTIER --request-manifest REQUESTS --request-id ID --preflight RECORD --output-directory ARCHIVES`. The subcommand is legal only in the local ledger profile while the exact Task 8 acquisition frontier is open; CI, another task/frontier, a committed vendor closure, a different logical key, or a caller-supplied URL rejects before socket creation. The standard-library client derives the URL as `https://static.crates.io/crates/<percent-encoded-name>/<percent-encoded-name>-<percent-encoded-version>.crate`, permits only DNS/TCP/TLS for literal host `static.crates.io:443`, uses the preflight-bound system OpenSSL/default CA with hostname verification, sends one `GET` with `Accept-Encoding: identity`, and sends no credential, cookie, referer, proxy, query, range, or conditional header. Status must be 200; redirect, authentication challenge, content encoding, more than 64 MiB per archive or 256 MiB total, checksum mismatch, extra response bytes, or a second request for the same logical key **within one acquisition generation** fails. Before transport, the wrapper appends/fsyncs one attempt record binding the exact request row, public-crate preflight path/digest/stable projection, frontier, generation, and predecessor; afterward it persists only URL/checksum/status/header-name/size/TLS-projection digests—not bodies or secrets—beside O_EXCL archive bytes. There is no automatic retry and Task 11's later GitHub preflight can never substitute for this endpoint-specific record.

Recovery selects exactly one state per logical key: `sealed-unconsumed`, `checksum-complete`, `forensic-incomplete`, or `transport-indeterminate`. A sealed-unconsumed preflight may be used only after the immediate projection recheck; a checksum-complete archive is rehashed and consumed without another GET. Every incomplete/indeterminate generation and partial archive is preserved. Before allocating a successor, the recovery classifier snapshots the current resource, emits a typed `read-incomplete` outcome binding every attempt/outcome and the exact still-missing set, and closes that resource-only frontier through the ledger's existing sole incomplete terminal state `tainted-preserved`; it does not invent another terminal enum. This terminal classification is neither archive success nor remote-mutation proof, but it guarantees no predecessor frontier remains open. Because GET has no server-side mutation, a successor acquisition generation may contain only that exact still-missing logical-key set; every repeated key must carry its own explicit predecessor attempt/outcome link plus a newly sealed public-crate preflight, while a never-attempted key links to the predecessor generation and exact `null` attempt. One request per logical key remains the limit inside that successor generation, and the 256 MiB cap is enforced over the entire predecessor/successor lineage rather than reset per generation. Unlinked or multiple live successors, a reused preflight/attempt, a changed stable projection, or any write-like method blocks. System network permission is an execution prerequisite, not an authority field or reusable approval token.

After every locked key is `checksum-complete`—immediately after census for an empty missing set, otherwise under the last live acquisition successor—freeze every contributing resource with `snapshot-resource`, allocate one fresh `cargo-archive-union` capture, and run `seal-cargo-archive-union`. It accepts only the active terminalizable census/acquisition child of the exact still-open `TASK8_FRONTIER_ID` and emits one canonical `qinao.cargo-archive-union.v1` manifest plus its exact capture whitelist. The manifest contains exactly `parentTaskFrontierId=TASK8_FRONTIER_ID`; the lock path/blob/digest and sorted complete locked package set; census resource/seal/snapshot identities; original missing/request key sets; the ordered complete acquisition predecessor chain; every request-row, public-crate preflight, attempt/outcome (including historical `transport-indeterminate` reads), resource snapshot, and archive `{logicalKey,name,version,checksum,size,resourceGenerationId,relativePath}` identity; whole-lineage requested/received byte counts; one stable-projection digest when acquisition occurred or exact `null` otherwise; `missingKeys=[]`; `duplicateKeys=[]`; `unclassifiedAttempts=[]`; `terminalizingArchiveFrontier={id,kind,state:"open-terminalizable"}`; `otherOpenArchiveFrontiers=[]`; `allChecksumsVerified=true`; and a self-excluding `unionDigest`. It requires exactly one checksum-correct ordinary archive per locked package, exact set equality with the lock, all referenced generations immutable and terminal except the named child being completed, total bytes within the lineage cap, and no partial/unlinked/live archive sibling. A historical transport-indeterminate GET remains visible but cannot supply archive bytes; only a later checksum-complete linked generation closes that key. A source-cache path, ambient Cargo home, mtime choice, or caller-selected archive is forbidden.

Seal that aggregate capture, then call `frontier-complete` on the exact `terminalizingArchiveFrontier` with parent `TASK8_FRONTIER_ID`, the union seal path/digest, and all contributing terminal records/snapshots. The child terminal record's only success states are `completed-zero-missing` and `completed-acquisition`; both bind the same union schema and, after the append/fsync, independently require the ledger's live projection to contain `openArchiveFrontiers=[]` and exactly the unchanged parent Task 8 frontier still open before materialization. Recovery has a closed suffix: if all archive/resource snapshots are complete but the aggregate capture is absent/incomplete, preserve the partial capture and deterministically allocate one successor capture without another GET; if the aggregate seal exists but child-terminal fsync/output was lost, `frontier-complete --recover-exact` reopens and returns the byte-identical terminal; a second valid aggregate seal, changed resource snapshot, missing key, different parent, or open archive predecessor blocks. `materialize-cargo-vendor` may consume only this unique aggregate seal through its child-terminal record while that same Task 8 parent remains open, never an ad hoc directory union or per-key success record.

`materialize-cargo-vendor` consumes only the terminal aggregate archive-union seal and does **not** call `cargo vendor`, read a Cargo home, or depend on Cargo's private registry layout. Using standard-library gzip/tar streaming, it requires one exact `<name>-<version>/` archive root and descriptor-validates every member before writing: only unique directories and bounded regular files; no absolute/`..`/NUL/control path, link, device, FIFO, socket, sparse entry, duplicate, Unicode-normalization/case-fold collision, out-of-root PAX path, archive-provided `.cargo-checksum.json`, or write outside the never-used `vendor.out/<name>-<version>/`. It streams regular bytes to O_EXCL files, verifies aggregate/member bounds and the outer crate checksum, normalizes only reviewed `0644`/`0755` modes, computes every file digest, and creates canonical `.cargo-checksum.json` with the locked package checksum plus exact file checksums. Its `files` object contains exactly every extracted regular file and deliberately excludes the generated `.cargo-checksum.json` itself; a missing, extra, duplicate, or self-entry fails. Adversarial archives exercise traversal, links, duplicate names, archive-supplied checksum records, case-fold collisions, decompression bombs, malformed gzip/tar, and interrupted extraction. Then validate the exact package set and generate the canonical `qinao.cargo-vendor-manifest.v1` record. It contains exactly `schemaVersion`, the Cargo-lock and Cargo-config path/mode/Git-blob/SHA-256 identities, digest-only fields `archiveUnionDigest`, `archiveUnionTerminalDigest`, and `archiveUnionSchemaVersion`, sorted package `{name,version,source,checksum,vendorDirectory,licenseExpression,licenseFiles}` records, every sorted vendor-file `{path,mode,gitBlobOid,sha256,size}` record, an exact reviewed source/license-disposition digest, and a self-excluding `manifestDigest`; unknown/missing license provenance is an explicit blocking disposition, not silently accepted. The portable tracked record forbids a local ledger/capture/seal path, resource/capture/generation/frontier ID, source-cache path, Cargo-home path, username, hostname, or other host identity. Runtime captures separately bind the archive census/acquisition/preflight/union/extraction records and paths. Local Task 8 proves those three portable digest fields against the terminal union; later local/CI candidate validation checks their exact schema/digest shape together with the complete vendor closure but neither attempts to reopen a Task 8 local ledger nor claims to have independently reconstructed the archive-acquisition history. Task 10 assigns the entire vendor closure to dependency/provenance plus workflow-automation-security review.

Create the exact `.cargo/config.toml` with only crates.io replacement to `vendored-sources`, `directory = "vendor"`, and `[net] offline = true`. Publish the verified absent `vendor.out` to absent `BehavioralAISubstrate/Cargo/vendor` with the same descriptor-relative no-clobber primitive used by the ledger; publish the config and manifest through their declared Task 8 edit frontier. A restart reopens the frontier and either proves the published vendor/config/manifest byte-identical or allocates a new resource; it never overlays, deletes, or resumes a partial tree. `verify-cargo-vendor` enumerates the complete Git tree at the requested revision—not merely filesystem glob output—recomputes every manifest tuple, proves the lock/config blobs, license/source dispositions, and package set, and runs before every Rust target. Finally run `cargo metadata --frozen` with a fresh empty private `CARGO_HOME` and a socket-attempt fixture; success must depend only on the tracked vendor closure. Any need for the network is a hard implementation blocker, not an implicit build prerequisite.

- [ ] **Step 5: Implement bounded execution**

Resolve every executable to an absolute canonical regular executable before creating the child environment. Each invocation gets:

```python
environment = {
    "HOME": str(private_home),
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "PATH": resolved_minimal_path,
    "TMPDIR": str(private_tmp) + os.sep,
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_OPTIONAL_LOCKS": "0",
}
```

Tool resolution never consumes inherited `HOME`, `PATH`, `DEVELOPER_DIR`, `CARGO_HOME`, or `RUSTUP_HOME`. Locally, the Task 3 ledger admits only explicitly enumerated system/Xcode/Homebrew/rustup roots after path-component ownership/mode, symlink-chain, executable hash/version, and companion-tool closure are frozen. In CI, the profile admits only `/usr/bin`/`/bin`, `/Applications/Xcode*.app` selected by `/usr/bin/xcrun`, and direct pairs below the exact `CI_RUNNER_HOME/.rustup/toolchains/*/bin` closure beneath the case-derived hosted root. Multiple installed Rust versions are expected: enumerate all direct `cargo`/`rustc` pairs, reject mismatched pairs, sort compatible stable releases satisfying `rust-version` by parsed version descending then raw path bytes, and select the unique highest release; two byte-different candidates at that same release block. Invoke the selected direct binaries rather than a rustup proxy, supply a fresh empty private `CARGO_HOME`, leave `RUSTUP_HOME` absent, require the tracked offline source replacement and verified vendor manifest, and set `PATH` to that frozen toolchain directory plus the exact linker/archiver/C-compiler companion closure and `/usr/bin:/bin` only for Rust children.

Hosted-runner, local rustup, and Homebrew toolchains may be owned and writable by the expected job/developer UID; they are explicitly candidate/environment evidence, not authority. Require the expected owner, reject group/world-writable components and changing symlink chains, recursively snapshot every executable/companion stat and digest immediately before and after each Rust target, and fail on drift. The companion closure is derived from frozen `rustc -vV`/target facts and exact `xcrun --find` results, then path/hash/version bound before Cargo starts; an unlisted build-script child executable is `incomplete`. A wrong owner, unbracketed writable toolchain, tool mismatch, registry/cache write outside the private `CARGO_HOME`, or a child resolving another executable is `incomplete`. Xcode/Swift children receive only the observed absolute `DEVELOPER_DIR` returned by the frozen `/usr/bin/xcrun`; arbitrary developer-directory inheritance is rejected.

Before any Rust command, require exactly one tagged `RustSourceIdentity`; the three modes are mutually exclusive and every result records the tag plus its complete digest:

1. `task8-frontier` is legal only for Task 8 `toolchain-report --source-mode frontier` before its commit. It reopens the exact open Task 8 frontier, declared dirty/staged paths, terminal archive-union seal, and sealed vendor/config/manifest publication resource; it loads the workspace config and fixed Seatbelt-template bytes only from those descriptor-bound frontier paths and binds their blob-style/SHA-256/resource identities. It has no `H` or `V` and emits only `claimScope="task8-precommit-smoke"`.
2. `committed-revision` is legal only for Task 8's post-commit `toolchain-report --source-mode revision --revision TASK8_COMMIT` and its paired `verify-cargo-vendor`. It requires that exact commit to be the one-parent result of the same Task 8 frontier, reopens config/vendor/manifest/template from its Git tree, and binds the commit/tree and exact source blobs directly. It has no `H` or `V` and cannot satisfy a candidate result.
3. `candidate-policy` is mandatory for every later local/CI matrix Rust target. It reopens the checked-out candidate/post-merge/supplemental revision through its typed identity, requires the exact workspace config and Seatbelt-template source blob to be bound by that revision's verified policy digest `V`, and emits the candidate/post-merge/supplemental claim scope already defined by the identity binder.

For all three modes, descriptor-walk from `BehavioralAISubstrate/Cargo` to filesystem root and reject every ancestor `.cargo/config` or `.cargo/config.toml` except the one exact workspace config selected by that source identity; require the new private `CARGO_HOME` to contain no config, credentials, registry, git, or preexisting file. The runner writes the exact `CARGO_TARGET_DIR` below its result root and generates one O_EXCL Seatbelt profile from the selected fixed source-template bytes and canonical parameters. Every Cargo command, compiler/build-script descendant, discovered test executable, and ignored-test listing runs under frozen `/usr/bin/sandbox-exec -f PROFILE` with no fallback. The profile denies every network operation, denies process execution outside the frozen toolchain/system companion paths plus newly built regular executables under `CARGO_TARGET_DIR`, and denies file writes outside exact descriptor-validated private `HOME`, `TMPDIR`, `CARGO_HOME`, `CARGO_TARGET_DIR`, result/log roots, and `/dev/null`; all repository/vendor/toolchain/system/Xcode inputs are read-only. It also denies reads below the real developer/runner home except the exact frozen toolchain and declared run/repository roots, preventing a vendored build script from harvesting unrelated user files into logs. Profile parameters are canonical absolute non-symlink paths, never string-concatenated policy fragments. Tests exercise all three legal modes and require failure before Cargo for a missing/extra tag, frontier/revision/`H`/`V` substitution, cross-mode config/vendor/template reuse, post-Task-8 frontier reuse, revision-parent drift, or claim-scope promotion.

The execution result binds the `/usr/bin/sandbox-exec` stat/digest, raw profile bytes/digest, parameter projection, pre/post writable-root inventories, complete executable inventory below `CARGO_TARGET_DIR`, and terminal sandbox status. Integration fixtures build a malicious local crate whose `build.rs` and test binary separately try TCP/UDP/Unix sockets, DNS, writes to the repository/parent/home/unrelated `/tmp`, reads a planted private-home marker, and executes an undeclared external helper; every attempt is kernel-denied while normal writes/execution below target/tmp succeed. Absence, unsupported Seatbelt syntax, profile drift, a sandbox-denial parser ambiguity, external write/read marker, or a Rust child outside the sandbox is `incomplete`; the plan makes no cross-platform fallback claim because all selected local/CI Rust jobs run on macOS.

The dispatcher executes `qinao_pr_validation.py` in-process and supplies a frozen read-only `ExecutionProfile` object through the closed loader API; it is not an environment variable, ambient singleton, or caller JSON. That object contains only already verified repository/run roots, profile kind, executable/toolchain projections, and—under CI—the case-derived runner root/workflow identity. Production execution entry rejects a missing object; pure unit functions receive an explicit typed fixture. Nested shim processes reconstruct the same object from their exact literal profile arguments and must produce an equal projection digest before running the declared leaf scanner.

Use `start_new_session=True`, concurrent bounded stdout/stderr reads, target deadline, five-minute aggregate teardown/evidence margin outside the target deadline, SIGTERM then SIGKILL for the full process group, and cleanup verified by descriptor/path identity. A leader that exits while descendants survive is failure. Maximum output is 64 MiB per stream for Swift/Cargo/Xcode and 16 MiB otherwise; one excess byte is `incomplete`.

Never interpolate shell data. Matrix commands are argv arrays plus a closed adapter name. The `sequence` adapter runs fixed argv entries serially and records one subresult per entry.

`run-ci-target --identity RECORD --target ID --output RESULT` reopens exactly one of the three Task 3 CI identity schemas and the current workflow/policy blobs. For `qinao.ci-identity.v1` it emits candidate-scoped results bound to `(B,H,T,V,bodyDigest)`; for `qinao.ci-push-identity.v1` it emits post-merge/supplemental results bound to `(before,after,parents,tree,V)`; for `qinao.ci-supplemental-identity.v1` it emits `claimScope="supplemental-only"`. The semantic token `@CHECKED_OUT_REVISION@` maps only to candidate `H`, main-push `after`, or supplemental `eventCommit`, each of which must equal checked-out `HEAD`; the identity-normalization record preserves the original field name and schema. Candidate-only `@B@`/`@T@` are illegal under push/supplemental identities, and no missing token is synthesized from another field. Schema/target/event/token mismatches or claim promotion fail. The CI allowlist is exact: baseline jobs may run only their mapped target(s), and `qinao-protocol-tests` may run only `protocol-units`, `workflow-contract-static`, and `repository-automation-static`. Local Task 11 remains the only source of the complete thirteen-target pre-merge matrix; CI results never substitute for it.

- [ ] **Step 6: Implement structured parsers from real formats**

- `unittest`: parse exactly one terminal `Ran N tests in ...` followed by `OK`; `N>0`; reject `skipped=`, failure/error, early/trailing contradictory summary, or truncated output.
- Swift XCTest: require strict xUnit with no DTD/entity, unique testcase IDs, exact counters, and the reviewed skip baseline. The authoritative BAS command disables Swift Testing. Record the four later best-effort Swift Testing batches from `swift-test-headless.sh` as limitations, not passed tests.
- Xcode: invoke the preserved `run_nonempty_xcode_test.py`; require `target=SampleHostTests`, positive discovered/executed, zero skipped/failed/expected-failure/incomplete, and evidence SHA-256.
- Cargo: parse the `--no-run --message-format=json` stream, require complete valid JSON lines, and collect each unique `profile.test=true` executable with its package ID and target name. Invoke each canonical executable with `--ignored --list --format terse`; prefix every listed test with that package/target identity, reject duplicate or undiscovered harnesses, and require the terminal test-name set (which must be globally unique) to be exactly:
  `test_perf_benchmark_1000_prompts`,
  `test_perf_benchmark_c_abi_round_trip`,
  `bench_batched_vs_per_call`.
- Then aggregate every actual `cargo test` `test result:` summary, require each result `ok`, total passed positive, zero failed, and require its aggregate ignored count to equal the discovery set. Fixtures cover exact success, one missing ID, one extra ID, duplicate terminal names, malformed compiler-artifact JSON, a missing executable, and a harness that was compiled but not listed.
- Static/document/build: adapters return exact enumerated/checked/failed counts rather than treating exit zero alone as evidence.

Add captured success/failure fixture text to the test module as byte literals; do not invoke real Swift/Xcode/Cargo from unit tests.

- [ ] **Step 7: Capture and review the full-suite skip baseline**

Start with an empty baseline and run `bas-xctest` and `qinao-xctest` once in the isolated implementation worktree. The expected initial result is `incomplete` if any skip occurs. Extract exact runtime test IDs and reasons from xUnit, review each against source and environment, and create:

```json
{
  "schemaVersion": "qinao.full-suite-skip-baseline.v1",
  "targets": [
    {
      "targetId": "bas-xctest",
      "testIds": [
        {
          "id": "Module.Suite/testName",
          "reason": "Exact runtime reason from the structured report",
          "environment": "macOS hosted/local headless",
          "owner": "single-developer",
          "reviewPolicy": "Any identity/reason/count change is incomplete and requires review."
        }
      ]
    }
  ]
}
```

The real file contains the observed exact IDs, not the illustrative entry. Source-text `XCTSkip` hits are only discovery aids and cannot populate the baseline automatically. Re-run both targets and require the observed set to match exactly.

- [ ] **Step 8: Verify realistic local toolchain facts**

The sterile Task 8 prelude reopens the one task frontier as `TASK8_FRONTIER_ID` and allocates a fresh mode-0700 `phase=task8-toolchain-precommit` capture as `TASK8_PRECOMMIT_CAPTURE_DIR`, both verified from the ledger rather than inherited. This is a TDD smoke report over the exact frontier-declared dirty/staged paths and the sealed, not-yet-committed vendor/config/manifest resource; it is explicitly not revision, `H`, or final evidence. Capture through the same execution profile and runner used by the matrix—never through an ambient tool name:

```bash
qinao_python scripts/qinao_pr_validation.py toolchain-report \
  --repository "$WT" \
  --frontier-id "$TASK8_FRONTIER_ID" \
  --source-mode frontier \
  --output "$TASK8_PRECOMMIT_CAPTURE_DIR/toolchain-report.json"
```

`toolchain-report` uses only the already bracketed absolute execution-profile paths. It runs the exact Python/interpreter projection query, `swift --version`, `xcodebuild -version`, `xcrun --find xcodebuild`, `xcrun --find xcresulttool`, runtime/device enumeration, direct selected `rustc --version`, direct selected `cargo --version`, vendor verification, and `cargo metadata --frozen --no-deps --format-version 1` through the same bounded adapters, private homes, ancestor-config proof, and Rust Seatbelt profile described above. In `source-mode=frontier`, vendor verification must bind every frontier path to its descriptor/blob-style/SHA-256 identity and sealed resource lineage and must reject any undeclared dirty path; the record carries `claimScope="task8-precommit-smoke"` and cannot satisfy a revision consumer. The output is one O_EXCL canonical record with every argv/path/stat/digest/version, sandbox/config/vendor identity, stdout/stderr digest/count, and terminal status; no naked subprocess exists beside the runner. Tests replace PATH/config/home with hostile fixtures and prove the same projections are selected.

Do not claim a pinned Rust toolchain: the repository has `rust-version="1.84"` but no `rust-toolchain.toml`. Record the selected observed version in evidence. Record iOS 18 manifests/iOS 27 nonconformance as a separate limitation; do not run `check-ios27-floor.sh`, CoreAI E2E, device smoke, endurance, benchmark, or DS3.

- [ ] **Step 9: Run unit tests and commit**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_convergence_audit \
  scripts.test_qinao_pr_protocol \
  scripts.test_qinao_workflow_inventory \
  scripts.test_qinao_pr_validation \
  scripts.test_check_sovereign_redaction \
  scripts.test_run_nonempty_swift_filter \
  scripts.test_run_nonempty_xcode_test
git add \
  scripts/qinao_pr_validation.py \
  scripts/test_qinao_pr_validation.py \
  scripts/check_sovereign_redaction.py \
  scripts/test_check_sovereign_redaction.py \
  scripts/check_sovereign_redaction.sh \
  scripts/check_qinao_import_boundaries.sh \
  scripts/check_sdk_import_boundaries.sh \
  scripts/check_substrate_residuals.sh \
  scripts/check_substrate_residual_markers.sh \
  scripts/check_chenglu_schema_parity.py \
  scripts/check_god_files.sh \
  BehavioralAISubstrate/Cargo/.cargo/config.toml \
  BehavioralAISubstrate/Cargo/vendor \
  docs/superpowers/evidence/2026-08-29-qinao-cargo-vendor-manifest.v1.json \
  docs/superpowers/validation/qinao-pr-validation-matrix.v1.json \
  docs/superpowers/validation/qinao-full-suite-skip-baseline.v1.json
git commit --no-verify --no-gpg-sign -m "feat: add typed candidate validation matrix"
TASK8_COMMIT="$(git rev-parse HEAD^{commit})"
test -z "$(git status --short)"
qinao_python scripts/qinao_pr_validation.py toolchain-report \
  --repository "$WT" \
  --frontier-id "$TASK8_FRONTIER_ID" \
  --source-mode revision \
  --revision "$TASK8_COMMIT" \
  --output "$TASK8_POSTCOMMIT_CAPTURE_DIR/toolchain-report.json"
qinao_python scripts/qinao_pr_validation.py verify-cargo-vendor \
  --repository "$WT" \
  --revision "$TASK8_COMMIT" \
  --manifest docs/superpowers/evidence/2026-08-29-qinao-cargo-vendor-manifest.v1.json
```

For the post-commit suffix, the sterile prelude allocates a fresh mode-0700 `phase=task8-toolchain-postcommit` capture as `TASK8_POSTCOMMIT_CAPTURE_DIR`; recovery selects it by frontier ID and phase, never pathname time. Only this `source-mode=revision` report is authoritative: it requires `TASK8_COMMIT` to contain exactly the declared Task 8 delta, reopens vendor/config/manifest and the full vendor-file set from that commit's Git tree, proves a clean worktree, and binds the commit/tree plus post-commit tool/sandbox results. The Task 8 frontier may complete only after this record and `verify-cargo-vendor` succeed. If the commit exists but the report is absent/incomplete, recovery preserves the partial capture and creates a fresh post-commit capture only after proving the commit, tree, declared paths, clean status, precommit resource lineage, and protected witness unchanged; it creates no replacement commit. A complete post-commit report is reopened byte-for-byte and never regenerated. Expected: all unit tests pass with nonzero counts; the committed skip baseline contains only reviewed real observations; the Task 8 terminal record binds the authoritative post-commit report digest.

### Task 9: Retire the active admission workflow and establish minimal read-only CI

**Files:**
- Delete: `.github/workflows/qinao-wave-admission.yml`
- Modify: `.github/workflows/test.yml`
- Create: `.github/pull_request_template.md`
- Create: `docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json`
- Modify: `scripts/test_chenglu_feature_schema.py`
- Test: `scripts/test_qinao_pr_protocol.py`
- Test: `scripts/test_qinao_workflow_inventory.py`

**Interfaces:**
- Consumes: preserved six baseline jobs, new protocol CLI, nonempty Xcode runner, and finite workflow contract.
- Produces: one active workflow with read-only candidate jobs and one stateless PR-body check; no host-setting changes.

- [ ] **Step 1: Write failing workflow contract tests against the post-`C` baseline**

Tests parse the exact active workflow bytes as a constrained contract and require:

- triggers exactly `push`, `pull_request`, and `workflow_dispatch`;
- top-level `permissions: {}`;
- each checkout job has only `contents: read`;
- the only external action is the exact pinned checkout already present after `C`:
  `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`;
- checkout uses `persist-credentials:false`, `submodules:false`, `lfs:false`, `set-safe-directory:false`;
- no environment, secrets expression, self-hosted runner, artifact/cache action, reusable workflow, dynamic `uses`, or write permission;
- no former admission variables, owner-ledger gate, managed-convergence runner, iOS 27 JIT group, or historical iOS-floor job;
- stable unique job/check names;
- every PR-running job checks out the exact event head and emits one valid `qinao.ci-identity.v1` record before its validation command;
- every one of the seven jobs that runs on a `main` push emits one valid future-safe `qinao.ci-push-identity.v1` record before validation;
- every non-main push or `workflow_dispatch` job emits one `qinao.ci-supplemental-identity.v1` record with an unpromotable supplemental-only claim before validation, so each event has exactly one applicable binder;
- `.github/workflows/qinao-wave-admission.yml` is absent at `H` but its `C` blob is recorded in retirement evidence.

Tests fail against `C` because the former `qinao-gates`, `qinao-ios27-floor`, and admission workflow are still active.

- [ ] **Step 2: Run the contract tests and confirm the expected failure**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_workflow_inventory.WorkflowContractTests
```

Expected: failures naming the old active surfaces, not a YAML parse crash.

- [ ] **Step 3: Delete only the active admission workflow**

Delete `.github/workflows/qinao-wave-admission.yml` with `apply_patch`. Do not delete or rewrite its historical implementation/evidence blobs. Record in the final diff inventory:

```text
retirement reason: workflow_dispatch/JIT source-admission controller conflicts with the approved ordinary Git/manual-PR route
historical source: exact blob at C
forward replacement: no admission workflow; ordinary PR evidence and fresh human merge decision
rollback: reviewed revert PR only
```

- [ ] **Step 4: Remove only the two obsolete jobs from `test.yml`**

Remove `qinao-gates` and `qinao-ios27-floor`, including old external replay variables and JIT runner configuration. Preserve the six baseline job IDs:

```text
bas-tests
qinao-tests
samplehost-tests
boundary-checks
python-fuzz
rust-tests
```

Preserve the top-level empty permissions and the pinned checkout OID from `4a`; remove the now-unused `actions/setup-python` step rather than letting it mutate PATH for a launcher that deliberately uses the observed system interpreter. Correct the Rust comment so it states the observed compiler is captured and the workspace lockfile plus tracked offline vendor closure are enforced; do not claim a nonexistent pinned `rust-toolchain.toml`.

- [ ] **Step 4A: Make every CI `run` step enter the sterile profile independently**

Add this exact workflow default; an individual step may not override it:

```yaml
defaults:
  run:
    shell: /usr/bin/env -i HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin /bin/bash --noprofile --norc -e -o pipefail {0}
```

Every `run: |` block begins with this literal prefix, with no command, expansion, or assignment before it:

```bash
set -euo pipefail
umask 077
GITHUB_WORKSPACE='${{ github.workspace }}'
RUNNER_TEMP='${{ runner.temp }}'
GITHUB_EVENT_PATH='${{ github.event_path }}'
case "$GITHUB_WORKSPACE" in
  /Users/runner/work/*) CI_RUNNER_HOME=/Users/runner ;;
  /home/runner/work/*) CI_RUNNER_HOME=/home/runner ;;
  *) exit 2 ;;
esac
case "$RUNNER_TEMP" in /Users/runner/work/_temp|/home/runner/work/_temp) ;; *) exit 2 ;; esac
case "$GITHUB_EVENT_PATH" in "$RUNNER_TEMP"/*) ;; *) exit 2 ;; esac
test "$(/bin/pwd -P)" = "$GITHUB_WORKSPACE"
test -d "$RUNNER_TEMP" && test ! -L "$RUNNER_TEMP"
test -f "$GITHUB_EVENT_PATH" && test ! -L "$GITHUB_EVENT_PATH"
WT="$GITHUB_WORKSPACE"
RUN_ROOT="$(/usr/bin/mktemp -d "$RUNNER_TEMP/qinao-sterile.XXXXXX")"
/bin/chmod 700 "$RUN_ROOT"
/bin/mkdir "$RUN_ROOT/home" "$RUN_ROOT/tmp"
/bin/chmod 700 "$RUN_ROOT/home" "$RUN_ROOT/tmp"
qinao_python() {
  /bin/test "$#" -ge 1
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" TMPDIR="$RUN_ROOT/tmp" \
    LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    /usr/bin/python3 -I -S -B \
    "$WT/scripts/qinao_convergence_audit.py" sterile-python --profile ci \
    --ci-runner-home "$CI_RUNNER_HOME" \
    --root "$RUN_ROOT" --repository "$WT" -- "$@"
}
```

The workflow AST test expands every literal block, requires this exact prefix and a nonempty command suffix, and rejects folded `run: >-`, step-level `shell`, an inherited/exported runner variable, direct `python`/`python3` outside the exact function, `BASH_ENV`, or any command before the prefix. It also proves `${{ github.workspace }}`, `${{ runner.temp }}`, and `${{ github.event_path }}` are the only GitHub expressions admitted inside the prefix and that they are used only as the three quoted assignments above; `CI_RUNNER_HOME` must be the literal case-derived value and never a context/environment read. For every block, tests concatenate the actual expanded prefix and actual suffix bytes, require `/bin/bash -n` success, then execute a no-network/no-product-mutation fixture with stubbed closed commands to prove the intended argv is one command rather than newline-split `--option` commands. The launcher records the exact `/usr/bin/env`, `/bin/bash`, `/bin/pwd`, `/bin/test`, `/usr/bin/mktemp`, `/bin/chmod`, `/bin/mkdir`, system interpreter, standard library, OpenSSL/default-CA, and closed module projections for that job; a different runner projection is visible evidence, never silently equated with the frozen local runtime. The exact runner-temp identity-file exception is tested for O_EXCL creation and read-only cross-step reopen; every other external runner-temp read/write is rejected. Later YAML excerpts show only the command suffix for readability; the committed workflow repeats the complete prefix in every block.

- [ ] **Step 5: Make SampleHost CI nonempty and structured**

Replace the separate naked build/test steps with one invocation of the preserved runner:

```yaml
      - name: SampleHost nonempty XCTest
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          set -euo pipefail
          XCODEBUILD="$(/usr/bin/xcrun --find xcodebuild)"
          XCRESULTTOOL="$(/usr/bin/xcrun --find xcresulttool)"
          qinao_python scripts/run_nonempty_xcode_test.py \
            --xcodebuild-executable "$XCODEBUILD" \
            --xcresulttool-executable "$XCRESULTTOOL" \
            --package-path SampleHost \
            --scheme SampleHost \
            --destination 'platform=iOS Simulator,name=iPhone 17e' \
            --derived-data-path "$RUN_ROOT/samplehost-derived-data" \
            --result-bundle-path "$RUN_ROOT/samplehost-result.xcresult" \
            --require-target SampleHostTests \
            --timeout-seconds 1800
```

Keep the job timeout at 45 minutes, leaving 15 minutes for checkout, tool discovery, result parsing, teardown, and logs.

- [ ] **Step 6: Remove the unpinned pytest install without losing any test**

The `C` blob has exactly 19 module-level `test_*` functions. Convert all 19—no subset—to methods of one `unittest.TestCase`; replace every `pytest.raises` with `self.assertRaisesRegex` and every bare assertion with the corresponding `self.assert*`, while preserving each test name and behavior. Remove its scripts-directory `sys.path.insert` and any now-unused `os` import; the closed loader supplies only the exact `chenglu_feature_schema` and `check_chenglu_schema_parity` module blobs already declared by the target. A test mutating `sys.path`, `sys.meta_path`, an importer cache, or an import hook fails before test execution. Do not add the illustrative duplicate-array case as a twentieth test: it already exists and must migrate in place.

```python
class ChengluFeatureSchemaTests(unittest.TestCase):
    def test_parse_swift_array_rejects_duplicates(self) -> None:
        source = (
            'public static let tones: [String] = ["a"]\n'
            'public static let tones: [String] = ["b"]\n'
        )
        with self.assertRaisesRegex(ValueError, "expected exactly 1"):
            parse_swift_array(source, "tones")

if __name__ == "__main__":
    unittest.main()
```

Add a contract test in `scripts/test_qinao_workflow_inventory.py` that loads the module through `unittest.defaultTestLoader`, recursively counts the suite, and requires exactly 19 unique test IDs. It fails if a module-level function is left undiscovered, a method is dropped, or a duplicate is introduced.

Change the CI step to:

```yaml
      - name: Run Python feature-schema tests
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python -m unittest -v scripts.test_chenglu_feature_schema
```

No `actions/setup-python` or `pip install` remains. The exact CI sterile profile records the system interpreter projection used by this test.

- [ ] **Step 7: Bind every PR CI result to exact `(B,H,T,V)` and add read-only protocol/metadata jobs**

For all nine PR-running jobs—the preserved six plus `qinao-protocol-tests`, `risk-check`, and `pr-metadata`—use the same pinned checkout input:

```yaml
      - name: Checkout exact PR head
        if: ${{ github.event_name == 'pull_request' }}
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
          persist-credentials: false
          submodules: false
          lfs: false
          set-safe-directory: false
      - name: Checkout supplemental event commit
        if: ${{ github.event_name != 'pull_request' }}
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          ref: ${{ github.sha }}
          fetch-depth: 0
          persist-credentials: false
          submodules: false
          lfs: false
          set-safe-directory: false
      - name: Bind PR candidate identity
        if: ${{ github.event_name == 'pull_request' }}
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python scripts/qinao_convergence_audit.py ci-bind \
          --repository "$GITHUB_WORKSPACE" \
          --event-path "$GITHUB_EVENT_PATH" \
          --output "$RUNNER_TEMP/qinao-ci-current-identity.json"
      - name: Bind merged main push identity
        if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python scripts/qinao_convergence_audit.py ci-push-bind \
          --repository "$GITHUB_WORKSPACE" \
          --event-path "$GITHUB_EVENT_PATH" \
          --output "$RUNNER_TEMP/qinao-ci-current-identity.json"
      - name: Bind supplemental event identity
        if: ${{ github.event_name == 'workflow_dispatch' || (github.event_name == 'push' && github.ref != 'refs/heads/main') }}
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python scripts/qinao_convergence_audit.py ci-supplemental-bind \
          --repository "$GITHUB_WORKSPACE" \
          --event-path "$GITHUB_EVENT_PATH" \
          --output "$RUNNER_TEMP/qinao-ci-current-identity.json"
```

The workflow contract requires exactly one applicable binding step to precede every validation step and requires its unique canonical log record. A binding failure fails the job. A `main` push run is post-merge evidence only and can never satisfy pre-merge candidate-required CI. Non-main push and `workflow_dispatch` runs remain explicitly supplemental.

Replace each preserved job's validation suffix with `qinao_python scripts/qinao_pr_validation.py run-ci-target --identity "$RUNNER_TEMP/qinao-ci-current-identity.json" ...` and this exact map: `bas-tests→bas-xctest`, `qinao-tests→qinao-xctest`, `samplehost-tests→samplehost-xctest`, `boundary-checks→boundary-static`, `python-fuzz→python-feature-tests`, and `rust-tests→[rust-build,rust-test]` in that order. `qinao-protocol-tests` runs `[protocol-units,workflow-contract-static,repository-automation-static]` in that order. Each target writes a separate canonical result below the step's private `RUN_ROOT`, logs its digest/counts, and no job contains a parallel direct invocation of Swift, Cargo, a boundary script, or Python. This makes the Step 4A prefix, resolved toolchain, nested-Python shim, timeout, parser, and nonempty rules the single CI execution path.

Add `qinao-protocol-tests` for all three event families. It checks out with the pinned action and `contents: read`, then uses the map above to run the seven standard-library unit modules and the two workflow inventory targets from Task 8.

Add PR-only `risk-check` with `contents: read`, the same exact-head checkout and identity step, followed by:

```yaml
      - name: Classify exact candidate diff risk
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python scripts/qinao_convergence_audit.py risk-check-event \
          --repository "$GITHUB_WORKSPACE" \
          --event-path "$GITHUB_EVENT_PATH" \
          --identity "$RUNNER_TEMP/qinao-ci-current-identity.json" \
          --output "$RUN_ROOT/qinao-risk-result.json"
```

It must emit a unique canonical risk record bound to the same tuple/body. For this policy/workflow-changing convergence candidate the only acceptable class is `high`. The check is candidate-controlled shadow evidence; Task 11 independently computes risk and, when the base already contains a reviewed risk implementation, also runs that base implementation. A changed/unknown risk implementation can only escalate.

Add `pr-metadata` with:

```yaml
  pr-metadata:
    name: Qinao PR metadata (informational)
    if: ${{ github.event_name == 'pull_request' }}
    runs-on: macos-latest
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
          persist-credentials: false
          submodules: false
          lfs: false
          set-safe-directory: false
      - name: Bind PR candidate identity
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python scripts/qinao_convergence_audit.py ci-bind \
          --repository "$GITHUB_WORKSPACE" \
          --event-path "$GITHUB_EVENT_PATH" \
          --output "$RUNNER_TEMP/qinao-ci-current-identity.json"
      - name: Validate exact PR metadata block
        run: |
          # The committed block first repeats the exact Step 4A prefix.
          qinao_python scripts/qinao_pr_protocol.py \
          validate-event-metadata \
          --event-path "$GITHUB_EVENT_PATH"
```

The CLI reads `pull_request.body` from the event JSON as data; it never interpolates the body into a shell command. It emits only validation status and a body SHA-256. The job is candidate-controlled informational evidence and is never described as protected-base trust.

The `pull_request` trigger explicitly includes `opened`, `synchronize`, `reopened`, and `edited`. A machine-block/body edit therefore creates a new PR-event run. Task 13 accepts only the latest terminal run set for the exact current body digest and exact `(B,H,T,V)`; earlier green runs become supplemental stale evidence.

- [ ] **Step 7A: Freeze the exact active-workflow contract**

Generate the closed contract projection described in Task 7 from the reviewed final `test.yml`; compute the prospective Git blob OID with `git hash-object` without `-w`, record its raw SHA-256 and every semantic field, and add the contract. Contract tests compare the actual bytes and projection, require only `.github/workflows/test.yml` active and no local action, and reject any source/contract mismatch. A workflow reviewer must inspect the raw file and contract together before commit.

- [ ] **Step 8: Add the lightweight PR template**

The template has human headings for outcome, risk, changed surfaces, validation, review findings/dispositions, limitations, rollback, forward recovery, and irreversible effects. It explains that the machine block is generated with:

```bash
qinao_python scripts/qinao_pr_protocol.py render-metadata --input pr-metadata.json
```

It includes the exact start/end markers but no approval checkbox, merge token, stored authorization, sample success claim, or prefilled evidence digest. A manually opened PR is intentionally metadata-incomplete until the generated canonical object is inserted.

- [ ] **Step 9: Define separate event behavior**

- `pull_request`: all six baseline jobs and the protocol job emit candidate identity, run their exact matrix target maps, then exact-diff risk and metadata validation run.
- `push` to existing configured branches: the six baseline jobs and protocol job run their maps; a `main` push emits post-merge identity in every one of those seven jobs, while each other configured branch emits supplemental identity. PR metadata/risk are skipped and neither push class is interpreted as pre-merge candidate success.
- `workflow_dispatch`: the six baseline jobs and protocol job emit supplemental identity and run their maps; PR metadata/risk are skipped.

No step reads `github.event.pull_request.*` unless that step/job is explicitly guarded to `pull_request`; validation commands never receive event text through shell interpolation. A skipped informational metadata job on non-PR events is not part of any required-evidence claim.

- [ ] **Step 10: Run workflow, protocol, and feature tests**

```bash
qinao_python -m unittest -v \
  scripts.test_chenglu_feature_schema \
  scripts.test_check_sovereign_redaction \
  scripts.test_qinao_pr_protocol \
  scripts.test_qinao_pr_validation \
  scripts.test_qinao_workflow_inventory \
  scripts.test_run_nonempty_xcode_test
git diff --check
```

Expected: nonzero tests and `OK`; workflow tests prove the forbidden surface is absent.

- [ ] **Step 11: Review and commit the retirement/CI change**

```bash
git diff -- .github scripts/test_chenglu_feature_schema.py
git add \
  .github/workflows/test.yml \
  .github/pull_request_template.md \
  docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json \
  scripts/test_chenglu_feature_schema.py \
  scripts/test_qinao_pr_protocol.py \
  scripts/test_qinao_workflow_inventory.py
git add -u .github/workflows/qinao-wave-admission.yml
git commit --no-verify --no-gpg-sign -m "ci: adopt read-only single-owner PR evidence"
```

Expected: deletion of one active admission workflow, removal of two obsolete jobs, preservation of six baseline jobs, three read-only evidence jobs, and no host mutation.

### Task 10: Add forward-policy invariants and the complete review configuration

**Files:**
- Modify: `scripts/test_qinao_convergence_audit.py`
- Modify: `scripts/test_qinao_pr_protocol.py`
- Modify: `scripts/test_qinao_workflow_inventory.py`
- Create: `docs/superpowers/evidence/2026-08-29-qinao-pr-review-configuration.v1.json`

**Interfaces:**
- Consumes: exact `C`, active workflow contract/matrix, plan/spec inventory, review schema, and synthetic raw-entry fixtures. It does not consume the real `B→H` manifest, which does not exist until Task 11.
- Produces: a deterministic forward-policy test suite and closed review partition/configuration included in `V`; Task 11 applies those rules to the real raw manifest and freezes the only accepted assignment record.

- [ ] **Step 1: Write a failing active-reference test**

Scan only forward-active consumers:

- `.github/workflows/**`;
- `.github/actions/**`;
- `docs/superpowers/validation/**`;
- `.github/pull_request_template.md`;
- new protocol/audit/validation/inventory modules.

Require no invocation/import/reference that treats these as forward gates:

```text
run_qinao_wave_admission.py
prepare_qinao_v2_wave_candidate.py
run_qinao_managed_convergence.py
check_qinao_owner_ledger.py
qinao-owner-ledger-v1.json
qinao_a02_provisional_design_edge.py
qinao_a03_design_source_identity.py
qinao_ds1_evidence_vault.swift
check-ios27-floor.sh
run-coreai-e2e-cert.sh
Deep Scan 3 launch/rejoin/restart/wait surfaces
```

Historical plan/spec/evidence/tool source may mention them. The test checks consumers, not a repository-wide keyword ban.

- [ ] **Step 2: Write a failing non-authority test**

Inspect the Python AST and closed call graph with role-specific rules, rather than applying an impossible repository-wide string ban. `qinao_pr_protocol.py` and every pure parser/normalizer/validator remain non-authority code and must contain no network executor, subprocess transport, GitHub mutation method/path, `git push`, merge command, approval-consumption/durable-authorization concept, old controller/admission import, or DS3 launcher/scheduler/waiter; every remote observation enters them only as data.

`qinao_convergence_audit.py` may contain transport only in the enumerated sealed executors `network-git`, `network-gh`, `git-credential-auth-read`, `lfs-batch-observe`, and the closed quarantine composition. `qinao_workflow_inventory.py` may contain the corresponding finite request renderers, but no transport. `qinao_pr_validation.py` may spawn only the exact matrix/toolchain/Seatbelt children and may open a socket only inside `acquire-cargo-archives`; `crate-egress-preflight` is a separate pure local producer of the closed `qinao.public-crate-egress.v1` schema and cannot resolve DNS or open a connection. `seal-cargo-archive-union` and `materialize-cargo-vendor` are pure local descriptor-based consumers: the former must terminally seal the exact census/acquisition lineage before its frontier can close, and the latter accepts only that unique terminal `qinao.cargo-archive-union.v1` seal. The importer call graph must require the open Task 8 archive-acquisition frontier, a sealed exact request manifest, the matching sealed public-crate preflight and predecessor lineage, derive the static-crates URL from the sealed lock/request row, use the one closed standard-library HTTPS adapter, and be unreachable in CI or after vendor publication. AST/call-graph tests require every allowed method/path/argv literal to be owned by one enumerated executor/renderer/importer/preflight-producer/union-sealer tuple, schema/preflight/frontier bound, and unreachable from pure policy/approval code; all other network/subprocess call sites or dynamic operation/path selection fail. The admitted GitHub set includes the exact-lease candidate push and exact POST/PATCH/comment/native-merge requests required later, while branch-protection/ruleset/settings/ref-deletion/workflow-control mutation remains absent everywhere. No executor, renderer, importer, preflight producer, or union sealer may decide approval, authorize itself, retry an unknown mutation, broaden an endpoint, or consume a PR/audit/status as durable authorization. This preserves the non-authority boundary without rejecting the plan's own narrowly specified I/O implementation.

- [ ] **Step 3: Define the review configuration**

The canonical JSON contains four complete partitions:

```json
{
  "schemaVersion": "qinao.review-configuration.v1",
  "partitions": [
    {
      "id": "identity-history-documents",
      "scopeRules": ["convergence topology", "protected 33-path state", "all plan/spec transformations", "newly reachable history/object disclosure"],
      "requiredProducer": "fresh Codex reviewer"
    },
    {
      "id": "protocol-jcs-recovery",
      "scopeRules": ["metadata", "risk", "RFC 8785", "V/A/E", "timeline chunks", "unknown outcomes"],
      "requiredProducer": "fresh Codex reviewer"
    },
    {
      "id": "workflow-automation-security",
      "scopeRules": ["workflow", "permissions", "actions", "host/app inventory", "cross-trigger flows", "complete Git-object egress and LFS presence closure"],
      "requiredProducer": "fresh Codex reviewer"
    },
    {
      "id": "validation-testing-operations",
      "scopeRules": ["matrix", "test semantics", "timeouts", "review/merge/post-merge procedures"],
      "requiredProducer": "fresh Codex reviewer"
    }
  ],
  "coverageRule": "Every raw diff entry is assigned to at least one partition; control, binary, generated, vendor, LFS, and document entries receive an explicit disposition.",
  "terminalRule": "All four reviews and one integration review are terminal on the same B/H/T/V; every finding is fixed, evidence-backed false-positive, or evidence-backed disputed-impact awaiting exact user disposition; incomplete and confirmed-actionable findings block.",
  "supplementalProducer": "CodeRabbit CLI 0.7.5 when authenticated and terminal; never a substitute for the required complete review."
}
```

Arrays have schema-defined order. The file uses these exact, ordered assignment rules over each raw entry's destination path (or deletion old path), status, modes, and content class:

1. `identity-history-documents`: all `docs/superpowers/plans/**`, `docs/superpowers/specs/**`, `.gitattributes`, LFS pointer/binary provenance, deletion/rename/copy/type/mode changes, every entry whose source/final object participates in convergence or recovery evidence, and the complete newly reachable commit/tree/blob/tag disclosure manifest.
2. `protocol-jcs-recovery`: `scripts/qinao_convergence_audit.py`, `scripts/qinao_pr_protocol.py`, their tests, the evidence schema, PR template machine block, document disposition/inventory, and any entry touching identity, hashing, serialization, chunking, unknown outcomes, push/PR/comment/merge recovery, or approval-audit rendering.
3. `workflow-automation-security`: every `.github/**` entry; `scripts/qinao_workflow_inventory.py` and tests; workflow contract; permissions/triggers/actions/runner/secret/environment/artifact/cache/data-flow/host-observation code; `.gitattributes`, the presence-only LFS Batch boundary, and every sensitive/large/binary/generated/vendor/recovery/full-commit-or-tag-field candidate in the remote-object disclosure.
4. `validation-testing-operations`: `scripts/qinao_pr_validation.py` and tests; validation matrix/skip baseline/review config; every source, test, dependency/lockfile, build/boundary runner, workflow validation command, merge/post-merge procedure, and any raw entry not captured by rules 1–3.

Assignment is additive, so a control file may enter several partitions. Rule 4 is a visible fallback assignment for review coverage, not risk downgrading; unknown content already classifies high. The configuration rejects an entry with zero partition IDs, a nonexistent path, an assignment unsupported by a rule, or a rule shadowed by display-path decoding. Task 11 evaluates rules against raw base64 paths and freezes `{rawManifestSha256, entryId, partitionIds}` sorted by entry ID. Task 13 gives exactly that assignment record—not a recomputed or hand-selected subset—to reviewers.

Review output is one canonical object with exactly:

```json
{
  "schemaVersion": "qinao.review-result.v1",
  "reviewId": "partition-or-integration-id",
  "producer": {"name": "Codex", "versionOrMethod": "exact method"},
  "startedAt": "RFC3339 UTC",
  "finishedAt": "RFC3339 UTC",
  "identity": {"B": "oid", "H": "oid", "T": "tree", "V": "digest"},
  "configurationBlobOid": "oid",
  "rawManifestSha256": "digest",
  "assignmentSha256": "digest",
  "coveredEntryIds": ["sorted stable raw-entry ID"],
  "terminalState": "complete|incomplete",
  "findings": [],
  "artifactSha256": "self-excluding digest"
}
```

Each finding has exactly `id`, `severity`, `state`, `rawEntryIds`, `pathB64`, `title`, `evidence`, `fixCommit`, and `dispositionEvidenceSha256`. IDs match `^[a-z0-9][a-z0-9.-]{2,79}$`; severity is `critical|high|medium|low`; state is `fixed|false-positive|disputed-impact|incomplete`. Evidence is a nonempty ordered array of closed `{kind,locator,sha256}` records. `fixed` requires a fix commit reachable from `H` plus a fresh review of the corrected tuple; `false-positive` requires concrete applicability evidence; `disputed-impact` requires concrete code/effect evidence, forces effective high risk, and later requires exact user disposition; `incomplete` covers any still-actionable, unknown, truncated, or unverified finding and blocks. A confirmed actionable issue cannot be represented as `false-positive` or accepted by user waiver. Integration review consumes exactly the four specialist record digests, full raw manifest, assignment, validation, and automation evidence, then emits the same schema with `reviewId="integration"` and must account for every specialist finding ID.

- [ ] **Step 4: Test review coverage**

Fixtures require:

- every raw diff entry assigned at least once;
- no nonexistent path;
- every `.github`, policy, evidence, binary, LFS, generated, and vendor path assigned to the relevant specialist;
- each finding satisfies the exact schema and one of `fixed/false-positive/disputed-impact/incomplete`;
- no `incomplete` or confirmed-actionable finding remains; every `disputed-impact` is retained for explicit Task 14 user disposition;
- all producer results bind the identical `(B,H,T,V)`;
- truncated/running/error/unknown review is incomplete.

- [ ] **Step 5: Run invariants**

```bash
qinao_python -m unittest -v \
  scripts.test_qinao_convergence_audit \
  scripts.test_qinao_pr_protocol \
  scripts.test_qinao_pr_validation \
  scripts.test_qinao_workflow_inventory
```

Expected: every test passes. Also run `git diff --check`.

- [ ] **Step 6: Commit**

```bash
git add \
  scripts/test_qinao_convergence_audit.py \
  scripts/test_qinao_pr_protocol.py \
  scripts/test_qinao_workflow_inventory.py \
  docs/superpowers/evidence/2026-08-29-qinao-pr-review-configuration.v1.json
git commit --no-verify --no-gpg-sign -m "test: enforce Qinao forward policy boundaries"
```

Expected: one test/configuration commit; no production or host mutation.

### Task 11: Freeze `H`, construct `B/T/V`, run the complete local matrix, and close the diff inventory

**Files:**
- No new tracked path is required
- Produce local non-sensitive evidence under a mode-0700 candidate directory below the repository's absolute Git common directory: `qinao-evidence/<tuple-digest>/`

**Interfaces:**
- Consumes: clean implementation branch, all policy/config blobs, full matrix, complete plan/spec inventory, and a freshly advertised/imported remote `main` object.
- Produces: immutable candidate tuple `(B,H,T,V)`, raw diff manifest, LFS/binary inventory, typed local results, and an exact restart rule.

Every local topology/tree/diff/object command in this task uses the same `sterile_git` wrapper as Task 2: `/usr/bin/env -i`, the Task-2 private HOME, `LANG/LC_ALL=C`, system/global config and attributes disabled, replacements/lazy fetch/pager/prompts disabled, LFS filters neutralized, hooks/signing/rerere/autostash disabled, and `/usr/bin/git --no-pager --no-optional-locks --no-replace-objects -C "$WT"`. Recreate the function in each shell process; plain `git -C "$WT"` in explanatory snippets means this wrapper for local object semantics, never ambient Git. Network-only `fetch/ls-remote/push` retains the separately reviewed credential plumbing but still sets no-smudge/no-hooks/no-replacements/no-lazy-fetch explicitly. Every fetch is additionally bound to the exact remote advertisement and the fixed negotiation/maintenance/submodule flags below; ambient local refs never select negotiation tips.

Before computing any merge tree, require the common and worktree Git `info/attributes` files to be absent (not merely ignored), record any `refs/replace/**` but prove the wrapper disables them, reject local `extensions.partialClone`, `remote.*.promisor`, or `remote.*.partialclonefilter`, and run an object-closure missing check over `B` and `H` with lazy fetch disabled. A missing/promised object, alternate attribute source, or ambient config dependency is incomplete. Unit/integration fixtures inject each condition and require failure.

- [ ] **Step 1: Require a clean implementation branch and exact ancestry**

```bash
set -euo pipefail
test -n "$WT"
COMMON_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -d "$RUN_ROOT/home"
sterile_git() {
  /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_AUTHOR_NAME='Qinao convergence' GIT_AUTHOR_EMAIL=qinao-convergence@invalid.local \
    GIT_COMMITTER_NAME='Qinao convergence' GIT_COMMITTER_EMAIL=qinao-convergence@invalid.local \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.autocrlf=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c commit.gpgSign=false -c merge.gpgSign=false \
    -c merge.autoStash=false -c rerere.enabled=false -C "$WT" "$@"
}
test -z "$(sterile_git status --porcelain=v1 --untracked-files=all)"
H0="$(sterile_git rev-parse HEAD^{commit})"
D="$(sterile_git rev-parse --verify refs/qinao/recovery/git-only-design-tip^{commit})"
C="$(
  sterile_git rev-list --first-parent HEAD |
  while IFS= read -r oid; do
    parents="$(sterile_git show -s --format=%P "$oid")"
    if test "$parents" = "4a9298db261bcfda97ea1748baad65649156ba66 $D"; then
      printf '%s\n' "$oid"
    fi
  done
)"
test "$(printf '%s\n' "$C" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
test "$(sterile_git rev-list --parents -n 1 "$C")" = "$C 4a9298db261bcfda97ea1748baad65649156ba66 $D"
sterile_git merge-base --is-ancestor "$C" "$H0"
```

Expected: clean branch and exact convergence parent order.

- [ ] **Step 1A: Freeze the network-egress route before the first Git/GitHub/LFS network read**

Before allocating any preflight output, recover the main convergence ledger, require no open frontier, and validate the complete terminal-frontier suffix as a closed chain anchored at clean `task10-completed`. Every later terminal frontier must consume the immediately preceding result HEAD/digest and be exactly one of: (a) `task11-base-merge` in `completed`/`recovered-completed` state, binding ordered parents `[startHead,B]`, predicted/result tree, full raw commit/config/protected witnesses, and an `otherParent` not already merged by an earlier identical transition; or (b) `task11-review-fix` in `completed`/`recovered-completed` state, binding a one-parent result commit plus exact finding/evidence/declared-path/failing-test/index-tree/secret-scan/config/protected digests. Current `H0` must equal the final result (`task10` HEAD when the suffix is empty). An unlinked/skipped/duplicated frontier, a repeated no-op base OID, any other Task 11 terminal kind, or any open/indeterminate intent blocks. Through the main ledger, allocate one `phase=preflight-root` generation with input digest binding repository/common-dir, `C/D/H0`, branch, the exact latest admitted frontier ID/record digest and complete admitted-chain digest, local config projection, exact remote URL, tool versions, and allowed phase set. Safely create/validate a mode-0700, non-symlink parent `$COMMON_GIT_DIR/qinao-preflight`, set `PREFLIGHT_ROOT="$COMMON_GIT_DIR/qinao-preflight/$PREFLIGHT_ID"`, and call committed Task 3 `init-run-state --profile preflight` with capture phases exactly `{network-egress,remote-auth-gh,remote-auth-git,remote-advertisement,remote-main}` and local resource/frontier kinds exactly `{fetch-quarantine,remote-main-import}`. These are literal finite sets, not wildcard prefixes: a build-time test extracts every `allocate-capture --root "$PREFLIGHT_ROOT" --phase LITERAL` occurrence from the execution contract and requires set equality with the identity allowlist, while resource/frontier literals are checked separately. The root's initial atomic chain names the parent allocation/frontier and expected absolute path. Run `recover-captures` from a new process before continuing. An incomplete root initialization is preserved and a fresh preflight-root generation may be allocated; a different/malformed published identity, path collision, or unexpected phase blocks. No network command may precede this terminal initialization.

Now allocate `phase=network-egress` inside that initialized ledger and run `network-egress-preflight` locally into the fresh capture before `gh auth status`, `ls-remote`, fetch, or the LFS presence observer. Require the exact Git fetch/push URL, LFS Batch endpoint, executable identities, effective-config projection, absent/safe `.lfsconfig`, credential-helper projection, and zero forbidden environment/config surface described in Task 3. Recover the sealed record path as `NETWORK_PREFLIGHT_RECORD` and define these functions byte-for-byte in every new shell process:

```bash
NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST="$(qinao_python \
  scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$NETWORK_PREFLIGHT_RECORD" --print-field stableProjectionDigest)"
qinao_network_git() {
  qinao_python scripts/qinao_convergence_audit.py network-git \
    --preflight "$NETWORK_PREFLIGHT_RECORD" "$@"
}
qinao_gh() {
  qinao_python scripts/qinao_convergence_audit.py network-gh \
    --preflight "$NETWORK_PREFLIGHT_RECORD" "$@"
}
```

Every call spells `--intent`, the closed `--operation`, and `--` before child argv. Every Git/GitHub network command from here through Task 15 explicitly calls one of these functions; a fence that shows plain `git` is local-only and must instead use `sterile_git`/`postmerge_git`. There is no ambient-command abbreviation or fallback. Invoke LFS only through the committed `lfs-batch-observe` client. Captured stdout/stderr never enables trace/debug, and no credential/helper response is persisted.

Bind the resulting `qinao.network-egress.v1` record digest **and** `stableProjectionDigest` into the preflight ledger and later tuple evidence. For each initial-main attempt, call Task 3 `allocate-resource --kind fetch-quarantine` to create a never-used mode-0700 bare generation `resources/fetch-quarantine.<resource-id>.git` with an empty template and scrubbed system/global config; prove/snapshot zero refs, zero loose/packed objects, absent alternates/shallow/promisor files, absent submodule config, and no configured remote before its first network call. Open one **resource-only network-fetch** frontier. A generation is selected as `FETCH_QUARANTINE` only after its exact `main=B` ref, fetch outcome, object-closure check, before/after recursive resource snapshots, capture manifest, and that frontier's completion are terminal. A timeout, open frontier, or snapshot mismatch taints and preserves that resource; a fresh empty resource generation may repeat this read, and no quarantine is cleaned or reused after an unclosed mutation. Only after the fetch frontier closes, take a complete `snapshot-git-state` of the shared repository and open a separate **local `remote-main-import` Git-state** frontier binding exact source resource/snapshot/B, destination-ref absence, before-state digest, and allowed object/ref delta. Its deterministic local import has the explicit continuation/recovery states in Step 2 and can never terminate as `tainted-preserved`. Later remote fetches likewise use resource-only frontiers and unique quarantine refs; every subsequent shared import uses its own Git-state frontier. Re-run the preflight immediately before the approved LFS presence query, branch push, PR create/PATCH/comment, and merge; require a fresh valid record whose `stableProjectionDigest` equals the selected baseline, while binding that fresh record's own digest/generation into the new intent. A newly reviewed credential-helper generation deliberately changes the stable projection and invalidates all earlier intents. Any other destination/config/executable/environment drift invalidates the pending intent before side effects. This deliberately closes the gap where ambient global/system Git config could redirect a reviewed object set to another push/LFS endpoint.

- [ ] **Step 1B: Preflight remote authentication before the first GitHub network read**

Before Task 11 Step 2, allocate three fresh captures under the already initialized durable preflight ledger. For `phase=remote-auth-gh`, render the closed `remote-auth-gh` request rows (`gh auth status --hostname github.com`, fixed-header `GET /user`, fixed-header `GET /repos/ChangGeng01/ProjectSix`, and the read-only Actions permission/workflow probes), seal them with `seal-network-request-manifest`, recover the returned manifest path as `AUTH_READ_INTENT`, and execute each exact row once through `qinao_gh`. Validate its complete safe projections, write the exact whitelist, and immediately call `seal-capture`; retain the terminal record as `GH_AUTH_CAPTURE_SEAL`. For `phase=remote-auth-git`, render/seal the two fixed REST rows plus credential-fill input profile, recover it as `GIT_CREDENTIAL_AUTH_INTENT`, execute exactly one `git-credential-auth-read --preflight "$NETWORK_PREFLIGHT_RECORD" --intent "$GIT_CREDENTIAL_AUTH_INTENT"`, validate the projection, and immediately seal the capture as `GIT_AUTH_CAPTURE_SEAL`; this proves the credential generation actually used by ordinary Git independently of the `gh` credential. For `phase=remote-advertisement`, render/seal the exact `network-git ls-remote --refs --branches --tags origin` row, bind both auth seals as ordered parents, and execute it once through `qinao_network_git`; safe-capture emits the validated projection as `REMOTE_ADVERTISEMENT_RECORD`/digest. Write no other file, then immediately `seal-capture` and retain `REMOTE_ADVERTISEMENT_SEAL` plus its independently reopened `sealDigest`. Every output basename, exact argv, method/path/header, parent seal path/digest, and maximum use is frozen before execution; none of the three allocation records is itself an intent. A resource/frontier allocation in Step 2 is rejected until all three terminal capture seals reopen exactly. Crash fixtures cover allocation, every row, whitelist, seal fsync/lost stdout, and prove restart reuses a unique sealed generation or explicitly supersedes one forensic-incomplete read generation—never appending to it.

Require both authenticated identities to be the repository owner, the Git credential's own scope/permission proof to satisfy the workflow-file rule below, the `gh` repository projection to report admin/push/pull and all required read surfaces, private metadata read to succeed, the scoped advertisement to contain exactly one `refs/heads/main`, and no prompt/token text in any safe projection. The `gh` and Git credential-generation fingerprints may differ, but neither can satisfy the other's proof. Probe no mutation. Do **not** probe Git LFS Batch yet: even a presence-only Batch request discloses candidate OID/size metadata, so LFS authentication remains explicitly unproven until Task 12 can query only the locally classified and independently approved OIDs.

Because `H` modifies/deletes `.github/workflows/**` over HTTPS, ordinary contents push permission alone is insufficient. Before the LFS presence query or Git push, require authoritative metadata for the **same Git-transport credential generation** proving permission to update workflow files: for a classic OAuth/PAT credential, its authenticated response exposes both repository access and `workflow`; for a fine-grained token/App, repository `Contents:write` and `Workflows:write` must both come from trustworthy grant metadata for that exact generation. The ordinary fine-grained/PAT-over-Git path has no assumed introspection shortcut: when trustworthy grant metadata is absent, this is an external precondition and execution blocks rather than testing with a push. This permission authorizes only Git content updates to the reviewed workflow paths; Actions dispatch/enable/disable/settings, workflow API mutation, status, deployment, package, release, ruleset, and protection writes remain forbidden. Any 401/403/404 ambiguity, invalid `gh` token, failed ordinary-Git credential path, credential-generation drift, or scope uncertainty stops before fetch/advertisement.

The minimum capability table is recorded **per credential generation**, never as one blended owner capability. The Git-transport generation must prove repository read/candidate-branch push plus workflow-file Git update (`repo`+`workflow` for classic, or authoritative `Contents:write`+`Workflows:write`). The independently fingerprinted `gh` generation must prove repository metadata/administration read; Actions/settings/runners/secrets/variables/environments/hooks/collaborators read; **Checks read**; **Commit statuses read**; **Pages read**; **Deployments read**; pull requests read plus write for create/PATCH; issue-or-PR-comment write for timeline records; and **Contents:write for the native `PUT /pulls/{number}/merge` operation**, in addition to any pull-request permission. For a classic credential, prove the covering scopes; for a fine-grained token/App, require authoritative repository permission fields for each applicable capability. A Git proof cannot fill a `gh` row and a `gh` proof cannot fill a Git row; an uninspectable fine-grained grant is an external precondition. Installation-grant enumeration is deliberately not listed as a normal-token capability: Task 12 records the credential-type visibility limitation instead of requesting a GitHub App user access token. No Actions workflow-control/settings mutation, check/status mutation, deployment, Pages, package, release, ruleset, or protection write is requested. Task 12 repeats this endpoint/method/capability/credential-generation table before every mutation and again before approval. This preflight proves only current identity/readability and declared host permissions—it never manufactures missing authorization or exposes a credential. Endpoint-specific 401/403/ambiguous 404 is `unknown`; only a permission-proved Pages-read plus `has_pages=false` may classify the documented disabled 404.

- [ ] **Step 2: Fetch only `main` through the proven-empty quarantine**

The first network fetch executes only inside the proven-empty quarantine, so it sends no local `have`. It writes a previously nonexistent quarantine ref, then a network-disabled local fetch imports that exact ref into a previously nonexistent shared evidence namespace. Before/after ref and object-state manifests prove the only shared ref addition; the quarantine is retained.

```bash
set -euo pipefail
WT="$(git worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
RESOURCE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-resource \
  --root "$PREFLIGHT_ROOT" --kind fetch-quarantine \
  --template empty-bare-git --print-field resourceId)"
FETCH_QUARANTINE="$PREFLIGHT_ROOT/resources/fetch-quarantine.$RESOURCE_ID.git"
test -d "$FETCH_QUARANTINE"
test -z "$(sterile_git -C "$FETCH_QUARANTINE" for-each-ref --format='%(refname)')"
test ! -e "$FETCH_QUARANTINE/objects/info/alternates"
test -z "$(find "$FETCH_QUARANTINE/objects" -type f ! -path '*/info/*' -print -quit)"
INITIAL_RESOURCE_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$PREFLIGHT_ROOT" --resource-id "$RESOURCE_ID" \
  --state initial-empty-bare --print-field snapshotDigest)"
QUARANTINE_MAIN_REF="refs/qinao/remote-main/$RESOURCE_ID"
REMOTE_MAIN_REF="refs/qinao/remote-main/$RESOURCE_ID"
test -z "$(sterile_git for-each-ref --format='%(refname)' "$REMOTE_MAIN_REF")"
FETCH_FRONTIER_ID="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$PREFLIGHT_ROOT" --kind fetch-quarantine --recover-exact \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --stable-projection "$NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST" \
  --resource-id "$RESOURCE_ID" --input-snapshot "$INITIAL_RESOURCE_DIGEST" \
  --remote-ref refs/heads/main --quarantine-ref "$QUARANTINE_MAIN_REF" \
  --advertisement-capture "$REMOTE_ADVERTISEMENT_SEAL" \
  --remote-advertisement "$REMOTE_ADVERTISEMENT_DIGEST" \
  --print-field frontierId)"
FETCH_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$PREFLIGHT_ROOT" --frontier-id "$FETCH_FRONTIER_ID" \
  --print-field startRecordPath)"
qinao_network_git --intent "$FETCH_INTENT_RECORD" --operation fetch-empty -- \
  -C "$FETCH_QUARANTINE" -c core.hooksPath=/dev/null fetch \
  --no-tags --no-auto-maintenance --no-write-commit-graph \
  --no-recurse-submodules --no-write-fetch-head \
  https://github.com/ChangGeng01/ProjectSix.git \
  "refs/heads/main:$QUARANTINE_MAIN_REF"
B="$(sterile_git -C "$FETCH_QUARANTINE" rev-parse "$QUARANTINE_MAIN_REF^{commit}")"
test "$(sterile_git -C "$FETCH_QUARANTINE" cat-file -t "$B")" = commit
EXPECTED_ADVERTISED_MAIN_OID="$(qinao_python scripts/qinao_convergence_audit.py \
  validate-remote-advertisement --record "$REMOTE_ADVERTISEMENT_RECORD" \
  --require-ref refs/heads/main --print-field refOid)"
if test "$B" != "$EXPECTED_ADVERTISED_MAIN_OID"; then
  RACE_RESOURCE_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
    snapshot-resource --root "$PREFLIGHT_ROOT" --resource-id "$RESOURCE_ID" \
    --state advertisement-race-tainted \
    --expected-ref "$QUARANTINE_MAIN_REF=$B" --print-field snapshotDigest)"
  qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$PREFLIGHT_ROOT" --frontier-id "$FETCH_FRONTIER_ID" \
    --recover-exact --state tainted-preserved \
    --result-snapshot "$RACE_RESOURCE_DIGEST" \
    --reason advertised-main-changed
  exit 75
fi
FINAL_RESOURCE_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$PREFLIGHT_ROOT" --resource-id "$RESOURCE_ID" \
  --state fetched-main --expected-ref "$QUARANTINE_MAIN_REF=$B" \
  --print-field snapshotDigest)"
FETCH_TERMINAL_RECORD="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$PREFLIGHT_ROOT" --frontier-id "$FETCH_FRONTIER_ID" --recover-exact \
  --state completed --result-snapshot "$FINAL_RESOURCE_DIGEST" \
  --result-ref "$QUARANTINE_MAIN_REF=$B" \
  --bound-advertised-ref "refs/heads/main=$EXPECTED_ADVERTISED_MAIN_OID" \
  --advertisement-capture "$REMOTE_ADVERTISEMENT_SEAL" \
  --print-field terminalRecordPath)"

SHARED_BEFORE_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
  --root "$PREFLIGHT_ROOT" --repository "$WT" \
  --require-ref-absent "$REMOTE_MAIN_REF" --state before-remote-main-import \
  --print-field snapshotDigest)"
IMPORT_FRONTIER_ID="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$PREFLIGHT_ROOT" --kind remote-main-import --recover-exact \
  --repository "$WT" --source-resource-id "$RESOURCE_ID" \
  --source-snapshot "$FINAL_RESOURCE_DIGEST" \
  --source-ref "$QUARANTINE_MAIN_REF=$B" \
  --destination-ref "$REMOTE_MAIN_REF=$B" \
  --input-git-state "$SHARED_BEFORE_DIGEST" --print-field frontierId)"
sterile_git -c core.hooksPath=/dev/null fetch \
  --no-tags --no-auto-maintenance --no-write-commit-graph \
  --no-recurse-submodules --no-write-fetch-head \
  "$FETCH_QUARANTINE" "$QUARANTINE_MAIN_REF:$REMOTE_MAIN_REF"
test "$(sterile_git rev-parse "$REMOTE_MAIN_REF^{commit}")" = "$B"
SHARED_AFTER_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
  --root "$PREFLIGHT_ROOT" --repository "$WT" \
  --compare-input "$SHARED_BEFORE_DIGEST" \
  --allow-source-resource "$RESOURCE_ID:$FINAL_RESOURCE_DIGEST" \
  --require-only-ref-addition "$REMOTE_MAIN_REF=$B" \
  --require-object-closure "$B" --state after-remote-main-import \
  --print-field snapshotDigest)"
IMPORT_TERMINAL_RECORD="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$PREFLIGHT_ROOT" --frontier-id "$IMPORT_FRONTIER_ID" \
  --recover-exact --state completed --repository "$WT" \
  --result-git-state "$SHARED_AFTER_DIGEST" --result-ref "$REMOTE_MAIN_REF=$B" \
  --source-frontier-terminal "$FETCH_TERMINAL_RECORD" \
  --print-field terminalRecordPath)"
REMOTE_MAIN_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$PREFLIGHT_ROOT" --phase remote-main \
  --parent-capture "$REMOTE_ADVERTISEMENT_SEAL" --print-field captureId)"
REMOTE_MAIN_CAPTURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$PREFLIGHT_ROOT" --capture-id "$REMOTE_MAIN_CAPTURE_ID" \
  --print-field absolutePath)"
qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$PREFLIGHT_ROOT" --emit-remote-main-result \
  --advertisement-capture "$REMOTE_ADVERTISEMENT_SEAL" \
  --fetch-terminal "$FETCH_TERMINAL_RECORD" \
  --import-terminal "$IMPORT_TERMINAL_RECORD" \
  --expected-ref "refs/heads/main=$B" --destination-ref "$REMOTE_MAIN_REF=$B" \
  --output "$REMOTE_MAIN_CAPTURE_DIR/remote-main.json" \
  --capture-files-output "$REMOTE_MAIN_CAPTURE_DIR/seal-files.txt"
REMOTE_MAIN_CAPTURE_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$PREFLIGHT_ROOT" --capture-id "$REMOTE_MAIN_CAPTURE_ID" \
  --files-from "$REMOTE_MAIN_CAPTURE_DIR/seal-files.txt" \
  --print-field sealRecordPath)"
printf 'B=%s\n' "$B"
```

Expected: the resource-only frontier closes before shared import begins; then one previously nonexistent private evidence ref equals the advertised `main`. No remote-tracking ref, `FETCH_HEAD`, submodule, commit-graph, MIDX, maintenance/config state, existing object byte, or other namespace changes; the after snapshot admits only valid immutable object additions from the exact `B` source closure plus `REMOTE_MAIN_REF=B`. Do not use `--prune`.

Exit `75` above is the sole closed advertisement-race result: preserve the resource and its terminal `tainted-preserved` frontier, perform a new scoped advertisement capture, allocate a new proven-empty quarantine, and restart Step 2. It is not a generic retry signal. The `completed` fetch-frontier validator independently requires `result-ref OID == bound-advertised-ref OID`; therefore no raced `main` object can be imported or merged before equality is proved.

At every Step 2 entry, first recover both frontier kinds. An open fetch-quarantine frontier is either reconciled to its exact complete resource snapshot or closed as resource-only `tainted-preserved` and replaced by a fresh empty generation; it never covers the shared repository. An open `remote-main-import` frontier uses `snapshot-git-state` to classify: `input-unchanged` reruns the same network-disabled local fetch; `attributable-objects-only` reruns it only when every addition is a valid content-addressed object reachable from the exact sealed source and the destination ref remains absent; `exact-poststate` appends `recovered-completed` without refetching; every other delta blocks. Because this second operation has no remote side effect and fixed immutable source/destination, those first two continuations are deterministic completion, not a new logical mutation. It may never use `tainted-preserved`. A lost start/completion response returns only the byte-identical record. `REMOTE_ADVERTISEMENT_DIGEST` and `REMOTE_ADVERTISEMENT_SEAL` are recovered from the sealed Step 1B capture, never ambient shell history; the displayed success path never reuses a tainted/open resource or bypasses either snapshot.

`recover-captures --emit-remote-main-result` is a pure, output-O_EXCL producer available only after both named frontiers are terminal. It reopens the parent advertisement seal/path/digest, fetch terminal/resource snapshot, import terminal/shared snapshot, and live immutable destination object; it requires exact `advertised main == fetched ref == imported ref == B`, then emits `qinao.remote-main-result.v1` with typed `ref`, `advertisedOid`, resource/frontier/snapshot IDs and digests, parent seal path/digest, and self-digest plus its exact whitelist. On restart, a unique sealed `remote-main` capture is reused; a single incomplete read-only result is explicitly superseded and regenerated from those same terminals; multiple/unlinked generations block. Step 5 consumes only this seal. Tests cover import-terminal fsync before result allocation, every result write/seal boundary, lost seal stdout, and producer/consumer field completeness.

- [ ] **Step 3: Reconcile a newly advanced base without rewriting `C`**

First recover any `tree-prediction` resource frontier. `merge-tree --write-tree` is forbidden against the shared object directory: it runs only with a fresh resource `GIT_OBJECT_DIRECTORY` and the shared objects exposed read-only as `GIT_ALTERNATE_OBJECT_DIRECTORIES`. An exact completed prediction resource supplies the tree/snapshot digest; an interrupted/partial prediction is closed only as local-resource `tainted-preserved` and replaced by a fresh empty object-directory generation, after proving the shared `snapshot-git-state` did not change. It is never imported into the shared repository. A crash immediately after `merge-tree` writes its tree is an explicit fixture and must leave only that resource generation changed.

Then run read-only `recover-captures --select-open-frontier-kind task11-base-merge --repository "$WT"` in a fresh process and consume its self-digest-verified canonical fields. It must classify exactly `none`, `intent-only`, `merge-prepared`, or `result-commit`: `intent-only` is the persisted start with exact clean `HEAD/index/preexisting Git-admin state` and no merge sequencer yet; `merge-prepared` adds exact `MERGE_HEAD/ORIG_HEAD/MERGE_MSG` and predicted conflict-free index; `result-commit` is the exact committed result with clean post-state but no completion record. The base-merge start binds the terminal prediction resource ID/snapshot/tree. The command block below retrieves the persisted ID/inputs, resumes the same frontier, and never re-samples them or opens a second frontier. Any other open frontier/state blocks.

Run:

```bash
set -euo pipefail
bootstrap_git() {
  /usr/bin/env -i HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_NO_REPLACE_OBJECTS=1 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects "$@"
}
DISCOVERY_ROOT="$(bootstrap_git -C "$PWD" rev-parse --path-format=absolute --show-toplevel)"
WT="$(bootstrap_git -C "$DISCOVERY_ROOT" worktree list --porcelain | \
  awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
test "$(printf '%s\n' "$WT" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
COMMON_GIT_DIR="$(bootstrap_git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -d "$RUN_ROOT/home"
test -d "$RUN_ROOT/tmp"
cd "$WT"
qinao_python() {
  /bin/test "$#" -ge 1
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" TMPDIR="$RUN_ROOT/tmp" \
    LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    /usr/bin/python3 -I -S -B \
    "$WT/scripts/qinao_convergence_audit.py" sterile-python \
    --root "$RUN_ROOT" --repository "$WT" -- "$@"
}
PREFLIGHT_ROOT="$(qinao_python "$WT/scripts/qinao_convergence_audit.py" recover-captures \
  --root "$RUN_ROOT" --select-current-preflight-root --print-field absolutePath)"
REMOTE_MAIN_CAPTURE_SEAL="$(qinao_python "$WT/scripts/qinao_convergence_audit.py" \
  recover-captures --root "$PREFLIGHT_ROOT" --select-capture \
  --phase remote-main --state sealed --print-field sealRecordPath)"
REMOTE_MAIN_REF="$(qinao_python "$WT/scripts/qinao_convergence_audit.py" recover-captures \
  --root "$PREFLIGHT_ROOT" --select-capture --phase remote-main --state sealed \
  --require-seal-record "$REMOTE_MAIN_CAPTURE_SEAL" --print-field ref)"
B="$(qinao_python "$WT/scripts/qinao_convergence_audit.py" recover-captures \
  --root "$PREFLIGHT_ROOT" --select-capture --phase remote-main --state sealed \
  --require-seal-record "$REMOTE_MAIN_CAPTURE_SEAL" --print-field advertisedOid)"
sterile_git() {
  /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    GIT_AUTHOR_NAME='Qinao convergence' GIT_AUTHOR_EMAIL=qinao-convergence@invalid.local \
    GIT_COMMITTER_NAME='Qinao convergence' GIT_COMMITTER_EMAIL=qinao-convergence@invalid.local \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.autocrlf=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c commit.gpgSign=false -c merge.gpgSign=false \
    -c merge.autoStash=false -c rerere.enabled=false -C "$WT" "$@"
}
test "$(sterile_git rev-parse "$REMOTE_MAIN_REF^{commit}")" = "$B"
base_frontier_field() {
  test "$#" = 1
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$RUN_ROOT" --select-open-frontier-kind task11-base-merge \
    --repository "$WT" --print-field "$1"
}
RECOVERY_STATE="$(base_frontier_field recoveryState)"
case "$RECOVERY_STATE" in
  none)
    H0="$(sterile_git rev-parse HEAD^{commit})"
    BASES="$(sterile_git merge-base --all "$B" "$H0")"
    test "$(printf '%s\n' "$BASES" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
    if sterile_git merge-base --is-ancestor "$B" "$H0"; then
      printf '%s\n' 'base already contained'
      exit 0
    fi
    if sterile_git merge-base --is-ancestor "$H0" "$B"; then
      printf '%s\n' 'candidate may already be landed or stale' >&2
      exit 2
    fi
    PREDICTION_SHARED_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py \
      snapshot-git-state --root "$RUN_ROOT" --repository "$WT" \
      --state before-tree-prediction --print-field snapshotDigest)"
    PREDICTION_RESOURCE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
      allocate-resource --root "$RUN_ROOT" --kind merge-tree-prediction \
      --template empty-git-object-dir --print-field resourceId)"
    PREDICTION_RESOURCE="$RUN_ROOT/resources/merge-tree-prediction.$PREDICTION_RESOURCE_ID"
    PREDICTION_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py \
      snapshot-resource --root "$RUN_ROOT" --resource-id "$PREDICTION_RESOURCE_ID" \
      --state initial-empty-object-dir --print-field snapshotDigest)"
    PREDICTION_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py \
      frontier-start --root "$RUN_ROOT" --kind tree-prediction --recover-exact \
      --resource-id "$PREDICTION_RESOURCE_ID" --input-snapshot "$PREDICTION_BEFORE" \
      --input-git-state "$PREDICTION_SHARED_BEFORE" \
      --left "$H0" --right "$B" --print-field frontierId)"
    PREDICTED_BASE_MERGE_TREE="$(
      /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_SYSTEM=/dev/null GIT_NO_REPLACE_OBJECTS=1 \
        GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 \
        GIT_OBJECT_DIRECTORY="$PREDICTION_RESOURCE/objects" \
        GIT_ALTERNATE_OBJECT_DIRECTORIES="$COMMON_GIT_DIR/objects" \
        /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
        -c core.hooksPath=/dev/null -C "$WT" \
        merge-tree --write-tree --no-messages "$H0" "$B"
    )"
    /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
      GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
      GIT_CONFIG_SYSTEM=/dev/null GIT_NO_REPLACE_OBJECTS=1 GIT_NO_LAZY_FETCH=1 \
      GIT_OBJECT_DIRECTORY="$PREDICTION_RESOURCE/objects" \
      GIT_ALTERNATE_OBJECT_DIRECTORIES="$COMMON_GIT_DIR/objects" \
      /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
      -c core.hooksPath=/dev/null -C "$WT" \
      cat-file -e "$PREDICTED_BASE_MERGE_TREE^{tree}"
    PREDICTION_AFTER="$(qinao_python scripts/qinao_convergence_audit.py \
      snapshot-resource --root "$RUN_ROOT" --resource-id "$PREDICTION_RESOURCE_ID" \
      --state predicted-tree --require-object "$PREDICTED_BASE_MERGE_TREE:tree" \
      --print-field snapshotDigest)"
    PREDICTION_SHARED_AFTER="$(qinao_python scripts/qinao_convergence_audit.py \
      snapshot-git-state --root "$RUN_ROOT" --repository "$WT" \
      --compare-input "$PREDICTION_SHARED_BEFORE" --require-no-change \
      --state after-tree-prediction --print-field snapshotDigest)"
    qinao_python scripts/qinao_convergence_audit.py frontier-complete \
      --root "$RUN_ROOT" --frontier-id "$PREDICTION_FRONTIER" \
      --recover-exact --state completed --result-snapshot "$PREDICTION_AFTER" \
      --result-tree "$PREDICTED_BASE_MERGE_TREE" \
      --result-git-state "$PREDICTION_SHARED_AFTER"
    BASE_MERGE_FRONTIER_ID="$(
      qinao_python scripts/qinao_convergence_audit.py frontier-start \
        --root "$RUN_ROOT" --kind task11-base-merge --recover-exact \
        --repository "$WT" --start-head "$H0" --other-parent "$B" \
        --expected-tree "$PREDICTED_BASE_MERGE_TREE" \
        --prediction-resource "$PREDICTION_RESOURCE_ID:$PREDICTION_AFTER" \
        --message-sha256 568b504e30feb14b522993b17f060a897fa88e25e9dd052c7bf441a43fbfa5f4 \
        --message-literal 'Merge fresh main into Qinao convergence candidate' \
        --expected-parent "$H0" --expected-parent "$B" \
        --declared-git-state HEAD --declared-git-state index \
        --declared-git-state MERGE_HEAD --declared-git-state ORIG_HEAD \
        --declared-git-state MERGE_MSG --bind-clean-status \
        --bind-preexisting-git-admin-state --bind-config-projection \
        --bind-protected-witness --print-field frontierId
    )"
    RECOVERY_STATE=intent-only
    ;;
  intent-only|merge-prepared|result-commit)
    BASE_MERGE_FRONTIER_ID="$(base_frontier_field frontierId)"
    H0="$(base_frontier_field startHead)"
    FRONTIER_B="$(base_frontier_field otherParent)"
    test "$FRONTIER_B" = "$B"
    PREDICTED_BASE_MERGE_TREE="$(base_frontier_field expectedTree)"
    test "$(sterile_git rev-parse "$REMOTE_MAIN_REF^{commit}")" = "$B"
    ;;
  *)
    printf '%s\n' 'unrecoverable base-merge frontier state' >&2
    exit 2
    ;;
esac

if test "$RECOVERY_STATE" = result-commit; then
  H1="$(base_frontier_field inferredResultHead)"
  qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$RUN_ROOT" --frontier-id "$BASE_MERGE_FRONTIER_ID" \
    --recover-exact --state recovered-completed --repository "$WT" \
    --result-head "$H1" --expected-parent "$H0" --expected-parent "$B" \
    --expected-tree "$PREDICTED_BASE_MERGE_TREE" \
    --message-sha256 568b504e30feb14b522993b17f060a897fa88e25e9dd052c7bf441a43fbfa5f4 \
    --require-clean --require-full-commit-metadata
  printf '%s\n' 'base merge recovered; restart Task 11 Step 1'
  exit 75
fi

if test "$RECOVERY_STATE" = intent-only; then
  test "$(sterile_git rev-parse HEAD^{commit})" = "$H0"
  test "$(sterile_git write-tree)" = "$(sterile_git rev-parse "$H0^{tree}")"
  test -z "$(sterile_git status --porcelain=v1 --untracked-files=all)"
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$RUN_ROOT" --frontier-id "$BASE_MERGE_FRONTIER_ID" \
    --repository "$WT" --require-state intent-only
  sterile_git merge --no-ff --no-commit --no-edit --no-gpg-sign --no-verify "$B"
elif test "$RECOVERY_STATE" = merge-prepared; then
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$RUN_ROOT" --frontier-id "$BASE_MERGE_FRONTIER_ID" \
    --repository "$WT" --require-state merge-prepared
else
  printf '%s\n' 'unexpected base-merge continuation state' >&2
  exit 2
fi

test "$(sterile_git rev-parse HEAD^{commit})" = "$H0"
test "$(sterile_git rev-parse MERGE_HEAD)" = "$B"
test "$(sterile_git rev-parse ORIG_HEAD)" = "$H0"
test -z "$(sterile_git ls-files -u)"
test "$(sterile_git write-tree)" = "$PREDICTED_BASE_MERGE_TREE"
test -z "$(sterile_git diff --name-only)"
test -z "$(sterile_git ls-files --others --exclude-standard)"
sterile_git commit --no-verify --no-gpg-sign \
  -m 'Merge fresh main into Qinao convergence candidate'
H1="$(sterile_git rev-parse HEAD^{commit})"
test "$(sterile_git rev-list --parents -n 1 "$H1")" = "$H1 $H0 $B"
test "$(sterile_git rev-parse "$H1^{tree}")" = "$PREDICTED_BASE_MERGE_TREE"
test -z "$(sterile_git ls-files -u)"
test -z "$(sterile_git status --porcelain=v1 --untracked-files=all)"
qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$RUN_ROOT" --frontier-id "$BASE_MERGE_FRONTIER_ID" \
  --recover-exact --state completed --repository "$WT" \
  --result-head "$H1" --expected-parent "$H0" --expected-parent "$B" \
  --expected-tree "$PREDICTED_BASE_MERGE_TREE" \
  --message-sha256 568b504e30feb14b522993b17f060a897fa88e25e9dd052c7bf441a43fbfa5f4 \
  --require-clean --require-full-commit-metadata
printf '%s\n' 'base merged; restart Task 11 Step 1 with a fresh evidence root'
```

If a base merge is created, mark every older evidence root `superseded-by-head=$H1` in its append-only capture log, never reuse any result, and create a new evidence root when restarting Step 1. `frontier-complete` reopens the raw result commit and requires ordered parents `[H0,B]`, predicted tree, exact message bytes ending in one LF, the sterile synthetic identities, valid captured timestamp/timezone fields, no optional/unknown headers, clean status/config equality, and unchanged protected witness before appending its distinct terminal record. If interrupted with the exact intent/MERGE_HEAD/index-tree state above, the recovery table completes only this fixed commit; if the fixed commit already became `HEAD` but its completion frontier is missing, it proves the same full metadata and calls `frontier-complete --recover-exact --state recovered-completed`. A lost completion response may return the already persisted byte-identical terminal record but never append a duplicate. Any other sequencer/index state blocks. Do not delete stale evidence and never rebase, squash, cherry-pick, reset, or amend `C`.

If `H0` is an ancestor of `B`, the implementation may already have landed or the branch identity is stale; stop and investigate. If histories are unrelated or merge-tree reports a conflict, stop with all refs/worktrees preserved.

- [ ] **Step 4: Freeze `H` and compute the policy revision `V`**

`V` binds the exact 25-path policy set frozen in Task 6, including mode/type/blob OID for each direct path, the complete nine-node boundary execution graph, and the verified transitive vendor-file closure named by the bound Cargo vendor manifest. Run the protocol CLI against objects reopened from `H`; require literal `len==25` plus set equality, ordinary blobs/modes, no duplicate, complete boundary/vendor enumeration, and 64 lowercase-hex `V`. Record the complete canonical policy-revision object, `H`, `H^{tree}`, and `V` externally; do not write `H` or `V` back into a file inside `H`.

- [ ] **Step 5: Construct the exact candidate tree `T`**

```bash
set -euo pipefail
COMMON_GIT_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
sterile_git() {
  /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.autocrlf=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c commit.gpgSign=false -c merge.gpgSign=false \
    -c merge.autoStash=false -c rerere.enabled=false -C "$WT" "$@"
}
H="$(sterile_git rev-parse HEAD^{commit})"
REMOTE_MAIN_REF="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$PREFLIGHT_ROOT" --select-capture --phase remote-main --state sealed \
  --print-field ref)"
ADVERTISED_MAIN_OID="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$PREFLIGHT_ROOT" --select-capture --phase remote-main --state sealed \
  --print-field advertisedOid)"
B="$(sterile_git rev-parse "$REMOTE_MAIN_REF^{commit}")"
test "$B" = "$ADVERTISED_MAIN_OID"
sterile_git merge-base --is-ancestor "$B" "$H"
T="$(sterile_git rev-parse "$H^{tree}")"
test "$(printf '%s' "$T" | wc -c | tr -d ' ')" = 40
test "$(sterile_git cat-file -t "$T")" = tree
test "$(sterile_git rev-parse "$H^{tree}")" = "$T"
printf 'B=%s\nH=%s\nT=%s\n' "$B" "$H" "$T"
```

Expected: because `B` is already proved an ancestor of `H`, the native merge candidate tree is exactly `H^{tree}`; no write-producing `merge-tree` call is needed here. `T` is never called a candidate commit. The host's eventual `[B,H]` merge tree is still independently verified in Tasks 13–15.

- [ ] **Step 5A: Initialize an interruption-safe local evidence root**

Derive `TUPLE_DIGEST=SHA-256("B\0H\0T\0V\0")` and run:

```bash
set -euo pipefail
GIT_COMMON_DIR="$(sterile_git rev-parse --path-format=absolute --git-common-dir)"
test -d "$GIT_COMMON_DIR"
test ! -L "$GIT_COMMON_DIR"
EVIDENCE_ROOT="$GIT_COMMON_DIR/qinao-evidence/$TUPLE_DIGEST"
qinao_python scripts/qinao_pr_protocol.py init-evidence-root \
  --path "$EVIDENCE_ROOT" --B "$B" --H "$H" --T "$T" --V "$V"
test "$(stat -f '%Lp' "$EVIDENCE_ROOT")" = 700
```

`init-evidence-root` first safely create-once validates the mode-0700, non-symlink `qinao-evidence/` parent, then delegates atomic staging publication, identity, records, fsync, and recovery to the already committed Task 3 ledger primitives. Its immutable identity binds `(B,H,T,V,TUPLE_DIGEST)`, schema/policy versions, repository/common-dir identity, and predecessor root if any; it refuses a different existing identity or malformed published ledger. It implements no parallel store and never overwrites an attempt/result. All later intent, safe-capture redacted projection, result/log digest, normalized record, and supersession marker is append-by-unique-name beneath this root; raw remote response/log bytes are never files. Scratch build products may use `/private/tmp`, but required non-sensitive evidence is scanned, projected, copied, and fsynced here before a step is considered complete. The plan never deletes this root, so it survives interruption and exceeds the requested three-day minimum without making it source-code authority; final redacted canonical evidence is additionally stored on the PR timeline.

Every later capture—local command, GET/list observation, fetch advertisement, CI/log poll, or mutation response—first calls the Task 3 `qinao_convergence_audit.py allocate-capture` command with phase, exact input digest, and operation kind. It creates a never-before-used mode-0700 `CAPTURE_DIR="$EVIDENCE_ROOT/captures/$PHASE/$CAPTURE_ID"`, appends its allocation record, and returns paths only after `fsync`. Capture commands run with `umask 077` and noclobber/O_EXCL output descriptors; therefore every later code fence that writes a basename assumes a freshly allocated `CAPTURE_DIR` and **must not** write a reusable root-level filename even where a logical basename is shown. The Task 3 `seal-capture` command records every filename, byte count, digest, exit/HTTP status, input digest, and completion state in an immutable manifest and updates an append-only phase-generation index; it never renames over or edits an older record.

On restart, Task 3 `recover-captures` validates every allocation and seal. A complete sealed read-only capture with identical inputs may be selected by digest; an incomplete read-only capture remains immutable evidence and a new capture continues the observation. A mutation allocation with an intent but no terminal response is never reissued: only a fresh observation capture may resolve it under the operation-specific state machine. An unsealed file, unexpected name, duplicate ID, partial manifest, digest mismatch, or collision is `indeterminate`, not silently overwritten. Phase consumers take exact paths only from the selected sealed-generation record, so `host-initial`, advertisement/object disclosure, PR recovery, host-candidate, CI, body PATCH, comments, merge, and post-merge captures all share this rule.

- [ ] **Step 6: Capture the complete raw candidate diff**

Run:

```bash
sterile_git diff \
  --raw -z --full-index --no-abbrev --no-renames \
  --no-ext-diff --no-textconv \
  "$B^{tree}" "$T"
```

Feed the exact bytes to `parse_raw_diff_z`. Store the raw-byte SHA-256, every entry's modes/OIDs/status/base64 paths, and candidate blob type/size/SHA-256. Require no unparsed byte. Risk classification is expected `high` because the candidate changes workflows, policy code, large preserved history, binaries, and `.gitattributes`.

Run candidate `risk-check-raw` on those bytes and require `high`. If `B` contains the reviewed `scripts/qinao_convergence_audit.py`, `scripts/qinao_pr_protocol.py`, and matching evidence schema, create a detached no-smudge/no-hook temporary worktree at `B` and execute that base script (with imports rooted at the base worktree) against the same external identity/raw files and implementation repository; combine results monotonically so either high means high and any base failure/unknown means high/incomplete. For this initial bootstrap, absence of those new files at `B` is an explicit `base-risk-check-unavailable` limitation and forces high; it is not a routine exemption.

- [ ] **Step 7: Inventory LFS, binary, generated, and vendor effects**

Record:

- `.gitattributes` blob at `B` and `T`;
- every canonical LFS pointer discovered by parsing the exact newly reachable `H ^ <every advertised remote head/tag tip>` object/path closure in Step 7A, with all reachable paths/commits and no ambient local ref expansion;
- as a supplemental cross-check only, `git lfs ls-files --long H` under the sterile/no-network environment; disagreement blocks, but this command can neither add an OID/path nor widen the authoritative closure;
- each authoritative LFS pointer OID/size in that exact push closure (including historical/intermediate reachability, not merely `H^{tree}`);
- each pointer's exact locally stored content-addressed object, recomputed SHA-256/size, provenance, and local classification, without invoking any LFS remote or Batch endpoint;
- every raw entry whose blob contains NUL, is over the reviewed size threshold, is under a vendor/generated path, or changes an archive/library;
- source/provenance/rebuild command where known and a limitation where not.

Record `git lfs version`/`git lfs env` in redacted form and hash their locally captured streams. The inventory opens content only through the exact pointer OID under the resolved common Git LFS object store, never through a checkout-smudged path or symlink, and independently hashes the bytes. A missing object, hash/size mismatch, symlink/path escape, unknown provenance, unparsed pointer, or object absent from the complete Git closure is incomplete. The known LFS rule for `docs/Recovery/3a011899-aafa-43e6-961a-5c2649331735.jsonl` is explicitly represented and is blocking unless its minimized non-private source disposition is proved locally. No LFS server learns an OID or size before Step 7B's reviewers close this inventory.

- [ ] **Step 7A: Disclose the complete Git/LFS object closure before any push**

Tree diff is not an upload boundary: pushing `H` can make intermediate commits, old trees/blobs, complete commit/tag objects (including identity/signature/optional headers), and LFS objects newly reachable even when they do not appear in `B→T`. This protocol therefore uses three disjoint immutable generations: `remote-audit-advertisement`, `remote-audit-fetched-map`, and `remote-audit-disclosure`. At entry, a path-safe `--select-remote-audit-chain --B "$B" --H "$H"` selector must return exactly one legal next state. It reuses a unique sealed generation, explicitly supersedes at most one incomplete read-only child, resumes the one compatible open fetch/import frontier, or starts the following fence only from `absent`; multiple/unlinked generations or phase regression block.

```bash
set -euo pipefail
umask 077
set -C
ADVERTISEMENT_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase remote-audit-advertisement --print-field captureId)"
ADVERTISEMENT_CAPTURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$ADVERTISEMENT_CAPTURE_ID" \
  --print-field absolutePath)"
ADVERTISEMENT="$ADVERTISEMENT_CAPTURE_DIR/remote-advertisement.tsv"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase remote-audit-advertisement --repository ChangGeng01/ProjectSix \
  --B "$B" --H "$H" --capture-basename remote-advertisement.tsv \
  --output "$ADVERTISEMENT_CAPTURE_DIR/remote-advertisement-request-rows.json"
ADVERTISEMENT_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$ADVERTISEMENT_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$ADVERTISEMENT_CAPTURE_DIR/remote-advertisement-request-rows.json" \
  --print-field manifestPath)"
qinao_network_git --intent "$ADVERTISEMENT_INTENT" --operation ls-remote -- \
  -C "$WT" ls-remote --refs --branches --tags origin >"$ADVERTISEMENT"
qinao_python scripts/qinao_convergence_audit.py validate-remote-advertisement \
  --input "$ADVERTISEMENT" --allow-prefix refs/heads/ --allow-prefix refs/tags/ \
  --require-ref "refs/heads/main=$B" \
  --request-manifest "$ADVERTISEMENT_INTENT" \
  --output "$ADVERTISEMENT_CAPTURE_DIR/remote-advertisement.json" \
  --capture-files-output "$ADVERTISEMENT_CAPTURE_DIR/seal-files.txt"
AUDIT_ADVERTISEMENT_RECORD="$ADVERTISEMENT_CAPTURE_DIR/remote-advertisement.json"
AUDIT_ADVERTISEMENT_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  validate-remote-advertisement --record "$AUDIT_ADVERTISEMENT_RECORD" \
  --print-field recordDigest)"
AUDIT_ADVERTISEMENT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$ADVERTISEMENT_CAPTURE_ID" \
  --files-from "$ADVERTISEMENT_CAPTURE_DIR/seal-files.txt" --print-field sealRecordPath)"
AUDIT_ADVERTISEMENT_SEAL_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --seal-record "$AUDIT_ADVERTISEMENT_SEAL" \
  --print-field sealDigest)"

AUDIT_NS="refs/qinao/remote-audit/$TUPLE_DIGEST/$ADVERTISEMENT_CAPTURE_ID"
AUDIT_RESOURCE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-resource \
  --root "$EVIDENCE_ROOT" --kind remote-audit-quarantine \
  --template empty-bare-git --print-field resourceId)"
AUDIT_QUARANTINE="$EVIDENCE_ROOT/resources/remote-audit-quarantine.$AUDIT_RESOURCE_ID.git"
QUARANTINE_NS="refs/qinao/remote-audit/$TUPLE_DIGEST/$ADVERTISEMENT_CAPTURE_ID/$AUDIT_RESOURCE_ID"
test -z "$(sterile_git for-each-ref --format='%(refname)' "$AUDIT_NS/")"
test -z "$(sterile_git -C "$AUDIT_QUARANTINE" for-each-ref --format='%(refname)')"
test ! -e "$AUDIT_QUARANTINE/objects/info/alternates"
test -z "$(find "$AUDIT_QUARANTINE/objects" -type f ! -path '*/info/*' -print -quit)"
REMOTE_AUDIT_RESOURCE_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$AUDIT_RESOURCE_ID" \
  --state initial-empty-remote-audit-bare --print-field snapshotDigest)"
REMOTE_AUDIT_FETCH_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$EVIDENCE_ROOT" --kind remote-audit-fetch --recover-exact \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --stable-projection "$NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST" \
  --resource-id "$AUDIT_RESOURCE_ID" --input-snapshot "$REMOTE_AUDIT_RESOURCE_BEFORE" \
  --advertisement-capture "$AUDIT_ADVERTISEMENT_SEAL" \
  --advertisement-capture-digest "$AUDIT_ADVERTISEMENT_SEAL_DIGEST" \
  --remote-advertisement "$AUDIT_ADVERTISEMENT_DIGEST" \
  --quarantine-namespace "$QUARANTINE_NS" --print-field frontierId)"
REMOTE_AUDIT_FETCH_INTENT="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --frontier-id "$REMOTE_AUDIT_FETCH_FRONTIER" \
  --print-field startRecordPath)"
qinao_network_git --intent "$REMOTE_AUDIT_FETCH_INTENT" --operation fetch-empty -- \
  -C "$AUDIT_QUARANTINE" -c core.hooksPath=/dev/null fetch \
  --no-tags --no-auto-maintenance --no-write-commit-graph \
  --no-recurse-submodules --no-write-fetch-head \
  https://github.com/ChangGeng01/ProjectSix.git \
  "refs/heads/*:$QUARANTINE_NS/heads/*" \
  "refs/tags/*:$QUARANTINE_NS/tags/*"

AUDIT_MAP_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase remote-audit-fetched-map \
  --parent-capture "$AUDIT_ADVERTISEMENT_SEAL" --print-field captureId)"
AUDIT_MAP_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$AUDIT_MAP_CAPTURE_ID" --print-field absolutePath)"
sterile_git -C "$AUDIT_QUARANTINE" for-each-ref \
  --format='%(objectname)%09%(refname)' "$QUARANTINE_NS/" \
  >"$AUDIT_MAP_DIR/quarantine-fetched-remote-refs.tsv"
REMOTE_AUDIT_MAP_STATE="$(qinao_python scripts/qinao_convergence_audit.py \
  validate-remote-advertisement --record "$AUDIT_ADVERTISEMENT_RECORD" \
  --fetched-ref-map "$AUDIT_MAP_DIR/quarantine-fetched-remote-refs.tsv" \
  --quarantine-namespace "$QUARANTINE_NS" --classify-exact-map \
  --output "$AUDIT_MAP_DIR/fetched-map-result.json" \
  --capture-files-output "$AUDIT_MAP_DIR/seal-files.txt" --print-field disposition)"
AUDIT_MAP_RECORD="$AUDIT_MAP_DIR/fetched-map-result.json"
AUDIT_MAP_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$AUDIT_MAP_CAPTURE_ID" \
  --files-from "$AUDIT_MAP_DIR/seal-files.txt" --print-field sealRecordPath)"
AUDIT_MAP_SEAL_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --seal-record "$AUDIT_MAP_SEAL" \
  --print-field sealDigest)"
REMOTE_AUDIT_RESOURCE_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$AUDIT_RESOURCE_ID" \
  --state after-remote-audit-fetch --print-field snapshotDigest)"
if test "$REMOTE_AUDIT_MAP_STATE" != exact; then
  qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$EVIDENCE_ROOT" --frontier-id "$REMOTE_AUDIT_FETCH_FRONTIER" \
    --recover-exact --state tainted-preserved \
    --result-snapshot "$REMOTE_AUDIT_RESOURCE_AFTER" \
    --advertisement-capture "$AUDIT_ADVERTISEMENT_SEAL" \
    --source-map-capture "$AUDIT_MAP_SEAL" --reason advertised-ref-map-changed
  exit 75
fi
REMOTE_AUDIT_FETCH_TERMINAL="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$EVIDENCE_ROOT" --frontier-id "$REMOTE_AUDIT_FETCH_FRONTIER" \
  --recover-exact --state completed --result-snapshot "$REMOTE_AUDIT_RESOURCE_AFTER" \
  --advertisement-capture "$AUDIT_ADVERTISEMENT_SEAL" \
  --source-map-capture "$AUDIT_MAP_SEAL" \
  --source-map-capture-digest "$AUDIT_MAP_SEAL_DIGEST" \
  --print-field terminalRecordPath)"

REMOTE_AUDIT_SHARED_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
  --root "$EVIDENCE_ROOT" --repository "$WT" --require-namespace-absent "$AUDIT_NS" \
  --state before-remote-audit-import --print-field snapshotDigest)"
REMOTE_AUDIT_IMPORT_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$EVIDENCE_ROOT" --kind remote-audit-import --recover-exact \
  --repository "$WT" --source-resource-id "$AUDIT_RESOURCE_ID" \
  --source-snapshot "$REMOTE_AUDIT_RESOURCE_AFTER" \
  --source-frontier-terminal "$REMOTE_AUDIT_FETCH_TERMINAL" \
  --advertisement-capture "$AUDIT_ADVERTISEMENT_SEAL" \
  --source-map-capture "$AUDIT_MAP_SEAL" --destination-namespace "$AUDIT_NS" \
  --input-git-state "$REMOTE_AUDIT_SHARED_BEFORE" --print-field frontierId)"
sterile_git -c core.hooksPath=/dev/null fetch \
  --no-tags --no-auto-maintenance --no-write-commit-graph \
  --no-recurse-submodules --no-write-fetch-head "$AUDIT_QUARANTINE" \
  "$QUARANTINE_NS/heads/*:$AUDIT_NS/heads/*" \
  "$QUARANTINE_NS/tags/*:$AUDIT_NS/tags/*"
REMOTE_AUDIT_SHARED_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
  --root "$EVIDENCE_ROOT" --repository "$WT" --compare-input "$REMOTE_AUDIT_SHARED_BEFORE" \
  --allow-source-resource "$AUDIT_RESOURCE_ID:$REMOTE_AUDIT_RESOURCE_AFTER" \
  --require-only-namespace-addition "$AUDIT_NS" \
  --state after-remote-audit-import --print-field snapshotDigest)"
REMOTE_AUDIT_IMPORT_TERMINAL="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$EVIDENCE_ROOT" --frontier-id "$REMOTE_AUDIT_IMPORT_FRONTIER" \
  --recover-exact --state completed --repository "$WT" \
  --result-git-state "$REMOTE_AUDIT_SHARED_AFTER" \
  --advertisement-capture "$AUDIT_ADVERTISEMENT_SEAL" \
  --source-map-capture "$AUDIT_MAP_SEAL" --print-field terminalRecordPath)"

AUDIT_DISCLOSURE_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase remote-audit-disclosure \
  --parent-capture "$AUDIT_ADVERTISEMENT_SEAL" --parent-capture "$AUDIT_MAP_SEAL" \
  --print-field captureId)"
AUDIT_DISCLOSURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$AUDIT_DISCLOSURE_CAPTURE_ID" \
  --print-field absolutePath)"
sterile_git for-each-ref --format='%(objectname)%09%(refname)' "$AUDIT_NS/" \
  >"$AUDIT_DISCLOSURE_DIR/fetched-remote-refs.tsv"
qinao_python scripts/qinao_convergence_audit.py remote-object-revisions \
  --H "$H" --advertisement "$AUDIT_ADVERTISEMENT_RECORD" \
  --source-map "$AUDIT_MAP_RECORD" \
  --imported-ref-map "$AUDIT_DISCLOSURE_DIR/fetched-remote-refs.tsv" \
  --import-terminal "$REMOTE_AUDIT_IMPORT_TERMINAL" \
  --exclude-ref refs/heads/codex/qinao-git-only-convergence \
  --output "$AUDIT_DISCLOSURE_DIR/remote-object-revisions.txt" \
  --excluded-output "$AUDIT_DISCLOSURE_DIR/excluded-target-ref.json"
sterile_git rev-list --objects --no-object-names --stdin \
  <"$AUDIT_DISCLOSURE_DIR/remote-object-revisions.txt" \
  >"$AUDIT_DISCLOSURE_DIR/new-reachable-object-oids.txt"
sterile_git cat-file \
  --batch-check='%(objectname) %(objecttype) %(objectsize) %(objectsize:disk)' \
  <"$AUDIT_DISCLOSURE_DIR/new-reachable-object-oids.txt" \
  >"$AUDIT_DISCLOSURE_DIR/new-reachable-object-types-sizes.txt"
qinao_python scripts/qinao_convergence_audit.py remote-object-disclosure \
  --repository "$WT" --H "$H" \
  --revision-input "$AUDIT_DISCLOSURE_DIR/remote-object-revisions.txt" \
  --advertisement-record "$AUDIT_ADVERTISEMENT_RECORD" \
  --fetched-ref-map "$AUDIT_DISCLOSURE_DIR/fetched-remote-refs.tsv" \
  --object-oids "$AUDIT_DISCLOSURE_DIR/new-reachable-object-oids.txt" \
  --object-types-sizes "$AUDIT_DISCLOSURE_DIR/new-reachable-object-types-sizes.txt" \
  --advertisement-capture "$AUDIT_ADVERTISEMENT_SEAL" \
  --source-map-capture "$AUDIT_MAP_SEAL" \
  --import-terminal "$REMOTE_AUDIT_IMPORT_TERMINAL" \
  --output "$AUDIT_DISCLOSURE_DIR/remote-object-disclosure.json" \
  --capture-files-output "$AUDIT_DISCLOSURE_DIR/seal-files.txt"
AUDIT_DISCLOSURE_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$AUDIT_DISCLOSURE_CAPTURE_ID" \
  --files-from "$AUDIT_DISCLOSURE_DIR/seal-files.txt" --print-field sealRecordPath)"
```

The validator maps each advertised remote head/tag to exactly one private ref and requires identical OIDs; missing/extra/duplicate refs, symbolic/unborn refs, a non-head/tag advertisement, fetch failure, or scoped-advertisement change is incomplete. `refs/pull/**` and other provider namespaces are intentionally outside this negative-tip boundary. Each attempt owns a zero-ref/zero-object resource and unique namespace. The advertisement seal exists before resource allocation; the source-map seal exists before fetch completion/import start; the disclosure capture is allocated only after import terminal completion. No command writes into either parent after its seal.

`remote-object-revisions` is injection-free: its first line is `H`, and remaining lines are one `^OID` for every exact fetched head/tag tip except the literal target candidate ref, sorted by OID/ref. It independently cross-checks advertisement, quarantine source map, imported map, and import terminal; records the excluded target ref/OID separately; and rejects any other omission. Excluding the target prevents an externally/preexisting `candidate=H` advertisement from cancelling the disclosure closure. An exact prior `H_old` may conservatively cause already-remote candidate history to be rescanned but never shrink disclosure.

Recovery is phase-monotone. A crash after fetch but before map seal derives a replacement read-only map from the preserved resource, seals it, and completes that same frontier; a mismatch closes only as `tainted-preserved` and restarts from a new advertisement/resource/namespace. An attributable partial import continues only from the two sealed parents; exact poststate recovers the same terminal; foreign drift blocks. A crash after import but before disclosure seal regenerates only a replacement local read-only disclosure from the immutable imported namespace and the same terminal. Tests kill the process at every write/seal/frontier boundary and require one lineage, no post-seal write, no duplicate terminal, and byte-identical final disclosure.

The CLI independently recomputes the object list and rejects any mismatch with the captured list/type/size stream. Treat this closure conservatively as the possible upload set even if the server may already possess an unreachable object. Every object receives a terminal disposition; the only passing content disposition is `approved-source`, backed by local type/path/provenance/content review. There is no unverifiable `already-remote` shortcut. The following are hard blockers under the approved spec, not facts that Task 14 may waive after upload: a secret/credential/key; private application data; full conversation/transcript/runtime evidence; any `docs/Recovery/**` content or LFS object not proved minimized, non-private source; an unexplained binary/archive/database; an object over the reviewed size threshold without provenance; or any unknown/truncated scan. Do not put raw suspect bytes into GitHub, CI, comments, or automated-review prompts.

Freeze the three seal paths/digests plus advertisement/object-manifest/pure-local-LFS-manifest digests into pre-push evidence and later into `E`. Task 12 must re-read the advertisement immediately before push; any change starts a new three-generation audit lineage and recomputes the closure.

- [ ] **Step 7B: Complete the local pre-push egress gate**

Before any branch push or PR creation, dispatch two fresh read-only reviewers: `history-object-completeness` validates advertisement/negative-tip/object/path/commit coverage, and `privacy-lfs-egress` validates the closed path/type/size/LFS/secret-scan dispositions. They receive the canonical disclosure, type/size streams, provenance, plan/spec, and non-sensitive ordinary source needed for classification; they never receive a blob already flagged as possible secret/private/transcript/recovery data. A flagged blob is automatically blocking without being copied into an automated-review prompt.

Each reviewer returns a canonical `qinao.egress-review.v1` bound to `(H, advertisementSha256, objectManifestSha256, lfsLocalManifestSha256)`, exact reviewed object/disposition IDs, terminal state, findings, and self-digest. A third fresh integration reviewer accounts for every object and both reports. Require three complete reports, full union coverage, zero incomplete/actionable/private-egress finding, and exact digest agreement. Persist their digests in the evidence root and later `E`; Task 12's exact-object Batch observation is allowed only after these reports close, and Task 13's integration review consumes both local and remote-observation digests but cannot retroactively authorize upload.

If the deterministic classifier or any reviewer finds a suspect/private/unknown object, stop before push and present the exact redacted disclosure to the user. Proceeding then requires a newly reviewed history/scope design; an ordinary-development “好” is not an override. If all objects are terminal `approved-source`, this closes the pre-push egress gate under the user's already-approved ordinary Git workflow.

- [ ] **Step 8: Verify the complete plan/spec transform at `H` without self-reference**

Run `documents-verify --source "$C" --final "$H"`. Require the path set for both plan/spec directories—including non-Markdown machine files such as `qinao-owner-ledger-v1.json`—to equal the inventory set, and every observed final blob to equal its precomputed expected blob. The tracked inventory records no self-referential `H`; this step emits the external `H` binding used by final evidence.

- [ ] **Step 9: Close and freeze the full-diff assignment before validation consumes it**

Apply the exact Task 10 rules to every raw entry. Require every entry assigned at least once and all control/binary/LFS/generated/vendor/document transformations to carry a specific review/provenance disposition. Emit a canonical assignment record containing the review-configuration blob OID, raw-manifest SHA-256, `(B,H,T,V)`, and every sorted `{entryId,pathB64,status,partitionIds}` row plus a self-excluding digest. This output is passed to the matrix only as `@ASSIGNMENT@` and is the **only** assignment input accepted by Task 13; Task 10 fixtures or a later hand-selected path list are never review scope.

- [ ] **Step 10: Execute the selected high-risk matrix**

Use the already initialized durable private evidence root, run all thirteen high-risk targets on exact `(B,H,T,V)`, and require terminal typed results. Job/target bounds leave teardown margins:

- protocol/static/document targets: 5–10 minutes each;
- BAS/Qinao: 30-minute target, 40-minute enclosing bound;
- SampleHost: 30-minute target, 45-minute enclosing bound;
- Rust build/test: 15/20-minute targets, 40-minute combined enclosing bound.

Any failure, unknown expected skip, output truncation, cancellation, timeout, zero discovery/execution, missing result, or stale identity stops. Preserve the complete result/log digests; do not paraphrase a failure into success.

- [ ] **Step 11: Verify the protected worktree again**

Run the completed `qinao_convergence_audit.py protected` command and compare every exact witness from Task 1 plus the stronger raw/content manifest digests. Any mismatch invalidates the candidate.

- [ ] **Step 12: Apply the restart rule**

If a local validation or later review requires any tracked change after `H` is frozen, do not edit under a stale tuple. Require clean `HEAD=H_old`, recover the main ledger, and open exactly one `task11-review-fix` frontier **before** editing. Its immutable input binds the prior admitted terminal-frontier digest, prior tuple/evidence-root digest when one exists, exact finding/result/evidence digests, ordered unique declared raw path set, expected failing test/static-result IDs, `H_old`/tree, clean porcelain/index/config/protected witnesses, and fixed commit message bytes `fix: resolve Qinao review findings\n`. An unbound verbal suggestion is not a finding input.

Use ordinary red-green-refactor inside that frontier: first add/run the smallest regression or static fixture and seal the expected failure; edit only declared paths; run focused tests, every affected matrix target, and the forward-policy/document/workflow checks selected by the raw changed surface. Before committing, require every dirty/staged/untracked path to equal a declared path, stage only those paths, record the exact index tree and full NUL raw `H_old→index` manifest, run `secret-scan-worktree` over the exact index plus declared dirty files with positive counts/zero findings, and repeat clean config/protected witnesses. Then commit through `sterile_git` only:

```bash
sterile_git commit --no-verify --no-gpg-sign \
  -m 'fix: resolve Qinao review findings'
```

The terminal `frontier-complete --recover-exact` reopens the result as a full raw commit and requires exactly one parent `H_old`, the recorded index tree, exact one-LF message, sterile synthetic author/committer identities, valid captured timestamps/timezones, no optional/unknown header, the complete declared-path delta, all required green result/log digests, the secret-scan digest, clean status/config, and unchanged protected witness. It records `resultHead=H_new` and the superseded tuple/evidence digest. Recovery admits only four exact states: pristine `H_old` after the start record; a dirty/staged subset of the declared paths with the recorded TDD phase; the recorded index tree ready for the fixed commit; or `HEAD=H_new` with the full commit/clean postconditions above but a missing terminal record, which is completed as `recovered-completed`. A lost start/completion response returns only a byte-identical existing record. Any undeclared path, different tree/message/parent, unknown sequencer, unbound finding, or ambiguous result blocks and preserves state; there is no reset/amend/cleanup shortcut.

After a terminal review-fix frontier, return to Task 11 Step 1 with `H0=H_new`. Re-fetch `B`, reconstruct `T`, recompute `V`, recapture diff/LFS/object disclosure, rerun the pre-push egress gate and selected matrix, and treat all older candidate evidence as stale. The new evidence root records `predecessorTupleDigest` and the prior root path/digest; only an append-only, digest-valid prior remote operation record may supply a confirmed `H_old` to Task 12. No validation/review result is reused across a changed tuple, and no unrecorded branch ancestor is inferred as prior state. Multiple fixes require multiple linked frontiers/commits; they are never folded into an earlier commit.

Expected task result: a clean immutable `H` and complete local candidate evidence, with no push or PR yet.

### Task 12: Capture initial host state, push the exact branch, and create one PR with tri-state recovery

**Files:**
- No tracked edits
- Create local evidence/intent files only in the private Task 11 evidence root

**Interfaces:**
- Consumes: immutable `(B,H,T,V)`, high risk, complete local results, and exact LFS inventory.
- Produces: one remote branch at `H`, one open PR with exact base/head/body digest, and read-only host observations.

- [ ] **Step 1: Re-read host capabilities before any remote mutation**

First perform a no-secret authentication preflight:

```bash
set -euo pipefail
REPO=ChangGeng01/ProjectSix
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase remote-auth-status --repository "$REPO" --B "$B" --H "$H" \
  --output "$CAPTURE_DIR/auth-status-request-rows.json"
AUTH_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CAPTURE_DIR/auth-status-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$AUTH_READ_INTENT" --operation auth-read -- \
  auth status --hostname github.com
test "$(sterile_git remote get-url origin)" = \
  https://github.com/ChangGeng01/ProjectSix.git
```

As observed while this plan was written, `gh 2.91.0` is installed but the currently active token reports invalid. Execution must stop here and ask the user to restore normal GitHub authentication; never print, inspect, copy, or persist the token, and never weaken the protocol to bypass this check.

After authentication succeeds, use only REST reads with the fixed media/version headers. Allocate a fresh mode-0700 `phase=host-initial` capture below the private evidence root; an older partial directory stays immutable and recovery allocates a new generation rather than rerunning into it. Set `umask 077` plus noclobber, seal the exact ordered request manifest, and run these request families through wrapper-owned `safe-capture`. Each logical output filename below receives the strict redacted projection/status/raw-digest/size/scan result—never raw host bytes, secrets, signed URLs, or raw stderr. Seal/select this generation only after every required endpoint and page closes:

```bash
set -euo pipefail
REPO=ChangGeng01/ProjectSix
ACCEPT=application/vnd.github+json
VERSION=2022-11-28
# HOST_DIR is the fresh CAPTURE_DIR returned by allocate-capture.
HOST_DIR="$CAPTURE_DIR"
test -d "$HOST_DIR"
test "$(stat -f '%Lp' "$HOST_DIR")" = 700
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase host-initial-static --repository "$REPO" \
  --output "$HOST_DIR/host-static-request-rows.json"
HOST_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$HOST_DIR/host-static-request-rows.json" --print-field manifestPath)"
umask 077
set -C
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api -H "Accept: $ACCEPT" -H "X-GitHub-Api-Version: $VERSION" \
  user >"$HOST_DIR/authenticated-user.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api -H "Accept: $ACCEPT" -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO" >"$HOST_DIR/repository.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api -H "Accept: $ACCEPT" -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/permissions" >"$HOST_DIR/actions-permissions.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api -H "Accept: $ACCEPT" -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/permissions/workflow" >"$HOST_DIR/workflow-permissions.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/workflows?per_page=100" >"$HOST_DIR/workflows.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/runs?per_page=100" \
  >"$HOST_DIR/repository-actions-runs.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/hooks?per_page=100" >"$HOST_DIR/hooks.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/environments?per_page=100" >"$HOST_DIR/environments.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/deployments?per_page=100" >"$HOST_DIR/deployments.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/keys?per_page=100" >"$HOST_DIR/deploy-keys.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/collaborators?affiliation=all&per_page=100" \
  >"$HOST_DIR/collaborators.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/invitations?per_page=100" \
  >"$HOST_DIR/repository-invitations.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/secrets?per_page=100" \
  >"$HOST_DIR/actions-secrets.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/variables?per_page=100" \
  >"$HOST_DIR/actions-variables.pages.json"
qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp -H "Accept: $ACCEPT" \
  -H "X-GitHub-Api-Version: $VERSION" \
  "repos/$REPO/actions/runners?per_page=100" \
  >"$HOST_DIR/self-hosted-runners.pages.json"
```

Parse the authenticated-user safe projection, require one `type="User"`, stable lowercase login comparison rules, and a positive numeric ID; freeze login, ID, raw-stream digest, and redacted-projection digest outside `A` as the only expected interactive merge actor. Never store the token, authorization headers, or raw response. Repository metadata must explicitly report `delete_branch_on_merge=false` and `has_pages=false`; otherwise this no-ref-deletion/no-publication plan stops before push.

For each exact environment returned by the complete environment collection, the pure normalizer emits its RFC-3986 percent-encoded name and repository numeric ID. Query the environment object, deployment branch policies/rules where enabled, and both `/repositories/$REPOSITORY_ID/environments/$ENCODED_NAME/secrets?per_page=100` and `/repositories/$REPOSITORY_ID/environments/$ENCODED_NAME/variables?per_page=100` with complete pagination and the same headers. For each workflow ID returned by the complete workflow collection, capture `repos/$REPO/actions/workflows/$WORKFLOW_ID` and `repos/$REPO/actions/workflows/$WORKFLOW_ID/runs?per_page=100`; IDs must be unique positive integers and paths must agree with `B` or be explicitly source-absent/non-active. Independently capture the fully paginated repository-wide `actions/runs` collection, reject its documented search/list cap being reached or a page boundary that cannot prove termination, cross-check every per-workflow run, and freeze the maximum run ID/creation tuple plus every workflow ID associated with either legacy path. Later snapshots must requery this frozen ID set even when the current registry omits an ID.

Do not append those discovered IDs to `HOST_READ_INTENT`. Seal the static parent safe projection first, then have the pure parser write bounded canonical ID files. For each dynamic family call `render-request-rows --phase host-initial-environments|host-initial-workflows --parent-projection "$HOST_STATIC_PROJECTION_DIGEST" --ids FILE`, seal the resulting child manifest, and execute every row once using its own `HOST_ENVIRONMENT_INTENT` or `HOST_WORKFLOW_INTENT`. The renderer proves percent encoding, unique/sorted IDs, exact endpoint/filename bijection, and a family-specific cap. A parent projection change, extra/missing ID, reused manifest row, or dynamic endpoint emitted from shell text instead of the child renderer blocks.

After normalizing the complete per-workflow histories and nonterminal union, derive the unique sorted set of `(head_sha,literalWorkflowPath)` rows for the two closed legacy paths. Accept `run.path` only as the literal path or `literalPath@nonempty-ref`; the suffix is recorded but never used as the object ref. Seal that parent projection, render `--phase host-initial-run-sources --parent-projection "$HOST_WORKFLOW_PROJECTION_DIGEST" --ids "$RUN_SOURCE_ROWS"`, seal it as `HOST_RUN_SOURCE_INTENT`, and only then issue the authenticated fixed-header Contents reads. For each row, use the pure RFC-3986 path encoder and a 40-hex-only ref encoder into its own unique output identity. The child endpoint manifest keys the capture by `SHA-256(head_sha || NUL || literalPath)`, validates `type=file`, exact returned path/name/blob SHA, strict base64 bytes, size, and Git blob hash, and maps every run ID to exactly one resulting source blob. Never interpolate `run.path` or its `@ref` suffix into a request. A non-2xx—including 404 for a no-longer-reachable historical run head—remains an `unknown` generation and blocks rather than being treated as an absent workflow.

Query each nonterminal Actions state separately so an API filter cannot hide a live old workflow:

```bash
for state in queued in_progress waiting requested pending; do
  qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
    api --paginate --slurp -H "Accept: $ACCEPT" \
    -H "X-GitHub-Api-Version: $VERSION" \
    "repos/$REPO/actions/runs?status=$state&per_page=100" \
    >"$HOST_DIR/actions-runs-$state.pages.json"
done
```

The normalizer requires a complete, duplicate-free union and cross-checks workflow IDs/paths/head SHAs/events against the per-workflow histories. It records only secret/variable names and metadata, runner names/labels/status/busy, collaborator login/ID/role/permission booleans, and pending invitation actors—never values or tokens. Any unexpected write/merge collaborator, invitation, writable deploy key/App, busy/nonterminal base-retiring workflow, or unreadable collection blocks.

For endpoints that may legitimately be unavailable, capture status/body without converting failure into an empty success:

```bash
capture_one() {
  test "$#" -eq 2
  endpoint="$1"
  stem="$2"
  set +e
  qinao_gh --intent "$HOST_READ_INTENT" --operation rest-read -- \
    api --include -H "Accept: $ACCEPT" \
    -H "X-GitHub-Api-Version: $VERSION" \
    "$endpoint" >"$HOST_DIR/$stem.http" 2>"$HOST_DIR/$stem.stderr"
  exit_code=$?
  set -e
  printf '%s\n' "$exit_code" >"$HOST_DIR/$stem.exit"
}
capture_one "repos/$REPO/actions/permissions/selected-actions" selected-actions
capture_one "repos/$REPO/pages" pages
capture_one "repos/$REPO/rulesets?per_page=100" rulesets-first-page
capture_one "repos/$REPO/branches/main/protection" main-protection
```

The implementation materializes a closed endpoint manifest containing every single/paginated/dynamic family named in this step—including the per-run historical Contents family—its exact producer row, expected response shape, pagination mode, sensitivity projection, and availability rule. Every direct body capture above is paired with a `capture_one` first-page status/header/body sidecar; every paginated/dynamic family is checked against that sidecar. A missing manifest row, command exit/status/body disagreement, redirect outside the allowed log endpoint, or family produced by neither the literal table nor a validated environment/workflow/installation/run-source row is incomplete. This unifies status handling instead of interpreting a failed direct command as an empty list.

When the rulesets first page is 2xx, seal its safe-projection digest, render a one-row `host-initial-rulesets-pages` child manifest bound to that digest, and run the corresponding `qinao_gh ... --operation rest-read -- api --paginate --slurp` row into `rulesets.pages.json`; a first-page/paginated disagreement fails. Classify the authenticated credential before any installations request. For the normal classic/fine-grained/OAuth `gh` credential, emit the canonical `installationGrantVisibility=unavailable-for-credential-type` limitation and make **no** `user/installations` call. Only if the already authenticated credential is independently proved to be a GitHub App user access token with the documented read capability may the closed child-manifest renderer add `user/installations?per_page=100`, then—after sealing that parent projection—each `user/installations/$id/repositories?per_page=100`; every call uses `qinao_gh`, complete pagination, unique positive IDs, and repository-membership cross-checks. The plan never asks the user to create/supply that second credential. Preserve only each called endpoint's safe non-2xx status/redacted projection rather than converting it to an empty array or persisting the raw body.

The normalizer in `qinao_workflow_inventory.py` accepts a safe-capture paginated projection only when every page is present, the in-memory raw response shape was exact, and pagination termination is authoritative. It validates the status/header projection, raw-stream digest/size and secret-scan disposition, hashes the canonical redacted fields, and cross-checks any API-visible installations against repository membership. No endpoint response, app name, or response string is executed as instructions.

Read repository visibility/ownership/default branch/merge/delete-branch/Pages settings, Actions permissions/allowlists, workflows/runs, hooks, complete deployments, environments/rules, repository/environment secret and variable metadata, self-hosted runners, nonterminal runs, deploy keys, every API-visible app/check/deployment/review producer, collaborators/invitations, rulesets, and `main` protection. Store only redacted response digests and non-sensitive fields. Require:

- private, single-owner repository;
- default branch `main`;
- auto-merge disabled;
- repository `has_pages=false`, Pages endpoint authoritative disabled/404-consistent, and no active/unclassified deployment or branch-native publication producer;
- native merge commit mode available for this convergence PR;
- no newly discovered high-privilege automation;
- ruleset/protection tier limitation unchanged;
- no mutation request.

An unreadable high-privilege surface is `unknown` and blocks the push/PR until resolved. Only the already-reviewed branch-protection/ruleset tier response may be classified `unavailable-by-tier`; an authentication error, generic 403, truncated page, or parser failure is not the known limitation.

- [ ] **Step 2: Classify remote branch and PR state before deciding any mutation**

First allocate and seal a fresh observation capture, render its exact rows, then repeat the heads-and-tags-scoped `qinao_network_git --operation ls-remote -- ... ls-remote --refs --branches --tags origin` invocation into its O_EXCL safe projection and require semantic advertisement equality with the selected Task 11 Step 7A generation. Any scoped-advertisement change returns to Task 11, which allocates a new observation ID/namespace and recomputes the object closure without touching old refs/files. Through separate single-use rendered rows, capture `ls-remote --exit-code origin refs/heads/main`, require success, exactly one valid row, and OID `B`; capture the intended branch query without `--exit-code`, retain its parsed wrapper result, and distinguish an authoritative zero-row result from a failed query. No plain ambient Git command performs these reads.

The branch state is one of only:

- `absent`: authoritative zero rows and no unresolved earlier push attempt;
- `current-trusted`: exactly one row at `H` **and** a digest-valid prior `remote-git-push` frontier/terminal or unresolved attempt for this exact tuple, plus its original pre-effect advertisement, full target-ref-excluding object/LFS disclosure, three egress reviews, and LFS presence observation; revalidate them and recover/confirm the same effect, then skip push;
- `unexpected-prior-egress`: exactly one row at `H` but no complete prior protocol provenance above; stop and report an irreversible external/preexisting push. It cannot be called pre-push-reviewed, cannot inherit the current disclosure as retroactive authorization, and needs a separate user decision/recovery design;
- `prior-confirmed`: exactly one row at `H_old`, where `H_old` is the predecessor tuple's digest-bound, confirmed remote head from the append-only operation ledger, `H_old != H`, and `git merge-base --is-ancestor H_old H` succeeds;
- `conflict`: any other/multiple row, unrecorded ancestor, failed query, or unresolved prior attempt whose observed ref is not the exact expected `H`; stop.

Do not infer `H_old` from “some ancestor” or the branch name. When Task 11 restarts after a review fix, its new evidence root names the exact predecessor tuple/root and carries forward only the prior root's confirmed observation record; otherwise `H_old` is absent. Exact remote `H` is authoritative recovery of the Git-ref effect even if the process died before writing its observation; the operation ledger records `recovered-success` only after the exact LFS presence observation is revalidated. This plan never performs an LFS upload, so there is no hidden pre-push LFS side effect to infer from the Git ref. Remote old/absent never receives the ref-recovery shortcut.

Before a push, also perform the complete all-state PR lookup from Step 7 for the exact repository/base/head branch. Normalize **all** matching branch PRs, not only those already at `H`, and freeze their number/state/base/head OID/body digest. Accept zero records or exactly one open, same-repository PR whose head is `H`/`H_old` consistently with the remote branch. A merged/closed PR, deleted head, multiple PRs, mismatched repository/base, or incomplete pagination stops. This preflight prevents a resumed task from blindly pushing or creating a duplicate.

- [ ] **Step 3: Observe exact approved LFS presence; never upload**

The durable convergence worktree does not rely on a repository `pre-push` hook: the source histories do not contain a tracked `.githooks/pre-push`, and ignored hooks from another worktree are not portable authority. Git push later runs with hooks disabled and `--recurse-submodules=no`; it has no LFS transfer side effect. Immediately re-run/bind the network-egress preflight and workflow-file permission proof before disclosing even one approved LFS OID. From the terminal local disclosure, render a canonical manifest containing every and only approved lowercase SHA-256 OID, exact size, base64 path IDs, local object digest, and the three egress-review digests.

Allocate one fresh `phase=lfs-presence-observation` capture for both empty and nonempty manifests. `lfs-batch-observe --empty-policy emit-no-network` emits the same typed schema with `requestCount=0` when the validated set is empty and proves that no credential lookup/socket occurred; otherwise it performs exactly one presence query. Its credential and raw response remain memory-only; the capture receives only the redacted canonical observation, process exit, and exact whitelist:

```bash
set -euo pipefail
LFS_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase lfs-presence-observation \
  --parent-capture "$AUDIT_DISCLOSURE_SEAL" --print-field captureId)"
LFS_CAPTURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$LFS_CAPTURE_ID" --print-field absolutePath)"
LFS_OBSERVATION="$LFS_CAPTURE_DIR/lfs-remote-observation.json"
LFS_EXIT="$LFS_CAPTURE_DIR/lfs-remote-observation.exit"
test ! -e "$LFS_OBSERVATION"
test ! -e "$LFS_EXIT"
set +e
qinao_python scripts/qinao_convergence_audit.py lfs-batch-observe \
  --endpoint https://github.com/ChangGeng01/ProjectSix.git/info/lfs/objects/batch \
  --ref refs/heads/codex/qinao-git-only-convergence \
  --manifest "$LFS_APPROVED_MANIFEST" \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --empty-policy emit-no-network \
  --output "$LFS_OBSERVATION"
LFS_OBSERVATION_EXIT=$?
set -e
printf '%s\n' "$LFS_OBSERVATION_EXIT" >"$LFS_EXIT"
test "$LFS_OBSERVATION_EXIT" = 0
LFS_REMOTE_OBSERVATION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  lfs-batch-observe --verify "$LFS_OBSERVATION" --exit-file "$LFS_EXIT" \
  --manifest "$LFS_APPROVED_MANIFEST" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --capture-files-output "$LFS_CAPTURE_DIR/seal-files.txt" --print-field recordDigest)"
LFS_OBSERVATION_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$LFS_CAPTURE_ID" \
  --files-from "$LFS_CAPTURE_DIR/seal-files.txt" --print-field sealRecordPath)"
LFS_OBSERVATION_SEAL_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --seal-record "$LFS_OBSERVATION_SEAL" \
  --print-field sealDigest)"
```

Require exit zero, exact manifest/review/preflight binding, `(requestCount,objectCount)=(0,0)` for an empty set or positive counts for a nonempty set, `redirectCount=0`, `followedActionCount=0`, every nonempty-set OID exactly `remote-present`, and no response/action/header secret in either persisted file. Bind both `LFS_OBSERVATION_SEAL`/seal digest and `LFS_REMOTE_OBSERVATION_DIGEST` into the push intent and as `lfsRemoteObservationSha256` in `E`; a bare JSON digest is insufficient. `remote-missing`, transport loss, auth/TLS/schema/redirect failure, unexpected action/error/object, truncation, or any indeterminate observation stops before Git push. It is safe to repeat only a fully read-only presence observation in a fresh generation after a transport failure; it never resolves missing content. A missing object requires a separate explicit user decision and reviewed LFS transfer plan outside this implementation—this plan contains no `git lfs push`, upload intent, action URL connection, or partial-upload recovery state. Crash fixtures cover both empty/nonempty branches, every write/seal boundary, and prove the push cannot start from an unsealed generation.

- [ ] **Step 3A: Push the immutable Git refspec at most once, only when needed**

If Step 2 classified `current-trusted`, recover/complete the already existing operation frontier and make no Git push after confirming the same exact LFS set is remote-satisfied. `unexpected-prior-egress` stops. For `absent` or `prior-confirmed`, require the Step 7A target-ref-excluding disclosure/pre-push reviews, Step 3 LFS presence, workflow-file permission proof, network-egress stable projection plus selected record digest, and advertisement to remain exact. Record old OID (`null` or exact `H_old`), expected `H`, ref, both network preflight digests, object/LFS disclosure digests, unique intent/attempt IDs, and start time. Set `EXPECTED_LEASE` to the empty string for authoritative absence or exact `H_old` for `prior-confirmed`; immediately repeat network-egress preflight and the exact branch query, requiring identical stable projection and binding the fresh record digest into the push intent. For `prior-confirmed`, independently require `H_old` to be an ancestor of `H`. Then invoke the Git push with hooks disabled and an exact old-value lease:

```bash
REF=refs/heads/codex/qinao-git-only-convergence
PUSH_REQUEST_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase candidate-push-request \
  --parent-capture "$AUDIT_DISCLOSURE_SEAL" \
  --parent-capture "$LFS_OBSERVATION_SEAL" --print-field captureId)"
PUSH_REQUEST_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$PUSH_REQUEST_CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase candidate-branch-push --repository ChangGeng01/ProjectSix \
  --H "$H" --ref "$REF" --expected-lease "$EXPECTED_LEASE" \
  --output "$PUSH_REQUEST_DIR/candidate-push-request-rows.json"
PUSH_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$PUSH_REQUEST_CAPTURE_ID" \
  --file candidate-push-request-rows.json --print-field sealRecordPath)"
PUSH_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  frontier-start --root "$EVIDENCE_ROOT" --kind remote-git-push \
  --recover-exact --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --request-capture "$PUSH_REQUEST_SEAL" \
  --request-rows "$PUSH_REQUEST_DIR/candidate-push-request-rows.json" \
  --old-oid "${EXPECTED_LEASE:-null}" --expected-oid "$H" --ref "$REF" \
  --object-disclosure "$REMOTE_OBJECT_DISCLOSURE_DIGEST" \
  --lfs-observation "$LFS_REMOTE_OBSERVATION_DIGEST" \
  --lfs-observation-capture "$LFS_OBSERVATION_SEAL" \
  --lfs-observation-capture-digest "$LFS_OBSERVATION_SEAL_DIGEST" \
  --print-field startRecordPath)"
set +e
qinao_network_git --intent "$PUSH_INTENT_RECORD" --operation push -- \
  -C "$WT" -c core.hooksPath=/dev/null \
  -c remote.origin.mirror=false -c push.followTags=false \
  -c push.pushOption= -c push.gpgSign=false \
  -c push.useForceIfIncludes=false push \
  --porcelain --recurse-submodules=no --no-follow-tags --no-signed \
  --no-force-if-includes \
  --force-with-lease="$REF:$EXPECTED_LEASE" origin \
  "$H:refs/heads/codex/qinao-git-only-convergence"
PUSH_EXIT=$?
set -e
PUSH_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --intent "$PUSH_INTENT_RECORD" \
  --require-wrapper-exit "$PUSH_EXIT" --print-field attemptRecordPath)"
```

The empty high-priority `push.pushOption` value clears inherited multivar values; no `--push-option` is sent. The exact lease is a compare-and-swap guard, not permission for a non-fast-forward rewrite: the only admitted transitions are `absent→H` and proved-ancestor `H_old→H`. Do not use `-u`, bare `--force`, a `+` refspec, `--force-if-includes`, follow-tags, signed push, push option, delete, mirror, atomic multi-ref, or a broad branch name. Any concurrent ref change makes the lease reject rather than being absorbed by an otherwise valid fast-forward. Record start/end, command outcome, intended ref, exact lease, and pre-push LFS inventory; the wrapper's receiving-side fixture/porcelain parser must prove exactly one intended ref and zero ancillary ref/option/signature effect.

- [ ] **Step 4: Recover an uncertain Git push without replay**

After the wrapper returns, allocate `phase=candidate-push-observation` with `--parent-capture "$PUSH_REQUEST_SEAL" --parent-attempt "$PUSH_ATTEMPT_RECORD"`, seal its exact one-ref read manifest, perform that bounded read, normalize the ref plus attempt result into the capture, and seal it before classification. Always query the exact remote ref after an attempted push:

- remote `H`: confirmed Git-ref success;
- old/absent ref plus a parsed terminal lease/rejection result that proves non-acceptance: confirmed Git-ref no-effect; retain the immutable, already verified LFS `remote-satisfied` presence observation (a missing/indeterminate observation could never have reached this push step);
- old/absent ref after timeout/lost/unreadable transport: indeterminate, because a point-in-time read does not prove the receive-pack transaction cannot still become visible; never replay this logical push;
- different ref, failed query, multiple rows, or ambiguous LFS effect: indeterminate.

For `confirmed-success` or strictly proved `confirmed-no-effect`, set `REMOTE_FRONTIER_ID` from `PUSH_INTENT_RECORD` and execute the Task 6 terminal pattern with the sealed exact-ref observation and push classifier; this closes `remote-git-push` exactly once. A transport-unknown classification leaves it open and blocks every later mutation. Only a terminal confirmed-no-effect completion plus a fresh user instruction can permit one new ref frontier; it never repeats LFS OIDs already proven satisfied. Equality with old/absent ref alone neither closes an unknown ref transaction nor undoes the separate LFS effect. On a later resumed execution, a prior terminal confirmed remote `H` is `current` and is skipped; an unresolved attempt remains blocking unless exact remote `H` recovers it as success and closes that same frontier. Any lease or ancestry rejection returns to Task 11/investigation and never weakens the exact lease.

- [ ] **Step 5: Generate the exact PR body**

Create a non-sensitive body file with the human sections and one canonical metadata block. For this convergence PR, the real values include:

- outcome: source-line convergence and active admission-controller retirement;
- declared risk: high;
- changed surfaces from the structured classifier;
- all local validation target summaries/digests;
- complete newly reachable Git/LFS object counts, disclosure/pre-push-review digests, and iOS 27/toolchain/Swift Testing/binary provenance limitations;
- rollback by reviewed revert PR;
- forward recovery by fresh repair PR;
- irreversible effects including remote branch/PR creation; explicitly state that this plan performed no LFS upload and made no snapshot/DS3/application-data claim.

Compute and store the full body SHA-256. The body contains no `E`, approval, secret, private path, or success claim unsupported by exact evidence.

- [ ] **Step 6: Reuse/update one existing PR or create only after authoritative zero**

After the branch is authoritatively at `H`, repeat the all-state lookup below. Apply this closed action table:

- exactly one open same-repository PR at base `B`, branch name, and head `H`, with intended body digest: record `confirmed-preexisting`; make no request;
- exactly one such open PR with a different **previously observed** body digest: update that same PR with the canonical one-key PATCH/body tri-state protocol from Task 13 Step 5A; never create another PR;
- authoritative zero branch PRs across all states: record a create intent digest over repository/base/head branch/`H`/title/body digest, then issue the create command exactly once;
- a PR still reporting `H_old` after the confirmed branch update: wait only for bounded authoritative rereads; if it does not become `H`, stop as inconsistent rather than creating/updating;
- multiple, closed, merged, deleted-head, different-base/repository, unexpected body, unreadable, or unresolved prior create/update state: stop.

Only the authoritative-zero branch executes:

```bash
PR_CREATE_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase pr-create-request \
  --print-field captureId)"
PR_CREATE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$PR_CREATE_CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_pr_protocol.py render-pr-create-request \
  --title 'Converge Qinao histories onto ordinary Git and lightweight PR review' \
  --head codex/qinao-git-only-convergence --base main \
  --body-file "$PR_BODY_FILE" \
  --output "$PR_CREATE_DIR/pr-create-request.json"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase pr-create --repository ChangGeng01/ProjectSix \
  --request "$PR_CREATE_DIR/pr-create-request.json" \
  --output "$PR_CREATE_DIR/pr-create-request-rows.json"
PR_CREATE_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$PR_CREATE_CAPTURE_ID" \
  --file pr-create-request.json --file pr-create-request-rows.json \
  --print-field sealRecordPath)"
PR_CREATE_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  frontier-start --root "$EVIDENCE_ROOT" --kind remote-pr-create \
  --recover-exact --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --request-capture "$PR_CREATE_REQUEST_SEAL" \
  --request-rows "$PR_CREATE_DIR/pr-create-request-rows.json" \
  --request "$PR_CREATE_DIR/pr-create-request.json" \
  --B "$B" --H "$H" --body-sha256 "$PR_BODY_SHA256" \
  --print-field startRecordPath)"
set +e
qinao_gh --intent "$PR_CREATE_INTENT_RECORD" --operation rest-post-pr -- \
  api --method POST \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  repos/ChangGeng01/ProjectSix/pulls \
  --input "$PR_CREATE_DIR/pr-create-request.json" \
  >/dev/null
PR_CREATE_EXIT=$?
set -e
PR_CREATE_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --intent "$PR_CREATE_INTENT_RECORD" \
  --require-wrapper-exit "$PR_CREATE_EXIT" --print-field attemptRecordPath)"
```

The request bytes must contain exactly `title`, `head`, `base`, `body`, `maintainer_can_modify=false`, and `draft=false`; the sealed request capture and intent bind their digest plus exact REST method/path/headers/argv. The wrapper writes its response/transport classification only to the immutable attempt ledger; shell stdout is discarded and never becomes authority. Do not use generic `gh pr create`, `--fill`, auto-merge, project mutation, labels as authority, or web fallback that loses the exact body. A reused PR retains its number and history; a review-fix cycle fast-forwards the same branch and updates the same PR.

- [ ] **Step 7: Observe every PR mutation and recover without duplication**

For whichever create/PATCH frontier is being observed, allocate the fresh phase capture with its exact sealed request as `--parent-capture` and its unique attempt as `--parent-attempt`; the allocation rejects a request/attempt from the other frontier. Query all PR states with complete pagination using:

```bash
# OBSERVATION_DIR is a fresh phase=pr-state CAPTURE_DIR.
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase pr-state --repository ChangGeng01/ProjectSix \
  --B "$B" --H "$H" --pr-number "${PR_NUMBER:-0}" \
  --output "$OBSERVATION_DIR/pr-state-request-rows.json"
PR_STATE_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$OBSERVATION_DIR/pr-state-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$PR_STATE_READ_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  'repos/ChangGeng01/ProjectSix/pulls?state=all&head=ChangGeng01:codex/qinao-git-only-convergence&base=main&per_page=100' \
  >"$OBSERVATION_DIR/pr-create-recovery.pages.json"
```

The pure normalizer rejects an incomplete page envelope, duplicate PR number, omitted head/base repository, or noncanonical text, then returns both the complete branch-level set and the exact-intent subset plus the capture's exact whitelist. Seal that observation generation before classification. After any create/PATCH exit—including timeout/lost response—perform this read and one exact-PR GET when a number is known, while retaining whether the transport returned a parsed authenticated terminal response or became unknown:

- exactly one open record at exact `B/H` and intended body: confirmed success;
- authoritative zero branch records after create, or exact old body after PATCH, is `confirmed-no-effect` only when paired with a parsed authenticated terminal rejection whose endpoint semantics prove that request was not accepted; one new attempt then requires a fresh instruction and a new operation ID;
- authoritative zero/old state after a timeout, lost/unreadable response, disconnect, cancellation, or other transport-unknown result remains `indeterminate`: GitHub supplies no idempotency key or pending-operation proof for these mutations, so the same logical create/PATCH is never retried even if repeated immediate reads remain unchanged;
- multiple branch records, closed/merged record, stale/mismatched head/body, unexpected body, unreadable page, or unknown head: indeterminate.

For a create frontier, set `REMOTE_FRONTIER_ID` to the ID named by `PR_CREATE_INTENT_RECORD`; persist the pure classifier output and the sealed all-state/exact-PR observation; then execute the mandatory Task 6 `frontier-complete` pattern only for `confirmed-success` or strictly proved `confirmed-no-effect`. The completion binds the exact PR number/base/head/body/actor on success or the authenticated rejection plus authoritative-zero proof on no-effect. A lost completion response uses `--recover-exact`. An indeterminate create stays open and prevents PATCH/comment/merge; it is not silently abandoned. Preexisting/reused PR paths open no create frontier.

Never issue a second create/PATCH merely because the first client returned no URL. A resumed task first observes the operation ledger plus host state, recovers/completes the same frontier when exact evidence permits, and skips a confirmed effect.

- [ ] **Step 8: Reopen the PR and bind the host observation**

Require one PR number, REST `state="open"`, `draft=false`, base OID `B`, head OID `H`, exact body digest, REST `auto_merge == null` (normalized to protocol `autoMerge=false`), and head branch at `H`. Record mergeability as observed, not assumed. Verify no host setting changed during push/creation. Do not look for GraphQL-only `autoMergeRequest` in REST data.

Expected task result: one exact remote branch and one exact open PR; no approval or merge yet.

### Task 13: Verify the host candidate, complete CI/reviews, compute `A/E`, and persist `final-evidence`

**Files:**
- No tracked edits unless a finding is fixed, in which case return to Task 11
- Local canonical review/automation/evidence files in the private evidence root
- PR timeline comments only after local verification

**Interfaces:**
- Consumes: PR number, exact `(B,H,T,V)`, persisted exact `PR_BODY_SHA256`, local results, review configuration, and host observations.
- Produces: terminal CI/review set, final automation digest `A`, canonical evidence digest `E`, and verified timeline record.

- [ ] **Step 1: Compare the host merge candidate to local `T`**

Use a phase-monotone capture chain, never one mutable `host-candidate` directory: sealed `host-candidate-head-advertisement` → candidate-head observation; sealed `host-candidate-merge-source` → shared import → sealed local result; or, after a terminal failed merge fetch, sealed `host-candidate-merge-absence` → sealed REST pull → sealed REST commit result. The candidate-head fetch, pull-merge fetch, and shared-repository import are independent durable frontiers; no Task 11 quarantine is reused or mutated. The fence begins only after a recovery selector proves no compatible sealed/open generation already exists. Wrapper stdout/stderr are safe projections only and never raw transport bytes:

```bash
NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST="$(qinao_python \
  scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$NETWORK_PREFLIGHT_RECORD" --print-field stableProjectionDigest)"
HOST_HEAD_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase host-candidate-head-advertisement \
  --print-field captureId)"
HOST_CANDIDATE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$HOST_HEAD_CAPTURE_ID" --print-field absolutePath)"
HOST_CANDIDATE_REF="refs/qinao/host-candidate/$TUPLE_DIGEST/$HOST_HEAD_CAPTURE_ID"
test -z "$(sterile_git for-each-ref --format='%(refname)' "$HOST_CANDIDATE_REF")"

qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase candidate-branch-read --repository ChangGeng01/ProjectSix \
  --H "$H" --output "$HOST_CANDIDATE_DIR/candidate-branch-request-rows.json"
HEAD_BRANCH_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$HOST_HEAD_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$HOST_CANDIDATE_DIR/candidate-branch-request-rows.json" \
  --print-field manifestPath)"
qinao_network_git --intent "$HEAD_BRANCH_READ_INTENT" --operation ls-remote -- \
  -C "$WT" ls-remote --exit-code origin \
  refs/heads/codex/qinao-git-only-convergence \
  >"$HOST_CANDIDATE_DIR/candidate-branch.tsv"
HEAD_BRANCH_OBSERVATION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  validate-remote-advertisement \
  --input "$HOST_CANDIDATE_DIR/candidate-branch.tsv" \
  --require-only-ref "refs/heads/codex/qinao-git-only-convergence=$H" \
  --request-manifest "$HEAD_BRANCH_READ_INTENT" \
  --output "$HOST_CANDIDATE_DIR/candidate-branch.json" \
  --capture-files-output "$HOST_CANDIDATE_DIR/seal-files.txt" \
  --print-field recordDigest)"
HOST_HEAD_ADVERTISEMENT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$HOST_HEAD_CAPTURE_ID" \
  --files-from "$HOST_CANDIDATE_DIR/seal-files.txt" --print-field sealRecordPath)"

HEAD_RESOURCE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-resource \
  --root "$EVIDENCE_ROOT" --kind host-head-quarantine \
  --template empty-bare-git --print-field resourceId)"
HEAD_QUARANTINE="$EVIDENCE_ROOT/resources/host-head-quarantine.$HEAD_RESOURCE_ID.git"
QUARANTINE_HEAD_REF="refs/qinao/remote-head/$TUPLE_DIGEST/$HOST_HEAD_CAPTURE_ID"
HEAD_RESOURCE_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$HEAD_RESOURCE_ID" \
  --state initial-empty-bare --print-field snapshotDigest)"
HEAD_FETCH_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$EVIDENCE_ROOT" --kind host-head-fetch --recover-exact \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --stable-projection "$NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST" \
  --resource-id "$HEAD_RESOURCE_ID" --input-snapshot "$HEAD_RESOURCE_BEFORE" \
  --advertisement-capture "$HOST_HEAD_ADVERTISEMENT_SEAL" \
  --remote-advertisement "$HEAD_BRANCH_OBSERVATION_DIGEST" \
  --expected-ref "refs/heads/codex/qinao-git-only-convergence=$H" \
  --quarantine-ref "$QUARANTINE_HEAD_REF" --print-field frontierId)"
HEAD_FETCH_INTENT="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --frontier-id "$HEAD_FETCH_FRONTIER" \
  --print-field startRecordPath)"
qinao_network_git --intent "$HEAD_FETCH_INTENT" --operation fetch-empty -- \
  -C "$HEAD_QUARANTINE" -c core.hooksPath=/dev/null fetch \
  --no-tags --no-auto-maintenance --no-write-commit-graph \
  --no-recurse-submodules --no-write-fetch-head \
  https://github.com/ChangGeng01/ProjectSix.git \
  "refs/heads/codex/qinao-git-only-convergence:$QUARANTINE_HEAD_REF"
FETCHED_HEAD_OID="$(sterile_git -C "$HEAD_QUARANTINE" \
  rev-parse "$QUARANTINE_HEAD_REF^{commit}")"
if test "$FETCHED_HEAD_OID" != "$H"; then
  HEAD_TAINTED_SNAPSHOT="$(qinao_python scripts/qinao_convergence_audit.py \
    snapshot-resource --root "$EVIDENCE_ROOT" --resource-id "$HEAD_RESOURCE_ID" \
    --state head-race-tainted --print-field snapshotDigest)"
  qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$EVIDENCE_ROOT" --frontier-id "$HEAD_FETCH_FRONTIER" \
    --recover-exact --state tainted-preserved \
    --result-snapshot "$HEAD_TAINTED_SNAPSHOT" --reason candidate-head-drift
  exit 75
fi
HEAD_RESOURCE_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$HEAD_RESOURCE_ID" \
  --state fetched-exact-head --expected-ref "$QUARANTINE_HEAD_REF=$H" \
  --print-field snapshotDigest)"
qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$EVIDENCE_ROOT" --frontier-id "$HEAD_FETCH_FRONTIER" \
  --recover-exact --state completed --result-snapshot "$HEAD_RESOURCE_AFTER" \
  --result-ref "$QUARANTINE_HEAD_REF=$H" \
  --advertisement-capture "$HOST_HEAD_ADVERTISEMENT_SEAL"

MERGE_RESOURCE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-resource \
  --root "$EVIDENCE_ROOT" --kind host-merge-quarantine \
  --template empty-bare-git --print-field resourceId)"
MERGE_QUARANTINE="$EVIDENCE_ROOT/resources/host-merge-quarantine.$MERGE_RESOURCE_ID.git"
QUARANTINE_HOST_CANDIDATE_REF="refs/qinao/host-candidate/$TUPLE_DIGEST/$HOST_HEAD_CAPTURE_ID"
MERGE_RESOURCE_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$MERGE_RESOURCE_ID" \
  --state initial-empty-bare --print-field snapshotDigest)"
MERGE_FETCH_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$EVIDENCE_ROOT" --kind host-merge-fetch --recover-exact \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --stable-projection "$NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST" \
  --resource-id "$MERGE_RESOURCE_ID" --input-snapshot "$MERGE_RESOURCE_BEFORE" \
  --candidate-head-capture "$HOST_HEAD_ADVERTISEMENT_SEAL" \
  --remote-ref "refs/pull/$PR_NUMBER/merge" \
  --quarantine-ref "$QUARANTINE_HOST_CANDIDATE_REF" --print-field frontierId)"
MERGE_FETCH_INTENT="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FETCH_FRONTIER" \
  --print-field startRecordPath)"
set +e
qinao_network_git --intent "$MERGE_FETCH_INTENT" --operation fetch-empty -- \
  -C "$MERGE_QUARANTINE" -c core.hooksPath=/dev/null fetch \
  --no-tags --no-auto-maintenance --no-write-commit-graph \
  --no-recurse-submodules --no-write-fetch-head \
  https://github.com/ChangGeng01/ProjectSix.git \
  "refs/pull/$PR_NUMBER/merge:$QUARANTINE_HOST_CANDIDATE_REF"
HOST_CANDIDATE_FETCH_EXIT=$?
set -e
if test "$HOST_CANDIDATE_FETCH_EXIT" = 0; then
  HOST_MERGE_OID="$(sterile_git -C "$MERGE_QUARANTINE" \
    rev-parse "$QUARANTINE_HOST_CANDIDATE_REF^{commit}")"
  MERGE_RESOURCE_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
    --root "$EVIDENCE_ROOT" --resource-id "$MERGE_RESOURCE_ID" \
    --state fetched-host-merge --expected-ref "$QUARANTINE_HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --print-field snapshotDigest)"
  MERGE_SOURCE_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
    --root "$EVIDENCE_ROOT" --phase host-candidate-merge-source \
    --parent-capture "$HOST_HEAD_ADVERTISEMENT_SEAL" --print-field captureId)"
  MERGE_SOURCE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --capture-id "$MERGE_SOURCE_CAPTURE_ID" \
    --print-field absolutePath)"
  qinao_python scripts/qinao_workflow_inventory.py validate-host-candidate \
    --repository "$MERGE_QUARANTINE" --commit "$HOST_MERGE_OID" \
    --expected-ref "$QUARANTINE_HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --B "$B" --H "$H" --T "$T" --mode local-resource \
    --output "$MERGE_SOURCE_DIR/host-candidate-source.json" \
    --capture-files-output "$MERGE_SOURCE_DIR/seal-files.txt"
  MERGE_SOURCE_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
    --root "$EVIDENCE_ROOT" --capture-id "$MERGE_SOURCE_CAPTURE_ID" \
    --files-from "$MERGE_SOURCE_DIR/seal-files.txt" --print-field sealRecordPath)"
  MERGE_FETCH_TERMINAL="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FETCH_FRONTIER" \
    --recover-exact --state completed --result-snapshot "$MERGE_RESOURCE_AFTER" \
    --result-ref "$QUARANTINE_HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --source-capture "$MERGE_SOURCE_SEAL" --print-field terminalRecordPath)"
  HOST_IMPORT_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
    --root "$EVIDENCE_ROOT" --repository "$WT" --require-ref-absent "$HOST_CANDIDATE_REF" \
    --state before-host-candidate-import --print-field snapshotDigest)"
  HOST_IMPORT_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
    --root "$EVIDENCE_ROOT" --kind host-candidate-import --recover-exact \
    --repository "$WT" --source-resource-id "$MERGE_RESOURCE_ID" \
    --source-snapshot "$MERGE_RESOURCE_AFTER" \
    --source-capture "$MERGE_SOURCE_SEAL" \
    --source-frontier-terminal "$MERGE_FETCH_TERMINAL" \
    --source-ref "$QUARANTINE_HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --destination-ref "$HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --input-git-state "$HOST_IMPORT_BEFORE" --print-field frontierId)"
  sterile_git -c core.hooksPath=/dev/null fetch \
    --no-tags --no-auto-maintenance --no-write-commit-graph \
    --no-recurse-submodules --no-write-fetch-head \
    "$MERGE_QUARANTINE" \
    "$QUARANTINE_HOST_CANDIDATE_REF:$HOST_CANDIDATE_REF"
  HOST_IMPORT_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
    --root "$EVIDENCE_ROOT" --repository "$WT" --compare-input "$HOST_IMPORT_BEFORE" \
    --allow-source-resource "$MERGE_RESOURCE_ID:$MERGE_RESOURCE_AFTER" \
    --require-only-ref-addition "$HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --state after-host-candidate-import --print-field snapshotDigest)"
  HOST_IMPORT_TERMINAL="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$EVIDENCE_ROOT" --frontier-id "$HOST_IMPORT_FRONTIER" \
    --recover-exact --state completed --repository "$WT" \
    --result-git-state "$HOST_IMPORT_AFTER" \
    --result-ref "$HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --source-capture "$MERGE_SOURCE_SEAL" --print-field terminalRecordPath)"
  HOST_RESULT_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
    --root "$EVIDENCE_ROOT" --phase host-candidate-local-result \
    --parent-capture "$MERGE_SOURCE_SEAL" --print-field captureId)"
  HOST_RESULT_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --capture-id "$HOST_RESULT_CAPTURE_ID" \
    --print-field absolutePath)"
  qinao_python scripts/qinao_workflow_inventory.py validate-host-candidate \
    --repository "$WT" --commit "$HOST_MERGE_OID" \
    --expected-ref "$HOST_CANDIDATE_REF=$HOST_MERGE_OID" \
    --source-capture "$MERGE_SOURCE_SEAL" --import-terminal "$HOST_IMPORT_TERMINAL" \
    --B "$B" --H "$H" --T "$T" --mode imported-ref \
    --output "$HOST_RESULT_DIR/host-candidate-result.json" \
    --capture-files-output "$HOST_RESULT_DIR/seal-files.txt"
  HOST_CANDIDATE_RESULT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
    --root "$EVIDENCE_ROOT" --capture-id "$HOST_RESULT_CAPTURE_ID" \
    --files-from "$HOST_RESULT_DIR/seal-files.txt" --print-field sealRecordPath)"
else
  MERGE_TAINTED_SNAPSHOT="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
    --root "$EVIDENCE_ROOT" --resource-id "$MERGE_RESOURCE_ID" \
    --state merge-fetch-failed-tainted --print-field snapshotDigest)"
  MERGE_FETCH_TERMINAL="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FETCH_FRONTIER" \
    --recover-exact --state tainted-preserved \
    --result-snapshot "$MERGE_TAINTED_SNAPSHOT" \
    --reason fetch-did-not-produce-merge-ref --print-field terminalRecordPath)"
fi
```

The success branch already seals the validated source before fetch completion and seals the imported result afterward; the unique local ref is never changed/deleted. Only when the fetch frontier is terminal `tainted-preserved` may the failure branch allocate a distinct absence capture and execute this single-row child manifest bound to that terminal failure projection:

```bash
if test "$HOST_CANDIDATE_FETCH_EXIT" != 0; then
MERGE_FETCH_FAILURE_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FETCH_FRONTIER" \
  --require-terminal-record "$MERGE_FETCH_TERMINAL" \
  --print-field terminalSafeProjectionDigest)"
MERGE_ABSENCE_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase host-candidate-merge-absence \
  --parent-capture "$HOST_HEAD_ADVERTISEMENT_SEAL" --print-field captureId)"
MERGE_ABSENCE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$MERGE_ABSENCE_CAPTURE_ID" \
  --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase host-candidate-merge-absence --repository ChangGeng01/ProjectSix \
  --parent-projection "$MERGE_FETCH_FAILURE_PROJECTION_DIGEST" \
  --pr-number "$PR_NUMBER" \
  --output "$MERGE_ABSENCE_DIR/merge-absence-request-rows.json"
MERGE_ABSENCE_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$MERGE_ABSENCE_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$MERGE_ABSENCE_DIR/merge-absence-request-rows.json" \
  --print-field manifestPath)"
set +e
qinao_network_git --intent "$MERGE_ABSENCE_INTENT" --operation ls-remote -- \
  -C "$WT" ls-remote --exit-code origin "refs/pull/$PR_NUMBER/merge" \
  >"$MERGE_ABSENCE_DIR/merge-absence.tsv"
MERGE_ABSENCE_EXIT=$?
set -e
test "$MERGE_ABSENCE_EXIT" = 2
MERGE_ABSENCE_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  validate-remote-advertisement --input "$MERGE_ABSENCE_DIR/merge-absence.tsv" \
  --request-manifest "$MERGE_ABSENCE_INTENT" \
  --output "$MERGE_ABSENCE_DIR/merge-absence.json" \
  --capture-files-output "$MERGE_ABSENCE_DIR/seal-files.txt" \
  --require-zero-rows --print-field recordDigest)"
MERGE_ABSENCE_RECORD="$MERGE_ABSENCE_DIR/merge-absence.json"
MERGE_ABSENCE_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$MERGE_ABSENCE_CAPTURE_ID" \
  --files-from "$MERGE_ABSENCE_DIR/seal-files.txt" --print-field sealRecordPath)"
fi
```

Only parsed exit `2` with zero rows is authoritative absence. A network/auth/parse failure is not absence. For authoritative absence, first seal the exact PR safe projection, render a `host-candidate-rest-pull` child manifest, and perform the only allowed first REST fallback. The commit SHA discovered there is then written to a bounded canonical ID file; render a second `host-candidate-rest-commit` child manifest bound to the pull projection digest before the commit request. `HOST_CANDIDATE_READ_INTENT` below therefore denotes the first single-use child manifest and `HOST_CANDIDATE_COMMIT_INTENT` the second; neither is an allocation record or reused row:

The merge-ref fetch is a narrowly declared exception to advertisement proof only because it starts from a separately snapshotted zero-ref/zero-object resource and requests exactly one provider-generated pull ref whose OID is not known in advance. Its frontier binds the exact PR number/ref and zero-have resource; success is not admitted until the fetched commit proves ordered parents `[B,H]` and tree `T`, while failure is always `tainted-preserved` followed by the exact absence/REST protocol. It never uses the self-declared ref name as proof of an advertised OID and never negotiates with shared/local objects.

```bash
if test "$HOST_CANDIDATE_FETCH_EXIT" != 0; then
HOST_PULL_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase host-candidate-rest-pull \
  --parent-capture "$MERGE_ABSENCE_SEAL" --print-field captureId)"
HOST_PULL_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$HOST_PULL_CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase host-candidate-rest-pull --repository ChangGeng01/ProjectSix \
  --parent-record "$MERGE_ABSENCE_RECORD" \
  --parent-projection "$MERGE_ABSENCE_PROJECTION_DIGEST" \
  --pr-number "$PR_NUMBER" \
  --output "$HOST_PULL_DIR/host-candidate-pull-request-rows.json"
HOST_CANDIDATE_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$HOST_PULL_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$HOST_PULL_DIR/host-candidate-pull-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$HOST_CANDIDATE_READ_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/pulls/$PR_NUMBER" \
  >"$HOST_PULL_DIR/host-candidate-pull.safe.json"
HOST_CANDIDATE_PULL_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" \
  --manifest "$HOST_CANDIDATE_READ_INTENT" --request-sequence 1 \
  --print-field safeProjectionDigest)"
HOST_MERGE_COMMIT_SHA="$(
  qinao_python scripts/qinao_workflow_inventory.py host-candidate-sha \
    --pull "$HOST_PULL_DIR/host-candidate-pull.safe.json" \
    --request-projection "$HOST_CANDIDATE_PULL_PROJECTION_DIGEST" \
    --B "$B" --H "$H" --output "$HOST_PULL_DIR/host-candidate-pull-result.json" \
    --capture-files-output "$HOST_PULL_DIR/seal-files.txt" \
    --print-field mergeCommitSha
)"
HOST_PULL_RESULT="$HOST_PULL_DIR/host-candidate-pull-result.json"
HOST_PULL_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$HOST_PULL_CAPTURE_ID" \
  --files-from "$HOST_PULL_DIR/seal-files.txt" --print-field sealRecordPath)"
HOST_COMMIT_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase host-candidate-rest-commit \
  --parent-capture "$HOST_PULL_SEAL" --print-field captureId)"
HOST_COMMIT_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$HOST_COMMIT_CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase host-candidate-rest-commit --repository ChangGeng01/ProjectSix \
  --parent-record "$HOST_PULL_RESULT" \
  --parent-projection "$HOST_CANDIDATE_PULL_PROJECTION_DIGEST" \
  --commit-oid "$HOST_MERGE_COMMIT_SHA" \
  --output "$HOST_COMMIT_DIR/host-candidate-commit-request-rows.json"
HOST_CANDIDATE_COMMIT_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$HOST_COMMIT_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$HOST_COMMIT_DIR/host-candidate-commit-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$HOST_CANDIDATE_COMMIT_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/git/commits/$HOST_MERGE_COMMIT_SHA" \
  >"$HOST_COMMIT_DIR/host-candidate-commit.safe.json"
qinao_python scripts/qinao_workflow_inventory.py validate-host-candidate \
  --mode rest --pull "$HOST_PULL_RESULT" \
  --commit-response "$HOST_COMMIT_DIR/host-candidate-commit.safe.json" \
  --commit-oid "$HOST_MERGE_COMMIT_SHA" --B "$B" --H "$H" --T "$T" \
  --absence-capture "$MERGE_ABSENCE_SEAL" --pull-capture "$HOST_PULL_SEAL" \
  --output "$HOST_COMMIT_DIR/host-candidate-result.json" \
  --capture-files-output "$HOST_COMMIT_DIR/seal-files.txt"
HOST_CANDIDATE_RESULT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$HOST_COMMIT_CAPTURE_ID" \
  --files-from "$HOST_COMMIT_DIR/seal-files.txt" --print-field sealRecordPath)"
fi
```

The pull normalizer obtains non-null 40-hex `merge_commit_sha` from the exact open PR response, checks base/head OIDs and repositories, writes a self-digesting semantic parent, and seals it before the commit request can be rendered. The second response must have `sha` equal to it, ordered `parents[].sha == [B,H]`, `tree.sha == T`, and a valid commit object; its terminal result is sealed separately. Recompute hermetic local `T` as a cross-check. Null/missing/changing `merge_commit_sha`, a 404/unreadable commit object, omitted/extra/swapped parent, different tree, or inability to prove the merge ref was authoritatively absent is `incomplete`; local `merge-tree` alone never substitutes for host-candidate evidence. A new base OID or different tree invalidates all evidence and returns to Task 11.

At every Step 1 entry, recover the capture chain first, then `host-head-fetch`, `host-merge-fetch`, and `host-candidate-import`. A resource frontier accepts only its exact input snapshot or exact single-ref complete poststate; partial/failed/unclassified resource bytes are terminal `tainted-preserved` and a new empty resource is allocated, never cleaned/reused. An open shared import accepts only input-unchanged or valid source-attributable objects with destination absent (continue the same local fetch), or exact destination/object poststate (append `recovered-completed`); foreign ref/object/admin drift blocks. If local import is already terminal but its result capture is absent/incomplete, regenerate only that pure result capture from the sealed source and terminal record. The REST fallback is legal only after one terminal failed merge-fetch plus one sealed authoritative-absence capture; each dynamic request consumes the immediately preceding semantic record/seal and writes only its own child. Crash fixtures cover every allocation/write/seal/frontier boundary, effect before resource completion, ref update before shared completion, terminal fsync/lost stdout, and prove no capture is written after seal and no side-effecting stage is replayed.

- [ ] **Step 2: Wait for every selected candidate-controlled CI job**

Require terminal conclusions for the six baseline jobs, `qinao-protocol-tests`, `risk-check`, and `pr-metadata`. For **every** accepted job, stream the complete log through `job-log-read`, locate exactly one canonical `qinao.ci-identity.v1` record, validate its self-digest, and require exact current `(B,H,T,V)` plus current PR-body SHA-256. The `risk-check` stream must additionally contain one valid `qinao.risk-result.v1` record with class high and the exact local raw-diff digest/reasons. Record workflow path/blob, event `pull_request`, run ID/attempt, job/check name and ID, start/end, conclusion, safe URL projection, whole-stream SHA-256, and identity-record digest. A green job without all identity fields is supplemental and cannot satisfy required CI.

Enumerate runs/jobs/check-suites/check-runs/statuses with complete pagination from the fixed REST API version. Commit-level check runs always use `filter=all`; never accept GitHub's default `latest`, which can hide older same-name runs. Independently enumerate every check suite for `H` and every suite's `filter=all` check runs, then require exact normalized-union/count agreement with the commit-level collection. Reaching the provider's 1,000-suite/check-run cap, an inconsistent `total_count`, a missing suite page, a run absent from either view, or any inability to prove complete termination is `unknown` and blocks. Select only the latest complete `pull_request` run set whose event payload/body digest and nine identity records match; a push, workflow-dispatch, default merge-checkout, stale body, earlier head/base/tree/policy, missing log, or duplicate record is not candidate-required evidence.

For every polling iteration allocate a fresh `phase=ci-observation` capture, set `CI_DIR="$CAPTURE_DIR"`, and use these exact reads with `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28` on every request. Seal one iteration only after all files/statuses/logs close; partial iterations remain immutable and are never selected:

```bash
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase ci-static --repository ChangGeng01/ProjectSix \
  --B "$B" --H "$H" --iteration "$CI_ITERATION" \
  --output "$CI_DIR/ci-static-request-rows.json"
CI_STATIC_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CI_DIR/ci-static-request-rows.json" --print-field manifestPath)"
qinao_gh --intent "$CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/actions/runs?event=pull_request&head_sha=$H&per_page=100" \
  >"$CI_DIR/ci-runs.pages.json"
qinao_gh --intent "$CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/commits/$H/check-runs?filter=all&per_page=100" \
  >"$CI_DIR/check-runs.pages.json"
qinao_gh --intent "$CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/commits/$H/check-suites?per_page=100" \
  >"$CI_DIR/check-suites.pages.json"
qinao_gh --intent "$CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/commits/$H/statuses?per_page=100" \
  >"$CI_DIR/statuses.pages.json"
qinao_gh --intent "$CI_STATIC_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' rate_limit \
  >"$CI_DIR/rate-limit.json"
```

After validating the complete suite page envelope and its count/cap, emit the sorted unique suite IDs with the pure inventory parser. For each ID, make this request into a unique O_EXCL-created filename in the same capture (the shell loop is bounded to the validated suite-ID set and refuses an existing output):

```bash
CI_STATIC_REQUEST_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$CI_STATIC_INTENT" \
  --print-field manifestSafeProjectionDigest)"
CI_STATIC_RESULT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py \
  observation-projection \
  --capture "$CI_DIR" --through static \
  --request-projection "$CI_STATIC_REQUEST_PROJECTION_DIGEST" \
  --suite-ids-output "$CI_DIR/check-suite-ids.txt" \
  --output "$CI_DIR/ci-static-projection.json" --print-field projectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase ci-suite-runs --repository ChangGeng01/ProjectSix \
  --parent-record "$CI_DIR/ci-static-projection.json" \
  --parent-projection "$CI_STATIC_RESULT_PROJECTION_DIGEST" \
  --ids "$CI_DIR/check-suite-ids.txt" \
  --output "$CI_DIR/ci-suite-request-rows.json"
CI_SUITE_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CI_DIR/ci-suite-request-rows.json" --print-field manifestPath)"
set -C
while IFS= read -r CHECK_SUITE_ID; do
  test -n "$CHECK_SUITE_ID"
  SUITE_RUNS="$CI_DIR/check-suite-$CHECK_SUITE_ID-runs.pages.json"
  test ! -e "$SUITE_RUNS"
  qinao_gh --intent "$CI_SUITE_READ_INTENT" --operation rest-read -- \
    api --paginate --slurp \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "repos/ChangGeng01/ProjectSix/check-suites/$CHECK_SUITE_ID/check-runs?filter=all&per_page=100" \
    >"$SUITE_RUNS"
done <"$CI_DIR/check-suite-ids.txt"
set +C
```

After the two-view union is validated, the pure parser emits sorted `check-run-id<TAB>annotations-count` rows. Fetch the distinct annotation family only for positive counts:

```bash
CI_SUITE_REQUEST_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$CI_SUITE_READ_INTENT" \
  --print-field manifestSafeProjectionDigest)"
CI_SUITE_RESULT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py \
  observation-projection \
  --capture "$CI_DIR" --through suites \
  --request-projection "$CI_SUITE_REQUEST_PROJECTION_DIGEST" \
  --parent-record "$CI_DIR/ci-static-projection.json" \
  --parent-projection "$CI_STATIC_RESULT_PROJECTION_DIGEST" \
  --suite-selection "$CI_DIR/ci-static-projection.json" \
  --annotation-counts-output "$CI_DIR/check-run-annotation-counts.tsv" \
  --output "$CI_DIR/ci-suite-projection.json" --print-field projectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase ci-annotations --repository ChangGeng01/ProjectSix \
  --parent-record "$CI_DIR/ci-suite-projection.json" \
  --parent-projection "$CI_SUITE_RESULT_PROJECTION_DIGEST" \
  --ids "$CI_DIR/check-run-annotation-counts.tsv" \
  --output "$CI_DIR/ci-annotation-request-rows.json"
CI_ANNOTATION_READ_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CI_DIR/ci-annotation-request-rows.json" --print-field manifestPath)"
set -C
while IFS=$'\t' read -r CHECK_RUN_ID ANNOTATION_COUNT; do
  case "$CHECK_RUN_ID:$ANNOTATION_COUNT" in
    *[!0-9:]*|:*|*:) exit 2 ;;
  esac
  test "$CHECK_RUN_ID" -gt 0
  test "$ANNOTATION_COUNT" -ge 0
  if test "$ANNOTATION_COUNT" -gt 0; then
    ANNOTATIONS="$CI_DIR/check-run-$CHECK_RUN_ID-annotations.pages.json"
    test ! -e "$ANNOTATIONS"
    qinao_gh --intent "$CI_ANNOTATION_READ_INTENT" --operation rest-read -- \
      api --paginate --slurp \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "repos/ChangGeng01/ProjectSix/check-runs/$CHECK_RUN_ID/annotations?per_page=100" \
      >"$ANNOTATIONS"
  fi
done <"$CI_DIR/check-run-annotation-counts.tsv"
set +C
```

Before sealing, `qinao_workflow_inventory.py` cross-checks suite IDs, every page envelope/`total_count`, the suite-level union, the commit-level `filter=all` union, every check-run raw/output digest, and every annotation page/count. The validated ID/count files are captured and hashed; a zero-suite result is allowed only when the ref-level run union is also empty, which cannot satisfy the nine required checks. A successful run with an undisposed notice/warning/failure annotation is incomplete rather than silently green.

For the selected unique run and each selected unique job, use the same explicit headers:

```bash
CI_ANNOTATION_REQUEST_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$CI_ANNOTATION_READ_INTENT" \
  --print-field manifestSafeProjectionDigest)"
CI_ANNOTATION_RESULT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py \
  observation-projection --capture "$CI_DIR" --through annotations \
  --request-projection "$CI_ANNOTATION_REQUEST_PROJECTION_DIGEST" \
  --parent-record "$CI_DIR/ci-suite-projection.json" \
  --parent-projection "$CI_SUITE_RESULT_PROJECTION_DIGEST" \
  --suite-selection "$CI_DIR/ci-static-projection.json" \
  --annotation-selection "$CI_DIR/ci-suite-projection.json" \
  --output "$CI_DIR/ci-annotation-projection.json" \
  --print-field projectionDigest)"
CANDIDATE_WORKFLOW_BLOB="$(sterile_git rev-parse "$H:.github/workflows/test.yml")"
CI_RUN_SELECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py select-ci-run \
  --capture "$CI_DIR" --event pull_request --head "$H" \
  --workflow-path .github/workflows/test.yml \
  --workflow-blob "$CANDIDATE_WORKFLOW_BLOB" \
  --workflow-contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json \
  --observation-projection "$CI_DIR/ci-annotation-projection.json" \
  --output "$CI_DIR/selected-run-selection.json" \
  --ids-output "$CI_DIR/selected-run-attempt.tsv" --print-field selectionDigest)"
RUN_ID="$(qinao_python scripts/qinao_workflow_inventory.py read-ci-run-selection \
  --selection "$CI_DIR/selected-run-selection.json" \
  --ids "$CI_DIR/selected-run-attempt.tsv" --print-field runId)"
RUN_ATTEMPT="$(qinao_python scripts/qinao_workflow_inventory.py read-ci-run-selection \
  --selection "$CI_DIR/selected-run-selection.json" \
  --ids "$CI_DIR/selected-run-attempt.tsv" --print-field runAttempt)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase ci-selected-jobs --repository ChangGeng01/ProjectSix \
  --parent-record "$CI_DIR/selected-run-selection.json" \
  --parent-projection "$CI_RUN_SELECTION_DIGEST" \
  --ids "$CI_DIR/selected-run-attempt.tsv" \
  --output "$CI_DIR/ci-selected-jobs-request-rows.json"
CI_JOB_LIST_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CI_DIR/ci-selected-jobs-request-rows.json" --print-field manifestPath)"
qinao_gh --intent "$CI_JOB_LIST_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/actions/runs/$RUN_ID/attempts/$RUN_ATTEMPT/jobs?per_page=100" \
  >"$CI_DIR/ci-jobs.pages.json"
CI_JOB_LIST_REQUEST_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$CI_JOB_LIST_INTENT" \
  --print-field manifestSafeProjectionDigest)"
CI_JOB_SELECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py select-ci-jobs \
  --jobs "$CI_DIR/ci-jobs.pages.json" --expected-set candidate-nine \
  --request-projection "$CI_JOB_LIST_REQUEST_PROJECTION_DIGEST" \
  --parent-record "$CI_DIR/selected-run-selection.json" \
  --parent-projection "$CI_RUN_SELECTION_DIGEST" \
  --output "$CI_DIR/selected-job-selection.json" \
  --ids-output "$CI_DIR/selected-job-ids.txt" --print-field selectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase ci-job-logs --repository ChangGeng01/ProjectSix \
  --parent-record "$CI_DIR/selected-job-selection.json" \
  --parent-projection "$CI_JOB_SELECTION_DIGEST" \
  --ids "$CI_DIR/selected-job-ids.txt" \
  --output "$CI_DIR/ci-job-log-request-rows.json"
CI_JOB_LOG_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CI_DIR/ci-job-log-request-rows.json" --print-field manifestPath)"
while IFS= read -r JOB_ID; do
  qinao_gh --intent "$CI_JOB_LOG_INTENT" --operation job-log-read -- \
    api -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "repos/ChangGeng01/ProjectSix/actions/jobs/$JOB_ID/logs" \
    >"$CI_DIR/ci-job-$JOB_ID.safe.json"
done <"$CI_DIR/selected-job-ids.txt"
qinao_python scripts/qinao_workflow_inventory.py validate-candidate-ci \
  --capture "$CI_DIR" --B "$B" --H "$H" --T "$T" --V "$V" \
  --body-digest "$PR_BODY_SHA256" \
  --workflow-contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json \
  --output "$CI_DIR/candidate-ci-result.json" \
  --capture-files-output "$CI_DIR/candidate-ci-seal-files.txt"
CI_CAPTURE_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" \
  --files-from "$CI_DIR/candidate-ci-seal-files.txt" \
  --print-field sealRecordPath)"
```

The wrapper streams and hashes each complete raw log in memory before parsing but persists only its safe projection, validated identity/risk lines, counts, and whole-stream digest. The normalizer requires nine exact expected job names, unique IDs, same workflow path/blob and run attempt, completed/success conclusions, no extra selected-name producer, and full page termination.

Treat success as evidence only. Missing, skipped-selected, neutral, cancelled, timed out, action-required, stale, or attached only to another head/candidate is incomplete.

Waiting is a bounded observation protocol, not an unbounded shell loop. Use a monotonic 90-minute total deadline (covering the 45-minute SampleHost bound plus queue/teardown), intervals `15,30,45,60,60...` seconds with no single wait over 60 seconds, and a unique iteration number. Every iteration captures/hashes fresh run, check-run, status, selected-attempt job, and rate-limit header/body files before selection; it never overwrites an earlier iteration. A nonterminal but structurally complete iteration runs `validate-candidate-ci --allow-incomplete`, emits an explicit incomplete result/whitelist, seals that capture, and only then allocates the next iteration; malformed/partial transport cannot be promoted to this state. Stop immediately on a terminal required failure, identity/body drift, authentication/rate-limit uncertainty, or base/head change. Success requires all nine exact terminal records in one accepted attempt. Deadline exhaustion emits a canonical `incomplete` wait result containing iteration count, first/last monotonic offsets, last observed IDs/states/digests, and timeout reason; it never promotes the latest partial snapshot.

- [ ] **Step 3: Dispatch four fresh specialist reviews**

Use `superpowers:requesting-code-review` and four fresh reviewers matching the exact configuration partitions. Give each reviewer:

- approved spec and this plan;
- full raw diff manifest and assigned entries;
- complete remote-object disclosure plus the three pre-push egress-review digests (never raw suspect/private bytes);
- `B/H/T/V`;
- relevant source blobs, tests, evidence, and limitations;
- requirement to return the exact `qinao.review-result.v1` object with stable IDs, evidence, severity, and `fixed/false-positive/disputed-impact/incomplete` state.

No reviewer edits files. Their independent reports are persisted locally and hashed.

- [ ] **Step 4: Run one integration review**

A fifth fresh reviewer receives all four reports, the complete raw manifest, remote-object disclosure, and all three pre-push egress reports. It checks cross-module types, identity algebra, recovery paths, workflow/host trust boundary, validation semantics, document transforms, Git object-egress/LFS-presence closure, binary provenance, and coverage. It must account for every raw entry, every newly reachable-object disposition/report digest, and every specialist finding; it cannot retroactively cure an egress that lacked the pre-push gate.

If any confirmed actionable or incomplete finding exists, fix it with TDD, commit, push only the new exact `H` after Task 11 restarts, and repeat Tasks 11–13. A false-positive or disputed-impact needs the exact evidence required by Task 10; unknown or truncated review cannot be waived.

- [ ] **Step 5: Optionally run CodeRabbit as supplemental review**

This implementation plan does not execute CodeRabbit because its independent network destinations/credential/output retention are outside the sealed `network-git`/`network-gh` boundary. Record `supplementalCodeRabbit=not-run-egress-out-of-scope`; the four specialist plus integration reviews remain the concrete required producer. A later run may add CodeRabbit only through a separately reviewed user-authorized egress profile and immutable intent—not by invoking its ambient CLI from Tasks 11–15.

- [ ] **Step 5A: Finalize the machine finding list and update the same PR body with tri-state recovery**

Render the final body from canonical metadata so `findingDispositions` exactly matches the four specialist reports, integration report, and every supplemental CodeRabbit finding when a terminal supplemental run exists. Before mutation, GET the PR in a fresh read capture with fixed API headers, require current body digest `OLD_BODY_SHA256`, and compute `INTENDED_BODY_SHA256`. If the digests already match, make no request. Otherwise allocate and seal one request-only `phase=pr-body-patch-request` capture containing the canonical one-key request and exact rows. The immutable frontier/attempt ledger—not that sealed directory—records the transport result:

```bash
PATCH_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase pr-body-patch-request --print-field captureId)"
PATCH_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$PATCH_CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_pr_protocol.py render-pr-patch-request \
  --body-file "$INTENDED_PR_BODY_FILE" \
  --output "$PATCH_DIR/pr-body-update-request.json"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase pr-body-patch --repository ChangGeng01/ProjectSix \
  --pr-number "$PR_NUMBER" --request "$PATCH_DIR/pr-body-update-request.json" \
  --output "$PATCH_DIR/pr-body-patch-request-rows.json"
PATCH_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$PATCH_CAPTURE_ID" \
  --file pr-body-update-request.json --file pr-body-patch-request-rows.json \
  --print-field sealRecordPath)"
PATCH_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  frontier-start --root "$EVIDENCE_ROOT" --kind remote-pr-patch \
  --recover-exact --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --request-capture "$PATCH_REQUEST_SEAL" \
  --request-rows "$PATCH_DIR/pr-body-patch-request-rows.json" \
  --request "$PATCH_DIR/pr-body-update-request.json" \
  --pr-number "$PR_NUMBER" --old-body "$OLD_BODY_SHA256" \
  --intended-body "$INTENDED_BODY_SHA256" --print-field startRecordPath)"
set +e
qinao_gh --intent "$PATCH_INTENT_RECORD" --operation pr-patch -- \
  api --method PATCH \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/pulls/$PR_NUMBER" \
  --input "$PATCH_DIR/pr-body-update-request.json" \
  >/dev/null
PATCH_EXIT=$?
set -e
PATCH_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --intent "$PATCH_INTENT_RECORD" \
  --require-wrapper-exit "$PATCH_EXIT" --print-field attemptRecordPath)"
```

After any exit—including timeout or lost response—allocate a new `phase=pr-body-observation` read capture with `--parent-capture "$PATCH_REQUEST_SEAL" --parent-attempt "$PATCH_ATTEMPT_RECORD"`, render/seal its exact one-PR GET manifest, execute it through `qinao_gh`, normalize the result, and seal the observation; never append it into `PATCH_DIR`. Exact intended digest is `confirmed-success`, including recovery after a transport-unknown result. Exact old digest is `confirmed-no-effect` only when the request also returned a parsed authenticated terminal rejection whose endpoint semantics prove non-acceptance. Exact old digest after timeout/lost/unreadable transport remains `indeterminate` regardless of repeated immediate reads; GitHub has no idempotency key or pending-operation proof, so that logical PATCH is never replayed. Any other digest, unreadable response, changed head/base/state, or multiple observations is also `indeterminate`. For either terminal classification, set `REMOTE_FRONTIER_ID` from `PATCH_INTENT_RECORD` and run the Task 6 terminal pattern with the sealed observation/classifier; indeterminate remains open and blocks comments/merge. A genuinely confirmed no-effect completion needs fresh user recovery instruction before one new operation.

A successful body update invalidates all earlier body-bound CI and any `E/A` computation. Wait for the `pull_request: edited` run, repeat Steps 1–2, and require all nine new identity records to carry `INTENDED_BODY_SHA256`. Code/raw-diff reviews remain valid only because `(B,H,T,V)`, raw manifest, assignment, and review configuration did not change; any of those changes returns to Task 11 and reruns reviews too.

- [ ] **Step 6: Capture the final finite automation observation**

At exact `H` and PR number, enumerate:

- repository tree paths/blobs under workflows/actions and their structured triggers/jobs/permissions/actions/data flows;
- repository/Actions/Pages settings and the complete deployments collection;
- hooks, environments and their secret/variable metadata, repository Actions secret/variable metadata, self-hosted runners, nonterminal runs, deploy keys, installed apps/integrations, collaborators, and pending repository invitations;
- rulesets/protection known tier state;
- complete PR checks, statuses, review submissions, pull-request review comments, issue/timeline comments, review/comment producers, and auto-merge state.

Allocate a fresh `phase=host-final` capture and repeat every Task 12 host request into it—never reuse the initial bytes or a partial final generation—including the complete per-workflow histories, nonterminal union, and one exact historical Contents request/decoded-blob proof for every unique `(run.head_sha,literalLegacyPath)` derived in this snapshot. Also GET the exact pull; fully paginated `pulls/$PR_NUMBER/reviews?per_page=100`; the separate fully paginated `pulls/$PR_NUMBER/comments?per_page=100` review-comment collection; commit-level `commits/$H/check-runs?filter=all&per_page=100`; complete `commits/$H/check-suites?per_page=100` plus every suite's `check-runs?filter=all&per_page=100`; every positive-count check run's fully paginated `/check-runs/{id}/annotations` plus all run output/raw digests; `commits/$H/statuses?per_page=100`; selected Actions run/jobs/logs; and the separate complete `issues/$PR_NUMBER/comments?per_page=100` timeline-comment set. Never substitute one of the three review/review-comment/issue-comment collections for another. Apply the same two-view check-run union/count/cap/output/annotation proof as Step 2; default-`latest` output is invalid. Use the same media/version headers, RFC-3986 path/ref construction, dynamic-family manifest, and page-envelope rules. Store non-sensitive fields and redacted response digests; never secret values/tokens. Seal only a complete generation and validate it with `qinao_workflow_inventory.py`. Any historical run-source 404/mismatch, high-privilege unknown, workflow/action/check-annotation omission, review/comment omission, write/secret/deploy surface, cross-trigger candidate data into privilege, stale CI identity, or initial/final capability drift stops.

- [ ] **Step 7: Compute `A`, choose the next evidence generation, and assemble canonical `E`**

Fetch the complete comments before building `E`. Validate every complete final-evidence generation as an immutable contiguous chain and classify the optional single staging prefix under Task 6. If staging exactly matches the current durable canonical record, resume that reserved sequence. If it binds an older tuple but remains fully reconstructable, finish it as historical before continuing; otherwise stop. With no staging, choose `evidenceSequence=maxComplete+1` and `supersedesManifestDigest` equal to the latest complete manifest digest (or sequence 1/`null`). If the latest complete generation already binds the exact current tuple/body/all payload inputs, reuse it and do not create a new generation; otherwise assemble a new one. Compute `A` from the validated inventory. Assemble the closed final payload with:

- PR number/full body digest;
- `S/S-tree/spec-blob/D/D-tree/5c/C/C-tree/C-parents` and document-inventory/protected-state digests;
- `B/H/T/V/M="merge"/P=[B,H]`;
- automation schema/version/`A`;
- frozen authenticated interactive actor login/numeric ID and response digest (outside automation authority);
- selected network-egress preflight/config/executable/endpoint digest and workflow-file credential-permission proof digest;
- raw diff/manifest/count;
- complete new-reachable Git/LFS object disclosure, remote-advertisement digest, and all three pre-push egress-review digests;
- high risk/reason codes;
- every typed validation result;
- every review producer, artifact digest, complete finding/disposition;
- supplemental CodeRabbit evidence or limitation;
- every external URI plus digest;
- limitations, blast radius, rollback, forward recovery, irreversible effects, and explicit absence/presence of any separately authorized external effect;
- draft/mergeability/auto-merge observations.

Require all inputs bind the same tuple. Compute `E` with self-exclusion and verify the record by round-trip reconstruction.

- [ ] **Step 8: Preflight and post deterministic final-evidence chunks with unknown-outcome recovery**

For each chunk in index order and then the manifest, first create `BODY` locally with the pure renderer and record its SHA-256 plus expected sequence/logical key/record digest. Before any POST, query the authoritative full comment set and run the pure verifier. An existing exact staging prefix is valid: skip every exact prefix member and continue only with its next missing chunk. Exactly one pre-existing exact current item means `confirmed-preexisting`; authoritative zero for the next logical key with no conflicting marker **and no unresolved prior intent for that key** permits one POST. A non-prefix partial, duplicate, conflict, gap, unreadable state, or unresolved prior intent stops. Only the authoritative-zero next-item branch allocates and seals one request-only capture, then makes exactly one transport call:

```bash
COMMENT_REQUEST_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase comment-post-request \
  --print-field captureId)"
COMMENT_REQUEST_DIR="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --capture-id "$COMMENT_REQUEST_CAPTURE_ID" \
  --print-field absolutePath)"
qinao_python scripts/qinao_pr_protocol.py render-comment-request \
  --body-file "$BODY" --output "$COMMENT_REQUEST_DIR/comment-request.json"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase comment-post --repository ChangGeng01/ProjectSix \
  --pr-number "$PR_NUMBER" --request "$COMMENT_REQUEST_DIR/comment-request.json" \
  --output "$COMMENT_REQUEST_DIR/comment-post-request-rows.json"
COMMENT_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$COMMENT_REQUEST_CAPTURE_ID" \
  --file comment-request.json --file comment-post-request-rows.json \
  --print-field sealRecordPath)"
COMMENT_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  frontier-start --root "$EVIDENCE_ROOT" --kind remote-comment-post \
  --recover-exact --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --request-capture "$COMMENT_REQUEST_SEAL" \
  --request-rows "$COMMENT_REQUEST_DIR/comment-post-request-rows.json" \
  --request "$COMMENT_REQUEST_DIR/comment-request.json" \
  --logical-key "$EXPECTED_LOGICAL_KEY" \
  --record-digest "$EXPECTED_RECORD_DIGEST" --print-field startRecordPath)"
set +e
qinao_gh --intent "$COMMENT_INTENT_RECORD" --operation comment-post -- \
  api --method POST \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/issues/$PR_NUMBER/comments" \
  --input "$COMMENT_REQUEST_DIR/comment-request.json" \
  >/dev/null
COMMENT_EXIT=$?
set -e
COMMENT_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --intent "$COMMENT_INTENT_RECORD" \
  --require-wrapper-exit "$COMMENT_EXIT" --print-field attemptRecordPath)"
COMMENT_ATTEMPT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" \
  --intent "$COMMENT_INTENT_RECORD" --require-wrapper-exit "$COMMENT_EXIT" \
  --print-field attemptSafeProjectionDigest)"
```

After every exit, including an unknown/timeout exit, allocate a new request-seal/attempt-parented observation capture, query the authoritative full comment set, normalize it through the pure verifier, and seal the exact result generation:

```bash
COMMENT_OBSERVATION_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase comment-observation \
  --parent-capture "$COMMENT_REQUEST_SEAL" \
  --parent-attempt "$COMMENT_ATTEMPT_RECORD" --print-field captureId)"
COMMENT_OBSERVATION_DIR="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --capture-id "$COMMENT_OBSERVATION_CAPTURE_ID" \
  --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase comment-observation --repository ChangGeng01/ProjectSix \
  --pr-number "$PR_NUMBER" --logical-key "$EXPECTED_LOGICAL_KEY" \
  --parent-projection "$COMMENT_ATTEMPT_PROJECTION_DIGEST" \
  --output "$COMMENT_OBSERVATION_DIR/comment-observation-request-rows.json"
COMMENT_OBSERVATION_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$COMMENT_OBSERVATION_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$COMMENT_OBSERVATION_DIR/comment-observation-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$COMMENT_OBSERVATION_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/issues/$PR_NUMBER/comments?per_page=100" \
  >"$COMMENT_OBSERVATION_DIR/comments-pages.json"
qinao_python scripts/qinao_pr_protocol.py verify-comment-observation \
  --comments-pages "$COMMENT_OBSERVATION_DIR/comments-pages.json" \
  --expected-body "$BODY" \
  --expected-record-digest "$EXPECTED_RECORD_DIGEST" \
  --attempt-record "$COMMENT_ATTEMPT_RECORD" \
  --output "$COMMENT_OBSERVATION_DIR/comment-observation.json" \
  --capture-files-output "$COMMENT_OBSERVATION_DIR/seal-files.txt"
COMMENT_OBSERVATION_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$COMMENT_OBSERVATION_CAPTURE_ID" \
  --files-from "$COMMENT_OBSERVATION_DIR/seal-files.txt" \
  --print-field sealRecordPath)"
RECOVERY_CLASSIFICATION_RECORD="$COMMENT_OBSERVATION_DIR/comment-observation.json"
CONFIRMED_STATE="$(qinao_python scripts/qinao_pr_protocol.py \
  verify-comment-observation --verify "$RECOVERY_CLASSIFICATION_RECORD" \
  --observation-capture "$COMMENT_OBSERVATION_SEAL" --print-field state)"
```

Match exact sequence/logical marker/record/chunk/manifest digest while retaining whether POST returned a parsed authenticated terminal response or became transport-unknown:

- exactly one exact record: confirmed;
- authoritative zero is confirmed no effect only with a parsed authenticated terminal rejection whose endpoint semantics prove non-acceptance; an explicit recovery instruction may then authorize one new attempt;
- authoritative zero after timeout/lost/unreadable response, disconnect, or cancellation remains indeterminate and permanently forbids replay of that logical key, even when later immediate reads remain zero;
- duplicate, partial, conflicting, unreadable, or mismatched: indeterminate.

Execute the terminal decision without ambient state:

```bash
case "$CONFIRMED_STATE" in
  confirmed-success|confirmed-no-effect)
    REMOTE_FRONTIER_ID="$(qinao_python scripts/qinao_convergence_audit.py \
      recover-captures --root "$EVIDENCE_ROOT" --intent "$COMMENT_INTENT_RECORD" \
      --print-field frontierId)"
    qinao_python scripts/qinao_convergence_audit.py frontier-complete \
      --root "$EVIDENCE_ROOT" --frontier-id "$REMOTE_FRONTIER_ID" \
      --recover-exact --state "$CONFIRMED_STATE" \
      --attempt-record "$COMMENT_ATTEMPT_RECORD" \
      --observation-capture "$COMMENT_OBSERVATION_SEAL" \
      --classification-record "$RECOVERY_CLASSIFICATION_RECORD" \
      --require-operation-specific-postcondition
    ;;
  indeterminate) exit 75 ;;
  *) exit 2 ;;
esac
```

Indeterminate leaves the frontier open and blocks every next chunk/audit/merge; the staging protocol does not skip around it. Never infer success from a client exit alone. Do not delete or edit a conflicting comment automatically.

This is the generic comment transport reused for Task 14 `approval-audit` and Task 15 post-merge verification. It never retries a transport-unknown logical key; Task 14 additionally expires the human decision after any non-confirmed audit POST. The local generator has no network; the transport never reads an audit as permission. Each body receives its own sealed request generation, intent/attempt, sealed observation generation, pagination proof, terminal-response/transport-unknown classification, and recovery classification. Focused tests interrupt before/after request seal, attempt prewrite, transport return, observation manifest, normalized result, observation seal, and terminal fsync; they reject any request/attempt/observation parent mismatch, write-after-seal, duplicate attempt, or missing capture member.

- [ ] **Step 9: Reconstruct `final-evidence` from the PR timeline**

Fetch comments afresh, ignore comment ordering/IDs, validate the complete immutable generation chain, reconstruct the unique latest generation and its complete chunk set, verify predecessor/record digests and `E`, and compare every latest payload field with current PR/local evidence. Older generations remain historical and cannot satisfy the current tuple.

Expected task result: complete terminal candidate evidence visible in the PR timeline. Stop here and present it to the user; there is still no merge authorization.

### Task 14: Obtain one fresh human decision and perform at most one immediate native merge

**Files:**
- No tracked edits
- At most one new PR `approval-audit` timeline record for each fresh user decision; older immutable decision generations remain historical

**Interfaces:**
- Consumes: reconstructed `final-evidence`, exact current `B/H/T/V/A/M/P/E`, and a fresh explicit user decision in the active task.
- Produces: one audit record and at most one deliberate native merge attempt.

- [ ] **Step 1: Present the complete decision summary**

Show the user:

- PR link/number and exact `B/H/T/V/A/M/P/E`;
- frozen authenticated merge actor login/numeric ID and response digest;
- exact `S/D/C` source-convergence topology and complete plan/spec inventory/protected-state witnesses;
- high-risk reasons and full raw-diff scope;
- every validation target/count/outcome;
- every review producer and complete finding disposition;
- every `disputed-impact` finding and its exact evidence, with an explicit request that the user accept or reject that disposition for this exact state; no confirmed actionable finding is presentable for waiver;
- workflow/host/app inventory and current tier limitation;
- LFS/binary/irreversible effects;
- known iOS 27/toolchain/Swift Testing/application-data/DS3 limitations;
- rollback, forward recovery, and unknown-merge procedure;
- explicit statement that no snapshot was required and DS3 remains unauthorized.

Immediately before showing the summary, capture/digest the full comment set and all host/local inputs listed above; this is the pre-presentation snapshot used by Step 3. Ask for a fresh decision on this exact state. A generic earlier “好”, a PR comment, old approval, audit record, check, or resumed task is insufficient.

- [ ] **Step 2: Stop on anything except an explicit current approval**

If the user rejects, asks to change something, is ambiguous, or the task is interrupted before merge, do not merge. Apply changes through Task 11 or re-present the unchanged state for a new decision.

- [ ] **Step 3: Render and post one new audit generation without reusing approval**

Immediately before rendering, fetch the complete comment set and require byte/digest equality with the pre-presentation snapshot. Validate all earlier approval audits as an immutable contiguous chain; they are historical only. Set `decisionSequence=max(existing)+1` (or 1) and `supersedesAuditDigest` to the latest prior digest (or `null`). Render `qinao.approval-audit.v1` with those fields, decision text digest, timestamp, PR, exact `B/H/T/V/A/M/P/E`, frozen authenticated-user login/ID/response digest, high-risk reasons, complete finding dispositions, limitations, blast radius, irreversible effects, rollback/forward recovery, and explicit absence of any separate DS3/publication/release authorization.

Before POST, run the generic complete-comment preflight for this exact sequence/logical key. An existing exact current-decision record is acceptable only as recovery within the same uninterrupted active decision turn; zero permits one POST. Post once and immediately reconstruct/validate the whole audit chain.

Only one exact newly observed audit in this uninterrupted decision turn is `confirmed-success`. Any other outcome expires the approval. A parsed authenticated terminal rejection that proves non-acceptance permits returning to Step 1 and obtaining a **new** explicit approval before a new audit sequence. By contrast, authoritative zero after a timeout/lost/unreadable POST is still `indeterminate`; it forbids both replay of that logical key and creation of a later audit sequence until the missing effect is observed or endpoint evidence authoritatively proves non-acceptance. Duplicate sequence, conflicting body, unreadable/partial timeline, tuple drift, or interruption is likewise `indeterminate`; it never reuses the old decision. A later fresh decision creates the next sequence only from a fully authoritative chain with no unresolved intent. The audit records what the human decided; no script/workflow/status reads it to unlock anything.

- [ ] **Step 4: Immediately re-read all approval inputs**

Allocate and seal a request-only `phase=approval-main-reread-request` capture, then invoke the committed composition. The composition allocates its own advertisement/source-map/result captures; it never writes into the request capture or reuses any quarantine:

```bash
APPROVAL_REQUEST_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase approval-main-reread-request \
  --print-field captureId)"
APPROVAL_REQUEST_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$APPROVAL_REQUEST_CAPTURE_ID" \
  --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase approval-main-advertisement --repository ChangGeng01/ProjectSix \
  --B "$B" --H "$H" --output "$APPROVAL_REQUEST_DIR/approval-main-request-rows.json"
APPROVAL_REQUEST_MANIFEST="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$APPROVAL_REQUEST_CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$APPROVAL_REQUEST_DIR/approval-main-request-rows.json" \
  --capture-files-output "$APPROVAL_REQUEST_DIR/seal-files.txt" \
  --print-field manifestPath)"
APPROVAL_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$APPROVAL_REQUEST_CAPTURE_ID" \
  --files-from "$APPROVAL_REQUEST_DIR/seal-files.txt" --print-field sealRecordPath)"
APPROVAL_MAIN_REF="refs/qinao/approval-main/$TUPLE_DIGEST/$APPROVAL_REQUEST_CAPTURE_ID"
APPROVAL_OUTCOME_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  quarantine-ref-observe \
  --root "$EVIDENCE_ROOT" --repository "$WT" \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --advertisement-request-capture "$APPROVAL_REQUEST_SEAL" \
  --advertisement-manifest "$APPROVAL_REQUEST_MANIFEST" \
  --remote-ref refs/heads/main --expected-oid "$B" \
  --require-advertised-ref "refs/heads/codex/qinao-git-only-convergence=$H" \
  --destination-ref "$APPROVAL_MAIN_REF" \
  --print-field outcomeRecordPath)"
test "$(qinao_python scripts/qinao_convergence_audit.py quarantine-ref-observe \
  --verify-outcome "$APPROVAL_OUTCOME_RECORD" --print-field state)" = observation-sealed
APPROVAL_MAIN_OBSERVATION_SEAL="$(qinao_python \
  scripts/qinao_convergence_audit.py quarantine-ref-observe \
  --verify-outcome "$APPROVAL_OUTCOME_RECORD" --print-field observationSealRecordPath)"
```

The typed result must be `observation-sealed` with exact fresh advertisement/fetch/resource/import records and destination `B`; the merge intent later binds the outcome record plus observation seal path/digest. `fetch-completed` or `import-completed` is an intermediate recovery state and resumes only that lineage; `fetch-tainted`, any open frontier, different ref, credential/config drift, or foreign shared Git-state delta immediately expires approval and blocks merge. No fresh generation/retry is allowed within that approval turn. Then re-read PR head/body/state/draft/mergeability/auto-merge, host candidate, the complete check-suite/two-view-check-run/raw-output/annotation/status views, review submissions, pull-request review comments, issue/timeline comments, final-evidence, approval-audit, host/apps/workflows, and the complete automation inventory, including fresh historical Contents proofs for every run-source pair in the reread. Every collection is freshly and completely paginated through newly rendered static and response-bound dynamic manifests; review comments are never inferred from reviews or issue comments, and annotations/output are never inferred from a check conclusion/count. Recompute `T`, `V`, `A`, and `E`. Require byte-for-byte identity with the presented semantic state and exact expected observation-evidence transition.

The only permitted comment-set transition since presentation is **exactly one newly posted, reconstructed, digest-valid latest audit generation** matching the just-received decision/current tuple and naming the prior audit digest. Every earlier audit body/digest and every older evidence generation must remain byte-identical. Require the latest pre-existing final-evidence generation and all of its chunks to remain complete/byte-identical; freeze its manifest/chunk digests plus the new audit digest. Any other comment addition/edit/deletion, duplicate/conflicting current sequence, missing/changed final-evidence generation, or change to `B/H/T/V/A/M/P/E`, body/state, finding, check/review producer, mergeability, auto-merge, host setting, actor identity, or automation classification expires approval. If posting the audit causes any workflow/check/automation change, approval also expires. Historical audits are allowed but never current authority; the expected one-generation addition itself is not unknown comment drift.

- [ ] **Step 5: Perform one immediate canonical REST merge only when explicitly directed**

Re-read remote `refs/heads/main` and the exact PR immediately before the call and require `main=B`, head `H`, body/evidence/audit unchanged, mergeable, auto-merge absent, and authenticated actor unchanged. GitHub's merge endpoint has a head-SHA precondition but no base-SHA compare-and-swap; this trusted-single-owner procedure minimizes but cannot eliminate a base race. A base change before the call expires approval; a race during the call is detected by the exact `R` postcondition and is never described as prevented.

The GitHub UI is observation-only for this protocol: it does not bind the reviewed head in the request, cannot freeze the exact request bytes, and can select squash/rebase/delete behavior. Do not click its merge control. Only after the user explicitly directs the active agent in this uninterrupted turn, allocate and seal one request-only capture containing canonical `{"merge_method":"merge","sha":"<exact H>"}` and its exact row, bind the sealed approval-reread outcome, then issue exactly one REST call. The wrapper records response/exit only in the immutable attempt ledger:

```bash
MERGE_REQUEST_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase merge-put-request \
  --parent-capture "$APPROVAL_MAIN_OBSERVATION_SEAL" --print-field captureId)"
MERGE_REQUEST_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$MERGE_REQUEST_CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_pr_protocol.py render-merge-request \
  --H "$H" --output "$MERGE_REQUEST_DIR/merge-request.json"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase merge-put --repository ChangGeng01/ProjectSix \
  --pr-number "$PR_NUMBER" --request "$MERGE_REQUEST_DIR/merge-request.json" \
  --output "$MERGE_REQUEST_DIR/merge-request-rows.json"
MERGE_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$MERGE_REQUEST_CAPTURE_ID" \
  --file merge-request.json --file merge-request-rows.json --print-field sealRecordPath)"
MERGE_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  frontier-start --root "$EVIDENCE_ROOT" --kind remote-merge-put \
  --recover-exact --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --request-capture "$MERGE_REQUEST_SEAL" \
  --request-rows "$MERGE_REQUEST_DIR/merge-request-rows.json" \
  --request "$MERGE_REQUEST_DIR/merge-request.json" --pr-number "$PR_NUMBER" \
  --B "$B" --H "$H" --T "$T" --V "$V" --A "$A" --E "$E" \
  --merge-method merge --parent "$B" --parent "$H" \
  --approval-audit "$LATEST_APPROVAL_AUDIT_DIGEST" \
  --approval-reread-outcome "$APPROVAL_OUTCOME_RECORD" \
  --approval-reread-capture "$APPROVAL_MAIN_OBSERVATION_SEAL" \
  --expected-actor-id "$AUTHENTICATED_USER_ID" \
  --print-field startRecordPath)"
set +e
qinao_gh --intent "$MERGE_INTENT_RECORD" --operation merge-put -- \
  api --method PUT \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/pulls/$PR_NUMBER/merge" \
  --input "$MERGE_REQUEST_DIR/merge-request.json" \
  >/dev/null
MERGE_EXIT=$?
set -e
MERGE_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --intent "$MERGE_INTENT_RECORD" \
  --require-wrapper-exit "$MERGE_EXIT" --print-field attemptRecordPath)"
```

The request has no auto/admin/delete/squash/rebase field. Record its digest and the frozen authenticated login/numeric ID as expected `merged_by` before the call. Do not queue the command for later or schedule it. Issue at most once. Any separately observed UI/other-actor merge is unexpected irreversible drift and enters Step 6/Task 15 failure handling; it is never normalized into this approval.

- [ ] **Step 6: Classify an uncertain merge without retry**

Immediately allocate `phase=merge-put-observation` with `--parent-capture "$MERGE_REQUEST_SEAL" --parent-attempt "$MERGE_ATTEMPT_RECORD"`, seal the exact PR/main/commit/comment request manifests, perform only those reads, normalize their safe projections, and seal the observation generation. Query PR state, remote `refs/heads/main`, host merge OID, tree, ordered parents, and matching audit/final-evidence:

- confirmed success only when merged, tree `T`, parents `[B,H]`, exact evidence/audit, and expected `merged_by` login/ID;
- confirmed no effect only when the merge request returned a parsed, authenticated terminal rejection whose endpoint semantics prove it was not accepted, and fresh repeated reads still show PR open, `main=B`, head/body unchanged, auto/queue absent; a timeout/lost/unreadable response is never no-effect merely because the first reread is unchanged;
- every other observation is indeterminate.

GitHub exposes no base-SHA CAS and no general pending-operation proof for a lost synchronous merge response. Therefore any transport-unknown result remains `indeterminate` until exact success is observed; it is not retried. Even a confirmed terminal no-effect requires a newly presented summary, a new audit sequence, and fresh approval before another attempt.

For confirmed success or strictly proved no-effect, set `REMOTE_FRONTIER_ID` from `MERGE_INTENT_RECORD` and execute the Task 6 terminal pattern with the fresh PR/main/commit/actor observation and merge classifier. Exact success closes only after binding `R` and its ordered parents/tree; no-effect closes only with the authenticated rejection plus open-PR/`main=B` proof. Indeterminate leaves the merge frontier open permanently; Task 15 may observe/recover exact success and close that same frontier but may never start a second merge frontier.

### Task 15: Verify `R` from a fresh checkout and preserve recovery state

**Files:**
- No tracked edits
- One non-sensitive post-merge verification timeline record
- One fresh verification worktree under `/private/tmp`

**Interfaces:**
- Consumes: confirmed/recovered merge result and exact `B/H/T/V/A/M/P/E`.
- Produces: verified `R` record or a blocked repair/revert report; no cleanup/deletion.

**Mandatory Task 15 cold-start rule:** Step 0 is intentionally self-contained while the merge frontier may still be open. After it closes, every new process used by Steps 1–10 repeats Step 1's sterile worktree/evidence-root discovery and wrapper construction, then invokes `recover-captures --select-task15-context --require-phase <last-required-terminal-phase>` separately for every scalar it uses. At minimum it reopens `C/B/H/T/V/A/E/R/tupleDigest/prNumber/expectedActorId/mergeRequestSealRecordPath/mergeAttemptRecordPath/completionPreflightRecordPath/terminalContinuationPreflightRecordPath`, verifies the original merge request seal and unique attempt against the terminal frontier/observation, verifies `C` is the unique normal merge with ordered parents `[4a9298d…,D]`, and verifies the original remote-merge frontier is `confirmed-success` for `R`. Only the terminal-continuation preflight may construct later network wrappers; the completion preflight is compared as immutable history. The selector admits either no open mutation frontier or exactly one phase-appropriate Task 15 local resource/import/worktree frontier and returns named scalars `openLocalFrontierKind` (`none` or its closed kind) and, for a non-`none` kind, `openLocalFrontierId`; before any new capture or resource, the caller must close/recover that exact frontier through its declared table and then require no open mutation. It never admits a second/open remote mutation. Phase-specific capture/resource/frontier paths are selected by immutable ID and terminal record, never inherited from a preceding fence or chosen by pathname/mtime. Each process recreates `postmerge_git`, `qinao_network_git`, and `qinao_gh`; tests execute every Step 1–10 fence from `env -i` with all plausible shell variables unset, plus each legal interrupted frontier state, and fail on any undeclared dependency or skipped recovery.

- [ ] **Step 0: Close the original merge frontier using reads only**

This step runs before `allocate-resource`, fetch, shared import, `worktree add`, or any new mutation frontier. It is a complete cold-start prelude; it inherits no shell variable or function from Tasks 11–14. An open merge frontier with no unique wrapper attempt is pre-transport/Task-14 recovery state and is rejected here; Task 15 observes only the exact already-attempted logical merge and never creates or resumes transport:

```bash
set -euo pipefail
umask 077
bootstrap_git() {
  /usr/bin/env -i HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects "$@"
}
DISCOVERY_ROOT="$(bootstrap_git -C "$PWD" rev-parse --path-format=absolute --show-toplevel)"
WT="$(bootstrap_git -C "$DISCOVERY_ROOT" worktree list --porcelain | \
  awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
test "$(printf '%s\n' "$WT" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
test -n "$WT"
COMMON_GIT_DIR="$(bootstrap_git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -d "$RUN_ROOT"
test -d "$RUN_ROOT/home"
test -d "$RUN_ROOT/tmp"
cd "$WT"
qinao_python() {
  /bin/test "$#" -ge 1
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" TMPDIR="$RUN_ROOT/tmp" \
    LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    /usr/bin/python3 -I -S -B \
    "$WT/scripts/qinao_convergence_audit.py" sterile-python \
    --root "$RUN_ROOT" --repository "$WT" -- "$@"
}
EVIDENCE_ROOT="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$RUN_ROOT" --select-current-evidence-root --print-field absolutePath)"
case "$EVIDENCE_ROOT" in "$COMMON_GIT_DIR"/qinao-evidence/*) ;; *) exit 2 ;; esac
test -d "$EVIDENCE_ROOT"
test ! -L "$EVIDENCE_ROOT"
MERGE_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-mutation-kind remote-merge-put \
  --print-field startRecordPath)"
MERGE_FRONTIER_ID="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --intent "$MERGE_INTENT_RECORD" --print-field frontierId)"
MERGE_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --intent "$MERGE_INTENT_RECORD" \
  --print-field requestSealRecordPath)"
MERGE_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --intent "$MERGE_INTENT_RECORD" \
  --print-field attemptRecordPath)"
RECOVERY_ENTRY_PARENT_ARGS=(
  --require-parent-capture "$MERGE_REQUEST_SEAL"
  --require-parent-attempt "$MERGE_ATTEMPT_RECORD"
)
MERGE_TERMINAL_STATE="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FRONTIER_ID" --print-field terminalState)"
case "$MERGE_TERMINAL_STATE" in open|confirmed-success) ;; *) exit 2 ;; esac
for field in B H T V A E tupleDigest prNumber expectedActorId \
  approvalAuditDigest preflightRecordPath gitCredentialGeneration ghCredentialGeneration; do
  value="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --intent "$MERGE_INTENT_RECORD" --print-field "$field")"
  test -n "$value"
  case "$field" in
    B) B="$value" ;; H) H="$value" ;; T) T="$value" ;; V) V="$value" ;;
    A) A="$value" ;; E) E="$value" ;;
    tupleDigest) TUPLE_DIGEST="$value" ;;
    prNumber) PR_NUMBER="$value" ;; expectedActorId) AUTHENTICATED_USER_ID="$value" ;;
    approvalAuditDigest) LATEST_APPROVAL_AUDIT_DIGEST="$value" ;;
    preflightRecordPath) BASELINE_NETWORK_PREFLIGHT_RECORD="$value" ;;
    gitCredentialGeneration) BASELINE_GIT_CREDENTIAL_GENERATION="$value" ;;
    ghCredentialGeneration) BASELINE_GH_CREDENTIAL_GENERATION="$value" ;;
  esac
done
RECOVERY_CAPTURE_ARGS=()
PREFLIGHT_FRONTIER_BINDING_ARGS=()
if test "$MERGE_TERMINAL_STATE" = open; then
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --require-only-open-mutation "$MERGE_FRONTIER_ID"
  RECOVERY_CAPTURE_ARGS=(--read-only-recovery --blocked-frontier "$MERGE_FRONTIER_ID")
  PREFLIGHT_FRONTIER_BINDING_ARGS=(--blocked-frontier "$MERGE_FRONTIER_ID")
  PREFLIGHT_RECOVERY_PHASE=postmerge-merge-recovery-preflight-open
else
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --require-no-open-mutation-frontier
  MERGE_TERMINAL_RECORD="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FRONTIER_ID" \
    --print-field terminalRecordPath)"
  PREFLIGHT_FRONTIER_BINDING_ARGS=(--terminal-frontier-record "$MERGE_TERMINAL_RECORD")
  PREFLIGHT_RECOVERY_PHASE=postmerge-merge-recovery-preflight-terminal
fi
ENTRY_PREFLIGHT_STATE="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
  --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
  --phase "$PREFLIGHT_RECOVERY_PHASE" --print-field state)"
if test "$ENTRY_PREFLIGHT_STATE" = sealed; then
  ENTRY_PREFLIGHT_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
    --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
    --phase "$PREFLIGHT_RECOVERY_PHASE" --print-field captureId)"
  ENTRY_PREFLIGHT_DIR="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --capture-id "$ENTRY_PREFLIGHT_CAPTURE_ID" \
    --print-field absolutePath)"
  ENTRY_PREFLIGHT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
    --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
    --phase "$PREFLIGHT_RECOVERY_PHASE" --print-field sealRecordPath)"
  NETWORK_PREFLIGHT_RECORD="$ENTRY_PREFLIGHT_DIR/network-egress.json"
else
  PREFLIGHT_REPLACEMENT_ARGS=()
  if test "$ENTRY_PREFLIGHT_STATE" = replace-incomplete; then
    INCOMPLETE_PREFLIGHT_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
      recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
      --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
      --phase "$PREFLIGHT_RECOVERY_PHASE" --print-field captureId)"
    PREFLIGHT_REPLACEMENT_ARGS=(--replace-incomplete-capture "$INCOMPLETE_PREFLIGHT_CAPTURE_ID")
  else
    test "$ENTRY_PREFLIGHT_STATE" = absent
  fi
  ENTRY_PREFLIGHT_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
    --root "$EVIDENCE_ROOT" --phase "$PREFLIGHT_RECOVERY_PHASE" \
    "${RECOVERY_CAPTURE_ARGS[@]}" "${PREFLIGHT_REPLACEMENT_ARGS[@]}" \
    --print-field captureId)"
  ENTRY_PREFLIGHT_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --capture-id "$ENTRY_PREFLIGHT_CAPTURE_ID" \
    --print-field absolutePath)"
  NETWORK_PREFLIGHT_RECORD="$ENTRY_PREFLIGHT_DIR/network-egress.json"
  qinao_python scripts/qinao_convergence_audit.py network-egress-preflight \
    --repository "$WT" --phase postmerge-merge-recovery-entry \
    "${PREFLIGHT_FRONTIER_BINDING_ARGS[@]}" \
    --baseline-intent "$MERGE_INTENT_RECORD" \
    --baseline-preflight "$BASELINE_NETWORK_PREFLIGHT_RECORD" \
    --output "$NETWORK_PREFLIGHT_RECORD"
  ENTRY_PREFLIGHT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
    --root "$EVIDENCE_ROOT" --capture-id "$ENTRY_PREFLIGHT_CAPTURE_ID" \
    --file network-egress.json --print-field sealRecordPath)"
fi
NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST="$(qinao_python \
  scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$NETWORK_PREFLIGHT_RECORD" --print-field stableProjectionDigest)"
test "$NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST" = "$(qinao_python \
  scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$BASELINE_NETWORK_PREFLIGHT_RECORD" --print-field stableProjectionDigest)"
test "$(qinao_python scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$NETWORK_PREFLIGHT_RECORD" --print-field gitCredentialGeneration)" = \
  "$BASELINE_GIT_CREDENTIAL_GENERATION"
test "$(qinao_python scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$NETWORK_PREFLIGHT_RECORD" --print-field ghCredentialGeneration)" = \
  "$BASELINE_GH_CREDENTIAL_GENERATION"
qinao_network_git() {
  qinao_python scripts/qinao_convergence_audit.py network-git \
    --preflight "$NETWORK_PREFLIGHT_RECORD" "$@"
}
qinao_gh() {
  qinao_python scripts/qinao_convergence_audit.py network-gh \
    --preflight "$NETWORK_PREFLIGHT_RECORD" "$@"
}
ENTRY_CAPTURE_STATE="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
  --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
  --phase postmerge-merge-recovery-entry "${RECOVERY_ENTRY_PARENT_ARGS[@]}" \
  --print-field state)"
if test "$ENTRY_CAPTURE_STATE" = sealed; then
  CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --select-recovery-capture \
    --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
    --phase postmerge-merge-recovery-entry "${RECOVERY_ENTRY_PARENT_ARGS[@]}" \
    --print-field captureId)"
  CAPTURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" --print-field absolutePath)"
  ENTRY_MERGE_OBSERVATION_SEAL="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
    --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
    --phase postmerge-merge-recovery-entry "${RECOVERY_ENTRY_PARENT_ARGS[@]}" \
    --print-field sealRecordPath)"
  ENTRY_R="$(qinao_python scripts/qinao_pr_protocol.py normalize-merge-observation \
    --verify "$CAPTURE_DIR/entry-merge-observation.json" --print-field resultOid)"
else
  ENTRY_REPLACEMENT_ARGS=()
  if test "$ENTRY_CAPTURE_STATE" = replace-incomplete; then
    INCOMPLETE_ENTRY_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
      recover-captures --root "$EVIDENCE_ROOT" --select-recovery-capture \
      --frontier-id "$MERGE_FRONTIER_ID" --intent "$MERGE_INTENT_RECORD" \
      --phase postmerge-merge-recovery-entry "${RECOVERY_ENTRY_PARENT_ARGS[@]}" \
      --print-field captureId)"
    ENTRY_REPLACEMENT_ARGS=(--replace-incomplete-capture "$INCOMPLETE_ENTRY_CAPTURE_ID")
  else
    test "$ENTRY_CAPTURE_STATE" = absent
  fi
  CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
    --root "$EVIDENCE_ROOT" --phase postmerge-merge-recovery-entry \
    --parent-capture "$MERGE_REQUEST_SEAL" --parent-attempt "$MERGE_ATTEMPT_RECORD" \
    "${RECOVERY_CAPTURE_ARGS[@]}" "${ENTRY_REPLACEMENT_ARGS[@]}" \
    --print-field captureId)"
  CAPTURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" --print-field absolutePath)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-merge-recovery-advertisement --repository ChangGeng01/ProjectSix \
  --B "$B" --H "$H" --output "$CAPTURE_DIR/advertisement-request-rows.json"
ENTRY_ADVERTISEMENT_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" \
  --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$CAPTURE_DIR/advertisement-request-rows.json" --print-field manifestPath)"
qinao_network_git --intent "$ENTRY_ADVERTISEMENT_INTENT" --operation ls-remote -- \
  -C "$WT" ls-remote --refs --branches origin >"$CAPTURE_DIR/advertisement.tsv"
qinao_python scripts/qinao_convergence_audit.py validate-remote-advertisement \
  --input "$CAPTURE_DIR/advertisement.tsv" --allow-prefix refs/heads/ \
  --output "$CAPTURE_DIR/advertisement.json"
ENTRY_R="$(qinao_python scripts/qinao_convergence_audit.py validate-remote-advertisement \
  --record "$CAPTURE_DIR/advertisement.json" --require-ref refs/heads/main \
  --print-field refOid)"
test "$ENTRY_R" != "$B"
test "$(qinao_python scripts/qinao_convergence_audit.py validate-remote-advertisement \
  --record "$CAPTURE_DIR/advertisement.json" \
  --require-ref refs/heads/codex/qinao-git-only-convergence --print-field refOid)" = "$H"
ENTRY_ADVERTISEMENT_PROJECTION="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$ENTRY_ADVERTISEMENT_INTENT" \
  --print-field manifestSafeProjectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-merge-recovery-host --repository ChangGeng01/ProjectSix \
  --parent-projection "$ENTRY_ADVERTISEMENT_PROJECTION" \
  --pr-number "$PR_NUMBER" --result-oid "$ENTRY_R" \
  --output "$CAPTURE_DIR/host-request-rows.json"
ENTRY_HOST_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" \
  --preflight "$NETWORK_PREFLIGHT_RECORD" --rows "$CAPTURE_DIR/host-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$ENTRY_HOST_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/pulls/$PR_NUMBER" >"$CAPTURE_DIR/pull.safe.json"
qinao_gh --intent "$ENTRY_HOST_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/git/commits/$ENTRY_R" >"$CAPTURE_DIR/commit.safe.json"
qinao_gh --intent "$ENTRY_HOST_INTENT" --operation rest-read -- \
  api --paginate --slurp -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/issues/$PR_NUMBER/comments?per_page=100" \
  >"$CAPTURE_DIR/comments.pages.safe.json"
qinao_gh --intent "$ENTRY_HOST_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' rate_limit \
  >"$CAPTURE_DIR/rate-limit.safe.json"
qinao_python scripts/qinao_pr_protocol.py normalize-merge-observation \
  --intent "$MERGE_INTENT_RECORD" --advertisement "$CAPTURE_DIR/advertisement.json" \
  --pull "$CAPTURE_DIR/pull.safe.json" --commit "$CAPTURE_DIR/commit.safe.json" \
  --comments "$CAPTURE_DIR/comments.pages.safe.json" \
  --expected-audit "$LATEST_APPROVAL_AUDIT_DIGEST" \
  --expected-actor-id "$AUTHENTICATED_USER_ID" \
  --output "$CAPTURE_DIR/entry-merge-observation.json" \
  --capture-files-output "$CAPTURE_DIR/seal-files.txt"
test "$(qinao_python scripts/qinao_pr_protocol.py normalize-merge-observation \
  --verify "$CAPTURE_DIR/entry-merge-observation.json" --print-field resultOid)" = "$ENTRY_R"
ENTRY_MERGE_OBSERVATION_SEAL="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-capture --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" \
  --files-from "$CAPTURE_DIR/seal-files.txt" --print-field sealRecordPath)"
fi
if test "$MERGE_TERMINAL_STATE" = open; then
  MERGE_TERMINAL_RECORD="$(qinao_python scripts/qinao_convergence_audit.py frontier-complete \
    --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FRONTIER_ID" \
    --recover-exact \
    --observation-capture "$ENTRY_MERGE_OBSERVATION_SEAL" \
    --classify-merge-recovery-from-observation \
    --require-operation-specific-postcondition --print-field terminalRecordPath)"
  TERMINAL_PREFLIGHT_CAPTURE_ID="$(qinao_python \
    scripts/qinao_convergence_audit.py allocate-capture \
    --root "$EVIDENCE_ROOT" --phase postmerge-merge-recovery-preflight-terminal \
    --parent-capture "$ENTRY_PREFLIGHT_SEAL" --print-field captureId)"
  TERMINAL_PREFLIGHT_DIR="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --capture-id "$TERMINAL_PREFLIGHT_CAPTURE_ID" \
    --print-field absolutePath)"
  qinao_python scripts/qinao_convergence_audit.py network-egress-preflight \
    --repository "$WT" --phase postmerge-merge-recovery-terminal \
    --terminal-frontier-record "$MERGE_TERMINAL_RECORD" \
    --baseline-intent "$MERGE_INTENT_RECORD" \
    --baseline-preflight "$BASELINE_NETWORK_PREFLIGHT_RECORD" \
    --output "$TERMINAL_PREFLIGHT_DIR/network-egress.json"
  TERMINAL_PREFLIGHT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
    --root "$EVIDENCE_ROOT" --capture-id "$TERMINAL_PREFLIGHT_CAPTURE_ID" \
    --file network-egress.json --print-field sealRecordPath)"
else
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FRONTIER_ID" \
    --require-terminal-result "$ENTRY_R" --require-terminal-observation-compatible \
    --observation-capture "$ENTRY_MERGE_OBSERVATION_SEAL"
fi
qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --require-no-open-mutation-frontier
```

The host phase table above contains exactly four rows and binds the commit/comment child requests to the sealed advertisement projection. The normalizer requires merged PR state, unchanged base/head/body, `merge_commit_sha=ENTRY_R`, parents `[B,H]`, tree `T`, exact expected actor, complete final-evidence/audit chains and `E`; its whitelist includes every request-row input, manifest, safe projection, normalized record, and itself, with no raw host body. A partial/capped page, credential/config drift, multiple merge lineages, extra file, or semantic drift blocks. Only after the last assertion succeeds may Step 1 allocate its quarantine. Crash fixtures cover cold-start discovery, allocation/partial-write/seal for both recovery phases, explicit forensic supersession of one incomplete generation, direct reuse of one sealed generation, rejection of two sealed/unlinked generations, observation seal before recovered completion, terminal fsync/lost stdout, and any attempted fetch/import/worktree/comment frontier while the original merge frontier remains open.

- [ ] **Step 1: Fetch only fresh `main` and freeze `R`**

First repeat the scoped advertisement and require the retained candidate branch still advertises exact `H`; this is a required post-merge invariant. Read the newly advertised `main` OID as the only expected `R`. Fetch into a fresh proven-empty resource so no local negotiation tip or reused quarantine is needed; a raced advertisement/fetch is tainted and restarted before shared import.

```bash
set -euo pipefail
umask 077
bootstrap_git() {
  /usr/bin/env -i HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects "$@"
}
DISCOVERY_ROOT="$(bootstrap_git -C "$PWD" rev-parse --path-format=absolute --show-toplevel)"
WT="$(bootstrap_git -C "$DISCOVERY_ROOT" worktree list --porcelain | \
  awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/codex\/qinao-git-only-convergence$/{print w}')"
test "$(printf '%s\n' "$WT" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
COMMON_GIT_DIR="$(bootstrap_git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -d "$RUN_ROOT/home"
test -d "$RUN_ROOT/tmp"
cd "$WT"
qinao_python() {
  /bin/test "$#" -ge 1
  /usr/bin/env -i \
    HOME="$RUN_ROOT/home" TMPDIR="$RUN_ROOT/tmp" \
    LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    /usr/bin/python3 -I -S -B \
    "$WT/scripts/qinao_convergence_audit.py" sterile-python \
    --root "$RUN_ROOT" --repository "$WT" -- "$@"
}
EVIDENCE_ROOT="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$RUN_ROOT" --select-current-evidence-root --print-field absolutePath)"
MERGE_INTENT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-mutation-kind remote-merge-put \
  --print-field startRecordPath)"
MERGE_FRONTIER_ID="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --intent "$MERGE_INTENT_RECORD" --print-field frontierId)"
test "$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --frontier-id "$MERGE_FRONTIER_ID" \
  --print-field terminalState)" = confirmed-success
MERGE_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field mergeRequestSealRecordPath)"
MERGE_ATTEMPT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field mergeAttemptRecordPath)"
B="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field B)"
H="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field H)"
T="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field T)"
V="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field V)"
A="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field A)"
E="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field E)"
C="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field C)"
PR_NUMBER="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field prNumber)"
TUPLE_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field tupleDigest)"
ENTRY_R="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field R)"
NETWORK_PREFLIGHT_RECORD="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --select-task15-context --require-phase merge-confirmed \
  --print-field terminalContinuationPreflightRecordPath)"
NETWORK_PREFLIGHT_STABLE_PROJECTION_DIGEST="$(qinao_python \
  scripts/qinao_convergence_audit.py network-egress-preflight \
  --verify "$NETWORK_PREFLIGHT_RECORD" --print-field stableProjectionDigest)"
qinao_network_git() {
  qinao_python scripts/qinao_convergence_audit.py network-git \
    --preflight "$NETWORK_PREFLIGHT_RECORD" "$@"
}
qinao_gh() {
  qinao_python scripts/qinao_convergence_audit.py network-gh \
    --preflight "$NETWORK_PREFLIGHT_RECORD" "$@"
}
OPEN_LOCAL_FRONTIER_KIND="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --select-task15-context \
  --require-phase merge-confirmed --print-field openLocalFrontierKind)"
case "$OPEN_LOCAL_FRONTIER_KIND" in
  none)
    POSTMERGE_LINEAGE_STATE="$(qinao_python scripts/qinao_convergence_audit.py \
      recover-captures --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
      --expected-R "$ENTRY_R" --expected-candidate "$H" --print-field state)"
    case "$POSTMERGE_LINEAGE_STATE" in
      request-incomplete)
        POSTMERGE_REQUEST_CAPTURE_ID="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field captureId)"
        POSTMERGE_TAINTED_PREDECESSOR="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field predecessorOutcomeRecordPath)"
        ;;
      request-sealed)
        POSTMERGE_REQUEST_CAPTURE_ID="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field captureId)"
        POSTMERGE_REQUEST_SEAL="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field requestSealRecordPath)"
        POSTMERGE_REQUEST_MANIFEST="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field requestManifestPath)"
        POSTMERGE_TAINTED_PREDECESSOR="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field predecessorOutcomeRecordPath)"
        ;;
      advertisement-sealed|fetch-completed|fetch-tainted|import-completed|observation-sealed)
        POSTMERGE_OUTCOME_RECORD="$(qinao_python \
          scripts/qinao_convergence_audit.py recover-captures \
          --root "$EVIDENCE_ROOT" --select-postmerge-main-lineage \
          --expected-R "$ENTRY_R" --expected-candidate "$H" \
          --print-field outcomeRecordPath)"
        ;;
      absent) ;;
      *) exit 2 ;;
    esac
    ;;
  postmerge-main-fetch|postmerge-main-import)
    OPEN_LOCAL_FRONTIER_ID="$(qinao_python scripts/qinao_convergence_audit.py \
      recover-captures --root "$EVIDENCE_ROOT" --select-task15-context \
      --require-phase merge-confirmed --print-field openLocalFrontierId)"
    POSTMERGE_OUTCOME_RECORD="$(qinao_python \
      scripts/qinao_convergence_audit.py quarantine-ref-observe \
      --root "$EVIDENCE_ROOT" --repository "$WT" \
      --recover-existing "$OPEN_LOCAL_FRONTIER_ID" --no-network \
      --print-field outcomeRecordPath)"
    POSTMERGE_LINEAGE_STATE="$(qinao_python \
      scripts/qinao_convergence_audit.py quarantine-ref-observe \
      --verify-outcome "$POSTMERGE_OUTCOME_RECORD" --print-field state)"
    ;;
  *) exit 2 ;;
esac
case "$POSTMERGE_LINEAGE_STATE" in
  advertisement-sealed|fetch-completed|import-completed)
    POSTMERGE_OUTCOME_RECORD="$(qinao_python \
      scripts/qinao_convergence_audit.py quarantine-ref-observe \
      --root "$EVIDENCE_ROOT" --repository "$WT" \
      --preflight "$NETWORK_PREFLIGHT_RECORD" \
      --resume-outcome "$POSTMERGE_OUTCOME_RECORD" --to-terminal \
      --print-field outcomeRecordPath)"
    POSTMERGE_LINEAGE_STATE="$(qinao_python \
      scripts/qinao_convergence_audit.py quarantine-ref-observe \
      --verify-outcome "$POSTMERGE_OUTCOME_RECORD" --print-field state)"
    ;;
  fetch-tainted)
    POSTMERGE_TAINTED_PREDECESSOR="$POSTMERGE_OUTCOME_RECORD"
    POSTMERGE_LINEAGE_STATE=allocate-fresh-generation
    ;;
  request-incomplete)
    POSTMERGE_INCOMPLETE_REQUEST_CAPTURE_ID="$POSTMERGE_REQUEST_CAPTURE_ID"
    POSTMERGE_LINEAGE_STATE=replace-incomplete-request
    ;;
  request-sealed|observation-sealed) ;;
  absent)
    POSTMERGE_TAINTED_PREDECESSOR=none
    ;;
  *) exit 2 ;;
esac
if test "$POSTMERGE_LINEAGE_STATE" = absent || \
   test "$POSTMERGE_LINEAGE_STATE" = allocate-fresh-generation || \
   test "$POSTMERGE_LINEAGE_STATE" = replace-incomplete-request; then
  qinao_python scripts/qinao_convergence_audit.py recover-captures \
    --root "$EVIDENCE_ROOT" --require-no-open-mutation-frontier
  if test "$POSTMERGE_LINEAGE_STATE" = allocate-fresh-generation; then
    POSTMERGE_REQUEST_CAPTURE_ID="$(qinao_python \
      scripts/qinao_convergence_audit.py allocate-capture \
      --root "$EVIDENCE_ROOT" --phase postmerge-main-request \
      --supersede-tainted-outcome "$POSTMERGE_TAINTED_PREDECESSOR" \
      --print-field captureId)"
  elif test "$POSTMERGE_LINEAGE_STATE" = replace-incomplete-request && \
       test "$POSTMERGE_TAINTED_PREDECESSOR" != none; then
    POSTMERGE_REQUEST_CAPTURE_ID="$(qinao_python \
      scripts/qinao_convergence_audit.py allocate-capture \
      --root "$EVIDENCE_ROOT" --phase postmerge-main-request \
      --replace-incomplete-capture "$POSTMERGE_INCOMPLETE_REQUEST_CAPTURE_ID" \
      --supersede-tainted-outcome "$POSTMERGE_TAINTED_PREDECESSOR" \
      --print-field captureId)"
  elif test "$POSTMERGE_LINEAGE_STATE" = replace-incomplete-request; then
    POSTMERGE_REQUEST_CAPTURE_ID="$(qinao_python \
      scripts/qinao_convergence_audit.py allocate-capture \
      --root "$EVIDENCE_ROOT" --phase postmerge-main-request \
      --replace-incomplete-capture "$POSTMERGE_INCOMPLETE_REQUEST_CAPTURE_ID" \
      --print-field captureId)"
  else
    POSTMERGE_REQUEST_CAPTURE_ID="$(qinao_python \
      scripts/qinao_convergence_audit.py allocate-capture \
      --root "$EVIDENCE_ROOT" --phase postmerge-main-request --print-field captureId)"
  fi
  POSTMERGE_REQUEST_DIR="$(qinao_python scripts/qinao_convergence_audit.py \
    recover-captures --root "$EVIDENCE_ROOT" --capture-id "$POSTMERGE_REQUEST_CAPTURE_ID" \
    --print-field absolutePath)"
  qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
    --phase postmerge-advertisement --repository ChangGeng01/ProjectSix \
    --H "$H" --result-oid "$ENTRY_R" \
    --output "$POSTMERGE_REQUEST_DIR/postmerge-advertisement-request-rows.json"
  POSTMERGE_REQUEST_MANIFEST="$(qinao_python scripts/qinao_convergence_audit.py \
    seal-network-request-manifest --root "$EVIDENCE_ROOT" \
    --capture-id "$POSTMERGE_REQUEST_CAPTURE_ID" \
    --preflight "$NETWORK_PREFLIGHT_RECORD" \
    --rows "$POSTMERGE_REQUEST_DIR/postmerge-advertisement-request-rows.json" \
    --capture-files-output "$POSTMERGE_REQUEST_DIR/seal-files.txt" \
    --print-field manifestPath)"
  POSTMERGE_REQUEST_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
    --root "$EVIDENCE_ROOT" --capture-id "$POSTMERGE_REQUEST_CAPTURE_ID" \
    --files-from "$POSTMERGE_REQUEST_DIR/seal-files.txt" --print-field sealRecordPath)"
  POSTMERGE_LINEAGE_STATE=request-sealed
fi
if test "$POSTMERGE_LINEAGE_STATE" = request-sealed; then
  POSTMERGE_REF="refs/qinao/postmerge-main/$TUPLE_DIGEST/$POSTMERGE_REQUEST_CAPTURE_ID"
  if test "$POSTMERGE_TAINTED_PREDECESSOR" != none; then
    POSTMERGE_OUTCOME_RECORD="$(qinao_python \
      scripts/qinao_convergence_audit.py quarantine-ref-observe \
      --root "$EVIDENCE_ROOT" --repository "$WT" \
      --preflight "$NETWORK_PREFLIGHT_RECORD" \
      --supersede-tainted-outcome "$POSTMERGE_TAINTED_PREDECESSOR" \
      --advertisement-request-capture "$POSTMERGE_REQUEST_SEAL" \
      --advertisement-manifest "$POSTMERGE_REQUEST_MANIFEST" \
      --remote-ref refs/heads/main --expected-oid "$ENTRY_R" \
      --require-advertised-ref "refs/heads/codex/qinao-git-only-convergence=$H" \
      --destination-ref "$POSTMERGE_REF" --to-terminal \
      --print-field outcomeRecordPath)"
  else
    POSTMERGE_OUTCOME_RECORD="$(qinao_python \
      scripts/qinao_convergence_audit.py quarantine-ref-observe \
      --root "$EVIDENCE_ROOT" --repository "$WT" \
      --preflight "$NETWORK_PREFLIGHT_RECORD" \
      --advertisement-request-capture "$POSTMERGE_REQUEST_SEAL" \
      --advertisement-manifest "$POSTMERGE_REQUEST_MANIFEST" \
      --remote-ref refs/heads/main --expected-oid "$ENTRY_R" \
      --require-advertised-ref "refs/heads/codex/qinao-git-only-convergence=$H" \
      --destination-ref "$POSTMERGE_REF" --to-terminal \
      --print-field outcomeRecordPath)"
  fi
  POSTMERGE_LINEAGE_STATE="$(qinao_python \
    scripts/qinao_convergence_audit.py quarantine-ref-observe \
    --verify-outcome "$POSTMERGE_OUTCOME_RECORD" --print-field state)"
fi
case "$POSTMERGE_LINEAGE_STATE" in
  observation-sealed) ;;
  fetch-tainted) exit 75 ;;
  *) exit 2 ;;
esac
R="$(qinao_python scripts/qinao_convergence_audit.py quarantine-ref-observe \
  --verify-outcome "$POSTMERGE_OUTCOME_RECORD" --print-field observedOid)"
POSTMERGE_REF="$(qinao_python scripts/qinao_convergence_audit.py quarantine-ref-observe \
  --verify-outcome "$POSTMERGE_OUTCOME_RECORD" --print-field destinationRef)"
POSTMERGE_RESULT_SEAL="$(qinao_python scripts/qinao_convergence_audit.py \
  quarantine-ref-observe --verify-outcome "$POSTMERGE_OUTCOME_RECORD" \
  --print-field observationSealRecordPath)"
test "$R" = "$ENTRY_R"
qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --require-no-open-mutation-frontier
```

The normal and resumed paths use the same composition and end at one sealed canonical result; there is no hand-written second lifecycle. `request-incomplete` is forensically closed and replaced once; `request-sealed` enters the same composition without rewriting request bytes; `observation-sealed` consumes the existing result directly. `fetch-completed` continues the unique network-disabled import; `import-completed` only seals the pure observation; `advertisement-sealed` starts the one not-yet-attempted fetch; `fetch-tainted` alone permits a new request/resource/ref generation after the old lineage is terminal, and both allocation and composition bind the typed predecessor path/digest. The destination ref is previously nonexistent and is never changed/deleted. Partial resources are preserved/tainted, foreign shared drift blocks, and no frontier uses cleanup. Do not fetch with prune and do not update any protected worktree. The terminal phase `postmerge-main-import` is satisfied only by the import terminal **and** `POSTMERGE_RESULT_SEAL`, so Step 2 cannot consume a bare ref effect.

- [ ] **Step 2: Verify exact tree and ordered topology**

Start from `env -i` and apply the mandatory Task 15 cold-start rule with `--require-phase postmerge-main-import`; bind `R` from the completed import result and recreate `postmerge_git` before this fence. No value below is inherited from Step 1.

```bash
COMMON_GIT_DIR="$(/usr/bin/git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
RUN_ROOT="$COMMON_GIT_DIR/qinao-runs/git-only-convergence"
test -d "$RUN_ROOT/home"
postmerge_git() {
  /usr/bin/env -i HOME="$RUN_ROOT/home" LANG=C LC_ALL=C PATH=/usr/bin:/bin \
    XDG_CONFIG_HOME=/nonexistent GIT_ATTR_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null \
    GIT_LITERAL_PATHSPECS=1 GIT_LFS_SKIP_SMUDGE=1 GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat \
    GIT_TERMINAL_PROMPT=0 PAGER=cat \
    /usr/bin/git --no-pager --no-optional-locks --no-replace-objects \
    -c core.hooksPath=/dev/null -c core.fsmonitor=false -c core.autocrlf=false \
    -c diff.external= -c commit.gpgSign=false -c merge.gpgSign=false \
    -c filter.lfs.clean= -c filter.lfs.smudge= \
    -c filter.lfs.process= -c filter.lfs.required=false \
    -c merge.autoStash=false -c rerere.enabled=false "$@"
}
test "$(postmerge_git -C "$WT" rev-parse "$R^{tree}")" = "$T"
test "$(postmerge_git -C "$WT" rev-list --parents -n 1 "$R")" = "$R $B $H"
postmerge_git -C "$WT" merge-base --is-ancestor "$C" "$H"
```

Also require the host PR merge OID to equal `R`, `merged=true`, `merged_by.login` and numeric `merged_by.id` to equal the frozen authenticated user from Task 12, merge mode inferred as native merge commit, and auto-merge absent/disabled.

- [ ] **Step 3: Create a fresh verification worktree**

Start from `env -i`, apply the mandatory Task 15 cold-start rule with `--require-phase postmerge-main-import`, and recreate `postmerge_git` byte-for-byte. If it reports an open `postmerge-worktree-add`, execute the recovery table below against that same resource/frontier and resume after its terminal completion; never enter this new-allocation fence. Every other open kind blocks. The fence below is therefore only the proved-no-open path with no prior terminal verification worktree. Before the checkout can run, allocate a fresh local capture and run `network-egress-preflight --local-only` against `WT`; require the same closed local/worktree config projection, no filter/driver/fsmonitor/partial-clone/promisor/submodule command, no replacement effect, and no missing `R` closure. Also require common and current-worktree `info/attributes` absent and the `R` tree's attributes to contain only the reviewed LFS rule. These are preconditions, not post-checks.

```bash
COMMON_GIT_DIR="$(postmerge_git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
CURRENT_WORKTREE_GIT_DIR="$(postmerge_git -C "$WT" rev-parse --path-format=absolute --git-dir)"
test ! -e "$COMMON_GIT_DIR/info/attributes"
test ! -e "$CURRENT_WORKTREE_GIT_DIR/info/attributes"
POSTMERGE_LOCAL_CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py \
  allocate-capture --root "$EVIDENCE_ROOT" --phase postmerge-local-preflight \
  --print-field captureId)"
POSTMERGE_LOCAL_CAPTURE_DIR="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --capture-id "$POSTMERGE_LOCAL_CAPTURE_ID" \
  --print-field absolutePath)"
POSTMERGE_LOCAL_PREFLIGHT_RECORD="$POSTMERGE_LOCAL_CAPTURE_DIR/postmerge-local-preflight.json"
qinao_python scripts/qinao_convergence_audit.py network-egress-preflight \
  --local-only --repository "$WT" --phase postmerge-worktree-create \
  --output "$POSTMERGE_LOCAL_PREFLIGHT_RECORD"
POSTMERGE_LOCAL_PREFLIGHT_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  network-egress-preflight --verify "$POSTMERGE_LOCAL_PREFLIGHT_RECORD" \
  --print-field recordDigest)"
POSTMERGE_LOCAL_CONFIG_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  network-egress-preflight --verify "$POSTMERGE_LOCAL_PREFLIGHT_RECORD" \
  --print-field localConfigProjectionDigest)"
BASELINE_LOCAL_CONFIG_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  network-egress-preflight --verify "$NETWORK_PREFLIGHT_RECORD" \
  --print-field localConfigProjectionDigest)"
test "$POSTMERGE_LOCAL_CONFIG_PROJECTION_DIGEST" = "$BASELINE_LOCAL_CONFIG_PROJECTION_DIGEST"
POSTMERGE_PROTECTED_WITNESS_RECORD="$POSTMERGE_LOCAL_CAPTURE_DIR/postmerge-protected-witness.json"
qinao_python scripts/qinao_convergence_audit.py protected \
  --repository "$WT" \
  --manifest docs/superpowers/evidence/2026-08-28-qinao-p0-protected-worktree-preservation-manifest.tsv \
  --receipt docs/superpowers/evidence/2026-08-28-qinao-p0-protected-worktree-preservation-receipt.md \
  --output "$POSTMERGE_PROTECTED_WITNESS_RECORD"
PROTECTED_WITNESS_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  protected --verify "$POSTMERGE_PROTECTED_WITNESS_RECORD" \
  --print-field witnessDigest)"
postmerge_git -C "$WT" rev-list --objects --missing=print "$R" \
  >"$POSTMERGE_LOCAL_CAPTURE_DIR/postmerge-r-closure.txt"
awk '$1 ~ /^\?/ { missing=1 } END { exit missing }' \
  "$POSTMERGE_LOCAL_CAPTURE_DIR/postmerge-r-closure.txt"
POSTMERGE_R_CLOSURE_DIGEST="$(/usr/bin/shasum -a 256 \
  "$POSTMERGE_LOCAL_CAPTURE_DIR/postmerge-r-closure.txt" | awk '{print $1}')"
POSTMERGE_LOCAL_CAPTURE_SEAL="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-capture --root "$EVIDENCE_ROOT" --capture-id "$POSTMERGE_LOCAL_CAPTURE_ID" \
  --file postmerge-local-preflight.json --file postmerge-protected-witness.json \
  --file postmerge-r-closure.txt --print-field sealRecordPath)"
VERIFY_RESOURCE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-resource \
  --root "$EVIDENCE_ROOT" --kind postmerge-verification-worktree \
  --external-parent /private/tmp --template empty-dir \
  --print-field resourceId)"
VERIFY_ROOT="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --resource-id "$VERIFY_RESOURCE_ID" \
  --print-field absolutePath)"
VERIFY_RESOURCE_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$VERIFY_RESOURCE_ID" \
  --state empty-verification-root --print-field snapshotDigest)"
WORKTREE_SHARED_BEFORE="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
  --root "$EVIDENCE_ROOT" --repository "$WT" \
  --state before-postmerge-worktree-add --print-field snapshotDigest)"
WORKTREE_ADD_FRONTIER="$(qinao_python scripts/qinao_convergence_audit.py frontier-start \
  --root "$EVIDENCE_ROOT" --kind postmerge-worktree-add --recover-exact \
  --repository "$WT" --resource-id "$VERIFY_RESOURCE_ID" \
  --input-resource "$VERIFY_RESOURCE_BEFORE" \
  --input-git-state "$WORKTREE_SHARED_BEFORE" \
  --destination "$VERIFY_ROOT/worktree" --commit "$R" \
  --local-preflight-record "$POSTMERGE_LOCAL_PREFLIGHT_RECORD" \
  --local-preflight-digest "$POSTMERGE_LOCAL_PREFLIGHT_DIGEST" \
  --config-projection "$POSTMERGE_LOCAL_CONFIG_PROJECTION_DIGEST" \
  --protected-witness-record "$POSTMERGE_PROTECTED_WITNESS_RECORD" \
  --protected-witness "$PROTECTED_WITNESS_DIGEST" \
  --closure-record "$POSTMERGE_LOCAL_CAPTURE_DIR/postmerge-r-closure.txt" \
  --closure-digest "$POSTMERGE_R_CLOSURE_DIGEST" \
  --observation-capture "$POSTMERGE_LOCAL_CAPTURE_SEAL" \
  --print-field frontierId)"
postmerge_git -C "$WT" \
  worktree add --detach "$VERIFY_ROOT/worktree" "$R"
VERIFY_GIT_DIR="$(postmerge_git -C "$VERIFY_ROOT/worktree" rev-parse --path-format=absolute --git-dir)"
COMMON_GIT_DIR="$(postmerge_git -C "$VERIFY_ROOT/worktree" rev-parse --path-format=absolute --git-common-dir)"
test ! -e "$COMMON_GIT_DIR/info/attributes"
test ! -e "$VERIFY_GIT_DIR/info/attributes"
test ! -e "$VERIFY_GIT_DIR/config.worktree"
test -z "$(postmerge_git -C "$VERIFY_ROOT/worktree" status --porcelain=v1 --untracked-files=all)"
VERIFY_RESOURCE_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-resource \
  --root "$EVIDENCE_ROOT" --resource-id "$VERIFY_RESOURCE_ID" \
  --state exact-detached-r-worktree --print-field snapshotDigest)"
WORKTREE_SHARED_AFTER="$(qinao_python scripts/qinao_convergence_audit.py snapshot-git-state \
  --root "$EVIDENCE_ROOT" --repository "$WT" \
  --compare-input "$WORKTREE_SHARED_BEFORE" \
  --allow-only-worktree-add "$VERIFY_ROOT/worktree=$R" \
  --state after-postmerge-worktree-add --print-field snapshotDigest)"
qinao_python scripts/qinao_convergence_audit.py frontier-complete \
  --root "$EVIDENCE_ROOT" --frontier-id "$WORKTREE_ADD_FRONTIER" \
  --recover-exact --state completed --repository "$WT" \
  --result-resource "$VERIFY_RESOURCE_AFTER" \
  --result-git-state "$WORKTREE_SHARED_AFTER" \
  --result-worktree "$VERIFY_ROOT/worktree=$R"
```

On entry, recover `postmerge-worktree-add` before allocating anything. Only `intent-only` with the exact empty resource/shared snapshot may continue the same add, or an exact registered detached `R` worktree with clean index/status, matching admin/common-dir registration, resource manifest/config/protected witnesses may append `recovered-completed`. A partial checkout, alternate registration/path, dirty/missing file, config/admin/ref drift, or ambiguous process state is preserved and blocks; never call worktree prune/remove or allocate a replacement over it. Crash fixtures cover registration before checkout, checkout before index fsync, exact poststate before completion, and lost completion stdout.

Re-run protocol units, forward-policy static, document inventory, workflow contract, automation inventory repository verification, and protected-worktree audit. Every local Git/object/status call in these reruns uses `postmerge_git`; repeat the config allowlist, disabled replacements/lazy fetch/filters/fsmonitor, and common/worktree attribute checks at each process boundary. Because `R^{tree}=T` and the complete application matrix already tested `T`, a second full local application matrix is not required; the mandatory fresh host push-run verification below still tests the actual `R`. If exact tree equality cannot be proved, rerun all thirteen targets and treat the merge verification as failed.

- [ ] **Step 4: Require the exact `R` main-push workflow to finish successfully**

Start each poll from `env -i` and apply the mandatory Task 15 cold-start rule with `--require-phase postmerge-worktree-add`. Wait for a unique Actions run with workflow path `.github/workflows/test.yml`, event `push`, head branch `main`, and `head_sha=R`. Every poll allocates a fresh `phase=postmerge-ci-observation` capture; an incomplete/read-failed generation is sealed as that observation and a later poll uses a new generation, never the former directory. The following fence begins only after recreating all three wrappers:

```bash
CAPTURE_ID="$(qinao_python scripts/qinao_convergence_audit.py allocate-capture \
  --root "$EVIDENCE_ROOT" --phase postmerge-ci-observation --print-field captureId)"
POSTMERGE_CI_DIR="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" --print-field absolutePath)"
POSTMERGE_CI_ITERATION="$(qinao_python scripts/qinao_convergence_audit.py recover-captures \
  --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" --print-field phaseSequence)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-ci-static --repository ChangGeng01/ProjectSix \
  --R "$R" --iteration "$POSTMERGE_CI_ITERATION" \
  --output "$POSTMERGE_CI_DIR/postmerge-ci-static-request-rows.json"
POSTMERGE_CI_STATIC_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$POSTMERGE_CI_DIR/postmerge-ci-static-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$POSTMERGE_CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/actions/runs?event=push&head_sha=$R&per_page=100" \
  >"$POSTMERGE_CI_DIR/postmerge-runs.pages.json"
qinao_gh --intent "$POSTMERGE_CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/commits/$R/check-runs?filter=all&per_page=100" \
  >"$POSTMERGE_CI_DIR/check-runs.pages.json"
qinao_gh --intent "$POSTMERGE_CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/commits/$R/check-suites?per_page=100" \
  >"$POSTMERGE_CI_DIR/check-suites.pages.json"
qinao_gh --intent "$POSTMERGE_CI_STATIC_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/commits/$R/statuses?per_page=100" \
  >"$POSTMERGE_CI_DIR/statuses.pages.json"
qinao_gh --intent "$POSTMERGE_CI_STATIC_INTENT" --operation rest-read -- \
  api -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' rate_limit \
  >"$POSTMERGE_CI_DIR/rate-limit.json"
POSTMERGE_CI_STATIC_REQUEST_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$POSTMERGE_CI_STATIC_INTENT" \
  --print-field manifestSafeProjectionDigest)"
POSTMERGE_CI_STATIC_RESULT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py \
  observation-projection \
  --capture "$POSTMERGE_CI_DIR" --through static \
  --request-projection "$POSTMERGE_CI_STATIC_REQUEST_PROJECTION_DIGEST" \
  --suite-ids-output "$POSTMERGE_CI_DIR/check-suite-ids.txt" \
  --output "$POSTMERGE_CI_DIR/ci-static-projection.json" \
  --print-field projectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-ci-suite-runs --repository ChangGeng01/ProjectSix \
  --parent-record "$POSTMERGE_CI_DIR/ci-static-projection.json" \
  --parent-projection "$POSTMERGE_CI_STATIC_RESULT_PROJECTION_DIGEST" \
  --ids "$POSTMERGE_CI_DIR/check-suite-ids.txt" \
  --output "$POSTMERGE_CI_DIR/ci-suite-request-rows.json"
POSTMERGE_CI_SUITE_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$POSTMERGE_CI_DIR/ci-suite-request-rows.json" --print-field manifestPath)"
set -C
while IFS= read -r CHECK_SUITE_ID; do
  test -n "$CHECK_SUITE_ID"
  SUITE_RUNS="$POSTMERGE_CI_DIR/check-suite-$CHECK_SUITE_ID-runs.pages.json"
  test ! -e "$SUITE_RUNS"
  qinao_gh --intent "$POSTMERGE_CI_SUITE_INTENT" --operation rest-read -- \
    api --paginate --slurp \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "repos/ChangGeng01/ProjectSix/check-suites/$CHECK_SUITE_ID/check-runs?filter=all&per_page=100" \
    >"$SUITE_RUNS"
done <"$POSTMERGE_CI_DIR/check-suite-ids.txt"
set +C
POSTMERGE_CI_SUITE_REQUEST_PROJECTION_DIGEST="$(qinao_python scripts/qinao_convergence_audit.py \
  recover-captures --root "$EVIDENCE_ROOT" --manifest "$POSTMERGE_CI_SUITE_INTENT" \
  --print-field manifestSafeProjectionDigest)"
POSTMERGE_CI_SUITE_RESULT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py \
  observation-projection \
  --capture "$POSTMERGE_CI_DIR" --through suites \
  --request-projection "$POSTMERGE_CI_SUITE_REQUEST_PROJECTION_DIGEST" \
  --parent-record "$POSTMERGE_CI_DIR/ci-static-projection.json" \
  --parent-projection "$POSTMERGE_CI_STATIC_RESULT_PROJECTION_DIGEST" \
  --suite-selection "$POSTMERGE_CI_DIR/ci-static-projection.json" \
  --annotation-counts-output "$POSTMERGE_CI_DIR/check-run-annotation-counts.tsv" \
  --output "$POSTMERGE_CI_DIR/ci-suite-projection.json" \
  --print-field projectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-ci-annotations --repository ChangGeng01/ProjectSix \
  --parent-record "$POSTMERGE_CI_DIR/ci-suite-projection.json" \
  --parent-projection "$POSTMERGE_CI_SUITE_RESULT_PROJECTION_DIGEST" \
  --ids "$POSTMERGE_CI_DIR/check-run-annotation-counts.tsv" \
  --output "$POSTMERGE_CI_DIR/ci-annotation-request-rows.json"
POSTMERGE_CI_ANNOTATION_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$POSTMERGE_CI_DIR/ci-annotation-request-rows.json" --print-field manifestPath)"
set -C
while IFS=$'\t' read -r CHECK_RUN_ID ANNOTATION_COUNT; do
  case "$CHECK_RUN_ID:$ANNOTATION_COUNT" in
    *[!0-9:]*|:*|*:) exit 2 ;;
  esac
  test "$CHECK_RUN_ID" -gt 0
  test "$ANNOTATION_COUNT" -ge 0
  if test "$ANNOTATION_COUNT" -gt 0; then
    ANNOTATIONS="$POSTMERGE_CI_DIR/check-run-$CHECK_RUN_ID-annotations.pages.json"
    test ! -e "$ANNOTATIONS"
    qinao_gh --intent "$POSTMERGE_CI_ANNOTATION_INTENT" --operation rest-read -- \
      api --paginate --slurp \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "repos/ChangGeng01/ProjectSix/check-runs/$CHECK_RUN_ID/annotations?per_page=100" \
      >"$ANNOTATIONS"
  fi
done <"$POSTMERGE_CI_DIR/check-run-annotation-counts.tsv"
set +C
POSTMERGE_CI_ANNOTATION_REQUEST_PROJECTION_DIGEST="$(qinao_python \
  scripts/qinao_convergence_audit.py recover-captures --root "$EVIDENCE_ROOT" \
  --manifest "$POSTMERGE_CI_ANNOTATION_INTENT" --print-field manifestSafeProjectionDigest)"
POSTMERGE_CI_ANNOTATION_RESULT_PROJECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py observation-projection \
  --capture "$POSTMERGE_CI_DIR" --through annotations \
  --request-projection "$POSTMERGE_CI_ANNOTATION_REQUEST_PROJECTION_DIGEST" \
  --parent-record "$POSTMERGE_CI_DIR/ci-suite-projection.json" \
  --parent-projection "$POSTMERGE_CI_SUITE_RESULT_PROJECTION_DIGEST" \
  --suite-selection "$POSTMERGE_CI_DIR/ci-static-projection.json" \
  --annotation-selection "$POSTMERGE_CI_DIR/ci-suite-projection.json" \
  --output "$POSTMERGE_CI_DIR/ci-annotation-projection.json" \
  --print-field projectionDigest)"
CANDIDATE_WORKFLOW_BLOB="$(postmerge_git -C "$WT" rev-parse "$H:.github/workflows/test.yml")"
POSTMERGE_WORKFLOW_BLOB="$(postmerge_git -C "$WT" rev-parse "$R:.github/workflows/test.yml")"
test "$POSTMERGE_WORKFLOW_BLOB" = "$CANDIDATE_WORKFLOW_BLOB"
POSTMERGE_RUN_SELECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py select-ci-run \
  --capture "$POSTMERGE_CI_DIR" --event push --head "$R" \
  --workflow-path .github/workflows/test.yml \
  --workflow-blob "$POSTMERGE_WORKFLOW_BLOB" \
  --workflow-contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json \
  --observation-projection "$POSTMERGE_CI_DIR/ci-annotation-projection.json" \
  --output "$POSTMERGE_CI_DIR/selected-run-selection.json" \
  --ids-output "$POSTMERGE_CI_DIR/selected-run-attempt.tsv" \
  --print-field selectionDigest)"
POSTMERGE_RUN_ID="$(qinao_python scripts/qinao_workflow_inventory.py read-ci-run-selection \
  --selection "$POSTMERGE_CI_DIR/selected-run-selection.json" \
  --ids "$POSTMERGE_CI_DIR/selected-run-attempt.tsv" --print-field runId)"
POSTMERGE_RUN_ATTEMPT="$(qinao_python scripts/qinao_workflow_inventory.py read-ci-run-selection \
  --selection "$POSTMERGE_CI_DIR/selected-run-selection.json" \
  --ids "$POSTMERGE_CI_DIR/selected-run-attempt.tsv" --print-field runAttempt)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-ci-jobs --repository ChangGeng01/ProjectSix \
  --parent-record "$POSTMERGE_CI_DIR/selected-run-selection.json" \
  --parent-projection "$POSTMERGE_RUN_SELECTION_DIGEST" \
  --ids "$POSTMERGE_CI_DIR/selected-run-attempt.tsv" \
  --output "$POSTMERGE_CI_DIR/postmerge-ci-jobs-request-rows.json"
POSTMERGE_CI_JOBS_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$POSTMERGE_CI_DIR/postmerge-ci-jobs-request-rows.json" \
  --print-field manifestPath)"
qinao_gh --intent "$POSTMERGE_CI_JOBS_INTENT" --operation rest-read -- \
  api --paginate --slurp \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/ChangGeng01/ProjectSix/actions/runs/$POSTMERGE_RUN_ID/attempts/$POSTMERGE_RUN_ATTEMPT/jobs?per_page=100" \
  >"$POSTMERGE_CI_DIR/postmerge-jobs.pages.json"
POSTMERGE_CI_JOBS_REQUEST_PROJECTION_DIGEST="$(qinao_python \
  scripts/qinao_convergence_audit.py recover-captures --root "$EVIDENCE_ROOT" \
  --manifest "$POSTMERGE_CI_JOBS_INTENT" --print-field manifestSafeProjectionDigest)"
POSTMERGE_JOB_SELECTION_DIGEST="$(qinao_python scripts/qinao_workflow_inventory.py select-ci-jobs \
  --jobs "$POSTMERGE_CI_DIR/postmerge-jobs.pages.json" \
  --expected-set postmerge-seven \
  --request-projection "$POSTMERGE_CI_JOBS_REQUEST_PROJECTION_DIGEST" \
  --parent-record "$POSTMERGE_CI_DIR/selected-run-selection.json" \
  --parent-projection "$POSTMERGE_RUN_SELECTION_DIGEST" \
  --output "$POSTMERGE_CI_DIR/selected-job-selection.json" \
  --ids-output "$POSTMERGE_CI_DIR/selected-job-ids.txt" \
  --print-field selectionDigest)"
qinao_python scripts/qinao_workflow_inventory.py render-request-rows \
  --phase postmerge-ci-job-logs --repository ChangGeng01/ProjectSix \
  --parent-record "$POSTMERGE_CI_DIR/selected-job-selection.json" \
  --parent-projection "$POSTMERGE_JOB_SELECTION_DIGEST" \
  --ids "$POSTMERGE_CI_DIR/selected-job-ids.txt" \
  --output "$POSTMERGE_CI_DIR/postmerge-ci-job-log-request-rows.json"
POSTMERGE_CI_LOG_INTENT="$(qinao_python scripts/qinao_convergence_audit.py \
  seal-network-request-manifest --root "$EVIDENCE_ROOT" \
  --capture-id "$CAPTURE_ID" --preflight "$NETWORK_PREFLIGHT_RECORD" \
  --rows "$POSTMERGE_CI_DIR/postmerge-ci-job-log-request-rows.json" \
  --print-field manifestPath)"
while IFS= read -r JOB_ID; do
  qinao_gh --intent "$POSTMERGE_CI_LOG_INTENT" --operation job-log-read -- \
    api -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "repos/ChangGeng01/ProjectSix/actions/jobs/$JOB_ID/logs" \
    >"$POSTMERGE_CI_DIR/postmerge-job-$JOB_ID.safe.json"
done <"$POSTMERGE_CI_DIR/selected-job-ids.txt"
qinao_python scripts/qinao_workflow_inventory.py validate-postmerge-ci \
  --capture "$POSTMERGE_CI_DIR" --B "$B" --H "$H" --R "$R" --T "$T" --V "$V" \
  --workflow-contract docs/superpowers/evidence/2026-08-29-qinao-workflow-contract.v1.json \
  --output "$POSTMERGE_CI_DIR/postmerge-ci-result.json" \
  --capture-files-output "$POSTMERGE_CI_DIR/postmerge-ci-seal-files.txt"
POSTMERGE_CI_SEAL="$(qinao_python scripts/qinao_convergence_audit.py seal-capture \
  --root "$EVIDENCE_ROOT" --capture-id "$CAPTURE_ID" \
  --files-from "$POSTMERGE_CI_DIR/postmerge-ci-seal-files.txt" \
  --print-field sealRecordPath)"
```

Require the six baseline jobs plus `qinao-protocol-tests` to be unique, terminal, and successful. The two PR-only jobs must be absent or skipped exactly as frozen by the workflow contract; they can never replace a required push job. Stream every required job log through `job-log-read`, locate exactly one canonical `qinao.ci-push-identity.v1` record, and require `before=B`, `after=R`, ordered `parents=[B,H]`, tree `T`, `V`, repository, `refs/heads/main`, workflow blob/path, run/attempt, and record digest to match. Missing, duplicate, stale, cancelled, neutral, skipped-required, or green-without-identity is a failed post-merge verification.

Use the same monotonic bounded polling protocol as Task 13: 90-minute total deadline, `15,30,45,60,60...` second intervals, unique immutable capture per iteration, fixed headers, rate-limit/state drift checks, and no single wait over 60 seconds. A structurally complete nonterminal iteration runs `validate-postmerge-ci --allow-incomplete`, emits its explicit incomplete result/whitelist, seals the generation, and only then permits the next capture; a partial transport never becomes an incomplete terminal observation. Select exactly one `R`/main/push run and one attempt; stop on terminal failure. Deadline exhaustion creates an `incomplete` post-merge wait record with the last exact observation and enters Step 9—it is never reported as a delayed success without a fresh later verification.

- [ ] **Step 5: Re-capture host automation and prove the retirement transition closed**

Repeat the complete Task 12 endpoint table into a freshly allocated, sealed mode-0700 `phase=host-postmerge` capture—never a reusable fixed directory—including repository/delete-branch/Pages settings, complete deployments, Actions allowlists, workflows and per-workflow histories, one fresh historical Contents request/decoded-blob proof for every unique `(run.head_sha,literalLegacyPath)` in this snapshot, hooks, environments/rules, repository/environment secret and variable metadata, runners, each nonterminal run status, deploy keys, the same credential-type installation-visibility limitation/API-visible producers, collaborators/invitations, rulesets/protection, merged PR/check/status producers, review submissions, the separate fully paginated pull-request review-comment collection, the separate issue/timeline-comment collection, and all their producers. For `R` and every other commit identity admitted by this inventory, repeat the Task 13 two-view proof: commit check-runs with `filter=all`, complete check suites, every suite's `filter=all` runs, every run's raw/output digest, and every positive-count annotation family must have identical normalized unions/counts and remain below the provider completeness cap. Rebuild the dynamic endpoint manifest and reject default-`latest` data, any suite/ref/output/annotation disagreement, any cap hit, any missing review/comment family, any historical 404, source mismatch, Pages enablement, or unclassified deployment. Compute a new canonical `A_R`; it is a post-merge state digest and is not required to equal pre-merge `A`.

Require `R`/`H` candidate workflow contract active, `qinao-wave-admission.yml` absent from `R`, the remote PR branch still at `H`, and `delete_branch_on_merge=false`. Requery **every** frozen premerge `legacyWorkflowTransportId` directly plus its completely paginated run history even when the current workflow registry omits it. Also fetch the complete repository-wide Actions-run collection and prove pagination reaches strictly before the frozen premerge repository high-watermark without hitting the provider cap. Every newly observed run is assigned by a fresh exact `head_sha:path` Contents proof to absent-old, old blob, or reviewed-new blob. A per-ID 404 is not retirement evidence; it is acceptable only when the complete repository-wide delta closes the same time/ID window and contains no unassigned/old-blob run. If either view is unreadable/capped or their overlap disagrees, retirement is indeterminate.

For each legacy path's Task 13 three-state record, evaluate retirement by old generation `(path, oldBlobOid|null)` rather than assuming a provider workflow ID belongs forever to one blob. `base-source-absent` means only that no old source generation existed at `B`; it does **not** forbid a reviewed new generation at the same path in `R`:

- for `qinao-wave-admission.yml`, `R:path` remains absent; whether its `B` state was absent or retiring, any current registered record is absent or explicitly non-active after bounded rereads, every frozen ID is re-read or covered by the repository-wide fallback above, and no post-snapshot run resolves to the old blob;
- for `test.yml`, `R:path` equals the reviewed candidate blob and its active workflow record/selected `R` run bind that new blob; this is required even when `B:path` was `base-source-absent` and may reuse a provider numeric workflow ID;
- if `test.yml@oldBlob` was `base-retiring`, that old generation is separately retired when no post-snapshot/new run resolves `head_sha:path` to `oldBlob`; reuse of its numeric workflow ID by `test.yml@newBlob` is allowed and is not evidence that the old generation stayed active;
- a path/blob/run that cannot be assigned uniquely to absent-old, retired-old, or reviewed-new generation is indeterminate.

Compare complete frozen-ID/repository-wide run sets and high-watermarks and require no new run of either old blob, no queued/in-progress/waiting/requested/pending run after the selected `R` run becomes terminal, and no new privileged producer. An API that still reports an active old source, a terminal run hidden between snapshots, an ambiguous run/blob, a pagination cap/gap, or an unreadable high-privilege endpoint fails verification. Build `PostMergeIdentity(R,B,H,T,V)`, run `qinao_workflow_inventory.py validate-postmerge --inventory POSTMERGE_INVENTORY --identity POSTMERGE_IDENTITY --output POSTMERGE_RESULT`, and compute/store `A_R` only from its terminal canonical output, along with raw-stream/safe-projection endpoint digests, selected run/log-stream digests, and transition result.

- [ ] **Step 6: Reconstruct timeline evidence after merge**

Allocate a second fresh read capture and reconstruct all final-evidence chunks/manifest plus the complete approval-audit chain from the PR timeline. Re-read PR, `main`, candidate branch, and commit `R`; require byte/digest-compatible extension of `ENTRY_MERGE_OBSERVATION_SEAL`, matching `E`, exact `main=R`, candidate branch `H`, expected actor, tree `T`, and ordered parents `[B,H]`. Confirm that the pre-merge records bind `(B,H,T,V,A,M,P,E)`, verify all external evidence remains readable by digest, and re-open the already terminal original merge frontier with result `R`. This later comprehensive verification never substitutes for or delays Step 0's frontier closure. Before Step 8, require `recover-captures --require-no-open-mutation-frontier` again; any drift or new/open mutation blocks the post-merge comment.

- [ ] **Step 7: Verify the protected source state one final time**

Run the full protected audit, including branch/HEAD/index-stage/porcelain/raw/content manifests. Any mismatch is a separate incident and does not trigger cleanup.

- [ ] **Step 8: Post the post-merge verification record**

The canonical record includes `R`, tree, parents, `merged_by` login/ID, `B/H/T/V/A/M/P/E`, post-merge `A_R`, final remote `refs/heads/main`/remote PR branch, verification-worktree OID, exact main-push run/job/log/identity digests, closed-retirement result, final-evidence/latest-audit digests, protected-state digest, test decision, and any limitation. Choose the next `postMergeSequence` from the authoritative comment chain, preflight the exact logical key before POST, and post at most once using the Task 13 request/full-pagination/record-digest tri-state protocol. Older post-merge records remain immutable historical records.

- [ ] **Step 9: Handle failure only through a new PR**

If the merge succeeded but verification fails, do not edit/direct-push `main`, reset refs, or delete evidence. Prepare either a repair PR or reviewed revert PR from fresh remote `refs/heads/main`, with its own `B/H/T/V/A/M/P/E` and fresh approval.

- [ ] **Step 10: Preserve all recovery inputs**

Leave the design branch/worktree, convergence branch/worktree, protected worktree/ref, remote PR branch, evidence roots, LFS objects, and source commits intact. Cleanup/retention is a separately reviewed later decision.

Expected final result: `R` is independently reconstructable and verified, or the process is safely blocked with every recovery input preserved.

## Final acceptance checklist

- [ ] `D` is a plan-only child of `S`; `S` tree/spec blob and `5c87355…` ancestry match.
- [ ] `C` is a normal merge with ordered parents exactly `[4a9298d…,D]`; predicted and actual trees match.
- [ ] The protected worktree/ref/HEAD/index/status/raw/content manifests match all frozen witnesses before, during, and after work.
- [ ] The all-plan/spec inventory includes every tracked path and blob at `C`, including non-Markdown machine evidence; only exact supersession pointer transforms differ at `H`.
- [ ] Former admission/controller/iOS-floor jobs are not active; their historical Git blobs remain reachable.
- [ ] One active workflow has minimal read-only permissions, pinned external actions, explicit event behavior, no privileged cross-trigger flow, and no host-enforcement claim.
- [ ] Raw candidate diff preserves modes, types, full OIDs, status, and raw path bytes; LFS/binary/generated/vendor effects are explicit.
- [ ] The complete newly reachable Git/LFS object closure—not only `B→T`—has a frozen remote-advertisement boundary, terminal local disclosure, three complete pre-push egress reviews, and no secret/private/recovery/unknown upload.
- [ ] Every selected typed target is nonempty and terminal on exact `(B,H,T,V)`; intentional skips equal reviewed exact identities.
- [ ] Four specialist reviews plus integration review cover every raw entry; every finding is fixed, evidence-backed false-positive, or evidence-backed disputed-impact explicitly disposed by the user; none is incomplete or confirmed-actionable.
- [ ] Remote branch/PR recovery reuses confirmed `H`/one open PR, fast-forwards only an exact recorded `H_old`, and never repeats an unresolved push/create/PATCH.
- [ ] Every enumerated API-visible automation surface is complete at each sealed point-in-time capture; high-privilege unknowns are absent; any exact `B` legacy workflow transition is fully observed; `A` is stable at the post-approval reread; installation-grant and `transientHostMutationVisibility="unavailable-no-audit-log"` limitations remain explicit rather than upgraded into continuous-history claims.
- [ ] Canonical final evidence reconstructs the latest immutable generation from the PR timeline and verifies `E`; sequenced audit records remain non-authoritative.
- [ ] Fresh user approval binds exact `B/H/T/V/A/M/P/E` and is followed immediately by at most one manual merge attempt.
- [ ] `R` has tree `T`, ordered parents `[B,H]`, exact authenticated `merged_by` login/ID, no auto-merge, fresh-checkout verification, seven successful `R`-bound main-push jobs, a closed legacy-workflow transition, and a complete post-merge automation digest `A_R`.
- [ ] No branch protection/ruleset mutation, direct/force/delete push, Pages/deployment/publication activation, ref/worktree cleanup, snapshot, iCloud application-data work, or DS3 action occurred.
