# Qinao P0 Execution Containment Design

**Status:** Implementation correction in progress. The first implementation passed its focused tests, but the 2026-08-24 whole-range adversarial review rejected the slice because the sandbox, metric evidence, verdict, and deploy validation did not yet fail closed as one system.

## Purpose

Close two concrete source-to-sink defects immediately without creating a second business authority, recovery store, provider registry, or release-admission path:

- `csf_a55195bf4dc071dd07ea8b40`: the paired HumanEval harness executes model-generated Python with `python -I` but does not use the repository's deny-default macOS sandbox.
- `csf_b4f26c94524cc59f6387550d`: the Mamba deploy converter imports code from a hard-coded external checkout and loads an unauthenticated pickle checkpoint before trust is established.

The generated-code defect is end-to-end: execution, infrastructure classification,
side-file aggregation, merge provenance, and release verdict are one security
boundary. A sandbox refusal must never become a computed model score. The
checkpoint defect likewise includes post-load trained-state completeness: safe
deserialization is insufficient if optimized Python can skip the refusal and save
an uninitialized asset.

This is tactical P0 containment for the selected Option 2 execution-gateway architecture. It does not claim to implement the future owned gateway, the W1 provider inversion, or the K3 recovery spine.

## Architectural Boundary

This slice owns no durable truth. It only makes two local tool boundaries fail closed:

1. **Generated-code execution boundary.** Every HumanEval program is copied into a private mode-0700 per-run directory and executed only after `sandbox-exec` has activated a deny-default profile. A trusted pre-exec launcher reports activation over an inherited private descriptor; stderr text is never used as the trust signal. Missing launch, failed profile application, and missing activation are typed `SandboxInfrastructureError` failures. The generated program receives a minimal environment, may write only inside its own run directory, cannot fork, and cannot retain descendants. The parent owns a fresh process session and performs process-group cleanup after success, failure, and timeout. There is no direct or unsandboxed fallback.
2. **Evaluation-evidence boundary.** A HumanEval metric exists only when its denominator is a positive integer. An invalid/all-infrastructure side-file actively removes metric `30` and its computed provenance from pre-existing values. Missing baseline evidence is `PENDING`, not a non-blocking `NOTE`. Base, tuned, merge, and verdict therefore fail closed as one chain.
3. **Checkpoint-consumption boundary.** A checkpoint is never deserialized from its caller-controlled path. The loader opens a non-symlink regular file, copies a bounded byte stream into an unlinked temporary snapshot while hashing, compares an explicit `sha256:<hex>` expectation, rewinds that exact snapshot, and only then invokes PyTorch with `weights_only=True`.
4. **Trained-state and code-provenance boundary.** Missing trained parameters or unexpected tensors cause explicit runtime refusal even under `python -O`, before quantization, conversion, deletion, or asset save. `mamba3_deploy.py` imports sibling tooling relative to its own resolved source directory and never reaches into a hard-coded primary checkout.

The future execution/provider gateway will absorb these checks behind one owned physical boundary. Until then, these guards are deliberately local and cannot mint authorization, certify a provider, advance a wave, or write recovery state.

## Invariants

- Model-generated Python cannot execute through a raw `subprocess.run` path in the paired evaluator.
- Sandbox launch failure never falls back to unsandboxed execution.
- Sandbox activation is authenticated by a parent-created descriptor that model output cannot forge.
- One evaluation cannot write into a sibling evaluation directory or leave a descendant alive after return or timeout.
- `-I`, timeout, and denominator semantics remain intact.
- HumanEval metric `30` and its computed provenance cannot survive a zero/invalid denominator, including as stale pre-existing data.
- Missing baseline metric `30` blocks the base-relative gate as `PENDING`.
- A trained checkpoint requires an explicit `CKPT_SHA256=sha256:<64 lowercase hex>` value.
- Digest mismatch, malformed/missing digest, symlink, non-regular file, oversize input, snapshot drift, or unsupported safe-load behavior fails before trained parameters are used.
- The byte sequence hashed is the byte sequence passed to the restricted loader.
- Missing/unexpected trained-state keys are refused by explicit control flow that optimization cannot erase, and no output asset is saved after refusal.
- `FORCE_RANDOM=1` remains an explicit non-production graph/ANE probe and consumes no checkpoint.
- No file under `.github/workflows`, no existing dirty plan, no owner-ledger script, no Swift runtime source, and no persistence schema changes in this slice.

## Data Flow

```text
model text -> private run root -> authenticated deny-default sandbox
                              -> model result / timeout / typed infrastructure failure
                              -> positive-denominator side-file or unavailable evidence
                              -> stale-clearing merge -> fail-closed base/tuned verdict

candidate-local tool code
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
           existing shape/state checks
```

## Failure Semantics

- Sandbox or process-launch exceptions remain visible infrastructure failures; they are not scored as model failures.
- A generated program that prints the same text as a sandbox error remains a model-attributable result because classification uses the private activation descriptor, not stderr matching.
- HumanEval writes no numeric metric when no program ran. An invalid HumanEval side-file revokes stale metric/provenance, and any unavailable base or tuned side blocks gate 30.
- Checkpoint guard failures terminate deployment with a concise refusal message. There is no permissive mode and no implicit digest discovery beside the artifact.
- Trained-state shape/key refusal uses explicit exceptions or branches rather than `assert`; Python optimization cannot remove it.
- The guard does not trust file names, modification times, “latest” selection, or a digest stored inside the same checkpoint.
- A configured byte limit prevents accidental or hostile unbounded staging. The default is 16 GiB and can only be changed through an explicit positive `CKPT_MAX_BYTES` value.

## Verification

- Unit tests prove mandatory sandbox delegation, an unforgeable activation distinction, and preserved outcome semantics.
- External macOS seatbelt tests prove private-run writes, sibling-temp denial, network/sensitive-read denial, and absence of detached descendants after both normal completion and timeout.
- Actual side-file merge plus verdict tests cover all-infrastructure, base-only-infrastructure, and tuned-only-infrastructure cases with stale metric/provenance seeded beforehand.
- Unit tests prove malformed/missing/mismatched checkpoint identities reject before loader invocation.
- Unit tests prove the loader receives only the verified unlinked snapshot and always receives `weights_only=True`.
- A real-PyTorch conditional test proves a malicious pickle payload cannot execute.
- An integration source test proves the deploy converter uses candidate-local imports and the verified loader.
- An optimized-interpreter integration test proves missing/unexpected trained keys refuse and no asset save occurs under `python -O`.
- A pre/post content manifest proves all 33 protected dirty paths remain byte-for-byte unchanged.

## Deferred Governed Work

- Exact-origin/credential-bound remote provider admission.
- A single `SovereignCapability -> ExecutionAdmissionReceipt` gateway.
- W1 provider inversion and one-operation stream/final semantics.
- Recovery transition persistence through the incumbent K3/EventLog owner.
- Halt epochs through the incumbent sovereign ledger owner.

Those items must follow the active controlled-convergence plans. They must not be accelerated by creating parallel registries, stores, journals, or certification authorities.
