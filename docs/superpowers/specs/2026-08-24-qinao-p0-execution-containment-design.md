# Qinao P0 Execution Containment Design

**Status:** Accepted for this P0 tactical-containment slice. The implementation
and prior status documentation are durably committed through `d3650dc5e`. Fresh
component reviewers accepted the sandbox, deploy, and HumanEval evidence
boundaries after the earlier adversarial rejections, and an independent
whole-range reviewer accepted `4f0b9846c..d3650dc5e` with P0–P3 clear. Latest
focused evidence is: checkpoint 45/45 under real PyTorch; system Python 45
discovered with two honest dependency skips; non-sandbox HumanEval/local-eval
136/136; and external macOS Seatbelt 43/43. This status does not authorize a
next governed slice or any global-recovery claim.

## Purpose

Close two concrete source-to-sink defects immediately without creating a second business authority, recovery store, provider registry, or release-admission path:

- `csf_a55195bf4dc071dd07ea8b40`: the paired HumanEval harness originally
  executed model-generated Python with `python -I` but without the repository's
  deny-default macOS sandbox.
- `csf_b4f26c94524cc59f6387550d`: the Mamba deploy converter originally imported
  code from a hard-coded external checkout and loaded an unauthenticated pickle
  checkpoint before trust was established.

The generated-code defect is end-to-end: execution, infrastructure classification,
side-file aggregation, merge provenance, and release verdict are one security
boundary. A sandbox refusal must never become a computed model score. The
checkpoint defect likewise includes post-load trained-state completeness: safe
deserialization is insufficient if optimized Python can skip the refusal and save
an uninitialized asset.

This is tactical P0 containment for the selected Option 2 execution-gateway architecture. It does not claim to implement the future owned gateway, the W1 provider inversion, or the K3 recovery spine.

## Architectural Boundary

This slice creates no new durable business, recovery, authorization, or
release-admission owner. It continues to emit the incumbent run-scoped
HumanEval evidence outputs and adds only authority-free lock files and
opaque-token incomplete-attempt tombstones as fail-closed coordination state.
Those coordination files carry no score, subject fact, completed-attempt
history, provider authority, or recovery transition. It makes four local tool
boundaries fail closed:

1. **Generated-code execution boundary.** Every HumanEval program is copied from
   one bounded `O_NOFOLLOW` source descriptor into a private mode-0700 run root
   and executed only after `sandbox-exec` activates a deny-default profile.
   Activation and normal completion use separate randomized control witnesses;
   process status zero without the trusted launcher's normal-return witness is a
   model failure, not PASS. The parent applies CPU/FSIZE/NOFILE kernel backstops,
   but CPU acceptance is independently accounted outside model control: live
   user+system CPU is observed through Darwin process accounting with Mach
   timebase conversion, and exit usage is retained through `wait4`. A program
   cannot turn a handled or ignored `SIGXCPU` into success. Bounded capture plus
   host-observed RSS, thread, private-directory and CPU policy, fresh-session
   ownership, and total teardown remain mandatory. Missing activation,
   observability, or cleanup proof is typed infrastructure failure. There is no
   raw fallback.
