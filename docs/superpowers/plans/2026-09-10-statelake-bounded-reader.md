# Task17 — bounded retained StateLake reader

**Execution checkpoint:** Three-file candidate implemented and frozen. Final
local reader/checked-bridge run passed26tests with no failures/skips, including
tiny real NDArrays. Independent review approved spec and quality with no Critical
or Important finding; the existing native-build deprecation is a non-blocking
verification note. No commit or issue closure is implied by this checkpoint.
Actual command/source identities are retained in Task17 handback.

This is the approved choice13A repair under the existing solo DS3-readiness
goal. It is not a new scan or an expansion of the experimental component.
Use subagent-driven-development / TDD and retain independent review.

## Global constraints

- Preserve existing artifacts, history, model selection and the normal
  statelake-device/1 int8/fp16 format. No real-store/key/data migration.
- Do not run PyTorch preparation, decode models, device/app probes, network,
  cloud/PCC, endurance, merge or DS3.
- No generic persistence framework, new dependency, Python-reader redesign or
  unrelated CoreAI helper repairs.
- Use only owned disposable fixture files. Coordinate the retained native
  scratch; Task15 source stays frozen through its independent review.
- Parser robustness is not proof of a supported attacker-controlled product
  import path. Keep the two historical source inputs and their provenance
  separate; do not broadly close them from a partial or skipped test.

## Files and existing evidence

Modify `BehavioralAISubstrate/Sources/BASAppleAdapters/BASStateLakeReader.swift`.
If needed, add one internal Foundation/Crypto decoding file in the same module
and one focused test file under the existing BehavioralAISubstrateTests target.
Do not add a target, public settings framework or public test-bypass API.
Root owns plan/evidence records.

Preparation and real paths are retained in
`.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/statelake-implementation-preflight-2026-09-10.md`.
The existing writer emits six ranked tensors with explicit dtype, shape, scale,
offset and byte length. It sets format statelake-device/1. Actual inference is
not required to test that byte format. The existing checked bridge
`validate(scalarCount:shape:)` may be reused; do not call its unchecked
elementCount/stride helpers on disk metadata.

## Design rulings

Keep the existing three-argument public load call and Loaded result. Preserve
existing binding/checksum/missing/header error categories where possible.
Typed private decoding is preferable to NSNumber/Bool/integer coercion through
unvalidated dictionaries. Reject unsupported format/dtype explicitly; do not
treat every non-int8 dtype as fp16.

Resource limits are local reader policy, not new file-format fields:
header <=1MiB, payload <=64MiB, total decoded Float16 bytes <=128MiB,
record count <=1024, rank 1...16. Limits must themselves have checked arithmetic.
These deliberately bound this retained experiment; larger artifacts are refused
with an explicit error, not silently truncated. An internal limits value may
allow tiny thresholds in tests through the same loader, not a public bypass.
Document these limits; do not infer a constant bound on whole-process RSS.

Open each file once, verify a regular descriptor and bound reads before growing
Data. A path-only size check followed by unbounded Data(contentsOf:) is not
sufficient. Use bounded chunks/EOF detection and reject growth past the cap.
Avoid blocking on a FIFO before the regular-file check; a nonblocking read-only
open is appropriate. Check actual read errors and handle descriptor ownership.
Concurrent bundle modification may fail validation; it must not be accepted as
a healthy partial load. No repair/rewrite/delete-on-error.

Validate all tensor metadata before any Float16/NDArray materialization:

- Nonempty unique names, exact integer offsets/lengths/dimensions, positive
  ranked extents; prompt length is nonnegative.
- Strict int8/fp16 dtype, finite positive int8 scale, contained byte range.
  Check range by subtraction/overflow-reporting, never unchecked start+nbytes.
- Exact byte-count/shape relationship, checked shape arithmetic and aggregate
  decoded allocation budget, including records not requested in stateOrder.
- Retain binding equality and full payload checksum validation.
- Missing requested states throw. Preserve requested ordering; if duplicate
  requested names are retained, avoid multiplying unbounded allocations.
- Decode fp16 bytes in the existing little-endian format without assuming raw
  pointer alignment. Validate representability rather than producing an
  overflowed int8-dequantized Float16. Do not revive corrupt numeric state.

Keep the validation/byte-decoding part testable without running a model.
Construct actual tiny NDArrays only in the public-reader integration controls
on an available CoreAI/macOS27 runtime. Local OS was observed as27.0; compiler
availability must be observed by the test, never inferred as a passing skip.

## Steps and evidence

1. Preserve original reader hash. Add a safe behavioral RED such as unsupported
   dtype with two valid payload bytes and a matching checksum/binding: the old
   reader accepts it as fp16, but the new contract must throw. Do not deliberately
   crash the runner with Int.max allocation or out-of-bounds old code. Missing
   new types alone are compile RED, not exercised parser failure.
2. Implement bounded file loading and full metadata validation before decoding.
   Preserve valid int8/fp16 ordering/numerical values, binding/checksum failures.
3. Add disposable controls for Bool/fractional/negative/overflow integers;
   zero/empty/excessive rank/shape, start/end/truncation/byte mismatch, unsupported
   dtype/format, duplicate names, absent requested state, invalid/overflow scale;
   exact limits and one-past limits (small internal thresholds or sparse files).
   Exercise oversized header/payload refusal without allocating oversized data.
4. Add valid mixed int8/fp16 artifact with odd byte offset to exercise alignment
   independence; compare decoded scalars and requested order. Add real public
   tiny-NDArray load/error controls when supported. No inference/model files.
5. Run focused tests then the relevant final reader/bridge suites once after
   final source changes using the already retained no-model native environment.
   Record selection/pass/skip/platform counts, errors, terminal command status,
   source identities and complete logs. Any missing platform evidence stays open.
6. Freeze one task-only candidate/report for independent spec/quality review.
   Resolve reviewed defects, re-review only the delta, then root commits code,
   this plan and concise evidence. Do not modify unrelated in-progress work.

This plan is saved for the next implementation slot; no Task17 source edit,
test, model invocation or issue closure has occurred merely by writing it.
