# Qinao P0 Execution Containment Design

**Status:** Approved implementation slice derived from the replacement Deep Scan and the user's 2026-08-24 instruction to begin implementation.

## Purpose

Close two concrete source-to-sink defects immediately without creating a second business authority, recovery store, provider registry, or release-admission path:

- `csf_a55195bf4dc071dd07ea8b40`: the paired HumanEval harness executes model-generated Python with `python -I` but does not use the repository's deny-default macOS sandbox.
- `csf_b4f26c94524cc59f6387550d`: the Mamba deploy converter imports code from a hard-coded external checkout and loads an unauthenticated pickle checkpoint before trust is established.

This is tactical P0 containment for the selected Option 2 execution-gateway architecture. It does not claim to implement the future owned gateway, the W1 provider inversion, or the K3 recovery spine.

## Architectural Boundary

This slice owns no durable truth. It only makes two local tool boundaries fail closed:

1. **Generated-code execution boundary.** Every paired-evaluation program is passed to the existing `qinao_sandbox.run_sandboxed` helper. There is no direct-subprocess fallback. If the sandbox is absent or cannot start, the run is classified as infrastructure failure and excluded from model scoring.
2. **Checkpoint-consumption boundary.** A checkpoint is never deserialized from its caller-controlled path. The loader opens a non-symlink regular file, copies a bounded byte stream into an unlinked temporary snapshot while hashing, compares an explicit `sha256:<hex>` expectation, rewinds that exact snapshot, and only then invokes PyTorch with `weights_only=True`.
3. **Code-provenance boundary.** `mamba3_deploy.py` imports sibling tooling relative to its own resolved source directory. It does not reach into a hard-coded primary checkout while executing from a candidate worktree.

The future execution/provider gateway will absorb these checks behind one owned physical boundary. Until then, these guards are deliberately local and cannot mint authorization, certify a provider, advance a wave, or write recovery state.

## Invariants

- Model-generated Python cannot execute through a raw `subprocess.run` path in the paired evaluator.
- Sandbox launch failure never falls back to unsandboxed execution.
- `-I`, timeout, and denominator semantics remain intact.
- A trained checkpoint requires an explicit `CKPT_SHA256=sha256:<64 lowercase hex>` value.
- Digest mismatch, malformed/missing digest, symlink, non-regular file, oversize input, snapshot drift, or unsupported safe-load behavior fails before trained parameters are used.
- The byte sequence hashed is the byte sequence passed to the restricted loader.
- `FORCE_RANDOM=1` remains an explicit non-production graph/ANE probe and consumes no checkpoint.
- No file under `.github/workflows`, no existing dirty plan, no owner-ledger script, no Swift runtime source, and no persistence schema changes in this slice.

## Data Flow

```text
model text -> temporary .py -> existing deny-default sandbox -> result/timeout/infra

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
- Checkpoint guard failures terminate deployment with a concise refusal message. There is no permissive mode and no implicit digest discovery beside the artifact.
- The guard does not trust file names, modification times, “latest” selection, or a digest stored inside the same checkpoint.
- A configured byte limit prevents accidental or hostile unbounded staging. The default is 16 GiB and can only be changed through an explicit positive `CKPT_MAX_BYTES` value.

## Verification

- Unit tests prove mandatory sandbox delegation and preserved outcome semantics.
- Unit tests prove malformed/missing/mismatched checkpoint identities reject before loader invocation.
- Unit tests prove the loader receives only the verified unlinked snapshot and always receives `weights_only=True`.
- A real-PyTorch conditional test proves a malicious pickle payload cannot execute.
- An integration source test proves the deploy converter uses candidate-local imports and the verified loader.
- Existing sandbox behavior tests verify benign code, sensitive-read denial, network denial, and write confinement on macOS.

## Deferred Governed Work

- Exact-origin/credential-bound remote provider admission.
- A single `SovereignCapability -> ExecutionAdmissionReceipt` gateway.
- W1 provider inversion and one-operation stream/final semantics.
- Recovery transition persistence through the incumbent K3/EventLog owner.
- Halt epochs through the incumbent sovereign ledger owner.

Those items must follow the active controlled-convergence plans. They must not be accelerated by creating parallel registries, stores, journals, or certification authorities.