2. **Evaluation-evidence boundary.** Both writers, typed aggregation and verdict
   share one versioned evidence schema. Metric 30 requires an explicit current
   run context: run-scoped evidence directory, tag-specific external subject
   SHA-256 receipt, current producer/harness digest, loaded dataset fingerprint,
   canonical sample IDs/count/digest, strict passed/total arithmetic, and zero
   infrastructure errors. Arbitrary explicit paths are generic regardless of
   filename. Before long-running producer work, a writer creates and fsyncs a
   unique incomplete-attempt tombstone, then holds the tag's exclusive lock
   through invalidation, publication, and normal scope exit. The tombstone stays
   visible for the complete producer body. Readers hold the corresponding shared
   lock and reject the tag while any tombstone remains. Verdict construction
   acquires distinct base/tuned locks in deterministic order and holds one
   anchored directory snapshot through both reads and comparison.

   Publication writes and fsyncs a private temporary fd, atomically renames it,
   retains that exact inode fd, verifies the no-follow path still names it, and
   fsyncs the directory. The current attempt clears its tombstone only after
   durable publication and a normal scope exit. A crashed attempt's marker
   persists fail-closed; only a later exclusive writer may prune it after proving
   the marker lock is no longer held. Commit failure must leave a durable marker,
   durably invalidate the output, or truncate and fsync the exact retained
   publication fd so it cannot parse as evidence. Aggregation accepts only the
   exact internal single-tag and multi-tag observation runtime types and
   revalidates their anchored directory and full live lock set. Cleanup first
   attempts every flock unlock, then closes each detached fd exactly once;
   primary failures are preserved and cleanup-only failures are reported.
   Base/tuned must use distinct tags and distinct subject SHA-256 identities,
   while proving the same run, producer, harness, dataset and sample set before
   comparison. Any missing/mismatched fact removes metric/provenance and yields
   blocking `PENDING`.
3. **Checkpoint-consumption boundary.** A checkpoint is never deserialized from its caller-controlled path. The loader opens a non-symlink regular file, copies a bounded byte stream into an unlinked temporary snapshot while hashing, compares an explicit `sha256:<hex>` expectation, rewinds that exact snapshot, and only then invokes PyTorch with `weights_only=True`.
4. **Trained-state and code-provenance boundary.** Missing trained parameters,
   unexpected tensors, or present nonzero registered decode state cause explicit
   refusal under `python -O` before quantization, conversion, deletion, or save.
   Deployment resolves the full reviewed commit in a self-contained no-checkout
   object store, verifies its security floor, rejects non-regular tree modes,
   and runs guards from a private commit-derived guard snapshot verified by fresh
   pre/post indices. Conversion does not execute that directory or a reusable
   archive path. A fresh temporary bare namespace initialized with `--template=`
   borrows only the verified object database. The object clone's local config,
   `refs/replace`, and `.git/info/attributes` do not participate; system/global
   configuration and attributes are disabled explicitly with
   `GIT_NO_REPLACE_OBJECTS=1`, `GIT_ATTR_NOSYSTEM=1`, and
   `core.attributesFile=/dev/null`. `git archive` writes directly into an
   unlinked `TemporaryFile`; its regular-file, zero-link, and nonempty properties
   are checked before the exact descriptor is inherited and imported through
   `/dev/fd/<n>`. Python remains isolated and `uv` runs with both `--no-config`
   and `--no-project`.

The future execution/provider gateway will absorb these checks behind one owned physical boundary. Until then, these guards are deliberately local and cannot mint authorization, certify a provider, advance a wave, or write recovery state.

## Invariants

- Model-generated Python cannot execute through a raw `subprocess.run` path in the paired evaluator.
- Sandbox launch failure never falls back to unsandboxed execution.
- Sandbox activation is accepted only through a randomized parent-created
  descriptor; stderr text and exit status cannot forge it. Same-interpreter
  tampering remains an explicit residual rather than a cryptographic guarantee.
- Process exit status zero is insufficient; missing normal-completion witness is
  a bounded nonzero model result.
- One evaluation cannot write into a sibling evaluation directory or leave a descendant alive after return or timeout.
- `-I`, true wall-timeout semantics, bounded resource policy and denominator
  semantics remain distinct.
- HumanEval metric `30` and its computed provenance cannot survive a zero/invalid denominator, any infrastructure failure, malformed/non-finite score, or inconsistent paired vector, including as stale pre-existing data.
- A legacy, replayed, wrong-run, wrong-subject, wrong-harness, wrong-dataset,
  wrong-producer or different-sample-set HumanEval file cannot certify metric 30.
- Missing baseline metric `30` blocks the base-relative gate as `PENDING`.
- A trained checkpoint requires an explicit `CKPT_SHA256=sha256:<64 lowercase hex>` value.
- Digest mismatch, malformed/missing digest, symlink, non-regular file, oversize input, snapshot drift, or unsupported safe-load behavior fails before trained parameters are used.
- The byte sequence hashed is the byte sequence passed to the restricted loader.
- Missing/unexpected trained-state keys are refused by explicit control flow that optimization cannot erase, and no output asset is saved after refusal.
- Only exact registered decode-state names may be absent, and any registered
  state present in the checkpoint must be proven zero.
- Conversion source bytes come from an anonymous stream exported from the
  reviewed object identity, not a mutable checkout, reusable archive path, or
  caller-controlled index; ambient Python/Git/uv configuration does not enter
  the documented command.
- A current HumanEval attempt marker remains visible until a normal scope exit
  commits the exact retained publication. A crashed marker persists until a
  later exclusive writer proves it stale and prunes it; readers cannot accept an
  in-flight/crashed attempt, and base/tuned cannot be observed as two fractured
  snapshots.
- `FORCE_RANDOM=1` remains an explicit non-production graph/ANE probe and consumes no checkpoint.
- No application/runtime persistence owner or schema, pre-existing protected
  dirty plan, workflow, owner-ledger script, or Swift runtime source changes in
  this slice; the run-scoped local HumanEval evidence and coordination format is
  the intentional exception.

## Data Flow

```text
model text -> bounded private snapshot -> authenticated deny-default sandbox
                                      -> activation + normal-completion witness
                                      -> bounded model result / timeout / typed infra
current run + subject + harness + actual dataset + canonical task set
                                      -> atomic typed side-file or unavailable evidence
                                      -> receipt-validating merge
                                      -> comparable base/tuned gate or PENDING

reviewed candidate-local tool closure
        + explicit expected SHA-256
        + bounded non-symlink checkpoint file
                    |
                    v
      hash while copying to unlinked snapshot
                    |
          constant-time digest match
                    |
                    v
       torch.load(snapshot, weights_only=True)
                    |
       trained/decode-state refusal
                    |
 reviewed commit -> self-contained object store
                 -> private guard snapshot -> guards -> fresh-index proof

 same verified object database
                 -> fresh temporary bare Git namespace
                 -> replacements/config/attributes isolated
                 -> git archive stdout -> anonymous TemporaryFile fd
                 -> /dev/fd import under uv --no-config --no-project
                 -> conversion
```

## Failure Semantics

- Sandbox or process-launch exceptions remain visible infrastructure failures; they are not scored as model failures.
- A generated program that prints the same text as a sandbox error remains a model-attributable result because classification uses the private activation descriptor, not stderr matching.
- Early `SystemExit(0)`/`os._exit(0)` without the trusted normal-return witness is
  nonzero model failure. Only true wall timeout raises `TimeoutExpired`; resource
  policy breach returns a bounded nonzero result after teardown.
- HumanEval writes no numeric metric when no program ran. An invalid HumanEval side-file revokes stale metric/provenance, and any unavailable base or tuned side blocks gate 30.
- Durable admission immediately revokes acceptance for the tag. After the writer
  acquires the tag's exclusive lock it physically invalidates both same-tag
  standard/paired outputs; its marker remains until normal commit, so a crash or
  interrupted cleanup cannot reuse an older or partially published success.
- During attempt/observation descriptor teardown, a cleanup syscall failure never
  truncates the remaining descriptor cleanup traversal or silently converts
  infrastructure uncertainty into success. All flock releases are attempted
  before every detached fd receives exactly one close attempt.
- Checkpoint guard failures terminate deployment with a concise refusal message. There is no permissive mode and no implicit digest discovery beside the artifact.
- Trained-state shape/key refusal uses explicit exceptions or branches rather than `assert`; Python optimization cannot remove it.
- The guard does not trust file names, modification times, “latest” selection, or a digest stored inside the same checkpoint.
- Deployment does not trust Git status/index flags or execute the reviewed
  repository worktree. Tree symlinks/gitlinks and startup environment injection
  fail before conversion.
- A configured byte limit prevents accidental or hostile unbounded staging. The default is 16 GiB and can only be changed through an explicit positive `CKPT_MAX_BYTES` value.

## Verification

- Unit tests prove mandatory sandbox delegation, distinct activation/completion
  control flow, early-zero-exit refusal, bounded resource outcomes, and preserved
  timeout semantics. They do not call the same-interpreter completion witness a
  cryptographic proof.
- External macOS seatbelt tests prove private-run writes, sibling-temp denial, network/sensitive-read denial, and absence of detached descendants after both normal completion and timeout.
- Actual side-file merge plus verdict tests cover all-infrastructure, base-only-infrastructure, and tuned-only-infrastructure cases with stale metric/provenance seeded beforehand.
- Receipt tests cover spoofed filenames, legacy/replayed files, partial context,
  subject/harness/dataset/sample-set mismatch, standard aggregate consistency,
  cross-producer replay, crash invalidation, and real CLI verdict behavior.
- Unit tests prove malformed/missing/mismatched checkpoint identities reject before loader invocation.
- Unit tests prove the loader receives only the verified unlinked snapshot and always receives `weights_only=True`.
- A real-PyTorch conditional test proves a malicious pickle payload cannot execute.
- An integration source test proves the deploy converter uses candidate-local imports and the verified loader.
- An optimized-interpreter integration test proves missing/unexpected trained keys refuse and no asset save occurs under `python -O`.
- Documented-shell tests prove index flags, mutable-source changes, replacement
  refs, repository attributes, tree links, ambient Git/Python/uv injection,
  project-local uv environments, and post-check mutation cannot change the
  reviewed anonymous conversion stream; optimized tests cover present
  zero/nonzero registered decode state.
- A pre/post content manifest proves all 33 protected dirty paths remain byte-for-byte unchanged.

Latest acceptance evidence is checkpoint 45/45 with real PyTorch, system-Python
checkpoint 45 discovered with two honest dependency skips, non-sandbox
HumanEval/local-eval 136/136, and external macOS Seatbelt 43/43. Fresh component
reviewers returned `ACCEPT` for evidence, sandbox, and deploy; an independent
whole-range reviewer returned `ACCEPT` for `4f0b9846c..d3650dc5e` with P0–P3
clear. None of these decisions expands the scope beyond this tactical slice.

## Accepted Residual Boundaries

- HumanEval receipts remain plaintext accidental-integrity evidence. A process
  able to rewrite environment, subject manifest and side-file together can forge
  them; authenticity belongs in the future owned execution/evidence gateway.
- HumanEval lock/tombstone files are durable coordination, not authority,
  recovery history, or completed-attempt records. A failed marker may remain and
  block reads until a later exclusive writer safely prunes it. If all marker,
  exact-fd poison, and path-invalidation primitives fail together, the tool
  reports that fail-closed state is unprovable rather than claiming recovery.
- The completion witness shares a Python interpreter with generated code and is
  a control-flow guard, not cryptographic isolation. A deliberately adversarial
  program may inspect frames/descriptors; a future external execution agent must
  issue the durable completion receipt.
- RSS/thread/directory/output aggregation and live CPU accounting are sampled by
  the host and can have a small bounded observation overshoot. `wait4` closes the
  exit-CPU gap; these observations do not attest binary or execution-stack
  identity. FSIZE/NOFILE and CPU signals remain kernel backstops.
- The private guard snapshot and anonymous conversion stream are two different
  materializations of the same reviewed object identity. The guard snapshot is
  not the final conversion source.
- Git/Python/uv/PyTorch/CoreAI binary identities and the joint checkpoint/source
  release receipt remain external prerequisites. A hostile same-user/root actor
  requires a separately attested release account/container.
- Non-HumanEval ladder producers retain legacy existence caching; this slice does
  not claim all 100 metrics are current-run bound.

## Deferred Governed Work

- Exact-origin/credential-bound remote provider admission.
- A single `SovereignCapability -> ExecutionAdmissionReceipt` gateway.
- W1 provider inversion and one-operation stream/final semantics.
- Recovery transition persistence through the incumbent K3/EventLog owner.
- Halt epochs through the incumbent sovereign ledger owner.

Those items must follow the active controlled-convergence plans. They must not be accelerated by creating parallel registries, stores, journals, or certification authorities.
